import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Les gros fichiers vivent déjà ailleurs dans le dépôt : on les recopie dans
// les assets au moment du build plutôt que de les dupliquer dans Git.
//   • réseaux NNUE  (75 Mo) ← ChessLab/Resources/
//   • modèle Maia3  (43 Mo) ← tools/maia3-spike/ (produit par convert_maia3_onnx.py)
//   • détecteur YOLO (10 Mo) ← tools/yolo-spike/ (produit par convert_yolo_onnx.py)
val generatedAssets = layout.buildDirectory.dir("generatedAssets")
val copyAssets by tasks.registering(Copy::class) {
    from(rootProject.file("../../ChessLab/Resources")) { include("nn-*.nnue") }
    from(rootProject.file("../maia3-spike")) {
        include("maia3_23m_fp16.onnx", "android_fixture.json")
    }
    from(rootProject.file("../yolo-spike")) {
        include("chess_pieces_yolo.onnx", "android_yolo_fixture.json", "*_640.png")
    }
    into(generatedAssets)
}

android {
    namespace = "com.chesslab.spike"
    compileSdk = 35
    ndkVersion = "27.2.12479018"

    defaultConfig {
        applicationId = "com.chesslab.spike"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1"
        // Le spike ne vise que les téléphones réels et l'émulateur Apple
        // Silicon : inutile de compiler Stockfish pour x86.
        ndk { abiFilters += listOf("arm64-v8a") }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    sourceSets["main"].assets.srcDir(generatedAssets)

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures { compose = true }
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

tasks.named("preBuild") { dependsOn(copyAssets) }

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.20.0")
}
