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

// `flutter build apk --target-platform android-arm64` still packs helper
// libraries of plugins for other processors. Keep only the requested ones.
val requestedAbis = (project.findProperty("target-platform") as String?)
    ?.split(',')
    ?.mapNotNull {
        when (it.trim()) {
            "android-arm64" -> "arm64-v8a"
            "android-arm" -> "armeabi-v7a"
            "android-x64" -> "x86_64"
            else -> null
        }
    }
    .orEmpty()

// SumUp affiliate key for card payments. KASSA_SUMUP_PROPERTIES names a
// properties file outside the repository with the line `affiliateKey=…`;
// tool/build_apk.sh sets it. Without the variable the key is empty and the
// app reports card payment as not set up. A variable that names a missing
// file stops the build: it must never silently build without card payment.
val sumUpPropertiesFile = System.getenv("KASSA_SUMUP_PROPERTIES")
    ?.takeIf { it.isNotBlank() }
    ?.let { file(it) }
if (sumUpPropertiesFile != null && !sumUpPropertiesFile.isFile) {
    throw GradleException("KASSA_SUMUP_PROPERTIES points to a missing file: $sumUpPropertiesFile")
}
val sumUpAffiliateKey = Properties().apply {
    sumUpPropertiesFile?.inputStream()?.use { load(it) }
}.getProperty("affiliateKey").orEmpty().trim()

val splitPerAbi = (project.findProperty("split-per-abi") as String?)?.toBoolean() ?: false

android {
    namespace = "io.github.n1kob1ko.kassa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // The SumUp SDK uses Java APIs that older Android versions lack.
        isCoreLibraryDesugaringEnabled = true
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "io.github.n1kob1ko.kassa"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // The SumUp SDK needs Android 8.0 or newer.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField(
            "String",
            "SUMUP_AFFILIATE_KEY",
            "\"" + sumUpAffiliateKey.replace("\\", "\\\\").replace("\"", "\\\"") + "\"",
        )
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

    // Native libraries are stored compressed inside the APK. The file handed
    // to a tester is then about half the size; Android unpacks the libraries
    // at install time.
    packaging {
        jniLibs {
            useLegacyPackaging = true
            if (requestedAbis.isNotEmpty() && !splitPerAbi) {
                listOf("arm64-v8a", "armeabi-v7a", "x86_64")
                    .filterNot { it in requestedAbis }
                    .forEach { excludes += "lib/$it/**" }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // The SumUp SDK leaves the versions of its Compose libraries to this list.
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("com.sumup:merchant-sdk:7.2.0")
}
