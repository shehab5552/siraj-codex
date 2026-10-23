package com.example.siraj

import android.content.Context
import android.os.StatFs
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Real free-space probe, restricted to this application's private data tree. */
class SirajDownloadStorageChannel(context: Context, messenger: BinaryMessenger) {
    private val appDataPath = context.applicationInfo.dataDir
    private val channel = MethodChannel(messenger, "siraj/download_storage")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "availableBytes") {
                result.notImplemented()
            } else {
                try {
                    val appData = File(appDataPath).canonicalFile
                    val path = call.argument<String>("path")
                    val directory = path?.let { File(it).canonicalFile }
                    if (directory == null || !directory.isDirectory ||
                        !directory.path.startsWith(appData.path + File.separator)) {
                        result.error("storage_unavailable", "App-private directory required", null)
                    } else {
                        result.success(StatFs(directory.path).availableBytes)
                    }
                } catch (_: Exception) {
                    result.error("storage_unavailable", "Storage availability could not be read", null)
                }
            }
        }
    }

    fun dispose() { channel.setMethodCallHandler(null) }
}
