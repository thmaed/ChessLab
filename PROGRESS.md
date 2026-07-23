# PROGRESS — ChessLab

Suivi d'avancement et décisions d'architecture. Mis à jour à chaque étape
du plan de développement (voir `PROMPT-ChessLab.md`).

## Étape 0 — Mise en place et vérifications ✅ (2026-07-11)

### Fait
- Projet Xcode `ChessLab.xcodeproj` créé à la main (pas d'accès à
  `xcodegen`/`tuist` dans l'environnement de build) : cible universelle
  iPhone + iPad, `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, Swift 6,
  `TARGETED_DEVICE_FAMILY = "1,2"`. Utilise les groupes synchronisés au
  système de fichiers (Xcode 16+) : ajouter un fichier dans `ChessLab/`,
  `ChessLabTests/` ou `ChessLabUITests/` suffit, pas d'édition du
  `project.pbxproj` nécessaire pour la plupart des changements.
- Dépendances SPM ajoutées et **vérifiées fonctionnelles** :
  - [ChessKit](https://github.com/chesskit-app/chesskit-swift) 0.17.0 —
    règles, FEN/PGN/SAN.
  - [ChessKitEngine](https://github.com/chesskit-app/chesskit-engine) 0.7.0 —
    Stockfish (et Lc0, non utilisé) via UCI.
  - Ce sont exactement les paquets nommés dans le brief. Pas eu besoin de
    replier sur une intégration directe des sources Stockfish.
- "Hello engine" validé à deux niveaux :
  1. Package SPM autonome en ligne de commande (macOS) pour dérisquer
     avant d'investir dans le projet Xcode — voir historique de session,
     script jetable non conservé dans le repo.
  2. Dans l'app elle-même (`HelloEngineViewModel` + `ContentView`) :
     lancée sur simulateur iPhone 17 ET iPad Pro 11" (M5), affichage
     "Moteur opérationnel — Stockfish 17 — profondeur 10 — Meilleur
     coup : e2e4". Build **Debug** réussi sur les deux destinations via
     `xcodebuild build -destination 'platform=iOS Simulator,name=...'`.
- `EngineController` (actor) : enveloppe `ChessKitEngine.Engine`,
  expose `start()/send()/stop()` et le flux de réponses UCI parsées.
  Base pour la suite ; la reprise après crash moteur (relancer + repartir
  du FEN courant) sera ajoutée à l'étape 1 quand le mode Jouer pilotera
  de vraies parties.

### Décisions d'architecture
- **Réseaux NNUE non embarqués par ChessKitEngine** (package volontairement
  allégé, `NNUE_EMBEDDING_OFF`). Stockfish refuse de tourner sans eux
  ("ERROR: The engine will be terminated now" au premier `go`). Téléchargés
  et bundlés manuellement dans `ChessLab/Resources/` :
  - `nn-1111cefa1111.nnue` (réseau big, ~71 Mo)
  - `nn-37f18f62d772.nnue` (réseau small, ~3,4 Mo)
  Récupérés depuis `https://data.stockfishchess.org/nn/...`. `EngineType`
  de ChessKitEngine les résout automatiquement via
  `Bundle.main.url(forResource:withExtension:"nnue")` — aucun code
  supplémentaire nécessaire côté app, juste les avoir dans le bundle
  (le groupe synchronisé `ChessLab/` les inclut automatiquement comme
  ressources). **Conséquence GPLv3** : ces réseaux et Stockfish
  lui-même sont sous GPLv3 → voir README pour les implications de
  distribution.
- **Groupes synchronisés au système de fichiers** (`PBXFileSystemSynchronizedRootGroup`,
  format de projet Xcode 16+) plutôt que `PBXGroup` classique : évite de
  toucher `project.pbxproj` à chaque nouveau fichier Swift/asset, ce qui
  sera précieux vu le nombre de fichiers à venir sur les étapes 1-7.
- **`objectVersion` du pbxproj** : Xcode a lui-même renormalisé le fichier
  après ouverture (objectVersion 70, réordonnancement alphabétique) —
  aucune action requise, comportement attendu.
- **`@Observable` + `@MainActor`** pour les ViewModels (SwiftUI +
  Swift 6 strict concurrency). Piège rencontré : un bloc `async let`
  à l'intérieur d'une méthode `@MainActor` crée une tâche enfant NON
  isolée à l'acteur — impossible d'y muter une propriété `@MainActor`
  directement. Corrigé en linéarisant le flux (pas de `async let`,
  simple boucle `for await` après les `send()`), ce qui fonctionne car
  `AsyncStream` bufferise les valeurs même si personne n'écoute encore.
- **Signature de code** : `CODE_SIGN_STYLE = Automatic` sans équipe
  configurée. Suffisant pour le simulateur ("Sign to Run Locally").
  À revoir avant tout déploiement sur appareil physique ou TestFlight.
- **Icône d'app** : image `Chesslab-icon.png` fournie et ajoutée dans
  `AppIcon.appiconset` (slot universel 1024×1024).

### Vérifié
- `xcodebuild build` réussit pour `platform=iOS Simulator,name=iPhone 17`
  ET `platform=iOS Simulator,name=iPad Pro 11-inch (M5)`.
- App installée et lancée sur les deux simulateurs : test moteur visible
  à l'écran, capture d'écran confirmée sur iPhone (immédiat) et iPad
  (après quelques secondes, deux simulateurs tournant en parallèle sur
  la même machine ⇒ CPU partagé, sans lien avec le code).
- Fichiers `.nnue` bien présents dans `ChessLab.app` après build
  (vérifié dans les Produits Debug).

### Reste à faire avant l'étape 1
- Tests unitaires de base (`xcodebuild test`) pas encore exécutés dans
  ce run — à confirmer.
- Aucun test unitaire de logique métier pour l'instant (normal, l'étape 0
  ne portait que sur la mise en place ; les tests UCI/FEN/SAN/Polyglot/
  SM-2 arriveront avec le code qu'ils couvrent, étapes 1+).
- `HelloEngineViewModel`/`ContentView` sont un écran de vérification
  technique, pas l'accueil final à 5 cartes (Jouer/Analyser/Ouvertures/
  Puzzles/Laboratoire) — à remplacer à l'étape 1.

## Étape 1 — Échiquier interactif + mode Jouer ✅ (2026-07-11)

✓ = partie complète jouable aux deux formats (iPhone + iPad), validé par
un test UI automatisé qui joue réellement un coup (tap-tap) et attend la
réponse du moteur, exécuté avec succès sur les deux simulateurs.

### Fait
- **`ContentView`/`HelloEngineViewModel`** de l'étape 0 déplacés vers
  `EngineDiagnosticsView`, accessible depuis un bouton discret
  (icône stéthoscope) de l'accueil plutôt que d'être l'écran principal.
- **`HomeView`** : 5 cartes (Jouer/Analyser/Ouvertures/Puzzles/
  Laboratoire), seule "Jouer" est active ; bandeau "Reprendre la partie
  en cours" si une autosauvegarde existe. Navigation via `NavigationStack`
  + `NavigationPath` avec un `Route` **portant les données en valeur
  associée** (`activeGame(PlayGameSettings)`, `resumedGame(PlayGameAutosave)`)
  plutôt que des `@State` séparés côté à côté du `path` — piège rencontré :
  faire `path.append(...)` puis écrire un `@State` séparé juste après dans
  le même closure produit une race où le `navigationDestination` du
  nouveau `Route` s'évalue avant que le `@State` associé soit lisible
  (contrairement à l'intuition sur le batching SwiftUI). Portée par la
  route, la donnée est toujours disponible atomiquement.
- **`ChessBoardView`** (composant central) : drag & drop ET tap-tap,
  points des coups légaux (pastille pleine / anneau si capture),
  surlignage du dernier coup, roi en échec surligné en rouge, fenêtre de
  promotion (D T F C), coordonnées a-h/1-8, orientation réversible (le
  plateau s'oriente selon la couleur jouée par l'utilisateur), flèche
  d'indice. 3 thèmes de plateau (classique/noyer/ardoise) sélectionnables
  depuis la barre d'outils. Pièces = glyphes unicode stylés (contour +
  remplissage dessinés en SwiftUI) — **pas d'asset externe donc aucune
  question de licence** ; un vrai set vectoriel (type Merida) reste une
  amélioration possible pour une passe de finition graphique.
- **Sons générés par synthèse** (`SoundPlayer`, sinusoïdes + enveloppe
  percussive, 4 sons distincts coup/prise/roque/échec) + **haptique**
  (`Haptics`, `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator`).
  Aucun fichier audio embarqué → aucune licence à documenter.
- **`PlayViewModel`** : orchestre `ChessKit.Board` (légalité, état de la
  partie) + `ChessKit.Game` (historique/PGN) + `EngineController`
  (Stockfish adverse). Couvre : couleur (blancs/noirs/aléatoire), départ
  standard ou FEN personnalisé (validé — voir `FENValidator`), slider Elo
  800–3190 avec presets, cadences (sans pendule / 5+0 / 10+0 / 15+10 /
  30+0) via `GameClock`, indice, alerte gaffe avant validation, reprise de
  coup (uniquement sans pendule, comme demandé), abandon, un heuristique
  simplifié d'abandon/nulle proposée par le moteur, écran de fin de
  partie.
- **Autosauvegarde** (`PlayGameAutosave` + `AutosaveStore`) : partie en
  cours persistée en JSON dans Documents après chaque coup (position de
  départ, coups en LAN, temps d'horloge restants, couleur résolue) ;
  proposée en reprise sur l'accueil. Effacée à la fin de partie.
- **Layouts adaptatifs** : iPhone (`VStack` vertical, liste de coups dans
  une sheet) vs iPad (`HStack`, panneau de coups **persistant** à côté de
  l'échiquier), commutés via `@Environment(\.horizontalSizeClass)`.
  Plateau contraint en 1:1 via `GeometryReader` + `.aspectRatio(1, .fit)`.
- Identifiants et labels d'accessibilité sur chaque case
  (`square_e4`, "Case e4, pion blanc") : base pour VoiceOver (l'annonce
  automatique des coups joués reste à ajouter) et permet un vrai test UI
  automatisé bout-en-bout (`ChessLabUITests.testPlayAGameMove`).

### Décisions d'architecture
- **`Board` (ChessKit) piloté directement pour l'interaction**, `Game`
  tenu en parallèle uniquement pour l'historique SAN/PGN — pas besoin de
  fouiller l'API interne de `MoveTree` (son `dictionary` n'est pas
  `public`) : la liste de coups affichée vient d'un `moveLog: [Move]`
  maison alimenté à chaque coup validé, et `Move.san`/`Move.lan` sont
  calculés directement par ChessKit sans contexte supplémentaire.
- **Reprise de coup = rejoue `moveLog` depuis zéro** via `Board`/`Game`
  fraîchement recréés (pas d'API de suppression dans `MoveTree`) : plus
  simple et robuste qu'une manipulation d'arbre.
- **Alerte gaffe = deux requêtes moteur rapides** (`movetime 300`) avant
  et après le coup candidat, comparées (avec inversion de signe pour le
  changement de perspective). Ajoute ~0,3–0,6 s de latence perceptible
  avant qu'un coup ne soit validé quand l'aide est active — accepté comme
  compromis simplicité/latence pour cette étape.
- **`Square(file:rank:)` de ChessKit n'est pas `public`** : construction
  des cases via `Square(notation:)` (chaînes "e4") ou `Square(rawValue:)`
  (0...63) uniquement.
- **Position(fen:) de ChessKit est permissive** (accepte quasiment tout
  FEN structurellement valide à 6 champs, y compris illégal). D'où
  `FENValidator` maison (deux rois, pas de pion sur la 1ère/8e rangée,
  camp qui n'a pas le trait pas déjà en échec via un `Board(position:)`
  frais, droits de roque cohérents avec les cases, case en passant
  plausible) — utilisé pour la position de départ personnalisée du mode
  Jouer, et réutilisable tel quel par le scanner/éditeur de l'étape 7.
- **Bug non-trivial rencontré et corrigé : crash `AVAudioEngine`.**
  `scheduleBuffer` levait une `NSException` (donc un crash non
  rattrapable côté Swift) parce que le format de connexion
  `player → mixer` (dérivé de `player.outputFormat(forBus:)` avant toute
  connexion, donc un format par défaut) ne correspondait pas au format
  des buffers générés (44,1 kHz mono). Fixé en définissant un unique
  `AVAudioFormat` explicite réutilisé pour la connexion ET les buffers.
  Retenir : sur `AVAudioEngine`, ne **jamais** dériver le format de
  connexion de `outputFormat(forBus:)` d'un nœud pas encore connecté.
- **`@Observable` + closures capturant `self` dans un `init` de classe** :
  reproduit un piège proche de celui de l'étape 0 (`currentIndex = game.startingIndex`
  juste après `game = ...` refusé par le compilateur — "self used before
  all stored properties are initialized"). Corrigé en calculant via une
  variable locale (`let newGame = ...; game = newGame; currentIndex = newGame.startingIndex`)
  plutôt qu'en relisant `self.game` avant la fin de l'initialisation.

### Simplifié / reporté (à noter pour une passe de polish)
- **Flèches/surlignages dessinables par l'utilisateur** (mode annotation
  à la Lichess) : pas implémenté cette étape, seule la flèche d'indice
  moteur existe. Le composant `ArrowShape` est déjà réutilisable.
- **Heuristique d'abandon/nulle du moteur** volontairement simple
  (fenêtre glissante des 3/6 derniers évals du moteur sur ses propres
  coups) — à affiner si elle se révèle trop capricieuse en pratique.
- **VoiceOver** : labels par case en place, mais pas d'annonce automatique
  du dernier coup joué (`UIAccessibility.post(notification:.announcement)`)
  ni de vérification complète Dynamic Type / cibles 44pt sur tous les
  contrôles — à couvrir dans une passe accessibilité dédiée.
- **Départ par image scannée** : hors scope (explicitement étape 7).
- **"Analyser cette partie"** en fin de partie : pas encore de bouton,
  le mode Analyser n'existe pas avant l'étape 3.
- Taille du plateau : contraint par la largeur disponible (déjà proche du
  maximum), mais laisse un espace vertical inutilisé sur les écrans hauts
  (iPhone) / larges (iPad panneau) — amélioration possible plus tard.

### Vérifié
- `xcodebuild test` (unitaires + UI) **succès sur iPhone 17 ET iPad Pro
  11" (M5)** : lancement, navigation Jouer → Nouvelle partie → coup
  tap-tap (e2-e4) → pion déplacé → le moteur (noirs) répond dans la
  foulée. Capture d'écran vérifiée sur les deux formats : plateau lisible,
  surlignage du dernier coup, panneau de coups adapté à chaque layout.
- Aucun crash restant (le crash `AVAudioEngine` rencontré pendant le
  développement de cette étape est corrigé et re-testé).

## Révision UX de l'étape 1 (2026-07-11, suite) ✅

Refonte visuelle demandée après une première revue utilisateur : fond
blanc jugé peu soigné, pièces glyphes peu lisibles, plateau non maximisé,
réglages en "gros blocs" façon Form UIKit.

### Fait
- **Pièces vectorielles cburnett** (CC BY-SA 3.0, Colin M.L. Burnett,
  téléchargées depuis Wikimedia Commons) en remplacement des glyphes
  Unicode — voir README pour l'attribution complète. 12 SVG embarqués
  dans `Assets.xcassets/Pieces/`, rendus via `Image(_:)` avec
  `preserves-vector-representation` (net à toute taille).
- **Thème sombre propre à l'app** (`Theme.swift`) appliqué à l'accueil,
  aux réglages de partie et à l'écran de jeu, via
  `.preferredColorScheme(.dark)` posé une fois à la racine — l'app a donc
  une identité visuelle sombre fixe (pas encore d'alternative claire
  proposée à l'utilisateur, cf. section "Simplifié" ci-dessous).
- **Plateau bord-à-bord sur iPhone** : suppression du padding horizontal
  autour de l'échiquier spécifiquement (le reste du contenu — pendules,
  contrôles, liste de coups — garde ses marges).
- **Réglages redessinés** (`NewGameSetupView`) : `Form`/`Section` UIKit
  remplacés par des cartes maison (`cardStyle()`), sélecteurs en chips
  (couleur, préréglages Elo) et lignes sélectionnables (cadence) au lieu
  de `Picker`/`Toggle` par défaut.
- **Déplacement de pièce immédiat.** Changement de comportement demandé
  explicitement par l'utilisateur, qui **prime sur la formulation initiale
  du cahier des charges** ("Alerte gaffe avant validation") : le coup
  s'affiche désormais instantanément au tap/drop, sans attente réseau.
  L'alerte gaffe devient **rétroactive** : après validation immédiate du
  coup, une vérification moteur (deux requêtes rapides avant/après,
  inchangé) tourne en tâche de fond ; si la perte dépasse ~2 pions, une
  alerte propose "Reprendre le coup" (dispo seulement si `canTakeback`,
  et seulement si aucun autre coup n'a été joué entretemps — sinon
  l'alerte est simplement ignorée plutôt que de proposer un retour en
  arrière déroutant sur plusieurs coups).
- **Flèches d'indice multiples** : jusqu'à 3 suggestions classées
  (`MultiPV = 3` activé en permanence sur le moteur, pas seulement à la
  demande), affichées avec une seule teinte (accent) mais une
  luminosité/opacité et une épaisseur décroissantes du rang 1 au rang 3.

### Décisions d'architecture
- **`Board.position` capturé juste avant mutation** dans `commit(...)`
  pour permettre le contrôle de gaffe rétroactif (on ne peut plus
  comparer avant/après une fois `board` réassigné).
- **`MultiPV = 3` réglé une fois à `engine.start(multipv:)`** plutôt que
  changé dynamiquement selon l'action (coup du moteur vs indice) : plus
  simple, léger surcoût de recherche acceptable aux profondeurs/movetimes
  utilisés ici.
- **Piège XCUITest découvert** : combiner `.accessibilityLabel(_:)` avec
  `.accessibilityHint(_:)` (ou `.accessibilityValue(_:)`) sur un même
  élément fait que la propriété `.label` lue par XCUITest concatène les
  deux ("Jouer, vs Stockfish" au lieu de "Jouer"), cassant toute
  recherche par égalité stricte (`app.buttons["Jouer"]`). Corrigé en ne
  posant qu'un `.accessibilityLabel` explicite sur les cartes du menu
  d'accueil (le sous-titre visuel n'est donc pas encore annoncé par
  VoiceOver — à revoir dans la passe accessibilité dédiée).
- **Licence des pièces** : cburnett est *share-alike* (CC BY-SA) — cela
  ne change rien à la licence du code de l'app, mais toute redistribution
  modifiée des SVG eux-mêmes devrait rester sous la même licence.
  Documenté dans le README.

### Simplifié / reporté
- Pas de bascule utilisateur clair/sombre : le mode sombre est fixe pour
  l'instant. Un réglage "suivre le système" pourra être ajouté plus tard
  sans revoir `Theme.swift` en profondeur (il suffira de conditionner
  `.preferredColorScheme`).
- Plateau iPad : toujours contraint par la largeur de sa colonne plutôt
  que bord-à-bord complet (l'iPad garde un panneau de coups permanent à
  côté, donc un plateau 100 % bord-à-bord n'a pas de sens dans ce
  layout) — comportement jugé correct, pas un oubli.
- L'alerte gaffe rétroactive peut désormais "manquer" une gaffe si le
  moteur a déjà répondu avant la fin de la vérification (~0,6 s) : accepté
  comme compromis direct de la priorité donnée au geste instantané.

### Vérifié
- `xcodebuild test` (unitaires + UI) de nouveau vert sur iPhone 17 ET
  iPad Pro 11" (M5) après la refonte.
- Vérification visuelle par capture d'écran (test UI temporaire, retiré
  après coup) : accueil, réglages, plateau en cours de partie, flèches
  d'indice multiples — sur les deux formats.

## Étape 2 — Livre d'ouvertures + mode deux humains ✅ (2026-07-12)

✓ = débuts variés sur 10 parties. Opérationnalisé par
`OpeningBookEngineTests.producesVariedOpeningLines()` (200 tirages simulés,
≥ 3 lignes distinctes sur 6 demi-coups — preuve plus solide que 10 vraies
parties, qui auraient été lentes et non déterministes à cause de Stockfish).

Session précédente interrompue par un crash avant que ce travail (ainsi que
des fondations de l'étape 3, voir plus bas) ne soit documenté ici. Reprise
2026-07-12 : build + suite de tests complète relancés, un test UI
temporaire ajouté puis retiré a rejoué le mode Deux joueurs de bout en
bout pour confirmer que rien n'a été laissé cassé par l'interruption.

### Fait
- **`OpeningBookEngine`** (`ChessLab/OpeningBook/`) : logique de tirage pure
  (pas de dépendance à `Board`/`Piece.Color`), réutilisable telle quelle par
  le Laboratoire (étape 6). Marche dans l'arbre coup par coup à partir du
  `sanPath` déjà joué ; tirage pondéré par `weight` ; réglage largeur
  (`mainLinesOnly` / `includeSidelines`) qui filtre sur `isMainLine`.
- **Livre embarqué en JSON** (`ChessLab/Resources/opening_book.json`) :
  arbre de 127 nœuds sous 4 racines (e4/d4/c4/Nf3), profondeur ~8-10 coups
  sur les lignes principales. Format JSON choisi plutôt que Polyglot .bin
  (plus simple à éditer/étendre à la main, pas de parseur binaire à écrire).
- **`PlayViewModel.requestEngineMove()`** pioche dans le livre
  (`bookMoveIfAvailable()`) tant que `settings.bookEnabled` et que la
  position y figure ; retombe sur le calcul normal dès que le livre est
  désactivé, la position est personnalisée (FEN de départ non standard),
  ou la ligne jouée sort de l'arbre connu. Même délai aléatoire de rythme
  UX qu'un coup calculé, pour que le coup de livre ne soit pas instantané
  et déroutant.
- **Mode Deux humains** (`ChessLab/TwoPlayer/`) : `TwoPlayerViewModel`
  (version allégée de `PlayViewModel`, sans moteur — pas d'indice, pas de
  barre d'éval, pas de reprise de coup), `TwoPlayerSetupView` (noms,
  orientation, cadence), `TwoPlayerGameView` (plateau plein écran, éval et
  notation MASQUÉES pendant la partie, révélées sur l'écran de résultat),
  autosauvegarde dédiée (`TwoPlayerGameAutosave`). Rotation face-à-face
  (pivot 180° après chaque coup) ou fixe, pendules doubles optionnelles,
  abandon par joueur, nulle par accord mutuel.
- **`PlayModeChoiceView`** : écran intermédiaire "Contre Stockfish" /
  "Deux joueurs" inséré entre la carte "Jouer" de l'accueil et les écrans
  de réglages respectifs.
- **`HomeView`** : bannière "Reprendre la partie en cours" désormais
  consciente des DEUX autosauvegardes possibles (vs Stockfish et Deux
  joueurs) — retient la plus récente si les deux existent (cas rare).

### Décisions d'architecture
- **Fondations de l'étape 3 avancées en avance de phase** : `GameRecord`
  (SwiftData, `ChessLab/Persistence/`) + `GameLibraryService` écrivent déjà
  une bibliothèque de parties terminées (PGN, résultat, joueurs) à chaque
  fin de partie, mode Jouer ET Deux joueurs confondus — mais **rien ne la
  relit encore**, le mode Analyser proprement dit reste à construire à
  l'étape 3. Fait maintenant pour que cette étape future ait de vraies
  données dès son démarrage. Modèle conçu compatible CloudKit dès le
  départ (propriétés optionnelles/valeurs par défaut, aucune contrainte
  unique) conformément à la mise en garde du brief.
- **Sync iCloud réelle non activée** (`CloudSyncSettingsStore.isEnabled`
  reste faux, aucune UI ne l'expose) : nécessite l'ajout manuel, une fois,
  de la capacité iCloud dans Xcode (Signing & Capabilities) — étape
  interactive non fiabilisable via `xcodebuild` seul dans cet
  environnement. Le `ModelConfiguration` de `ChessLabApp` est déjà écrit
  pour basculer vers `.automatic` sans modification structurelle le jour
  où ce réglage sera activé.
- **Bouton "Analyser cette partie" présent mais désactivé** sur l'écran de
  résultat des deux modes (Jouer et Deux joueurs) : même report que la
  bibliothèque, cohérent avec le plan (mode Analyser = étape 3).
- **Refonte concurrente de l'indice** (`hintsWanted` séparé de
  `isHintAnalyzing`, force graduée par écart d'éval — voir
  `HintMove.strength`) et **pause de la pendule en arrière-plan**
  (`handleAppBackgrounded`/`handleAppForegrounded`) faites dans la même
  session : hors périmètre strict de l'étape 2, mais nécessaires pour que
  le mode Deux humains (qui réutilise `GameClock`) ait un comportement de
  pendule cohérent avec le mode Jouer. Voir `stopHintIfNeeded()` dans
  `PlayViewModel.swift` pour le piège de concurrence corrigé (consommateur
  unique du flux de réponses moteur, plusieurs appelants pouvaient se
  disputer le `bestmove` du vrai coup suivant).

### Vérifié
- `xcodebuild test` (unitaires + UI) vert sur simulateur iPhone 17 : 8/8
  tests unitaires (dont les 6 `OpeningBookEngineTests`), 5/5 tests UI
  (un flake de timing isolé sur `testMoveWhileHintAnalyzingDoesNotDeadlock`
  en run complet — passe seul en 20 s ; non représentatif d'une régression,
  cf. marge insuffisante face à la charge simulateur en suite complète).
- Mode Deux humains rejoué de bout en bout via un test UI temporaire
  (setup → coups tap-tap → pivot face-à-face → abandon avec choix du
  joueur → écran de résultat avec notation révélée et "Analyser cette
  partie" désactivé → retour accueil) — succès, test retiré ensuite.
- Aucun TODO/stub restant dans le code des étapes 2/3 ajouté cette session.

## Révision UX du mode Deux joueurs (2026-07-12, suite) ✅

Deux retours utilisateur après coup d'œil sur le résultat de l'étape 2 :

- **Mode d'orientation "Table"** : `TwoPlayerGameSettings.RotationMode`
  gagne un troisième cas `.tabletop`. Contrairement à "Face à face
  (pivote)" qui ne fait que réassigner quelle couleur s'affiche en bas
  (aucune vraie rotation de pixels — les deux joueurs assis en vis-à-vis
  doivent donc quand même retourner l'appareil à la main pour lire
  noms/pendule à l'endroit), le mode Table garde le plateau **fixe**
  (comme `.fixed`, aucun changement dans `TwoPlayerViewModel`) mais
  tourne réellement les éléments qui doivent être lus par le joueur d'en
  face, via `.rotationEffect(.degrees(180))` :
  - HUD + barre de contrôles du haut sont dupliqués et tournés en bloc
    (`TwoPlayerGameView.topZone`) : noms, pendule, icônes Abandonner/Nulle
    lisibles à l'endroit pour qui est assis en face, en permanence.
  - **Les pièces, elles, tournent TOUTES ensemble selon le trait** (pas
    par couleur) : `ChessBoardView.allPiecesRotated` (nouveau paramètre,
    `false` par défaut ailleurs) applique la rotation à la couche de
    pièces entière quand c'est au tour du joueur d'en face de jouer
    (`TwoPlayerGameView` calcule
    `isTabletopMode && board.position.sideToMove == topColor`). Premier
    essai (rotation figée par couleur de pièce, indépendante du trait)
    corrigé après retour utilisateur — la bonne mécanique est que
    l'échiquier entier "se retourne" pour celui dont c'est le tour,
    exactement comme le HUD au-dessus de lui, et non que les pièces
    noires soient en permanence à l'envers.
  Le plateau lui-même (cases, coordonnées) ne bouge jamais — seuls les
  glyphes tournent, avec une animation `.easeInOut(0.35s)` pour que le
  changement de trait soit visible plutôt qu'un saut brutal. Vérifié
  visuellement par capture d'écran (tests UI temporaires, retirés après
  coup) : trait aux Blancs → tout à l'endroit pour eux ; trait aux Noirs →
  pièces des DEUX couleurs basculées ensemble.
- **Accueil simplifié** : `PlayModeChoiceView` (écran de choix
  intermédiaire "Contre Stockfish" / "Deux joueurs") retiré — jugé
  superflu, un tap de moins pour lancer une partie. Ses deux libellés et
  icônes sont repris tels quels comme deux tuiles directes sur l'accueil,
  ce qui a permis de ne quasiment pas toucher les tests UI existants
  (seul le premier tap sur "Jouer" disparaît, le reste du chemin — tap
  sur "Contre Stockfish"/"Deux joueurs" — restait identique).

## Étape 3 — Mode Analyser ✅ (2026-07-12)

✓ = un PGN importé est classifié, variantes navigables, export PGN
rechargeable sans perte — validé concrètement par
`AnalysisPGNRoundTripTests.pgnWithVariationNagAndCommentRoundTripsLossless()`
(une partie avec variante + NAG + commentaire survit à un aller-retour
`.pgn` → `Game(pgn:)` → `.pgn` texte pour texte) et par un parcours UI de
bout en bout (import → navigation → variante créée → export), voir
"Vérifié" plus bas.

### Recherche préalable (évite de réinventer)
`ChessKit.Game` gère DÉJÀ les variantes en interne : `make(move:from:)`
crée automatiquement une nouvelle branche (`MoveTree.Index.variation`) si
on joue un coup différent depuis un index historique, `Game.positions`
cache la position de chaque nœud, et `PGNParser`/`Game.pgn` round-trip
déjà variantes imbriquées, NAG et commentaires. `MoveTree` conforme à
`BidirectionalCollection` (`index(before:)`/`index(after:)` suivent les
vrais liens de l'arbre, y compris à travers les branches) — utilisé pour
toute navigation et pour reconstruire la liste de coups affichée depuis
`MoveTree.pgnRepresentation` (pas d'API publique "enfants d'un index",
`Node` est interne). Détail précieux : `ChessKit.Move.Assessment` a déjà
exactement les bons symboles NAG (`.dubious` "?!", `.mistake` "?",
`.blunder` "??", `.brilliant` "!!", `.good` "!") — réutilisé directement
comme type de classification (``MoveClassifier``) plutôt qu'un enum
maison, ce qui fait que les classifications s'exportent automatiquement
en PGN via `Game.annotate(moveAt:assessment:)`.

### Fait
- **`ChessLab/Analysis/`** (nouveau dossier) :
  - `MoveClassification.swift` — `EvalConversion.winPercentage(cp:/mate:)`
    (sigmoïde du brief), `MoveClassifier.classify(...)` (seuils
    imprécision/erreur/gaffe 10/20/30 points de perte de probabilité de
    gain), `MoveClassifier.isBrilliant(...)` + `involvesSacrifice(...)`
    (heuristique simple : perte nette de matériel ≥ 2, case reprenable
    par un adversaire moins cher ou égal — sans recherche en profondeur),
    `AccuracyScore.accuracy(averageWinPercentLoss:)` (précision par
    joueur, formule inspirée de celle popularisée par Lichess, choix
    documenté car non spécifiée telle quelle dans le brief).
  - `EcoOpening.swift`/`EcoOpeningLoader.swift` + `Resources/eco_openings.json`
    — base ECO embarquée (76 ouvertures courantes, même principe que
    `OpeningBookLoader`), recherche par plus long préfixe SAN commun.
  - `AnalysisMoveEvaluation.swift` — petit cache par nœud
    (`[MoveTree.Index: AnalysisMoveEvaluation]`).
  - `AnalysisViewModel.swift` — `@Observable @MainActor`, possède son
    PROPRE `EngineController` (le commentaire de `EngineController`
    prévoit explicitement "une instance par partie/analyse active" :
    tourner en parallèle de celle du mode Jouer est le modèle prévu, pas
    un raccourci). Navigation dans l'arbre réel (`goToNext/Previous/goTo`,
    `attemptMove` crée une branche via `game.make` si on n'est pas sur la
    ligne déjà connue). Analyse en continu (MultiPV=3) de la position
    affichée, sur le même pattern que `PlayViewModel.startHintAnalysis`/
    `stopHintIfNeeded` (file sérielle, un seul consommateur du flux de
    réponses moteur) mais toujours active, pas de bascule utilisateur.
    Classification de fond de la ligne principale après import
    (MultiPV=1, un eval par nœud, mise en cache POV Blancs partagée entre
    classification/précision/courbe — pas 2 evals par coup : "avant" pour
    le coup N est simplement l'éval déjà mis en cache du nœud N-1),
    complétée par une vérification MultiPV=2 ponctuelle (donc peu
    coûteuse) uniquement pour les coups candidats au brillant (sacrifice
    détecté localement sans perte de probabilité). Variantes explorées
    classifiées à la volée à la navigation, pas en avance.
  - `AnalysisView.swift` — layout adaptatif iPhone (sheet)/iPad (scroll
    vertical), sur le même gabarit que `PlayView.swift`. Plateau + barre
    d'éval (`EvalBarView`, extraite de `PlayView.swift` vers
    `ChessLab/Board/EvalBarView.swift` pour réutilisation) + flèches
    MultiPV (`HintMove`, extrait avec son constructeur
    `HintMoveBuilder` vers `ChessLab/Board/HintMove.swift`, partagé avec
    `PlayViewModel`) + liste de coups indentée par profondeur de variante
    avec icônes de classification + courbe d'éval Swift Charts (bornée
    ±10 pions, mat = ±10, cliquable) + en-tête ECO + menu (Jouer à partir
    d'ici / Exporter le PGN / thème du plateau).
  - `AnalysisEntryView.swift` — choix de la source : dernière partie,
    coller un PGN, importer un fichier `.pgn` (`fileImporter`), position
    FEN (réutilise `FENValidator.errors(in:)`), bibliothèque.
  - `AnalysisLibraryView.swift` — liste simple des `GameRecord`
    (`@Query` SwiftData), tap → ouvre l'analyse sur ce PGN.
- **Accueil** : carte "Analyser" activée, nouvelles routes
  `analysisEntry`/`analysisLibrary`/`activeAnalysis(AnalysisSource)` +
  `AnalysisHost` paresseux (même gabarit que `TwoPlayerActiveGameHost` —
  l'analyse a le même effet de bord process moteur que le mode Jouer).
- **Boutons "Analyser cette partie"** réellement branchés dans
  `PlayView.GameOverCard` (nouveau, n'existait pas) et
  `TwoPlayerGameView.TwoPlayerResultCard` (remplace le texte désactivé
  posé à l'étape 2), tous deux poussant `.activeAnalysis(.pgn(game.pgn))`.

### Décisions d'architecture
- **Bug réel trouvé par le test UI, pas juste un flake** : la carte
  "Coller un PGN" lisait `UIPasteboard.general.string` directement au tap
  — dans le simulateur (et potentiellement en usage réel), lire le
  presse-papiers écrit par un AUTRE process/app peut déclencher une
  invite système de consentement qui bloque le fil principal tant que
  personne n'y répond ; sans utilisateur pour taper "Autoriser", l'app
  restait gelée indéfiniment (confirmé en extrayant des frames de la
  vidéo d'échec du test — écran figé du premier au dernier instant,
  aucun crash). Corrigé en remplaçant la lecture directe par un
  `PasteButton` SwiftUI (API pensée par Apple précisément pour ça : un
  tap sur `PasteButton` est reconnu comme un geste de collage explicite,
  sans invite de consentement). Retenir : ne jamais lire
  `UIPasteboard.general` en dehors d'un `PasteButton`/`PasteButton`-like.
- **Périmètre volontairement réduit** par rapport à la description
  complète du mode Analyser du brief, même esprit "cœur solide + révision
  UX ensuite" que les étapes 1-2. Reporté (à noter si demandé) :
  - Share extension recevant un PGN depuis une autre app (nouveau target
    Xcode, hors de portée de `xcodebuild` seul dans cet environnement —
    même limitation déjà documentée pour la capacité iCloud CloudKit).
  - Import image scannée (explicitement étape 7 dans le plan).
  - Classification eager de TOUTES les variantes (seule la ligne
    principale est classifiée à l'import ; une variante n'est classifiée
    qu'à la volée, dès qu'on y navigue).
  - Recherche/tags avancés dans la bibliothèque (liste simple, pas de
    filtre par date/tag).
  - Sauvegarde des résultats d'analyse dans `GameRecord` (recalculés à
    chaque ouverture — pas de nouveau champ SwiftData cette passe).
  - Bouton "Créer des puzzles depuis les erreurs" affiché mais désactivé
    (Mode 4, pas encore construit) — même convention que les cartes
    désactivées de l'accueil.

### Vérifié
- `xcodebuild test` : 29 tests unitaires (dont
  `MoveClassificationTests`, `EcoOpeningLookupTests`,
  `AnalysisPGNRoundTripTests`) + 5 tests UI, tous verts sur simulateur
  iPhone 17, deux runs consécutifs sans flake.
- Parcours UI temporaire (ajouté puis retiré) : accueil → Analyser →
  coller un PGN (Ruy Lopez, 3 coups) → position importée affichée →
  panneau coups/courbe → navigation vers un coup antérieur (2...Nc6) →
  coup alternatif joué (3.Bc4 au lieu de 3.Bb5) → variante indentée
  apparaît SOUS la ligne principale, qui continue normalement avec
  3...a6 après la parenthèse → en-tête ECO se met à jour ("C50 Partie
  italienne") → menu d'export accessible. Captures d'écran confirmées
  visuellement à chaque étape clé.
- Piège XCUITest déjà connu retrouvé une fois de plus : un `Button`
  combinant plusieurs `Text` (numéro de coup + SAN) en un seul libellé
  d'accessibilité imprévisible — corrigé avec un `.accessibilityLabel`
  explicite sur la ligne de coup, même remède que pour les cartes de
  l'accueil (voir étape 1).

### Révision (2026-07-12, suite)
- **Cible de déploiement remontée à iOS 18.0** (était 17.0 depuis
  l'étape 0), sur demande explicite — `IPHONEOS_DEPLOYMENT_TARGET` dans
  les deux configurations (Debug/Release) du target `ChessLab` dans
  `project.pbxproj`. Aucune API du projet ne nécessitait encore iOS 18 ;
  changement purement en prévision.
- **`AnalysisView`** : `ChartProxy.plotAreaFrame` (dépréciée iOS 17,
  utilisée dans le geste de la courbe d'éval) remplacée par
  `plotFrame` (`Anchor<CGRect>?`), avec `guard let` plutôt qu'un
  force-unwrap.
- **Bug de compilation latent corrigé** : `PlayView.body` contenait un
  `.background(Color.clear.accessibilityIdentifier(...).accessibilityValue("\(...)")...)`
  inline que le vérificateur de types du compilateur a cessé de résoudre
  dans le budget imparti ("unable to type-check ... in reasonable time")
  après la bascule vers iOS 18 — extrait en propriété calculée
  `moveCountMarker` séparée (même valeur, juste sorti du corps de
  `body`), ce qui résout l'expression instantanément. Aucun changement
  de comportement, seulement de structure.

### Mode Jouer — reprise de plusieurs coups à la fois (2026-07-12) ✅

Nouvelle aide, désactivable, sur demande explicite : ``PlayGameSettings/multiMoveTakebackEnabled``
(`false` par défaut — opt-in, aide plus appuyée que les autres). Une fois
activée (toggle "Reprendre plusieurs coups à la fois" dans la section
Aides de `NewGameSetupView`), taper un coup ANTÉRIEUR dans la liste des
coups (`PlayView.MoveListView`) revient directement à l'état juste après
ce coup, en un seul geste — pas besoin de taper "Reprendre" en boucle.

### Fait
- `PlayViewModel.takeback()` refactorisé : la logique de reconstruction
  post-reprise (arrêt de l'indice, autosauvegarde, relance moteur si
  besoin) est désormais dans `performTakeback(keeping:)`, commune à
  `takeback()` (1 ou 2 coups, comportement inchangé) et au nouveau
  `takeback(toMoveIndex:)` (jusqu'à l'index choisi, 0-based ; `-1` pour
  revenir au tout début).
- `MoveListView` : chaque coup (sauf le tout dernier — y "revenir"
  serait un no-op) devient un bouton (accent, souligné) quand l'option
  est active ET qu'une reprise est possible (`canTakeback`), sinon reste
  un simple `Text` comme avant. La feuille de coups se referme
  automatiquement après sélection (iPhone).

### Décisions d'architecture
- **Le trait peut revenir au moteur après une reprise multiple** :
  contrairement au bouton "Reprendre" habituel qui recule d'au plus 2
  coups pour TOUJOURS rendre la main à l'utilisateur, taper un coup joué
  par l'utilisateur (ex. son propre 1er coup) laisse ensuite le trait au
  moteur — celui-ci répond alors immédiatement (même logique que
  `takeback()` existant : "cas reprendre le tout premier coup du
  moteur"). Comportement voulu, pas un bug — vérifié explicitement par
  le test UI temporaire (voir "Vérifié").

### Vérifié
- Test UI temporaire (ajouté puis retiré) : option activée en réglages,
  3 paires de coups jouées (6 demi-coups), tap sur le 1er coup ("e4")
  dans la liste → le compteur de coups saute directement de 6 à 2 (1
  coup conservé + réponse immédiate du moteur), impossible à obtenir en
  un seul tap avec le bouton "Reprendre" classique (qui plafonne à 2
  coups par tap) — prouve concrètement la reprise multiple. Capture
  d'écran confirmée : plateau revenu exactement à la position après
  1.e4 e5 (pièces f1/g1 de retour à la maison).

## Étape 4 — Mode Puzzles ✅ (2026-07-12)

✓ = une partie avec gaffes génère ≥ 1 puzzle résoluble — validé
concrètement par un parcours UI de bout en bout (import PGN avec une
gaffe connue → "Créer des puzzles depuis les erreurs" → 1 puzzle créé →
file de puzzles dus → résolution avec révélation de solution après 3
essais → retour à la partie d'origine), voir "Vérifié" plus bas.

### Fait
- **`ChessLab/Puzzles/`** (nouveau dossier) :
  - `Puzzle.swift` — `@Model` SwiftData, même discipline CloudKit-safe
    que `GameRecord` (toutes les propriétés optionnelles ou avec valeur
    par défaut, aucune contrainte unique) : `fen`, `playedMoveSAN`,
    `solutionLANs`, `themeRaw` (+ `PuzzleTheme` enum : mat/pièce en
    prise/fourchette/tactique), `sourceGamePGN` (le PGN complet, stocké
    directement plutôt qu'une référence à `GameRecord.id` — tous les
    points d'entrée de `AnalysisSource` ne portent pas un identifiant de
    partie fiable), champs SM-2 et compteurs succès/échec.
  - `SpacedRepetition.swift` — SM-2 simplifié (qualité binaire
    succès/échec plutôt que 0-5), pur, testé.
  - `PuzzleThemeDetector.swift` — pur (aucun moteur requis), rejoue
    `solutionLANs` sur un `Board` frais pour détecter mat (position
    finale), pièce en prise (1er coup capture une pièce de valeur ≥ 3
    sans reprise possible) et fourchette (1er coup attaque ≥ 2 pièces
    adverses de valeur ≥ 3), sinon "Tactique" générique.
  - `ChessLab/Board/PieceValue.swift` — `pieceValue(_:)` extraite de
    `MoveClassification.swift` en fonction libre partagée, réutilisée par
    le détecteur de thème.
  - `PuzzleSolveViewModel.swift` — `@Observable @MainActor`, construit
    `Board`/orientation depuis `puzzle.fen`. Coup correct → avance
    `currentStep`, riposte adverse auto-jouée après un court délai
    (rythme naturel, même esprit que `PlayViewModel.bookMoveIfAvailable`) ;
    coup incorrect → `attemptsRemaining` décrémenté, à 0 révèle la
    solution via une flèche (`hintMoves`/`HintMove`, réutilisés tels
    quels) ; séquence épuisée → succès. Dans les deux cas, calcule le
    prochain `SpacedRepetition.Schedule` et sauvegarde immédiatement.
  - `PuzzleSolveView.swift` — plateau (`ChessBoardView` réutilisé sans
    modification), bandeau thème + "Trouvez mieux que…", indicateur
    d'essais (3 points), overlay de résultat avec "Retour à l'accueil"
    et, si succès, "Voir dans la partie d'origine".
  - `PuzzleQueueView.swift` — `@Query(sort: \Puzzle.dueDate)`, file des
    puzzles dus (`dueDate <= Date()`) + stats globales et par thème
    (calculées depuis les compteurs succès/échec), état vide
    (`ContentUnavailableView`) invitant à analyser une partie.
- **`AnalysisViewModel.generatePuzzles(in:)`** — pour chaque coup classé
  `.mistake`/`.blunder` dans `moveEvaluations`, relance une recherche
  MultiPV=2 plus profonde (1200ms, contre le budget plus court de la
  classification de fond) sur la position AVANT le coup, ne retient le
  candidat que si l'écart PV1–PV2 dépasse 150 centipions (filtre de
  netteté du brief), construit la solution depuis la PV complète du
  meilleur coup (pas seulement son premier demi-coup), déduit le thème
  via `PuzzleThemeDetector`, insère un `Puzzle`. `rankedEval` étendu pour
  retourner la PV complète en plus du coup et du score (nécessaire pour
  une solution multi-coups, pas juste le 1er coup joué).
- **`AnalysisView`** — item de menu "Créer des puzzles depuis les
  erreurs" (désactivé pendant `isClassifying`/génération en cours),
  alerte de résultat ("N puzzle(s) créé(s)" ou message expliquant
  l'absence de gaffe assez nette).
- **`ChessLabApp.swift`** — `Puzzle` ajouté au `Schema` SwiftData.
- **Accueil** — carte "Puzzles" activée, routes `puzzleQueue`/
  `activePuzzle(Puzzle)`, `PuzzleHost` paresseux (même gabarit que
  `AnalysisHost`/`TwoPlayerActiveGameHost`).

### Décisions d'architecture
- **Deadlock réel trouvé, même mécanisme que celui déjà documenté à
  l'étape 1** : `generatePuzzles(in:)` empilait initialement son travail
  directement via `enqueueEngineWork`, mais l'analyse en continu
  (`go infinite`, démarrée par `startLiveAnalysis()`) ne se termine
  jamais d'elle-même — tout ce qui est empilé après elle attend
  indéfiniment, puisque la seule façon de l'arrêter (`.stop`) nécessite
  elle-même l'accès à la file. Corrigé en ajoutant un
  `await stopLiveAnalysisIfNeeded()` en appel direct (hors file, comme
  `PlayViewModel.interruptHintAnalysisIfNeeded()` et
  `AnalysisViewModel.handleViewDisappear()`) avant d'empiler la
  génération. Diagnostiqué via un test UI qui restait bloqué avec le
  bouton visible et "tapable" mais sans effet.
- **Le filtre de netteté (150cp) juge l'ambiguïté de la POSITION avant
  le coup, pas la sévérité de la gaffe elle-même** — leçon tirée d'un
  premier scénario de test raté : `1. e4 e5 2. Qh5 Nc6 3. Qxf7+` (sacrifice
  de dame flagrant) est rejeté par le filtre, car la position juste
  avant 3.Qxf7+ offre plusieurs coups de développement à peu près
  équivalents pour Blanc — aucun écart PV1–PV2 net, donc pas de solution
  sans ambiguïté à proposer comme puzzle, même si le coup joué était une
  franche gaffe. Un puzzle a besoin d'un MEILLEUR COUP clairement
  supérieur à toute alternative, pas seulement d'un mauvais coup joué.
  Confirmé par l'alerte "Aucune gaffe assez nette pour un puzzle sans
  ambiguïté dans cette partie." Le second scénario testé
  (`1. e4 e6 2. Nf3 Qh4 3. a3`, Blanc ignore une dame en prise en h4 par
  son cavalier f3) passe immédiatement le filtre : "capturer une dame
  gratuite" est écrasamment dominant sur toute alternative.
- **`sourceGamePGN` stocke le PGN complet plutôt qu'une référence** —
  choix déjà justifié ci-dessus (Fait), retenu ici comme décision
  délibérée plutôt qu'un raccourci : simplifie "Voir dans la partie
  d'origine" (réouvre directement `.activeAnalysis(.pgn(...))`) sans
  dépendre de la persistance ou non de la partie source dans
  `GameRecord`.
- **Périmètre volontairement réduit**, reporté :
  - File quotidienne mixte ouvertures+puzzles ("Entraînement du jour") —
    le mode Ouvertures (étape 5) n'existe pas encore ; seule la file de
    puzzles dus existe pour l'instant, le moteur SM-2 est déjà
    directement réutilisable tel quel à l'étape 5.
  - Thème "clouage" non détecté (géométrie de pin non triviale sans
    moteur d'attaque public dans ChessKit) — seuls mat/pièce en
    prise/fourchette/tactique générique cette passe.
  - "Voir dans la partie d'origine" rouvre le PGN complet en Analyser
    (pas de saut direct au coup précis).
  - Historique détaillé des tentatives — seuls des compteurs agrégés
    succès/échec par puzzle, pas un journal par tentative.

### Vérifié
- `xcodebuild test` : 41 tests unitaires (dont les nouveaux
  `SpacedRepetitionTests` et `PuzzleThemeDetectorTests`) + suite UI
  complète, tous verts sur simulateur iPhone 17.
- Parcours UI temporaire (ajouté puis retiré) : accueil → Analyser →
  coller un PGN avec une gaffe nette (dame en prise ignorée) → "Créer
  des puzzles depuis les erreurs" (bouton attendu réellement activable,
  pas un délai fixe, le temps que la classification de fond se termine)
  → alerte "1 puzzle créé" → retour à l'accueil → Puzzles → puzzle du
  jour ouvert (thème "Pièce en prise" confirmé à l'écran) → 3 coups
  clairement hors-solution joués pour épuiser les essais → "Solution
  révélée" affichée → "Voir dans la partie d'origine" rouvre bien
  l'analyse sur la partie source. Captures d'écran confirmées
  visuellement à chaque étape clé (position de départ du puzzle,
  overlay de solution révélée). Test relancé après correction du
  deadlock : passé deux fois de suite (~44s), aucun flake.

## Étape 5 — Mode Ouvertures ✅ (2026-07-12)

✓ = import d'un répertoire PGN + session de révision — validé
concrètement par un parcours UI de bout en bout (création d'un
répertoire → import PGN → 3 cartes générées → session : réussite sur
une carte, échec+révélation sur une autre → "Continuer contre Stockfish
depuis ici"), voir "Vérifié" plus bas.

### Recherche préalable (évite un module d'arbre parallèle)
`ChessKit.MoveTree` expose `indices: [Index]` (tous les nœuds de
l'arbre, variantes comprises) et `index(before:)` suit `Node.previous`
— le VRAI parent d'un nœud, qu'il soit sur la ligne principale ou une
variante (`Node.children`/`Node.next` ne sont, eux, pas publics). En
regroupant tous les indices par leur parent (`RepertoireTree.swift`),
on obtient directement "les coups possibles à cette position" sans
avoir à convertir vers l'`OpeningBookNode` de l'étape 2 (qui reste
dédié au livre intégré du moteur — structure différente, pas de poids
de popularité pour un répertoire utilisateur). Un seul utilitaire pur
factorise cette marche dans l'arbre pour trois usages : génération des
cartes de révision, détection de sortie de répertoire en mode Jouer, et
— indirectement, via `game.moves` directement — le constructeur manuel.

### Fait
- **`ChessLab/OpeningRepertoire/`** (nouveau dossier) :
  - `RepertoireTree.swift` — `childrenByParent(in:)`/`sanPath(to:in:)`/
    `pathKey(to:in:)`, purs.
  - `Repertoire.swift` — `@Model` SwiftData (discipline CloudKit-safe
    habituelle) : `name`, `colorRaw` (+ `color` calculé), `pgn` (source
    de vérité unique — l'arbre de variantes EST le répertoire),
    `createdAt`.
  - `RepertoireItem.swift` — `@Model`, une carte SRS par position où
    l'utilisateur doit trouver un coup : `repertoireID`, `pathKey` (SAN
    joints depuis la racine — identité STABLE à travers les
    régénérations, contrairement à `MoveTree.Index` qui est reconstruit
    à chaque parsing), `fen`, `expectedSANs`/`expectedLANs` (tous les
    enfants à ce nœud — plusieurs réponses "livre" possibles pour une
    même position), champs SM-2 + compteurs (mêmes noms que `Puzzle`,
    ``SpacedRepetition`` réutilisé tel quel, aucune duplication).
  - `RepertoireItemGenerator.swift` — pur (`generate(from:color:)`) +
    `reconcile(repertoire:in:)` côté `ModelContext` : régénère les
    cartes après import/édition en conservant la progression SM-2 des
    `pathKey` déjà connus, insère les nouvelles, supprime les
    orphelines (lignes retirées du répertoire).
  - `RepertoireExitDetector.swift` — pur, marche `sanMoveList` (partie
    du mode Jouer) contre l'arbre du répertoire, retourne le premier
    point de divergence UNIQUEMENT si c'est un coup du CAMP DU
    RÉPERTOIRE qui dévie (un coup hors-livre de l'adversaire n'est pas
    imputable à l'utilisateur, même si la ligne "sort du répertoire" à
    ce moment-là) ; une ligne qui s'arrête simplement (plus aucun coup
    connu) n'est pas une déviation.
  - `RepertoireTrainingViewModel.swift`/`RepertoireTrainingView.swift` —
    résolution d'UNE carte (pas une séquence multi-coups comme un
    puzzle : pas de riposte adverse à auto-jouer, la carte se termine
    dès le premier coup). Coup correct (SAN ∈ `expectedSANs`) → succès
    immédiat ; incorrect → `attemptsRemaining` décrémenté, 0 → flèches
    de révélation vers CHAQUE `expectedLANs` + le premier coup attendu
    est auto-joué (pour que "Continuer contre Stockfish depuis ici"
    parte d'un FEN cohérent avec la suite réelle du répertoire). Même
    gabarit que `PuzzleSolveViewModel`/`PuzzleSolveView`.
  - `RepertoireQueueView.swift` — `@Query` filtrée sur UN répertoire,
    triée par `dueDate`, stats (réussite globale, positions maîtrisées
    `repetitions >= 2`, jamais vues) — même gabarit que
    `PuzzleQueueView`. N'affiche jamais `expectedSANs` dans la liste
    (ce serait donner la réponse avant d'ouvrir la carte) : seul le
    chemin déjà joué (`pathKey`) apparaît.
  - `RepertoireListView.swift` (créer : nom + camp uniquement) +
    `RepertoireDetailView.swift` (Réviser / Construire / Importer un
    PGN — l'import se fait DEPUIS le détail, pas mélangé à la création,
    pour ne pas cumuler deux flux différents dans une seule feuille).
  - `RepertoireBuilderViewModel.swift`/`RepertoireBuilderView.swift` —
    version allégée d'`AnalysisViewModel` SANS moteur ni classification :
    navigation dans l'arbre réel (`goToNext/Previous/goTo`), jouer un
    coup crée une branche via `game.make(move:from:)` (même mécanisme
    natif que l'Analyste), "Enregistrer" persiste `game.pgn` et relance
    `RepertoireItemGenerator.reconcile`.
- **`ChessLab/Board/TextImportSheet.swift`** — extrait de la version
  `private` d'`AnalysisEntryView.swift` à sa deuxième utilisation (import
  de PGN dans un répertoire), `PasteButton` conservé (pas de lecture
  directe d'`UIPasteboard`, piège déjà documenté à l'étape 3).
- **`PlayViewModel`** — `repertoireExitInfo`/`deviatedRepertoire`
  calculés une seule fois dans le `didSet` existant d'`outcome` (pas un
  nouveau site à toucher parmi les ~7 endroits qui affectent `outcome`) :
  seulement si EXACTEMENT un répertoire correspond au camp joué
  (`userColor`). `GameOverCard` affiche "Vous avez quitté votre
  répertoire au coup N — coup prévu : X" + lien "Réviser ce répertoire"
  quand détecté.
- **`ChessLabApp.swift`** — `Repertoire`/`RepertoireItem` ajoutés au
  `Schema` SwiftData.
- **Accueil** — carte "Ouvertures" activée, bandeau "Entraînement du
  jour" enrichi d'un décompte réel ("X ouverture(s), Y puzzle(s) dus",
  deux `@Query` légères), routes `repertoireList`/`repertoireDetail`/
  `repertoireReview`/`repertoireBuild`/`activeRepertoireItem`.

### Décisions d'architecture
- **Chaque position de décision du répertoire est une carte SRS
  indépendante**, plutôt qu'une session qui rejoue toute une ligne du
  début et échoue globalement à la première erreur (à la Chessable/Anki,
  plus proche de l'esprit "sessions quotidiennes priorisant les
  positions faibles ou dues" du brief que d'un simulateur de partie
  complète). Conséquence directe : pas de riposte adverse à auto-jouer
  à l'intérieur d'une carte (le FEN stocké capture déjà tout le contexte
  jusque-là) — modèle nettement plus simple qu'un puzzle multi-coups.
- **Tirage de la réponse adverse en construction/révision : implicite et
  non pondéré** — contrairement au livre intégré du moteur
  (`OpeningBookNode.weight`), le PGN d'un répertoire utilisateur ne
  porte aucune métadonnée de popularité ; l'arbre `ChessKit.Game` ne
  distinguant pas non plus "ligne principale"/"secondaire" par un poids
  numérique, aucune notion de tirage pondéré n'était de toute façon
  applicable ici — chaque branche est un coup "livre" valide au même
  titre.
- **Import remplace tout l'arbre existant** — pas de fusion coup par
  coup entre un PGN réimporté et le répertoire actuel ; la réconciliation
  des cartes (`reconcile`) opère après coup sur le nouvel arbre complet,
  ce qui suffit à préserver la progression SM-2 des positions qui
  survivent au remplacement.
- **Périmètre volontairement réduit**, reporté :
  - File quotidienne VRAIMENT mixte (un seul flux trié
    ouvertures+puzzles ensemble) — seul un bandeau de comptage à
    l'accueil pour l'instant ; chaque file (`RepertoireQueueView`/
    `PuzzleQueueView`) reste consultée séparément.
  - Notification locale optionnelle — hors périmètre du critère
    d'acceptation, nécessiterait une permission système.
  - Détection de sortie de répertoire : seulement si un match NON
    ambigu (exactement un répertoire pour la couleur jouée) — avec
    plusieurs répertoires du même camp, aucune tentative de deviner
    lequel l'utilisateur avait en tête.
  - "Réviser ce répertoire" depuis la fin de partie rouvre la file du
    répertoire entier, pas directement la carte de la position de
    divergence (déjà entièrement identifiable via `pathKey`
    si demandé plus tard — pas un mur architectural, juste hors
    périmètre de cette passe).

### Vérifié
- `xcodebuild test` : 49 tests unitaires (dont les nouveaux
  `RepertoireItemGeneratorTests` et `RepertoireExitDetectorTests`,
  8 tests) + suite UI complète, tous verts sur simulateur iPhone 17.
- Parcours UI temporaire (ajouté puis retiré) : accueil → Ouvertures →
  créer "Italienne" (Blancs) → importer PGN
  "1. e4 e5 2. Nf3 Nc6 3. Bb5" → alerte "3 nouvelle(s) carte(s)" → 3
  positions à réviser confirmées à l'écran → Réviser → carte racine
  (attend 1.e4) → 1.e4 joué → "Bravo !" + "Continuer contre Stockfish
  depuis ici" → retour, carte "e4 e5" (attend 2.Nf3) → 3 coups
  délibérément hors-solution → "Solution révélée" (cavalier auto-joué
  en f3, visible sur la capture). Captures d'écran confirmées
  visuellement à chaque étape clé.
- Piège retrouvé une fois de plus (accessibilité) : les lignes de liste
  d'`RepertoireListView`/`RepertoireQueueView` combinaient plusieurs
  `Text` en un seul libellé imprévisible — corrigé avec un
  `.accessibilityLabel` explicite sur chaque ligne, même remède que
  pour les cartes de l'accueil et le panneau de coups de l'Analyste.
- Piège distinct (pas un bug de l'app) : le conteneur SwiftData local
  n'est PAS remis à zéro par `-resetPlaySettings` (qui ne vide que
  `PlaySettingsStore`/`AutosaveStore`) — des relances répétées du test
  temporaire accumulaient plusieurs répertoires "Italienne", faisant
  échouer la résolution d'élément unique. Contourné en désinstallant
  l'app du simulateur (`xcrun simctl uninstall`) entre les relances de
  ce test précis ; n'affecte pas la suite normale (chaque test
  unitaire/UI existant crée ses propres données dans le même run,
  aucun ne dépend d'un état SwiftData vide au lancement).

### Correctif post-étape 5 — blocage de la file moteur du mode Analyser (2026-07-12)

Bug signalé par l'utilisateur en testant : "je reprends ma dernière
partie et rien ne se passe, ou Stockfish cherche à l'infini sur la
première position." Racine du problème dans
`AnalysisViewModel.startLiveAnalysis()` : le travail mis en file
attendait `await task.value` — la fin de sa PROPRE recherche
`go infinite` — avant de rendre la main. Une recherche infinie ne se
termine que sur réception d'un `.bestmove`, lui-même déclenché
uniquement par un `.stop` explicite ; or, envoyer ce `.stop` nécessite
justement d'exécuter un AUTRE travail sur la même file sérielle — un
travail qui ne peut jamais s'exécuter puisqu'il est mis en file
DERRIÈRE celui qui attend indéfiniment. Conséquence concrète :
`classifyMainLine()` (icônes de coup, précision par joueur, courbe
d'éval) restait bloquée pour toujours dès la toute première ouverture
d'une session d'analyse, et plus aucune navigation ultérieure ne
rafraîchissait quoi que ce soit — exactement les deux symptômes
décrits. Un unique bypass existait (`handleViewDisappear()`, appelé à
la fermeture de l'écran), ce qui masquait le bug tant qu'on ne
restait pas sur l'écran assez longtemps pour observer l'absence de
précision/icônes.

**Corrigé** en deux temps :
1. `setupEngine()` n'appelle plus `startLiveAnalysis()` avant
   `classifyMainLine()` — cette dernière démarre déjà l'analyse en
   continu elle-même une fois terminée (et maintenant aussi dans le cas
   "aucun coup à classifier", branche qui l'omettait auparavant —
   sessions FEN/vierges concernées).
2. Correctif de fond : `startLiveAnalysis()` ne fait plus
   `await task.value` sur la recherche infinie à l'intérieur du travail
   mis en file — la tâche de fond continue de tourner de façon
   détachée (suivie via `liveAnalysisTask`), et c'est le PROCHAIN
   travail mis en file (nouvelle navigation, classification,
   génération de puzzles…) qui l'interrompt via
   `stopLiveAnalysisIfNeeded()`, dans son tour normal. Sans ce second
   correctif, le premier aurait seulement déplacé le blocage à la
   PREMIÈRE navigation au lieu de le supprimer.

Vérifié par un test UI temporaire (ajouté puis retiré) : import d'un
PGN de 8 demi-coups → panneau "Coups et courbe d'éval" ouvert → la
précision par joueur apparaît en ~1s (contre jamais, avant le
correctif) → navigation vers un coup antérieur reste réactive. Capture
d'écran confirmée (courbe d'éval, "96% de précision"/"97% de
précision", liste de coups). Suite complète (49 tests unitaires + UI)
relancée après retrait du test temporaire, tout vert.

Vérifié une seconde fois sur une position FEN précise fournie par
l'utilisateur en cours de milieu de partie (Noir au trait), et sur le
point d'entrée "Dernière partie" spécifiquement (pas seulement "coller
un PGN") — jouer une partie jusqu'à l'abandon, puis Analyser → Dernière
partie : la classification démarre et se termine normalement dans les
deux cas (tests UI temporaires, retirés après confirmation).

### Repositionnement des bandeaux "Le moteur réfléchit"/"Analyse en continu" (2026-07-12)

Signalé par l'utilisateur : ces bandeaux (mode Jouer et mode Analyser)
se superposaient au plateau (texte gris sur `.ultraThinMaterial`,
recouvrant les cases du haut) au lieu d'être positionnés au-dessus.

**Corrigé** dans `PlayView.swift` (`thinkingBadge`) et
`AnalysisView.swift` (`analyzingBadge`) : passés d'un `.overlay(alignment:
.top)` sur le plateau à un élément DANS LE FLUX, au-dessus du plateau
(`VStack { badge; ChessBoardView(...) }`), qui pousse donc légèrement le
plateau vers le bas. Couleur passée de `Theme.textPrimary` (gris/blanc)
à `Theme.warning` (ambre, nouvelle utilisation cohérente avec les
autres indicateurs "en cours"). Pour éviter tout saut de mise en page
quand le bandeau apparaît/disparaît (c'était la raison d'être de
l'ancien overlay), la hauteur du badge reste réservée en permanence
(`.frame(height: 20)`) et seule son opacité bascule selon
`isEngineThinking`/`isLiveAnalyzing`, plutôt qu'un `if` qui
inséterait/retirerait la vue.

Vérifié par un test UI temporaire (ajouté puis retiré) : capture
d'écran confirmant le badge "Analyse en continu — profondeur N" en
ambre, positionné au-dessus du plateau sans recouvrir aucune case
(première tentative de capture ratée à cause d'un délai fixe trop
court avant la première réponse moteur sous charge machine élevée —
corrigé en attendant explicitement l'apparition du badge plutôt qu'un
délai arbitraire, leçon retenue pour les futurs tests d'analyse en
continu).

### Refonte du panneau "Coups et courbe d'éval" (2026-07-12)

Signalé par l'utilisateur : le panneau (feuille modale ouverte via un
bouton, séparée du plateau) était "inutilisable" sur iPhone.

**Corrigé** — proposition présentée et validée avant implémentation :
- **`AnalysisView.iPhoneLayout`** aligné sur `iPadLayout`, déjà correct :
  suppression de la feuille (`showPanelSheet`/`.sheet`) et du bouton
  "Coups et courbe d'éval" qui l'ouvrait ; tout défile désormais
  ensemble dans un unique `ScrollView` (plateau, barre d'éval,
  navigation, courbe, précision, liste de coups) — plus rien à ouvrir
  pour voir la courbe.
- **Pastilles colorées de classification**, à la manière de chess.com,
  à côté du SAN dans la liste de coups (`MoveListPanelView`) : nouvelle
  vue `AssessmentPill`, capsule colorée contenant le symbole NAG
  (`!!`/`!`/`?!`/`?`/`??`), invisible pour un coup non classé. Couleurs
  demandées par l'utilisateur : bleu (`Theme.info`, nouvelle couleur
  ajoutée à `Theme.swift`) pour `!!`/`!`, orange (`Theme.warning`,
  réutilisée) pour `!?`, rouge (`Theme.danger`, réutilisée — couleur non
  précisée par l'utilisateur pour ce groupe, choisie par cohérence avec
  la convention chess.com et les couleurs déjà dans l'app) pour `?`/`??`.
  `MoveListRow` étendu d'un champ `assessment: Move.Assessment` (en plus
  de `assessmentSuffix` déjà existant, conservé pour l'étiquette
  d'accessibilité) pour que la vue puisse choisir la couleur.

### Décisions d'architecture
- Question posée avant implémentation (défilement du plateau avec le
  reste, ou plateau fixe en en-tête pendant que le panneau défile
  seul) — l'utilisateur a choisi l'option la plus simple ("tout défile
  ensemble", comme l'iPad déjà existant), évitant un gabarit de mise en
  page supplémentaire à maintenir.
- **`assessmentSuffix` conservé en plus du nouveau `assessment`** dans
  `MoveListRow` plutôt que remplacé : l'étiquette d'accessibilité du
  bouton de coup (`row.san + row.assessmentSuffix`, ex. "a3??") reste
  la même chaîne texte déjà utilisée par tous les tests UI existants —
  aucune raison de la faire dépendre indirectement de la nouvelle
  pastille visuelle.

### Vérifié
- `xcodebuild build` propre après chaque changement.
- Test UI temporaire (ajouté puis retiré) : import d'un PGN avec deux
  gaffes nettes (`1. e4 e6 2. Nf3 Qh4 3. a3`) → absence confirmée du
  bouton "Coups et courbe d'éval" → classification menée à son terme
  → défilement (glissé unique sur une longue distance depuis une zone
  sous le plateau — `app.swipeUp()` classique démarre au centre de
  l'écran et se fait intercepter par le geste de glisser-déposer des
  pièces du plateau, piège à retenir pour de futurs tests de cet
  écran) → capture d'écran confirmant les deux pastilles rouges "??"
  bien visibles à côté de `Qh4` et `a3` dans la liste, courbe et
  précision affichées sans avoir ouvert quoi que ce soit. Suite
  complète (49 tests unitaires + UI) relancée après retrait du test
  temporaire.

### Import de répertoire depuis une étude Lichess (2026-07-12)

Étude préalable demandée par l'utilisateur ("serait-il possible
d'importer des éléments venant de Lichess ?"), proposition présentée
(base de puzzles CC0, export d'étude en PGN, opening explorer), option
retenue pour ce chantier : import direct d'une étude Lichess publique
dans le mode Ouvertures.

### Fait
- **`ChessLab/OpeningRepertoire/LichessStudyImportService.swift`** —
  service réseau minimal (pas de dépendance tierce, `URLSession`
  directe) :
  - `studyID(from:)` — accepte un lien complet
    (`https://lichess.org/study/XXXXXXXX`, avec ou sans chapitre) ou un
    identifiant nu (8 caractères alphanumériques, le format Lichess).
  - `fetchPGN(from:)` — `GET /api/study/{id}.pgn` (endpoint public,
    licence CC0, aucune authentification requise pour une étude
    publique), retourne le PGN assaini du PREMIER chapitre +
    `chapterCount` total.
  - `splitIntoGames(_:)` — un export multi-chapitres concatène
    plusieurs parties PGN à la suite (chaque chapitre recommence par
    `[Event ...]`) ; seul le premier est utilisé (voir "Simplifié" plus
    bas), le nombre total est renvoyé pour informer l'utilisateur.
- **`RepertoireDetailView`** — nouvelle action "Importer depuis
  Lichess" + feuille dédiée (`LichessImportSheet`, distincte de
  `TextImportSheet` : celle-ci gère un appel réseau asynchrone avec
  indicateur de chargement, pas juste une validation synchrone de texte
  collé). Réutilise ensuite exactement le même chemin que l'import PGN
  manuel (`RepertoireItemGenerator.reconcile`) — aucune duplication de
  logique de réconciliation.

### Décisions d'architecture
- **Deux bugs réels de compatibilité découverts en testant contre une
  VRAIE étude publique** (pas une donnée synthétique) — `ChessKit.PGNParser`
  s'est avéré strictement plus exigeant que ce que les exports Lichess
  produisent naturellement :
  1. `PGNParser.parse` découpe tout le texte par ligne vide et n'en
     tolère qu'UNE seule (celle séparant tags et coups) — au-delà, il
     lève `.tooManyLineBreaks`. Les commentaires d'étude Lichess sont
     très souvent multi-paragraphes, avec des lignes vides internes.
     Corrigé par `collapseExtraBlankLines(_:)` : seule la toute première
     ligne vide rencontrée est conservée, toutes les suivantes sont
     supprimées (les simples retours à la ligne de part et d'autre
     suffisent à garder le commentaire lisible en interne).
  2. `PGNParser.MoveTextParser.parse` exige que le tout premier jeton du
     texte de coups soit un numéro ou un SAN — un commentaire
     d'introduction AVANT le coup 1 (`{ Bienvenue dans ce chapitre… }
     1. e4 …`), pourtant l'usage quasi systématique en tête de chapitre
     Lichess (note pédagogique du chapitre), fait échouer le parsing
     avec `.unexpectedMoveTextToken`. Corrigé par `stripLeadingComment(_:)` :
     retire un ou plusieurs commentaires en tête de texte de coups avant
     de transmettre à `Game(pgn:)` — ce texte pédagogique n'a de toute
     façon aucune utilité pour l'arbre de coups d'un répertoire.
  Diagnostiqué efficacement via un test unitaire de reproduction
  isolée (PGN littéral extrait au `curl` de la vraie réponse Lichess,
  testé directement contre `Game(pgn:)` sans passer par tout le cycle
  UI+réseau à chaque itération) plutôt qu'en itérant sur le test UI
  complet (~45s par tentative) — a permis de trouver les deux causes en
  quelques secondes chacune une fois isolées.
- **Une feuille dédiée plutôt que réutiliser `TextImportSheet`** :
  cette dernière est pensée pour un texte déjà en main, validé de façon
  synchrone (`onConfirm: () -> Void`) — l'import Lichess a un état de
  chargement réseau asynchrone (`isImporting`, bouton désactivé /
  `ProgressView` pendant la requête) que `TextImportSheet` ne
  modélise pas ; plutôt que de dénaturer un composant partagé pour un
  besoin différent, une petite vue dédiée reste plus simple.
- **Périmètre volontairement réduit**, reporté :
  - Seul le PREMIER chapitre d'une étude multi-chapitres est importé —
    fusionner plusieurs arbres de variantes indépendants (chaque
    chapitre Lichess en est un) en un seul répertoire n'a pas de
    résolution évidente sans risquer de mélanger des lignes sans
    rapport entre elles. L'utilisateur est informé du nombre total de
    chapitres dans le message de résultat.
  - Pas de sélecteur de chapitre — importer un autre chapitre précis
    nécessiterait de coller l'URL du chapitre visé (le paramètre est
    déjà extrait et ignoré par `studyID(from:)`, mais rien ne
    l'exploite encore côté requête, qui prend toujours l'étude entière
    puis n'en garde que le premier chapitre).
  - Pas d'étude PRIVÉE (nécessiterait un jeton OAuth Lichess, hors
    périmètre de ce chantier).

### Vérifié
- `xcodebuild test` : 18 nouveaux tests unitaires pour
  `LichessStudyImportService` (extraction d'identifiant, découpage en
  chapitres, LES DEUX assainissements PGN — dont un test de bout en
  bout reproduisant fidèlement le vrai chapitre problématique) — tous
  verts, plus la suite complète (unitaires + UI) inchangée par ailleurs.
- Test UI temporaire (ajouté puis retiré) avec une VRAIE requête réseau
  vers une étude Lichess publique réelle (🎯 Learning the London
  Opening, 13 chapitres, vérifiée accessible avant le test) : créer un
  répertoire → Importer depuis Lichess → coller l'URL de l'étude →
  alerte "2 nouvelle(s) carte(s) de révision créée(s). Cette étude
  contient 13 chapitres — seul le premier a été importé." → "2
  position(s) à réviser" confirmé sur l'écran de détail. Capture
  d'écran confirmée visuellement.

### Bibliothèque de puzzles Lichess embarquée, préchargée automatiquement (2026-07-12)

Suite de l'étude précédente (option B retenue par l'utilisateur), avec
deux précisions demandées ensuite : 10 000 puzzles au total, et
préchargés automatiquement (aucune action de l'utilisateur requise).

### Fait
- **Conversion hors app** (script Python, pas dans le projet Xcode —
  même principe que la génération d'`eco_openings.json`/`opening_book.json` :
  travail ponctuel, aucune dépendance ajoutée à l'app) :
  1. Téléchargement de `lichess_db_puzzle.csv.zst` (licence CC0,
     `database.lichess.org`, ~6,06 millions de puzzles, ~300 Mo compressé).
  2. Filtres qualité : `Popularity > 0`, `NbPlays ≥ 100`, longueur de
     solution entre 2 et 6 demi-coups (le premier coup du champ `Moves`
     Lichess est le coup de MISE EN PLACE de l'adversaire, pas la
     solution — appliqué via `python-chess` pour obtenir le FEN réel du
     puzzle, le reste des coups devenant `solutionLANs`).
  3. Échantillonnage stratifié par réservoir (Algorithme R), en flux
     (le CSV décompressé ne tient pas confortablement en mémoire) : une
     cellule par (tranche de rating de 200 points de 600 à 2400) ×
     (thème tactique parmi checkmate/fork/pin/skewer/discoveredAttack/
     hangingPiece/sacrifice/tactique générique), pour une répartition
     réellement variée plutôt qu'un tirage brut biaisé vers le rating
     le plus fréquent (~1500-1800 dans la base brute). **9 997 puzzles**
     retenus au final (cible 10 000, quelques cellules rares n'ayant pas
     atteint leur quota) — répartition mesurée quasi parfaitement égale
     (~1250 par thème, ~1110 par tranche de rating). Sortie :
     `lichess_puzzles.json` (1,5 Mo), copié dans `ChessLab/Resources/`.
- **`Puzzle`** (modèle SwiftData) étendu de deux champs : `rating: Int?`
  (fourni par Lichess, `nil` pour un puzzle issu de vos parties) et
  `sourceRaw`/`source: PuzzleSource` (`.ownGames`/`.lichess`, même
  patron que `themeRaw`/`theme`). `PuzzleTheme` étendu de `pin`,
  `skewer`, `discoveredAttack`, `sacrifice` (labels français).
- **`LichessPuzzleLoader.swift`** — décode `lichess_puzzles.json`, même
  schéma que `EcoOpeningLoader`/`OpeningBookLoader`.
- **`PuzzleLibrarySeeder.swift`** — précharge la bibliothèque dans la
  base locale, marqueur `UserDefaults` pour ne le faire qu'une seule
  fois (jamais de réinsertion aux lancements suivants, même si
  l'utilisateur supprime des puzzles). Appelé depuis
  `HomeView.onAppear`, différé d'un tick (`Task { @MainActor in }`)
  pour laisser l'accueil s'afficher avant les ~10 000 insertions —
  mesuré à ~2,8s pour l'insertion complète (test unitaire avec conteneur
  en mémoire), imperceptible en pratique dans ce délai différé.
- **`PuzzleQueueView`** — section Statistiques distingue désormais "Vos
  gaffes" (parties perso) de "Bibliothèque Lichess" ; chaque ligne de
  puzzle affiche son rating (pastille discrète) quand disponible ; la
  file "dus" est plafonnée à 20 par séance (voir "Décisions" ci-dessous).

### Décisions d'architecture
- **Plafond de 20 puzzles "dus" par séance** — avec ~10 000 puzzles tous
  `dueDate = Date()` dès l'insertion (immédiatement disponibles, "vous
  n'avez qu'à commencer"), une file sans plafond afficherait la totalité
  d'un coup. Le plafond ne limite que l'AFFICHAGE d'une séance ; les
  puzzles non montrés aujourd'hui restent disponibles ensuite (leur
  `dueDate` n'avance que lorsqu'ils sont effectivement résolus).
- **Thème principal unique par puzzle** (comme pour `Puzzle` issu de vos
  parties) — un puzzle Lichess porte souvent plusieurs tags
  (`"fork sacrifice middlegame"`) ; un ordre de priorité fixe
  (checkmate > fork > pin > skewer > discoveredAttack > hangingPiece >
  sacrifice > repli générique) choisit le plus spécifique. Les tags de
  PHASE de partie (`middlegame`/`endgame`/`opening`) de la proposition
  initiale ont été délibérément exclus du thème affiché/échantillonné
  au moment de l'implémentation : ce ne sont pas des "thèmes tactiques"
  au même titre que fourchette/clouage, les mélanger aurait rendu le
  libellé affiché à l'utilisateur incohérent (montrer "Milieu de
  partie" comme s'il s'agissait d'un type de coup).
- **Playlist/champs "partie d'origine" laissés `nil`** pour un puzzle
  Lichess (`playedMoveSAN`, `sourceGamePGN`) — déjà gérés en optionnel
  par `PuzzleSolveView`/`PuzzleSolveViewModel` existants ("Trouvez le
  meilleur coup" au lieu de "Trouvez mieux que…", bouton "Voir dans la
  partie d'origine" simplement absent) : aucune modification nécessaire
  côté résolution, seule la génération/le préchargement diffèrent.

### Vérifié
- `xcodebuild test` : nouveaux tests unitaires
  (`PuzzleLibrarySeederTests` — bibliothèque bundlée non vide, champs
  bien formés, insertion dans un contexte en mémoire crée exactement
  `LichessPuzzleLoader.standard.count` `Puzzle`) + suite complète
  (70 tests, 11 suites) toujours verte.
- Test UI temporaire (ajouté puis retiré) : lancement de l'app depuis
  zéro (aucune action manuelle d'import) → Puzzles → "Bibliothèque
  Lichess : 9997" visible immédiatement, répartition par thème quasi
  égale confirmée à l'écran (Fourchette/Pièce en prise/Tactique/
  Clouage/Attaque à la découverte/Enfilade/Mat : 1251 chacun,
  Sacrifice : 1240), "Puzzles dus (20 sur 9997)" confirmant le
  plafonnement, ouverture d'un puzzle de la bibliothèque (pastille de
  rating visible, en-tête "Trouvez le meilleur coup" sans référence à
  une partie d'origine). Captures d'écran confirmées visuellement.
- Taille : 1,5 Mo ajoutés au bundle (`lichess_puzzles.json`), négligeable
  à côté des réseaux de neurones Stockfish déjà embarqués (~78 Mo).

### Refonte UX du mode Puzzles : difficulté, phase de partie, trait (2026-07-12)

Demande explicite ("en tant que spécialiste des échecs et de l'UX")
de revoir toute l'interface pour organiser les puzzles par difficulté
et par phase de partie (simplifiées), plus l'indication du trait sur
l'écran de résolution.

### Fait
- **`GamePhase.swift`** — `GamePhase` (`.opening`/`.middlegame`/`.endgame`,
  3 catégories volontairement simples) + `GamePhaseClassifier.classify(fen:)`,
  pur, déduit la phase du SEUL FEN (les puzzles n'ont pas d'historique
  de coups) : finale si peu de pièces majeures/mineures restent (seuil
  différent selon qu'il reste des dames ou non — voir "Décisions"),
  ouverture si coup précoce avec quasiment tout le matériel de départ
  encore là, milieu de partie sinon (repli, le cas le plus fréquent).
  Calculée à la volée (`Puzzle.phase`), jamais stockée : s'applique
  aussi bien à vos gaffes qu'aux puzzles Lichess sans dépendre d'une
  donnée que seule la bibliothèque fournirait.
- **`DifficultyTier.swift`** — 4 paliers lisibles (Débutant/Intermédiaire/
  Confirmé/Expert) sur la plage de rating 600-2400 de la bibliothèque,
  plutôt que d'exposer le nombre brut. `nil` pour un puzzle sans note
  (vos gaffes).
- **`PuzzleQueueView`** repensée : pastilles de filtre à bascule pour la
  difficulté et pour la phase (deux rangées défilables horizontalement,
  combinables), appliquées à la file "dus" ; chaque ligne affiche
  désormais thème + rating + phase (icône et libellé). Section
  Statistiques allégée (vos gaffes / bibliothèque / réussite globale
  seulement — la répartition par thème, moins utile maintenant que les
  filtres permettent d'explorer directement, a été retirée pour ne pas
  surcharger l'écran).
- **`PuzzleSolveView`** — en-tête enrichi de pastilles difficulté + phase
  à côté du thème, et nouvelle indication "Trait aux blancs"/"Trait aux
  noirs" (déduite de `viewModel.orientation`, déjà calculée comme le
  camp au trait sur la position de départ du puzzle).

### Décisions d'architecture
- **Seuil de finale différent selon la présence de dames** — calibré
  empiriquement sur les 9 997 puzzles réellement embarqués (script
  Python de vérification hors app, pas de code ajouté au projet) : un
  seuil unique "≤ 6 pièces majeures/mineures, dames comprises" classait
  à tort **51 %** des puzzles en "Finale" (une position avec deux dames
  et 4 autres pièces s'y engouffrait alors qu'elle est clairement un
  milieu de partie). Deux seuils distincts — ≤ 2 si des dames sont
  encore là (quasiment plus rien d'autre), ≤ 6 sinon — ramène la
  répartition à ~28 % Finale / ~70 % Milieu de partie / ~1 % Ouverture,
  bien plus fidèle à l'intuition d'un joueur : les tactiques se
  produisent surtout en milieu de partie, les finales sont fréquentes
  mais minoritaires, les ouvertures produisent rarement une tactique
  forcée. Leçon retenue : un seuil unique "nombre de pièces" sans
  distinguer si des dames restent est trop grossier, et vérifier
  empiriquement contre les VRAIES données change concrètement la
  décision de seuil plutôt que de deviner un chiffre a priori.
- **Phase et difficulté calculées, jamais stockées** — `Puzzle.phase`/
  `Puzzle.difficultyTier` sont des propriétés calculées (comme
  `Puzzle.theme`/`Puzzle.source` déjà existants), pas des colonnes
  SwiftData : la phase se déduit uniformément du FEN pour n'importe
  quel puzzle (bibliothèque ou perso) sans migration de schéma, et la
  difficulté découle directement de `rating` déjà présent.
- **Filtres appliqués à la file "dus" uniquement, pas aux statistiques**
  — les stats restent une vue d'ensemble stable ; combiner difficulté ET
  phase (ex. "Confirmé" + "Finale") réduit la file en conséquence sans
  jamais la vider complètement pour les combinaisons réalistes (440
  puzzles pour cette combinaison précise sur l'échantillon embarqué).

### Vérifié
- `xcodebuild test` : 7 nouveaux tests unitaires (`GamePhaseAndDifficultyTests` —
  positions réelles caractéristiques de chaque phase, bornes exactes des
  paliers de rating) + suite complète (77 tests, 12 suites) toujours
  verte.
- Test UI temporaire (ajouté puis retiré) : file "dus" filtrée sur
  "Finale" seule (5131 sur 9997, avant calibrage du seuil — confirmé
  trop large, seuil corrigé) puis sur "Finale" + "Confirmé" combinés
  (440, ratings 1625-1994, cohérents avec le palier "Confirmé" choisi)
  → ouverture d'un puzzle de la sélection filtrée → en-tête confirmé
  affichant "TACTIQUE", pastille "Confirmé", pastille "👑 Finale", et
  "Trait aux blancs" sous le titre. Captures d'écran confirmées
  visuellement à chaque étape, y compris la position réellement
  clairsemée (roi + quelques pions) validant visuellement la
  classification "Finale".
- Piège XCUITest retrouvé une fois de plus, nouvelle variante cette
  fois : un bouton (`"Expert"`) EXISTE dans la hiérarchie d'accessibilité
  mais n'est pas "hittable" tant qu'il reste hors du cadre visible de
  son propre `ScrollView` horizontal (erreur "Activation point
  invalid") — contourné en ciblant un filtre déjà visible sans défiler
  plutôt qu'en simulant un défilement horizontal pour cette vérification
  ponctuelle.

### Bibliothèque à 50 000 puzzles, sans répétition avant épuisement, panneau de résultat repensé (2026-07-12, suite)

Trois demandes liées : ne plus présenter plusieurs fois le même puzzle
trop tôt, faire passer la bibliothèque de 10 000 à 50 000 puzzles, et
sortir le résultat (réussite/échec) d'un overlay qui recouvrait le
plateau.

### Fait
- **Ré-échantillonnage à 50 000** (même script Python hors app,
  `TOTAL_TARGET` changé) : **49 473 puzzles** retenus (quelques cellules
  rares n'atteignent pas leur quota), répartition mesurée quasi égale
  par thème (~6 255 chacun, sacrifice 5 688) et par tranche de rating
  (~5 560 chacune, 600-800 à 4 993). `lichess_puzzles.json` passé de
  1,5 Mo à 7,6 Mo.
- **`Puzzle`** — deux champs ajoutés : `externalID: String?` (le
  `PuzzleId` Lichess, clé naturelle pour un réamorçage idempotent) et
  `firstOpenedAt: Date?` (date de la toute première ouverture RÉELLE de
  l'écran de résolution, pas seulement listé dans la file — `nil` tant
  que jamais ouvert).
- **`PuzzleLibrarySeeder`** — déduplique désormais par `externalID` (en
  plus du marqueur `UserDefaults` existant, qui protège le cas courant
  mais pas un double appel avant que ce marqueur n'ait pu être écrit) :
  ne réinsère jamais un puzzle Lichess déjà présent.
- **`PuzzleSolveViewModel.init`** — marque `firstOpenedAt` à la toute
  première ouverture de l'écran de résolution.
- **`PuzzleSessionBuilder.swift`** (nouveau) — logique pure de
  composition de séance : puzzles jamais ouverts d'abord (mélangés
  entre eux), puzzles déjà ouverts ensuite (mélangés entre eux) — ne
  recommence à répéter un puzzle déjà vu qu'une fois tous les inédits
  épuisés pour les filtres actifs.
- **`PuzzleQueueView`** — la séance du jour (`todaysSession`) devient un
  `@State` figé, recomposé via `PuzzleSessionBuilder.buildSession(...)`
  seulement à l'apparition de l'écran et au changement de filtre (pas à
  chaque réévaluation de `body`), pour ne pas réordonner la liste sous
  les yeux de l'utilisateur au moindre re-rendu.
- **Panneau de résultat sorti de l'overlay** — signalé inutilisable
  visuellement ("je ne veux pas que la fenêtre s'affiche devant le
  puzzle, mais en dessous") : `PuzzleSolveView` affiche désormais la
  carte de résultat (`resultCard`) DANS LE FLUX, sous l'échiquier (à la
  place du compteur d'essais une fois le puzzle terminé), jamais en
  `.overlay` opaque par-dessus — la position (et la flèche de solution
  quand elle a été révélée) reste visible en permanence. Deux boutons
  seulement : **"Retour"** (retour à la file de puzzles, pas à
  l'accueil — voir "Décisions") et **"Nouveau puzzle"** (nouveau,
  charge un autre puzzle SANS quitter l'écran).
- **`PuzzleSolveViewModel.loadNextPuzzle()`** (nouveau) — tire un puzzle
  suivant (même priorité "jamais ouvert d'abord" que la file, via
  `PuzzleSessionBuilder`, appliquée ici à un tirage d'un seul puzzle
  parmi tous les puzzles dus, hors le puzzle courant) et réinitialise
  tout l'état de résolution en place (plateau, essais, indices, étape
  courante) — `puzzle`/`orientation` sont passés de `let` à
  `private(set) var` pour permettre cet échange sans recréer la vue.

### Décisions d'architecture
- **"Retour" ramène à la file de puzzles (pop d'un niveau), pas à
  l'accueil** — clarifié explicitement par l'utilisateur en cours de
  demande. `HomeView` : le `onExit` de `PuzzleHost` est passé de
  `path = NavigationPath()` (vidait toute la pile, retour à l'accueil)
  à `path.removeLast()` (ne dépile que l'écran de résolution, revient
  sur la file déjà ouverte juste en dessous dans la pile de
  navigation).
- **"Nouveau puzzle" reste sur le même écran plutôt que de renaviguer**
  — `PuzzleSolveViewModel` détenait déjà le `ModelContext`, échanger son
  `puzzle`/`board`/état interne en place évite un aller-retour par la
  file (route `Route.activePuzzle` figée sur le puzzle initial) et rend
  la boucle "un puzzle après l'autre" plus rapide pour l'utilisateur.
- **Le tirage de "Nouveau puzzle" ignore les filtres actifs de la
  file** (difficulté/phase choisis dans `PuzzleQueueView`) — l'écran de
  résolution n'a aucune notion de ces filtres et n'en reçoit pas ;
  plutôt que de faire transiter cet état à travers `PuzzleHost`/`Route`
  pour un bouton d'appoint, le tirage porte sur l'ensemble des puzzles
  dus. Limitation acceptée sciemment, à revoir si l'usage montre que
  "Nouveau puzzle" est utilisé pour rester dans un filtre précis plutôt
  que pour enchaîner rapidement.

### Vérifié
- `xcodebuild test` : nouveaux tests unitaires — `PuzzleSessionBuilderTests`
  (5 tests : priorité aux jamais-ouverts, pas de doublons, repli sur les
  déjà-ouverts une fois le pool épuisé, plafond respecté) et
  `PuzzleLibrarySeederTests` étendu (`seedingTwiceDoesNotDuplicatePuzzles`,
  vérifie qu'un second appel avant l'écriture effective du marqueur
  `UserDefaults` ne duplique rien grâce à la déduplication par
  `externalID`) — suite complète à **83 tests, 13 suites**, toujours
  verte (l'insertion des 49 473 puzzles en conteneur mémoire prend
  ~15-32s dans les tests, contre ~2,8s pour la précédente bibliothèque
  à 10 000 — coût ponctuel mesuré, pas optimisé davantage).
- Test UI temporaire (ajouté puis retiré) : préchargement des 49 473
  confirmé au premier lancement, ouverture d'un puzzle, coup de pion
  légal rejoué 3 fois pour forcer un résultat (sans connaître la
  solution du puzzle tiré aléatoirement) → capture d'écran confirmant
  le panneau "Solution révélée" / "Retour" / "Nouveau puzzle" affiché
  SOUS l'échiquier, celui-ci restant entièrement visible → "Nouveau
  puzzle" charge une nouvelle position sur le même écran (panneau de
  résultat disparu, plateau réinitialisé) → un second résultat forcé
  puis "Retour" ramène bien sur la file de puzzles (pas l'accueil).
  Suite complète relancée après retrait du test temporaire.

## Révision UX générale — identité affirmée + mouvement (2026-07-14) ✅

Passe transversale de finition visuelle sur TOUS les écrans, demandée
après revue : garder l'identité sombre existante mais l'affirmer
(dégradés, profondeur, couleur par section) et ajouter du mouvement
expressif. Aucune logique métier touchée.

### Fait
- **`Theme.swift` refondu (point de levier)** : presque tout l'UI passe
  par les composants partagés, donc les enrichir propage partout.
  - Dégradé d'accent signature (émeraude → sarcelle, `accentGradient`),
    fond d'ambiance `AppBackground` (halos radiaux diffus) via
    `.appBackground()`, teintes par section (`violet`/`rose`/`teal`…).
  - Composants réutilisables neufs : `PressableButtonStyle`
    (`.buttonStyle(.pressable)`, contraction au toucher), `GlowModifier`
    (`.glow(_:)`), `IconBadge` (pastille d'icône colorée), `CelebrationView`
    (confettis), jetons de mouvement (`Theme.spring`/`snappySpring`).
  - `CardBackground`, `ChipButton`, `FilterChip` enrichis (dégradé +
    ombre + lueur d'état sélectionné) — donc cartes, chips et filtres de
    tout écran héritent du nouveau look sans édition locale.
- **Écrans élevés** (accueil, Jouer, Deux joueurs, Analyser + entrée +
  bibliothèque, Puzzles solve/queue, Ouvertures liste/détail/révision/
  bibliothèque/lignes/constructeur, réglages des deux modes, diagnostic,
  plateau, barre d'éval) : cartes de mode tintées à glyphe décoratif,
  pendule/joueur actif surligné+lueur, **confettis à la victoire et au
  puzzle résolu**, cartes de fin animées (entrée en ressort, trophée qui
  pulse), CTA en dégradé, plateau avec relief (ombre + liseré), courbe
  d'éval lissée à remplissage dégradé, tuiles de stats homogènes.
- **Piège corrigé** : sur un `Button("titre", action:)` (label chaîne),
  appliquer `.buttonStyle(.pressable)` APRÈS un `.background()` ne fait
  se contracter que le texte, pas le fond. Les CTA concernés (cartes de
  fin de partie/puzzle) sont repassés en forme `Button { } label: { … }`
  pour que toute la capsule réagisse.

### Vérifié
- Build Debug vert (iPhone 17 Pro) à chaque lot d'écrans + build final.
- App lancée sur simulateur, capture de l'accueil confirmant fond
  d'ambiance, carte "hero" du jour et tuiles de mode tintées.

## Étape 6 — Laboratoire (Stockfish vs Stockfish) ✅ (2026-07-14)

✓ = série de 20 parties avec stats, reprise après fermeture de l'app.
La boucle moteur-contre-moteur en direct (série de 20, position à
56 demi-coups, UI réactive, tuiles de stats) a été confirmée à l'écran ;
les stats, la persistance et la reprise sont couvertes par des tests
unitaires déterministes (voir "Vérifié").

### Fait
- **`ChessLab/Laboratory/`** (nouveau dossier) :
  - `LabStats.swift` — pur, testable sans moteur : score, %,
    écart Elo estimé (`−400·log₁₀(1/score − 1)`), intervalle de confiance
    à 95 % (erreur standard du score → bornes Elo), LOS (approximation
    normale sur parties décisives, via `erf`), longueur moyenne.
  - `LabGameSettings.swift` — réglages (Elo indépendant par camp A/B,
    livre par camp, `movetimeMs`, `gameCount` 1–500, alternance des
    couleurs, FEN de départ, adjudication, mode rapide) + persistance :
    `LabSettingsStore` (derniers réglages), `LabSeriesState` +
    `LabAutosaveStore` (état complet de la série sauvegardé **après
    chaque partie** dans Documents → reprise après fermeture de l'app).
  - `LabViewModel.swift` — `@Observable @MainActor`, un seul
    `EngineController` sert les deux camps (on repousse les `setoption`
    du camp au trait avant chaque coup, commutation bon marché sans
    second process). Livre par camp, fins terminales
    (`GameOutcome.fromBoardState`) + adjudication (nulle si éval ~0
    prolongée après un minimum de coups ; gain si |éval| ≥ 8 pions
    prolongé), pause/annulation, reprise (`init(resuming:)`).
  - `LabExport.swift` — export PGN (parties concaténées) + CSV (une ligne
    par partie), purs.
  - `LabSetupView.swift` / `LabRunView.swift` — configuration (avec
    bannière "Reprendre la série" si une sauvegarde existe) et écran
    d'exécution : progression, plateau en direct, tuiles de stats,
    répartition V/N/D, pause/arrêt, export PGN/CSV — dans le nouveau
    langage visuel.
- **Accueil** : carte "Laboratoire" activée (routes `labSetup`/
  `activeLab`/`resumedLab` + `LabHost` paresseux, même gabarit que les
  autres hôtes).

### Décisions d'architecture
- **Bug réel (gel/crash intermittent de la série) — deux causes,
  corrigées.** Signalé à l'usage ("des fois ça se fige et ça avance plus").
  1. *Saturation du `MainActor`* : la première version consommait le flux
     de réponses moteur (des centaines de lignes `info` par recherche) sur
     le `MainActor`. Indolore sur une partie brève (mode Jouer), mais en
     série continue ça monopolise le fil principal. Déplacé sur l'acteur
     moteur (`EngineController.computeBestMove(...)`), hors MainActor.
  2. *Itérateurs multiples sur un `AsyncStream` unique* (cause du gel
     intermittent restant) : le flux de ChessKitEngine est UN SEUL
     `AsyncStream` à itérateur unique. Recréer un `for await` à chaque
     coup revient à créer des centaines d'itérateurs successifs sur le
     même stream — **non supporté par Swift** (éléments perdus, voire
     crash intermittent) : de loin en loin, le `bestmove` passait entre
     deux itérateurs, la recherche n'aboutissait pas et la série se
     figeait, ou l'app se terminait. Diagnostiqué en samplant le
     processus (app terminée sous ~45 s de série) après une capture
     montrant une partie bloquée. **Corrigé** : un lecteur UNIQUE et
     persistant (`ensureReader`) consomme le flux une seule fois pour
     toute la vie de l'`EngineController` ; chaque `computeBestMove` dépose
     une continuation que le lecteur réveille au `bestmove` suivant.
     Garde-fous conservés : `.stop` forcé si la recherche déborde son
     budget (bestmove immédiat), borne dure renvoyant `nil` plutôt que de
     bloquer. Vérifié : série de 20 parties qui défile sans accroc (11+
     parties terminées, stats à jour, app vivante) sur une fenêtre longue.
  - Note : `computeBestMove`/le lecteur ne servent QU'au Laboratoire ;
    les modes Jouer/Analyser gardent leur `EngineController` propre et
    leur consommation directe du flux (une recherche à la fois, non
    concernée).
- **Camps A/B abstraits plutôt que Blanc/Noir** : l'alternance des
  couleurs étant résolue en amont, les stats rapportent tout au camp A
  (réglage fixe), ce qui donne un écart Elo non biaisé par l'avantage des
  Blancs.
- **Abandon / nulle par accord configurables** (demande utilisateur) :
  l'ancien réglage unique "Adjuger les parties décidées" est scindé en
  deux interrupteurs indépendants — "Abandon autorisé (camp perdant)"
  (un camp menant de ≥ 8 pions de façon prolongée fait abandonner
  l'autre) et "Nul par accord autorisé" (position ~nulle prolongée). Les
  nulles **selon les règles** (mat impossible = matériel insuffisant,
  pat, 50 coups, répétition) restent, elles, TOUJOURS déclarées via
  `GameOutcome.fromBoardState`, indépendamment de ces deux réglages.
- **Périmètre volontairement réduit**, reporté (même esprit que les
  étapes précédentes) : visualisation live des variantes en réflexion
  (flèches info pv) non affichée ; histogramme de longueurs simplifié en
  répartition V/N/D ; vue "tournoi" iPad côte à côte non spécialisée ;
  seuils d'abandon/nulle fixes (les réglages exposent l'activation, pas
  les seuils eux-mêmes).

### Vérifié
- `xcodebuild test` (`ChessLabTests`) vert — suite passée à ~104 tests /
  17 suites avec l'ajout de `LabStatsTests` (score/Elo/IC/LOS/longueur),
  `LabCompletedGameTests` (mapping résultat↔camp), `LabExportTests`
  (PGN/CSV) et `LabPersistenceTests` (round-trip `LabSeriesState`,
  point de reprise, `LabViewModel(resuming:)` repart à la bonne partie).
- Test UI temporaire (ajouté puis retiré) : accueil → Laboratoire →
  Lancer → l'écran d'exécution démarre, le compteur de demi-coups grimpe
  et l'UI reste réactive pendant les calculs (preuve de la correction du
  gel). Capture d'écran confirmant une partie moteur-contre-moteur en
  cours (56 demi-coups) avec toutes les tuiles de stats. Retiré ensuite,
  la suite permanente ne gardant que les tests déterministes (convention
  du projet pour les tests dépendant du moteur).

## Phase 0 (final-1407) — Revue de bugs du 14/07 : les 19 corrections ✅ (2026-07-15)

Traitement intégral de `bug-1407.md` (1 critique, 10 importants, 8 mineurs),
soit les lots 0.1 à 0.4 de `final-1407.md` en une passe — l'étape 7 (scanner)
branchera de nouveaux flux sur ces chemins, ils devaient être sains d'abord.

### Fait
- **n°1 + n°19 (critique) — garde de couleur sur le chemin drag & drop.**
  `board.position.piece(at: start)?.color == …` ajouté dans les 7
  `attemptMove`/`attemptUserMove` (Play, TwoPlayer, Analysis,
  RepertoireBuilder, Puzzle, RepertoireTraining, OpeningLineTraining) : ni
  `Board.canMove` ni `legalMoves` ne consultent le trait, et `Position.move`
  le bascule inconditionnellement — seul le chemin tap-tap était protégé.
  Défense supplémentaire : `ChessBoardView.draggableColor` (nouveau
  paramètre, `nil` = les deux couleurs) n'attache le `dragGesture` qu'aux
  pièces de la couleur concernée. Ne touche QUE le glissement : le tap sur
  une pièce non glissable traverse jusqu'à la case sous-jacente, donc la
  capture au tap-tap continue de fonctionner.
- **n°2 — pendule affichée figée.** `GameClock.displayRemaining(for:)`
  (propriétés PUBLIÉES) pour les vues ; `remaining(for:)` reste réservée à
  la logique (budget moteur, autosave) et le documente. Les vues lisaient
  `remaining(for:)`, adossée aux temps `@ObservationIgnored` : aucune
  invalidation SwiftUI, le temps ne bougeait qu'au coup suivant.
- **n°3 — interblocage indice / fin de partie.** `interruptHintAnalysisIfNeeded()`
  (hors file) dans le `didSet` d'`outcome`, AVANT `releaseEngine()` dont le
  `stopHintIfNeeded` était enfilé derrière le maillon d'indice qu'il devait
  débloquer.
- **n°4 — pendule non redémarrée à la reprise.** `clock?.startTurn(for:)`
  (sans `previousMover`, donc sans incrément) dans les deux `init(resuming:)`.
- **n°5 — échec de démarrage moteur silencieux.** `start()` est désormais
  contrôlé : `isEngineUnavailable` sur `PlayViewModel`/`AnalysisViewModel` +
  bannière « Moteur indisponible ». Le contrôleur en échec n'est PAS conservé
  (`Engine.send` ignore silencieusement toute commande hors service).
  C'est la base du Lot 2.A (bouton « Réessayer »).
- **n°6 — replay d'autosave corrompu.** `replay(lans:)` renvoie `Bool` et
  s'arrête au PREMIER LAN inapplicable ; les `init(resuming:)` échouent alors
  et purgent l'autosave → « Reprise impossible ». `TwoPlayerViewModel.init(resuming:)`
  devient failable (comme celui de Play) ; `TwoPlayerResumedGameHost` affiche
  le même `ContentUnavailableView` que `ResumedGameHost`.
- **n°7 — position de départ déjà terminée.** `GameOutcome.ofStartingPosition(_:)`
  + `PlayViewModel.outcome` calculé aux deux init ; `bestmove (none)` et tout
  coup inapplicable traités explicitement (`endGameIfPositionIsTerminal`) ;
  `FENValidator` refuse une position sans coup légal pour le camp au trait.
- **n°8 — PGN vers l'analyse.** `PGNExport.pgn(for:)` dans le `gameOverPanel`
  de `PlayView` (et harmonisé dans `TwoPlayerGameView`) : `game.pgn` brut
  n'émet pas `[SetUp]/[FEN]`, l'analyse d'une partie à FEN personnalisé
  rechargeait les coups depuis la position standard → analyse vide.
- **n°9 — classification d'analyse non annulée.** Drapeau `isTornDown`
  (`handleViewDisappear`/`handleViewAppear`) vérifié en tête de chaque maillon
  de file, dans la boucle de classification, et avant tout `startLiveAnalysis()`.
- **n°10 — barrière `isready`/`readyok`.** `EngineController.synchronize()`
  appelée avant chaque recherche (`quickScore`, `updateEvalBar`,
  `requestEngineMove`, indice, live, `rankedEval`) : jette les `info` en retard
  de la recherche précédente (ChessKitEngine crée une `Task` non structurée par
  ligne UCI, l'ordre n'est pas garanti sous rafale).
- **n°11 — coup fantôme entre deux puzzles.** `revealTask` suivie et annulée
  par `loadNextPuzzle`, + `guard !Task.isCancelled` après le `sleep` (que
  `try?` avalait).
- **n°12 — `computeBestMove`.** Borne dure : `hardStopIfPending` note le
  `bestmove` à venir comme périmé (`staleBestmovesToDiscard`) et envoie `.stop`,
  au lieu de le laisser résoudre la requête SUIVANTE avec un coup calculé pour
  une autre position ; réentrance : toute continuation encore en attente est
  résolue (`nil`) avant d'installer la nouvelle.
- **n°13 — `LabViewModel.cancel()`** ne remet plus `runTask`/`isRunning` à zéro
  (c'est la fin réelle de `runSeries` qui le fait) : sinon un `start()` pendant
  l'arrêt lançait une seconde série concurrente, inannulable.
- **n°14 — alerte gaffe** silencieuse si le mat était déjà subi avant le coup
  (`b.mate < 0`), symétrique du garde existant pour `missedMate`.
- **n°15 — `HintMove.id`** composite (rang + cases) : plusieurs coups acceptés
  par une carte de répertoire produisent des flèches toutes de rang 1.
- **n°16 — annulation de promotion** (tap hors du sélecteur) sur les 5 écrans
  qui en manquaient (Analyse, Puzzle, RepertoireTraining, RepertoireBuilder,
  OpeningLineTraining).
- **n°17 — Diagnostic moteur** : `status = .failure(...)` quand `start()` échoue
  (le cas n'était jamais produit ; l'écran restait à « Démarrage… »).
- **n°18 — `PGNSanitizer`** : les lignes vides de TÊTE sont retirées avant
  l'aplatissement (elles consommaient l'unique séparateur conservé).

### Décisions d'architecture
- **`GameOutcome.ofStartingPosition(_:)` sonde la position MIROIR** (même
  échiquier, trait inversé, via le FEN). La correction proposée par la revue
  (`outcome = outcomeIfGameEnded()` à l'init) ne pouvait PAS marcher seule :
  vérifié dans les sources ChessKit, `Board.updateState()` n'appelle
  `checkState(for:)` qu'avec le camp au trait, or cette fonction inspecte
  l'ADVERSAIRE de la couleur reçue — un mat/pat du camp au trait laisse donc
  `state == .active` et `fromBoardState` renvoie `nil`. Le miroir remet le camp
  réellement au trait dans le rôle inspecté. Cantonné à `.checkmate`/`.stalemate`
  (les autres nulles sont déjà vues correctement à l'init).
- **`outcomeIfGameEnded()` bascule sur `moveLog.isEmpty`** : la sonde miroir ne
  sert que sur une position de départ (aucun coup joué) ; dès qu'un coup est
  joué, `board.state` est complet et fait autorité — pas de coût par coup.
- **Barrière UCI placée AVANT chaque recherche** plutôt qu'après chaque
  `bestmove` consommé (les deux étaient proposés) : couvre aussi les
  consommateurs qui quitteraient leur boucle en cours de route.
- **`PlayViewModel.blunderSeverity(before:after:)` extraite en statique pure**
  (la version `async` l'appelle) : la règle du n°14 est ainsi testable sans
  moteur. Seul refactor de la passe — aucun changement de comportement.
- **`PendingBlunderWarning.Severity: Equatable`** pour les assertions de test.

### Vérifié
- `xcodebuild test` (`ChessLabTests`) vert : **155 tests / 24 suites** (104 →
  130 avant la passe, +25 avec `BugFixes1407Tests`).
- Nouvelle suite `BugFixes1407Tests` — un test par bug testable unitairement
  (n°1, 4, 6, 7, 8, 14, 15, 18, + n°19). Aucun ne démarre Stockfish : les VMs
  retenus sont sans moteur, ou dans un état où le moteur n'est jamais créé
  (un FEN terminal fait sortir `setupEngine` avant la création du contrôleur).
- **Tests prouvés utiles** : garde de couleur retiré temporairement →
  `twoPlayerRefusesDraggingAPieceOfTheSideNotToMove` et
  `twoPlayerKeepsColorsAlternatingAfterAWrongColourDrag` échouent en
  reproduisant exactement la corruption décrite (`moveLog → [e5]`, puis deux
  coups blancs d'affilée). Garde restauré, suite re-verte.
- `chessKitItselfAllowsMovingThePieceOfTheSideNotToMove` et
  `chessKitDoesNotSeeCheckmateOfTheSideToMoveOnAFreshBoard` verrouillent les
  deux comportements de ChessKit dont dépendent les corrections n°1 et n°7 : si
  une future version de la lib les change, ces tests le signalent.

### Reste à faire (reporté, documenté)
- **n°12 non testé unitairement** : `EngineController` démarre un vrai
  Stockfish. Sa couverture est le Lot 6.B de `final-1407.md` (« moteur simulé »
  injecté), qui prévoit explicitement ce cas (`bestmove (none)`, réponses
  tardives après timeout) — à faire là, pas avant.
- **n°3, 5, 9, 10, 11, 13 non testés unitairement** pour la même raison
  (concurrence/moteur) ; corrigés et relus, à couvrir avec l'injection du 6.B.
- `AnalysisViewModel.exportedPGN` renvoie `game.pgn` brut : même défaut que le
  n°8 (une session d'analyse ouverte sur un FEN exporte un PGN non rechargeable).
  HORS périmètre de la revue, non corrigé ici — à traiter avec le Lot 5.I
  (persistance des analyses) ou en correction dédiée.

## Phase 1 (final-1407) — Lot 1.A : éditeur graphique de position ✅ (2026-07-15)

Premier lot de l'étape 7 (la seule du plan d'origine jamais commencée).
L'éditeur d'abord, comme prévu : c'est le **fallback exigé par le prompt**
quand le scanner se trompe, et le socle de son écran de confirmation
(Lot 1.D). Nouveau dossier `ChessLab/PositionEditor/`.

### Fait
- **`PositionEditorViewModel`** (`@Observable @MainActor`, sans moteur, pur) :
  grille libre `[Square: Piece]`, trait, 4 droits de roque, case en passant,
  orientation d'affichage, outil de palette (12 pièces + gomme). Génération
  du FEN à 6 champs écrite à la main (compteurs figés à `0 1` : un éditeur ne
  connaît pas l'historique) et validation continue déléguée à
  `FENValidator.errors(in:)` — `errors` / `isValid` exposés. `init(fen:)` et
  `load(fen:)` pour le pré-remplissage du Lot 1.D ; un FEN illisible retombe
  sur la position standard.
- **Cohérence automatique** : les droits de roque devenus impossibles (roi ou
  tour hors de sa case) et une case en passant périmée sont **élagués à chaque
  mutation** plutôt que signalés en erreur. Idem à la lecture d'un FEN
  incohérent (le scanner en produira).
- **`PositionEditorBoardView`** : grille 8×8 tapable dédiée, sans aucune règle
  du jeu, réutilisant `BoardTheme` + `PieceGlyphView` (identifiants
  `square_xx`, libellés d'accessibilité explicites).
- **`PositionEditorView`** : plateau + palette (2 rangées × 6 + gomme,
  sélection à l'accent), chips Standard / Vider / Inverser, sections Trait,
  Roques, Prise en passant, FEN affiché, bandeau d'erreurs, actions de sortie
  désactivées tant que la position est invalide. Habillage `Theme` uniquement.
- **`PieceNaming`** : nom français d'une pièce isolée (accord en genre), pour
  les libellés d'accessibilité du plateau ET de la palette. Distinct de
  `MoveNarration`, qui verbalise un COUP à partir de son SAN.
- **Branchements** : `Route.positionEditor(String?)` + carte « Éditeur de
  position » dans `AnalysisEntryView` ; bouton « Ouvrir l'éditeur » dans la
  section Départ de `NewGameSetupView`. Jouer → `playFromPosition(fen)`
  (existant), Analyser → `.fen(fen)` (existant).

### Décisions d'architecture
- **Grille dédiée plutôt que `ChessBoardView`** (option laissée ouverte par le
  plan) : `ChessBoardView` s'appuie sur un `Board` ChessKit (coups légaux,
  échec, dernier coup, drag) alors qu'un éditeur manipule des positions
  arbitraires, souvent illégales et parfois sans roi. Seuls le thème et les
  glyphes sont partagés — le rendu reste identique au reste de l'app.
- **Sorties de l'éditeur = un mode explicite** (`PositionEditorView.Exit`) :
  `.standalone` (l'éditeur route lui-même vers Jouer/Analyser, et plus tard
  Labo) ou `.picker` (une seule action, qui REND le FEN à l'appelant).
  Motif : ouvert depuis `NewGameSetupView`, un bouton « Jouer » aurait
  redémarré sur les réglages MÉMORISÉS en jetant la couleur/force/cadence que
  l'utilisateur venait de choisir à l'écran. D'où la feuille `.picker` qui
  remplit le champ FEN de la section Départ et laisse « Commencer » décider.
  `.standalone` accepte `onUseAsLabStart` optionnel : bouton masqué tant que
  `LabSetupView` n'expose pas `startFEN` (Lot 1.D), sans rien à recâbler.
- **Rangée de la case en passant déduite du trait** (6 si les Blancs jouent,
  3 sinon) et jamais saisie ; seules les colonnes réellement plausibles sont
  proposées (le pion doit être là, les deux cases traversées libres). Un
  changement de trait la périme donc et l'efface.
- **`State(initialValue:)` assumé ici** : la règle de l'hôte paresseux
  (`ActiveGameHost`) vise les ViewModels à effet de bord (moteur) ; celui-ci
  n'en a aucun.

### Vérifié
- `xcodebuild test` vert : **174 tests / 25 suites** (155 → 174, +19 avec
  `PositionEditorTests`) + les 5 tests UI existants (5/5).
- `PositionEditorTests` couvre les critères du lot : aller-retour grille → FEN
  → `Position(fen:)` → grille, FEN standard généré == `Position.standard.fen`,
  positions invalides signalées (2 rois blancs, pion en 8e, plateau sans roi),
  élagage des roques et de la case en passant, chargement d'un FEN incohérent,
  orientation sans effet sur le FEN.
- **Vérification visuelle par test UI temporaire** (captures relues, test
  retiré ensuite — convention du projet). Elle a trouvé DEUX défauts que les
  tests unitaires ne pouvaient pas voir :
  1. **Cases occupées introuvables pour XCUITest** : sans
     `.accessibilityElement(children: .ignore)`, une case portant un glyphe
     n'est pas un élément unique et `square_e2` ne répondait pas (les cases
     VIDES, elles, répondaient). `ChessBoardView` y échappe sans le savoir :
     ses pièces vivent dans une couche séparée de ses cases. Piège noté en
     commentaire — le test UI de bout en bout du Lot 1.D en dépend.
  2. **Pièces noires illisibles dans la palette** (fond sombre) : corrigé avec
     le contour `PieceGlyphView(outline:)`, la solution déjà retenue pour le
     bandeau des prises.
- Captures relues confirmant : position standard, pose d'une pièce, décochage
  AUTOMATIQUE du petit roque blanc à la suppression de la tour h1 (FEN passé
  à `Qkq`), plateau vide → bandeau d'erreur + sorties désactivées.
- **Aléa signalé** : `testMoveWhileHintAnalyzingDoesNotDeadlock` a échoué une
  fois dans une exécution complète, puis est repassé seul et en suite complète
  (5/5 deux fois). Test dépendant du timing du moteur, sans rapport avec ce
  lot (il ne touche pas l'éditeur) — non-déterminisme déjà documenté.

### Reste à faire (Lot 1.D)
- Bouton « Départ du Laboratoire » : `onUseAsLabStart` est prêt et câblé,
  il attend l'exposition de `LabGameSettings.startFEN` dans `LabSetupView`.

## Phase 1 (final-1407) — Lot 1.B : sources d'image, caméra et redressement ✅ (2026-07-15)

Nouveau dossier `ChessLab/Scanner/`. Le pipeline image → 64 vignettes, sans
aucune reconnaissance de pièce (c'est le Lot 1.C).

### Fait
- **`BoardQuad`** : les 4 coins + l'homographie carré unité → quadrilatère
  (méthode de Heckbert), les 81 intersections de la grille 8×8, le
  quadrilatère d'une case, l'aire, le tri de 4 points quelconques en
  TL/TR/BR/BL (Vision ne garantit pas l'ordre), la convexité. **Convention
  posée pour tout le scanner** : pixels, origine en HAUT à gauche ; les
  conversions vers Vision (normalisé, origine en bas) et CoreImage (origine
  en bas) sont faites À LA FRONTIÈRE de ces frameworks.
- **`ScanSource`** : `.screenshot` / `.screenPhoto` / `.physicalTopDown`,
  avec libellé, icône et consigne de prise de vue. Choix EXPLICITE en v1.
- **`BoardDetector`** (Vision) : `VNDetectRectanglesRequest` réglé pour un
  quasi-carré (`minimumAspectRatio` 0.8, `minimumSize` 0.2), plus grand
  candidat retenu. Pour `.screenPhoto`, second passage À L'INTÉRIEUR du
  rectangle trouvé (souvent l'écran entier), retenu seulement s'il est
  nettement plus petit.
- **`BoardRectifier`** : `CIPerspectiveCorrection` → carré 800 px (100 px par
  case : assez pour un glyphe, et le sous-échantillonnage atténue le moiré
  d'une photo d'écran) → découpe en 8×8 vignettes, ligne 0 en haut. **Aucune
  notion de case d'échiquier** ici : une photo zénithale n'a pas
  d'orientation de référence, la correspondance grille → `Square` est décidée
  au Lot 1.C.
- **`BoardCropView`** (livrable obligatoire) : 4 poignées draggables +
  **grille 8×8 projetée en temps réel**, pré-positionnées sur la détection
  auto ou, à défaut, à 10 % de l'image. `ImageDisplayTransform` extrait à
  part pour que les deux sens de conversion restent exactement inverses.
- **Entrées d'image** : `PhotosPicker`, `CameraPicker`
  (`UIImagePickerController` encapsulé, bouton masqué sur simulateur),
  `.dropDestination` (iPad, sur tout l'écran) et `fileImporter`.
  `INFOPLIST_KEY_NSCameraUsageDescription` ajouté aux build settings Debug ET
  Release (l'un des rares cas légitimes d'édition du `.pbxproj`).
- **`BoardImageRenderer`** : rendu bitmap d'un plateau/d'une case depuis une
  position. Sert DEUX besoins d'un même code : les gabarits du template
  matching (Lot 1.C) et les images de test injectées.
- **`ScanTestImage`** + argument `-scanTestImage <nom>` : `synthetic`,
  `fen:<FEN>` ou le nom d'une image du bundle. Les sélecteurs système étant
  hors process, c'est la seule façon de tester le parcours en XCUITest —
  prévu par le plan pour le Lot 1.D, écrit ici car il sert déjà.
- Route `.scanner` + carte « Scanner une position » dans `AnalysisEntryView`.
  L'étape finale affiche pour l'instant le plateau redressé ; le Lot 1.C
  branchera la classification à cet endroit exact.

### Décisions d'architecture
- **La détection auto n'est jamais une vérité** : elle ne fait que
  pré-positionner les poignées. En cas d'échec, cadre à 10 % plutôt qu'un
  message d'erreur — l'ajustement manuel est le vrai filet de sécurité.
- **Convexité obligatoire avant redressement** (voir « Vérifié »).
- **Orientation de l'image normalisée AVANT tout** : une photo verticale
  porte son orientation dans les métadonnées, `cgImage` rend les pixels
  bruts. Sans ça, tout le pipeline travaillerait sur une image couchée.
- Image de travail bornée à 1600 px : une photo de 12 Mpx ne rend pas la
  détection meilleure, seulement plus lente.

### Vérifié
- Suite complète verte : **202 tests / 27 suites** (174 → 202, +28) + 5 tests
  UI. `BoardQuadTests` (20) et `BoardRectifierTests` (8).
- Tests significatifs plutôt que décoratifs :
  - le centre du carré unité tombe sur **l'intersection des diagonales** du
    quadrilatère — propriété projective forte qu'une homographie fausse rate ;
  - sous perspective, les rangées du fond se **resserrent** (sinon la
    projection serait affine et la découpe se décalerait sur les photos) ;
  - plateau synthétique à **couleurs uniques par case** → déformé selon un
    quadrilatère connu → redressé → chaque vignette retrouve SA couleur. Sur
    un simple damier, une inversion lignes/colonnes passerait inaperçue.
- **Défaut trouvé par la vérification visuelle** (test UI temporaire, retiré) :
  un cadrage **croisé** (coin haut gauche glissé sur le coin bas droit)
  produisait une image redressée coupée en diagonale, **sans aucun message**.
  Le garde d'aire (`> 100`) ne pouvait pas l'attraper : ce cadrage a une aire
  de **24 000 px²**. Corrigé par `BoardQuad.isConvex` (signe des produits
  vectoriels des arêtes consécutives) : contour et poignées passent au rouge,
  validation désactivée, message explicite. Deux tests verrouillent le cas
  exact + le nœud papillon.
  ⚠️ Mes deux premiers cas de test de convexité étaient FAUX (un rectangle
  parcouru dans l'ordre, et un triangle avec un point sur une arête) : c'est
  l'implémentation qui avait raison. Cas remplacés par de vraies figures
  dégénérées.
- Autres défauts vus à la capture et corrigés : « Changer d'image » tronquait
  le titre de l'écran (→ « Changer ») ; l'aperçu en `Image(decorative:)` est
  masqué à l'accessibilité par définition, donc invisible aux tests ET à
  VoiceOver (→ `.accessibilityElement()`).
- L'image de test synthétique est rendue **avec une marge** : sans elle, le
  plateau touche les bords, Vision n'a aucun bord franc et la détection auto
  échoue — une vraie capture d'écran a toujours une interface autour.
- Capture finale relue : image de test → détection auto → redressement → la
  position sicilienne (1. e4 c5) ressort exactement cadrée sur les bords du
  plateau.

### Reste à faire
- Fixtures d'images RÉELLES (Lot 1.C) : **action utilisateur**, l'agent ne
  peut pas les produire.

## Phase 1 (final-1407) — Lot 1.C : lecture des diagrammes numériques ✅ (2026-07-15)

Reconnaissance des pièces sur capture d'écran et photo d'écran, par
corrélation contre des gabarits. Le plateau réel est le Lot 1.E.

### Fait
- **Architecture « prête pour CoreML »** (exigence du prompt) :
  `SquareOccupancy` (`.empty` / `.piece(color:kind:)`, `kind` optionnel =
  « à préciser »), `SquareReading` (+ confiance), protocole
  `SquareClassifying`. Un classifieur CoreML pourra se substituer sans que
  rien d'autre du pipeline ne bouge.
- **`TemplateSquareClassifier`** : gabarits = les 12 pièces rendues par
  `BoardImageRenderer` sur la case claire ET sombre de chaque thème, à
  3 échelles de glyphe (216 gabarits), réduits en niveaux de gris 32×32.
  Mesure = **corrélation croisée normalisée (ZNCC)**, invariante à toute
  transformation affine de la luminosité. Case vide détectée par l'écart-type
  AVANT tout matching (sinon un gabarit quelconque « gagne » sur du bruit).
  Seuils abaissés pour `.screenPhoto` (moiré, reflets) : mieux vaut une case
  signalée qu'une erreur silencieuse.
- **Confiance = qualité du score ET avance sur la meilleure AUTRE pièce.** Un
  cavalier à 0.90 avec le fou à 0.89 n'est pas une lecture sûre : c'est
  exactement le cas à soumettre à l'utilisateur.
- **`BoardScanReading`** : grille de lectures → `[Square: Piece]` selon
  l'orientation, cases peu sûres, cases sans type, et génération du FEN.
  `BoardReadingRotation` : 0°/180° pour un diagramme numérique, 4 quarts de
  tour pour un plateau réel. `suggestedRotation()` tranche par la LÉGALITÉ
  (`FENValidator`), et départage sur la plausibilité des pions.
- **`ScannerFixtureTests` + `ScannerFixtures/`** (manifeste + README) :
  suite `.enabled(if:)` qui ne produit AUCUN cas tant que le manifeste est
  vide — la suite reste verte tant que l'utilisateur n'a pas fourni d'images.
- Classification branchée dans `ScannerViewModel.confirmCrop()`.

### Décisions d'architecture
- **`TemplateSquareClassifier` est une struct NON isolée** : seul le rendu des
  gabarits touche UIKit (isolé à l'`init`). `classify` reste du calcul pur,
  déplaçable hors du fil principal sans toucher au protocole. Marquer le
  protocole `@MainActor` aurait cloué toute classification future au fil
  principal.
- **Roques déduits de la position, jamais inventés** : une image ne dit pas si
  le roi a déjà bougé. Idem le trait, qui n'est JAMAIS déductible d'une image
  (paramètre, confirmé par l'utilisateur — blancs par défaut).
- **Une case sans correspondance est rendue « vide » avec une confiance
  basse** plutôt qu'inventée : elle sera surlignée à la confirmation.

### Vérifié
- Suite unitaire verte : **220 tests / 29 suites** (202 → 220, +18).
- ⚠️ **Limite assumée, écrite en tête de la suite** : gabarits et plateaux de
  test sortent du MÊME moteur de rendu. Les tests synthétiques prouvent la
  cohérence du pipeline (découpe, rotation, seuils, FEN), PAS qu'une vraie
  capture Lichess est lisible. D'où deux tests qui s'en approchent :
  - **couleurs de plateau absentes de tous les thèmes** (`#f0d9b5`/`#b58863`,
    celles de Lichess) → lecture exacte quand même. C'est la preuve que la
    reconnaissance tient à la FORME du glyphe et non à la couleur du plateau —
    la propriété qui rend le critère « capture Lichess reconnue » atteignable ;
  - **photo d'écran dégradée** (sous-exposition, flou gaussien, bruit) →
    ≥ 60/64 cases correctes, le seuil du prompt.
- Autres tests : 5 positions (départ, sicilienne, milieu de partie, finale,
  sans dames) lues au FEN exact ; les 3 thèmes ; 3 marges de glyphe ; plateau
  vu du côté des Noirs → rotation `.half` suggérée ; plateau vide → aucune
  pièce ; ZNCC (auto-corrélation = 1, invariance luminosité/contraste = 1,
  motif inversé = −1, aplat = pas de normalisation).

### Reste à faire
- **ACTION UTILISATEUR** : déposer les images réelles dans
  `ChessLabTests/ScannerFixtures/` (1 capture Lichess, 1 photo d'écran,
  2 photos zénithales), chacune avec son FEN — voir le README du dossier.
  Sans elles, le critère « capture Lichess reconnue » n'est pas prouvé sur du
  réel, seulement rendu plausible par le test « couleurs hors thèmes ».

## Phase 1 (final-1407) — Lot 1.D : confirmation obligatoire et branchements ✅ (2026-07-16)

Le scanner devient un parcours complet pour les sources numériques : image →
cadrage → lecture → **confirmation** → Jouer / Analyser / Départ Laboratoire.

### Fait
- **`ScanConfirmationView`** : l'éditeur du Lot 1.A pré-rempli avec la lecture,
  augmenté de ce qu'une image ne peut pas donner — le sens de lecture
  (« Inverser la lecture » pour un diagramme, « Pivoter 90° » pour une photo
  zénithale) — et d'un bandeau qui compte les cases incertaines. Ces cases sont
  surlignées sur le plateau et se corrigent au tap, à la palette.
- **`PositionEditorView` devient générique** (`Header: View`) : le scanner
  insère ses bandeaux sous le plateau sans que l'éditeur connaisse le scanner.
  Une surcharge `where Header == EmptyView` garde l'usage courant intact.
- **`LabGameSettings.startFEN` est enfin atteignable** : section « Départ » dans
  `LabSetupView` (toggle + champ FEN validé + boutons éditeur/scanner). Le
  modèle et `startingPosition` existaient depuis l'étape 6, mais aucune UI ne
  les réglait : la fonctionnalité était morte.
- **Route `labSetup(startFEN:)`** : l'éditeur et le scanner autonomes proposent
  « Départ du Laboratoire », qui pousse les réglages Labo pré-remplis.
- **Boutons « Scanner » dans les deux sections « Départ »** (Jouer et Labo), à
  côté de « Ouvrir l'éditeur ».
- **Test UI de bout en bout** (`ScannerFlowUITests`) : `-scanTestImage synthetic`
  → cadrage → confirmation → correction manuelle (poser puis effacer une dame)
  → « Jouer » → la partie démarre sur la position scannée.

### Décisions d'architecture
- **`PositionEditorExit` est un type de PREMIER NIVEAU**, plus imbriqué dans
  l'éditeur : les types imbriqués d'un générique sont distincts pour chaque
  spécialisation, donc une sortie construite pour un éditeur sans en-tête
  n'aurait pas été du même type que celle du scanner. Le scanner peut ainsi
  transmettre la sortie sans la connaître — d'où le fait qu'il serve aussi bien
  d'écran autonome que de sélecteur en feuille.
- **Le trait n'a PAS de contrôle propre à la confirmation** : la section
  « Trait » de l'éditeur fait autorité. Un second contrôle aurait créé deux
  sources de vérité pour la même donnée (défaut : blancs, jamais déductible
  d'une image).
- **Pivoter relit tout et écrase les corrections manuelles** (`onChange` sur le
  FEN d'entrée) : c'est le sens même d'une rotation. La corriger case par case
  serait la seule autre option, et elle est plus surprenante.
- **Éditeur et scanner en FEUILLE depuis les réglages** (jamais poussés comme
  une route) : ils RAPPORTENT le FEN dans le champ, et les réglages déjà
  choisis à l'écran — couleur, force, cadence, nombre de parties — survivent au
  détour.

### Vérifié
- Suite unitaire verte : **220 tests / 29 suites** ; test UI du scanner vert
  (21 s), soit le critère d'acceptation de l'étape 7 : « capture reconnue,
  corrigée, puis jouée ».
- **Défaut trouvé en écrivant les feuilles** : le scanner pose déjà un bouton
  en `cancellationAction` à chaque étape (« Changer », « Recadrer »). Un
  « Annuler » de feuille à la même place se serait affiché À CÔTÉ, deux
  boutons de retour distincts dans la même barre → l'annulation de la feuille
  passe en `topBarTrailing`.
- Garde-fou de sortie : un FEN illégal ne peut atteindre le moteur — les
  actions de l'éditeur sont désactivées tant que `FENValidator` proteste, et
  `LabSetupView.start()` revalide le champ FEN saisi à la main.

### Reste à faire
- Lot 1.E : plateau réel vu du dessus (occupation + couleur + complétion
  assistée des types).

## Phase 1 (final-1407) — Lot 1.E : plateau réel vu du dessus ✅ (2026-07-16)

Occupation + couleur en vision classique, types complétés par l'utilisateur.
Et, au passage, la correction du défaut qui rendait le scanner inopérant dans
la vraie app.

### Fait
- **`PhysicalOccupancyClassifier`** (pur, sans ML) : par case, distance
  chromatique au fond attendu **OU** densité de contours (Laplacien) ;
  couleurs du damier estimées par la médiane des anneaux périphériques,
  groupées par parité ; camps séparés par regroupement 1D des luminances des
  cases occupées. Sortie : `kind: nil` — le type n'est jamais deviné.
- **`SquareClassifying.classify(grid:)`** : le pipeline lit la grille ENTIÈRE.
  Un classifieur de plateau réel a besoin du contexte global (les deux
  couleurs du damier, la séparation des camps) qu'une case seule ne donne pas.
  Les classifieurs qui s'en passent héritent de l'implémentation par défaut.
- **Complétion assistée** : l'éditeur tient des pièces « sans type »
  (`unknownPieces`, hors de `pieces` — une pièce sans type n'existe ni pour
  ChessKit ni pour le FEN), affichées en disque ○/● à la couleur lue. La case
  en attente est cernée, la palette de l'écran de confirmation est filtrée à
  sa couleur, et assigner passe à la suivante. Aucune action de sortie tant
  qu'il reste un type inconnu.
- **`BoardGridFinder`** : recalage de la grille sur les lignes du damier.
- Test UI du parcours complet : image plateau réel → lecture (occupation +
  couleur) → 3 taps → partie jouée sur la position complétée.

### Décisions d'architecture
- **Tous les seuils sont RELATIFS au contraste propre du damier**, aucun n'est
  absolu. Le plateau photographié porte sa propre référence d'exposition —
  l'écart entre ses cases claires et sombres. En lumière tamisée, tout baisse
  ensemble, les rapports ne bougent pas. (Le prompt suggérait une balance des
  blancs gray-world ; ceci fait le même travail sans étape de prétraitement.)
- **Regroupement plutôt que seuil de luminance** pour la couleur des pièces :
  des pièces crème sur bois clair et brunes sur bois sombre ne tombent
  d'aucun côté d'un seuil fixe, mais forment toujours deux paquets. Quand il
  n'y en a qu'un (finale à un seul camp), repli sur les couleurs du damier —
  avec une confiance basse, donc signalée.
- **La case en attente est DÉRIVÉE** (première de la file), jamais stockée :
  assigner la retire, la suivante devient sélectionnée toute seule. Un état
  séparé se serait désynchronisé à la première correction manuelle.
- Le rendu du plateau réel synthétique vit dans `ScanTestImage` (app), pas
  dans la cible de test : le test UI le fabrique par argument de lancement, et
  les tests unitaires appellent LA MÊME fonction — jamais deux rendus qui
  divergent.

### Vérifié
- Suite unitaire verte : **244 tests / 32 suites** (220 → 244, +24) ; 7 tests
  UI dont les deux parcours scanner de bout en bout.
- Critère du lot atteint : occupation + couleur **64/64** sur les 5 positions
  de référence, et **≥ 61/64 en lumière tamisée**.
- 🔴 **Le défaut majeur du lot, trouvé en écrivant le test UI du plateau
  réel** : dans la VRAIE app, le scanner ne lisait que **8 pions sur 32
  pièces** (58 cases signalées « incertaines », bouton Jouer désactivé). Cause :
  `VNDetectRectangles` rend un quadrilatère **~3 % trop grand** même sur une
  capture parfaite ; après redressement, le plateau se retrouvait décalé de
  ~14 px sur 800, soit 0,14 case. Découper en huitièmes exacts faisait alors
  mordre chaque vignette sur sa voisine. Seuls les pions, petits et centrés,
  gardaient assez de jeu. Corrigé par `BoardGridFinder` : l'image redressée
  porte la vérité — ses propres lignes de damier —, on en retrouve le pas et
  la phase, et on découpe là-dessus.
- ⚠️ **Les tests de 1.C ne pouvaient pas voir ce défaut** : ils découpaient des
  plateaux rendus, donc parfaitement cadrés. La détection réelle n'était
  jamais dans la boucle. D'où le nouveau test
  `theWholeAppPipelineReadsTheInjectedTestImage`, qui part de l'image telle que
  l'app la reçoit et traverse détection ET redressement réels.
- ⚠️ **Le test UI du Lot 1.D ne prouvait rien non plus** : il tapait un bouton
  DÉSACTIVÉ (donc sans effet), puis vérifiait le libellé de l'éditeur — resté
  à l'écran. Or le plateau de jeu écrit « Case e4, … » quand l'éditeur écrit
  « e4, … ». Le test se prouvait qu'il n'avait pas changé d'écran. Il exige
  désormais le libellé de la PARTIE, et que le bouton soit actif.
- Deux autres défauts trouvés en chemin :
  - le recalage analysé sur une image réduite (256 px) introduisait un
    décalage d'un demi-pixel — 2,5 px une fois remis à l'échelle, assez pour
    désaxer les vignettes. L'analyse se fait maintenant à la résolution native ;
  - profil de contours en **médiane** et non en moyenne : les colonnes
    tombaient juste, les rangées dérivaient de 2,5 px, tirées par les bords
    des glyphes. Une ligne du damier traverse toute l'image, le bord d'une
    dame non — la médiane fait le tri, la moyenne les met sur le même plan.
- Rognage de 2 % à l'intérieur des lignes (`BoardRectifier.edgeInset`) : sans
  lui, chaque vignette emportait un liseré de sa voisine, et 33 cases d'une
  capture parfaite ressortaient « incertaines » (contre 4 aujourd'hui).

### Reste à faire
- **ACTION UTILISATEUR** (inchangée) : les fixtures photo RÉELLES de
  `ChessLabTests/ScannerFixtures/`. Le synthétique prouve l'algorithme, pas la
  vraie vie — en particulier pour les pièces réelles vues du sommet.
- Lot 1.F (optionnel) : types physiques par CoreML, visée caméra assistée,
  auto-détection de la source. Le `.mlmodel` demande des photos zénithales de
  jeux réels — l'agent ne peut pas les produire.

## Revue UX — disposition iPad de « Contre Stockfish » ✅ (2026-07-16)

Demande utilisateur : que l'échiquier prenne (quasi) toute la largeur, le reste
au-dessus et en dessous.

### Fait
- **Portrait : colonne unique**, plateau à ~84 % de la largeur (contre 58 %),
  pendules collées au plateau, éval/transport/actions dessous, liste des coups
  en continu tout en bas. Avant, le plateau tenait dans une colonne de gauche
  et la MOITIÉ BASSE de l'écran était vide (vérifié à la capture).
- **Paysage : deux colonnes**, mais le plateau prend toute la hauteur
  disponible au lieu d'être borné à 58 % de la largeur.
- C'est l'ORIENTATION qui décide, plus la classe de taille : seule la hauteur
  disponible dit si un plateau pleine largeur tient. En Split View / Stage
  Manager, une fenêtre étroite reste en classe compacte, donc sur la
  disposition iPhone — inchangé.

### Décisions d'architecture
- **`.layoutPriority(1)` sur le plateau, et plus aucune constante de « chrome »
  soustraite à la main.** Deux vues gourmandes en hauteur (le plateau et le
  défilement des coups) se partageaient l'espace à parts égales : l'échiquier
  tombait à la moitié de la largeur et la liste s'octroyait un bas d'écran
  vide. Le plateau se sert maintenant en premier, la liste prend le reste.
  L'ancienne version paysage soustrayait une hauteur estimée à la main — un
  chiffre qui ment dès qu'une police ou une marge bouge.
- **Un minimum de 150 pt pour la liste des coups** : un plateau VRAIMENT pleine
  largeur ne lui laissait qu'un filet de 60 pt, où seul le titre était
  lisible. C'est ce minimum qui rend le plateau « quasi » pleine largeur
  (~84 %) plutôt que strictement pleine largeur — l'échiquier reste énorme et
  la liste reste utile.
- La liste des coups est sans défilement propre : chaque disposition
  l'enveloppe (le portrait lui donne la hauteur restante, le paysage la met
  dans le défilement de sa colonne). Deux `ScrollView` imbriqués ne
  défileraient ni l'un ni l'autre.

### Vérifié
- Captures iPad Pro 11" avant/après en portrait (test UI temporaire, retiré) :
  plateau de 58 % → ~84 % de la largeur, plus aucune zone morte.
- Suites vertes sur iPhone 17 ET iPad Pro 11" : 244 tests unitaires + 7 UI.
- ⚠️ **Le paysage n'a PAS pu être vérifié à la capture** : le simulateur rend
  l'app tournée à 90° dans une fenêtre restée portrait, quelle que soit la
  méthode (rotation avant ou après lancement, `app.screenshot()` ou
  `XCUIScreen.main`). Le code ne repose plus sur aucune constante devinée et
  suit la même règle que le portrait (vérifiée, elle), mais la disposition
  paysage reste à confirmer sur un vrai iPad.

## Phase 2 (final-1407) — Fondations moteur ✅ (2026-07-16)

Les quatre lots (2.A à 2.D), plus deux correctifs demandés en cours de route.

### Fait
- **2.A — Reprise après panne** : `EngineController.restart()` (stop → start →
  `ucinewgame` → ré-émission des réglages du mode appelant) et bannière
  « Moteur indisponible — **Réessayer** » partagée par Jouer et Analyser. La
  reprise repart du FEN courant : c'est `requestEngineMove` qui envoie la
  position, il n'y a rien à repositionner à la main.
- **2.B — Threads et Hash** : réglages persistés (`AppSettings`), section
  « Réglages avancés ». `Hash` n'était **jamais** envoyé (Stockfish tournait
  sur son défaut interne) et `Threads` valait **1** là où le prompt en demande
  2 — ChessKitEngine envoie `Threads = max(coreCount − 1, 1)`, d'où
  `coreCount(forThreads:)` qui ajoute 1.
- **2.C — Thermique** : `ThermalMonitor` (observation de
  `thermalStateDidChangeNotification`), bandeau « Appareil chaud — moteur
  bridé » sur Jouer/Analyser/Labo, et réduction RÉELLE : movetime ÷ 2 (Jouer,
  classification d'analyse, Labo) et 1 thread au prochain démarrage.
- **2.D — Veille** : `IdleTimerGuard` + toggle « Empêcher la mise en veille »
  dans le Labo, activé par défaut au-delà de 20 parties.
- **Échelle Elo du mode Jouer revue** (demande du 16/07) : plus de 2800 ni de
  « Maximum » — ces deux-là ne se jouent pas, ils se subissent. Ajout de 1000
  et 1400, qui resserrent l'échelle là où l'on progresse (elle sautait de 800 à
  1200 puis à 1600). Le slider de Jouer est plafonné à 2500
  (`playSliderRange`) ; le Laboratoire garde la plage complète, c'est tout son
  intérêt.

### Décisions d'architecture
- **Trois portes dérobées de test, assumées** (`-simulateEngineFailure <n>`,
  `-simulateThermalState <état>`, et l'injection d'`IdleTimerGuard`). Sans
  elles, aucun de ces trois lots ne serait vérifiable : on ne provoque pas une
  panne NNUE, on ne fait pas chauffer un simulateur, et on ne lit pas
  `UIApplication.isIdleTimerDisabled` sans effet de bord. `<n>` et non un
  drapeau : c'est ce qui rend la REPRISE testable (le 1er démarrage échoue, le
  « Réessayer » réussit), là où un échec permanent n'aurait prouvé que
  l'affichage.
- **`fair` ne déclenche RIEN** : c'est l'état normal d'un appareil qui calcule.
  Brider dès `fair` reviendrait à brider en permanence.
- **Le garde de veille s'éteint dans son `deinit`** : `isIdleTimerDisabled` est
  un réglage GLOBAL ; on ne confie pas une ressource système à la discipline
  des appelants (ici trois chemins : annulation, fin de boucle, disparition de
  l'écran).
- **Les réglages moteur s'appliquent au PROCHAIN démarrage**, et l'UI le dit :
  changer `Threads` sur un moteur en pleine recherche n'a pas de comportement
  défini en UCI.

### Vérifié
- Suite complète verte : **262 tests / 36 suites** (244 → 262) + 11 tests UI.
- **Reprise prouvée de bout en bout** (`EngineRecoveryUITests`) : bannière →
  aucun coup du moteur (compteur figé à 1) → « Réessayer » → le moteur répond
  au coup DÉJÀ joué. C'est le `<n>` de la porte dérobée qui rend ça possible.
- ⚠️ **Ce qu'UCI ne permet pas de vérifier** : `setoption` n'a aucun accusé de
  réception et le moteur n'annonce que ses valeurs par DÉFAUT. On ne peut donc
  pas demander à Stockfish combien de threads il utilise. Ce qui est vérifié —
  et c'est toute notre moitié du contrat — c'est que la bonne commande, avec la
  bonne valeur, part vers un moteur DÉMARRÉ (`Engine.send` jette en silence
  tout ce qui arrive trop tôt), et qu'il calcule encore après.
- ⚠️ **Le test à moteur réel est opt-in** (`TEST_RUNNER_ENGINE_INTEGRATION=1`) :
  ChessKitEngine n'héberge qu'**un seul Stockfish par processus**, et
  `BugFixes1407Tests` construit des `PlayViewModel` qui en démarrent un sans
  jamais l'arrêter. Dans la suite complète, ce test ne pouvait donc pas obtenir
  de moteur : il mesurait la place disponible, pas le produit. Vérifié à part
  (vert, 1,8 s). Le **Lot 6.B** (moteur injectable) est ce qui débloquera ça.

## Correctif — le tap-tap qui ne répondait pas ✅ (2026-07-16)

Bug signalé : « des fois je suis obligé de dragguer la pièce, le clic départ /
clic arrivée ne fonctionne pas ».

### Fait
- `ChessBoardView` ne jugeait un geste « tap » qu'en dessous de **8 px** de
  déplacement — plus serré que la tolérance d'iOS (~10 pt). Un tap un peu
  tremblé (pouce en main, en marchant) partait donc en glissement et se soldait
  par un `onDropPiece(e2, e2)` : un coup d'une case vers ELLE-MÊME, illégal,
  rejeté en silence — et surtout **aucune sélection**. La pièce semblait morte
  au tap-tap, et il fallait la glisser.
- Deux corrections : un relâchement sur la case de DÉPART est un tap **par
  définition** (aucun coup ne va d'une case à elle-même), et la tolérance passe
  à 12 pt, alignée sur iOS.

### Vérifié
- `TapToMoveUITests` : le test du tap tremblé **échoue sur le code d'origine**
  (e4 reste vide) et passe après correction — c'est la seule preuve qui vaille
  pour un bug aléatoire.
- ⚠️ **Pourquoi aucun test ne l'avait vu** : `tap()` de XCUITest est au pixel
  près, il ne tremble jamais. Le test reproduit le tremblement à la main
  (`press(forDuration:thenDragTo:)` sur 10 pt), sans quoi ce bug serait resté
  invisible à l'automatisation tout en étant permanent pour l'utilisateur.

## Phase 3 (final-1407) — Notation française et localisation ✅ (2026-07-16)

### Fait — Lot 3.A : notation des pièces
- **`SANFormatter`** (pur) + `PieceNotation` (`.french` par défaut, `.english`
  en option) + deux chips dans Réglages, avec un exemple sous les chips
  (« Cf3, Dxd5, O-O » vaut mieux qu'une explication).
- Appliqué à TOUT le SAN affiché : liste des coups de Jouer et d'Analyser,
  fin de partie à deux joueurs, « Trouvez mieux que… » des puzzles, arbre du
  constructeur de répertoire, chemins de la file de répertoire, message de
  sortie de répertoire. Libellés d'accessibilité compris.
- **JAMAIS** appliqué à ce qui est stocké, comparé ou exporté : PGN,
  `pathKey`, `expectedSANs`. La traduction se fait au dernier moment, dans la
  vue.

### Fait — Lot 3.B : String Catalog
- `ChessLab/Localizable.xcstrings` (langue source **fr**), **185 clés**
  extraites. L'app avait déjà `SWIFT_EMIT_LOC_STRINGS = YES` et
  `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` : seul le catalogue manquait.
- Chaînes construites converties en `String(localized:)` là où ce sont des
  PHRASES (barre d'éval, écart Elo du Labo). Le formatage purement numérique
  (`%+.1f`, `%02d:%02d`) reste en `String(format:)` : ce n'est pas de la
  langue, et une phrase traduisible ne doit pas transporter des
  spécificateurs qu'un traducteur peut casser.
- Aucune traduction anglaise fournie : l'app reste FR, « prête à localiser »
  suffit (conforme au prompt).

### Décisions d'architecture
- **Une seule passe, table de correspondance** (`K→R, Q→D, R→T, B→F, N→C`).
  Des `replace` successifs seraient faux : « R → T » puis « K → R »
  retraduirait les T fraîchement écrits, et le roi finirait tour. Deux tests
  verrouillent exactement ce cas.
- **Les majuscules SEULES sont traduites** : les minuscules sont des colonnes,
  le `b` de `bxa3` n'est pas un fou. `O-O`, `x`, `+`, `#` et les chiffres
  traversent intacts ; `=Q` → `=D` par la même passe, et c'est voulu.
- **L'accessibilité est francisée elle aussi**, contrairement à ce que
  suggérait le plan. Sa mise en garde (« les tests UI cherchent des SAN
  anglais dans les libellés d'accessibilité ») ne s'applique plus : vérifié
  par grep, aucun test UI ne le fait aujourd'hui. Garder l'anglais aurait
  dégradé VoiceOver pour préserver des tests qui n'existent pas.
- `pathKey` est une CLÉ (comparée, persistée) : traduite pour l'œil au moment
  de l'affichage, jamais dans le modèle.

### Vérifié
- Suite complète verte : **272 tests / 37 suites** (262 → 272) + 11 tests UI.
- **La ligne rouge est verrouillée par un test** : réglage en français →
  export PGN → il contient `Nf3` et `Bb5`, jamais `Cf3` ni `Fb5`. C'est le
  seul de ces chemins qui QUITTE l'app, donc celui où l'erreur coûterait le
  plus cher (un PGN francisé n'est relisible par aucun autre logiciel).
- ⚠️ **`xcodebuild` ne peuple PAS le catalogue** (c'est l'IDE qui le fait à la
  compilation). La synchronisation en ligne de commande se fait avec :
  `xcrun xcstringstool sync ChessLab/Localizable.xcstrings --stringsdata <DerivedData>/…/ChessLab.build/Objects-normal/arm64/*.stringsdata`
  — à relancer quand des chaînes sont ajoutées.
- Trouvé en synchronisant : trois `TextField("")` et un `Picker("")` sans
  libellé. Ils polluaient le catalogue d'une clé VIDE et, surtout, laissaient
  ces contrôles muets sous VoiceOver. Corrigés (libellé réel + `labelsHidden`).

## Phase 4 (final-1407) — iPad et accessibilité ✅ (2026-07-17)

### Fait — Lot 4.A : clavier
- **Analyser** : ←/→ (coup précédent/suivant), **espace** (coup suivant, en
  attendant la lecture auto du Lot 5.A), **⌘F** (retourner le plateau).
- **Jouer** : ←/→ parcourent la consultation.
- Raccourcis posés sur les VRAIS boutons plutôt que sur des boutons cachés :
  un bouton masqué ne reçoit pas toujours son raccourci selon l'état du focus.
  Seule exception, l'espace : deux raccourcis ne peuvent pas coexister sur un
  même bouton, d'où un second bouton de taille nulle, masqué à
  l'accessibilité.

### Fait — Lot 4.B : accessibilité
- **Réduire les animations** (`accessibilityReduceMotion`) : plus de confettis
  du tout (`CelebrationView` ne dessine rien — atténuer ne suffirait pas, c'est
  le mouvement qui gêne), et les pièces sont POSÉES au lieu de glisser.
- **Cibles 44 pt** : `navIconButton` de Jouer et de Deux joueurs passait de 40
  à 44 — le minimum des HIG.
- **Annonce VoiceOver du RÉSULTAT** (Jouer et Deux joueurs) : les coups étaient
  annoncés, la fin de partie non. Un utilisateur non voyant voyait le moteur
  cesser de répondre sans jamais savoir qu'il venait de gagner.
- **`EngineDiagnosticsView` rebranchée**, depuis les Réglages (« Moteur →
  Diagnostic moteur »). L'écran existait, complet et à jour, mais AUCUNE route
  n'y menait : du code vivant et inatteignable. Le bug n°17 (état d'échec
  jamais produit) était, lui, déjà corrigé en phase 0.
- Trois `TextField` et un `Picker` sans libellé (trouvés au Lot 3.B) :
  désormais nommés, donc annoncés par VoiceOver.

### Décisions d'architecture
- Le routage du diagnostic passe par un **callback** (`onOpenDiagnostics`) et
  non par la route directement : `HomeView.Route` est privée, et la convention
  du projet veut que les écrans remontent une intention plutôt que de router.

### Vérifié
- Suite complète verte : **272 tests / 37 suites** + 13 tests UI.
- **Raccourcis prouvés** (`KeyboardShortcutsUITests`, iPad ET iPhone) : ← après
  un coup joué → l'écran passe en consultation. C'est `typeKey` qui rend ça
  vérifiable, via le clavier matériel du simulateur.
- **Diagnostic prouvé atteignable** (`EngineDiagnosticsRouteUITests`) : c'est
  le CHEMIN qui était cassé, c'est donc lui qu'on verrouille — pas le contenu,
  qui dépend de Stockfish et n'a rien à faire dans un test déterministe.
- Dynamic Type **XXL** vérifié à la capture (test temporaire, retiré) sur les
  Réglages, le diagnostic et la nouvelle partie : rien n'est tronqué ni
  chevauché, les cartes s'étirent. Le diagnostic répond « Moteur opérationnel —
  Stockfish 17 — profondeur 9 ».

## Phase 5 (final-1407) — Compléments par mode : ceux qu'exige le prompt ✅ (2026-07-17)

La phase 5 est « à la carte » dans le plan. Choix assumé, faute de pouvoir
poser la question : **on fait les trois compléments que le PROMPT réclame
explicitement**, on laisse les bonus.

### Fait — Lot 5.A : lecture automatique de l'analyse
- Bouton lecture/pause dans la barre de navigation, **un coup par seconde**
  (le prompt), `Task` annulable, arrêt à la fin de la ligne. L'espace le
  déclenche (le raccourci du Lot 4.A avance donc désormais la lecture au lieu
  d'un seul coup).
- **Toute navigation manuelle l'arrête** (le prompt : « stop à la fin ou à
  toute interaction »), y compris la disparition de l'écran — sans quoi la
  lecture déroulerait la partie derrière un écran fermé, en relançant une
  analyse à chaque coup.

### Fait — Lot 5.B : statistiques de puzzles
- `PuzzleStats` (pur) : réussite globale + **thèmes d'erreurs récurrents**
  (« vous ratez souvent des fourchettes », dit le prompt), et une carte dans
  `PuzzleQueueView`, qui n'avait plus aucune statistique.

### Fait — Lot 5.G : flèche « menace » rouge
- `ThreatPosition` (pur) : même position, trait passé à l'adversaire → courte
  recherche (200 ms) → flèche **rouge translucide** de ce que l'adversaire
  jouerait si on lui laissait la main.

### Laissés de côté (bonus, non exigés par le prompt)
5.C (file du jour mixte), 5.D (notifications), 5.E (compléments Labo),
5.F (annotations dessinées), 5.I (recherche bibliothèque). 5.H (share
extension) reste hors périmètre sans accord explicite — nouveau target Xcode.

### Décisions d'architecture
- **La menace est enfilée AVANT l'analyse en continu**, jamais après :
  l'analyse tourne en `go infinite`, qui ne se termine jamais tout seul —
  derrière elle, la recherche de menace attendrait une fin qui ne vient pas
  (l'interblocage déjà documenté deux fois sur ce projet). Devant, elle dure
  200 ms et rend la main.
- **La menace vit dans `startLiveAnalysis`, pas dans `afterNavigate`** : c'est
  le seul point commun à TOUS les démarrages d'analyse (ouverture de l'écran,
  retour dessus, navigation). Placée dans `afterNavigate`, elle ne s'affichait
  jamais tant qu'on n'avait pas changé de coup — défaut vu à la capture.
- **La lecture automatique est identifiée par sa `Task`**, pas par un booléen
  à part : deux sources de vérité pour « ça joue ou pas » finiraient par
  diverger. L'avance interne (`advance()`) est distincte de `goToNext()`, qui
  arrête la lecture — sinon elle se serait arrêtée elle-même au premier coup.
- **`PuzzleStats` ne charge QUE les puzzles tentés** (prédicat SwiftData) : la
  bibliothèque Lichess embarquée en compte des dizaines de milliers, les
  matérialiser tous pour un pourcentage rendrait l'écran inutilisable.
- Un thème n'est « à travailler » qu'au-delà de 4 essais ET 34 % d'échecs :
  sans ces deux seuils, la carte désignerait une faiblesse au premier échec
  venu, ou un thème réussi à 90 % juste parce qu'il est le moins bon.

### Vérifié
- Suite complète verte : **285 tests / 39 suites** (272 → 285) + 13 tests UI.
- **Flèche menace vue à la capture** sur l'Italienne : rouge, de f6 vers e4 —
  c'est bien Cxe4 que les Noirs menacent. Les flèches de coups à jouer restent
  en gris : les deux ne se confondent pas.
- Défaut trouvé à la capture (corrigé) : la menace ne s'affichait pas du tout à
  l'ouverture de l'écran — voir la décision ci-dessus.
- `ThreatPosition` refuse de produire un FEN quand l'adversaire est en ÉCHEC :
  lui passer la main laisserait un roi en prise, et le prompt interdit
  d'envoyer un FEN illégal au moteur. Le test le prouve sur une vraie position
  d'échec — ma première tentative était fausse (le fou n'attaquait pas le roi)
  et le test l'a dit.

## Phase 6 (final-1407) — Lot 6.A : fuites d'instances moteur ✅ (2026-07-17)

Le compteur demandé par le plan… qui a trouvé deux vrais bugs.

### Fait
- **`EngineInstanceCounter`** : compte les `EngineController` vivants (init /
  deinit), exposé sur l'accueil par un marqueur invisible « vivantes/créées ».
- **`EngineLeakUITests`** : traverse Jouer → Analyser et exige zéro instance
  au retour.

### Deux bugs trouvés en écrivant le test (c'est tout l'intérêt du lot)
- 🔴 **Le moteur de Jouer n'était pas libéré en quittant une partie NON
  terminée** (bouton retour) : `handleViewDisappear` ne coupait que l'indice.
  Le moteur survivait jusqu'à la libération paresseuse du view model, et
  enchaîner sur Analyser faisait coexister deux réseaux NNUE de 78 Mo —
  l'app pouvait être **tuée pour dépassement mémoire**. Corrigé :
  `handleViewDisappear` libère désormais le moteur, à **capture forte** (une
  capture `[weak self]` trouvait `self` déjà nil à la sortie d'écran et
  n'appelait jamais `stop()`).
- 🔴 **`print()` dans le compteur corrompait le flux du moteur** : ChessKitEngine
  détourne le `stdout` du processus (`dup2`) pour capter la sortie de
  Stockfish. Mes logs de debug étaient injectés dans ce tuyau, pris pour de
  l'UCI. Remplacés par `os_log`, hors du flux.

### Décisions d'architecture
- **Pas de portillon d'activation.** J'ai d'abord cru que deux moteurs ne
  pouvaient pas coexister (le messenger détourne `stdin`/`stdout`) et bâti un
  sémaphore inter-VM. Erreur : deux moteurs coexistent très bien le temps d'une
  transition, et mon portillon à continuations introduisait un blocage fatal.
  La vraie cause était la libération tardive du moteur de Jouer (ci-dessus) et
  le `print` parasite. Vérifié en revenant au code committé : Jouer → Analyser
  y fonctionne. Le portillon a été retiré entièrement.
- **`OSAllocatedUnfairLock`** et non un acteur : le `deinit` d'un
  `EngineController` doit décrémenter, et un `deinit` ne peut pas `await`.

### Vérifié
- Suite complète verte : **285 tests / 39 suites** + **15 tests UI** (le
  parcours Jouer → Analyser compris, qui plantait avant le correctif).
- `EngineLeakUITests` : trois lancements consécutifs verts, plus aucun `kill`.

## Phase 6 (final-1407) — Lots 6.B et 6.C ✅ / documenté (2026-07-17)

### Fait — Lot 6.B : tests de notre consommation UCI
- **`EngineScore`** (pur) : interprétation d'un score `info` — mat = ±10 000
  centipions, le `mate` prime sur le `cp`, une ligne de progression sans score
  ne dit rien (et surtout ne renvoie pas 0, qui serait lu « position égale »).
  Cette logique était recopiée à l'identique dans plusieurs boucles de
  consommation ; centralisée et wirée dans les sites à convention « plate »
  de `PlayViewModel`, à comportement RIGOUREUSEMENT identique.
- **`EngineScoreTests`** : sur de VRAIES lignes UCI parsées par ChessKitEngine
  (`EngineResponse(rawValue:)`), pas des `Info` fabriqués — la chaîne réelle,
  du texte moteur au centipion. Couvre cp ±, mat ±, `mate` prioritaire, ligne
  sans score, et `bestmove (none)` reconnu comme un bestmove (la position
  terminale que le Lot 0.2 empêche de geler).
- Choix assumé : NE PAS rewirer les view models derrière un protocole
  d'injection complet (l'autre option du plan). La file moteur et ses hôtes
  paresseux encodent des corrections de bugs réels ; les rebrancher pour un
  moteur simulé était le risque que le plan lui-même déconseille en dernier
  lot. La valeur — tester notre lecture des réponses — est atteinte par la
  brique pure, sans toucher à la concurrence délicate.

### Lot 6.C : budgets de performance — passe manuelle Instruments
- **Non automatisable en headless** : le plan demande un profil Instruments
  (Time Profiler / Animation Hitches) d'une série Labo rapide et du scroll
  d'une longue analyse, puis la correction des hotspots ÉVIDENTS. Instruments
  se pilote à la main, sur appareil.
- **Ce qui est déjà acquis par construction** (cibles du prompt : 60 fps
  échiquier, < 100 ms après un coup) : le coup de l'utilisateur s'applique
  SYNCHRONEMENT au plateau avant tout appel moteur (aucune attente réseau ou
  Stockfish dans le chemin du geste — documenté dès l'étape 1) ; les données
  dérivées (liste de coups, courbe d'éval, précision) sont matérialisées à la
  mutation, pas recalculées dans `body` ; les `@Query` lourds (puzzles, items)
  sont remplacés par des compteurs mis en cache. Aucun hotspot introduit par
  les phases 2 à 6.
- **Reste à faire (action manuelle)** : un profil Instruments sur un appareil
  réel avant publication, pour confirmer les cibles et débusquer un éventuel
  hotspot non évident.

---

## État final du plan final-1407 (2026-07-17)

Toutes les phases sont traitées :
- **Phase 0** (bugs) ✅ · **Phase 1** (étape 7 : éditeur + scanner) ✅ sauf
  Lot 1.F (CoreML, **action utilisateur** : photos zénithales de jeux réels).
- **Phase 2** (fondations moteur) ✅ · **Phase 3** (notation FR + catalog) ✅
- **Phase 4** (iPad + accessibilité) ✅ · **Phase 5** (compléments exigés par
  le prompt : 5.A/5.B/5.G) ✅ ; bonus 5.C/5.D/5.E/5.F/5.I laissés, 5.H (share
  extension) hors périmètre sans accord.
- **Phase 6** : 6.A ✅ (a trouvé deux bugs), 6.B ✅, 6.C documenté (passe
  Instruments manuelle avant publication).

**Actions utilisateur restantes** : fixtures photo du scanner
(`ChessLabTests/ScannerFixtures/`), photos pour le modèle CoreML du Lot 1.F,
et le profil Instruments du Lot 6.C.

## Bilingue FR/EN + section Aide ✅ (2026-07-17/18)

Demande utilisateur, après final-1407.

### Fait — Bilingue
- **`AppLanguage`** (système / français / anglais) + réglage dans les Settings.
  « Système » regarde le CODE DE LANGUE des préférences de l'OS (français si
  fr, fr-CH ou fr-CA ; anglais sinon) — pas la région, sinon un français
  canadien basculerait en anglais.
- **`LocalizationController`** : détourne `Bundle.main` vers le `.lproj`
  choisi. `Text` (via la locale d'environnement qui force le re-rendu) ET les
  chaînes hors SwiftUI (`LocalizationController.string(_:)`) suivent le choix
  in-app, immédiatement, sans redémarrage.
- **`Localizable.xcstrings`** : 352 clés, toutes traduites en anglais.
- Passe complète sur les libellés dynamiques : composants réutilisables passés
  en `LocalizedStringKey` (localise les littéraux des sites d'appel), labels
  d'enum/struct laissés en clé française et localisés à l'affichage.

### Fait — Aide
- **`HelpView`** : une carte par module (Contre Stockfish, Deux joueurs,
  Puzzles, Ouvertures, Analyser, Laboratoire, Éditeur/Scanner, Réglages),
  description claire et succincte, bilingue. Accessible depuis les Réglages.

### Décisions d'architecture
- **`String(localized:)` suit la langue de l'OS, PAS le choix in-app** : c'est
  le piège de la localisation runtime. Tout ce qui est AFFICHÉ passe donc par
  `Text`/`LocalizedStringKey` (détournement de bundle) ou par
  `LocalizationController.string(_:)` (accessibilité, chaînes composées).
- **Pas de `.id(langue)` sur la racine** : cela reconstruirait la
  `NavigationStack` et renverrait à l'accueil à chaque changement de langue.
  Le seul changement de la locale d'environnement suffit à re-rendre les
  `Text` (leur clé est alors re-résolue via le bundle détourné).
- **Les données persistées gardent leur clé** : `TimeControlCategory.rawValue`
  (Codable) et les labels des `static let` (thèmes, préréglages) restent en
  français ; seul l'affichage traduit. Un catalogue francisé casserait la
  reprise des séries et des réglages sauvegardés.

### Vérifié
- Accueil, Réglages, Nouvelle partie, Puzzles et l'Aide entièrement en
  anglais à la capture ; Aide vérifiée dans les deux langues.
- Suite complète verte dans les deux langues : **292 tests unitaires / 40
  suites + tous les tests UI** (dont un test d'atteignabilité de l'Aide et le
  reset de langue à `-resetPlaySettings` pour des tests déterministes).

## Analyser une partie récente ✅ (2026-07-18)

Demande utilisateur : « j'aimerais pouvoir analyser les parties récentes que
j'ai jouées ».

### Fait
- **Accueil** : section « Parties récentes » (4 dernières parties terminées,
  `@Query` trié par date décroissante, `fetchLimit = 4`). Chaque ligne est
  tappable et ouvre directement l'analyse (`Route.activeAnalysis(.pgn(pgn))`).
- Titre de partie et noms de joueurs localisés via
  `LocalizationController.string(_:)` (hors SwiftUI).
- Test UI de bout en bout : jouer → abandonner → retour accueil → tap sur la
  partie → l'analyse s'ouvre sur la position de DÉPART (assertion `square_e2`
  = pion blanc).

## Refonte du scanner — reconnaissance et cadrage automatiques ✅ (2026-07-18)

Demande utilisateur : « revois en profondeur le mode scanner (résultats très
mauvais), ajoute le collage d'image, et découvre le cadrage automatiquement ».

### Fait
- **`CheckerboardDetector`** : détection du plateau par sa signature de damier
  (8 bandes claires/sombres alternées sur chaque axe), sans passer par Vision.
  Bien plus fiable qu'une détection de rectangles sur un diagramme numérique,
  où le plateau remplit l'image et où les pièces cassent les arêtes. Racine du
  « résultats très mauvais » : un cadrage imprécis décalait cumulativement les
  cases ; un plateau bien cadré redresse la reconnaissance.
- **Cadrage automatique** : pour une source « diagramme numérique »,
  `BoardDetector.detectBoard` renvoie une détection *confiante* et le scanner
  enchaîne directement sur la confirmation (plus d'étape de recadrage manuel).
  Les photos en perspective restent sur Vision + ajustement manuel.
- **Coller une image** (4e source) : `PasteButton` au premier écran.

### Décisions d'architecture
- **Jugement par la ligne la PLUS FAIBLE des 9, pas par leur moyenne** : une
  demi-période (cellule deux fois trop petite) aligne ses lignes une sur deux
  sur les vraies crêtes et sa moyenne reste haute — mais son minimum
  s'effondre. Le minimum distingue le vrai plateau d'un sous-motif, et il est
  insensible aux pièces (elles ne créent pas 9 crêtes équidistantes pleine
  hauteur).
- **Échantillonnage fenêtré symétrique** (max dans ±quelques px, lignes ET
  centres) : absorbe le flottement de période sur 8 cases sans qu'un bruit
  sans structure paraisse « contrasté ».
- **Marge de 2 %** autour du plateau détecté : la détection donne le cadre au
  pixel près, mais « près » ne suffit pas — on élargit d'un chouïa pour
  ENGLOBER tout le plateau, à charge pour `BoardGridFinder` de recaler la
  grille au pixel exact.
- **Profil de transitions par médiane** (des |gradients| perpendiculaires) :
  une ligne du damier traverse toute l'image, un bord de pièce non — la
  médiane éteint les pièces.

### Vérifié
- **294 tests unitaires / 41 suites** verts, dont `CheckerboardDetectorTests`
  (détection au pixel, capture nette et damier vide) et le test de pipeline
  complet `theWholeAppPipelineReadsTheInjectedTestImage` (FEN exact,
  ≤ 6 cases incertaines).
- Parcours UI du scanner vert : capture nette → cadrage AUTOMATIQUE →
  confirmation ; plateau réel → cadrage manuel → complétion des types.
- Compilation **sans avertissement** (`nonisolated(unsafe)` retirés de
  `BoardRectifier` et `ThermalMonitor` via une boîte `Sendable`, libellé du
  `PhotosPicker` inliné, `#require` redondant retiré).

## Scanner, 2e passe — le cas de la VRAIE capture de téléphone ✅ (2026-07-18)

Retour utilisateur sur capture chess.com réelle : « le cadrage est inopérant »
et « la reconnaissance désastreuse ». La 1re passe n'avait été validée que sur
des fixtures carrées à large marge ; une vraie capture est PORTRAIT
(1206×2622), le plateau touche les deux bords, n'occupe qu'une bande de la
hauteur, et l'interface est chargée (coups, joueurs, mini-glyphes capturés).

### Fait
- **Fixture réaliste** (`ScanTestImage.renderRealisticScreenshot`) reproduisant
  ce cas, avec coordonnées incrustées dans les cases — injectable en test UI
  via `-scanTestImage realistic` (le parcours UI capture l'utilise désormais).
- **`CheckerboardDetector` refondu** pour ce cas :
  - les axes se cherchent indépendamment puis l'axe trouvé ANCRE l'autre
    (plateau carré EN PIXELS) avec un profil restreint à sa bande — hors
    bande, la médiane des gradients meurt dans l'interface ;
  - une ligne coupée par le bord de l'image est excusée, mais chaque excuse
    COÛTE (× comptées/9) — sinon un span décalé d'une case, dont la 9e ligne
    « sort » de l'image, bat mécaniquement le vrai plateau (son minimum est
    pris sur un sous-ensemble des vraies lignes) ;
  - toutes les longueurs se comparent en pixels d'origine, jamais en unités
    du carré d'analyse 384×384 (une image portrait étire ses axes
    différemment).
- **Classifieur** : les coordonnées incrustées (chess.com, Lichess) rendent
  les 15 cases du bord non plates → nouveau test d'« aplat CENTRAL » (60 % du
  centre) : un chiffre dans le coin n'empêche plus de juger la case vide, une
  pièce couvre toujours le centre.

### Décisions d'architecture
- Le test pipeline vérifie la lecture en rotation `.none` : sur une finale
  clairsemée, l'orientation est objectivement ambiguë et `suggestedRotation`
  peut préférer 180° — c'est le bouton « Pivoter » de la confirmation qui
  tranche, pas une heuristique.
- Limite connue et assumée : les gabarits sont les glyphes cburnett de l'app ;
  un set très différent (chess.com « neo ») corrèle moins bien et sortira
  davantage de cases « incertaines » (signalées, pas inventées). L'alignement
  de grille — la vraie racine du « désastreux » — est, lui, corrigé.

### Vérifié
- **296 tests unitaires / 42 suites** verts, dont les 2 nouveaux
  `RealisticScreenshotScanTests` : détection du cadre au pixel (plateau collé
  aux bords) ET pipeline complet lisant le FEN exact de la position de la
  capture d'origine, ≤ 6 cases incertaines malgré les coordonnées incrustées.
- Parcours UI du scanner vert SUR LA FIXTURE RÉALISTE (cadrage automatique →
  confirmation → partie jouée).

## Reconnaissance ML — YOLO, Phase A : intégration app + scaffolding ✅ (2026-07-18)

Demande utilisateur : « implémenter la totale avec YOLO » (Palier 3 de
l'analyse ML). Objectif : un détecteur d'objets reconnaît les pièces sur le
plateau entier, au lieu du template matching case par case.

Découpage assumé : l'ENTRAÎNEMENT du modèle (dataset annoté + GPU) tourne hors
de la session de dev (Colab / Mac). La Phase A livre TOUT le reste — l'app et
les tests fonctionnent avant même que le modèle existe, par repli automatique.

### Fait (côté app, complet et testé)
- **`BoardClassifying`** : protocole « plateau entier » parallèle à
  `SquareClassifying` (un détecteur regarde l'image redressée d'un tenant, pas
  64 vignettes). Rend `nil` si indisponible → repli en silence.
- **`YOLOBoardClassifier`** : charge `ChessPiecesYOLO.mlpackage` du bundle PAR
  URL (pas de classe générée : compile et tourne sans modèle) et fait tourner
  Vision (`VNCoreMLRequest` → `VNRecognizedObjectObservation`).
- **`YOLODetectionMapper`** (pur, 7 tests) : détections → grille 8×8 → FEN.
  Ancrage BAS-CENTRE remonté d'une demi-case (robuste aux glyphes hauts comme
  le roi, et à la ligne de grille pile sous la boîte) ; collision sur une case
  tranchée par la confiance ; confiance des détections → surlignage « case
  incertaine » existant.
- **`PieceLabel`** : 12 classes couleur×type, `trainingOrder` = contrat avec
  `data.yaml`, verrouillé par un test.
- **`ScannerViewModel`** : essaie YOLO d'abord pour les sources numériques,
  retombe sur les gabarits sinon — comportement identique tant que le modèle
  n'est pas livré.

### Fait (scaffolding d'entraînement, `scripts/yolo/`)
- `generate_synthetic.py` : dataset 2D synthétique (python-chess + cairosvg),
  positions plausibles, styles de plateau variés, perturbations (flou, bruit,
  JPEG) — vérité terrain gratuite et parfaite, robustesse aux jeux inconnus.
- `train.py` : entraînement YOLO11n (Ultralytics) + export Core ML avec NMS
  intégré (Vision renvoie directement des observations, zéro post-traitement).
- `data.yaml` (contrat de classes) + `README.md` (pistes A synthétique / B
  photos réelles, licences, insertion du `.mlpackage` dans Xcode).

### Décisions d'architecture
- **YOLO sur l'image REDRESSÉE** (800×800) et non l'image brute : réutilise la
  localisation déjà résolue (`CheckerboardDetector` + `BoardRectifier`), rend
  le mapping boîte→case trivial et déterministe. Variante perspective +
  homographie notée pour plus tard.
- **Repli automatique plutôt qu'exigence** : l'app ne DÉPEND jamais du modèle.
  C'est ce qui permet de livrer la Phase A tout de suite et d'activer YOLO
  d'un simple glisser-déposer du `.mlpackage`.
- **YOLO11n** (nano) : quelques Mo, ami du Neural Engine — adapté au mobile.

### Reste (hors session de dev)
- Phase B : générer le dataset, entraîner, exporter → `ChessPiecesYOLO.mlpackage`
  (scripts fournis).
- Phase C : déposer le modèle, calibrer les seuils sur fixtures, ajuster l'UI,
  tester avec le modèle réel présent.
- Phase D (option) : piste B photos réelles + variante image brute perspective.

### Vérifié
- **303 tests unitaires / 44 suites** verts (dont 7 nouveaux : mapper +
  pipeline plateau-entier avec détecteur fictif), **sans avertissement**.
- Parcours UI du scanner toujours vert : modèle absent → repli propre sur les
  gabarits, comportement inchangé.

### Suite — libellés tolérants à N'IMPORTE QUEL modèle (2026-07-18)
Pour pouvoir déposer un modèle tout fait (Hugging Face, Roboflow) sans éditer
le code à chaque fois — chacun nomme ses classes autrement :
- **`PieceLabelResolver`** reconnaît les conventions du terrain : kebab
  (`white-pawn`), espaces/majuscules (`White Pawn`), camelCase (`whiteBishop`),
  lettre FEN (`P`/`p`, la casse = la couleur), code deux lettres (`wp`, `wb`),
  ordre inversé (`pawn_white`). Rejette le reste (`corner`, `board`).
- `YOLODetectionMapper.Detection` porte désormais `color`/`kind` directement,
  découplé de l'enum figé ; le résolveur fait le pont modèle → app.
- `train.py --imgsz` : exporter un modèle tout fait à sa résolution native
  (ex. 416 pour yamero999), sinon Vision et le modèle divergent.
- **310 tests / 45 suites** verts (dont 7 nouveaux pour le résolveur).

## Chien de garde moteur — plus jamais d'écran figé sur un Stockfish muet ✅ (2026-07-19)

### Fait
- **`EngineWatchdog`** : toute attente moteur court désormais contre une
  échéance (`graceMs = 8000` au-delà du budget de recherche demandé). La
  première arrivée gagne, l'autre tâche est annulée.
- Câblé dans les **4 modes** : Jouer (alerte gaffe, barre d'éval), Analyse
  (menace, analyse continue, classification), Laboratoire (série de parties),
  Hello (écran de diagnostic).
- **Redémarrage d'office** du moteur détecté muet, réglages de session
  RÉÉMIS : threads, `Hash`, et force Elo. Un `restart` nu repartait sur 1
  thread / 16 Mo — moteur affaibli en silence — et aurait fait jouer un
  moteur réglé à 1400 Elo comme un maître.
- `synchronize()` devient bornée et rend `Bool`.

### Décisions d'architecture
- **L'annulation conclut le perdant** : l'itération d'un `AsyncStream` se
  termine à l'annulation de sa tâche, donc pas de lecteur fantôme accroché au
  flux. Un `bestmove` tardif d'un moteur seulement LENT est évacué par la
  barrière `synchronize()` avant la recherche suivante.
- **Marge large à dessein** : un appareil chargé ou en surchauffe étire
  légitimement un `movetime`. Un faux positif redémarrerait un moteur sain en
  pleine partie.
- **`os_log` et jamais `print`** : stdout est le canal UCI de ChessKitEngine.

### Deux bugs trouvés en chemin
- **`await task.value` n'est PAS interrompu par l'annulation.**
  `withTaskGroup` attend tous ses enfants avant de rendre la main : dans
  `stopLiveAnalysisIfNeeded()`, le chien de garde serait resté suspendu POUR
  TOUJOURS à l'échéance — exactement le gel qu'il devait supprimer, au point
  le plus fréquenté de l'écran d'analyse. Corrigé par un relais
  `withTaskCancellationHandler` qui annule la tâche non structurée.
- **ChessKitEngine SEGFAULTE si on écrit dans un moteur non démarré**
  (`EXC_BAD_ACCESS` à `0x50` dans `EngineMessenger.sendCommand:`). Le
  commentaire de `synchronize()` affirmait l'inverse (« `send` est ignoré »).
  Bug LATENT de `HEAD`, qu'aucun des 341 tests ne touchait, et que ce lot
  rendait bien plus probable puisqu'il ajoute des redémarrages automatiques.
  Garde `isRunning` posée dans `send(_:)`, seul point d'écriture vers le
  moteur.

### Vérifié
- **345 tests / 51 suites** verts (baseline `HEAD` mesurée à 341 / 50 :
  +4 tests, +1 suite, zéro régression).
- Le test du segfault n'est pas décoratif : sans la garde, il tue le
  processus de test — c'est ainsi qu'il a été découvert.

### Note d'environnement
`xcodebuild` se bloque indéfiniment sur une lecture coordonnée de
`ChessLab.xcodeproj` (`NSFileCoordinator._blockOnAccessClaim:`) : le projet
est sous `~/Desktop`, synchronisé par iCloud Drive. Contournement retenu ici :
compiler depuis une copie hors zone synchronisée. Déplacer le dépôt hors du
Bureau réglerait la cause.

## Analyser — la flèche fantôme « e2-e4 » en milieu de partie ✅ (2026-07-19)

### Fait
La boucle d'analyse en continu écrivait `hintMoves`, `liveDepth` et
l'évaluation courante sans vérifier que la position analysée était encore
celle affichée. Elle ne se gardait que par `isLiveAnalyzing`, drapeau
PARTAGÉ du view model et non propre à la tâche : dès que la navigation
relançait une analyse, il repassait à `true` et les réponses TARDIVES de la
position précédente — encore en vol sur le flux — franchissaient de nouveau
la garde pour réécrire les flèches. D'où un « e2-e4 » affiché en plein
milieu de partie, coup pourtant impossible.

La tâche capture désormais le FEN qu'elle analyse et n'écrit plus rien si
l'écran en montre un autre — même discipline que `computeThreat()`, qui
avait déjà ce contrôle.

### Décisions d'architecture
- `clearArrows()` n'était pas en cause : il nettoie AVANT la nouvelle
  analyse, et c'est APRÈS qu'on resalissait. Corriger le nettoyage n'aurait
  rien donné ; c'est l'écriture qu'il fallait garder.
- La garde couvre aussi la barre d'éval et la profondeur, écrites dans la
  même boucle : elles pouvaient afficher un score de la position précédente
  sans le moindre signe visible.

### Vérifié
- **345 tests / 51 suites** verts, sans régression.

### Piste ABANDONNÉE dans la même session : couleur des pièces mesurée
Tentative de décorréler la couleur du modèle YOLO (12 classes mêlant
couleur et type) en la mesurant sur les pixels. **Deux mécanismes essayés,
deux régressions sur images RÉELLES**, donc annulé :
- luminance absolue, fond de case écarté → couleurs INVERSÉES (15 échecs) :
  sur pièce blanche/case claire, le remplissage blanc était jeté avec le
  fond, ne laissant que le contour noir du glyphe.
- écart signé au fond → 6 échecs, une fixture PIRE qu'avant (62 → 58).

Les 9 tests unitaires écrits pour l'occasion passaient tous : ils validaient
la théorie, pas la réalité. Ce sont `ScannerFixtureTests` et
`ReadingOrientationTests` — vraies photos dans le vrai pipeline — qui ont
arrêté la régression.

Pour reprendre : instrumenter d'abord le pipeline pour SORTIR les
luminances réellement mesurées sur les fixtures qui échouent, au lieu de
raisonner sur des cas idéalisés. Sinon, ré-entraîner en 6 classes (type
seul) reste la voie de fond.

## Accueil — suppression de la carte « Entraînement du jour » ✅ (2026-07-19)

### Fait
Carte retirée à la demande de l'utilisateur (jugée sans utilité), avec tout
ce qui n'existait que pour elle : `trainingSummary`, `dueStat(...)`, les
`@State` `dueRepertoireCount`/`duePuzzleCount`, `refreshDueCounts()` et ses
QUATRE points d'appel.

### Décisions d'architecture
- Le gain n'est pas seulement visuel : deux des appels supprimés étaient des
  `onChange` — fin du préchargement Lichess, et `path.count` à CHAQUE retour
  à l'accueil — qui déclenchaient des `fetchCount` SwiftData. L'accueil fait
  désormais strictement moins de travail à chaque navigation.
- Clés `Localizable.xcstrings` laissées en place : inertes une fois le code
  parti, et y toucher risquerait plus que ça ne rapporte sur un fichier de
  7 800 lignes déjà modifié par ailleurs.

### Vérifié
- **345 tests / 51 suites** verts, sans avertissement. Aucun test, unitaire
  ou UI, ne s'appuyait sur cette carte.

## Harnais de mesure du budget de recherche (analyse) ✅ (2026-07-19)

### Fait
`EngineSearchBudgetBenchmark` : un INSTRUMENT, pas un test. Il ne vérifie
rien et ne peut pas échouer — il produit un tableau. Pour 4 positions
(ouverture, milieu calme, milieu TACTIQUE, finale), en MultiPV=2 avec les
vrais réglages threads/`Hash` de l'app, il relève `depth`, `seldepth`,
`nodes` et temps réel sous trois limites : `movetime 400` (réglage actuel de
`rankedEval`), `movetime 700` (plafond envisagé) et `depth 20`.

### Pourquoi
La classification coûte ~500 ms/coup (`movetime: 400` + enrobage). Question
ouverte : quelle profondeur cela atteint-il réellement, et un plafond à
700 ms serait-il rare ou permanent ? Sans ces chiffres, choisir entre
400 ms, 700 ms, profondeur 20 ou N nœuds reste une préférence esthétique.

### Décisions d'architecture
- **Désactivé par défaut** (`CHESSLAB_BENCH=1`) : vérifié, il est bien
  `skipped` et la suite reste à 175 s contre 169 s de baseline. Actif, il
  ajouterait plusieurs minutes pour zéro assertion.
- **`os_log`, jamais `print`** : stdout est le canal UCI de ChessKitEngine.
- **Rodage jeté** : la première recherche remplit la table de hachage.
- **Arrêt explicite du moteur**, pas un `defer` — `defer` ne peut pas
  attendre, et un Stockfish laissé vivant chercherait derrière les tests
  suivants.
- **État thermique relevé en début ET en fin** : l'écart est un résultat en
  soi. Si l'appareil chauffe en 4 positions, une analyse de partie entière
  (40 à 80 recherches) tourne surtout sous budget réduit, et la profondeur
  mesurée à froid n'est pas celle que voit l'utilisateur.

### À exécuter sur APPAREIL RÉEL
Le simulateur tourne sur le CPU du Mac, 3 à 5× plus rapide qu'un iPhone.
Calibrer une profondeur cible sur des chiffres de simulateur garantirait que
les vrais appareils tapent le plafond de temps en permanence — le défaut
même qu'on cherche à éviter.

### Reste à faire
Mesure 3 — la dérive de classification : rejouer de vraies parties sous les
deux réglages et sortir la matrice des changements de `MoveQuality`. C'est
le seul chiffre qui parle d'expérience utilisateur. Les seuils de
`MoveClassifier` ayant été calibrés à 400 ms, changer la profondeur les
déplace — et les parties DÉJÀ analysées (annotations NAG persistées) ne
seraient plus cohérentes avec les nouvelles.

## Analyse — budget de recherche en NŒUDS plutôt qu'en temps ✅ (2026-07-19)

### Fait
`rankedEval` passe de `movetime: 400` à **`nodes: 300000, capMs: 1500`**
(UCI s'arrête à la première limite atteinte). Génération de puzzles :
`nodes: 900000, capMs: 4500` — même rapport triple que l'ancien 1200/400.
Nouveau `ThermalMonitor.nodeFactor`, distinct de `movetimeFactor`.

### Mesuré (iPhone 17 Pro, **Release**, MultiPV=2)
`movetime 400` atteignait la profondeur **11 à 13** en milieu de partie —
loin des 18-20 visés par Lichess/chess.com. `depth 20` coûtait 6 à 8,5 s
par position, soit 8 à 11 min pour une partie : inutilisable. Et une finale
atteignait la profondeur 20 en **109 ms** tout en consommant ses 400 ms.

À `nodes 300000` : ~600-750 ms en milieu de partie (4 threads), **229 ms**
sur finale, **~2,4 s à 1 seul thread**. Le plafond `capMs` ne mord donc
qu'en régime dégradé.

**Dérive de classification mesurée sur 40 demi-coups : 9 changements, TOUS
dans la bande des bons coups** (`excellent`→`best`, etc.). Aucune faute
n'est reclassée — l'unique gaffe de la partie est identifiée à l'identique
sous les deux réglages. Les seuils de `MoveClassifier` n'ont donc PAS
besoin d'être recalibrés, et les parties déjà annotées restent cohérentes
sur ce qui compte.

### Décisions d'architecture
- **La surchauffe rabote le TRAVAIL, pas le temps.** Appliquer
  `movetimeFactor` à une recherche bornée en nœuds serait contradictoire :
  les deux limites se combattraient et la première atteinte gagnerait au
  hasard de la charge, ruinant la reproductibilité recherchée.
  `movetimeFactor` reste pour Jouer et le Laboratoire, dont les budgets
  sont légitimement temporels.
- **Pas de plafond de PROFONDEUR**, envisagé puis écarté : les nœuds
  bornent déjà le travail, et là où la profondeur monte haut (finales) elle
  monte parce que les nœuds y sont bon marché. Une troisième limite n'aurait
  ajouté que des interactions à démêler.
- **Déterminisme non absolu** : la recherche multi-threads explore dans un
  ordre dépendant de l'entrelacement. Mais ce résidu est sans commune
  mesure avec la dépendance à la vitesse de l'appareil, qui disparaît.
- Observation inattendue : à budget de nœuds égal, le MONO-thread atteint
  une profondeur SUPÉRIEURE (16 vs 13). La recherche parallèle gaspille des
  nœuds en explorations redondantes — les threads achètent de la vitesse,
  pas de la qualité par nœud.

### Pièges rencontrés (harnais de mesure)
- Variable d'environnement ignorée sur appareil → préfixe `TEST_RUNNER_`.
- **Debug fausse tout** : Stockfish y tourne ~7× moins vite (62 000 nœuds/s
  contre 460 000). Le premier tableau, en Debug, était inexploitable.
- `@testable` refusé en Release → `ENABLE_TESTABILITY=YES`.
- Les blocs `#if DEBUG` d'`EngineController` manquent en Release et la
  cible de test ne compile plus → `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG`.
- **`-only-testing` au niveau de la FONCTION ne sélectionne rien** en Swift
  Testing, et `xcodebuild` rend `exit 0` avec « 0 tests » — un succès
  apparent. Uniquement `Cible/Suite`.
- **Swift Testing parallélise par défaut** : deux tests démarrant chacun un
  Stockfish font planter le runner, `stdout` étant la ressource UCI GLOBALE
  de ChessKitEngine. D'où `@Suite(.serialized)`.
- Un test à deux passes (4 threads puis 1) se bloquait à 120 s : son
  redémarrage moteur en cours de test laissait un flux bancal. SUPPRIMÉ —
  un instrument qui ment est pire que pas d'instrument. Démarré directement
  à 1 thread, tout passe : **ce n'était pas un bug de production**.

### Vérifié
- **348 tests / 53 suites** verts. Les deux suites de mesure restent
  ignorées par défaut (`CHESSLAB_BENCH=1` pour les activer).

## Accueil — identité visuelle : wordmark, logo, et composants rehaussés ✅ (2026-07-19)

### Fait
Le grand titre iOS système « ChessLab » (jugé peu attrayant) est remplacé
par un header maison dans le contenu : pastille-logo (cavalier cburnett sur
tuile dégradé émeraude, halo doux) + wordmark bicolore « Chess » blanc /
« Lab » dégradé, police arrondie, tagline localisée FR/EN. Barre de
navigation transparente, bouton Réglages en pastille circulaire.
- Bannière « Reprendre la partie » promue en CTA plein dégradé à texte
  sombre — l'action principale ne ressemble plus à une carte grise.
- Cartes de mode : bordure en dégradé de leur teinte + flèche de lancement.
- Titres de section : tiret dégradé en préfixe.
- **`IconBadge` refondu** (propage sur 10+ écrans) : pastille pâle → tuile
  pleine teinte en dégradé, icône SOMBRE, liseré lumineux. Le langage des
  chips sélectionnées étendu à toute l'app ; contraste garanti sur toutes
  les teintes (une icône blanche sur le jaune `warning` était illisible).
- **`AppBackground`** : fond plat → dégradé vertical + 3e halo violet.

### Décisions d'architecture
- `Text(verbatim:)` pour « Chess »/« Lab » : une MARQUE ne se traduit pas,
  et ça n'engendre aucune clé de localisation parasite.
- Le wordmark concaténé garde le label d'accessibilité « ChessLab » (+
  `accessibilityLabel` explicite) : le test UI de fumée s'accroche à
  `staticTexts["ChessLab"]`. Identifiant `openSettings` conservé.
- Clé tagline insérée CHIRURGICALEMENT dans le xcstrings (pas de
  réécriture JSON globale d'un fichier de 7 800 lignes).

### Vérifié
- **348 tests / 53 suites** verts.

## Écrans d'options — sections identifiables d'un coup d'œil ✅ (2026-07-19)

### Fait
`SettingsSection` gagne `systemImage`/`tint` optionnels : petite tuile
d'icône dans la teinte de la SECTION (façon Réglages iOS), la teinte
reprenant celle du mode parent — le code couleur des cartes de l'accueil
se prolonge jusque dans les écrans de réglage. Les 22 sections des 7
écrans annotées : Nouvelle partie (émeraude), Deux joueurs (bleu), Labo
(rose), Éditeur de position (jaune), Scanner (sarcelle).

### Décisions d'architecture
- Teinte pâle + icône colorée, PAS la tuile pleine d'`IconBadge` : dans le
  langage établi par les chips, « plein dégradé » signifie sélectionné/actif
  — un en-tête de section est passif, il prend le registre au repos. Et à
  22 pt, un dégradé plein serait brouillon.
- Paramètres optionnels avec défauts : aucun appelant cassé, le repli sans
  icône garde le tiret dégradé de l'accueil.
- Titres inchangés → zéro nouvelle clé de localisation. Icônes décoratives
  masquées de VoiceOver.

### Vérifié
- **348 tests / 53 suites** unitaires verts, ET les suites UI de fumée
  exécutées pour de vrai (vérifié ligne à ligne — deux « 0 test exécuté »
  silencieux déjà rencontrés aujourd'hui) : `testAppLaunches`
  (`staticTexts["ChessLab"]`), `HelpRouteUITests` (`openSettings`),
  `testPlayAGameMove` / `testSettingsArePersistedBetweenGames` qui
  traversent le nouvel écran Nouvelle partie.

## Ouvertures — noms français dans la bibliothèque ✅ (2026-07-19)

### Fait
Les 149 familles d'ouvertures de `opening_library.json` s'affichent en
français quand l'app est en français : « Partie espagnole » (Ruy Lopez),
« Défense russe » (Petrov), « Gambit dame », est-indienne/ouest-indienne…
Conventions vérifiées sur Wikipédia FR (liste ECO) à la demande de
l'utilisateur. Coups dans les noms en notation française (« avec Ff5 »).

### Décisions d'architecture
- La DONNÉE garde sa clé anglaise stable (générée du dataset
  lichess-org/chess-openings) ; seul l'AFFICHAGE traduit, via le catalogue
  (`Text(LocalizedStringKey(family))`) — la doctrine bilingue existante.
  149 clés insérées dans le xcstrings par script, avec assertion de
  couverture (zéro manquante, zéro orpheline) et validation JSON.
- La recherche matche le nom AFFICHÉ ET le nom anglais : « sicilienne »
  trouve la Sicilienne, « Ruy Lopez » aussi.
- Le commentaire du modèle documentait la décision INVERSE (« pas de
  traduction ») : réécrit — demande utilisateur du 19/07, nouveau contrat
  « jamais de Text(family) brut ».

### Vérifié
- **348 tests / 53 suites** verts (les tests n'utilisent `family` que
  comme clé de données, jamais comme affichage).

### Suite — tri français de la bibliothèque (2026-07-19)
Remarque utilisateur immédiate après la traduction : la liste restait triée
sur la clé ANGLAISE de la donnée — « Partie espagnole » rangée au R de
« Ruy Lopez ». Tri déplacé sur le nom AFFICHÉ (`localizedStandardCompare`,
accents à la française) ; en anglais l'ordre d'origine est inchangé.
**348 / 53 verts.**

## YOLO — styles chess.com dans le générateur ; modèle époque-9 REJETÉ ✅ (2026-07-19)

### Fait
- **Palette chess.com MESURÉE** sur une capture réelle fournie par
  l'utilisateur (archivée : `scripts/yolo/reference/chesscom-capture.jpg`) :
  cases `#EEEED6`/`#7C955C`, pièces blanches `#F8F8F8`, pièces noires
  **`#545351` — un gris MOYEN**, hors de la plage d'entraînement existante
  (`#000000`→`#4A4A4A`, côté clair). Cause directe et vérifiable des pièces
  noires prises pour des blanches sur les captures chess.com.
- `generate_synthetic.py` : +3 styles de pièces qui ENTOURENT la valeur
  mesurée (pour apprendre un intervalle, pas un point) + le vert chess.com
  iOS relevé. Dataset régénéré (8000+1000), présence du gris vérifiée dans
  les images produites.

### Le modèle réentraîné est REJETÉ — et c'est le processus qui a marché
Entraînement YOLO11n relancé, arrêté à l'époque 9 (~35 min/époque sur MPS ;
100 époques ≈ 50 h, intenable) avec des métriques de validation parfaites
(mAP50 0,995, précision/rappel 1,0). Export Core ML, dépôt dans la copie de
test, confrontation aux fixtures RÉELLES :
- `chesscom_endgame_rook` : 60/64 corrects (min 64), 4 erreurs muettes (max 2)
- `chesscom_endgame_pawns` : 61/64 (min 63), 3 erreurs muettes (max 1)
→ PIRE que le modèle en place, qui passe tout. **Poubelle, ancien modèle
conservé.** Un mAP parfait sur validation synthétique ne transfère pas ;
9 époques ne suffisent pas à généraliser. La règle « le juge est la fixture
réelle, pas la métrique d'entraînement » — posée avant le résultat — a
empêché de commiter un modèle flatteur et régressif.

### Reste (hors session)
Entraînement COMPLET (100 époques / early-stop patience 20) : ~50 h sur ce
Mac, ou une nuit sur GPU cloud. Puis même protocole : export, fixtures,
et idéalement une fixture supplémentaire de position DENSE chess.com
(la capture de référence est une position initiale 32 pièces, parfaite
pour ça) — les finales actuelles testent peu la confusion de couleur.

### Note d'environnement (répétée, car 4e occurrence aujourd'hui)
iCloud/Desktop a bloqué DEUX exports Core ML (python figé dans un `read()`
jamais rendu, ~0 s de CPU en 20+ min — diagnostic via `sample <pid>`) et un
`git commit`. Remède systématique : travailler depuis /tmp.

## Revue de code — correction des trois lots détectés ✅ (2026-07-20)

### Lot A — trou de localisation systémique
La revue a trouvé ~10 fonctions d'aide affichant du `String` VERBATIM
(`Text(param)` sans lookup catalogue) sur 8 écrans : panneau de fin de
partie des deux modes (« Accueil », « Revanche »), cartes d'entrée
d'analyse, boutons de sortie de l'éditeur, contrôles et stats du Labo,
cartes du répertoire. En anglais, tout restait français — VoiceOver
compris. La vérification bilingue du 18/07 ne voyait que les `Text("…")`
directs ; le motif indirect passait sous le radar.

Corrections :
- 10 signatures `String` → `LocalizedStringKey`.
- `GameOutcome` : phrases composées via `LocalizationController.string` ;
  `frenchLabel` → `displayLabel` (le nom documentait le bug).
- Deux `String(localized:)` remplacés (LabRunView, AnalysisViewModel) —
  le piège documenté « langue OS ≠ choix in-app ».
- **43 clés ajoutées** au catalogue (traductions EN incluses, y compris
  les interpolées « Gagnées %lld »…) + la clé manquante de PuzzleQueueView.
- ModeCard : `lineLimit`/`minimumScaleFactor` (hauteur figée 132 pt vs
  tailles d'accessibilité XXL).

À vérifier de visu (aucun test automatique ne couvre le RENDU anglais) :
basculer l'app en anglais et regarder un panneau de fin de partie.

### Lot B — autosave sur l'horloge précise
Les deux autosaves lisaient `whiteRemaining`/`blackRemaining` (valeurs
PUBLIÉES, au pas d'affichage — jusqu'à 1 s de retard) au lieu de
`remaining(for:)`, en contradiction avec le contrat écrit dans `GameClock`
même. Corrigé dans PlayViewModel et TwoPlayerViewModel.

### Sain, vérifié pendant la revue
Zéro `print()` (stdout = UCI), zéro `try!`/`as!`, teardown moteur couvert
partout où il y a un moteur, pause d'horloge en arrière-plan correcte dans
les deux modes, observers nettoyés, annonces VoiceOver, `reduceMotion`
respecté, états vides présents.

### Vérifié
- **348 tests / 53 suites** verts sur l'état combiné A+B.

## Scanner — recroisement YOLO × gabarits + garde-fous de cohérence (2026-07-20)

### Fait (modules développés par l'utilisateur dans un autre environnement,
### intégrés et vérifiés ici)
- **`BoardConsistency`** (nouveau, pur) : abaisse la confiance des lectures
  IMPOSSIBLES aux échecs (pion sur rangée de fond, 2 rois d'une couleur, roi
  manquant → dames suspectes, > 8 pions) pour qu'elles soient SURLIGNÉES à la
  confirmation. Ne corrige jamais en silence : avoue le doute. Branché dans
  les deux variantes de `BoardScanner.scan(...)`.
- **Recroisement YOLO × gabarits** (`BoardScanReading.crossChecked(against:)`
  + `ScannerViewModel.boardScan(rectified:squares:)`) : le classifieur par
  gabarits donne un second avis ; là où il est SÛR et contredit YOLO, la case
  est signalée (occupation YOLO conservée). Rattrape une pièce manquée par
  YOLO. Les gabarits se taisent sur un jeu inconnu (scores effondrés) → pas
  d'inondation de faux signalements.
- **Nouveau modèle** `ChessPiecesYOLO.mlpackage` entraîné sur 50 jeux réels
  (30 Lichess + 20 chess.com). Remplace l'ancien.
- `ScannerFixtureTests` reflète le vrai chemin (YOLO + recroisement) ;
  `maxSilentlyWrong` mesure ce qui compte : l'erreur NON signalée.

### Vérifié
- **359 tests / 55 suites** verts (+11/+2 : `BoardConsistencyTests`,
  `ScanCrossCheckTests`). Les 3 fixtures réelles + `YOLORealModelOrientation`
  PASSENT avec le nouveau modèle — là où le modèle époque-9 du 19/07 échouait
  (60/64, 61/64). Groupes synchronisés Xcode 16 : les 2 fichiers neufs
  s'incluent sans toucher au pbxproj.

### En attente (décision utilisateur)
- `scripts/yolo/piece-sets/` (20 jeux chess.com PROPRIÉTAIRES) NON commités :
  redistribution d'images propriétaires sur un dépôt GitHub public. Pipeline
  de réentraînement fourni mais laissé hors commit tant que la question de
  licence n'est pas tranchée.
- Le modèle reste un « starter » (14 epochs CPU) ; réentraînement Colab GPU
  (100 epochs, ~15 min) recommandé pour la qualité maximale.
- Dossier `chesslab-scanner-changes/` conservé (contient le pipeline) —
  suppression après décision sur les piece-sets.

### Finalisation (2026-07-20)
- Pipeline de réentraînement mis à jour : `generate_synthetic.py` (285→494
  lignes : rendu SVG Lichois ET PNG chess.com auto-détectés via
  `--piece-sets-dir`), `README.md`, `data.yaml` (commentaires + chemin local).
- **50 jeux de pièces déposés dans `scripts/yolo/piece-sets/` mais
  GITIGNORÉS** : les 20 jeux chess.com sont propriétaires — présents en local
  pour réentraîner, jamais poussés sur GitHub. Réentraînement fonctionnel
  d'emblée (`--piece-sets-dir ./piece-sets`).
- Dossier source `chesslab-scanner-changes/` supprimé (tout intégré) ；
  doublons macOS « … 2.py » nettoyés.

## Analyse — optimisations moteur (tune-analysis.md), pool NON livrable (2026-07-20)

### Le pool de moteurs (Task 1) est IRRÉALISABLE sur ChessKitEngine
tune-analysis.md demandait un pool de K moteurs mono-thread cherchant EN
PARALLÈLE (reproductibilité + vitesse). Vérifié à la source
(`EngineMessenger.mm`) : chaque instance fait `dup2(pipe, fileno(stdout))`
et `dup2(pipe, fileno(stdin))` — elle détourne le `stdin`/`stdout` GLOBAL du
processus. Un second moteur écrase la redirection du premier ; les moteurs
surnuméraires ne reçoivent plus AUCUNE sortie et toute recherche sur eux
expire. Deux moteurs qui cherchent en même temps ne sont pas « lents », ils
sont cassés. C'est précisément pourquoi l'app a déjà `EngineInstanceCounter`
et un test de fuite (la lib est mono-moteur-actif par construction).

Le document prévoyait ce cas : « si tu ne peux pas livrer le pool proprement,
garde la classification actuelle (moteur partagé, threads inchangés) et
signale-le — ne livre pas de mono-thread séquentiel sans parallélisme ». Fait :
classification INCHANGÉE (moteur partagé, multi-thread). Pas de test de
reproductibilité ni de fuite de pool (sans objet).

### Livré (indépendant du pool)
- **Tâche 2** : `refreshDerivedData` retiré de `classifyNode` (rendait la
  boucle quadratique sur le MainActor), COALESCÉ dans la boucle (tous les
  4 nœuds) + un final ; immédiat dans `ensureEvaluatedLazily`.
- **Tâche 3** : budget de nœuds réduit dans l'ouverture (80 000 au livre
  contre 300 000), appliqué au chemin de classification via `baseNodeBudget`.
- **Tâche 4** : analyse en continu ET indice de Jouer bornés en profondeur
  (`go depth 22 movetime 8000`) au lieu de `go infinite` — les cœurs ne
  tournent plus à 100 % tant qu'une position reste affichée ; `ThermalMonitor.
  liveDepth` plafonne à 16 en surchauffe.
- **Tâche 5** : `engineHashMB` adaptatif à la RAM (128/64/32 Mo).
- **Tâche 1e** (gardé, utile sans pool) : conversion d'éval factorisée en
  helpers purs `terminalCachedEval` / `makeCachedEval`, partagés — une seule
  logique de verdict.
- **Décision respectée** : threads du moteur partagé INCHANGÉS (pas de
  `recommendedAnalysisThreads`).

### Vérifié
- **359 tests / 55 suites** unitaires verts, sans régression ni warning.
- `EngineLeakUITests` (fuite d'instances) : VERT sur simulateur propre
  (aliveCount == 0 après le tour) — le bornage de `go infinite` ne laisse
  fuiter aucun moteur. (Sur un simulateur dégradé par une longue journée de
  builds, il échoue à l'IDENTIQUE sur `HEAD` sans mes changements : flake
  d'environnement, pas de régression — confirmé par comparaison baseline.)
- `AnalysisReviewUITests` : vert.

## Scanner YOLO seul + bibliothèque : heure et longueur (2026-07-20)

### Scanner — « Que scannez-vous ? » supprimé (demande utilisateur)
La section et l'option « Plateau réel » disparaissent : le scanner ne traite
plus que les échiquiers À L'ÉCRAN, lus par YOLO. `ScanSubject` (qui n'existait
que pour piloter cette section) est supprimé, ainsi que le helper `tint(for:)`.
`resolveSourceAndDetect` ne garde que la déduction capture / photo d'écran —
toutes deux `isDigitalDiagram`, donc toutes deux sur la route YOLO. Plus
aucune question posée à l'utilisateur.

**Reste inatteignable depuis l'UI** (non supprimé, à trancher) :
`ScanSource.physicalTopDown`, `PhysicalOccupancyClassifier` (437 lignes) et
leurs tests, plus le flux « Pièces à préciser ». Les retirer est une seconde
coupe, bien plus large (un test UI + ~200 lignes de tests unitaires) : laissée
à la décision de l'utilisateur plutôt que décidée seule.

### Bibliothèque des parties — heure + nombre de coups
- **Heure** ajoutée à la date (`date.formatted(date:.abbreviated, time:.shortened)`) :
  deux parties du même jour ne se distinguaient pas ; le format suit la locale.
- **Nombre de coups** : nouveau champ STOCKÉ `GameRecord.moveCount` (demi-coups,
  même unité que le « coup(s) joué(s) » de la bannière de reprise), rempli à
  l'enregistrement des deux modes via l'unique `GameLibraryService`.
  - Stocké et non dérivé : reparser chaque PGN à chaque rendu de ligne serait
    absurde sur une bibliothèque de centaines de parties. Champ optionnel →
    migration SwiftData additive, sans risque.
  - `backfillMoveCounts` rattrape les parties enregistrées AVANT le champ (une
    seule fois, à l'ouverture de la bibliothèque) : sinon l'existant restait
    muet sur sa longueur pour une donnée pourtant présente dans le PGN. PGN
    illisible ignoré, sauvegarde seulement si quelque chose a changé.

### Style
« Coller » harmonisé avec « Photothèque » / « Appareil photo » : pleine
largeur, même rayon, même surface. Son libellé reste rendu par le SYSTÈME
(`PasteButton` ne permet pas de label personnalisé) — conservé malgré tout,
car lui seul colle sans déclencher l'alerte de permission d'iOS.

### Vérifié
- **359 tests / 55 suites** verts.

### Suite — purge du plateau réel + logo + « Coller » (2026-07-20)

**« Coller » au même look que les deux autres entrées** (demande utilisateur) :
`PasteButton` remplacé par un bouton ordinaire portant le même
`ScannerEntryLabel` (pastille violette + icône presse-papiers + chevron). Le
libellé d'un `PasteButton` est rendu par le SYSTÈME et ne peut pas être
remplacé — d'où le remplacement. Contrepartie assumée : iOS peut afficher son
invite de collage. Atténuée en consultant `hasImages` d'ABORD (contrôle de
métadonnée, aucune invite) : un presse-papiers sans image est refusé sans que
son contenu soit jamais lu. Logique placée dans le view model, seul détenteur
d'`errorMessage`.

**Logo de l'accueil** : `IMG_7047.png` → asset `AppLogo`, qui remplace la
TUILE ENTIÈRE (dégradé + liseré + glyphe de cavalier). L'illustration porte
déjà son cadre émeraude et son fond : deux cadres empilés se seraient
contrariés. Gabarit et lueur inchangés.

**Purge du scanner de plateau réel** (suite de la décision UI) :
supprimés `PhysicalOccupancyClassifier` (437 l.), `PhysicalBoardScannerTests`
(~200 l.), `ScanSource.physicalTopDown`, `isDigitalDiagram` et ses 7 sites
d'appel simplifiés, le test UI « plateau réel », `SyntheticPhysicalBoard`,
`ScanTestImage.renderPhysical`, le champ de fixture `occupancyAndColorOnly`,
le bouton « Pivoter 90° » et `rotateReading()`.

Deux pièges que seule la compilation a révélés :
- **`RGBColor` était enterré dans le fichier du plateau réel** mais servait à
  `CheckerboardDetector` et `BoardGridFinder` — le cœur de la détection.
  Or de tout ce type, seule `median([Double])` avait encore des appelants :
  extraite dans `Median.swift` (`Sample.median`). Ressusciter la structure
  entière n'aurait fait que remplacer du code mort par du code mort.
- Le bloc `else` du bouton « Pivoter 90° » restait orphelin après retrait de
  son `if` — accolades déséquilibrées.

**GARDÉ délibérément** : `unknownPieces` / « Pièces à préciser ». Malgré sa
mention initiale, ce n'est pas de la plomberie scanner mais une capacité
GÉNÉRALE de `PositionEditorViewModel` (10 usages, tests dédiés) ; le type
`SquareOccupancy` porte `kind` optionnel indépendamment du scanner. La retirer
serait un refactor de l'éditeur, pas un nettoyage d'orphelin.

**Vérifié : 346 tests / 54 suites verts** (contre 359/55 : la baisse est
exactement les tests du plateau réel, partis avec la fonctionnalité). Toutes
les suites scanner restantes sont vertes, fixtures réelles comprises.

## Analyse — barème d'évaluation resserré + règles affinées ; puzzle restylé ; théorie plus profonde (2026-07-20)

### Barème resserré (valeurs choisies par l'utilisateur)
Excellent 0-2 %, Bon coup 2-5 %, Imprécision 5-10 %, Erreur 10-20 %, Gaffe
≥ 20 % (seuils `MoveClassifier` : inaccuracy 5, mistake 10, blunder 20). La
version d'origine (10/20/30) était jugée trop indulgente — un coup lâchant
8 % restait « Bon coup », il est désormais « Imprécision ».

### Trois règles de classification affinées (demande utilisateur)
- **Grand coup** : exception au « pas de Grand coup si position ≥ 85 % » —
  autorisé quand même si le 2e choix s'effondre de ≥ 30 %
  (`secondBestCollapseThreshold`), signe qu'un seul coup gardait le gain.
- **Brillant** : nouvelle condition anti-faux-positif — le sacrifice ne doit
  PAS être immédiatement repris sur sa case au coup suivant (sinon simple
  simplification). Champ `sacrificeImmediatelyRecaptured`, calculé en
  regardant le coup réel suivant (`MoveClassifier.isImmediatelyRecaptured`).
- **Occasion manquée** : la perte ≥ 5 % doit résulter d'une TACTIQUE ratée
  (mat direct ou gain de matériel), pas d'un simple relâchement positionnel.
  Champ `bestMoveWasTactical`, calculé par `bestMoveIsTactical` (capture sur
  la case d'arrivée du meilleur coup, ou mat direct).

Deux approximations ASSUMÉES et documentées : « reprise triviale » = reprise
sur la case (sans juger la valeur) ; « tactique » = capture ou mat (pas de
preuve de gain NET après échanges). À confirmer/ajuster par l'utilisateur.

### Théorie plus profonde
`isInBook` pointe désormais sur `EcoOpeningLoader.bookLines` = base ECO
(courte, médiane 2 coups) COMPLÉTÉE par les 149 lignes de la bibliothèque
d'ouvertures (~11 coups). La théorie ne s'arrête plus au premier échange. Le
NOM de l'ouverture reste sur `standard` (codes ECO). PGN de la bibliothèque
parsé en SAN par `EcoOpeningLoader.sanMoves(fromPGN:)`.

### Puzzle — niveau et phase mis en valeur
Les tags niveau/phase, avant en gris minuscule, deviennent des PASTILLES
colorées (plus grandes) : difficulté en progression vert → rouge, phase avec
son icône et sa teinte. Couleurs mappées dans la vue (le modèle
`DifficultyTier` reste sans SwiftUI, il alimente des #Predicate SwiftData).

### Vérifié
- **348 tests / 54 suites** verts (nouveaux cas : Grand coup 85 %+, occasion
  manquée sans tactique, sacrifice repris).

## Éditeur de position — refonte condensée (2026-07-20)
Après une reconnaissance de pièces, l'écran montrait tout l'outillage de
composition en permanence. Refonte à la demande :
- **Palette + actions (Standard/Vider/Inverser) REPLIÉES** derrière un seul
  en-tête « Éditer le jeu », déployé au tap. Auto-déployé s'il reste des
  pièces à préciser (le scanner attend une saisie).
- **Trait** sur une ligne : un pion ⚪ et un pion ⚫ côte à côte (au lieu de
  deux chips « Aux Blancs/Noirs »).
- **Roques** condensés en chips `O-O ⚪`… cliquables ; section MASQUÉE si
  aucun roque possible (roi/tours déplacés) — plus de rangées grisées.
- **Prise en passant** condensée ; section MASQUÉE si impossible (cas
  fréquent) au lieu d'un message « rien ici ».
- **FEN** sur une ligne tronquée + bouton « Copier » (au lieu d'un pavé
  monospace de 4 lignes).

Les tests d'éditeur pilotent le ViewModel (état), pas l'UI : refonte sans
impact. **348 tests / 54 suites verts.**

## Ouvertures — filtre « Style » stratégique (multi-attribut) (2026-07-20)
Nouvel axe de filtre dans la bibliothèque, ORTHOGONAL au code ECO :
classique / hypermoderne / système / irrégulière. Les 149 familles
catégorisées à la main (théorie échiquéenne).

- **Multi-attribut** : 20 vrais hybrides portent DEUX styles (dominant en
  premier) — Attaque est-indienne = système+hypermoderne, Catalane =
  hypermoderne+classique, Londres/Colle = système+classique, Sicilienne =
  classique+hypermoderne, Réti = hypermoderne+système… Le filtre matche
  « contient » : la Londres remonte sous « Système » ET « Classiques ».
- **Couverture 149/149 vérifiée par assertion** (script) : aucune oubliée,
  aucun tag inexistant, aucun doublon intra-ouverture. « Irrégulière »
  recueille les 51 fantaisistes (Grob, Bongcloud…) pour un filtre exhaustif.
- **Décodage défensif** : `styles: [String]?` brut → `styleCategories`
  typé écarte les valeurs inconnues, ne casse jamais toute la bibliothèque.
- Le NOM/CODE ECO d'affichage est inchangé ; le style est un pur axe de
  filtre. Filtre localisé FR/EN.

Borné à ce seul axe (un futur « gambit » / « ouverte-fermée » serait un
champ séparé). **348 tests / 54 suites verts.**

## Analyse : flèches vertes de revue, gain/perte, « Continuer » avec Elo (2026-07-21)
Trois retouches issues du test à l'usage du mode Analyse.

- **Flèches de REVUE d'une partie terminée** : le meilleur coup s'affiche
  désormais en VERT, lu dans la classification DÉJÀ calculée — plus de
  recalcul moteur en naviguant, donc plus de scintillement ni de flèche
  périmée. Une 2e flèche verte de taille voisine apparaît quand un autre
  coup est presque aussi bon (« deux coups qui se valent »). Les flèches
  GRISES de l'analyse live sont conservées pour l'analyse d'une POSITION
  isolée (FEN/vierge) ; les flèches ROUGES (menace adverse) restent dans
  les deux cas. Distinction via `AnalysisViewModel.isGameReview` (PGN avec
  coups vs position). `CachedEval` mémorise le 2e meilleur coup (gratuit,
  MultiPV=2 déjà en place), nouveau `HintMove.Kind.reviewBest`.

- **Bandeau coach** : « Le meilleur était … » retiré (doublon avec la
  flèche verte) ; à sa place, le GAIN/PERTE du coup joué aligné à droite
  (+2 % émeraude, −13 % teinte de la pastille, ≈ 0 % neutre). Nouvelle
  `lastMoveWinDelta` ; retrait du `betterMoveSAN`/`san(forLan:)` devenus
  morts.

- **« Continuer contre Stockfish »** (fin d'une ligne d'ouverture / d'un
  répertoire) : bouton stylisé (capsule violette + icône moteur) au lieu
  d'un lien discret, et surtout il passe désormais par l'écran de réglages
  PRÉ-REMPLI avec la position atteinte, pour CHOISIR l'Elo (et ajuster
  cadence/aides) au lieu de repartir en silence aux derniers réglages.
  `NewGameSetupView(initialFEN:)` + route `continueVsStockfish`.

**348 tests / 54 suites verts.**

## Préparation App Store + purge du code mort « répertoire personnel » (2026-07-21)

En documentant l'import Lichess dans les notes destinées aux reviewers
Apple, l'utilisateur a signalé que « on avait retiré l'option répertoire ».
Vérification : `RepertoireListView.swift` confirme le retrait du sélecteur
« Mes répertoires » le 18/07/2026 (Ouvertures ne montre plus que la
bibliothèque ECO), mais l'écran de détail qui en dépendait —
`RepertoireDetailView.swift` (import PGN + import Lichess via
`LichessStudyImportService.swift`) et l'écran de construction manuelle
(`RepertoireBuilderView.swift`/`RepertoireBuilderViewModel.swift`) —
étaient restés dans le binaire sans plus AUCUNE route pour y mener
(`Route.repertoireDetail` n'était jamais poussée). Code mort confirmé,
cinq fichiers supprimés (dont le test du service Lichess), deux cas de
`Route` et un hôte privé retirés de `HomeView.swift`.

**Conséquence directe : l'app ne fait plus aucun appel réseau** — c'était
le seul usage d'`URLSession` du projet. Mentions réseau/Lichess retirées
des notes reviewers Apple, de la politique de confidentialité et de la
description marketing (paragraphe « Ouvertures » réécrit pour ne décrire
que la bibliothèque ECO, seule partie encore accessible).

**Découverte en marge, non traitée** : même les écrans encore branchés du
module répertoire (`RepertoireQueueView`, `RepertoireTrainingHost`,
`RepertoireItemGenerator`) dépendent d'un `Repertoire` déjà en base, et
plus rien dans le code n'en crée un — juste des lectures via
`FetchDescriptor<Repertoire>`. Le pipeline de révision espacée des
répertoires personnels est donc probablement inatteignable sur une
installation fraîche, indépendamment du nettoyage ci-dessus. Signalé dans
`AppStoreSubmission/CHECKLIST.md`, pas creusé plus loin (hors du périmètre
de la demande initiale).

Par ailleurs, préparation complète du dossier de soumission App Store
(icône aplatie, manifeste de confidentialité, écran Licences in-app,
métadonnées, captures d'écran FR/EN, politique de confidentialité et page
de support déposées dans `docs/`) — détail dans `AppStoreSubmission/`.

**330 tests / 53 suites verts** (348/54 moins les 18 tests du service
Lichess supprimé).
