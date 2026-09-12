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

## La ressemblance avec iOS

Le portage ne reprend pas seulement les fonctions : il reprend la FORME, écran
par écran, depuis les sources SwiftUI et les captures de la soumission App
Store. Le fond signature (`AppBackground`), les pastilles d'icône, les cartes
à bordure teintée, les en-têtes de section, les puces, les lignes joueurs, les
tuiles de mode — tout vient de `ChessLab/Theme.swift` et de ses vues, avec les
mêmes valeurs.

Deux conséquences à connaître avant de toucher au code :

- **Une partie se prépare.** Accueil → Nouvelle partie (couleur, adversaire,
  niveau, cadence, aides) → Jouer. Il n'y a pas de raccourci vers le plateau.
- **Les neuf personnages ont des illustrations**, recopiées des assets iOS par
  `tools/android-assets/copy_images.py`. Leur teinte est celle de l'avatar, pas
  une couleur de la palette.

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
| Pendule | bullet, blitz, rapide, classique, avec incrément |
| Abandon, nulle, indice | et la consultation d'un coup passé |
| Scanner | lire une position sur une photo, plateau détecté tout seul |
| Réglages | quatre thèmes, trois jeux de pièces, force du moteur |
| Paysage | plateau et panneau côte à côte, sur téléphone comme sur tablette |
| Deux langues | français et anglais, décor ET contenu des cours ; réglage dans l'app |
| Bibliothèque | les parties terminées, enregistrées et rejouables |
| Entraîner | répétition espacée FSRS-5 : séance du jour, positions à consolider, une ligne |

## Ce qui reste

- **Crazyhouse.** Fairy-Stockfish la connaît, mais elle demande de parachuter
  les pièces prises : il y faut une réserve et un geste de pose. Sans eux, le
  moteur jouerait des coups que l'utilisateur ne pourrait pas rendre.
- **La mesure sur un vrai téléphone.** L'émulateur ne dit rien de la vitesse ni
  du thermique — et c'est de là que dépend la calibration des niveaux.
- La synchronisation entre appareils (iOS passe par CloudKit ; côté Android le
  journal de révisions est déjà écrit pour fusionner, mais rien ne le transporte).

## Construire et tester

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
./gradlew :chesskit:test                  # les règles : 10 s, sans émulateur
./gradlew :app:testDebugUnitTest          # FSRS et les files de révision, sans émulateur
./gradlew :maia:testDebugUnitTest         # l'encodeur, prouvé au bit près
./gradlew :vision:testDebugUnitTest       # homographie et lecture de grille
./gradlew :app:connectedDebugAndroidTest  # 40 cas de bout en bout, sur appareil
./gradlew :app:assembleDebug
```

**La boucle de travail est la JVM.** Les règles, l'encodeur Maia et la vision
se testent sur la machine en quelques secondes ; seule l'interface demande un
appareil.

## Les deux langues

L'anglais est la langue PAR DÉFAUT (`res/values/`), le français vit dans
`res/values-fr/` — un téléphone réglé sur une langue qu'on ne traduit pas
retombe ainsi sur l'anglais plutôt que sur du français incompris. Le français
reste la langue D'ÉCRITURE : traduire, c'est partir de lui.

- `app/src/main/res/values{,-fr}/strings_app.xml` — le décor, 295 clés.
- `maia/src/main/res/values{,-fr}/strings.xml` — les neuf personnages,
  **générés** avec `OpponentGallery.kt` par
  `tools/maia-profiles/generate_profiles.py`, qui va chercher l'anglais dans
  `ChessLab/Localizable.xcstrings` : l'app iOS l'avait déjà traduit.
- Le CONTENU des cours (noms, résumés, commentaires) porte ses deux langues
  dans ses propres fichiers JSON ; `CourseRepository` lit celle du moment.

Le choix se fait dans les Réglages (Système / Français / English). Sur Android
13 et au-delà il passe par le réglage système « langue de l'application », ce
qui fait aussi apparaître ChessLab dans la liste des Réglages ; en dessous,
l'activité enveloppe son contexte elle-même.

Les tests d'interface tournent en FRANÇAIS, langue fixée par `LanguageRule`
avant que l'activité démarre : sans elle, les mêmes assertions passeraient sur
une machine et échoueraient sur une autre. `EnglishTest` couvre l'anglais,
personnages et contenu des cours compris.

## Deux artefacts non versionnés

`tools/maia3-spike/maia3_23m_fp16.onnx` (43 Mo) et
`tools/yolo-spike/chess_pieces_yolo.onnx` (10 Mo) sont produits par leurs
scripts de conversion et ignorés par Git. Sans eux, l'app se construit quand
même : les personnages laissent la place à Stockfish et le scanner le dit.

## Taille et publication

| | compressé | brut |
| --- | --- | --- |
| Réseau NNUE principal | 61,7 Mo | 74,9 Mo |
| Maia-3 (ONNX fp16) | 41,8 Mo | 45,5 Mo |
| Détecteur YOLO | 9,2 Mo | 10,6 Mo |
| ONNX Runtime | 6,3 Mo | 17,6 Mo |
| Puzzles Lichess | 4,7 Mo | 18,8 Mo |
| Moteurs (Stockfish, Fairy) | 6,2 Mo | 24,3 Mo |
| **Bundle complet** | **145,6 Mo** | 243,7 Mo |

C'est la taille COMPRESSÉE qui compte pour Google Play, dont le plafond est
d'environ 200 Mo sans Play Asset Delivery : on passe, sans marge confortable.
Sur l'appareil, compter en plus les 78 Mo de réseaux NNUE extraits — Stockfish
veut de vrais fichiers, et les assets Android n'en sont pas.

### Signer

Le trousseau ne vit PAS dans le dépôt. Le build cherche un
`keystore.properties` dans `~/.chesslab-android/`, puis dans
`android/keystore.properties` (ignoré par Git) :

```properties
storeFile=/chemin/vers/chesslab-release.jks
storePassword=…
keyAlias=chesslab
keyPassword=…
```

Sans lui, `assembleRelease` sort un APK NON SIGNÉ : bon pour un essai local,
refusé par Google Play.

```bash
./gradlew :app:bundleRelease   # l'AAB à téléverser
./gradlew :app:assembleRelease # l'APK, pour installer à la main
```

R8 reste désactivé : les ponts JNI et les modèles se chargent par nom, et un
obfuscateur mal réglé les casse en silence — un plantage qui n'apparaîtrait
qu'en production.
