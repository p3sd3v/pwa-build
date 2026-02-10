plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    val packageName = System.getenv("PACKAGENAME") ?: "com.example.pwa_build"
    val appName = System.getenv("APPNAME") ?: "PWA Build"
    val schemeDynamicLink =  System.getenv("SCHEME_DYNAMIC_LINK") ?: "pwabuild"
    val hostDynamicLink = System.getenv("HOST_DYNAMIC_LINK") ?: "pwabuild"
    val branchIoKeyLive = System.getenv("BRANCH_IO_KEY_LIVE") ?: "key_live"
    val branchIoKeyTest = System.getenv("BRANCH_IO_KEY_TEST") ?: "key_test"

    namespace = packageName
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // default values
        applicationId = packageName // Set default applicationId to packageName
        
        resValue(type = "string", name = "scheme", value = schemeDynamicLink)
        resValue(type = "string", name = "app_link", value = "${hostDynamicLink}.app.link")
        resValue(type = "string", name = "app_link_alternate", value = "${hostDynamicLink}-alternate.app.link")
        resValue(type = "string", name = "app_link_test", value = "${hostDynamicLink}.test-app.link")
        resValue(type = "string", name = "key_live", value = branchIoKeyLive)
        resValue(type = "string", name = "key_test", value = branchIoKeyTest)
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions("flavor-type")

    productFlavors {
        create("dev") {
            dimension = "flavor-type"
            applicationId = "${packageName}.dev"
            resValue(type = "string", name = "app_name", value = "${appName} Dev")
            resValue(type = "bool", name = "branch_test", value = "true")
        }
        create("hml") {
            dimension = "flavor-type"
            applicationId = "${packageName}.hml"
            resValue(type = "string", name = "app_name", value = "${appName} HML")
            resValue(type = "bool", name = "branch_test", value = "true")
        }
        create("prod") {
            dimension = "flavor-type"
            applicationId = packageName
            resValue(type = "string", name = "app_name", value = appName)
            resValue(type = "bool", name = "branch_test", value = "false")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
