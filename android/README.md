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
- **« Changer de mode » est le lien transversal de l'app**, comme
  `QuickSwitchMenu.swift` : un bouton dans la barre du haut, qui emporte la
  POSITION AFFICHÉE vers un autre grand mode. Il est sur Jouer, Deux joueurs,
  Analyser, Puzzles, Entraîner, les lecteurs de cours, les listes d'ouvertures
  et de finales, et les variantes (analyse seule — les autres modes jouent aux
  règles orthodoxes). Les écrans ne peuvent pas écrire dans la barre du haut,
  qui est composée au-dessus d'eux : ils s'y inscrivent par `TopBarActions` et
  s'en retirent en partant.

## Ce qui marche

| | |
| --- | --- |
| Contre l'ordinateur | les neuf personnages (Maia-3) ou Stockfish, niveau réglable |
| Deux joueurs | sur le même appareil, plateau qui se retourne |
| Puzzles | les 106 094 puzzles Lichess, lus en flux |
| Ouvertures | 58 cours, chapitres, commentaires, statistiques |
| Finales | 78 cours, même lecteur |
| Analyser | PGN et FEN, ouverture nommée (ECO), flèches du moteur, coups candidats |
| Revue de partie | chaque coup classé, précision par joueur, courbe d'évaluation |
| Bandeau coach | « e5 — Erreur, −12 % », et CE QUI punit le coup, en une phrase |
| Puzzles maison | tirés de vos propres fautes, à côté des puzzles Lichess |
| Changer de mode | la position affichée s'emporte vers un autre mode, depuis huit écrans |
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

## L'analyse d'une partie

Tout le barème vient d'iOS, à la constante près — et les fonctions qui le
portent sont PURES, donc vérifiées sur la JVM sans émulateur
(`ClassificationTest`, `TrimmerTest`, `ThreatTest`).

- **Classer un coup** se fait sur la PROBABILITÉ DE GAIN et non sur les
  centipions : à +8, lâcher 300 cp ne change rien ; à 0.00, c'est décisif. Le
  barème est celui d'iOS — Excellent sous 2 %, Bon coup 2-5 %, Imprécision
  5-10 %, Erreur 10-20 %, Gaffe au-delà.
- **La précision** est la courbe de Lichess appliquée à une moyenne PONDÉRÉE
  par la volatilité de la position. Sans cette pondération, vingt coups de
  finition dans une partie déjà gagnée gonflent le score de plusieurs points
  sans que rien n'ait été mieux joué.
- **L'explication d'une faute** est lue sur la RÉFUTATION du moteur, rejouée
  sur un plateau : mat du couloir, fourchette, clouage, pièce en prise. Aucun
  modèle de langage n'entre là — dans une app d'apprentissage, une explication
  inventée s'apprend aussi bien qu'une vraie.
- **Le budget de recherche est en NŒUDS** (300 000 par position, 900 000 pour
  une solution de puzzle) et non en temps : un budget en temps rendrait le
  verdict dépendant de la charge de l'appareil, et la même partie analysée deux
  fois donnerait deux réponses.

## Le moteur ne se laisse plus abandonner à mi-démarrage

`EngineService.start()` tourne désormais sous `NonCancellable`. Sans ça,
quitter un écran PENDANT le démarrage annulait la tâche entre `e.start()` —
qui a déjà lancé le moteur natif — et l'affectation d'`engine`. Le moteur
restait vivant sans propriétaire ; or Stockfish n'en accepte qu'UN par
process, si bien que toute demande suivante se voyait refuser, `failed`
passait à vrai, et l'app annonçait « moteur indisponible » **pour le reste de
la session**.

Trouvé en analysant une partie juste après l'avoir chargée : la revue rendait
zéro évaluation, et le bilan s'affichait vide au lieu de dire qu'il avait
échoué. C'est le pendant Android des six mécanismes de panne moteur corrigés
côté iOS fin août.

## Deux bugs de ChessKit corrigés dans le port

**1. Un plateau construit sur une position finie se croyait actif.**
`Board(position)`, sans qu'aucun coup n'y ait été joué, se déclarait actif sur
une position de MAT, et pouvait annoncer un échec sur le camp qui venait de
mater : `updateState()` prenait le camp AU TRAIT là où il faut celui qui vient
de jouer. Visible dans l'analyse — le roi maté n'était pas surligné, et le coup
de mat était classé sur une évaluation absente, donc noté « occasion manquée ».

**2. `Board` écrivait dans la position de l'appelant.** Le constructeur gardait
la position PAR RÉFÉRENCE, et jouer dessus la modifiait chez celui qui l'avait
passée. L'original Swift est une `struct` — la copie y est gratuite, le port
l'a perdue en route. Conséquence mesurée : le détecteur de motifs rejoue la
réfutation du moteur sur la position d'après un coup fautif, et écrasait au
passage la liste des positions de la partie. Les coups suivants étaient alors
classés sur des positions qui n'étaient pas les leurs — un mat noté
« excellent », et des précisions fausses sans que rien ne le signale.

Les deux sont corrigés dans `chesskit/Board.kt` et prouvés par
`BoardStateTest` / `BoardIsolationTest` (les tests échouent si on retire le
correctif — vérifié). **Les deux sont dans ChessKit en amont**, Swift comme
Kotlin : à signaler, avec les trois autres déjà relevés.

## Ce qui reste

- **Crazyhouse.** Fairy-Stockfish la connaît, mais elle demande de parachuter
  les pièces prises : il y faut une réserve et un geste de pose. Sans eux, le
  moteur jouerait des coups que l'utilisateur ne pourrait pas rendre.
- **La mesure sur un vrai téléphone.** L'émulateur ne dit rien de la vitesse ni
  du thermique — et c'est de là que dépend la calibration des niveaux.
- **Les écrans d'analyse annexes d'iOS** : l'éditeur de tags PGN et la
  bibliothèque de parties détaillée. L'analyse elle-même est à parité.

## Construire et tester

Pour publier, voir `PUBLIER.md` — le chemin complet jusqu'au Play Store.

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
./gradlew :chesskit:test                  # les règles : 10 s, sans émulateur
./gradlew :app:testDebugUnitTest          # FSRS et les files de révision, sans émulateur
./gradlew :maia:testDebugUnitTest         # l'encodeur, prouvé au bit près
./gradlew :vision:testDebugUnitTest       # homographie et lecture de grille
./gradlew :app:connectedDebugAndroidTest  # 59 cas de bout en bout, sur appareil
./gradlew :app:assembleDebug
```

**La boucle de travail est la JVM.** Les règles, l'encodeur Maia et la vision
se testent sur la machine en quelques secondes ; seule l'interface demande un
appareil.

## Le transfert entre appareils

Pas de compte, pas de serveur : un fichier `.clab` que l'utilisateur écrit où
il veut (Réglages › Transfert entre appareils) et rouvre où il veut. C'est la
seule forme de synchronisation compatible avec ce que l'aide promet — rien ne
part sans qu'on l'ait demandé.

**L'import FUSIONNE, il ne remplace jamais.** Le fichier ne porte pas l'état
FSRS : il porte le JOURNAL des révisions, et l'état se recalcule en le
rejouant. C'est la stratégie d'`OpeningProgressSync.swift` côté iOS, dont
iCloud n'était qu'un tuyau. Il en découle trois propriétés, prouvées par
`TransferMergeTest` :

- **déterministe** — le résultat ne dépend que de la chronologie réelle ;
- **idempotent** — réimporter le même fichier ne change rien ;
- **commutatif** — A puis B donne le même état que B puis A.

Le transfert est **entre appareils Android** : changer de téléphone, ou en
tenir deux. L'échange avec iOS a été écarté (décision du 12/09/2026) : les
deux apps gardent chacune sa progression. Le format reste néanmoins spécifié
dans le commentaire de `TransferFile.kt`, avec un exemple complet — si l'envie
revenait, la moitié Swift serait mécanique, la stratégie de fusion existant
déjà des deux côtés.

Ce qui ne voyage PAS, et c'est voulu : la bibliothèque de puzzles et les cours,
embarqués et identiques partout. iOS l'a appris à ses dépens — dans un store
commun, la synchro poussait les cent mille puzzles vers iCloud.

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
| **Bundle complet** | **148 Mo** | 243,7 Mo |

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
