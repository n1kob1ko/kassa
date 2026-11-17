import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing for the installable release build. The key and its passwords live
// outside the repository; the environment variable KASSA_KEY_PROPERTIES names
// a properties file with storeFile (relative to that file), storePassword,
// keyAlias and keyPassword. tool/build_apk.sh sets it.
val keyPropertiesFile = System.getenv("KASSA_KEY_PROPERTIES")
    ?.takeIf { it.isNotBlank() }
    ?.let { file(it) }
if (keyPropertiesFile != null && !keyPropertiesFile.isFile) {
    throw GradleException("KASSA_KEY_PROPERTIES points to a missing file: $keyPropertiesFile")
}
val keyProperties = Properties().apply {
    keyPropertiesFile?.inputStream()?.use { load(it) }
}

android {
    namespace = "io.github.n1kob1ko.kassa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.n1kob1ko.kassa"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropertiesFile != null) {
            create("release") {
                storeFile = keyPropertiesFile.parentFile.resolve(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Without KASSA_KEY_PROPERTIES the release build falls back to the
            // debug key, so `flutter run --release` works on a developer
            // machine. Such a build must never be handed out: an update signed
            // with the real key cannot be installed over it.
            signingConfig = signingConfigs.getByName(
                if (keyPropertiesFile != null) "release" else "debug",
            )
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
