import java.security.MessageDigest
import java.util.zip.ZipFile
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.TaskAction

plugins { id("com.android.library") }

android {
    namespace = "com.example.siraj.ai_runtime"
    // Matches the pinned Flutter3.38.5 Android SDK values.
    compileSdk = 36
    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

val runtimeCoordinate = "com.google.ai.edge.litertlm:litertlm-android:0.19.0"
val runtimeIdentity by configurations.creating {
    isCanBeConsumed = false
    isTransitive = false
}

dependencies {
    // Deliberately implementation, never api: only plain Java facade types
    // cross this module boundary. The real Maven POM supplies runtime deps.
    implementation(runtimeCoordinate)
    runtimeIdentity("$runtimeCoordinate@aar")
}

val verifyRuntimeIdentity by tasks.registering {
    inputs.files(runtimeIdentity)
    doLast {
        val artifact = runtimeIdentity.singleFile
        val digest = MessageDigest.getInstance("SHA-256")
        artifact.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        val sha256 = digest.digest().joinToString("") { "%02x".format(it) }
        check(artifact.length() == 21197249L &&
            sha256 == "e5c7a86048225efba8ab6d35fcd91f5870c86c65ca2538c07c3c1f63d02efa2b") {
            "LiteRT-LM0.19.0 artifact identity mismatch"
        }
    }
}

tasks.named("preBuild").configure { dependsOn(verifyRuntimeIdentity) }

// Preserve the verified SDK's redistribution notices in the resulting APK.
// These generated text assets never enter Git and contain no model weights.
abstract class RuntimeNoticesTask : DefaultTask() {
    @get:InputFile abstract val runtimeAar: RegularFileProperty
    @get:OutputDirectory abstract val outputDirectory: DirectoryProperty
    @TaskAction fun generate() {
        val output = outputDirectory.get().dir("licenses/litertlm-android-0.19.0").asFile
        check(output.mkdirs() || output.isDirectory)
        ZipFile(runtimeAar.get().asFile).use { archive ->
            for ((name, destination) in mapOf(
                "LICENSE" to "LICENSE.txt",
                "THIRD_PARTY_NOTICE.txt" to "THIRD_PARTY_NOTICE.txt",
            )) {
                val entry = checkNotNull(archive.getEntry(name)) { "Runtime notice missing: $name" }
                archive.getInputStream(entry).use { input ->
                    output.resolve(destination).outputStream().use { input.copyTo(it) }
                }
            }
        }
    }
}
val generateRuntimeNotices = tasks.register<RuntimeNoticesTask>("generateRuntimeNotices") {
    dependsOn(verifyRuntimeIdentity)
    runtimeAar.set(layout.file(providers.provider { runtimeIdentity.singleFile }))
    outputDirectory.set(layout.buildDirectory.dir("generated/runtime-notices"))
}
// AGP's generated-source API registers both the real directory and its producer
// for every variant/consumer, including lint, AAR packaging and APK asset merge.
androidComponents.onVariants { variant ->
    variant.sources.assets?.addGeneratedSourceDirectory(
        generateRuntimeNotices, RuntimeNoticesTask::outputDirectory,
    )
}
