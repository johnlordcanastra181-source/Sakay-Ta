import java.io.FileInputStream
import java.util.Properties

// Release signing credentials. Stored OUTSIDE version control
// (android/key.properties is git-ignored). When missing, release builds fall
// back to the debug signing key so `flutter run --release` keeps working.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}
val googleMapsApiKey =
    (localProperties.getProperty("GOOGLE_MAPS_API_KEY") ?: "").trim()

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase: applied only when the Android config from `flutterfire configure`
// (google-services.json) exists, so builds work before configuration too.
if (project.file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.example.sakay_ta"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.sakay_ta"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Signed with the upload keystore when key.properties is present,
            // otherwise with the debug key (so `flutter run --release` works).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            ndk {
                // FULL: strip native symbols from the APK (keeps it ~63 MB)
                // but export them for Play Console crash symbolication.
                debugSymbolLevel = "FULL"
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

tasks.matching { it.name.startsWith("compile") && it.name.endsWith("JavaWithJavac") }.configureEach {
    val javacTask = this
    rootProject.subprojects.forEach { subproject ->
        if (subproject.name != "app") {
            subproject.tasks.matching { it.name.startsWith("bundleLibCompileToJar") }.configureEach {
                javacTask.dependsOn(this)
            }
        }
    }
}
