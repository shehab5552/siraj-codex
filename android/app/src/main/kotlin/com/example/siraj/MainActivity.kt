package com.example.siraj

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Flutter's Android entry point. Authentication crypto remains native and
 * independent of the UI and SQLite layers. */
class MainActivity : FlutterActivity() {
    private var secureSessionChannel: SirajSecureSessionChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        secureSessionChannel = SirajSecureSessionChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        secureSessionChannel?.dispose()
        secureSessionChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
