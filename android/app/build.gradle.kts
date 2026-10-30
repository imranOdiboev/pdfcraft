import java.security.MessageDigest
import java.util.zip.ZipFile

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.odibo.pdf"
    compileSdk = 36
    buildToolsVersion = "35.0.0"
    ndkVersion = "30.0.16248370"
    defaultConfig {
        applicationId = "com.odibo.pdf"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0-debug"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk { abiFilters += (providers.gradleProperty("odiboAbi").orNull ?: "arm64-v8a") }
    }
    buildFeatures { compose = true; buildConfig = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    sourceSets {
        getByName("main") {
            res.srcDir(layout.buildDirectory.dir("generated/odibo/res"))
            assets.srcDir(layout.buildDirectory.dir("generated/odibo/assets"))
            assets.srcDir(layout.buildDirectory.dir("generated/dependencyNotices"))
            jniLibs.srcDir(layout.buildDirectory.dir("generated/odibo/jniLibs"))
        }
    }
    packaging {
        // The private helper is an executable PIE, installed in the code directory.
        // It is never copied to writable app data or loaded through JNI.
        jniLibs { useLegacyPackaging = true; keepDebugSymbols += "**/libodibo_core_exec.so" }
        resources.merges += setOf("META-INF/LICENSE", "META-INF/NOTICE")
    }
    lint { abortOnError = true; checkReleaseBuilds = true }
    testOptions { unitTests.isReturnDefaultValues = false }
}
kotlin { jvmToolchain(17) }

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.10.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3:1.4.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.4")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.9.4")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}

// Inventory resolved Android inputs, including actual archive digests. No plugin
// or telemetry service is needed. Preserve licence/notice files found in AAR/JARs.
tasks.register("collectAndroidNotices") {
    // Own a separate output directory: Gradle may clean task outputs before
    // execution. Never claim the pre-staged upstream/brand/font legal directory.
    val destination = layout.buildDirectory.dir("generated/dependencyNotices/legal")
    outputs.dir(destination)
    doLast {
        val dir = destination.get().asFile.apply { mkdirs() }
        val output = StringBuilder("ODIBO PDF Android 0.1 Android dependencies\n")
        configurations.getByName("debugRuntimeClasspath").resolvedConfiguration.resolvedArtifacts
            .sortedBy { it.moduleVersion.id.toString() }.forEach { artifact ->
                val hash = MessageDigest.getInstance("SHA-256").digest(artifact.file.readBytes())
                    .joinToString("") { "%02x".format(it) }
                output.append("\n${artifact.moduleVersion.id}\nSHA-256: $hash\n")
                ZipFile(artifact.file).use { zip ->
                    zip.entries().asSequence().filter { !it.isDirectory &&
                        it.name.startsWith("META-INF/") &&
                        Regex("(?i).*(LICENSE|NOTICE|COPYING).*").matches(it.name)
                    }.forEach { entry ->
                        output.append("\n${entry.name}\n")
                        zip.getInputStream(entry).bufferedReader().use { output.append(it.readText()) }
                        output.append("\n")
                    }
                }
            }
        dir.resolve("ANDROID_DEPENDENCIES.txt").writeText(output.toString())
        val common = dir.resolve("THIRD_PARTY_NOTICES.txt")
        val rust = layout.buildDirectory.file("generated/odibo/assets/legal/RUST_DEPENDENCIES.txt")
            .get().asFile.readText()
        common.writeText("Dependency inventory and preserved licence texts\n\n" + output + "\n" + rust)
    }
}
tasks.named("preBuild") { dependsOn("collectAndroidNotices") }
