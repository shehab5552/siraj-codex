package com.example.siraj

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/** Non-secret, device-scoped appearance only, excluded by app backup policy. */
internal class SirajAppearanceChannel(context: Context, messenger: BinaryMessenger) {
    private val preferences = context.getSharedPreferences("siraj_appearance_v1", Context.MODE_PRIVATE)
    private val channel = MethodChannel(messenger, "siraj/appearance", StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "read" -> result.success(mapOf(
                        "language" to preferences.getString("language", "ar"),
                        "theme" to preferences.getString("theme", "system"),
                        "onboarding" to preferences.getBoolean("onboarding", false),
                    ))
                    "write" -> {
                        val language = call.argument<String>("language")
                        val theme = call.argument<String>("theme")
                        val onboarding = call.argument<Boolean>("onboarding")
                        if (language !in listOf("ar", "en") || theme !in listOf("system", "light", "dark") || onboarding == null) {
                            result.error("PREFERENCES_INVALID", null, null)
                        } else if (preferences.edit().putString("language", language).putString("theme", theme).putBoolean("onboarding", onboarding).commit()) {
                            result.success(null)
                        } else result.error("PREFERENCES_WRITE_FAILED", null, null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("PREFERENCES_UNAVAILABLE", null, null) }
        }
    }
    fun dispose() { channel.setMethodCallHandler(null) }
}
