plugins {
    alias(libs.plugins.android.application)
    // AGP 9.x auto-applies kotlin-android when it detects a Kotlin source
    // set, so we don't apply it explicitly — applying both gives a
    // duplicate "kotlin" extension error.
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.secrets.gradle)
}

android {
    namespace = "fi.eport.searchassistant"
    compileSdk = 36

    defaultConfig {
        applicationId = "fi.eport.searchassistant"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // Optional release signing — looks for app/release.keystore at build
    // time and reads passwords from local.properties via the secrets-
    // gradle-plugin (RELEASE_STORE_PASSWORD / RELEASE_KEY_PASSWORD /
    // RELEASE_KEY_ALIAS). When the keystore is missing (debug-only dev
    // workflow), the release build falls back to the debug keystore so
    // `./gradlew bundleRelease` still produces an installable AAB.
    signingConfigs {
        val releaseKeystore = file("release.keystore")
        if (releaseKeystore.exists()) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = providers.gradleProperty("RELEASE_STORE_PASSWORD").orNull
                keyAlias = providers.gradleProperty("RELEASE_KEY_ALIAS").orNull ?: "release"
                keyPassword = providers.gradleProperty("RELEASE_KEY_PASSWORD").orNull
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false  // flip on once ProGuard rules are tuned
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

kotlin {
    // Match the Android Studio JBR. Bytecode is still emitted at the
    // Java-17 level via compileOptions above.
    jvmToolchain(21)
}

// Google's secrets-gradle-plugin: injects values from local.properties into
// BuildConfig + Manifest placeholders. We only need MAPS_API_KEY.
secrets {
    propertiesFileName = "local.properties"
    defaultPropertiesFileName = "local.properties.sample"
}

dependencies {
    // Core / lifecycle / compose foundation
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)

    // Coroutines + serialization
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.coroutines.play.services)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.datetime)

    // Networking
    implementation(libs.retrofit.core)
    implementation(libs.retrofit.kotlinx.serialization)
    implementation(libs.okhttp.core)
    implementation(libs.okhttp.logging)

    // SignalR
    implementation(libs.signalr)

    // Google Maps + location
    implementation(libs.maps.compose)
    implementation(libs.play.services.maps)
    implementation(libs.play.services.location)

    // QR generation (ShareSheet)
    implementation(libs.zxing.android.embedded)

    // Tests
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit.ext)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
}
