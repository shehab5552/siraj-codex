plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingValues = listOf("SIRAJ_KEYSTORE_PATH", "SIRAJ_KEYSTORE_PASSWORD", "SIRAJ_KEY_ALIAS", "SIRAJ_KEY_PASSWORD")
    .map { System.getenv(it)?.takeIf(String::isNotBlank) }
require(signingValues.all { it == null } || signingValues.all { it != null }) {
    "Supply all four SIRAJ signing environment variables, or none for an unsigned release."
}

android {
    namespace = "com.example.siraj"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        // Both normal debug and unsigned evaluation release are isolated from
        // any original SIRAJ installation. Production identity is a separate gate.
        applicationId = "com.example.siraj.unifiedtest"
        // PBKDF2WithHmacSHA256 requires Android API 26 or later.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (signingValues.all { it != null }) {
            create("sirajRelease") {
                storeFile = file(signingValues[0]!!)
                storePassword = signingValues[1]
                keyAlias = signingValues[2]
                keyPassword = signingValues[3]
            }
        }
    }
    buildTypes {
        release {
            // Never silently sign a release with the Android debug key.
            signingConfig = signingConfigs.findByName("sirajRelease")
        }
    }
}
flutter { source = "../.." }
