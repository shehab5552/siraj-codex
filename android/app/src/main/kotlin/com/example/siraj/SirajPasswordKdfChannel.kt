package com.example.siraj

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/** One CPU task at a time, including across activity/engine replacement.
 * No credentials/exception messages are logged or returned. Logical cancellation
 * is owned by Dart; a running provider call drains before the lane is reusable. */
internal class SirajPasswordKdfChannel(messenger: BinaryMessenger) {
    companion object { private val occupied = AtomicBoolean(false) }
    private val channel = MethodChannel(messenger, "siraj/password_kdf")
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var disposed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "derive") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val password = call.argument<String>("password")
            val salt = call.argument<ByteArray>("salt")
            val iterations = call.argument<Int>("iterations")
            if (password.isNullOrEmpty() || password.length > 1024 ||
                password.toByteArray(Charsets.UTF_8).size > 1024 ||
                salt == null || salt.isEmpty() || salt.size > 256 ||
                iterations == null || iterations !in 1..5000000) {
                result.error("KDF_INVALID", null, null)
                return@setMethodCallHandler
            }
            if (!occupied.compareAndSet(false, true)) {
                result.error("KDF_BUSY", null, null)
                return@setMethodCallHandler
            }
            val chars = password.toCharArray()
            val nonce = salt.copyOf()
            executor.execute {
                var spec: PBEKeySpec? = null
                var derived: ByteArray? = null
                var output: ByteArray? = null
                var failed = false
                try {
                    spec = PBEKeySpec(chars, nonce, iterations, 256)
                    derived = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
                        .generateSecret(spec).encoded
                    output = derived.copyOf()
                } catch (_: Exception) {
                    failed = true
                } finally {
                    spec?.clearPassword()
                    chars.fill('\u0000')
                    nonce.fill(0)
                    derived?.fill(0)
                    occupied.set(false)
                }
                // Completion is observable only after provider cleanup and
                // global lane release. Posting earlier races the next derive.
                val response = output
                val posted = main.post {
                    try {
                        if (!disposed) {
                            if (failed) result.error("KDF_FAILED", null, null)
                            else result.success(response)
                        }
                    } finally { response?.fill(0) }
                }
                if (!posted) response?.fill(0)
            }
        }
    }

    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        // Do not interrupt provider cleanup or free the global lane early.
        executor.shutdown()
    }
}
