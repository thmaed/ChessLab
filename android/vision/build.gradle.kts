plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.chesslab.vision"
    compileSdk = 35
    defaultConfig { minSdk = 26 }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // L'homographie, la NMS et l'assemblage de FEN sont de la logique pure :
    // testés sur JVM, sans appareil.
    testOptions.unitTests.all {
        it.useJUnitPlatform()
        it.testLogging { events("passed", "failed"); showStandardStreams = true }
    }
}

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

dependencies {
    api(project(":chesskit"))
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.22.0")
    testImplementation(kotlin("test"))
}
