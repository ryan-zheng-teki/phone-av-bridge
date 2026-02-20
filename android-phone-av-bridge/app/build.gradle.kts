plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.android")
}

val ciKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
val ciKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val ciKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
val ciKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
val ciReleaseSigningEnabled = listOf(
  ciKeystorePath,
  ciKeystorePassword,
  ciKeyAlias,
  ciKeyPassword,
).all { !it.isNullOrBlank() }

android {
  namespace = "org.autobyteus.phoneavbridge"
  compileSdk = 35

  defaultConfig {
    applicationId = "org.autobyteus.phoneavbridge"
    minSdk = 30
    targetSdk = 35
    versionCode = 2
    versionName = "0.1.1"

    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
  }

  signingConfigs {
    if (ciReleaseSigningEnabled) {
      create("ciRelease") {
        storeFile = file(ciKeystorePath!!)
        storePassword = ciKeystorePassword
        keyAlias = ciKeyAlias
        keyPassword = ciKeyPassword
      }
    }
  }

  buildTypes {
    release {
      isMinifyEnabled = false
      proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro",
      )
      if (ciReleaseSigningEnabled) {
        signingConfig = signingConfigs.getByName("ciRelease")
      }
    }
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
  kotlinOptions {
    jvmTarget = "17"
  }
}

dependencies {
  implementation("androidx.core:core-ktx:1.13.1")
  implementation("androidx.appcompat:appcompat:1.7.0")
  implementation("com.google.android.material:material:1.12.0")
  implementation("androidx.constraintlayout:constraintlayout:2.1.4")
  implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.4")
  implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
  implementation("com.journeyapps:zxing-android-embedded:4.3.0")
  implementation("com.github.pedroSG94:RTSP-Server:1.2.8")
  implementation("com.github.pedroSG94.RootEncoder:library:2.4.5")

  testImplementation("junit:junit:4.13.2")
  testImplementation("org.jetbrains.kotlin:kotlin-test:1.9.24")

  androidTestImplementation("androidx.test.ext:junit:1.2.1")
  androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
}
