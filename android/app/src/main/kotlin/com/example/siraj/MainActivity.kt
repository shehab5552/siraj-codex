package com.example.siraj

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Flutter's Android entry point. Authentication crypto remains native and
 * independent of the UI and SQLite layers. */
class MainActivity : FlutterActivity() {
    private var appearanceChannel: SirajAppearanceChannel? = null
    private var passwordKdfChannel: SirajPasswordKdfChannel? = null
    private var secureSessionChannel: SirajSecureSessionChannel? = null
    private var downloadStorageChannel: SirajDownloadStorageChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appearanceChannel?.dispose()
        passwordKdfChannel?.dispose()
        downloadStorageChannel?.dispose()
        secureSessionChannel?.dispose()
        appearanceChannel = SirajAppearanceChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        passwordKdfChannel = SirajPasswordKdfChannel(flutterEngine.dartExecutor.binaryMessenger)
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
        appearanceChannel?.dispose()
        appearanceChannel = null
        passwordKdfChannel?.dispose()
        passwordKdfChannel = null
        downloadStorageChannel?.dispose()
        downloadStorageChannel = null
        secureSessionChannel?.dispose()
        secureSessionChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
