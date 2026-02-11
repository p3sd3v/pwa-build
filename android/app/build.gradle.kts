plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.wedev.pwa_build"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.wedev.pwa_build"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }


    buildTypes {
        getByName("release") {
            isDebuggable = false
        }
    }
    flavorDimensions("default")

    productFlavors {
        create("dev") {
            dimension = "default"
            applicationIdSuffix = ".dev" // O pacote será com.exemplo.app.dev
            resValue(type="string", name="app_name", value=System.getenv("APPNAME")?: "App Dev")
        }
        create("prod") {
            applicationIdSuffix = System.getenv("FLAVOR")?: "prod"
            // Mantém o applicationId original (com.exemplo.app)
            resValue(type="string", name="app_name", value=System.getenv("APPNAME")?: "App Oficial")
        }
    }
}

flutter {
    source = "../.."
}
