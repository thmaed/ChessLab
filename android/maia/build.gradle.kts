plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.chesslab.maia"
    compileSdk = 35
    defaultConfig { minSdk = 26 }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // L'encodeur et la table de coups sont de la logique PURE : leurs tests
    // tournent sur la JVM, sans émulateur, contre les mêmes fixtures que l'app
    // iOS. Seul le modèle lui-même demande Android.
    testOptions.unitTests.all {
        it.useJUnitPlatform()
        it.testLogging { events("passed", "failed", "skipped"); showStandardStreams = true }
    }
}

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

dependencies {
    // @StringRes : les personnages portent des ressources, pas des chaînes.
    implementation("androidx.annotation:annotation:1.9.1")
    api(project(":chesskit"))
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.22.0")
    testImplementation(kotlin("test"))
}
