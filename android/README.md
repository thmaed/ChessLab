# ChessLab pour Android

Le portage de l'app iOS. Frère de `ChessLab/`, pas une réécriture : les
données, les modèles et les sources C++ sont les MÊMES fichiers, lus là où ils
sont déjà.

## Structure

```
android/
├── chesskit/   les règles du jeu en Kotlin — JVM PUR, testable sans émulateur
├── engine/     Stockfish et Fairy-Stockfish au NDK, ponts JNI
├── maia/       Maia-3 (ONNX) et les neuf personnages
├── vision/     le scanner : homographie, YOLO, lecture de la grille
└── app/        l'application Compose
```

Rien n'est dupliqué. Le `CMakeLists` pointe sur `Vendor/CStockfish` et
`Vendor/CFairyStockfish` comme le projet Xcode ; les réseaux NNUE, les puzzles,
les cours d'ouvertures et de finales et les répertoires des personnages sont
recopiés depuis `ChessLab/Resources/` au moment du build.

## Ce qui marche

| | |
| --- | --- |
| Contre l'ordinateur | les neuf personnages (Maia-3) ou Stockfish, niveau réglable |
| Deux joueurs | sur le même appareil, plateau qui se retourne |
| Puzzles | les 106 094 puzzles Lichess, lus en flux |
| Ouvertures | 58 cours, chapitres, commentaires, statistiques |
| Finales | 78 cours, même lecteur |
| Analyser | PGN et FEN, navigation, évaluation du moteur, bibliothèque |
| Laboratoire | l'ordinateur contre lui-même, en série |
| Variantes | Chess960, Roi de la colline, Trois échecs, Horde, Course des rois, Atomique, Antichecs |
| Scanner | lire une position sur une photo (cadrage manuel) |
| Réglages | quatre thèmes, trois jeux de pièces, force du moteur |
| Bibliothèque | les parties terminées, enregistrées et rejouables |
| Entraîner | répétition espacée FSRS-5 : séance du jour, positions à consolider, une ligne |

## Ce qui reste

- **La mesure sur un vrai téléphone.** L'émulateur ne dit rien de la vitesse ni
  du thermique — et c'est de là que dépend la calibration des niveaux.
- La détection automatique du plateau dans le scanner (le cadrage est manuel).
- L'anglais : l'interface est en français seulement.
- Les mises en page tablette et paysage.
- La synchronisation entre appareils (iOS passe par CloudKit ; côté Android le
  journal de révisions est déjà écrit pour fusionner, mais rien ne le transporte).

## Construire et tester

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
./gradlew :chesskit:test                  # les règles : 10 s, sans émulateur
./gradlew :app:testDebugUnitTest          # FSRS et les files de révision, sans émulateur
./gradlew :maia:testDebugUnitTest         # l'encodeur, prouvé au bit près
./gradlew :vision:testDebugUnitTest       # homographie et lecture de grille
./gradlew :app:connectedDebugAndroidTest  # 31 cas de bout en bout, sur appareil
./gradlew :app:assembleDebug
```

**La boucle de travail est la JVM.** Les règles, l'encodeur Maia et la vision
se testent sur la machine en quelques secondes ; seule l'interface demande un
appareil.

## Deux artefacts non versionnés

`tools/maia3-spike/maia3_23m_fp16.onnx` (43 Mo) et
`tools/yolo-spike/chess_pieces_yolo.onnx` (10 Mo) sont produits par leurs
scripts de conversion et ignorés par Git. Sans eux, l'app se construit quand
même : les personnages laissent la place à Stockfish et le scanner le dit.

## Taille

APK de débogage : ~170 Mo — réseaux NNUE 75, Maia 43, puzzles 19, ONNX Runtime
17, cours 4, YOLO 10. Sous le plafond de Google Play (~200 Mo sans Play Asset
Delivery), mais SANS MARGE : c'est la première décision d'architecture à
trancher avant une publication — tout embarquer, ou télécharger les gros
réseaux au premier lancement.
