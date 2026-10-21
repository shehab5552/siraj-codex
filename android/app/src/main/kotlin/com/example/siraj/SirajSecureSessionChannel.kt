package com.example.siraj

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * SIRAJ P0: Android-only storage of an opaque local session marker.
 * AES-256-GCM key NEVER leaves AndroidKeyStore. The encrypted payload is held
 * in app-private preferences. All disk and crypto work is off the UI thread.
 * No biometric permission or device-credential prompt is required.
 *
 * The b04_test namespace is strictly separate from production storage.
 * This class never accesses the user's SQLite database or their password.
 */
internal class SirajSecureSessionChannel(
    context: Context,
    messenger: BinaryMessenger,
) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { task ->
        Thread(task, "siraj-secure-session").apply { isDaemon = true }
    }
    private val channel = MethodChannel(messenger, "siraj/auth_keystore_v1")

    init {
        channel.setMethodCallHandler { call, result ->
            // Never run Keystore, Cipher, or SharedPreferences on Android's UI.
            worker.execute {
                try {
                    val scope = scopeFor(call)
                    val response: Any? = when (call.method) {
                        "read" -> read(scope)
                        "write" -> {
                            val marker = call.argument<String>("marker")
                                ?: throw IllegalArgumentException("Missing marker")
                            require(marker.isNotEmpty() && marker.length <= 65536) {
                                "Invalid marker size"
                            }
                            write(scope, marker)
                            null
                        }
                        "clear" -> {
                            clear(scope)
                            null
                        }
                        else -> throw IllegalArgumentException("Unsupported method")
                    }
                    mainHandler.post { result.success(response) }
                } catch (_: Exception) {
                    // Do not log or return private strings, keystore details,
                    // key aliases, exception bodies, or plaintext markers.
                    mainHandler.post {
                        result.error("SIRAJ_SECURE_SESSION_FAILED", "Secure session operation failed", null)
                    }
                }
            }
        }
    }

    private data class Scope(val prefsName: String, val keyAlias: String)

    private fun scopeFor(call: MethodCall): Scope {
        return when (call.argument<String>("scope")) {
            "production" -> Scope("siraj_p0_secure_session_v1", "siraj_p0_aes_session_v1")
            "b04_test" -> Scope("siraj_p0_b04_secure_test_v1", "siraj_p0_aes_b04_test_v1")
            else -> throw IllegalArgumentException("Invalid storage scope")
        }
    }

    private fun preferences(scope: Scope) =
        appContext.getSharedPreferences(scope.prefsName, Context.MODE_PRIVATE)

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply {
        load(null)
    }

    private fun keyForRead(scope: Scope): SecretKey {
        return keyStore().getKey(scope.keyAlias, null) as? SecretKey
            ?: throw IllegalStateException("Session key unavailable")
    }

    private fun keyForWrite(scope: Scope): SecretKey {
        val existing = keyStore().getKey(scope.keyAlias, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore",
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                scope.keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setKeySize(256)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(false)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }

    private fun write(scope: Scope, marker: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, keyForWrite(scope))
        val iv = cipher.iv
        require(iv.size == 12) { "Unexpected GCM nonce length" }
        val encoded = marker.toByteArray(Charsets.UTF_8)
        val encrypted = try {
            cipher.doFinal(encoded)
        } finally {
            encoded.fill(0)
        }
        val payload = Base64.encodeToString(iv + encrypted, Base64.NO_WRAP)
        if (!preferences(scope).edit().putString(PAYLOAD_KEY, payload).commit()) {
            throw IllegalStateException("Encrypted marker persistence failed")
        }
    }

    private fun read(scope: Scope): String? {
        val payload = preferences(scope).getString(PAYLOAD_KEY, null) ?: return null
        val bytes = Base64.decode(payload, Base64.NO_WRAP)
        require(bytes.size >= 12 + 16) { "Invalid encrypted marker" }
        val iv = bytes.copyOfRange(0, 12)
        val cipherBytes = bytes.copyOfRange(12, bytes.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, keyForRead(scope), GCMParameterSpec(128, iv))
        val plaintext = cipher.doFinal(cipherBytes) // Authenticated decrypt: fails closed
        return try {
            String(plaintext, Charsets.UTF_8)
        } finally {
            plaintext.fill(0)
        }
    }

    private fun clear(scope: Scope) {
        if (!preferences(scope).edit().remove(PAYLOAD_KEY).commit()) {
            throw IllegalStateException("Encrypted marker deletion failed")
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    private companion object {
        const val PAYLOAD_KEY = "encrypted_session_marker"
    }
}
