package com.example.siraj

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Flutter's Android entry point. Authentication crypto remains native and
 * independent of the UI and SQLite layers. */
class MainActivity : FlutterActivity() {
    private var secureSessionChannel: SirajSecureSessionChannel? = null
    private var downloadStorageChannel: SirajDownloadStorageChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        downloadStorageChannel?.dispose()
        secureSessionChannel?.dispose()
        downloadStorageChannel = SirajDownloadStorageChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        secureSessionChannel = SirajSecureSessionChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        downloadStorageChannel?.dispose()
        downloadStorageChannel = null
        secureSessionChannel?.dispose()
        secureSessionChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
