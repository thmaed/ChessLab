import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
    id("com.github.triplet.play")
}

// Les réseaux NNUE vivent déjà dans ChessLab/Resources/ : recopiés dans les
// assets au build plutôt que dupliqués dans Git (75 Mo).
val generatedAssets = layout.buildDirectory.dir("generatedAssets")
val copyAssets by tasks.registering(Copy::class) {
    from(rootProject.file("../ChessLab/Resources")) {
        include("nn-*.nnue")
        include("lichess_puzzles.json")
        include("openings/**")          // cours d'ouvertures ET de finales
        include("opponent_books.json")  // les répertoires des personnages
        include("opening_book.json")    // le livre d'ouvertures général
        include("opening_library.json") // les lignes qui étendent la théorie de l'analyse
    }
    // le modèle vit dans tools/, avec le script qui le produit
    from(rootProject.file("../tools/maia3-spike")) { include("maia3_23m_fp16.onnx") }
    from(rootProject.file("../tools/yolo-spike")) { include("chess_pieces_yolo.onnx") }
    into(generatedAssets)
}

// La signature de publication. Le trousseau ne vit PAS dans le dépôt : le
// fichier de propriétés est cherché dans ~/.chesslab-android/, puis dans
// android/keystore.properties (lui aussi ignoré par Git). Sans lui, le build
// release marche quand même — il sort simplement non signé, bon pour un essai
// local mais pas pour Google Play.
val keystoreProps = Properties().apply {
    listOf(
        File(System.getProperty("user.home"), ".chesslab-android/keystore.properties"),
        rootProject.file("keystore.properties"),
    ).firstOrNull { it.exists() }?.inputStream()?.use { load(it) }
}

// La clé du compte de service Google Play. Comme le trousseau de signature,
// elle ne vit PAS dans le dépôt : on la cherche dans ~/.private_keys/ — là où
// vit déjà la clé App Store Connect — puis dans android/, lui aussi ignoré.
val playCredentials = listOf(
    File(System.getProperty("user.home"), ".private_keys/play-service-account.json"),
    rootProject.file("play-service-account.json"),
).firstOrNull { it.exists() }

play {
    // Sans clé, le greffon se tait : `./gradlew build` marche pour qui n'a pas
    // à publier, et les tâches de publication disent pourquoi elles ne font
    // rien plutôt que d'échouer en énumérant des chemins.
    enabled.set(playCredentials != null)
    playCredentials?.let { serviceAccountCredentials.set(it) }

    // Un AAB, jamais un APK : Google Play n'accepte plus d'APK pour une app neuve.
    defaultToAppBundles.set(true)

    // On ne vise JAMAIS la production par défaut. Publier se demande
    // explicitement (`--track production`), et l'accès à la production
    // n'est de toute façon accordé qu'après le test fermé de 14 jours.
    track.set("internal")
    releaseStatus.set(com.github.triplet.gradle.androidpublisher.ReleaseStatus.COMPLETED)

}

android {
    namespace = "com.chesslab"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.chesslab"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1"
        ndk { abiFilters += listOf("arm64-v8a") }
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    sourceSets["main"].assets.srcDir(generatedAssets)

    signingConfigs {
        if (keystoreProps.getProperty("storeFile") != null) {
            create("release") {
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // R8 reste DÉSACTIVÉ : les ponts JNI et les modèles ONNX se
            // chargent par réflexion et par nom, et un obfuscateur mal réglé
            // les casse en silence — un plantage qui n'apparaîtrait qu'en
            // production. À rallumer un jour, avec des règles écrites et une
            // suite de tests passée sur le build release.
            isMinifyEnabled = false
            signingConfig = signingConfigs.findByName("release")
        }
        debug {
            // Un identifiant DISTINCT, pour que le build de test et le build
            // signé cohabitent sur le même téléphone.
            //
            // Sans lui, installer l'un chasse l'autre — les signatures
            // diffèrent, Android refuse la mise à jour — et la seule issue est
            // de DÉSINSTALLER, ce qui emporte la bibliothèque de parties et
            // toute la progression. Vérifier une capture sur le build signé
            // puis relancer la suite instrumentée devenait un choix entre les
            // deux. Chacun a désormais son bac à sable.
            applicationIdSuffix = ".debug"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures { compose = true }
}

kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }

// Les images de fixtures du scanner, déjà mises au format d'entrée par
// tools/yolo-spike, servent au test de bout en bout du scanner.
val testAssets = layout.buildDirectory.dir("testAssets")
val copyTestAssets by tasks.registering(Copy::class) {
    from(rootProject.file("../ChessLabTests/ScannerFixtures")) { include("*.png") }
    into(testAssets)
}
android.sourceSets["androidTest"].assets.srcDir(testAssets)

tasks.named("preBuild") { dependsOn(copyAssets, copyTestAssets) }

dependencies {
    implementation(project(":chesskit"))
    implementation(project(":engine"))
    implementation(project(":maia"))
    implementation(project(":vision"))

    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("androidx.datastore:datastore-preferences:1.1.1")
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")

    // Les tests JVM : FSRS et les files de révision sont du calcul pur, ils
    // n'ont rien à faire dans un émulateur.
    testImplementation("junit:junit:4.13.2")
    // `org.json` n'est qu'un TALON dans les tests JVM : chaque appel lève
    // « not mocked ». La vraie implémentation, elle, se comporte comme celle
    // d'Android — c'est ce qui permet de tester le format de transfert sans
    // émulateur.
    testImplementation("org.json:json:20240303")

    androidTestImplementation(platform("androidx.compose:compose-bom:2024.10.01"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
