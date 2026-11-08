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
    implementation("androidx.annotation:annotation:1.11.0")
    api(project(":chesskit"))
    // ONNX Runtime ÉPINGLÉ à 1.22.0 — ne pas « mettre à jour » sans remesurer (08/11/2026,
    // Galaxy A16, les 56 cas de tools/maia3-spike/android_fixture.json) : la 1.31.1 est
    // 2,5× PLUS LENTE (232 ms au lieu de 91 ms par coup de Maia) et moins fidèle (écart
    // max 0,0258 au lieu de 0,0026) ; la 1.24.3 n'ouvre même pas le modèle. Aucun niveau
    // d'optimisation de session n'y change rien.
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.22.0")
    testImplementation(kotlin("test"))
}
