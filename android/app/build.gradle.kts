plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

// A release must use an explicitly supplied, retained signing identity. Never fall back to
// the per-run debug.keystore: that produces APKs that cannot update prior installations.
val companyStore = System.getenv("SAUNA_SIGNING_STORE")
val companyPassword = System.getenv("SAUNA_SIGNING_PASSWORD")
val companyAlias = System.getenv("SAUNA_SIGNING_ALIAS")
val hasCompanySigning = !companyStore.isNullOrBlank() &&
    !companyPassword.isNullOrBlank() && !companyAlias.isNullOrBlank()

gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release", ignoreCase = true) } && !hasCompanySigning) {
        throw GradleException("Release APK blocked: configure the retained Sauna Stilo signing key. A new debug key is not an update-compatible replacement.")
    }
}

android {
    namespace = "com.saunastylo.saunastylo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        // Legacy identity. Do not sign this ID with the recovery edition's new key.
        // Recovery com.saunastilo.personal is a separate install, not a legacy update.
        applicationId = "com.saunastylo.saunastylo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (hasCompanySigning) {
            create("companyRelease") {
                storeFile = file(companyStore!!)
                storePassword = companyPassword
                keyAlias = companyAlias
                keyPassword = companyPassword
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("companyRelease")
        }
    }
}
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
flutter { source = "../.." }
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
