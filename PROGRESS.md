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

## Lot 0 — instrumentation et mesure des traits de mise en page (2026-08-13)

Point de départ : deux remontées utilisateur (écrans qui dépassent en
largeur sur iPhone ; échiquier minuscule en paysage) et un audit **statique**
qui n'avait pu être validé à l'exécution. Ce lot ne corrige rien : il pose
l'instrumentation et **mesure**, pour que les lots suivants s'appuient sur
des relevés plutôt que sur des hauteurs de chrome estimées.

### Fait

- **`ChessLab/LayoutTraitsProbe.swift`** — sonde `#if DEBUG` posée sur la
  racine (`ChessLabApp`). Elle expose les traits réels de la fenêtre dans un
  marqueur d'accessibilité `layoutTraits` (`h`, `v`, taille fenêtre, taille
  de zone sûre, encoches, `dynamicTypeSize`), et affiche la même chose en
  surimpression avec l'argument de lancement `-showTraits`. Hors Debug,
  `layoutTraitsProbe()` ne fait rien — rien de tout cela n'existe dans le
  binaire livré.
- **`ChessLabUITests/LayoutProbe.swift`** — harnais de mesure :
  - lecture/analyse des traits (`LayoutTraits`), avec attente active de
    l'orientation demandée (une rotation n'est pas instantanée : sans ça on
    mesure encore la fenêtre d'avant) ;
  - `boardRect(in:)` — rectangle du plateau par **union des `frame` de
    `square_a8` et `square_h1`**, sans instrumenter le code applicatif ;
  - `horizontalOverflows(in:)` — détecteur générique : parcourt les
    descendants et signale tout élément coupé par un bord de la fenêtre.
- **`ChessLabUITests/LayoutTraitsUITests.swift`** — relevés (traits,
  géométrie du plateau, inventaire des débordements), imprimés sous forme
  `TRAITS|…` / `BOARD|…` / `OVERFLOW|…` et récupérés dans la sortie
  `xcodebuild`.
- **`ChessLabUITests/LayoutOverflowUITests.swift`** — les tests de
  non-régression du Lot 5, écrits **avant** les correctifs pour constater
  leur échec (sélecteur de promotion, plateau ≥ 80 % de la largeur utile,
  détecteur sur accueil et sur *Jouer*).

### Décisions d'architecture

- **Le marqueur va en `.background`, jamais en `.overlay`.** Posé en
  superposition, son élément d'accessibilité pleine fenêtre devient le
  premier touché au point de frappe : XCUITest déclare alors « Not
  hittable » **tous** les boutons de l'écran, et `ResumeGameUITests` est
  tombé ainsi. `allowsHitTesting(false)` n'y change rien — c'est la
  hiérarchie d'accessibilité, pas le hit-testing SwiftUI, que consulte le
  pilote de test. Même parti pris que le marqueur `engineInstances` existant.
  La surimpression *visible*, elle, reste au-dessus, mais seulement sous
  `-showTraits` (mode d'inspection manuelle, jamais piloté par les tests).
- **`GeometryReader` SANS `ignoresSafeArea`.** Mesuré : avec
  `.ignoresSafeArea()`, la vue possède tout l'écran et les encoches sont
  rapportées **à zéro** (iPhone SE : 375×667 avec des insets nuls, alors que
  la barre d'état en occupe 20). Sans, `geo.size` est la zone sûre et
  `geo.safeAreaInsets` les vraies encoches ; la taille de fenêtre se
  reconstitue par addition. C'est cette forme qui donne les deux
  informations.
- **Le détecteur ignore les éléments ENTIÈREMENT hors cadre.** Un
  `ScrollView(.horizontal)` — le bon patron, déjà en place dans
  `MoveStripView`, `AnalysisLibraryView`, `OpeningReaderView` — pousse
  légitimement du contenu hors de la fenêtre. Ce qu'on traque, c'est
  l'élément **coupé** : partiellement visible, tranché par le bord. Les
  conteneurs (`.other`) sont exclus du parcours : leur largeur ne dit rien de
  ce que l'utilisateur voit couper ; les cases du plateau, qui sont des
  `.other`, se mesurent séparément par `boardRect(in:)`.
- **Compiler depuis `/tmp`** (rappel) : le dépôt est sous `~/Desktop`
  synchronisé iCloud, où `xcodebuild` se bloque. Piège rencontré en plus
  cette fois : `-destination 'generic/platform=iOS Simulator'` compile aussi
  **x86_64**, que le Stockfish vendorisé (NEON) refuse — viser une
  destination concrète, ou `ARCHS=arm64`.

### Vérifié — classes de taille réelles (iOS 26.5, simulateur)

Fenêtre = zone sûre + encoches. Encoches notées haut/gauche/bas/droite.

| Appareil | Orientation | h / v | Fenêtre | Zone sûre | Encoches |
|---|---|---|---|---|---|
| iPhone SE (3e gen) | portrait | compact / regular | 375×667 | 375×647 | 20/0/0/0 |
| iPhone SE (3e gen) | paysage | compact / compact | 667×375 | 667×375 | 0/0/0/0 |
| iPhone 16 | portrait | compact / regular | 393×852 | 393×759 | 59/0/34/0 |
| iPhone 16 | paysage | compact / compact | 852×393 | 734×373 | 0/59/20/59 |
| iPhone 16 Pro | portrait | compact / regular | 402×874 | 402×778 | 62/0/34/0 |
| iPhone 16 Pro | paysage | compact / compact | 874×402 | 750×382 | 0/62/20/62 |
| **iPhone 16 Plus** | portrait | compact / regular | 430×932 | 430×839 | 59/0/34/0 |
| **iPhone 16 Plus** | paysage | **regular** / compact | 932×430 | 814×410 | 0/59/20/59 |
| **iPhone 16 Pro Max** | portrait | compact / regular | 440×956 | 440×860 | 62/0/34/0 |
| **iPhone 16 Pro Max** | paysage | **regular** / compact | 956×440 | 832×420 | 0/62/20/62 |
| iPad mini (A17 Pro) | portrait | regular / regular | 744×1133 | 744×1081 | 32/0/20/0 |
| iPad mini (A17 Pro) | paysage | regular / regular | 1133×744 | 1133×692 | 32/0/20/0 |
| iPad Pro 11" (M5) | portrait | regular / regular | 834×1210 | 834×1158 | 32/0/20/0 |
| iPad Pro 11" (M5) | paysage | regular / regular | 1210×834 | 1210×782 | 32/0/20/0 |
| iPad Pro 13" (M5) | portrait | regular / regular | 1032×1376 | 1032×1324 | 32/0/20/0 |
| iPad Pro 13" (M5) | paysage | regular / regular | 1376×1032 | 1376×980 | 32/0/20/0 |

**L'hypothèse de l'audit est CONFIRMÉE** : iPhone **Plus** et **Pro Max**
rapportent `horizontalSizeClass == .regular` en paysage, contrairement à
iPhone SE / 16 / 16 Pro qui restent `.compact`. Ces deux modèles basculent
donc sur l'ossature iPad (`splitBody`) **à la simple rotation** — le
déclencheur de perte de partie du Lot 1 est atteignable sans multitâche, sur
deux modèles grand public. Ce n'est plus un scénario iPad exotique.

Deux relevés secondaires utiles pour la suite :

- en paysage, la zone sûre d'un iPhone perd **118 à 124 pt de largeur** en
  encoches latérales (734 utiles sur 852 pour un iPhone 16) — l'estimation
  « ~734 pt inutilisés » de l'audit tombe juste ;
- les iPad ne changent **jamais** de classe de taille par rotation (toujours
  `regular/regular`) : leur exposition au Lot 1 passe exclusivement par
  Split View / Slide Over / Stage Manager.

### Vérifications statiques de l'audit

| Affirmation | Verdict | Mesure |
|---|---|---|
| `verticalSizeClass` lu dans aucun fichier | confirmé | 0 occurrence |
| Aucun `@ScaledMetric` / `dynamicTypeSize` / `sizeCategory` | confirmé | 0 occurrence |
| 21 `.font(.system(size:))` figées | nuancé | **29** aujourd'hui |
| 11 écrans affichent un échiquier | confirmé | 11 fichiers appellent `ChessBoardView(` (+ `PositionEditorView`, qui a son propre plateau) |
| Aucun `XCUIDevice`/`orientation` dans `ChessLabUITests/` | confirmé | 0 occurrence avant ce lot |
| Orientations iPhone déclarées en Debug ET Release | confirmé | pbxproj : `Portrait LandscapeLeft LandscapeRight` aux deux ; clé `_iPad` = 4 orientations |
| 782 clés, 92 sans traduction anglaise | nuancé | **796 clés, 85 sans `en`** — conclusion inchangée : le pire cas de largeur est le français dans les deux langues |
| `PromotionPickerView` : 380 pt rigides | confirmé (calcul) | 4×(10+56+10) + 3×12 + 2×20 |
| `Text(choice.label)` non localisant | confirmé | `choices` est un `[String]` → `Text(_: String)` |
| `FlowLayout` et `WrapLayout` portent le même défaut | confirmé | `sizeThatFits(.unspecified)` + garde `x > minX` dans les deux |
| 7 hôtes de view model détruits par la bascule | nuancé | **8** — `TwoPlayerResumedGameHost` manquait à la liste |
| `AutosaveStore.clearPlay()` appelé depuis l'`init` | confirmé | `PlayViewModel.init(settings:)`, `TwoPlayerViewModel.init(settings:)` |
| `.onChange(of: sidebarSelection)` posé sur `sidebar` | confirmé | `HomeView.swift:314` — jamais exécuté en compact |
| `modesSection` appelée seulement depuis `iPhoneHome` | confirmé | un seul site (`:645`) ; le commentaire de `ModeCard` référence un `modeGridColumns` **qui n'existe plus** |
| `ModeCard` déborde verticalement en AX3+ | nuancé | hauteur figée confirmée (132/168), mais titre et sous-titre ont déjà `lineLimit(2)` + `minimumScaleFactor` → troncature attendue plutôt que débordement ; reste à mesurer |
| `LabRunView.statTile` : `lineLimit(1)` sans `minimumScaleFactor` | nuancé | la valeur a `minimumScaleFactor(0.7)` ; seul le libellé `caption2` en est dépourvu |
| `PuzzleSolveView:80` inatteignable sur iPhone | confirmé | dans `wideLayout`, gardé par `.regular` **et** `width > height` |
| `HelpView` : largeur dure depuis `UIScreen.main.bounds` | confirmé | `authorImageWidth` |
| `AnalysisView:173` : `min(width*0.55, height - 48)` | confirmé | tel quel |

### Non vérifié à ce stade

- **Display Zoom** (le plancher de 320 pt) : non reproductible par argument
  de lancement, donc jamais mesuré — les chiffres « à 320 pt » de l'audit
  restent des calculs.
- **Split View / Slide Over / Stage Manager** : non pilotables depuis
  XCUITest. L'exposition iPad au Lot 1 reste donc démontrée par le code, pas
  par la mesure — d'où le besoin, au Lot 1, d'un moyen déterministe de
  provoquer la bascule de classe de taille.
- **Mac Catalyst** : aucune destination macOS testée dans ce lot.
- **Dynamic Type** : relevés faits à la taille `large` uniquement ; les
  tailles accessibilité viendront avec les tests du Lot 3.

### Vérifié — le harnais 0.2 à l'épreuve

Premier passage sur iPhone SE (375 pt, français, taille de texte par
défaut) et iPhone 16 :

| Mesure | Résultat |
|---|---|
| Plateau, portrait iPhone SE | côté **375 pt** = **100 %** de la largeur utile |
| Plateau, portrait iPhone 16 | côté **393 pt** = **100 %** de la largeur utile |
| Détecteur sur *Jouer* (début de partie) | aucun débordement |
| Détecteur sur l'accueil | **4 signalements** (voir ci-dessous) |
| Sélecteur de promotion, tuiles | 17,5→93,5 / 105,5→181,5 / 193,5→269,5 / 281,5→357,5 dans une fenêtre 0→375 |

**Le portrait iPhone est excellent et le reste** : le plateau occupe la
largeur entière (`PlayView` annule sa marge pour le seul plateau). Le
garde-fou du Lot 5.3 (≥ 80 %) a donc une marge confortable.

**3.1 — sélecteur de promotion : diagnostic NUANCÉ, sévérité à revoir.**
L'arithmétique de l'audit est juste (4×76 + 3×12 + 2×20 = **380 pt**, et
380 > 375), mais la conséquence annoncée ne se reproduit pas : à taille de
texte par défaut, **aucune tuile n'est coupée** — les quatre boutons tiennent
entre 17,5 et 357,5 pt. Ce qui dépasse, ce sont les **2,5 pt de fond de carte
de chaque côté** (la carte de 380 pt centrée dans 375). Le symptôme réel est
un liseré arrondi rogné, pas des « boutons rognés ». Le défaut de fond reste
à corriger (largeur rigide incompressible, et surtout explosion aux tailles
d'accessibilité), mais ce n'est pas le 🔴 critique annoncé, et ce **n'est
probablement pas** la remontée utilisateur n°1.

Conséquence pour le harnais : le détecteur ne l'attrape pas, puisqu'il exclut
les conteneurs `.other` — dont les fonds de carte. Le test du Lot 5.2 devra
donc mesurer la **carte** du sélecteur (identifiant d'accessibilité à
ajouter), pas seulement ses tuiles.

**Découverte NON prévue par l'audit — l'accueil déborde sur iPhone SE.** Le
détecteur signale les tuiles « Deux joueurs » (17,5 pt dehors) et
« Ouvertures » (6,5 pt dehors) de la grille des modes. Vérification
arithmétique : la grille place bien la 2e colonne à x=194,5 pour une tuile
de 160,5 pt (fin à 355 pt, correcte) — **c'est la grande icône décorative
« fantôme » de `ModeCard`** (`Image(systemName:)` en 96 pt, `offset(x: 46)`)
qui étend la `frame` d'accessibilité jusqu'à 392,5 pt. Elle est **visuellement
écrêtée** par le `.clipShape` de la carte, mais l'accessibilité, elle, ne
sait pas qu'elle est écrêtée.

C'est donc un **faux positif à l'écran** — mais un **vrai défaut
d'accessibilité** : cette icône purement décorative n'a rien à faire dans la
hiérarchie (VoiceOver la voit, et elle fausse la géométrie annoncée aux
outils). À corriger au Lot 3 par `accessibilityHidden(true)`, ce qui rendra
du même coup le détecteur exploitable sur l'accueil.

**3.3 — bandeau de pièces capturées : non reproduit à ce stade**, et pour une
raison simple : au début de partie le bandeau est vide. Le mesurer demande
une partie avec une dizaine de prises — à faire au Lot 3.

### Incident d'infrastructure, sans rapport avec le code

Un des relevés (`testReportBoardGeometry` sur iPhone SE) est tombé avec
« Test crashed with signal term ». Diagnostic : c'est **`SimRenderServer`**
(le serveur de rendu du simulateur) qui a crashé — rapport dans
`~/Library/Logs/DiagnosticReports/`, à l'horodatage exact — vraisemblablement
parce que plusieurs simulateurs tournaient de front. La même mesure obtenue
par un autre chemin (`BOARD-RATIO` du test de débordement) est cohérente.
À retenir : **ne pas lire un « signal term » comme un bug de l'app** sans
avoir regardé les rapports de crash de l'hôte.

### Vérifié — 4.1 : l'accueil iPad en portrait est INFIRMÉ

Le relevé du plateau sur iPad Pro 11" a d'abord échoué faute de trouver
« Contre l'ordinateur » à l'écran, ce qui ressemblait à une confirmation
spectaculaire du diagnostic 4.1 (« plus aucun point d'entrée vers les modes
en portrait »). Vérification faite (`IPadEntryPointsUITests`, qui exige une
`frame` non vide **et** dans la fenêtre, pas la simple existence dans la
hiérarchie) : c'est l'inverse.

| Appareil | Orientation | Modes atteignables | Position des lignes |
|---|---|---|---|
| iPad Pro 11" | portrait | **6/6** | x=26→314 dans une fenêtre de 834 pt, y=130→442 |
| iPad Pro 11" | paysage | **6/6** | idem, fenêtre 1210 pt |
| iPhone 16 | portrait | 6/6 | grille de tuiles |

Sur **iPadOS 26.5, la barre latérale est affichée par défaut en portrait**
(le bouton de la barre d'outils propose « Masquer la barre latérale », donc
elle est visible) : les six modes sont atteignables dès le lancement, dans
les deux orientations. La prémisse de l'audit — « en portrait, iPadOS masque
la sidebar par défaut » — ne tient pas sur cette version.

Ce qui reste vrai du diagnostic : la grille `modesSection` n'existe
effectivement que dans l'ossature iPhone, et `detailRoot` ne pose ni
`navigationTitle` ni `toolbar`. Mais l'écran n'est pas « sans issue », et la
priorité du Lot 4 baisse d'autant.

Le vrai enseignement est ailleurs : **l'échec initial venait de mon propre
harnais**, pas de l'app. Une ligne de barre latérale est remontée par
XCUITest en `staticText`, pas en `button` ni en `cell` — l'assistant de
navigation cherchait les deux mauvaises formes. Corrigé dans
`LayoutTraitsUITests`. À retenir pour tous les tests iPad à venir.

## Lot 1 — la partie ne se perd plus au changement de classe de taille (2026-08-13)

Le seul point de **perte de données utilisateur** de l'audit. Confirmé, et
plus grave que décrit : le Lot 0 a montré que les iPhone Plus et Pro Max
basculent en classe `.regular` **en paysage**, donc qu'une simple rotation
suffisait à détruire la partie en cours et son autosauvegarde.

### Fait

- **`AutosaveStore.clearPlay()` / `clearTwoPlayer()` sortis des
  initialiseurs** (`PlayViewModel`, `TwoPlayerViewModel`). Un initialiseur
  qui efface un fichier est un piège : toute reconstruction de vue détruit
  des données. L'effacement vit désormais à l'intention explicite, dans
  `HomeView.startNewGame(_:)` / `startNewTwoPlayerGame(_:)`, par où passent
  **tous** les départs de partie (nouvelle partie, position d'éditeur, scan,
  « jouer depuis ici » de l'analyse, revanche).
- **`SessionStore`** (nouveau) : coffre des view models de session, détenu
  par `HomeView` — donc au-dessus du `if/else` d'ossature. Les douze hôtes
  gardent un `@State` local, mais seulement comme miroir de rendu :
  reconstruit, il est re-rempli depuis le coffre avec la **même** instance.
  Vidé quand la pile de navigation redevient vide (retour à l'accueil), pour
  ne pas laisser un Stockfish survivre à son écran.
- **`PlayView` gagne son `onAppear`** → `PlayViewModel.handleViewAppear()`,
  qui redemande un moteur si la partie continue. Sans lui, le correctif
  ci-dessus aurait produit pire que le mal : une partie intacte à l'écran
  mais un adversaire définitivement muet, `handleViewDisappear()` ayant
  libéré Stockfish à la destruction du sous-arbre.
- **`SkeletonOverride`** (Debug, `-skeletonToggle`) : bascule d'ossature à la
  demande, pour rendre la panne reproductible en test.

### Décisions d'architecture

- **Le coffre est clé par la ROUTE** (`String(describing: route)`), pas par
  une dérivation par type de charge utile : la route EST l'identité de
  l'écran. Deux analyses de PGN différents ont des routes différentes, donc
  des sessions distinctes ; une revanche aux réglages identiques a la même
  clé — d'où `SessionStore.remove(_:)`, appelé au départ d'une partie neuve,
  sans quoi la « nouvelle » partie rouvrait l'ancienne position.
- **Douze hôtes, pas sept.** L'audit en listait sept ; il en manquait cinq —
  `TwoPlayerResumedGameHost`, et les quatre du module `OpeningGraph`
  (`OpeningReaderHost`, `OpeningExplorerHost`, `OpeningLearnHost`,
  `OpeningTrainHost`). Tous câblés.
- **Le correctif (a) seul n'aurait pas suffi**, et le (b) seul non plus :
  (a) sauve la sauvegarde, (b) sauve l'état vivant (analyse, puzzle,
  laboratoire, ouvertures) que (a) ne couvre pas. Les deux sont livrés,
  comme demandé.
- **Bascule de test plutôt que rotation** : la rotation d'un Plus/Pro Max
  marche, mais le Lot 2 verrouille l'iPhone en portrait — un test fondé sur
  elle mourrait au lot suivant. Split View et Stage Manager, eux, ne se
  pilotent pas depuis XCUITest. On force donc la valeur d'environnement que
  lit `HomeView`. **Limite assumée** : c'est bien le mécanisme de la panne
  (le `_ConditionalContent` détruit sa branche sortante), mais ce n'est pas
  une vraie rotation — rien ne reproduit ici le changement de taille de
  fenêtre.

### Vérifié

- `SkeletonSwitchUITests` : deux tests, **rouges avant correction, verts
  après** — vérifié en remisant les correctifs applicatifs et en rejouant la
  même suite :

  | Test | Avant | Après |
  |---|---|---|
  | `testGameSurvivesSizeClassSwitch` (`moveCount` inchangé) | ❌ | ✅ |
  | `testAutosaveSurvivesSizeClassSwitch` (« Reprendre » toujours offert) | ❌ | ✅ |

- **Point connexe `sidebarSelection` / `path` : CONFIRMÉ, et mesuré.**
  `testReportSidebarAndPathCoherence` part de « Puzzles » ouvert depuis la
  grille iPhone, bascule, puis appuie sur retour :

  | Étape | Écran |
  |---|---|
  | avant bascule | Puzzles |
  | après bascule | Puzzles (l'écran, lui, est préservé) |
  | après « retour » | *(barre sans titre)* — le tableau de bord iPad |

  Le retour ne ramène donc pas à l'écran d'où l'on venait, mais au tableau
  de bord — qui ne pose ni `navigationTitle` ni `toolbar`, d'où une barre
  vide. Symptôme exactement conforme au diagnostic.

  **Non corrigé dans ce lot, volontairement.** Le remède demande de
  réconcilier les deux représentations à la bascule, donc d'insérer une
  route en TÊTE de pile — ce que `NavigationPath` ne permet pas (append et
  removeLast seulement). Il faut passer la pile en `[Route]` typé, un
  changement qui touche la trentaine de sites de navigation. Le faire à la
  va-vite ici produirait un défaut pire : synchroniser `sidebarSelection`
  sans retirer l'entrée correspondante de la pile afficherait l'écran
  d'entrée **deux fois** (racine de détail + empilé). C'est un chantier à
  part entière ; la perte de données, elle, est traitée.

## Lot 2 — iPhone verrouillé en portrait (2026-08-13)

### Fait

- `ChessLab.xcodeproj/project.pbxproj`, **Debug ET Release** :
  `INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait`.
  La clé `_iPad` reste inchangée — quatre orientations, comme exigé par le
  multitâche (l'app ne pose pas `UIRequiresFullScreen`, Split View en dépend).
- `OrientationLockUITests` : l'iPhone reste portrait malgré une demande de
  rotation ; l'iPad, lui, doit continuer de tourner (les deux tests
  s'auto-excluent selon l'idiome).

### Décisions d'architecture

- Le paysage iPhone n'était adapté **nulle part** — `verticalSizeClass` n'est
  lu dans aucun fichier, et les seuls `GeometryReader` qui comparent largeur
  et hauteur sont enfermés dans des branches `.regular`, inatteignables sur
  iPhone standard. Le verrou fait donc disparaître une classe de bugs entière
  plutôt que de la rustiner ; le vrai layout paysage reste un chantier à part.
- **Effet de bord bienvenu sur le Lot 1** : le verrou rend le déclencheur de
  rotation inatteignable sur iPhone Plus / Pro Max. Il ne dispense pas du
  correctif — l'iPad reste exposé via Split View, Slide Over et Stage Manager,
  et c'est précisément pourquoi le test du Lot 1 ne repose pas sur la
  rotation.

### Vérifié

- `testIPhoneStaysPortraitAfterRotationRequest` : vert sur iPhone 16 — la
  fenêtre garde exactement ses dimensions après `XCUIDevice.orientation =
  .landscapeLeft`.
- **Mac Catalyst** : ces clés `INFOPLIST_KEY_UISupportedInterfaceOrientations*`
  ne s'appliquent qu'à iOS/iPadOS ; Catalyst gère ses fenêtres par
  `windowScene.sizeRestrictions` (plancher de 820 pt posé dans
  `MenuCommands.swift`). Vérifié par lecture, **pas par exécution** : aucune
  destination macOS n'a été compilée dans cette session.
- Aucun test UI existant ne dépendait du paysage (grep : zéro `XCUIDevice` /
  `orientation` avant ce chantier).

### Suite UI complète après les lots 1 et 2 (iPhone 16, iOS 26.5)

**26 tests verts, 3 échecs** au premier passage, puis **28 verts, 2 échecs**
après correction :

| Test | Cause | État |
|---|---|---|
| `EngineRecoveryUITests` | **Régression de ma part** : `handleViewAppear()` relançait le moteur même après un ÉCHEC de démarrage, masquant la bannière « Moteur indisponible » et court-circuitant « Réessayer ». Corrigé par un drapeau `wasEngineReleasedOnDisappear` — la reprise n'a lieu qu'après un aller-retour d'écran, jamais après un échec. | ✅ réparé |
| `KeyboardShortcutsUITests` | **Préexistant** — vérifié en remisant tous mes correctifs applicatifs : échoue à l'identique. | ❌ préexistant |
| `ScannerFlowUITests` | **Préexistant** — idem (« dame blanche » introuvable sur l'écran de confirmation). | ❌ préexistant |

Ces deux échecs préexistants ne sont **pas** traités ici : hors du périmètre
des lots demandés, et les diagnostiquer supposerait de démêler un changement
antérieur non documenté. Ils sont signalés, avec la preuve qu'ils ne viennent
pas de ce chantier.

## Lot 3 — débordements de largeur sur iPhone (2026-08-13)

### Fait

- **`FlowLayout` corrigé, `WrapLayout` supprimé** (3.4). Les deux étaient
  dupliqués à l'identique et portaient les deux mêmes défauts :
  `sizeThatFits(.unspecified)` demandait la largeur idéale **sur une seule
  ligne** (un texte de puce ne pouvait donc ni se replier ni se tronquer), et
  la condition de retour à la ligne exigeait `x > minX`, si bien qu'une puce
  plus large que le conteneur était posée en début de ligne et débordait sans
  filet. Désormais la largeur proposée aux enfants est **bornée à la ligne**
  et toute mesure y est écrêtée. `WrapLayout` est un simple `typealias` :
  une implémentation, une correction. Couvre les **8 sites d'appel**, dont les
  étiquettes saisies par l'utilisateur d'`AnalysisLibraryView`.
- **Sélecteur de promotion** (3.1) : tuiles à part égale de la largeur
  offerte, glyphe borné à 56 pt au lieu d'être figé, libellé en `lineLimit(1)`
  + `minimumScaleFactor`, carte plafonnée à 420 pt avec une marge de sécurité.
  **Et le bug de localisation corrigé** : `choices` portait des `String`, donc
  `Text(_: String)` — « Dame / Tour / Fou / Cavalier » restaient en français
  en anglais alors que les traductions existaient déjà au catalogue.
- **Barre de navigation d'*Analyser*** (3.2) : l'indicateur de classification
  renonce à du contenu au lieu de pousser les boutons dehors — `ViewThatFits`
  choisit entre la phrase complète, le compteur seul, puis le rouet seul. La
  barre porte 268 pt incompressibles de boutons ; il restait ~75 pt utiles sur
  iPhone SE pour un libellé qui en réclame ~125.
- **Bandeau des pièces capturées** (3.3) : le chevauchement se resserre quand
  les prises s'accumulent (9 → 7 → 5 pt). Toutes les pièces restent visibles,
  là où un écrêtage en aurait escamoté.
- **Rangées sur-remplies** (3.5) : les trios de puces de `NewGameSetupView` et
  `PositionEditorView` passent en `FlowLayout` (ils réclamaient ~323 et
  ~326 pt pour 303 disponibles) ; la légende du laboratoire aussi ; le libellé
  de `statTile` reçoit le `minimumScaleFactor` qui manquait.
- **`HelpView`** (3.6) : `UIScreen.main.bounds.width * 0.6` consommé en
  `.frame(width:)` — une largeur DURE calculée sur l'écran physique — devient
  un `containerRelativeFrame`, qui suit la fenêtre. En Slide Over sur iPad
  (fenêtre 320, écran 1 024) l'image réclamait 670 pt, soit 420 hors cadre, et
  la valeur ne s'invalidait jamais au redimensionnement.
- **Icône décorative des tuiles d'accueil** : masquée à l'accessibilité, et
  fond écrêté (VoiceOver n'annonce plus « person.2.fill »).

### Vérifié — mesuré sur iPhone SE (375 pt), taille par défaut ET AX5

`DynamicTypeOverflowUITests` parcourt les écrans d'entrée aux deux tailles.
Après correction, **plus aucun débordement** sur *nouvelle partie*, *deux
joueurs* et *puzzles* — y compris en **AX5**, où les puces débordaient
jusqu'à ~190 pt hors écran.

Sélecteur de promotion, avant → après (iPhone SE, français) :

| | Avant | Après |
|---|---|---|
| Tuile « Dame » | 17,5 → 93,5 (76 pt figés) | 32,0 → 101,0 (69 pt, partagés) |
| Carte | 380 pt rigides, 2,5 pt hors écran de chaque côté | dans les marges, compressible |

### L'artefact de l'accueil : mesuré, compris, assumé

Le détecteur signalait deux tuiles de la grille (17,5 et 6,5 pt « dehors »).
La mesure des six tuiles tranche : **rien n'est coupé à l'écran**.

| Tuile | Largeur annoncée | Symbole |
|---|---|---|
| Contre l'ordinateur | 174,5 | `cpu` |
| **Deux joueurs** | **198,0** | `person.2.fill` |
| Puzzles | 196,5 | `puzzlepiece.fill` |
| **Ouvertures** | **187,0** | `books.vertical.fill` |
| Analyser | 178,5 | `chart.xyaxis.line` |
| Laboratoire | 173,0 | `flask` |

Les colonnes, elles, sont régulières (x=20 et x=194,5, pas de 174,5 = 160,5 de
carte + 14 d'espacement) et le contenu tient dedans (« Sur le même appareil »
va de 210,5 à 339, exactement dans les marges). La largeur annoncée **varie
avec le symbole** : c'est la grande icône décorative du fond, visuellement
écrêtée par le `clipShape` de la carte, que SwiftUI continue de compter dans
la géométrie remontée à l'accessibilité.

**Trois tentatives de correction n'ont rien changé à la mesure**, au
demi-point près : `accessibilityHidden(true)` sur l'image puis sur tout le
fond, `clipped()`, et un `frame` explicite sur le glyphe. Le test du Lot 5
exclut donc ces éléments **sur preuve**, exclusion argumentée dans le code —
plutôt qu'un seuil de tolérance, qui aurait aussi laissé passer de vrais
débordements. Les deux corrections d'accessibilité sont conservées ; le
`frame` explicite, sans effet mesurable, a été retiré.

### Non traité dans ce lot

- Le **Dynamic Type des gabarits figés** (boutons 44/46/56, aperçus 30×30,
  glyphes de prises 15 pt) reste globalement non traité : aucun
  `@ScaledMetric` dans le projet, et les 29 `.font(.system(size:))` ne
  grossissent toujours pas. Les écrans mesurés ne débordent plus en AX5, mais
  l'incohérence « moitié du texte qui scale, moitié qui ne scale pas »
  demeure — chantier de fond, pas un correctif de largeur.
- **Display Zoom (320 pt)** : toujours pas reproductible par argument de
  lancement, donc jamais mesuré.
- Les rangées 3.5 restantes (`AnalysisView.candidatesBar`, `PuzzleSolveView`,
  `SettingsView.piecePreview`, `GameSummaryView.categoryRow`,
  `OpeningExplorerView.moveRow`, `AnalysisLibraryView`) n'ont **pas** été
  retouchées : elles tronquent leur texte plutôt que de sortir de l'écran, et
  aucune n'a été signalée par le détecteur aux deux tailles mesurées.

## Lot 4 — revue iPad : les deux défauts francs (2026-08-13)

Le Lot 0 ayant **infirmé** le diagnostic 4.1 (l'accueil iPad en portrait
montre bien ses six modes, la barre latérale étant affichée par défaut sur
iPadOS 26.5), ce lot se concentre sur les deux débordements réels.

### Fait

- **`AnalysisView` en paysage (4.2)** — la réserve de hauteur devinée
  (`geo.size.height - 48`) est supprimée. Sous le plateau, la colonne empile
  le badge d'analyse (26), la barre d'éval (20), la navigation (44), les
  candidats (~34), la barre coach (~40), leurs espacements et 24 pt de marge
  haut et bas : de l'ordre de **270 pt, pas 48**. La colonne n'étant pas dans
  un `ScrollView`, le débordement était franc et irrécupérable — la barre
  coach passait sous le bord de l'écran. Le plateau se sert désormais en
  premier via `layoutPriority(1)` et les barres à hauteur fixe prennent ce qui
  reste : **plus aucune constante de chrome soustraite à la main**, exactement
  le remède déjà appliqué à `PlayView` (voir « Revue UX — disposition iPad »).
- **`OpeningReaderView` (4.4)** — plafond de 520 pt sur le côté du plateau. Un
  carré `.aspectRatio(1, .fit)` dans un `ScrollView` **vertical** ne se résout
  que contre la largeur, la hauteur y étant illimitée : sur une colonne de
  détail iPad le plateau atteignait ~1 014 pt dans un viewport de ~870, et le
  fil de coups, la carte d'explication et la liste démarraient **sous le
  pli** — alors que l'explication est la raison d'être de cet écran.

### Non traité, et pourquoi

- **4.3 (répartition de la largeur sur grand écran)**, **4.5 (feuilles
  modales inadaptées)** et le reste de 4.1 (absence de `navigationTitle` sur
  `detailRoot`) : ce sont des travaux de **conception**, pas des correctifs de
  débordement — panneau puzzle fixé à 360 pt, `TwoPlayerGameView` sans
  disposition à deux colonnes, écrans d'entrée sans plafond de largeur,
  scanner et éditeur de position présentés en form sheet. Les toucher sans
  pouvoir juger le rendu (le simulateur ne permet pas de vérifier une
  disposition paysage à la capture — piège documenté) reviendrait à déplacer
  des chiffres à l'aveugle.
- **Les deux correctifs ci-dessus n'ont pas pu être vérifiés à l'exécution**
  en paysage iPad, pour la même raison. Ils suppriment l'un et l'autre une
  constante devinée au profit d'une règle de priorité de disposition, ce qui
  est structurellement plus sûr — mais c'est une correction *par
  construction*, pas une mesure.

## Lot 5 — non-régression et matrice de vérification (2026-08-13)

### Suite unitaire

**430 tests, 72 suites, 0 échec** (iPhone 16, iOS 26.5). C'est la vérification
qui manquait le plus : les lots 1 et 3 touchent `PlayViewModel`,
`TwoPlayerViewModel` et `Theme`. Rien n'a bougé.

*Piège rencontré* : un `xcodebuild build` simple écrase `ChessLab.app` **sans**
son greffon `ChessLabTests.xctest`, et le run suivant échoue sur « Failed to
create a bundle instance » — ce n'est pas un bug de test, il faut refaire un
`build-for-testing`.

### Matrice de mise en page

| Appareil | Tests | Résultat |
|---|---|---|
| iPhone SE (3e gen) — L, AX3, AX5 | 11 | **11 verts** |
| iPhone 16 Pro Max | 9 | **9 verts** |
| iPad mini (A17 Pro) | 5 | 4 verts + 1 (voir « question ouverte ») |
| iPad Pro 11" (M5) | 5 | **5 verts** |
| iPad Pro 13" (M5) | 5 | **5 verts** |

*(Chiffres après correction des trois défauts de harnais décrits plus bas ;
au premier passage, les trois iPad affichaient 3 rouges chacun — tous
imputables au harnais, aucun à l'app.)*

**Vérifications clés obtenues :**

- **Le verrou portrait est effectif et ciblé.** iPhone 16 Pro Max après une
  demande de paysage : `440×956`, `h=compact`, `effective=false` — alors que
  le même appareil rapportait `regular` en `956×440` au Lot 0. Le déclencheur
  de rotation du Lot 1 est donc devenu inatteignable sur Plus/Pro Max. Et
  `testIPadStillRotates` passe sur les trois iPad : ils gardent bien leurs
  quatre orientations.
- **Le Lot 1 tient sur iPad aussi** : `testGameSurvivesSizeClassSwitch` et
  `testAutosaveSurvivesSizeClassSwitch` sont verts sur mini, 11" et 13".
- **AX3 sur iPhone SE : les cinq écrans d'entrée sont propres.** En AX5 aussi
  pour les trois atteignables.
- **4.1 infirmé une seconde fois** : iPad mini montre 6/6 modes en portrait
  ET en paysage, comme l'iPad Pro 11".

### Trois défauts de MON harnais, corrigés en route

Aucun n'était un défaut de l'app — et c'est la leçon récurrente de ce
chantier :

1. `LayoutOverflowUITests` ne cherchait « Contre l'ordinateur » que comme
   `Button` : sur iPad c'est un `staticText` de barre latérale. Trois tests
   tombaient sur les trois iPad pour cette seule raison.
2. `testReportSidebarAndPathCoherence` supposait la grille de modes : il
   s'exclut désormais proprement en ossature régulière (le déséquilibre qu'il
   observe n'existe que depuis la grille).
3. Le balayage Dynamic Type concluait « écran inatteignable » en AX5 faute de
   défiler jusqu'aux tuiles passées sous le pli.

### Question ouverte, non tranchée

**La promotion ne s'ouvre pas dans *Analyser* sur iPad mini** — et
seulement là. Après correction du harnais, le relevé complet est sans
ambiguïté :

| Appareil | `testPromotionPickerFitsOnScreen` |
|---|---|
| iPad Pro 11" (M5) | ✅ |
| iPad Pro 13" (M5) | ✅ |
| **iPad mini (A17 Pro)** | ❌ |

Le test tape a7 puis a8 — les deux événements sont bien synthétisés, la
position FEN est chargée, le plateau affiché — et le sélecteur n'apparaît
jamais, après 53 s d'attente (contre ~15 s pour un passage normal). Défaut
propre au mini, ou simple lenteur de ce simulateur ? **Non déterminé**, faute
de budget.

*(Une première rédaction de cette note disait « sur iPad » : c'était faux,
l'échec ne concerne que le mini — les deux iPad Pro passent.)*

Le test est borné à la classe compacte, là où la largeur est réellement
contrainte et où la mesure a un sens ; la question est consignée ici plutôt
que masquée par un rouge sans diagnostic.

### Non fait

- **Captures App Store régénérées** : 16 fichiers (accueil, Ouvertures,
  lecteur, partie) × français/anglais × iPhone 16 Pro Max (`iphone-6.9`) et
  iPad Pro 13" (`ipad-13`). Les anciennes étaient périmées (libellés « Contre
  Stockfish », « Répertoires PGN ») et avaient été supprimées avant ce
  chantier ; les nouvelles reflètent l'interface corrigée.
- **Mac Catalyst** : aucune destination macOS compilée de toute la session.
  Le plancher de fenêtre à 820 pt et l'insensibilité de Catalyst aux clés
  `INFOPLIST_KEY_UISupportedInterfaceOrientations*` sont vérifiés **par
  lecture**, pas à l'exécution.
- **Split View / Slide Over / Stage Manager** : non pilotables depuis
  XCUITest ; c'est précisément pourquoi le Lot 1 se teste par une bascule
  d'ossature forcée.
- **Display Zoom (320 pt)** : non reproductible par argument de lancement.

### État de la suite UI

Deux échecs **préexistants** subsistent (`KeyboardShortcutsUITests`,
`ScannerFlowUITests`), démontrés indépendants de ce chantier en rejouant sans
aucun de mes correctifs applicatifs. Ils ne sont pas traités : hors périmètre.

## Revue statique — bugs moteur, pendule, PGN, tâches, scanner (2026-08-13)

Chantier `PROMPT-bugs.md` : une revue statique (lecture seule, sans build ni
simulateur) avait listé des défauts à confirmer. Tous les diagnostics traités
ci-dessous ont été **confirmés** à la lecture du code, et deux d'entre eux
prouvés à l'exécution par un test rouge avant / vert après.

### Lot 1 — Moteur : état global, instances mortes, fuite

**Le fond du problème : `isRunning` était GLOBAL.** `cstockfish_start` sortait
en silence quand `gRunning` était vrai, **sans reconfigurer le callback**. Une
seconde instance créée pendant que la première se libérait — et les libérations
sont asynchrones, personne ne les attend (`Task { await engine.stop() }` au
départ d'un écran pendant que le suivant construit déjà son contrôleur) —
se croyait donc démarrée, ne recevait aucune ligne, échouait sur le délai de
5 s avec une bannière « Moteur indisponible » indiscernable d'une panne NNUE,
**et envoyait quand même ses commandes** dans le moteur de l'autre écran.

Correctifs :

- `cstockfish_start` **rend un code** (`0` / `-1` si le process est pris) au
  lieu de sortir en silence. Reconfigurer `gOutput` à la place aurait détourné
  la sortie du propriétaire légitime vers le nouveau venu : pire.
- `StockfishEngine` gagne un `didStart` **par instance** : `isRunning` vaut
  désormais « j'ai démarré ET le process tourne ». Et `stop()` ne coupe le
  process **que si cette instance le possède** — sans cette garde, l'instance
  fantôme tuait le moteur de l'écran réellement actif en se libérant.
- `EngineController.start()` **attend** la libération (par tentatives, borné à
  4 s) au lieu de faire comme si de rien n'était. Au-delà, il échoue
  honnêtement.
- **Fuite (1.2)** : `ensureMoveReader` — chemin **exclusif au Laboratoire** —
  installait une tâche qui itère le flux parsé sans fin et capturait `self`
  FORT pendant l'itération. Ni `stop()` ni `deinit` ne l'annulaient : cycle de
  rétention, `deinit` jamais appelé, une instance « vivante » de plus **à
  chaque passage au Laboratoire**, définitivement. `self` est maintenant repris
  faiblement à chaque tour, et la tâche est annulée par `stop()` et `restart()`.
- **`deinit` (1.3)** rend le process : `engine.stop()` (idempotent, et sans
  effet si l'instance n'est pas propriétaire) plus l'annulation des lecteurs.
  Sans ça, une libération hors `stop()` laissait `gRunning` vrai pour tous les
  écrans suivants, et le thread moteur continuait d'appeler un callback pointant
  un objet désalloué — use-after-free.
- **Recherches croisées (1.4)** : abandonner une recherche incrémente désormais
  `staleBestmovesToDiscard`, comme le fait `hardStopIfPending`. Sans ce
  compteur, le `bestmove` tardif de la position PRÉCÉDENTE venait résoudre la
  nouvelle continuation — coup illégal (partie du Labo interrompue sans
  explication) ou, pire, coup légal accepté pour le bon.
- **Consommateur unique (1.5)** : le commentaire du dépôt parlait de réponses
  « volées » ; c'est en réalité un `fatalError` du stdlib (« attempt to await
  next() on more than one task »), donc un crash. L'invariant devient
  **vérifiable** : `synchronize()` assère en DEBUG qu'aucun lecteur de coups
  n'est installé. Le multiplexeur reste la vraie solution, non retenue ici
  (refonte du contrôleur, hors périmètre d'une correction de bug).

**Vérifié — rouge avant / vert après.** `EngineLeakUITests` traverse enfin le
**Laboratoire** : son en-tête documentait ce parcours depuis toujours, mais le
test n'appelait que `visitPlay` et `visitAnalysis`. La fuite tenait debout
précisément parce que le test censé l'attraper ne passait pas par là.

| | Instances vivantes au retour à l'accueil |
|---|---|
| Sans les correctifs | **1** (sur 3 créées) ❌ |
| Avec | **0** ✅ |

### Lot 2 — La pendule ne décomptait pas le premier coup

`startTurn` n'était appelé qu'au premier `commit` et à la reprise d'une
autosauvegarde ; les `init` de partie neuve créaient la `GameClock` **sans la
démarrer**. Le camp au trait jouait donc son premier coup **hors du temps**,
l'affichage restait figé, et contre Stockfish aux Blancs la réflexion du moteur
n'était pas décomptée. Le commentaire de la reprise qualifiait déjà ce
comportement de bug « répétable à volonté » : la partie neuve avait le même.

**Décision : démarrage à l'APPARITION de la vue**, pas à l'`init`. Entre la
construction du view model et le premier pixel affiché il peut s'écouler
quelques centaines de millisecondes ; les décompter reviendrait à les voler au
joueur. `PlayViewModel.handleViewAppear()` (déjà présent) et un nouveau
`TwoPlayerViewModel.handleViewAppear()` s'en chargent, bornés à
`moveLog.isEmpty` pour qu'un simple retour sur l'écran ne relance rien.

**Vérifié** : `GameClockStartTests` — 5 tests, dont celui exigé par le Lot 0.3
(« le temps des Blancs décroît AVANT le premier coup »). Sans le correctif,
**2 échouent** ; avec, les 5 passent.

*Piège de test rencontré, deux fois* : la première version lisait la pendule
juste après un `sleep` unique. La pendule décompte depuis sa propre tâche, sur
le même acteur que le test — quand d'autres suites saturent le `MainActor`, le
réveil du test peut précéder le premier tick. On mesurait l'ordonnancement, pas
le comportement. Remplacé par une attente active… dont la fenêtre de 10 s s'est
révélée **encore trop courte** quand la suite complète tourne : les bancs
d'essai moteur monopolisent l'acteur, et ce test a mis **170 s** à s'exécuter
sans qu'un seul tick passe dans sa fenêtre. Fenêtre portée à 120 s ; elle sort
dès la première décrue, donc ne coûte rien sur une machine au repos.

**Suite unitaire complète : 444 tests, 74 suites, 0 échec.**

### Lot 3 — Le PGN exporté perdait sa position de départ

`AnalysisViewModel.exportedPGN` valait `game.pgn`, **contournant** `PGNExport`
— qui existe précisément pour émettre `[SetUp "1"]` / `[FEN …]`. Pour une
session ouverte sur une FEN (scan, éditeur, « Position FEN »), le PGN partagé,
rechargé, rejouait ses coups depuis la position **standard**. La même valeur
alimentait le `sourceGamePGN` des puzzles générés.

`PGNExport` a été rendu robuste au passage : il préfixait `"[SetUp…]\n[FEN…]\n\n"`,
ce qui n'était correct **que parce que** les parties de l'app n'ont aujourd'hui
aucun tag. Au premier tag (nom des joueurs, `Result`, ou un PGN importé), le
préfixe créait une **troisième section** et `PGNParser` levait
`.tooManyLineBreaks` — PGN irrécupérable. Les tags s'insèrent désormais **dans**
la section de tags. Trois tests couvrent les trois cas (FEN, position standard,
partie déjà taguée).

### Lot 4 — Tâches non annulables

- **Lecture automatique (Analyse)** : la tâche remettait `autoplayTask = nil`
  en sortie de boucle sans vérifier que c'était bien *elle* l'enregistrée. Deux
  appuis rapprochés sur ⏯ et l'ancienne tâche annulait le suivi de la
  **nouvelle** : `isAutoplaying` repassait à faux pendant que la partie
  continuait de se dérouler, et `stopAutoplay()` n'avait plus rien à annuler —
  lecture inarrêtable. Corrigé par un jeton de génération.
- **Riposte de puzzle** : tâche différée non suivie, alors que le même piège
  avait déjà été corrigé pour `revealTask` juste à côté. Latent aujourd'hui,
  mais tout changement d'enchaînement aurait rejoué le coup adverse de
  l'ancien puzzle sur le plateau du nouveau. Suivie et annulée dans
  `loadNextPuzzle()`.

### Lot 5 — Scanner

- **Redressement calculé deux fois** : `rectifyAndSlice` fait déjà le
  `rectify`, et l'appelant demandait les deux — soit deux
  `CIPerspectiveCorrection` et deux redimensionnements 800×800 par scan, sur le
  chemin où l'utilisateur attend devant un indicateur d'activité. Remplacé par
  `rectify` + `slice`.
- **Paramètre mort** : `BoardReadingRotation.candidates(for:)` ignorait
  `source`. Le paramètre est **retiré** plutôt que documenté : une signature
  qui prend une source laisse croire à un comportement par source qui n'existe
  pas.
- **5.2 — mesuré, et la mesure a tranché contre le correctif.** Le diagnostic
  est exact à la lecture (`edgeProfile` laisse `profile[0]` et `profile[side-1]`
  à zéro, donc le couple pas/phase se choisit sur 7 lignes au lieu de 9). La
  dérivée décentrée aux bords a donc été implémentée, puis **retirée** : elle
  ne change **rien**, au centième de pixel près.

  | Cadrage | Écart max avant | après |
  |---|---|---|
  | parfait | 0,00 / 0,00 | 0,00 / 0,00 |
  | large (14 px de marge) | 1,71 / 1,71 | 1,71 / 1,71 |
  | serré (6 px rognés) | 6,00 / **14,52** | 6,00 / **14,52** |

  L'erreur du cadrage serré — la seule vraiment gênante, 14,5 px là où
  l'en-tête du module juge 2,5 px suffisants à faire chuter la reconnaissance —
  vient donc **d'ailleurs** : les lignes extrêmes y tombent hors de l'image, où
  `sample` rend zéro par construction, quoi que contienne le profil. On ne
  remue pas un algorithme calibré au pixel près pour un gain nul : le code
  d'origine reste, avec la mesure consignée en tête de fonction, et
  `BoardGridEdgeBiasTests` fige les trois valeurs pour qu'une régression se
  voie. Le vrai chantier — le cadrage serré — a maintenant sa référence
  chiffrée.

### Lot 6 — Répétition espacée

- **6.1 corrigé** : une position ayant un enregistrement **sans** `dueDate`
  n'était ni « due » ni « neuve » — elle disparaissait de la file, en silence.
  Inatteignable aujourd'hui (seul `recordReview` crée des enregistrements),
  mais `ensureProgress` est `@discardableResult` et visible dans tout le
  module. Traitée comme neuve, avec deux tests.
- **6.2 — décision : on assume, et on le documente.** FSRS-5 est correctement
  implémenté, mais `intervalDays` plancher à 1 jour : une position ratée
  revient **demain**, pas dans la session. Ajouter des *learning steps*
  changerait la nature de l'entraînement (durée de séance, nombre de positions
  vues par jour) — c'est une décision de produit, pas une correction de bug.
  Le comportement est désormais écrit noir sur blanc en tête de `FSRS.swift`,
  avec l'endroit où l'implémenter le jour venu (`OpeningTrainingQueue`, sans
  toucher au stockage).

### Vérification finale après les correctifs moteur

Les changements de cycle de vie du moteur étant les plus risqués de la
session, la suite UI complète a été rejouée : **33 verts / 2 rouges**, les
deux rouges étant les échecs préexistants déjà démontrés indépendants
(`KeyboardShortcutsUITests`, `ScannerFlowUITests`). Suite unitaire : **444
tests, 74 suites, 0 échec.**

### Non fait

- **Journal UCI en DEBUG (Lot 0.2)** non ajouté : les deux bugs qu'il devait
  départager (1.1 et 1.2) ont été confirmés autrement — le premier par lecture
  du shim (`if (gRunning) return;` sans reconfiguration du callback, sans
  ambiguïté possible), le second par le test de fuite, rouge puis vert. Un
  journal n'aurait rien prouvé de plus.
- Le **multiplexeur** du Lot 1.5 : l'invariant est rendu vérifiable, pas
  supprimé.

## Les deux échecs UI « préexistants » : c'était de la pourriture de test (2026-08-14)

Les deux tests que les chantiers précédents avaient constatés rouges — et
démontrés indépendants de leurs correctifs — sont désormais réparés. **Ni l'un
ni l'autre ne signalait un bug de l'app** : dans les deux cas, un écran avait
évolué et le test ne l'avait pas suivi.

### `KeyboardShortcutsUITests`

Il attendait un `StaticText` commençant par « Consultation ». Ce bandeau a été
retiré de l'écran *Jouer* par la refonte « contrôles simplifiés — une seule
rangée » (commit `e70d869`, antérieur à ces chantiers) : c'est désormais le
bouton « Reprendre ici » qui signale qu'on n'est plus sur la position vive, et
le libellé « Consultation — coup X/Y » ne subsiste que dans *Deux joueurs*.

Réécrit pour asserter le **comportement** plutôt que le chrome : après deux ←,
le plateau doit être revenu à la position de départ (e4 vide, pion en e2), et
→ doit le ramener en avant. Une refonte d'habillage ne le cassera plus ; une
flèche qui cesse de naviguer, si.

### `ScannerFlowUITests`

Deux changements cumulés, tous deux antérieurs :

1. la palette de pièces est maintenant **repliée** derrière « Éditer le jeu »
   (refonte condensée de l'éditeur) — le test tapait un bouton qui n'est plus
   visible d'emblée ;
2. les boutons de palette ont reçu des identifiants (`palette_wQ`…), et **dès
   qu'un élément en porte un, XCUITest ne résout plus la requête par
   libellé** : `app.buttons["dame blanche"]` ne matche plus rien, la recherche
   portant sur les identifiants.

Le test déploie donc la section puis cible `palette_wQ`. L'identifiant a de
plus l'avantage d'être indépendant de la langue, alors que le libellé passe par
le catalogue de traductions.

**Leçon commune** : un test UI qui s'accroche à un libellé visible ou à la
présence d'un bandeau se périme à la première refonte d'habillage, et le
signale par un échec qui ressemble à un bug. Les identifiants d'accessibilité
et les assertions de comportement, eux, survivent.

### État des suites après ces deux réparations

- **Suite UI : 35 tests, 0 échec** (iPhone 16, iOS 26.5) — entièrement verte
  pour la première fois depuis le début de ces chantiers. Hors captures App
  Store et balayage Dynamic Type, lancés à la demande.
- **Suite unitaire : 444 tests, 74 suites, 0 échec.**

## Précision du glisser-déposer (2026-08-14)

Le plateau découpait le point de relâchement au trait près : sur une case de
~46 pt (iPhone), relâcher 1 pt au-delà de la frontière jouait la case voisine,
ou plus souvent rien du tout. Et pendant le geste, **rien n'était annoncé** —
le joueur découvrait le résultat après coup.

### Fait

**Un résolveur unique, extrait dans un type valeur.** Toute la géométrie du
plateau vivait dans des méthodes **privées d'une `View`**, donc intestable ; on
n'y accédait qu'en passant par XCUITest, qui tape au centre exact des cases et
ne prouve donc rien sur la précision. `BoardGeometry` reprend la conversion
case ↔ point et ajoute `resolve(point:legalTargets:)`, dans l'ordre :

1. hors plateau au-delà d'une **marge de grâce** d'une demi-case → annulation ;
2. si la case géométrique est elle-même une cible légale, elle est retenue
   **telle quelle** — viser juste donne exactement le comportement d'avant, au
   point près ;
3. sinon, la cible légale dont le centre est le plus proche, dans un rayon de
   `0,85 × case` ;
4. si les deux meilleures sont indiscernables (< `0,15 × case` d'écart) →
   annulation.

**`square(at:squareSize:)` a disparu, et c'était un bug.** Il bornait les
coordonnées (`min(7, max(0, …))`) : relâcher très à gauche du plateau, à la
hauteur de a4, résolvait sur a4 et **jouait un coup jamais visé**. Son
remplaçant rend `nil` au-delà de la marge de grâce. C'est le seul défaut de
correction du lot ; le reste est du confort.

**La cible visée est annoncée en direct** (`dropTargetLayer`) : un remplissage
plein de `theme.selectedColor`, plus un liseré de la même teinte pour la
distinguer de la case de départ. Couche placée **au-dessus des pièces** — sur
une capture, un marqueur dessous serait masqué par la pièce adverse.

**Les pastilles de coups légaux suivent la pièce tirée**, plus la sélection.
Glisser une pièce non sélectionnée n'en affichait aucune.

**Le fantôme est soulevé** : agrandi de 20 %, décalé de 0,4 case hors de la
zone de contact. Le décalage suit `allPiecesRotated`, sinon il part vers le bas
pour le joueur d'en face en mode Table.

### Décisions d'architecture

**Le rayon est plafonné à `0,85 × case`, pas davantage.** La demi-diagonale
d'une case vaut `0,707 × case` : en dessous, un rayon ne couvrirait même pas
les coins de la case visée — il ne servirait à rien. Au-dessus de `1,0`, un
relâchement **centré sur une case adjacente** serait capté. `0,85` laisse
~18 pt de rattrapage au-delà du bord de la cible sur iPhone.

**L'ambiguïté annule au lieu de deviner.** Deux cibles légales quasi
équidistantes : le résolveur ne tranche pas. Mieux vaut redemander le geste que
jouer un coup non voulu — c'est la même logique que la marge de grâce, prise
dans l'autre sens.

**La case de départ est comparée sur la case *géométrique*, jamais sur la
sortie du résolveur.** Le piège n'est pas théorique : relâcher sur le bord haut
de e2 donne géométriquement e2, qui n'est **pas** une cible légale (aucun coup
ne va d'une case à elle-même) ; le rattrapage s'activerait donc, et le centre
de e3 n'est qu'à une demi-case — dans le rayon. Le geste de renoncement
jouerait un coup. Ordre figé par `theResolverAloneWouldSnapAwayFromTheOriginSquare`.

**La zone d'annulation n'a pas été élargie.** Elle reste la case de départ
exacte, conformément à la règle produit : annuler ne coûte rien, mais ne doit
pas non plus manger de surface utile du plateau.

**Les coups légaux sont calculés une fois par geste**, pas à chaque image — le
résolveur tourne à 60-120 Hz pour un ensemble constant. Le cache n'est réutilisé
que s'il appartient bien à la case tirée : un second doigt posé ailleurs pendant
le geste hériterait sinon des cibles de la première pièce.

**Comparaisons sur les carrés des distances** dans la boucle (jusqu'à 27 cibles
pour une dame au centre) ; les deux seules racines carrées du calcul servent la
garde d'ambiguïté, une fois par relâchement.

### L'arbitrage *Puzzles*, tranché et borné

Le risque connu : dans *Puzzles*, un coup légal mais faux consomme un essai.
Avant, un relâchement maladroit tombant sur une case **illégale** ne coûtait
rien ; avec le rattrapage, il peut désormais devenir un coup joué.

Trois bornes le rendent acceptable, et deux tests les figent :

1. **le résolveur ne peut choisir que parmi les cibles légales de la pièce
   tirée** — il ne peut donc jamais inventer un coup, seulement retenir celui
   dont le joueur était le plus proche, c'est-à-dire celui qu'il visait
   (`theResolverOnlyEverReturnsALegalTargetOrNothing`, balayage exhaustif au
   quart de case, deux orientations) ;
2. **le rattrapage ne franchit pas une case entière** : relâcher au centre
   exact d'une case annule, même si une cible légale est sa voisine directe
   (`theSnapNeverReachesAcrossAWholeSquare`) ;
3. **la teinte de cible dit en direct ce qui sera joué**, donc l'erreur est
   corrigeable avant de lever le doigt. Le rattrapage sans cet affichage aurait
   été inacceptable ; c'est un couple, pas deux améliorations séparées.

Le cas net : le joueur visait la bonne case et l'a manquée de peu. Avant, son
coup était perdu et il recommençait ; maintenant il est joué. Dans un puzzle
c'est le plus souvent le **bon** coup qui était en train de se perdre.

### Vérifié

- **`BoardGeometryTests` — 18 tests** : centres des 64 cases aux deux
  orientations, frontières au centième de point, primauté de la case
  géométrique, rattrapage vers la seule voisine légale, refus de voler le coup
  au profit d'une case illégale, ambiguïté, vainqueur net, marge de grâce,
  **régression du bornage** (`aFarAwayDropAlignedOnALegalEdgeSquareCancels`),
  propriété de sûreté, plafond du rattrapage, sens de la levée du fantôme des
  deux côtés de la table.
- **`DragPrecisionUITests` — 5 tests**, le câblage dans l'app réelle : une
  erreur de branchement laisserait la suite unitaire entièrement verte. Tous
  les points de relâchement sont calculés à partir de la **taille de case
  mesurée**, jamais en points en dur. Le plus utile est
  `testADropJustPastTheTargetSquareStillPlaysTheMove` : il relâche
  géométriquement **dans e5** et attend le coup e2-e4 — rouge avant ce
  chantier, vert après.
- **Suite unitaire : 464 tests, 76 suites, 0 échec** (contre 447 en référence
  avant le chantier), lancée seule.
- **Suite UI : 35 tests, 0 échec** — identique à la référence d'avant le
  chantier, plus les 5 nouveaux tests de glissement (**8 verts / 0 rouge** avec
  `TapToMoveUITests` et `TapToCaptureUITests`, qui protègent le chemin tap-tap
  que l'ordre des branches de `onEnded` aurait pu casser).

### Trois défauts de MON harnais, corrigés en route

Aucun ne signalait un défaut de l'app ; tous trois auraient pu être lus comme
tels.

1. **FEN de promotion impossible.** Le premier essai plaçait le roi noir en e8
   et le pion blanc en e7. Un pion ne capture pas devant lui : e8 ne figurait
   dans aucune cible légale, le test ne pouvait qu'échouer. Roi déplacé en h8,
   et **assertion de garde ajoutée** sur `square_e7` — si la saisie de position
   personnalisée cesse un jour de fonctionner, l'échec pointera là plutôt que
   sur un sélecteur absent.
2. **`app.otherElements["promotionPicker"]` ne matche jamais.** Mesuré : ni par
   glissement ni par tap-tap. L'identifiant est posé sur un conteneur que
   SwiftUI n'expose pas comme élément d'accessibilité à part entière. Les
   tuiles, elles, sont de vrais boutons — c'est d'ailleurs par
   `app.buttons["Dame"]` que `LayoutOverflowUITests` procédait déjà.
3. **Deux `xcodebuild test` simultanés font échouer la pendule.** En lançant la
   suite unitaire et une suite UI en parallèle sur deux simulateurs,
   `whiteTimeDecreasesBeforeTheFirstMove` a épuisé sa fenêtre de 120 s sans un
   seul tic, et les simulateurs ont fini en `Mach error -308 (server died)`.
   Relancé seul : **0,336 s, vert**. La fenêtre du test n'est pas en cause ;
   c'est le parallélisme qui l'est. Sur cette machine, les suites se lancent en
   séquence.

### Non fait, et pourquoi

**Aucun mécanisme de confirmation.** Un coup joué est joué : ni annulation
proposée, ni « êtes-vous sûr ». C'est la règle produit, et le rattrapage la
respecte en annulant au moindre doute plutôt qu'en demandant.

**La lisibilité de la teinte n'a pas été revalidée** pour le daltonisme ni le
contraste : `selectedColor` est déjà la teinte de sélection des quatre thèmes,
déjà validée, déjà affichée sur toutes les cases y compris la première rangée.
Le seul ajout est un liseré de la même couleur, qui ne peut que la rendre plus
saillante.

**Pas de capture d'écran en cours de glissement.** Les gestes XCUITest sont
atomiques : impossible de photographier l'état intermédiaire sans échafaudage
dans le code de production. Le seul fait visuel qui aurait pu casser en
silence — le **sens** de la levée du fantôme en mode Table — a été extrait en
`ChessBoardView.dragLiftOffset(squareSize:rotated:)` et couvert par un test.

## Le score de précision était trop généreux (2026-08-14)

Signalé en usage : « dans le module d'analyse, je trouve que le score de
précision est trop généreux si je compare avec chess.com — j'arrive
régulièrement à 92-94 % alors que je devrais être autour de 80 % », puis, dans
la foulée, « les coups de fin de partie ont aussi tendance à augmenter
artificiellement le score ».

**La seconde remarque explique la première**, et le calcul le confirme avant
toute modification de code. Partie de club témoin — 1 gaffe (25 points de
perte), 2 erreurs (12), 3 imprécisions (7), 34 coups sains (1) :

- sur 40 coups, perte moyenne 2,60 → **89,0 %** ;
- prolongée de 20 coups de finition dans une position déjà gagnée, où toute
  perte est nulle, la moyenne tombe à 1,73 → **92,5 %**.

Rien n'a été mieux joué : le dénominateur a grossi de vingt coups qui ne
pouvaient rien perdre. Une moyenne simple traite « ne rien lâcher dans une
position gagnée » comme un exploit.

### Deux pistes écartées par la mesure

**Le budget du moteur.** Une évaluation trop courte sous-estimerait
mécaniquement les pertes. Vérifié : 300 000 nœuds atteignent la profondeur
18-20, comparable à ce qu'annonce chess.com. Ce n'est pas le maillon faible.

**La méthode complète de Lichess** — une précision par coup, puis moyenne
pondérée et moyenne harmonique — a été implémentée, mesurée, puis **retirée**.
La courbe étant convexe, l'inégalité de Jensen rend cette agrégation *plus
généreuse* : la partie témoin est remontée à **93,3 %**, au-dessus des 92,5 %
qu'on cherchait à faire baisser. La moyenne harmonique ne compensait pas.

Au passage, le premier jeu d'essai était vicié : la courbe d'évaluation y était
inventée indépendamment des pertes, si bien que la pondération de volatilité
n'avait rien à mesurer et que les tests « passaient » sans rien prouver. Une
gaffe **doit** se voir dans la courbe — c'est la définition d'une gaffe. Les
tests dérivent désormais la courbe des pertes.

### Ce qui a été retenu

La courbe ne bouge pas, et reste appliquée à une **moyenne** des pertes — c'est
le sens strict, celui que Jensen favorise. Ce qui change, c'est la moyenne :
elle est **pondérée**, et le poids d'un coup est le produit de deux facteurs.

1. **Ce qui bougeait** — l'écart-type des probabilités de gain sur une fenêtre
   glissante, ramené à `[1 ; 3]`. Plage volontairement resserrée : avec celle
   de Lichess (`[0,5 ; 12]`), les six mauvais coups de la partie témoin
   captaient les trois quarts du poids et le score tombait à **68 %** — le
   calcul ne notait plus que les pires moments. « Un moment critique compte
   jusqu'à trois fois un coup tranquille » est le compromis retenu.
2. **Ce qui était en jeu** — au-delà de 90/10, la partie est tenue pour jouée
   et le coup ne pèse plus que 5 %. La volatilité seule ne suffisait pas :
   mesuré, avec un simple plancher, vingt coups de finition regonflaient encore
   le score de **14 points**. Une position figée à 99 % n'est pas seulement
   calme, elle ne décide plus de rien.

Le coup qui **fait** basculer la partie garde son poids plein : la position
n'est tenue pour jouée que si elle l'était avant *et* après.

Ce second facteur règle du même coup la sévérité : une gaffe est par définition
un grand écart de probabilité de gain, donc une forte volatilité, donc un poids
élevé. Elle ne peut plus être noyée sous vingt coups anodins — sans qu'il ait
fallu accorder un second barème.

### Vérifié

`AccuracyScoreTests` — 13 tests, **sans moteur** : tout porte sur l'agrégation,
et chaque chiffre est reproductible à la calculette.

| | ancienne méthode | nouvelle |
|---|---|---|
| Partie de club témoin | **92,50 %** | **83,72 %** |
| Gonflement par 20 coups de finition | +3,50 pts | **+0,97 pt** |
| Gaffe unique / même perte étalée | 95,60 / 95,60 | **89,36 / 95,60** |

La dernière ligne est la plus parlante : l'ancienne moyenne simple ne pouvait
**pas** distinguer une gaffe unique d'une perte diluée sur quarante coups —
même somme, même nombre de coups, même score au point près.

**Suite unitaire : 477 tests, 78 suites, 0 échec.**

### Calibrage restant, à trancher sur des parties réelles

Les 83,72 % du témoin tombent dans la zone attendue, mais le témoin est
**synthétique** : c'est un profil de pertes choisi à la main, pas une partie
jouée. La plage `[1 ; 3]` et le seuil 90/10 sont des arbitrages, documentés
comme tels et regroupés en constantes nommées (`decidedMargin`,
`decidedStake`). Le juge de paix reste une partie réelle réanalysée et comparée
à son score chess.com — c'est la seule vérité terrain disponible, et elle est
du côté de l'utilisateur.

## Le tap-tap était devenu plus exigeant que le glisser (2026-08-14)

Retour d'usage immédiatement après le chantier précédent : « ça coince des
fois, j'ai de la peine à cliquer sur la case d'arrivée — le déplacement
fonctionne bien ». **Asymétrie introduite par ce chantier même** : le
rattrapage vers la cible légale la plus proche n'avait été branché que sur le
GLISSER. Le tap-tap, lui, restait au point près.

### Ce que la mesure a dit — et ce qu'elle a démenti

Deux causes étaient plausibles. Une seule tient.

**Démentie : la dérive du doigt.** L'hypothèse de départ était que la case
d'arrivée, case NUE de la grille, n'a qu'un geste de tap — sans le
`DragGesture(minimumDistance: 0)` ni le repli à 12 pt dont bénéficie une pièce,
donc sans rien pour rattraper un tap qui glisse. Mesuré : un tap qui dérive de
**0,3 case** sur la case d'arrivée joue déjà le coup. La tolérance native
suffit largement. Hypothèse abandonnée, et avec elle le correctif risqué
qu'elle appelait — poser un `DragGesture` sur les 64 cases, alors que le
plateau est **dans un `ScrollView`** sur l'écran d'analyse iPhone : le
défilement démarré depuis le plateau en aurait fait les frais.

**Confirmée : l'absence de rattrapage.** Le même point, à 0,6 case du centre de
e4 (donc géométriquement dans e5), joue e2-e4 **en glissant** et **rien du
tout** en tapant. Le geste lent et posé était devenu le plus exigeant des deux.

### Le correctif

`SpatialTapGesture` remplace `onTapGesture` sur les cases : il rend le POINT
touché, et non seulement la case. Un geste de TAP ne capte pas le défilement,
contrairement à un `DragGesture` — la contrainte du `ScrollView` est donc
respectée sans compromis.

Le rattrapage ne s'applique qu'aux cases qui, sans lui, **ne feraient rien
d'utile** :

- une cible légale tapée directement est jouée telle quelle ;
- la case sélectionnée reste le geste de désélection ;
- une pièce à soi intercepte le tap avant la grille — elle porte son propre
  geste — donc changer de sélection n'est jamais concerné.

Reste la case morte tapée pendant qu'une pièce est sélectionnée, qui ne
provoquait qu'une désélection : c'est là, et là seulement, qu'on regarde s'il y
avait une cible légale dans le rayon. Le rayon, la garde d'ambiguïté et la
propriété de sûreté sont ceux de ``BoardGeometry`` — un seul résolveur pour les
deux gestes, ce qui était l'objet du chantier.

### Vérifié

- `TapPrecisionUITests` — 3 tests. `testATapJustPastTheDestinationSquareStillPlaysTheMove`
  était **rouge avant, vert après**. Les deux autres sont les filets : le tap
  tremblé (qui marchait déjà — le test le fige) et le tap propre + le tap
  franchement ailleurs, qui doit toujours désélectionner sans rien jouer.
- **11 verts / 0 rouge** avec `TapToMoveUITests`, `TapToCaptureUITests` et
  `DragPrecisionUITests` : les deux gestes se partagent désormais le résolveur,
  aucun des deux n'a régressé.
- **Suite unitaire : 466 tests, 77 suites, 0 échec.**

## La revue d'analyse qui n'avait jamais lieu (2026-08-14)

Signalé en usage réel : « je viens de finir une partie, et quand j'ai cliqué
sur analyse, l'app ne m'a pas affiché le graphique et n'a pas pré-calculé tous
les coups ; à la place le message *Moteur en attente* était affiché ».
**Intermittent** — la partie suivante a fonctionné.

### Le défaut

`classifyMainLine()` n'est pas appelée directement : elle est mise en **file**
moteur par `setupEngine()`, donc **derrière** le démarrage de Stockfish — ~1 s,
le temps de charger le réseau NNUE de 78 Mo. Son maillon commence par
`guard !self.isTornDown`.

Si l'écran est marqué disparu pendant cette seconde-là, la classification est
**abandonnée en silence**. Et plus rien ne la redemande jamais :

- la reprise de `handleViewAppear()` ne repasse par `setupEngine()` que si le
  moteur avait été **libéré** en partant. Ici il ne l'était pas — il n'existait
  pas encore quand la disparition a été signalée, et la tâche de libération
  sort sur `guard let engine = self.engine` sans rien marquer ;
- la branche de revue de `handleViewAppear()` se contentait d'un
  `showCachedEval(at:)`, c'est-à-dire de lire un cache **vide**.

Le moteur reste bien vivant, donc `isEngineUnavailable` reste faux et **aucune
bannière ne prévient**. L'écran affiche « Moteur en attente » — le libellé du
badge quand le moteur ne calcule rien — indéfiniment. C'est exactement le
symptôme rapporté, et son caractère intermittent découle de la largeur de la
fenêtre : il faut que l'événement de disparition tombe dans cette seconde-là.

Le même trou laissait une revue **quittée en cours de route** définitivement à
moitié faite, courbe d'évaluation tronquée comprise : la boucle sort sur
`isTornDown`, et le retour sur l'écran ne reprenait rien.

### Le correctif

`handleViewAppear()` décide désormais sur les **données**, pas sur un drapeau :
si la ligne principale n'est pas entièrement classée et que le moteur n'est pas
déclaré indisponible, la revue est **relancée**. `classifyNode` ignorant les
nœuds déjà en cache, une reprise ne recalcule que ce qui manque.

Un drapeau de progression aurait menti : `isClassifying` est remis à faux par
la sortie de boucle, précisément dans le cas qu'il faut détecter.

Ajout d'un garde `isClassificationPending` : `isClassifying` ne passe à vrai
qu'une fois le maillon **arrivé à son tour**, une seconde plus tard. Sans lui,
un second `onAppear` — SwiftUI en émet parfois deux — enfilait une seconde
classification qui ne recalculait rien mais faisait clignoter la barre de
progression.

### Ce qui n'a PAS été touché, et pourquoi

Le garde `isTornDown` reste tel quel. Il protège d'un vrai désastre, documenté
plus haut : une classification poursuivie sur un écran mort, suivie d'un
`go infinite` que plus rien n'arrêterait — moteur et view model retenus jusqu'au
kill de l'app. Le défaut n'était pas d'abandonner, c'était de ne jamais
reprendre.

### Vérifié

`AnalysisReviewRestartTests` — 2 tests à **moteur réel**, donc gated par
`ENGINE_INTEGRATION=1` comme les autres tests d'intégration moteur du dépôt.

- `aReviewSkippedWhileTheScreenWasAwayIsRestartedOnReturn` reproduit la fenêtre
  de façon déterministe : `handleViewDisappear()` est appelé alors que `engine`
  est encore `nil`. **Rouge avant** — zéro coup classé 90 s après le retour sur
  l'écran, moteur vivant, aucune bannière. **Vert après**, en 12 s.
- `aReviewLeftHalfwayIsResumedOnReturn` couvre l'écran quitté en cours de revue.
  Première version écrite sur une partie de 4 coups : elle passait **sans rien
  prouver**, la revue se terminant avant qu'on ait le temps de quitter l'écran.
  Réécrite sur 20 coups, avec un `#require` qui échoue si la revue s'est
  terminée trop tôt — la reproduction ne peut plus se dégrader en silence.
- **Suite unitaire complète : 466 tests, 77 suites, 0 échec.**

Non reproduit en conditions réelles : je n'ai pas provoqué l'événement de
disparition dans l'app elle-même. Ce qui est établi, c'est que ce chemin produit
exactement le symptôme décrit et que rien ne l'en sortait ; si le déclencheur
réel avait été autre, le symptôme se reproduira et il faudra chercher ailleurs.

## Chantier I — « le pourquoi » (2026-08-15)

Premier des trois chantiers de l'analyse produit du 15/08. Le constat de
départ : le bandeau coach sait dire « e5 — Erreur, −12 % », donc **combien** un
coup coûte, et n'a jamais su dire **ce qui le punit**. L'utilisateur apprend
qu'il a eu tort, pas ce qu'il n'a pas vu, et rejouera le même coup dans trois
parties. Toute la valeur pédagogique est dans le pourquoi.

### La matière première était déjà payée

`rankedEval` renvoie la **variante principale** du moteur pour chaque rang, et
`makeCachedEval` la jetait. Or sur la position d'APRÈS un coup — que la
classification évalue de toute façon —, cette variante est exactement la
**réfutation** : ce que l'adversaire va faire du coup joué.

Le chantier ne coûte donc **aucune recherche moteur supplémentaire**. Expliquer
une revue de quarante coups, c'est quarante rejeux de douze demi-coups sur un
plateau.

### Ce qui a été construit

`TacticalMotifDetector` (pur) reconnaît le motif d'UN coup à partir du plateau
d'après : mat (et mat du couloir), fourchette — royale comprise, le roi nommé
en premier —, échec à la découverte, clouage, pièce en prise.

`MoveExplainer` (pur) rejoue la réfutation et en tire le motif, le coût
matériel et la phrase. Deux pièges y sont traités, tous deux mesurés :

- **le matériel se lit au dernier point CALME de la ligne**, pas au dernier
  demi-coup. Une variante coupée juste après une prise annoncerait une perte de
  dame que la reprise du demi-coup suivant efface. Quand aucun point calme
  n'existe, on se rabat sur le dernier demi-coup et le chiffre est surévalué —
  comportement figé par un test plutôt que laissé implicite ;
- **le mat fait taire le décompte matériel.** « Mat en 2. Vous perdez
  3 points. » n'a aucun sens.

### Aucun modèle de langage, et c'est le point

Un modèle qui commente une position invente des motifs qui n'y sont pas. Ici
tout est **rejoué sur un plateau** : le motif est prouvé par la ligne du
moteur, ou il n'est pas nommé. L'explicateur rend `nil` chaque fois que la
ligne ne dit rien d'exploitable — mieux vaut se taire que meubler. Dans une app
d'apprentissage, une explication fausse s'apprend aussi bien qu'une vraie.

### Les phrases se construisent à la LECTURE

L'explication est mise en cache pour toute la session ; un changement de langue
en cours de route doit la retraduire, pas la laisser figée. `sentence(notation:)`
est donc pure et appelée au rendu, sur le modèle de `SANFormatter.display`.

Deux contorsions de français assumées : tournure **nominale** pour le clouage
(« clouage de votre cavalier devant votre roi ») parce que « votre tour est
clouée » demanderait un accord en genre qu'un gabarit à trous ne sait pas
faire ; et la pièce qui démasque n'est **pas nommée** dans l'échec à la
découverte, pour la même raison (« son fou » / « sa tour ») — la flèche du
plateau la montre déjà.

### L'interface : `ViewThatFits`, pas un `if`

La seconde ligne du bandeau coach est exactement le genre d'ajout qui l'avait
déjà fait passer sous le bord de l'écran (colonne gauche de l'iPad en paysage,
qui n'est pas dans un `ScrollView` — voir plus haut « Revue UX — disposition
iPad »).

La barre est donc rendue par `ViewThatFits(in: .vertical)` : la version à deux
lignes n'est retenue que si elle TIENT dans la hauteur proposée, sinon on
retombe sur la barre d'une ligne d'hier, à l'identique. Aucune constante de
chrome devinée, et la phrase ne peut structurellement pas repousser le plateau
— elle prend la place restante ou elle s'efface.

### Ce qui n'a PAS été touché, et pourquoi

- **`PuzzleThemeDetector` n'est pas fusionné** dans le nouveau détecteur, bien
  que les deux fassent un travail voisin. Il étiquette une bibliothèque de
  puzzles **déjà en base** : changer son verdict rétiquetterait des puzzles
  existants. La fusion se fera quand elle sera l'objet du chantier.
- **Seules les fautes sont expliquées** (`quality.isFault`). La variante
  d'après un bon coup raconte la suite de la partie, pas une punition.
- **Pas de repli sur les annotations d'un PGN importé**, contrairement à
  `lastMoveQuality` : un « ?? » écrit par quelqu'un d'autre dit qu'il y a
  faute, jamais laquelle.
- **Le niveau 3 (positionnel)** — les coups qui ne perdent rien mais abandonnent
  une case, ouvrent une colonne, isolent un pion — reste à faire. C'est là que
  ça devient rare ; ce n'est pas là que ça devient utile en premier.

### Vérifié

- `TacticalMotifDetectorTests` et `MoveExplanationTests` — **20 tests**. Chaque
  motif a son test de reconnaissance ET son test de NON-reconnaissance :
  l'échange pris pour une pièce en prise, l'échec direct pris pour une
  découverte, le roi en échec pris pour une pièce clouée, l'attaque simple
  prise pour une fourchette. Les variantes sont écrites à la main, donc les
  tests ne dépendent ni de Stockfish ni de sa profondeur.
- `CoachExplanationUITests` — parcours réel, moteur réel : mat du berger importé
  en PGN, navigation sur la gaffe `3...Cf6`. L'app affiche
  **« Dxf7# : et c'est mat. »**
- **Mesures de mise en page** (frames d'accessibilité, jamais de captures — le
  piège du paysage au simulateur est documenté plus haut) :
  - iPhone 17 portrait : bandeau `y=[689,3…750,7]`, hauteur **61,3 pt**,
    fenêtre 874 pt ;
  - iPad mini **paysage** — le cas qui avait cassé : bandeau
    `y=[624,0…685,5]`, hauteur **61,5 pt**, fenêtre 744 pt. La version à deux
    lignes y tient, avec 58 pt de marge. Aucun débordement horizontal.
- **Suite unitaire : 497 tests, 80 suites, 0 échec.**
- UI de non-régression : `AnalysisReviewUITests`, `AnalysisStepThroughUITests`,
  `LayoutOverflowUITests` et `DynamicTypeOverflowUITests` (AX3 et AX5 compris) —
  **12 tests, 0 échec.**

## La promotion sur iPad mini : question close, l'app n'a jamais été en cause (2026-08-15)

Point 1 de la liste « Reste à faire » — le seul dont l'impact utilisateur était
**inconnu**, donc le premier traité.

### Ce qu'on cherchait

`testPromotionPickerFitsOnScreen` était rouge sur iPad mini et vert sur les deux
iPad Pro. Le sélecteur de promotion ne s'ouvrait jamais après 53 s. Soit un
utilisateur d'iPad mini ne pouvait pas promouvoir un pion en analysant, soit
c'était un artefact du test.

### La réponse : artefact de test

Un test dédié — `PromotionUITests`, qui ne mesure rien et vérifie seulement que
le sélecteur **s'ouvre** — a été rejoué sur trois états du dépôt, sur le même
simulateur iPad mini (A17 Pro) :

| Commit | Date | `testPromotionPickerOpensInAnalysis` |
|---|---|---|
| `4dd031e` — **le commit où le relevé a été consigné** | 14/08 07:32 | ✅ |
| `a4c51f3` — avant le rattrapage du tap-tap | 14/08 18:45 | ✅ |
| `8fb563f` — état courant | 15/08 | ✅ |

Les cadres relevés sont identiques aux trois états (`a7` en
`[318,5 ; 181,5 ; 49,5×50]`, `a8` juste au-dessus, tous deux `atteignable=oui`).

L'hypothèse « c'est la précision du tap qui a corrigé ça » est donc **infirmée
par la mesure** : le chemin passe déjà avant ces commits. **L'app n'a jamais été
cassée sur iPad mini**, et aucun utilisateur n'a jamais été touché.

### Ce qui reste, et qui vaut mieux qu'un diagnostic

Le mécanisme exact de l'ancien faux rouge n'est pas élucidé — il n'existe plus
et ne se reproduit sur aucun des trois états. Chercher plus loin coûterait du
temps de machine pour une réponse sans conséquence.

Ce qui compte est acquis : la promotion dans *Analyser* a désormais un test
**sur toutes les classes de taille**, là où `LayoutOverflowUITests` se borne à
la classe compacte (il mesure une largeur, ce qui n'a de sens que là). La
question ne peut plus se rouvrir en silence.

## Le cadrage serré du scanner : la bonne grille était hors concours (2026-08-15)

Point 2 de la liste. Une capture rognée au plus juste sortait avec **14,5 px**
d'erreur de grille, alors que l'en-tête de `BoardGridFinder` juge 2,5 px
suffisants à faire chuter la reconnaissance.

### Le défaut, en une ligne

`lines(from:scale:)` exigeait que les 9 lignes tiennent dans l'image :
`phase >= -1` **et** `phase + period * 8 <= side + 1`.

Sur le cas de référence — plateau de 800 px rogné de 6 px, donc image de 788 px,
vraie grille de pas 100 et de phase −6 — la première condition impose
`phase ≥ −1` et la seconde `phase ≤ −11`. Elles sont **contradictoires** : aucun
pas de 100 n'était admissible. La recherche se rabattait sur `period ≤ 98,75`,
soit 1,25 px d'erreur par case et une dizaine de pixels au bout de la grille.

**La bonne réponse n'était pas mal notée : elle était hors concours.** C'est
pourquoi corriger le profil des bords n'avait rien donné — le diagnostic
précédent cherchait au bon endroit une cause qui était ailleurs.

### Trois correctifs, chacun révélé par le précédent

1. **Le garde devient un quorum.** Une grille a le droit de déborder ; il suffit
   que 7 de ses 9 lignes tombent dans l'image. Le score reste une SOMME et non
   une moyenne, délibérément : une ligne hors champ rapporte zéro, donc déborder
   coûte des points. Une moyenne rendrait le débordement gratuit et une grille
   pourrait gagner en poussant dehors ses deux lignes les plus faibles.
   → rangées 14,52 → 2,58.

2. **La recherche s'affine.** Il restait 2,58 px, et c'était la
   **quantification** : 25 pas sur ±12 % donnent 0,985 px de résolution, et le
   vrai pas (100 pour un idéal de 98,5) tombe entre deux crans. L'erreur est
   petite par case et s'ACCUMULE sur sept. Deux passes d'affinage autour du
   meilleur couple, chacune divisant le pas par 12 : résolution finale 0,007 px,
   pour ~17 000 interpolations là où le profil en fait déjà 600 000.

3. **Les ex æquo se tranchent vers la grille la plus simple.** L'affinage a
   révélé un biais que la quantification masquait : `edgeProfile` calcule
   `|L(x+1) − L(x−1)|`, donc un bord franc en `x` allume `x−1` ET `x`. Toutes
   les phases de ce plateau de deux pixels marquent le même score, et la passe
   fine s'y posait n'importe où — un plateau **parfaitement cadré** ressortait
   décalé de 1,10 px, et `BoardRectifier` en tirait des vignettes de 97 px à un
   bout et 96 px à l'autre, alors que l'égalité de leurs tailles est un
   invariant (`slicedSquaresAreSquareAndTrimmedOfTheirNeighbours`, rouge).
   D'où la règle : **à score égal, on garde la grille la plus proche de
   l'hypothèse uniforme**. Quand l'image ne distingue pas deux grilles, on ne
   s'éloigne pas du découpage naïf sans raison ; quand elle les distingue, le
   score tranche seul.

C'est aussi l'explication rétrospective du « la dérivée décentrée ne change
rien » consigné en août : c'était vrai, mais parce que la quantification de la
recherche masquait le biais de bord — pas parce qu'il n'existait pas.

### Vérifié

Écart maximal des 9 lignes, et des **7 lignes intérieures** — celles qui
découpent réellement les vignettes, les deux extrêmes étant hors image et
ramenées au bord par `grid(in:)` :

| Cadrage | avant | après | intérieur après |
|---|---|---|---|
| parfait | 0,00 / 0,00 | **0,00 / 0,00** | 0,00 / 0,00 |
| large (14 px de marge) | 1,71 / 1,71 | **0,99 / 0,99** | 0,87 / 0,87 |
| serré (6 px rognés) | 6,00 / **14,52** | **6,00 / 6,00** | **0,96 / 0,96** |

Les 6,00 restants du cadrage serré ne sont plus une erreur de recalage : ce sont
exactement les deux lignes hors image, ramenées au bord. L'intérieur est à
0,96 px, très en dessous du seuil de 2,5.

**Aucun cadrage n'est dégradé, tous sont sous le seuil.**

- `BoardGridEdgeBiasTests` porte désormais une assertion SERRÉE sur les lignes
  intérieures du cadrage serré (< 2 px, contre « < 60, ne pas partir en
  vrille »), et 2,5 px sur les deux autres cadrages.
- **Suite unitaire : 497 tests, 80 suites, 0 échec** — dont tout le pipeline
  scanner (`BoardScannerTests`, `ScannerFixtureTests`,
  `RealisticScreenshotScanTests`, `BoardRectifierTests`).
- `ScannerFlowUITests`, signalé comme échec préexistant le 14/08, **passe**.

## Feuilles modales iPad (Lot 4.5) : le bouton était bien sous le pli (2026-08-15)

Point 3 de la liste. Une `.sheet` sans consigne s'ouvre en **form sheet**
(~540×620) sur iPad. Deux écrans y étaient à l'étroit : le scanner, dont le
recadrage à quatre poignées est le geste le moins adapté à une petite fenêtre,
et l'éditeur de position, dont le plateau est plafonné à 460 pt.

### Mesuré avant de corriger

iPad mini (A17 Pro), portrait, fenêtre 744×1133, sur l'éditeur ouvert depuis
*Contre l'ordinateur* :

| | bouton « Utiliser cette position » | atteignable |
|---|---|---|
| avant | `y=[1022,0…1070,5]` | **non** |
| après | `y=[827,5…876,0]` | **oui** |

C'est exactement le symptôme consigné : le bouton de validation **n'était jamais
visible à l'ouverture**. Il fallait défiler pour le trouver, sans rien qui
l'indique.

Pour le scanner, la feuille passe d'un bandeau centré (`Annuler` en `y=250,5`,
soit une feuille de ~620 pt centrée sur 1133) à une feuille qui part du bord
haut (`y=56,0`).

### Le correctif : `presentationSizing(.page)`, pas `fullScreenCover`

Quatre sites (`NewGameSetupView` et `LabSetupView`, éditeur et scanner). Le
choix se justifie :

- **sans effet sur iPhone**, où `presentationSizing` ne s'applique pas — le
  parcours compact n'est pas touché du tout ;
- **le glissement de fermeture est préservé**, contrairement à un
  `fullScreenCover` qui aurait forcé le passage par « Annuler ».

### Un piège de test, corrigé en route

La première version du test du scanner mesurait la **largeur** de la feuille et
passait **aussi sans le correctif** : sur un iPad mini en portrait, une form
sheet fait déjà 540 pt sur 744, soit plus de la moitié. C'est la HAUTEUR qui
distingue les deux présentations. L'assertion a été recalée dessus, et le test
vérifié rouge-avant/vert-après pour de bon.

### Vérifié

`IPadSheetSizingUITests` — 2 tests, iPad mini. **Rouge avant, vert après** sur
les deux, la mesure étant imprimée (`FEUILLE|…`) même quand le test passe. Le
test se saute proprement sur iPhone, où la form sheet n'existe pas.

## Dynamic Type : le décompte de 29 était un faux chiffre (2026-08-15)

Point 4 de la liste, qui annonçait « 29 `.font(.system(size:))` qui ne scalent
pas du tout ». Le chiffre est exact, sa lecture ne l'était pas : **la très
grande majorité de ces 29 sites ne DOIT pas scaler.**

### Ce que le décompte mélangeait

En les regardant un par un, ils se rangent en trois familles :

1. **Des SF Symbols dans un cadre de contrôle fixe** — `Image(systemName:)` à
   15 pt dans un `.frame(width: 44, height: 44)`, à 17 pt dans un cercle de
   46 pt, à 11 pt dans un carré de 22 pt. C'est le gros du lot. Un glyphe est
   dimensionné pour SON contrôle : le faire grossir dans un cadre qui ne bouge
   pas ne l'agrandit pas, ça le rogne. Les figer est la pratique correcte.
2. **Des tailles dérivées de la géométrie du plateau** — `squareSize * 0,2`
   pour les coordonnées, `side * 0,5` dans l'éditeur, `size * 0,42` pour les
   pastilles de qualité. Ce n'est pas de la typographie, c'est du dessin : ces
   tailles doivent suivre le plateau, jamais le réglage de texte.
3. **Du vrai texte que l'utilisateur lit** — et il n'y en a que **quatre**.

### Les quatre, et pourquoi ce sont les bons

Le symptôme décrit — « dans une même rangée, une moitié du texte grandit et
l'autre non » — se lisait littéralement dans deux d'entre eux :

- `GameSummaryView` : `Text("87")` figé à 40 pt **concaténé** avec `Text(" %")`
  en `.headline`, qui scale. À AX5, le « % » rattrapait le nombre ;
- `HomeView` : le nom « ChessLab » figé à 32 pt, juste au-dessus d'un
  `.subheadline` qui grossissait — à AX5 le sous-titre rattrapait le titre ;
- `ProgressionView` : le taux de réussite, 40 pt figés ;
- `TwoPlayerGameView` : le libellé d'un bouton, 15 pt figés — un libellé se lit,
  et sa capsule n'a pas de hauteur figée (des marges, pas un `frame`), donc
  elle grandit avec lui.

### Le mécanisme

`Font.system(size:)` ne scale pas, et la seule voie officielle est
`@ScaledMetric`, qui ne s'utilise que dans une vue. D'où `ScaledSystemFont`, un
modificateur qui le porte : le point d'appel reste une ligne. Sa documentation
énonce ce qu'il ne faut **pas** y passer — les deux familles ci-dessus — pour
que le prochain lecteur ne refasse pas la lecture hâtive du décompte.

Les trois chiffres affichés en très grand sont **plafonnés** (1,4× pour le nom,
1,5× pour les nombres) : à AX5, un 40 pt sans bride donnerait un 100 pt qui
chasserait le reste de la carte. Le plafond garde la réponse à Dynamic Type —
le chiffre grossit bel et bien — sans faire exploser la mise en page.

### Vérifié

- Balayage `DynamicTypeOverflowUITests` à L, AX3 et AX5 : **aucun débordement
  nouveau**, sur aucun écran.
- L'écran **Progression a été ajouté au balayage** : c'est le seul qui affiche
  un nombre en très grand, il devait être couvert dès lors qu'il scale.
  `progression|aucun` à AX5.
- **Suite unitaire : 497 tests, 80 suites, 0 échec.**

### Trouvé au passage, NON corrigé

Le balayage signale un débordement de **10,7 pt** sur la tuile « Deux joueurs »
de l'accueil (`x=[208,0…412,7]` pour une fenêtre de 402 pt sur iPhone 17). Il
est présent **à toutes les tailles de texte, y compris la taille L par défaut**,
donc étranger à Dynamic Type — et antérieur à ce chantier.

À noter : `LayoutOverflowUITests.testNoOverflowOnHomeScreen` passe malgré tout,
parce que `LayoutProbe` ne parcourt pas les mêmes types d'éléments. Les deux
sondes ne sont pas d'accord, et c'est la première qu'il faudra croire. À traiter
séparément — ce n'est ni un problème de taille de texte, ni un des quatre points
de la liste.

## Retour testeur externe (Nils, ~1800 Elo, iPhone 11) — 2026-08-15

Premier retour d'un joueur classé sur une version installée. Quatre points, dont
un qui met en cause la crédibilité de tout un mode.

### 1. « Cette base de données d'ouvertures semble douteuse » — LE point dur

Il envoie deux captures : Blackmar-Diemer, dernier coup de la variante
**…Cd5 qui perd une pièce** ; gambit Englund, **…Db4 qui laisse une tour
gratuite en a1** (…Dxa1+ gagnait). Il a raison sur les deux.

**Cause.** `validate.py` ne vérifiait que l'intégrité du graphe — légalité,
clés FEN, arêtes non orphelines. Rien ne vérifiait la QUALITÉ ÉCHIQUÉENNE. Un
coup absurde mais légal passait, et les docstrings de 52 fichiers de contenu
affirmaient « Lignes vérifiées » sans que rien ne l'ait jamais vérifié.

**Constat de l'audit** (Stockfish 17, prof. 18 en balayage, 24 en contre-mesure,
3 067 arêtes) : **32 coups perdant ≥ 1,50**, dont 10 en FIN de chapitre. Le
défaut se concentrait là — une variante s'achevait sur une gaffe, ce qui est
exactement ce qu'un lecteur remarque en premier.

**Corrigé — 15 lignes réécrites**, chaque remplacement calculé coup par coup au
moteur :

| ouverture | avant | après |
|---|---|---|
| englund-gambit | 8…Db4 (−2,12) | **8…Dxa1+** (+5,67), puis Cd1 Dxa2 |
| englund-gambit | 5…Dxb2 (−2,20) | **5…Dxf4**, jusqu'à Cxa8 (cavalier enfermé) |
| blackmar-diemer | 10…Cd5 (−4,35) | **10…e6**, Ce5 Ff5 Cxc6 bxc6 |
| scandinavian | 5…Cxd5 (−4,72) | **5…Fg4 !** d'abord — le fou d7 bouchait la colonne d |
| caro-kann (Fantaisie) | 7…e5 (−1,33) | **7…Dh4+ !** Re2 Dxe4+ Rf2 Dh4+ |
| anti-sicilians (Smith-Morra) | 9…Fe7 (−2,24) | **9…Dc7** avant le fou (sinon e5 !) |
| kings-indian (Sämisch) | 11…a5 (−1,72) | **11…Fxg4 !** sacrifice de démolition |
| bogo-indian | 7…Cbd7 (−2,19) | **7…Fd7**, sans lâcher le fou b4 |
| colle (Koltanowski) | 11.De2 (−1,80) | **11.Fxh7+ !** le sacrifice grec, raison d'être du système |
| colle (Zukertort) | 9.Cd2 (−1,60 après …b6) | **9.f4 avant Cd2** — l'autre ordre perd d4 |
| london (principale) | 10…Ce4 (−1,52) | **10…Ce7** vers f5 |
| london (piège Cb5) | 6.Tb1 (+0,21) | **6.a3 !** (+3,10) ferme a2 avant Tb1 |
| kings-indian-attack | 10.Cf1 (perd e5) | **10.De2** d'abord, puis Cf1 |
| sicilian-classical | 10…Cge5 (−0,06) | **10…Fxd4 !** (+1,57) |
| sicilian-scheveningen | 10…b5 (−3,51) | **10…Da5** — …b5 perdait la tour a8 |

Et 4 coups adverses volontairement perdants, qui étaient présentés comme
normaux, portent désormais `role: "trap"` — l'app les affiche avec la pastille
« Piège » (Englund 6.Fc3, Albin 6.Fxb4 du piège de Lasker, Stafford 6.Cc3,
Levenfish …Cd5). Le commentaire du Stafford affirmait même que 6.Cc3 était
« la bonne défense » : c'est faux, seul 6.Fe2 tient, et c'est dit maintenant.

**Garde-fou permanent : `tools/opening-generator/audit.py`.** Rejoue chaque
arête sous Stockfish et sort en erreur si un coup perd ≥ 1,50 sans annotation.
Deux niveaux, parce que les deux fautes ne se valent pas :
- **erreur (bloquant)** — coup de NOTRE répertoire qui perd, ou fin de chapitre
  qui perd : on enseigne une faute, ou on laisse la variante finir sur une
  gaffe. C'est le défaut remonté par le testeur, et il ne peut plus passer.
- **avertissement** — coup de l'ADVERSAIRE en milieu de ligne qui n'est pas le
  meilleur : on ne ment à personne, mais on ne couvre pas sa meilleure défense.
  Lacune de couverture, pas mensonge. `--strict` bloque aussi là-dessus.

À enchaîner systématiquement : `python3 author.py && python3 audit.py
--stockfish "$(which stockfish)"`. Documenté dans le README du générateur.

Le garde-fou a d'ailleurs trouvé une 15e gaffe que mon premier balayage avait
manquée (Scheveningen …b5, qui perd la tour a8) : la contre-mesure à profondeur
24, faite DEPUIS LA MÊME POSITION via `root_moves`, voit ce que la comparaison
parent/enfant à profondeur 18 laissait passer. C'est la raison d'être des deux
passes.

**État : `audit.py` sort 0 — aucune gaffe enseignée sur les 58 cours.**

### 1 bis. Seconde passe — les lacunes de couverture, et deux faux positifs

Les 7 avertissements de la première passe se sont révélés être trois choses
différentes, et deux d'entre elles étaient des défauts de MON outil :

- **Faux positif « le meilleur coup est déjà à côté »** (Englund 5.Cc3) : la
  position proposait DEUX arêtes, Cc3 et Fd2, et Fd2 est justement le meilleur.
  Le lecteur voit les deux ; il n'y a rien à combler. `audit.py` regarde
  désormais les coups FRÈRES — mais seulement pour l'adversaire : de notre côté,
  une alternative perdante reste perdante même à côté du bon coup.
- **Faux positif « déjà perdu »** (Englund 6.Dd2, Stafford dxe4) : au fond d'un
  piège, l'adversaire perd quoi qu'il joue (−5,64 contre −3,96). Signaler qu'il
  aurait pu perdre plus proprement n'apprend rien. Filtre à −3,00.
- **Vraies lacunes, comblées** — 4 branches ajoutées, calculées au moteur :

| ouverture | ce qui manquait | pourquoi ça comptait |
|---|---|---|
| london-system | 5…Cd5 après 5.Cb5 | le chapitre ne montrait que 5…Ca6, qui perd — on croyait le piège gagnant par force. Il ne l'est pas : 5…Cd5 tient par répétition |
| colle-system | 10…Cxe5 | le sacrifice grec ne marche que si les Noirs reculent en d7. S'ils prennent, les Blancs sont un pion de moins et sans attaque |
| latvian-gambit | 6.Fh5+ | la réfutation qui gagne la qualité par force — à connaître AVANT de jouer le Letton, pas après |
| kings-indian | 11.h4 | plus fort que Cge2, et …Fxg4 ne marche plus |

**Reste 1 avertissement, assumé** : Blackmar-Diemer 8…h6, où le moteur préfère
8…Fb4 (−1,87 contre +0,80). Non comblé volontairement — la suite que propose le
moteur passe par un Th3 que je ne peux pas présenter comme de la théorie, et
8…h6 est bien le coup principal des sources. C'est une vraie lacune, elle est
inscrite ici plutôt que masquée par une ligne inventée.

### 2. « L'architecture est très bonne mais le contenu est plutôt mauvais »

Mesuré, et il a encore raison : les 58 cours totalisent **3 123 positions pour
3 067 arêtes** — soit des arbres quasi LINÉAIRES (une arête par position). La
Scandinave a 79 positions ; il dit connaître « 10× plus de coups théoriques que
ceux montrés, rien que de tête », et avoir un livre de 300 pages sur cette seule
ouverture.

**Cause structurelle trouvée** : `generate.py`, la chaîne qui interroge
l'Explorer Lichess et construit un vrai graphe branchu avec transpositions,
**n'a jamais servi à la production** (son cache `.cache/explorer` est vide, son
`out/` ne contient que des stubs de 3 à 6 positions). Les 58 cours embarqués
sortent tous d'`author.py`, c'est-à-dire de variantes tapées à la main. Les deux
chaînes sont maintenant décrites côte à côte dans le README, parce que rien ne
le disait et que c'est la clé du sujet.

C'est la piste d'approfondissement : lancer `generate.py` par-dessus les lignes
écrites à la main donnerait les défenses alternatives réelles — et l'audit
ci-dessus devient alors indispensable, puisque les branches à faible fréquence
d'une base 1400-1800 contiennent forcément des mauvais coups.

### 3. Trois essais par puzzle — corrigé

« Le but d'un puzzle c'est de réfléchir jusqu'à ce qu'on ait calculé la variante
jusqu'au bout, pas de tenter un coup sans trop savoir pourquoi. » Argument
juste. **Un seul essai par défaut** ; les trois essais restent disponibles dans
Réglages → Puzzles pour qui préfère chercher en tâtonnant. L'indicateur affiche
« UN SEUL ESSAI » plutôt qu'un compteur à un cran.

### 4. Le lecteur d'ouvertures oblige à faire défiler — corrigé

« Quand il y a beaucoup de coups, les derniers apparaissent bas, il faut
scroller et on ne voit plus l'échiquier. » Le plateau était DANS le
`ScrollView` : dès qu'une position offrait plusieurs variantes, lire la liste
sortait la position de l'écran — alors qu'on lit les coups en REGARDANT la
position. Le plateau est désormais **ancré**, seul le panneau texte défile, et
il est plafonné à la moitié de la hauteur utile. Bonus : disposition paysage
(plateau à gauche, lecture à droite) pour l'iPad.

### 5. L'abandon du moteur — rien à faire

« Très curieuse » se lit ici comme « intrigante » : il enchaîne sur l'intérêt de
voir quand l'ordinateur se considère perdu. Le comportement est déjà
désactivable (Nouvelle partie → « L'ordinateur peut abandonner s'il est
perdu »), seuil à −8,00 sur trois coups consécutifs. Aucun changement.

### 6. Répertoires écrits par l'utilisateur, et partagés — non fait, gros morceau

Sa proposition : que chacun saisisse SES ouvertures dans l'app et les mémorise
avec le moteur FSRS existant, puis puisse les partager. C'est la bonne réponse
au point 2 — et c'est un chantier entier (éditeur d'arbre, import PGN, stockage,
puis un dos serveur ou un format d'échange de fichier pour le partage), pas une
finition. Reporté sciemment, inscrit ci-dessous.

### Vérifié

- `audit.py` **vert** : 0 gaffe enseignée, 58 cours, 3 107 arêtes, seuil 1,50.
- `xcodebuild build` propre ; `xcodebuild test` (`ChessLabTests`) vert sur
  simulateur iPhone 17.
- Stockfish 17 compilé depuis `Vendor/CStockfish` pour l'audit (le paquet Swift
  n'expose pas de binaire ; il suffit de rétablir `main.cpp` depuis `_main.cpp`,
  que le Makefile amont attend et que la vendorisation avait renommé).
- **Vérifié sur la géométrie iPhone 11** (simulateur créé à la main :
  `xcrun simctl create "iPhone 11 (test)" …SimDeviceType.iPhone-11 …iOS-26-5`,
  le type d'appareil existe encore même si aucun simulateur n'est installé par
  défaut). `OpeningReaderScreenshotUITests` y passe et la capture montre le
  plateau entier, le fil des coups, la carte d'explication et la barre
  Précédent/Suivant simultanément à l'écran.
- **Défaut de test trouvé au passage** : `OpeningReaderScreenshotUITests`
  échouait sur écran court. Il exigeait l'existence de la cellule « Italian
  Game » AVANT de faire défiler, or la liste est paresseuse : sur iPhone 11 la
  cellule n'est même pas construite au départ. Le défilement passe avant
  l'assertion. Invisible sur la famille iPhone 17, où tout tient à l'écran.
- **Verrou ajouté** : `OpeningBlunderRegressionTests` — les 15 positions
  corrigées et les 3 pièges annotés sont relus DEPUIS LE BUNDLE à chaque
  `xcodebuild test`. La correction vivait dans `content/*.py`, hors cible iOS :
  rien n'empêchait un `author.py` de la faire disparaître sans bruit.
- Les trois captures « plateau coupé sur les bords » du testeur sont des
  **recadrages** : en mode Jouer et Analyser le plateau est volontairement de
  bord à bord (`padding(.horizontal, -12)` qui annule la marge du conteneur),
  donc exactement large comme l'écran. Rien à corriger.

## Répertoires personnels — import PGN, partage, suppression ✅ (2026-08-15)

Réponse à la demande de Nils (« que les utilisateurs puissent écrire leur base
d'ouvertures dans l'app… et se la partager »). Ce lot fait l'import et le
partage ; l'éditeur d'arbre dans l'app reste à faire, et reste facultatif.

### Pourquoi c'était petit

Deux choses, découvertes avant d'écrire quoi que ce soit, rendent ce lot court :

1. **`ChessKit.PGNParser` sait déjà lire les variantes.** Les parenthèses
   deviennent un `MoveTree` branchu (`Game.moves`, `Game.positions`,
   `history(for:)`). La partie réputée pénible — parser un répertoire
   arborescent — était déjà faite, et pas par nous.
2. **Tout l'aval est indexé par FEN normalisée, pas par identifiant de cours.**
   FSRS, fusion des transpositions, lecteur, entraîneur : un cours importé y
   entre sans qu'une seule ligne change. C'est le pari architectural du jalon J2
   qui paie ici — et c'est aussi pourquoi la progression d'une position apprise
   dans un cours livré vaut immédiatement dans un répertoire importé.

### Fait

- **`OpeningPGNImporter`** — PGN → `OpeningCourse`. Pur, sans disque ni UI.
  Une partie par chapitre (le tag `Event`, qui porte le nom du chapitre dans une
  étude Lichess exportée) ; les variantes deviennent des arêtes alternatives ;
  les positions communes FUSIONNENT, ce qui transforme un empilement d'arbres
  PGN en vrai graphe. Les annotations de l'auteur suivent : `?`/`??` → rôle
  `trap`, `?!` → `inaccuracy`, donc les pastilles du lecteur sans ressaisie.
  Chaque arête est vérifiée par `OpeningCourseValidator.resultingKey` AVANT
  d'être créée : un coup que ChessKit tokenise mais qui ne rejoue pas est
  compté et écarté, jamais transformé en arête invalide.
- **`UserOpeningStore`** — un JSON par répertoire dans `Documents/UserOpenings/`,
  au format EXACT des cours embarqués. C'est ce choix qui rend le partage
  gratuit : exporter, c'est donner le fichier ; importer, c'est le même
  décodeur qu'au démarrage. **Aucun serveur, aucun compte.** Identifiants
  préfixés `user-` (jamais de collision avec les 58 livrés). Tout cours passe
  le validateur d'intégrité AVANT écriture — la porte utilisateur n'est pas
  plus permissive que celle du bundle.
- **`OpeningCatalog`** — façade qui réunit bundle + utilisateur. Les huit sites
  d'appel de l'interface y passent ; `OpeningCourseLoader` reste strictement le
  bundle. `OpeningTranspositionIndex.bundled` et
  `OpeningsGraphFeature.hasBundledCourses` restent volontairement sur le bundle
  seul (l'index est un `static let` construit une fois : y mêler des cours qui
  arrivent après serait faux).
- **UI** — bouton « + » dans Ouvertures, feuille d'import (coller, `PasteButton`,
  ou ouvrir un `.pgn`/`.json`), choix du camp étudié (le seul renseignement
  qu'un PGN ne porte pas), `ShareLink` et suppression par glissement sur les
  répertoires personnels uniquement.
- **Section « Mes répertoires » en tête de liste.** Trouvé par le test de bout
  en bout : rangé alphabétiquement au milieu de cinquante-huit ouvertures, un
  répertoire fraîchement importé était introuvable — après l'import on retombait
  sur une liste d'apparence identique, sans rien qui dise que ça avait marché.
- Le dialogue de suppression dit ce qui SURVIT (« votre progression sur ces
  positions est conservée ») : elle est attachée aux positions, pas au fichier.

### Vérifié

- **14 tests unitaires** (`OpeningPGNImporterTests`, `UserOpeningStoreTests`) :
  variantes → branches, transpositions fusionnées (deux arêtes vers un seul
  nœud), annotations → rôles, commentaires affichables, multi-parties →
  chapitres, graphe incohérent refusé, et l'**aller-retour export → import**,
  qui est le vrai test du partage : le fichier écrit est exactement celui qu'un
  ami relira.
- **1 test UI de bout en bout** (`OpeningImportUITests`) : « + » → coller un PGN
  avec variante → la liste se rafraîchit seule → le cours s'ouvre dans le MÊME
  lecteur que les cours livrés → suppression.
- Suite complète verte, build propre.

### Reste (volontairement)

- **Éditeur d'arbre dans l'app** (ajouter/supprimer une variante, commenter) —
  3-4 lots. Facultatif tant que l'import existe : on écrit dans Lichess Studies
  et on importe.
- **Synchronisation iCloud des fichiers de cours** : la progression se
  synchronise déjà (elle est dans le store « Games »), le FICHIER du répertoire
  non — il reste sur l'appareil où on l'a importé. Le partage manuel comble en
  attendant.
- **Droits d'auteur** : Nils parle d'un livre de 300 pages. L'import personnel
  ne pose pas de question ; la redistribution entre utilisateurs, si. À trancher
  avant d'aller vers quoi que ce soit de centralisé.

## Version 1.4.0 — aide, bouton d'accueil, métadonnées App Store ✅ (2026-08-15)

### La 1.3 n'a jamais été soumise

Constat fait en préparant la 1.4, et il change le contenu du texte « Nouveautés » :
le dernier build envoyé à Apple est le **build 3 de la 1.2** (commit `a211763`).
Le 1.3.0 / build 5 a été préparé puis laissé de côté. Les utilisateurs passent
donc **directement de 1.2 à 1.4**, et le texte des nouveautés couvre les deux
lots — sinon personne ne verrait jamais ce qui a été fait pour la 1.3.

- `MARKETING_VERSION = 1.4.0`, `CURRENT_PROJECT_VERSION = 6` aux deux
  configurations de la cible applicative (les cibles de test restent en 1.2.0/3,
  sans effet sur la soumission).
- `AppStoreSubmission/RELEASE_NOTES-1.4.0.md` créé — il manquait : METADATA
  renvoyait à un `RELEASE_NOTES-1.3.0.md` qui n'a jamais existé.
- **Description App Store complétée** (FR + EN) : la 1.4 ajoute une
  fonctionnalité annoncée (importer et partager ses répertoires), la description
  ne pouvait pas rester muette dessus. C'est le premier de ces lots où la
  description elle-même change.

### Aide : un bouton coloré sur l'accueil, et la question du partage traitée

L'aide était enterrée dans les Réglages. Personne ne va chercher un mode
d'emploi là, et l'import/partage de répertoires est précisément la chose qu'on
ne devine pas. Bouton rond **teinté** en tête de la barre d'outils d'accueil,
à gauche de Progression et Réglages — `toolbarCircleButton` prend un `tint`
optionnel, réservé à ce seul bouton pour qu'il se remarque sans le chercher.

Identifiant `openHelpFromHome`, **distinct** du `openHelp` des Réglages : deux
boutons de même nom dans l'arbre d'accessibilité rendraient les tests ambigus.

Nouvelle carte d'aide **« Vos répertoires et le partage »**, qui répond aux
questions qu'un fichier partagé soulève vraiment :
- comment ajouter le sien (PGN, variantes conservées, camp à indiquer) ;
- comment le partager (glissement → Partager, un fichier, aucun compte) ;
- **ce qui est partagé et ce qui ne l'est pas** : le fichier contient les coups
  et les commentaires, jamais la progression ; à l'inverse un répertoire importé
  profite aussitôt de ce qu'on sait déjà des positions ;
- ce que fait la suppression (le fichier part, la progression reste) ;
- qu'un répertoire importé **ne suit pas la synchro iCloud** ;
- **les droits d'auteur** : saisir un livre pour soi est une chose, le
  rediffuser en est une autre. Dit à l'utilisateur, pas seulement dans PROGRESS.

Cartes « Nouveautés », « Ouvertures » et « Puzzles » mises à jour ; traductions
anglaises fournies pour les six chaînes nouvelles ou modifiées.

### Vérifié
- `HelpRouteUITests` couvre les DEUX chemins (accueil et Réglages) ; le nouveau
  test exige que la carte du partage soit là.
- Capture de l'accueil relue : le bouton est bien teinté, à côté de Progression.
- ⚠️ **Piège rencontré** : la copie de build dans `/tmp` avait pris la place du
  répertoire courant, et les `rsync ./ …` sont devenus des no-op silencieux —
  les tests tournaient sur un arbre périmé sans que rien ne l'indique. Toujours
  donner un chemin ABSOLU à `rsync` dans ce dépôt.

## Le plateau injouable en iOS 18 — `.position` contre `.offset` ✅ (2026-08-16)

Signalé sur **iPhone 11 et iPhone XS Max, tous deux en iOS 18** : aucune pièce
ne répond, ni au tap ni au glisser, sur les quatre écrans. Le même iPhone 11
passé en iOS 26 fonctionne parfaitement.

### La cause

Dans `ChessBoardView.piecesLayer`, chaque pièce était placée par
`.position(centerPoint(of:))`.

**`.position` est un modificateur de MISE EN PAGE** : il rend une vue qui occupe
tout l'espace offert et y place l'enfant au point demandé. Chaque pièce
fabriquait donc un conteneur **de la taille du plateau entier**, et ces 32
conteneurs s'empilaient dans le `ForEach`. En iOS 18, c'est le conteneur du
dessus qui intercepte le toucher sur toute la surface.

D'où un symptôme trompeur : « seule la colonne H répond ». Ce n'était pas une
colonne, c'était **une seule pièce** — h2, la dernière de `position.pieces`,
puis h4 une fois le pion avancé. Le journal de diagnostic ne montre jamais
autre chose.

### La correction, et la fausse piste qui a précédé

**Première tentative, insuffisante** : déplacer le geste AVANT `.position`.
Rejetée par l'appareil, symptôme inchangé — le conteneur pleine surface existe
toujours, et c'est lui le problème, pas l'endroit où le geste est accroché.

**Correction retenue** : `.offset` au lieu de `.position`. C'est un
modificateur de RENDU : la vue garde sa taille d'une case et le hit-testing
suit le décalage. Plus aucun conteneur pleine surface. Le `ZStack` étant
aligné `.topLeading`, un demi-carreau est retranché au centre de la case
(`originOffset`).

Deuxième occurrence corrigée dans `BoardCropView` : quatre poignées de
recadrage, même construction, donc la dernière de `Corner.allCases` aurait
répondu sur toute l'image. Jamais signalée faute d'avoir scanné un plateau
depuis un iOS 18.

**Vérifié sur l'appareil** (iPhone XS Max, iOS 18) : le plateau répond
normalement. C'est la seule validation qui compte — voir ci-dessous.

### Deux angles morts de la vérification, comblés

1. **Aucun test ne vérifiait qu'une case est ATTEIGNABLE**, seulement qu'elle
   existe. Or une case injoignable existe dans l'arbre d'accessibilité et
   s'affiche normalement. `BoardHitTestUITests` exige désormais `isHittable`
   sur trois cases, à cinq tailles de texte.
2. **Tous les runtimes installés sont en iOS 26**, alors que la cible de
   déploiement est **iOS 18.0** : deux versions majeures jamais exercées. Ce
   défaut y est totalement invisible, donc aucun test d'interface ne pouvait
   l'attraper ici. `PositionedGestureOrderTests` relit les SOURCES et échoue si
   une vue interactive est placée par `.position` — seule forme de test qui
   tienne sur ce genre de défaut.

*Piège rencontré* : ce garde-fou a d'abord vérifié la mauvaise chose (un ORDRE,
c'est-à-dire précisément la correction qui ne marche pas), et s'est ancré sur
le commentaire qui documentait le piège. Il vérifie maintenant l'USAGE.

**Conséquence pour la soumission** : l'étape TestFlight de
`AppStoreSubmission/CHECKLIST.md` est notée « recommandée ». Elle est
**nécessaire**, et un appareil iOS 18 doit rester dans la boucle tant que la
cible de déploiement n'est pas remontée.

## Stockfish 17.1 remplace la 17 ✅ (2026-08-16)

### Pourquoi la 17.1 et pas la 18

La 18 existe (publiée le 31/01/2026) et l'intégration ne posait aucun problème :
le shim ne touche **aucune API interne** de Stockfish, il redirige l'entrée/
sortie et parle UCI en texte. Changer de version est un remplacement de
sources, pas un portage.

Ce qui a tranché, c'est le **poids du réseau NNUE** :

| version | gros réseau | poids | publiée |
|---|---|---|---|
| 17 (précédente) | `nn-1111cefa1111` | 71 Mo | 06/09/2024 |
| **17.1 (retenue)** | `nn-1c0000000000` | **71 Mo** | 30/03/2025 |
| 18 | `nn-c288c895ea92` | **104 Mo** | 31/01/2026 |

Les ressources pèsent 94 Mo ; la 18 les porterait à ~127 Mo, soit +33 Mo pour
l'utilisateur et un rapprochement net du seuil au-delà duquel iOS exige le
Wi-Fi. Pour une app dont l'argument est « tout est hors ligne », c'est cher.
La 17.1 apporte dix-huit mois de progrès **à taille identique** : le gain est
gratuit, la 18 se paie en mégaoctets.

### Ce qui a changé

- sources vendorisées remplacées par `sf_17.1` (le fichier `history.h` est
  nouveau), point d'entrée renommé `main` → `_main` comme le faisait la
  vendorisation d'origine ;
- `nn-1c0000000000.nnue` remplace `nn-1111cefa1111.nnue` dans
  `ChessLab/Resources/`. Le PETIT réseau est inchangé entre les deux versions ;
- écran Licences, catalogue de traduction, README, `Package.swift` et le test
  de fumée du paquet (qui vérifie la présence du réseau **par son nom**) ;
- version de l'app 1.4.0 → **1.5.0**, build 7.

### Pièges de la reconstruction du binaire d'audit

Deux, tous deux rencontrés :

1. **La cible `net` du Makefile 17.1 appelle `../scripts/net.sh`**, absent de
   l'arbre vendorisé (le script vit à la racine du dépôt amont, pas dans
   `src/`). Les réseaux étant déjà présents, on compile par `make all` sans
   passer par `net`.
2. **`_main.cpp` n'est pas dans les `SRCS`** : un `main.cpp` qui se contente
   d'appeler `_main` ne relie rien. Il doit contenir la fonction ET le pont —
   c'est-à-dire une copie de `_main.cpp` suivie de `int main(...) { return
   _main(...); }`.

Procédure complète dans le README du générateur.

### Vérifié

- `xcodebuild build` vert ; binaire d'audit annonce « Stockfish 17.1 » en UCI ;
- **audit complet des 58 cours rejoué sous 17.1** — changer de moteur change
  les évaluations, une ligne acceptée à 1,40 hier peut franchir le seuil
  aujourd'hui. C'est la vérification qui compte, pas la compilation.

## Le module Finales — construit en un jour sous oracle (17/08)

Demande du matin : « une étude approfondie d'un nouveau module pour les
Finales… un véritable coach ». Étude ET construction le jour même — le
détail des sources et licences est dans le README du générateur ;
l'étude de décision complète vit dans l'historique git (docs/ETUDE-FINALES.md,
supprimée le 18/08 une fois exécutée).

**L'architecture en une phrase** : les finales sont des cours d'ouvertures
qui partent d'une autre position — même JSON, même lecteur, même répétition
espacée, même synchro iCloud ; un champ `kind` les sépare dans le catalogue,
un écran `EndgameListView` les groupe par famille, une tuile « Finales »
les sert.

**La garantie qui change tout** : jusqu'à 7 pièces, la tablebase Syzygy
donne le verdict EXACT. `audit_endgames.py` prouve donc que chaque coup
enseigné préserve son verdict théorique — pas « évalué +2,3 », PROUVÉ.
Douze cours, 300 positions, 152 coups commentés FR+EN, zéro coup faux.

**Cinq dogmes corrigés par l'oracle pendant l'écriture** — la raison d'être
de la méthode « aucune ligne de mémoire » :

1. la racine « évidente » de l'opposition était nulle ;
2. mon premier mat donnait la dame en prise (bis repetita de la Teichmann) ;
3. Philidor : la tour passive tient dans notre position — dogme nuancé ;
4. dame contre pion-fou : le fameux Ka1 « du coin » PERD joué trop tôt, la
   vraie ressource est la promotion-échange c1=D ;
5. la meilleure défense contre la vis sans fin est d1=C, cavalier du
   désespoir — enseigné, réfutation comprise.

## Extension du module Finales — 19 cours, recherche croisée (18/08)

Demande : couvrir un catalogue de référence (~90 finales nommées, calqué sur
un plan de cours type Silman/Dvoretsky) en s'appuyant aussi sur ce qui se
trouve en ligne — Wikipédia, Lichess Practice — pour situer les positions
canoniques, l'oracle tranchant ensuite chaque coup comme toujours.

**Huit cours ajoutés** : Saavedra (sous-promotion tour, 1895 — sourcé
Wikipédia : Fenton-Potter 1875, Barbier, découverte du prêtre espagnol en
mai 1895), Vančura (pion-tour + tour de flanc, 1924), le trébuchet (racine
introuvable dans aucune source en ligne vérifiable — trouvée par recherche
SYSTÉMATIQUE de toutes les paires de rois à distance de cavalier, jusqu'à
isoler les deux seules qui donnent une vraie perte des DEUX côtés selon qui
a le trait), la défense du petit côté (Tarrasch 1906), dame contre tour
(technique de Philidor, 14 coups sans un échec gratuit), le mauvais fou
(fou + pion-tour de la mauvaise couleur — nouvelle famille « fous »), la
coupure verticale du roi.

**Ce que la recherche a corrigé avant même l'oracle** : ma première tentative
de trébuchet, construite de mémoire sur une description approximative
trouvée en ligne, ÉTAIT DÉJÀ FAUSSE géométriquement (les rois avaient une
case de rechange, donc aucune vraie zugzwang) — repérée par la recherche
systématique avant même d'interroger la tablebase. Et la « règle des cinq »
pour la coupure de tour, largement citée en ligne, ne tient pas telle
quelle : un cas limite (4+1=5, censé nulle) s'est révélé gagné à l'oracle.

**Contrainte d'architecture découverte en écrivant** : un cours a UNE seule
racine — un chapitre ne peut pas repartir d'une position aux pièces
différentes (l'autre camp au trait, un fou sur une autre case). Les trois
comparatifs prévus (trébuchet côté noir, grand côté de la défense, bon fou)
sont donc restés en PROSE dans les commentaires plutôt qu'en lignes
rejouables — plus honnête qu'une ligne bricolée qui ne serait pas la même
position.

21 cours de finales au total, 0 problème à l'audit tablebase.

**Suite immédiate (même soir)** : triangulation (Wikipédia, position
Kd5+Pb6+Pc5 vs Kd7+Pb7 — le triangle Ke5-Kd4-Kd5 restitue EXACTEMENT la
position de départ trait inversé, vérifié coup par coup), cavalier + pion
contre cavalier (nouvelle famille « Cavaliers » : pousser tout de suite si
le défenseur est loin, forteresse d'un blocus déjà en place — les deux
vérités contraires que cette finale enseigne), et deux pions liés contre
tour (même paire de pions, un seul rang de différence — gagné en 6e, nulle
en 5e : une tour ne peut viser qu'un pion à la fois).

22 cours de finales, catalogue à 80. 0 problème à l'audit.

**Trois pistes tentées et ABANDONNÉES cette session, honnêtement notées** —
la discipline « aucune ligne de mémoire » vaut aussi dans l'autre sens :
mieux vaut ne rien publier qu'une leçon bricolée sur une contre-vérification
qui ne prouve pas ce qu'elle prétend.

- **Cavalier contre pion-tour en 7e** : le piège découvert en testant — un
  cavalier SEUL contre roi+pion ne peut jamais gagner (matériel insuffisant
  pour mater une fois le pion arrêté), donc « gagné/nul » n'y a pas de sens
  sans une pièce supplémentaire. La vraie question (le cavalier arrive-t-il
  à temps sur les cases clés f8/g5 ?) demande une construction plus soignée
  que je n'ai pas eu le temps de finir proprement.
- **Tour contre fou, bon/mauvais coin** : la théorie du « mauvais coin »
  (roi défenseur dans le coin de la couleur du fou = filets de mat
  spécifiques) est une affaire de TACTIQUE LOCALE — une position déjà
  resserrée — et non une propriété de la position lointaine que j'ai testée
  (qui donne « nulle » des deux côtés, sans surprise : Tour+Roi contre
  Fou+Roi sans pion est un nul classique quel que soit le coin, à cette
  distance). Nécessite de partir d'une position de mat déjà en construction,
  pas d'une position de départ générique.
- **Cases clés (isolé de l'opposition)** : chevauche trop le cours
  « L'opposition » existant pour justifier un cours à part sans une racine
  qui isole vraiment le concept — pas trouvée à temps.

**Quatrième piste tentée et abandonnée** : dame+pion contre dame (position
réelle sourcée, Botvinnik-Ravinsky 1944) — vérifiée à l'oracle, DTM 98
(près de 50 coups de conversion forcée). Trop long pour un chapitre
d'enseignement cohérent sans une position de départ bien plus proche de la
résolution, que je n'ai pas trouvée à temps. Confirme au passage la
réputation de cette finale comme l'une des plus longues à convertir.

**Pion passé protégé** livré à la place : un pion défendu par un autre est
INTOUCHABLE — capturer le protecteur ou seulement s'en approcher perdent de
la même façon, vérifié dans les deux cas.

23 cours de finales, catalogue à 81.

**Découverte méthodologique en cherchant « 3 contre 2 même aile »** : les
finales tour+pions DES DEUX côtés (majorités de pions à plusieurs) dépassent
presque toujours 8 pièces (2 rois + 2 tours + 5 pions et plus), hors de
portée de l'oracle en ligne — vérifié en reproduisant l'échec deux fois de
suite pour écarter un accident réseau. L'app annonce « ≤ 7 pièces » et je
n'ai PAS touché à ce chiffre : une position à 8 pièces a répondu une fois
correctement pendant les tests, mais rien ne garantit que ce comportement
est officiellement supporté par le service Lichess (dont la documentation
publique parle de tables 7 pièces) — mieux vaut une garantie prudente que
respectée à la lettre qu'une promesse optimiste qui casserait un jour sans
prévenir. « 3 contre 2 » et « 4 contre 3 même aile » restent donc HORS de
portée de la preuve tablebase telle quelle ; ils resteraient possibles en
mode « vérifié moteur » (comme la percée l'a été), à décider séparément.

**Cours livré à la place, dans le même esprit et à 7 pièces pile** : deux
pions contre un à l'aile roi. Trouvaille inattendue de l'oracle : GARDER
les tours ne fait que la nulle — la seule voie vers le gain est d'échanger
tout de suite pour laisser la majorité parler en finale de pions pure.
Contre-intuitif, et exactement le genre de leçon qu'une ligne écrite de
mémoire n'aurait jamais surprise.

24 cours de finales, catalogue à 82.

**Tour contre cavalier** livré ensuite : nouvelle famille « Déséquilibres
matériels ». Sans pion, une tour ne bat PAS un cavalier seul — vérifié
depuis plusieurs racines, y compris un cavalier délibérément séparé de son
roi (toujours nulle : les cavaliers ont trop de ressources d'évasion). Utile
autant pour ne pas se battre pour rien que pour ne pas résigner trop tôt.

25 cours de finales, catalogue à 83.

**Cavalier contre deux pions séparés** livré ensuite : même paire de pions
que pour « majorité à l'aile roi », même logique de seuil de rang — sur la
6e, le cavalier ne peut être qu'à un endroit à la fois et un des deux pions
passe toujours ; sur la 5e (un rang plus tôt), posté au centre, il a le
temps de courir d'une aile à l'autre et tient la nulle.

26 cours de finales, catalogue à 84.

**Fous de même couleur : la forteresse** livré ensuite — deux tentatives de
construction ont d'abord échoué (fou noir hors de propos placé sur une case
attaquée par le pion ou le fou blanc, capture gratuite plutôt que vraie
finale théorique), corrigées avant publication. La version retenue : roi
défenseur devant le pion, fou de la même couleur à bonne distance — toute
tentative blanche vérifiée retombe sur une répétition exacte de la position
de départ.

27 cours de finales, catalogue à 85.

**Fou contre deux pions séparés** livré ensuite, même seuil de rang (5e
tient, 6e perd) que la version cavalier — avec une asymétrie propre au fou,
révélée par l'oracle : SEUL h7 gagne à la racine, pas a7, alors même que le
fou d4 semblait couvrir la diagonale des deux ailes. Il ne couvre en réalité
qu'UN sens de fuite à la fois — la portée en ligne droite d'un fou n'est
pas une omniscience.

28 cours de finales, catalogue à 86.

**Tour contre fou, deuxième tentative** — repris une deuxième fois après un
premier abandon documenté plus haut. Nouvelle racine plus resserrée
(6kb/8/6K1/8/8/8/8/3R4 b) : l'oracle donne bien « perte » pour les noirs,
mais `derive_optimal.py` révèle pourquoi — le roi noir est déjà acculé
contre le roi blanc adjacent (g6), et la ligne optimale force le roi à
abandonner son fou pour que la tour le CAPTURE gratuitement (`Rxh8`). C'est
le même défaut de construction (pièce non défendue) déjà attrapé deux fois
sur les fous de même couleur cette session — pas une démonstration du
« mauvais coin ». Cours livré quand même, mais SANS la théorie du coin :
juste ce qui est solidement prouvé, à savoir que tour contre fou seul, sans
pion et roi défenseur groupé, est nulle — comme cavalier contre tour. La
nuance de couleur de coin reste hors de portée de cette méthode ; il
faudrait une position où le coin change le verdict à matériel et
distances égales, pas une position déjà quasi tranchée par ailleurs.

29 cours de finales, catalogue à 87.

**Fou contre cavalier** ouvert ensuite — première entrée de la catégorie que
l'utilisateur avait nommée à part dans sa liste. Sourcée cette fois-ci via
Wikipédia (page « Finale fou contre cavalier ») plutôt que construite à
tâtons : l'étude de Hall (1988), fou + pion contre cavalier, 5 pièces,
dtm 49 à la racine — largement dans la fenêtre tablebase. Le fou n'a rien à
prouver par la force ; il maneuvre sur la longue diagonale pendant que le roi
garde le pion, jusqu'à mettre le cavalier en zugzwang. Bonus offert par
l'oracle lui-même : DEUX pièges naturels ressortent de l'exploration
(`Kxe8??` gagne le cavalier mais abandonne la garde du pion — repris aussitôt ;
`c7??` pousse trop tôt, le cavalier veille depuis e8 et le reprend), tous
deux vérifiés comme changeant réellement le verdict (`role: "trap"`, aucun
`fake_trap` signalé par `audit_endgames.py`). Rangé dans la famille « fous »
plutôt que dans une nouvelle famille dédiée — une seule entrée ne justifie
pas encore sa propre catégorie côté Swift.

30 cours de finales, catalogue à 88.

**Fou contre cavalier, deuxième pièce** livrée dans la foulée — même page
Wikipédia, l'étude de Sam Loyd (1860) cette fois : pion noir à un pas de la
promotion, cavalier en soutien, fou blanc seul en face. L'oracle est
catégorique — TOUTE retraite de fou perd (`Bg2??`, la plus naturelle,
retombe en perte en 16 coups), seul un sacrifice sur la case même de
promotion (`Bh1!!`) tient la nulle : le roi noir n'a d'autre choix que de
reprendre, et se retrouve emmuré dans le coin derrière son propre pion — le
pion ne peut plus jamais avancer. Le roi blanc navigue ensuite entre f1 et
f2 en forteresse permanente. Deuxième cours vérifié de la même page
source dans la même soirée.

31 cours de finales, catalogue à 89.

**Tour derrière le pion passé (règle de Tarrasch)** livré ensuite — item qui
avait déjà résisté une fois (ma première tentative gagnait quel que soit
l'emplacement de la tour, matériel trop écrasant pour que le placement
change quoi que ce soit). Deux racines artificielles ultérieures (pion
seul, tours et rois loin de l'action) ont donné la même réponse plate :
nulle quel que soit le coup, distance trop grande pour que le placement
compte. Résolu en source, pas en construction : Wikipédia (page « Tarrasch
rule ») cite Short-Yusupov 1984 comme exception classique, et l'oracle
confirme au signe près — racine à 6 pièces, dtm 75, `Rh3` (la case « derrière
le pion », donc la règle appliquée à la lettre) ne fait que la nulle, seul
`Rf7` gagne. La leçon n'est pas la règle elle-même mais sa limite : il faut
d'abord couper le roi adverse sur la 7e rangée, la tour ne rejoint la bonne
case qu'ensuite, une fois le terrain gagné. Sourcé plutôt qu'inventé, pour
la deuxième fois du chantier « fou contre cavalier » — la discipline
web+oracle commence à payer sur les items qui avaient résisté à la pure
construction.

32 cours de finales, catalogue à 90.

**Tour contre fou, troisième tentative — enfin la vraie théorie du coin**
livrée dans la foulée. Les deux essais précédents avaient buté sur des
pièces non défendues (documenté deux fois plus haut) ; cette fois la
position vient directement de Wikipédia (page « Fortress (chess) »,
exemple « rook vs bishop fortress ») plutôt que d'une construction maison :
roi et fou noirs dans le coin de la couleur OPPOSÉE à celle du fou. L'oracle
confirme quelque chose de plus fort qu'une simple nulle — la tour ne peut
MÊME PAS gagner le fou par la force : `Rxg8+?? Kxg8` rend la tour dans la
foulée (le roi blanc sur g6 ne défend pas g8), et une ligne complète
(`Rc1 Be6 Rc8+ Bg8`) revient à la lettre sur la position de départ, boucle
parfaite. Bonus trouvé en explorant : `Kh6??` livre un pat immédiat — le
fou, cloué sur la 8e rangée entre la tour et son propre roi, ne peut plus
bouger du tout. La leçon que les deux tentatives précédentes cherchaient
sans la trouver.

33 cours de finales, catalogue à 91.

**Point de contrôle** : audit complet (`audit_endgames.py` sans `--only`)
relancé sur les 33 cours de finales après cette rafale d'ajouts — 974
requêtes tablebase, toutes en cache, 0 nouvelle régression. Le seul signal
est une note informative déjà connue sur `eg-queen-vs-bishop-pawn`
(défense sous-optimale volontairement montrée), pas une erreur.

**Dame contre tour ET pion** livrée ensuite — sourcée Müller & Lamprecht
(« Fundamental Chess Endings ») via Wikipédia (« Queen versus rook
endgame ») plutôt qu'inventée : un pion ordinaire (pas un pion-tour) en 2e
rangée, collé au roi et à la tour, ferme une forteresse que la dame seule ne
perce jamais tant que la tour navette sur la 3e rangée. Racine à 5 pièces,
ligne source (`1.Rg3 Ke4 2.Re3+ Kf4 3.Rg3 Qc6+ 4.Kg1`) confirmée coup par
coup. Piège naturel trouvé en explorant : quitter la 3e rangée pour activer
la tour (`Re6??`) l'abandonne sans défense, `Qxe6` la croque aussitôt.

34 cours de finales, catalogue à 92.

**Dame contre pion-tour en 7e** livrée ensuite — l'exception du coin,
sourcée Wikipédia (« Queen versus pawn endgame ») : un pion CENTRAL en 2e
rangée perd toujours contre la dame seule, mais un pion-TOUR ne perd pas
forcément si le roi attaquant est trop loin. Racine à 4 pièces : le roi
noir navette entre b1 et b2 pendant que la dame donne échec depuis d2 puis
d1, et la ligne source revient à la lettre sur une position déjà vue deux
coups plus tôt — boucle parfaite, vérifiée coup par coup. Piège naturel :
prendre le pion avec échec (`Qxa2+??`) semble gagner du matériel, mais la
dame atterrit à côté du roi noir sans que son propre roi (encore loin) ne
la défende — `Kxa2` la reprend gratuitement.

35 cours de finales, catalogue à 93.

**Tour et mauvais pion-tour contre fou** livrée ensuite — sourcée Fine &
Benko (Basic Chess Endings, position de Berger citée par Wikipédia
« Wrong rook pawn ») : la forteresse du mauvais pion-tour, déjà connue
contre un fou seul (`eg-wrong-bishop`), résiste identique même quand
l'attaquant a une TOUR ENTIÈRE de plus. Racine à 5 pièces. Trouvaille en
explorant : offrir carrément la tour (`Rh7+`, non défendue) et la voir
prise (`Kxh7`) transpose EXACTEMENT dans la forteresse du fou seul déjà
au catalogue — un lien concret entre deux cours plutôt qu'une coïncidence.

36 cours de finales, catalogue à 94.

**Cases conjuguées** livrée ensuite — sourcée France-Échecs (article
« Cases conjuguées »), qui propose une miniature à 6 paires de cases
correspondantes. Racine à 5 pièces : le roi blanc joue Kb3, et sur les SEPT
coups noirs légaux, un seul (Kc5) tient la nulle — les six autres perdent,
certains en plus de quarante coups sans rien qui le trahisse sur
l'échiquier. C'est la même idée que l'opposition simple déjà couverte
(`eg-opposition`), mais généralisée : au lieu d'une seule case en face,
chaque case du roi attaquant a SA case de réponse propre, et une seule.
Piège construit à partir de l'exploration elle-même : Kc6, aussi
raisonnable que Kc5 en apparence, perd après Kc4.

37 cours de finales, catalogue à 95.

**Étude de Grigoriev** livrée ensuite — sourcée via l'analyse d'Elkies
(« Endgame Explorations 9 »), une étude primée à La Stratégie. Racine à
5 pièces, mais dtm 61 : la technique la plus longue vérifiée dans tout le
module cette session. Quatre coups blancs se ressemblent à la racine
(pousser le pion e de deux façons, ranger le roi sur g2 ou h2) — un SEUL
(`Kg3`) gagne, les trois autres ne font que la nulle. Piège construit à
partir de l'exploration : pousser `e4+` tout de suite semble créer un pion
passé sans attendre, mais le roi noir le reprend aussitôt (`Kxe4`) et toute
la marche de roi qui faisait le travail disparaît avec lui.

38 cours de finales, catalogue à 96.

**Tour et fou contre tour** livrée ensuite — première entrée des
« déséquilibres matériels » lourds, sourcée Wikipédia (« Rook and bishop
versus rook endgame »), position de Szén : contrairement à l'intuition
« matériel en plus = gagnant », la tour et le fou ne gagnent PAS toujours
contre une tour seule. Racine à 5 pièces, position réellement tenue quatre
fois de suite dans une vraie partie (Pintér-Razuvayev, 1982) avant la
nulle. Piège trouvé en explorant : après la manœuvre correcte du fou noir,
la tour blanche a plusieurs cases sûres (e7, etc.) mais une case tout aussi
plausible (`Ra7??`) abandonne la colonne b — `Rb1#`, mat immédiat en un
coup. La marge entre forteresse et mat tenait à une seule case de tour.

39 cours de finales, catalogue à 97.

**Tour et cavalier contre tour** livrée en miroir immédiat — là où le fou
l'emporte en général sur une tour seule (avec des exceptions comme Szén),
le cavalier ne l'emporte PRESQUE JAMAIS : il manque la portée nécessaire
pour aider sa tour à construire un filet de mat. Vérifié depuis une
position neutre : les VINGT coups blancs légaux à la racine retombent tous
sur la même nulle — y compris une ligne où les noirs gagnent le cavalier
purement et simplement (`Rxa4`), sans que le résultat change d'un iota. Pas
de piège trouvé cette fois : la position est trop uniformément nulle pour
qu'aucun coup blanc ne dégrade quoi que ce soit — cours à un seul chapitre,
comme les autres forteresses « pièce en plus qui ne suffit pas ».

40 cours de finales, catalogue à 98.

**Point de contrôle final de cette rafale** : audit complet relancé
(`audit_endgames.py` sans `--only`) — 1046 requêtes tablebase, toutes en
cache, 0 régression sur les 40 cours.

**Forteresse de Karstedt (1903, dame contre fou+cavalier) tentée et
abandonnée** : la structure générale est documentée (fou b2, cavalier d4,
barrage sur a3-b3-c3-c2-c1, roi défenseur au coin), mais aucune source
trouvée ne donne le placement EXACT des pièces attaquantes ni la défense
du cavalier. Une reconstruction à vue (roi et dame blancs placés à
l'estime) a été testée à l'oracle — et perd en 13 coups, `Qxd4+` croquant
le cavalier non défendu tout net. Même défaut de construction déjà
rencontré deux fois cette session (pièce hors de propos, non défendue) —
mais cette fois sans savoir SI la vraie position source évite ce piège ou
si ma reconstruction était simplement incomplète. Abandonné plutôt que
publié à faible confiance.

**Dame contre deux tours** livrée ensuite — construite (pas sourcée sur une
partie précise) à partir du principe général documenté (Dvoretsky, Fine &
Benko) : sans pion, deux tours coordonnées tiennent la nulle contre la
dame, À CONDITION de se défendre mutuellement. Racine à 4 pièces, testée
neutre : confirmé à l'oracle. Trouvaille de construction, pas cherchée au
départ : `Kf8` (rester sur la 8e rangée) bloque la coordination des deux
tours et perd une tour gratuitement à `Qxa8+` ; `Kg7` (quitter la rangée)
la préserve. Et si la dame croque quand même une fois la rangée dégagée
(`Qxa8??`), l'autre tour reprend aussitôt (`Rxa8`) — la coordination paie
exactement comme annoncé.

41 cours de finales, catalogue à 99.

**Dame contre tour et fou** livrée ensuite — même principe de construction
que dame-contre-deux-tours : sans pion, la dame l'emporte en général contre
tour+fou en séparant les pièces noires par échecs à distance jusqu'au
zugzwang, sauf si roi-tour-fou restent groupés en triangle, chacun
protégeant un autre. Racine à 5 pièces, testée neutre, confirmée à l'oracle.
Piège trouvé en explorant : une case de roi qui semble tout aussi défendable
que la bonne (`Ke6??` au lieu de `Kf8`) abandonne la protection de la tour
— deux échecs plus tard, `Qxg8` la croque hors de portée.

**Le catalogue franchit les 100 cours** (42 finales + 58 ouvertures).

**Dame contre tour et cavalier** livrée en miroir immédiat — même
construction que contre tour et fou. Fait notable : ce triangle-ci est
encore PLUS solide. Depuis la racine, aucune tentative blanche testée par
l'oracle ne trouve de faille, et après l'échec initial, les SIX réponses
noires possibles tiennent toutes la nulle (contre une seule pour le fou,
où `Ke6??` perdait). Le cavalier couvre des cases que le fou, prisonnier
d'une seule couleur, ne peut jamais défendre — cours à un seul chapitre,
aucun piège authentique trouvé malgré la recherche.

43 cours de finales, catalogue à 101.

**Défense frontale** livrée ensuite — sourcée Wikipédia (« Rook and pawn
versus rook endgame ») : quand le roi défenseur est coupé du pion et ne
peut rejoindre la position de Philidor à temps, la tour se contente
d'attendre sur la rangée de promotion, peu importe la colonne, prête à
croquer le pion dès son arrivée. Racine à 5 pièces. Ligne complète et
satisfaisante : la tour quitte même la rangée pour harceler le pion par le
flanc en chemin (`Rc6`), puis revient juste à temps (`Rc8`) avant la
promotion. Piège trouvé en explorant : l'échec par-derrière — souvent LA
ressource clé dans ces finales — donné trop tôt (`Rb3+??`) ne fait
qu'aider le roi blanc à se rapprocher de son pion.

44 cours de finales, catalogue à 102.

**Tour et pion contre cavalier** livrée ensuite — recherches infructueuses
sur « majorité paralysée » (concept surtout illustré avec de nombreux
pions, hors de portée tablebase, plus proche du thème stratégique que de
la ligne forcée) et sur un exemple canonique d'échec perpétuel en dame+pion
contre dame (aucune position isolée trouvée, seulement des parties
complètes). Construite à la place, en position neutre comme les autres
comparaisons de matériel de la session : un pion de plus suffit très
généralement à la tour pour l'emporter sur un cavalier seul — vérifié,
victoire dans toutes les tentatives testées à la racine.

45 cours de finales, catalogue à 103.

**Recherches en parallèle** (première fois cette session, à la demande de
l'utilisateur) : quatre requêtes web lancées simultanément plutôt qu'une
par une. Deux pistes mortes de plus (Centurini et « cavalier deux ailes » :
principes généraux trouvés, aucune position exacte sourcée ; Lasker-
Tarrasch 1914 : référence introuvable sur la page Wikipédia de Lasker).
Une piste payante : « tour seule contre pions liés » cite un seuil précis
— 6e rangée bat la tour, 5e rangée la tour tient — repris directement du
principe plutôt que d'une partie précise, et confirmé à l'oracle à
condition d'égaliser l'implication des DEUX rois (mon premier essai, roi
défenseur proche de l'action et roi attaquant loin, faussait la
comparaison : il faut les deux rois symétriquement hors-jeu pour isoler
l'effet du rang). **Pions liés en 6e contre tour** livrée : le seuil se
vérifie à la lettre, et perdre un seul tempo (`Kc1??` avant de pousser)
suffit à laisser le roi noir revenir à temps et inverser tout le verdict.

**Incident mineur, corrigé** : une insertion de localisation a ponctuellement
produit un diff de 638 lignes au lieu des ~16 attendues (flûté, cause non
identifiée — probablement une écriture concurrente pendant que le fichier
était relu). Détecté immédiatement par la vérification systématique du
diff après chaque édition, annulé (`git checkout`), refait à l'identique :
diff propre au deuxième essai. La discipline de vérification a fonctionné
comme prévu.

46 cours de finales, catalogue à 104.

**Cavalier ou fou : lequel prendre ?** livrée ensuite — sourcée ChessBase
(« The Wrong Bishop »), une position-test trouvée en cherchant un exemple
de manœuvre de diversion sourcée : le roi blanc touche à la fois le
cavalier et le fou noirs, mais ne peut en prendre qu'un. Racine à 5 pièces.
Contre-intuitif : prendre le fou — de la bonne couleur pour la case de
promotion h8, ce qui semblait favoriser les noirs — PERD, alors que prendre
le cavalier tient la nulle. La raison n'est pas la couleur de la pièce
laissée en jeu mais la vitesse du roi blanc : après `Kxc5`, il colle sa
route à celle du pion et arrive PILE à temps pour croquer la dame la
seconde où elle apparaît (`Kxh1`) ; après `Kxe5`, le cavalier gagne un
tempo par échec (`Ne6+`) que le roi ne rattrape jamais.

47 cours de finales, catalogue à 105.

**Deux cavaliers contre un pion** livrée ensuite — sourcée Rév. Horatio
Bolton (1840), trouvée en cherchant la ligne de Troitzky. Deux cavaliers
seuls ne peuvent JAMAIS forcer mat contre un roi nu — le pat guette
toujours — mais un pion adverse fournit exactement le coup de réserve qui
évite ce pat au bon moment, et le mat redevient possible. Racine à
5 pièces, dtm 17 jusqu'au mat effectif (`Nf2#`), vérifié coup par coup.
Piège trouvé en explorant : avancer le roi blanc sans avoir d'abord
bloqué le pion (`Ke6??`) laisse au roi noir toute liberté de s'échapper
vers lui — la nulle tient.

48 cours de finales, catalogue à 106.

**La forteresse de Karstedt, enfin résolue** — troisième tentative sur cet
item après deux échecs déjà documentés plus haut (aucune source ne donnait
le placement exact, une reconstruction à l'estime perdait en 13 coups).
Une nouvelle recherche a fini par livrer les trois cases exactes du trio
défenseur : roi h1, fou g2, cavalier e4 — la SEULE configuration connue où
roi+fou+cavalier, sans un seul pion, tient la nulle contre une dame seule.
Testée à l'oracle avec une dame attaquante placée à distance raisonnable
(b5) : confirmé, racine à 5 pièces, draw. La clé structurelle : le fou sur
g2 garde à la fois le roi ET le cavalier posté juste devant lui sur e4 —
le bouger (`Bf1??`) abandonne le cavalier, `Qxe4` le croque aussitôt et la
forteresse s'effondre.

49 cours de finales, catalogue à 107.

**Rythme accéléré à la demande de l'utilisateur** : recherche et
construction groupées avant le cycle de build/test (le vrai goulot,
~7-8 min par cycle), plutôt qu'un cycle complet par cours.

**Couper avant de pousser** livrée ensuite — sourcée Chéron. Racine à
5 pièces, dtm 89 (technique complète très longue), mais la décision qui
compte tient en un seul coup : couper le roi noir sur la 3e rangée
(`Re3`) AVANT de songer à avancer le pion. Piège trouvé en explorant :
pousser tout de suite (`c4??`) sans couper laisse le pion sans défense,
repris avec échec. Ligne principale raccourcie honnêtement : après
`Rxc3+ Kxc3`, la position retombe sur la finale élémentaire roi+tour
contre roi déjà connue, pas la peine de rejouer les 89 coups.

50 cours de finales, catalogue à 108.

**Tour et deux pions liés contre tour** livrée dans la foulée, deuxième
cours du même cycle groupé — construction générique (comme les autres
comparaisons de matériel de la session) plutôt que sourcée : deux pions
passés et liés déjà avancés (5e/6e rangée) battent une tour seule, quasi
sans exception. Vérifié depuis une position neutre à 6 pièces : la
plupart des dix coups blancs testés à la racine gagnent — la tour adverse
ne peut jamais surveiller les deux cases de promotion à la fois. Tentative
parallèle sur « cavalier + 2 pions contre tour » abandonnée : deux
constructions différentes (pions en 5e, pions liés avancés) sont
retombées sur une simple nulle, sans le récit tranché espéré.

51 cours de finales, catalogue à 109.

**Centurini, enfin résolu — quatrième tentative.** Le principe manquait
toujours d'une position exacte après trois essais infructueux, jusqu'à ce
qu'une recherche finisse par livrer la règle précise du maître italien :
« nulle si le roi défenseur atteint, devant le pion, une case qui N'EST
PAS de la couleur du fou ». Construite à partir de cette règle plutôt que
d'un diagramme copié — et un premier essai s'est révélé faux (fou et pion
contre roi NU au lieu de fou et pion contre FOU de même couleur, gagné
haut la main par les blancs) avant de corriger en ajoutant le second fou.
Racine à 5 pièces, confirmée nulle. Piège trouvé en explorant : un repli
qui semble prudent (`Ka8??`) abandonne justement LA case qui faisait toute
la forteresse.

**Incident JSON, corrigé** : l'entrée servant de repère pour cette
insertion se trouvait être la toute dernière du fichier (sans virgule de
fin) — l'insertion standard y a cassé le JSON deux fois de suite (virgule
manquante, puis virgule surnuméraire). Détecté immédiatement par la
vérification systématique, corrigé à la main les deux fois avant de
continuer. La discipline de vérification a encore fonctionné comme prévu.

52 cours de finales, catalogue à 110.

**La défense Cochrane** livrée dans la foulée, deuxième cours du même
cycle groupé — sourcée John Cochrane : contre tour et fou, la tour
défenseur cloue le fou adverse contre son propre roi sur une colonne
centrale, rois à bonne distance. Racine à 5 pièces. Trouvaille amusante en
construisant : la tour noire peut même croquer la tour blanche pour
simplifier (`Rxa1`) sans rien perdre — tour contre fou seul est déjà
connu nul (`eg-rook-vs-bishop`), un deuxième lien concret entre deux cours
de la session. Piège trouvé en explorant : lâcher la colonne d pour
chasser la tour blanche (`Rb1??`) libère le fou du clouage, et la tour
noire tombe aussitôt avec échec.

53 cours de finales, catalogue à 111.

**La défense de la 2e rangée** livrée dans la foulée, troisième cours du
même cycle groupé — deuxième grande méthode connue contre tour et fou, à
côté du clouage Cochrane déjà livré : la tour défenseur reste sur sa
propre 7e rangée, hors de portée du roi adverse, sans jamais avoir besoin
d'aller y voir de plus près. Racine à 5 pièces, construite sur le principe
documenté (Atalik-Norri 1997, van Wely-Carlsen 2007 cités comme exemples
pratiques) plutôt que sur l'une de ces parties précises. Piège trouvé en
explorant : quitter la rangée pour approcher le roi blanc (`Rd7??`) amène
la tour directement à portée — `Kxd7` la croque sans effort.

54 cours de finales, catalogue à 112.

**Le pion passé éloigné** livrée dans la foulée, quatrième cours du même
cycle groupé — technique classique du leurre : un pion passé isolé loin
du reste force le roi adverse à s'en occuper seul, pendant que l'autre
roi traverse tout l'échiquier. Racine à 7 pièces — première fois cette
session que l'oracle renvoie un verdict sans DTM numérique (`dtm: None`)
alors que le verdict lui-même reste fiable ; `verify_line.py` continue de
fonctionner normalement puisqu'il ne dépend que de la préservation du
verdict, pas du chiffre. Aucun piège trouvé cette fois : la position est
robuste, cours à un seul chapitre.

55 cours de finales, catalogue à 113.

**Pions sur les deux ailes contre cavalier** livrée ensuite — item de la
liste initiale enfin traité, construit sur le principe documenté (le
cavalier a une portée trop courte pour défendre les deux ailes à la fois)
plutôt que sourcé sur une partie précise. Piste parallèle explorée sans
succès : la manœuvre de Prokeš (tour qui tient la nulle contre deux pions
liés avancés par un sacrifice de qualité) — aucune source ne donne la
position exacte de l'étude de 1939, et une reconstruction à l'estime
n'a pas été tentée pour éviter un nouveau risque de construction erronée
comme documenté plusieurs fois cette session. Racine à 5 pièces : un pion
de chaque aile, déjà avancés, contre un cavalier seul — pousser
immédiatement gagne, perdre un tempo (`Kd1??`) laisse au cavalier le temps
de croquer l'un des deux pions et tenir la nulle avec l'autre.

56 cours de finales, catalogue à 114.

**La faille de la règle de Bahr** livrée ensuite — sourcée ARVES
(Francesco Santelli, « The flaw in Bahr's rule »), dans le même esprit que
Neustadtl-Porges documenté plus haut : une règle classique corrigée par
l'oracle. La règle de Bahr prétend que trois conditions réunies (pions-
tours bloqués, roi attaquant collé à son pion, roi défenseur devant)
suffisent à gagner. Racine à 5 pièces : confirmé faux — nulle, les blancs
au trait. Fait vérifié en prime, non joué mais noté : la MÊME position
avec les NOIRS au trait est gagnée pour les blancs (« manœuvre de John
Crum ») — un cas net où le trait seul renverse tout le verdict, sans
qu'aucune des trois conditions de la règle ne change.

57 cours de finales, catalogue à 115.

**La forteresse de Horwitz-Kling qui n'existe pas** livrée dans la foulée
— deuxième « règle corrigée par tablebase » de la session : Horwitz et
Kling pensaient en 1851 qu'une forteresse défensive existait pour deux
fous contre cavalier. Il n'y en a pas — gain général, confirmé jusqu'à
78 coups. Racine à 5 pièces, mais dtm 127 : la technique la plus longue
rencontrée cette session, largement au-delà de ce qu'une ligne complète
pourrait montrer utilement. Cours délibérément réduit au strict minimum —
seulement la décision de départ (`Kd3!` gagne, `Bc2??` ne fait que la
nulle) — plutôt que de forcer une ligne de 63 coups qui n'apprendrait
rien de plus que « suivez l'oracle ».

58 cours de finales, catalogue à 116.

**Découverte de workflow** : le commit de ce lot a poussé un diff de
`Localizable.xcstrings` bien plus large que prévu (1795 lignes touchées au
lieu des ~32 attendues pour 2 cours). Vérifié après coup : JSON valide,
tout le contenu intact — c'est une reformulation (ré-indentation, ré-
ordonnancement) sans perte, pas une corruption. Déjà vu une fois plus tôt
(incident noté alors comme un « flûte » isolé) ; cette deuxième occurrence,
survenue APRÈS mon édition propre mais AVANT le commit — donc pendant l'un
des `xcodebuild build` du cycle — suggère que ce n'est pas aléatoire :
Xcode reformate probablement le catalogue de chaînes pendant la
compilation elle-même. Contre-mesure adoptée : vérifier le diff de ce
fichier juste avant chaque commit, pas seulement juste après l'édition.

**Reste à faire** (mis à jour, 58 cours de finales, catalogue à 116) :
environ 32 items du catalogue de référence restent à couvrir.

- **Cases conjuguées et Grigoriev sont FAITS** (`eg-corresponding-squares`,
  `eg-grigoriev-king-race`) — retirés de la liste « à sourcer ». Centurini
  reste ouvert (fou contre pions passés dans les finales de fous, jamais
  nommément sourcé — `same_color_bishops` couvre une forteresse générique
  du même esprit, sans porter le nom).
- **Lasker (Lasker-Reichhelm, Fine #70) tenté et bloqué** : position source
  exacte trouvée (`8/k7/3p4/p2P1p2/P2P1P2/8/8/K7`), mais 8 pièces réparties
  sur les DEUX ailes — l'oracle en ligne répond `unknown`, le même plafond
  déjà rencontré cette session sur les configurations tour+pions à 9 pièces.
  Resterait possible en mode « vérifié moteur » (comme la percée), pas en
  vérité tablebase telle quelle.
- **Fou contre cavalier, les deux derniers items** (Fischer-Taimanov 1971,
  Karpov-Kasparov 1984) tentés et reportés : ce sont des parties réelles à
  matériel TOUR+fou/cavalier (pas fou/cavalier seuls), sur des dizaines de
  coups avec de nombreux pions des deux ailes — bien au-delà de la fenêtre
  tablebase, et le risque de mal transcrire une position précise à partir
  d'une partie complète est réel. Les 2 items déjà livrés (Hall, Sam Loyd)
  couvrent le cœur de la théorie fou-contre-cavalier ; ces deux-là
  resteraient pour une session dédiée à l'analyse de parties complètes.
- **Tour et fou contre tour, et tour et cavalier contre tour sont FAITS**
  (`eg-rook-vs-rook-and-bishop`, position de Szén ; `eg-rook-vs-rook-and-knight`)
  — retirés de la liste. Le reste des « déséquilibres matériels » (dame
  contre tour+fou/cavalier, dame contre deux pièces mineures…) reste la
  famille la moins couverte après « fou contre cavalier ».
- Les thèmes transversaux (zugzwang, forteresses, principe des deux
  faiblesses…) seront traités en galeries multi-positions plutôt qu'en une
  racine chacun — format encore à concevoir, rien de commencé.

Et toujours : le mat aux deux fous, et — v2 — l'entraînement libre arbitré
par tablebase, embarquée en sous-sélection WDL (~15-25 Mo, lisible
nativement par Stockfish via SyzygyPath) plutôt que les tables complètes
(940 Mo, écartées).

## Dix tests rouges que la campagne de contenu avait masqués (16/08)

Première suite complète depuis la fusion du menu Analyser : **10 échecs**.
Neuf venaient de ce chantier-là — « Position FEN » et « Coller un PGN » ont
fusionné en « Analyser PGN / FEN », et cinq classes de tests cherchaient
encore les anciens boutons. La régression avait plusieurs heures.

**Pourquoi elle est passée inaperçue.** La campagne de contenu ne touche pas
au code Swift, donc je n'ai pas relancé la suite entre les commits. Le
raisonnement est faux : ce n'est pas le commit courant qui casse quelque
chose, c'est le précédent qui n'a jamais été vérifié. Un changement de
libellé VISIBLE doit déclencher un passage sur les tests d'interface, seuls à
viser les libellés par leur texte.

**Le dixième échec était d'une autre nature** — et j'ai d'abord accusé la
mauvaise cause. Le bandeau coach en paysage expirait à 90 s ; comme je venais
de mesurer un affinage ×3, j'ai soupçonné mon propre ralentissement. Mesure
isolée : le bandeau apparaît en **5 s**. L'échec ne survenait que sous la
charge des cinq classes enchaînées.

Le vrai défaut était l'ordre des instructions : sur iPhone ce test se saute
faute d'iPad, mais il attendait d'abord le bandeau jusqu'à 90 s pour le jeter
ensuite. **Une mesure qui n'aura pas lieu ne doit pas pouvoir échouer.** La
condition de saut est passée avant l'attente ; aucune couverture perdue (le
test frère vérifie le bandeau en portrait), et la classe est passée de 402 s à
312 s.

État après correction : **560 tests unitaires en 90 suites + 63 tests
d'interface, 0 échec.**

## Campagne de contenu — les 58 cours ✅ (2026-08-16)

Réponse au point 2 de Nils (« l'architecture est très bonne mais le contenu est
plutôt mauvais »), menée sur la base du classement de `coverage.py`.

| | Avant | Après |
|---|---|---|
| Positions | 3 191 | **4 074** (+883) |
| Coups commentés | 484 | **759** (+275) |
| Cours retravaillés | — | **58 / 58** |

### Ce que le classement a révélé, et qu'aucune relecture n'aurait trouvé

Le travail cours par cours n'aurait jamais montré ces motifs : ils
n'apparaissent qu'en comparant les 58 entre eux.

1. **Tous les répertoires NOIRS contre 1.d4 ont le même trou n°1 : la
   London.** Est-Indienne, Grünfeld, Nimzo, Benoni, Benko, Tarrasch, Albin,
   Tchigorine, Bogo, Budapest, Est-Indienne ancienne — chacun suppose que les
   Blancs jouent 2.c4. En club, ils jouent 2.Ff4 une partie sur six, et 2.Cf3
   autant. L'élève sortait de son répertoire **au deuxième coup**, avant que
   l'ouverture qu'il a choisie ait pu exister.

2. **Tous les répertoires 1.e4 e5 ignoraient 2…d6 (Philidor) et 2…Cf6
   (Petroff).** Ce ne sont pas des variantes oubliées mais des ENTRÉES :
   l'adversaire refuse le débat au deuxième coup.

3. **Toutes les Siciliennes ignoraient les sorties précoces du fou en c4**,
   qui empêchent justement la Sicilienne ouverte dont elles dépendent.

4. **Les trois cours frères du Gambit Dame** — accepté, refusé, Slave —
   ignoraient chacun les réponses que les deux autres traitent.

### Deux natures de contenu écrites

- **Des variantes** là où l'ouverture survit : la Tarrasch garde …c5 contre la
  London, la Nimzo garde …Db6 (même esprit : gêner avant de développer).
- **Des mises au point de PORTÉE** là où elle n'existe plus : sans c4, le
  Budapest, le Benko et l'Albin ne sont pas des gambits mais des pions donnés.
  Le Stafford suppose 3.Cxe5, le Letton 2.Cf3, l'Éléphant 3.exd5. Le dire vaut
  mieux que laisser chercher un coup qui n'a plus de sens.

### L'arbitrage qui a gouverné toute la campagne

**Le meilleur coup du moteur n'est pas toujours le bon coup du RÉPERTOIRE.**
Sur la London, la Roi-Indienne d'attaque, le Colle, la Veresov, la Torre,
Stockfish propose systématiquement le coup qui QUITTE le système — 3.e4 au
lieu de 3.Ff4, d4 au lieu de d3, c4 au lieu de e3. À chaque fois c'est
objectivement le meilleur coup, et à chaque fois c'est la mauvaise réponse
pour un élève venu apprendre ce système précis. Suivre le moteur aveuglément
aurait produit des répertoires qui se contredisent : irréprochables et
inutilisables. Le raisonnement est écrit dans les fichiers, pas seulement dans
les commits, pour que personne ne « corrige » plus tard en relançant Stockfish.

### Une gaffe enseignée trouvée en chemin

Sicilienne classique, ligne Boleslavsky : après 10.Cd5 le cours enseignait
10…Fxd5 (perte 1,65) là où 10…Cxe4 gagne un pion. Elle avait passé l'audit
complet du soir — arête « suspecte » dont la contre-mesure à profondeur 24
avait tranché d'un cheveu — et n'est ressortie que sur un lot plus petit, où
l'ordre d'exploration change. Cas limite, mais un cas limite à 1,65 sur un
seuil de 1,50 reste un coup qui perd un pion et demi, présenté comme la ligne
principale. C'est exactement le défaut que le testeur avait relevé en août.

### Ce qui n'a PAS changé, et qu'il faut dire

Le ratio arêtes/positions reste à 0,99. Les cours sont mieux reliés et n'ont
plus de trou béant, mais ils demeurent des LIGNES, pas des arbres touffus. Le
reproche de fond de Nils — « je connais dix fois plus de coups théoriques que
ceux montrés » — n'est levé qu'en partie. Ce qui a réellement changé, c'est
qu'on ne sort plus du répertoire au deuxième coup.

## Reste à faire, par ordre de valeur (état au 2026-08-15)

Classé par rapport valeur/risque, pas par ordre des prompts d'origine. Chaque
point restant a été **écarté sciemment**, pas oublié — la raison est donnée.

### ✅ 1 à 4 — traités le 15/08/2026

Les quatre premiers points de la liste du 14/08 sont faits ; chacun a sa section
détaillée plus haut dans ce fichier.

| # | Point | Verdict |
|---|---|---|
| 1 | Promotion sur iPad mini | **Aucun défaut** — vert sur les trois états du dépôt, y compris le commit du relevé. Artefact de l'ancien test. Couvert désormais par `PromotionUITests`. |
| 2 | Cadrage serré du scanner | **Corrigé** — la bonne grille était hors concours (garde contradictoire). Rangées 14,52 px → 6,00, lignes intérieures 0,96. |
| 3 | Feuilles modales iPad | **Corrigé** — `presentationSizing(.page)`. Le bouton de validation de l'éditeur passe de « atteignable=non » à « oui ». |
| 4 | Dynamic Type des gabarits figés | **Corrigé pour les 4 sites qui le méritaient** — les 25 autres sont des SF Symbols en cadre fixe ou des tailles dérivées du plateau, qui ne doivent pas scaler. |

### 5. Refonte `NavigationPath` → `[Route]` — valeur moyenne, risque élevé

Réconcilierait `sidebarSelection` et `path` à la bascule d'ossature (symptôme
mesuré : « retour » depuis Puzzles mène au tableau de bord iPad dans une barre
sans titre). Mais l'iPhone étant verrouillé en portrait, **le public se réduit
aux utilisateurs d'iPad en Split View / Stage Manager**. Coût : une trentaine
de sites de navigation, sur l'ossature même de l'app. Seul point où le remède
peut faire plus de mal que le mal.

### 6. Répartition des largeurs sur grand écran (Lot 4.3) — invérifiable ici

Panneau puzzle fixé à 360 pt, pas de disposition à deux colonnes en deux
joueurs, écrans d'entrée sans plafond de largeur. Le simulateur ne permet pas
de juger un rendu paysage à la capture (piège documenté) : sans un vrai iPad,
ce serait déplacer des chiffres au hasard.

### ✅ 7. La tuile « Deux joueurs » déborde de 10,7 pt — FAUX POSITIF, tranché le 15/08 au soir

**Le relevé était exact, son interprétation était fausse.** La tuile ne
déborde pas : c'est l'artefact de géométrie du fond décoratif, déjà instruit
et écarté sur preuves dans `LayoutOverflowUITests`, redécouvert par le
balayage parce que rien ne le signalait comme connu.

Ce que dit la mesure refaite sur iPhone 17 (`DynamicTypeOverflowUITests`,
taille L) — c'est le détail des TYPES qui tranche, et il manquait au relevé
d'origine :

```
accueil | .image  « person.2.fill » x=[208,0…412,7] → 10,7 pt dehors
accueil | .button « Deux joueurs »  x=[208,0…412,7] → 10,7 pt dehors
```

Deux éléments, **frames identiques**, et **aucun `.staticText`**. Le contenu
de la carte tient donc à l'intérieur — vérifié directement depuis :
`TILE-TEXT|Deux joueurs|x=[224,0…317,7]`, quand la carte va de 208 à 382.
L'arithmétique de la grille confirme le reste : fenêtre 402, marges de 20,
deux colonnes de 174 → la colonne droite commence à x=208, valeur relevée.
Les 30,7 pt en trop sont le glyphe `person.2.fill` du fond, écrêté à l'œil par
`clipShape` mais compté dans la géométrie annoncée à l'accessibilité.

#### La correction erronée que ce point demandait

L'entrée du 15/08 affirmait que « `LayoutProbe` ne parcourt pas les mêmes types
d'éléments ». **C'est faux** : les deux tests appellent le même
`LayoutProbe.horizontalOverflows`, donc les mêmes `inspectedTypes`. La seule
différence était un argument — le garde-fou passait `ignoring:`, le balayage
non. Croire l'une des deux sondes contre l'autre n'avait donc pas de sens.

#### Le vrai défaut, lui, existait — et il est corrigé

L'exclusion portait sur le **libellé, tous types confondus**. Or « Deux
joueurs » nomme à la fois le bouton (artefact) et le `Text` du titre à
l'intérieur : un titre réellement coupé aurait été mis sous silence avec
l'artefact. Trois changements :

1. `LayoutProbe.neverExcludedTypes` — une exclusion ne s'applique plus jamais
   à un type porteur de texte (`.staticText`, `.textField`, `.textView`…).
   `testNoOverflowOnHomeScreen` mesure donc désormais réellement les textes des
   tuiles, et **passe toujours** : ils tiennent.
2. `LayoutProbe.homeModeTileArtifacts` — la liste d'exclusion devient une
   source unique, partagée par le garde-fou et le balayage, avec la
   démonstration chiffrée en commentaire.
3. Le balayage **marque** l'artefact au lieu de le taire :
   `[ARTEFACT CONNU — fond décoratif, rien n'est coupé]`. C'est ce qui évitera
   qu'il soit consigné comme un défaut neuf une troisième fois.

Nouveau test `testHomeTileTextsAreMeasuredNotExcluded` : il prouve que
l'exclusion ne couvre que les conteneurs. *Piège rencontré* : sa première
version exigeait un élément unique par libellé et échouait — l'arbre
d'accessibilité expose le même texte jusqu'à cinq fois. Il mesure maintenant
toutes les occurrences.

**Ce qui reste ouvert** : la géométrie annoncée reste fausse, et quatre
tentatives de correction côté SwiftUI ont échoué (`accessibilityHidden` sur
l'image puis sur tout le fond, `clipped()`, `frame` explicite sur le glyphe).
`clipped()` s'applique au `ZStack`, dont la frame est déjà gonflée par le
glyphe — d'où le no-op. Sans effet utilisateur mesurable, ce n'est pas une
priorité ; c'est documenté pour qui rouvrirait le sujet.

### 7 bis. Répertoires d'ouvertures écrits par l'utilisateur — NOUVEAU (15/08)

Demandé par le testeur externe (voir plus haut, point 6), et c'est la seule
réponse qui passe à l'échelle sur la profondeur du contenu : 58 cours écrits à
la main ne rattraperont jamais un livre de 300 pages sur la seule Scandinave.

Découpage naturel, du plus utile au plus coûteux :
1. ~~**Import PGN** d'un répertoire dans le graphe FEN existant~~ — **FAIT le
   15/08**, voir la section « Répertoires personnels » plus haut.
2. **Éditeur d'arbre** dans l'app (ajouter/supprimer une variante, commenter).
   Seul morceau restant, et facultatif tant que l'import existe.
3. ~~**Partage** : export/import d'un fichier de cours~~ — **FAIT le 15/08**
   (`ShareLink` sur le JSON du cours, aucun serveur). Reste à trancher la
   question des droits d'auteur avant tout dispositif centralisé.

### ✅ 7 ter. Approfondir les cours — DÉBLOQUÉ et RÉORIENTÉ (16/08)

**La prémisse du point était fausse.** Les 58 cours ne sont pas quasi linéaires
parce que la chaîne Explorer était cassée : ils sont **écrits à la main** dans
`content/*.py` et compilés par `author.py`, sans réseau. Ce sont des lignes
d'enseignement, avec chapitres, résumés et 484 commentaires bilingues.
`generate.py` est une chaîne **parallèle**, statistique, qui n'a jamais
alimenté l'app — d'où la confusion.

Mesuré sur un pilote (Scandinave, jeton en place) :

| | Livré | Régénéré par l'Explorer |
|---|---|---|
| Positions | 81 | 434 (×5,4) |
| Ratio arêtes/positions | 0,988 — ligne droite | 1,058 — vraies branches |
| Coups commentés | 33 | **0** |
| Poids (58 cours) | 1,3 Mo | ~10 Mo |

Régénérer aurait donc échangé la pédagogie contre un extrait de base de
données. **Décision (validée) : l'Explorer sert d'informateur, pas de
générateur.**

`coverage.py` (nouveau) pose la question inverse : parmi ce que le joueur va
réellement affronter, qu'est-ce que le cours laisse sans réponse ? Il ne
modifie aucun cours, il classe le travail d'écriture. Deux choix portent tout :
une lacune n'existe que sur un **coup adverse** (un répertoire prescrit les
siens), et la priorité est **« probabilité d'arriver là × fréquence du coup
manquant »**.

Trois faux positifs écartés après les avoir vus dans la sortie : la position de
départ, le coup qui **choisit** l'ouverture (`SCOPE_PLY` — contre 1…d5 un
Trompowsky n'existe pas), et les fins de ligne, comptées à part.

**Résultat sur les 58 cours** — 1 292 requêtes, aucun échec :
- **1 115 trous** au seuil de 10 % ;
- **la moitié de la dette tient dans 123 trous**, soit 11 % du total : c'est là
  que les heures d'écriture rapportent ;
- dette la plus lourde : `london-system` (2,36), `scandinavian` (2,11),
  `nimzo-larsen` (2,02) ;
- trous les plus coûteux : `1.e4 Cc6 2.Cf3` (Nimzowitsch, 41 %), `1.d4 f5 2.c4`
  (Hollandaise, 36 %), `1.c4 Cf6 2.Cc3 g6` (Anglaise, 35 %).

Rapport lisible (lignes en notation algébrique, pas en FEN) :
<https://claude.ai/code/artifact/69827531-9ea4-425f-9bdf-d3bea7fac199>

**La suite est de l'écriture**, dans `content/*.py`, en descendant le
classement. Relancer `coverage.py` après coup met la dette à jour — c'est la
mesure d'avancement.

#### L'accès à l'API (résolu le 16/08)

La chaîne Explorer était **bloquée par un 401 nginx**.

**Correction du 15/08 au soir** : l'hypothèse « c'est cet environnement, à
retester depuis un Terminal ordinaire » est **démentie par la mesure**. Le
réseau fonctionne, et Lichess aussi — c'est l'explorer, et lui seul, qui
refuse :

| Requête | Réponse |
|---|---|
| `lichess.org`, `database.lichess.org`, `api.chess.com`, `wikipedia.org` | **200** |
| `tablebase.lichess.ovh` — même domaine que l'explorer | **200** |
| `explorer.lichess.ovh/masters` **et** `explorer.lichess.org/masters` | **401** |
| idem avec UA navigateur, UA de contact, sans UA, avec `Authorization: Bearer` | **401**, corps identique (172 octets, nginx) |
| `OPTIONS` sur le même chemin | **204** |
| racine du service | **301** |

Donc : ni un blocage de domaine côté bac à sable (le tablebase passe sur le
même domaine), ni un mauvais nom d'hôte (`explorer.lichess.org` est bien le
nom documenté dans la spec OpenAPI de Lichess — et refuse pareil), ni un
User-Agent, ni un jeton manquant (un `Bearer` ne change rien, et `explorer.py`
n'a de toute façon aucun support de jeton). Le préflight CORS passe mais les
requêtes de données sont refusées à la porte nginx.

**Cause trouvée le 16/08 : l'API n'est plus anonyme.** Le navigateur de
l'utilisateur reçoit le même 401 (donc ce n'est pas la sortie réseau des
outils), et une requête émise depuis l'infrastructure Anthropic — une troisième
adresse, sans rapport — reçoit également 401 : ce n'est donc pas non plus un
blocage d'IP. La spec OpenAPI de Lichess le déclare explicitement :

```yaml
# doc/specs/tags/openingexplorer/masters.yaml
security:
  - OAuth2: []
```

L'exemple `curl` sans authentification qui figure encore dans la description de
cette même page est périmé ; le comportement observé suit la spec.

**Corrigé dans la chaîne** (`explorer.py`, `generate.py`, README) :
- jeton OAuth lu dans `LICHESS_TOKEN` (ou `LICHESS_API_TOKEN`) et envoyé en
  `Authorization: Bearer`. Jamais en argument de ligne de commande — cela finit
  dans l'historique du shell et dans la liste des processus ;
- `generate.py` refuse de démarrer sans jeton, **avant** de charger les noms ECO
  et Stockfish : sinon le lot tourne longtemps pour ne produire que du vide.
  `--dry-run` reste utilisable sans jeton, puisqu'il ne sort pas sur le réseau ;
- le 401 a désormais un diagnostic dédié, qui distingue « aucun jeton envoyé »
  de « jeton envoyé et refusé », au lieu des cinq pistes génériques dont quatre
  étaient hors sujet ;
- noms d'hôte passés à `explorer.lichess.org` (ceux de la spec).

**Ce qui reste à vérifier, et qui demande le jeton** : qu'un jeton *valide*
débloque bien l'accès. Un jeton bidon reçoit le même 401 nginx que l'absence de
jeton — le refus a lieu à la porte, pas dans l'application — donc la preuve ne
peut venir que d'un vrai jeton. Si même un jeton valide échouait, la voie de
repli reste `database.lichess.org` (qui répond 200) en dumps hors ligne, plus
lourds mais sans dépendance réseau.

À enchaîner obligatoirement avec `audit.py`, dont l'avertissement restant
(Blackmar 8…h6) dit déjà où la couverture manque.

### 8. Chantier I, niveau 3 — l'explication POSITIONNELLE

Le « pourquoi » traite aujourd'hui le matériel et les motifs tactiques. Restent
les coups qui ne perdent rien mais abandonnent une case, ouvrent une colonne à
l'adversaire, isolent un pion, échangent le bon fou. Détectable par comparaison
de traits de structure avant/après. C'est là que ça devient rare — ce n'est pas
là que ça devient utile en premier.

## Module Finales — nouvelle famille « Thèmes transversaux », 4 cours (18/08)

Neuvième famille ajoutée au module (`themes` / « Thèmes transversaux »,
icône ampoule) pour des principes qui traversent les familles matérielles
existantes plutôt que d'appartenir à l'une d'elles. Quatre cours, tous
construits depuis zéro et vérifiés à l'oracle (aucune étude sourcée retrouvée
avec assez de certitude pour être citée honnêtement — voir plus bas pour la
recherche tentée) :

- **`eg-theme-two-weaknesses`** — le principe des deux faiblesses
  (Capablanca) : roi+3 pions blancs (a5 passé, f3) contre roi+1 pion noir
  (f6). Le pion a occupe le roi noir à lui seul ; pendant ce temps le pion f
  avance sans opposition. Deux chapitres montrent les deux choix noirs
  possibles (courir vers a5, ou garder f6) : dans les deux cas c'est
  l'AUTRE faiblesse qui tombe. Racine à 5 pièces.
- **`eg-theme-domination`** — dame contre cavalier en a8. Qd8+ couvre à la
  fois l'échec, b6 ET c7 (diagonale a5-d8) : le cavalier n'a strictement
  aucune case, la domination au sens plein. Un second chapitre (Qa4, attaque
  la même pièce mais ne couvre ni b6 ni c7) montre la différence entre
  « attaquer » et « dominer » — le cavalier s'échappe même avec un échec au
  passage (Nc7+). Racine à 4 pièces.
- **`eg-theme-stalemate-resource`** — dame contre tour, Noirs objectivement
  perdus. La tour attaque la dame (Rb7) ; Qxb7 semble gratuit mais verrouille
  g7 ET h7 par la 7e rangée pendant que le roi blanc tient g8 — pat, sans
  échec. Un second chapitre montre la parade (toute autre case de dame que
  b7 gagne normalement). Volontairement distinct de Saavedra (sous-promotion)
  et de « Tour contre Fou — le bon coin » (forteresse à boucle), déjà au
  catalogue. Racine à 4 pièces.
- **`eg-theme-active-king`** — même matériel, mêmes pions, même tour dans
  les deux chapitres d'une finale tour+pions ; seule différence : Ke3
  (gagnant) contre Ke2 (nul), une case d'écart. Racine à 7 pièces : le
  serveur ne fournit pas le DTM exact à cette taille, mais la catégorie
  gain/nulle reste prouvée sur chaque coup. Volontairement une finale de
  PIÈCES, pas une course de rois pure comme Grigoriev (déjà au catalogue).

**Recherche tentée pour la domination** : Troitzky, Kubbel et Kasparyan ont
tous composé sur le thème « cavalier dominé », mais aucune recherche n'a
retrouvé de FEN exacte assez sourcée pour la citer sans risque de fabriquer
une référence — le cours est donc honnêtement étiqueté construction, comme
plusieurs des 58 cours déjà au catalogue.

**Un bug de racine attrapé par `author.py` lui-même** : la première version
de `two_weaknesses.py` utilisait encore la racine à 7 pièces abandonnée en
cours de conception (2 pions par camp, f7+g7 vs f2+g2) au lieu de la racine
à 5 pièces réellement vérifiée à l'oracle (f6 vs f3) — `illegal san: 'Kxf6'`
à la compilation, corrigé avant tout audit. Rappel utile : copier-coller la
mauvaise racine entre deux tentatives de construction est une catégorie
d'erreur à part entière, distincte d'une ligne fausse.

62 cours de finales au catalogue. Audit propre sur les 4 nouveaux :
`✓ Chaque coup enseigné préserve son verdict théorique (tablebase)`. Une
seule ligne informative (non bloquante) : le `Qxb7` piège de
`eg-theme-stalemate-resource` est signalé « défense sous-optimale » côté
adversaire, exactement l'effet recherché. `Localizable.xcstrings` : 4
entrées ajoutées chirurgicalement (68 lignes, JSON valide re-vérifié après
coup).

## Bug UI pré-existant trouvé (et isolé, pas corrigé) : `testEndgameTileLeadsToLucenaInTheReader` (18/08)

Suite complète après le lot navigation + thèmes transversaux : un seul
échec, `EndgameModuleUITests.testEndgameTileLeadsToLucenaInTheReader()` —
après un tap sur la tuile Finales, le bouton `endgame_eg-lucena` n'apparaît
jamais dans la liste.

**Ce n'est PAS une régression de cette session.** Démarche de preuve :
1. Reproductible deux fois de suite sur un simulateur fraîchement effacé
   (`simctl erase`) — écarte un état de simulateur périmé.
2. Reproductible à l'IDENTIQUE avec `git stash -u` (donc TOUT le travail du
   jour de côté, code strictement égal à `origin/main`) — écarte toute
   cause dans la navigation, le filtre Progression ou les cours de finales
   ajoutés aujourd'hui.
3. Le catalogue embarqué dans le `.app` compilé contient bien `eg-lucena`
   (famille `rooks`, vérifié en extrayant `opening_catalog.json` du bundle
   construit) — écarte un souci de données.

Cause réelle non identifiée — pas d'investigation plus poussée faite
aujourd'hui (hors périmètre du travail demandé). À noter : au passage,
deux simulateurs « iPhone 17 » strictement homonymes coexistaient
(`76B18A38…` et `6D6D634E…`), ce qui rend `-destination
'platform=iOS Simulator,name=iPhone 17'` ambigu — les deux ont été
effacés ; utiliser l'UDID explicite si l'ambiguïté revient.

## Le mat aux deux fous — troisième mat élémentaire (18/08)

Item du « reste à faire » depuis la livraison initiale du module (17/08).
`eg-bishop-pair-mate`, famille `mates`, racine à 4 pièces
(`8/8/8/4k3/8/8/4K3/2B2B2 w`) : roi et deux fous de couleurs opposées, roi
noir centralisé pour un test exigeant. Même méthode que `rook_mate.py` :
ligne ENTIÈREMENT dérivée par `derive_optimal.py` (29 demi-coups, DTM
exact), puis annotée pour raconter la technique — la « barrière diagonale »
des deux fous qui avance case par case, exactement comme la tour rétrécit
sa boîte, jusqu'à ce que le roi blanc vienne porter le coup final. Un point
signalé explicitement dans les commentaires : contrairement au mat fou +
cavalier, N'IMPORTE QUEL coin ou case de bord convient ici (les deux fous
couvrent les deux couleurs de case) — pas de piège de « mauvais coin ».
Audit propre : `✓ Chaque coup enseigné préserve son verdict théorique`.

63 cours de finales au catalogue (121 au total). `Localizable.xcstrings` :
1 entrée ajoutée chirurgicalement après « The Active King in a Rook Ending »
(17 lignes, JSON valide re-vérifié).

## Le sélecteur rapide reprend la partie en cours, partout (18/08)

Demande : depuis un mode de jeu (lecteur d'ouverture/finale, puzzle en
cours, partie contre le moteur, partie à deux joueurs), passer à un autre
mode via le sélecteur rapide doit reprendre la position AFFICHÉE, pas
repartir d'une partie neuve — cohérent partout dans l'app. Les écrans de
LISTE/FILE (Puzzles, Ouvertures, Finales — pas de position unique à
reprendre) restent volontairement neufs.

**Ce qui manquait** : `OpeningReaderView` (lecteur, ouvertures ET finales)
envoyait déjà le FEN affiché vers « Contre l'ordinateur » mais PAS vers
Laboratoire ni Deux joueurs (`onOpenLab`/`onOpenTwoPlayer` en `() -> Void`,
sans position). Même trou dans `PuzzleSolveView` (les trois destinations),
et dans `PlayView` côté Deux joueurs uniquement (Laboratoire fonctionnait
déjà). `TwoPlayerGameView`, lui, était déjà correct des deux côtés — pas
touché.

**Le blocage réel** : `TwoPlayerGameSettings` n'avait tout simplement AUCUN
support de position de départ personnalisée (contrairement à
`PlayGameSettings`) — « pas prévu pour ce mode », disait le commentaire
d'origine. Ajouté `startFEN: String?` + `startingPosition`, même contrat
que côté Jouer, non persisté (`TwoPlayerSettingsStore.save` l'efface, comme
`PlaySettingsStore`). `TwoPlayerSetupView` gagne un `initialFEN` (titre
« Continuer la partie » quand fourni, comme `NewGameSetupView`).
`Route.twoPlayerSetup` reste la route NEUVE ; une nouvelle route miroir,
`Route.continueTwoPlayer(String)`, porte la position — même schéma que
`Route.newGame` / `Route.continueVsStockfish(String)` côté moteur.

Vérifié : chaque écran capture désormais son FEN affiché dans la closure
passée à `QuickSwitchMenu` (celui-ci reste volontairement sans paramètre —
c'est l'appelant qui capture), et le route jusqu'à l'écran de réglages
correspondant. Compilation propre ; suite complète relancée pour
confirmer (voir entrée suivante si un souci apparaît).

## Deux joueurs : noms par défaut traduits, pas figés en français (18/08)

`TwoPlayerGameSettings.whiteName`/`blackName` valaient littéralement
`"Blancs"`/`"Noirs"` — un utilisateur anglophone les voyait tels quels,
dans les champs pré-remplis ET dans les messages VoiceOver. Les clés
existaient déjà dans `Localizable.xcstrings` avec leurs traductions
(`"Blancs"` → `"White"`, `"Noirs"` → `"Black"`) : seul le point d'usage ne
passait pas par `LocalizationController.string(...)`. Corrigé aux quatre
endroits où la valeur littérale servait de DONNÉE (pas juste de libellé de
champ, déjà correctement localisé via `LocalizedStringKey`) : le repli
« champ vide » de `TwoPlayerSetupView.start()`, le pré-remplissage au tout
premier lancement (aucun réglage sauvegardé), l'annonce VoiceOver de
`TwoPlayerViewModel.announceMove`, et le suffixe « (Blancs)/(Noirs) » du
dialogue d'abandon.

## Le bug Lucena, résolu : c'était le test, pas l'app (18/08)

Suite du signalement précédent (« bug UI pré-existant isolé »). En reprenant
l'investigation : la famille « Finales de pions », qui précède « Finales de
tours » dans la liste, compte désormais 12 cours — la ligne Lucena se
retrouve à la ~14e ligne affichée (après l'en-tête pions, ses 12 lignes, et
l'en-tête tours). Une `List` SwiftUI ne matérialise pas les lignes trop
loin hors-écran dans l'arbre d'accessibilité : `waitForExistence` du test
attendait un élément que rien ne rendait encore.

**Pas un bug de l'app** — les données et l'écran sont corrects, seul le
test ne défilait jamais. Corrigé par la même parade déjà utilisée dans
`RecentGamesUITests`/`AnalysisReviewUITests` : une boucle `swipeUp` bornée
(12 essais) avant `waitForExistence`. Vérifié isolément (passe en 22 s),
puis suite complète relancée pour confirmer l'absence d'autre régression.

## Accueil iPhone : libellés courts, iPad garde les longs (18/08)

Signalé par l'utilisateur : les tuiles de l'accueil tronquaient sur iPhone
(« Contre l'ordinat… »). `ModeCard` gagne `shortTitle`/`shortSubtitle`,
servis uniquement en classe compacte — l'iPad (classe régulière, tuiles
larges) garde les libellés complets. Sept tuiles retouchées côté compact ;
la vérification a été VISUELLE (captures simulateur FR et EN, plus aucune
troncature), pas seulement compilée. `VoiceOver` continue d'annoncer le
titre COMPLET (l'`accessibilityLabel` utilise `title`, pas la variante).
Au passage : « The computer against itself » raccourci en « Self-play »
côté anglais.

**Une leçon d'outillage payée cher** : pour vérifier la capture anglaise,
`defaults write …ChessLab settings.appLanguage english` a été écrit sur LE
simulateur qui sert aussi aux tests — la suite suivante a échoué presque
entière (~60 tests UI cherchant des libellés français). Réglé par
`simctl erase` et relance. Règle : toute pollution manuelle d'un simulateur
de test (defaults, langue, état d'app) doit être effacée avant la suite
suivante — ou faite sur un AUTRE simulateur.

## Moteur d'analyse : trois économies sans toucher au calibrage (18/08)

Audit à la demande de l'utilisateur (« les tests de seuil consomment-ils
trop ? ») : le détecteur de zone limite est gratuit (arithmétique pure),
mais la relecture a trouvé deux gaspillages réels + un trou d'énergie.
Implémentés tous les trois, AUCUN ne touche les nombres calibrés (bande ±2,
budgets 300k/3M, plancher 1M inchangés) :

1. **Gardes `isBook`/`isForced` avant l'affinage** (`classifyNode`) : un
   coup de théorie sera classé `.book` et un coup forcé `.best` quelle que
   soit l'éval — les affiner payait jusqu'à 2×3M nœuds pour une étiquette
   qui n'en tient pas compte. Les deux drapeaux, déjà nécessaires à
   l'`Input`, sont simplement calculés AVANT le bloc d'affinage.
2. **Re-test de la bande entre les deux affinages** : si l'affinage du
   parent sort la perte de la zone d'hésitation, celui de l'enfant (≥ 1M de
   plancher) n'est plus payé. La paire mixte qui en résulte est déjà un
   état normal du système (garde anti-double-affinage, sens inverse).
3. **Mode économie d'énergie iOS** : `isLowPowerModeEnabled` saute
   l'affinage comme la surchauffe le fait déjà — mais SANS diviser le
   budget de base par deux, contrairement au chemin thermique : la
   surchauffe est rare et transitoire, le mode économie est un état banal
   (20 % de batterie) où dégrader aussi la base se paierait trop souvent.
   Arbitrage assumé : verdicts de base pleins, pas d'affinage, et ils
   restent en cache comme les verdicts « à chaud » thermiques.

## Labo : le duo Elo × temps par coup, documenté à l'écran (18/08)

Question de l'utilisateur : « un temps trop bas ne limite-t-il pas l'Elo ? »
Réponse sourcée (doc officielle Stockfish) : l'échelle `UCI_Elo` est
calibrée à la cadence 120s+1s (~2-3 s par coup), ancrage CCRL 40/4. Un camp
BRIDÉ y est peu sensible (le bridage probabiliste domine le temps) ; le
niveau « Maximum » (3190 ⇒ aucun bridage) tire TOUTE sa force du temps —
c'est le seul cas où l'écart affiché ment vraiment à temps court, en se
comprimant. Sous 1320, le temps est déjà ignoré (profondeur plafonnée).

Deux retouches dans `LabSetupView`, aucune mécanique changée :
- la note sous le curseur de réflexion énonce le fait de calibration (et
  que l'écart A-B reste comparatif entre deux camps bridés) ;
- un avertissement ciblé apparaît quand un camp ≥ 2800 rencontre moins de
  0,5 s/coup — LE cas trompeur. Pas de couplage automatique temps↔Elo :
  le mode rapide à 150 ms est ce qui rend une série de 100 parties
  regardable, on informe sans contraindre.

## Entraînement libre v2 — l'arbitrage au verdict, livré arbitré moteur (nuit du 18/08)

Le dernier gros morceau du module Finales : jusqu'ici l'entraîneur guidé
n'acceptait que LE coup de la leçon ; le mode LIBRE accepte tout coup qui
préserve le verdict théorique, et reprend ceux qui le lâchent (« gagnant →
nulle »), meilleur coup de l'arbitre en correction. Écran accessible depuis
le lecteur d'une finale (bouton cible, doré), `Route.endgameFreeTrain`.

**L'estimation de l'étude était fausse d'un ordre de grandeur.** Le plan
initial (« sous-sélection WDL ~15-25 Mo ») a été chiffré cette nuit contre
l'index réel du miroir Lichess : la fermeture captures+promotions des
racines des cours fait 377,8 Mo de fichiers `.rtbw` ; même réduite aux
seules configurations APPARAISSANT dans les cours, 177,3 Mo (les gros
postes sont les tables pièce+pion : KRPvKR seule — la Lucena ! — pèse
15,6 Mo). Embarquer 177 Mo est une décision produit, pas un détail
technique ; et l'app n'a par ailleurs AUCUN appel réseau aujourd'hui —
introduire le premier (sondage en ligne) en est une autre. Les deux sont
donc DIFFÉRÉES explicitement.

**Ce qui est livré à la place** : un protocole `EndgameVerdictJudging`
(la couture où un fournisseur EXACT se branchera — tables embarquées ou
en ligne, le jour où la décision produit est prise) avec une seule
implémentation ce soir : le moteur plein pot, 500 ms par question, seuil
±250 cp identique à celui de l'audit >7 pièces. L'UI dit « arbitrage
vérifié moteur » — VÉRIFIÉ, pas prouvé, la nuance maison reste visible.
Le pat depuis une position gagnante est arbitré par les RÈGLES, sans
moteur (le cas d'école de la dame trop gourmande).

Mécanique : baseline recalculée à chaque tour utilisateur (préchargée
pendant la réflexion adverse), coup fautif JAMAIS commité (le plateau ne
bouge pas, on réessaie), compteur de reprises affiché au bilan final —
« conversion propre » seulement quand il est à zéro. Une amélioration de
verdict est acceptée sans félicitation : sous jeu optimal c'est
impossible, donc c'est l'arbitre qui se corrige, pas l'utilisateur qui
brille. Pas de FSRS ici (voulu) : une conversion libre n'est pas une
carte de révision. 9 tests unitaires sur fournisseurs factices (verdicts
scriptés par FEN, défense scriptée) : acceptation, reprise, correction,
mat/pat par les règles, point de vue d'un cours côté noir.

Trois positions de test corrigées en route, leçon utile : dans une
position de test « dame contre roi », le coup naturel est souvent MAT —
et un mat court-circuite l'arbitre (chemin des règles), ce qui teste le
mauvais flux. Et un « pat en un » n'en est un que si TOUTES les issues
sont fermées — le premier essai laissait a7-a6 jouable. Vérifiées
python-chess avant correction, comme le contenu des cours.

## Huit cours de finales de plus, sous la même discipline (nuit du 18/08)

Session autonome nocturne, même mandat que la veille : combler les vrais
trous du catalogue de référence, chaque coup prouvé à la tablebase avant
d'être écrit. Huit cours livrés, 71 finales au catalogue (129 au total).

- **eg-philidor-rook-bishop** (déséquilibres) : la position de Philidor
  1749, tour et fou contre tour — le pendant GAGNANT des trois défenses
  déjà au catalogue. Sourcée Wikipédia, racine à 5 pièces, dtm 41 ; l'oracle
  confirme que sur 23 coups blancs, SEUL 1.Tf8+ gagne, et que le naturel
  1.Fc6?? tombe sur Td7+ ! et le pat (chapitre piège).
- **eg-bishop-knight-mate** (mats) : le quatrième mat élémentaire, ligne
  DTM-optimale de 39 demi-coups depuis le mauvais coin a8. La défense
  optimale de la tablebase joue exactement la parade des manuels (courir
  vers h1, l'autre mauvais coin) — la ligne montre la barrière de fou et
  l'épaulement qui l'interceptent.
- **eg-knight-vs-rook-pawn** (cavaliers) : reprise de la piste « cavalier
  contre pion-tour » abandonnée précédemment (camp fort inversé). Cavalier
  seul contre pion-tour en 6e : nulle — et l'oracle rend la danse c8-d6-b5
  spectaculaire, UN seul coup sauveur à chaque attaque du roi. Piège
  vérifié : Ce7?? (une case trop loin) fait basculer nulle → perte.
- **eg-promotion-race-check** (pions) : course de pions 3 temps contre 3,
  décidée par la géométrie des cases de promotion (roi noir sur la
  diagonale a8-h1 : promotion avec échec, puis Dxg2 sur la même diagonale).
  Un seul des huit coups blancs gagne (la poussée) ; le piège Rb6?? est le
  miroir exact — c'est alors la promotion NOIRE qui tombe avec échec.
  Première racine REJETÉE par l'oracle : le roi noir en e4 rattrapait le
  pion a5 tout en gardant sa course (Rd5 ! à double usage) — corrigée en
  reculant le pion d'un cran hors du carré.
- **eg-wrong-bishop-win** (fous) : le pendant offensif du « mauvais fou » —
  la forteresse exige d'ATTEINDRE le coin. Racine réglée au couteau : des
  six coups de fou, seul Ff4 gagne (l'unique route en un temps vers la
  diagonale-barrière b8-h2) ; la poussée naturelle a5?? laisse le roi noir
  se glisser en a8 et reconstruit exactement la forteresse du cours jumeau.
- **eg-queen-pawn-vs-queen** (dames) : l'item abandonné la veille
  (Botvinnik-Ravinsky, dtm 98) trouvé sous forme enseignable — position de
  manuel Müller & Lamprecht (FCE 9.12A, via Wikipédia), trait aux Blancs
  gagné dtm 41, trait aux Noirs nulle (les deux vérifiés). Tout le
  programme en 25 demi-coups : le parapluie (Rh6 derrière Dg6+pion h7),
  les échecs blancs qui repositionnent avec tempo, la deuxième dame, la
  double interposition. Piège Rh6?? prématuré, réfuté par Dh3 ! (clouage du
  pion h5 contre le roi — pas un échec, un gel définitif).
- **eg-rook-vs-connected-fifth** (tours) : miroir exact du cours « pions
  liés en 6e » un rang plus tôt — le verdict ne retombe pas à la nulle, il
  s'INVERSE (la tour gagne, dtm 35). Deux trouvailles d'oracle : après la
  poussée e6, TOUS les coups de tour sur la colonne a perdent (c'est le
  ROI qui réfute, la tour restant balayer la 8e) ; et Ta5, gagnant tant que
  les pions sont en 5e, PERD un tempo plus tard — le piège du cours.
- **eg-centurini-deflection** (fous) : le gain de Centurini — « deux
  diagonales, dont une trop courte ». Principe sourcé (règles de 1856),
  coordonnées introuvables en ligne (une transcription avec rois adjacents,
  illégale) : position construite et vérifiée depuis zéro, dtm 19. La
  mécanique célèbre sort seule de derive_optimal : Ra8 confisque a7 (seule
  case d'attaque de la petite diagonale), Fb8 s'interpose, puis Fg3 rafle
  la grande diagonale entière. Piège Ff4?? (échanger le gardien) : la prise
  a lieu SUR la diagonale de garde, nulle sèche.

**Abandonné en route, honnêtement** : la version « enchère pure » de la
course de pions (racine e4/h5 : perdante — le roi noir servait la course ET
la chasse) ; les racines dame+pion à pion g (nulles ou perdantes — mes
premiers FEN omettaient… la dame blanche, l'oracle a rendu des verdicts de
« dame contre pion » très instructifs sur ma propre étourderie) ; une racine
Centurini avec Fe1 qui prenait le fou noir au premier coup (même défaut de
pièce en prise que les fous de même couleur de la veille). La ligne
Troitsky explicite reste non couverte : deux_knights_vs_pawn enseigne la
phase finale, pas la frontière — un cours dédié demanderait d'enseigner un
fragment de gain à dtm 70+, format non résolu ce soir.

Audit final groupé des huit : « ✓ Chaque coup enseigné préserve son verdict
théorique (tablebase) », 0 requête réseau (360 en cache).
`Localizable.xcstrings` : 8 entrées FR ajoutées chirurgicalement d'un bloc
après « The Bishop Pair Mate » (136 lignes, JSON revalidé, diff propre).

## Six études célèbres pour la famille « practical » (nuit du 18/08)

Troisième session de contenu de la nuit, mandat resserré : la famille
« Études célèbres » ne comptait que 2 cours (Réti, Saavedra) sur 71
finales. Six études authentiques livrées — compositeur et année vérifiés,
position exacte sourcée, chaque demi-coup passé à la tablebase AVANT
écriture. 77 finales au catalogue (135 cours au total).

- **eg-lasker-ladder** (Lasker 1890, 6 pièces) : l'escalier roi+tour,
  sourcé ARVES (« Ballet dancing »). L'oracle confirme l'étude au-delà de
  l'espéré : 1.Kb8 est le SEUL des 14 coups qui gagne, la descente
  historique est la ligne DTM-optimale exacte, et Txh2 annule aux DEUX
  moments naturels — pour deux raisons différentes (roi sur c8 ; tour
  quittant la garde de c7 → …Txc7 !). Deux chapitres pièges en découlent.
- **eg-grigoriev-h8** (Grigoriev 1930, 5 pièces) : la marche a8→h8→d3,
  35 demi-coups tous vérifiés. Diagramme LU depuis le GIF de l'article
  d'Elkies (ACJ) + solution commentée. Pièges prouvés : 1.b4? nulle,
  1.Kb8? b4! (et 2.c4?? b3 PERD), 2.Ka7? b4! 3.c4 pat, miroir cassé
  9…Kh6? 10.c5.
- **eg-troitsky-1906** (Troïtski 1906, 7 pièces) : cage h1-h3, tournée du
  cavalier, sacrifice Cf3!. Position+clé sourcées ARVES ; 1.Cg2 unique
  gain, les deux prises naturelles (Cxg4?, gxh4?) annulent — chacune son
  chapitre. Branche …h5 couverte (le manège mange les trois pions).
- **eg-mattison-1914** (Matisons 1914, 6 pièces) : FEN exacte du PGN d'une
  étude Lichess dédiée. Fe3+! (bouche la colonne e), Fa7!! (coupe la route
  a8-e8), Ff2! (dévie la tour) ; l'oracle ajoute que 4.Kf4 est unique —
  les QUATRE promotions n'y font que nulle — et que dans le piège du roi
  fuyard, 5.e8=D perd même la partie (enfilade e1-e8).
- **eg-rinck-1920** (Rinck 1920, 6 pièces) : domination, sourcée Wikipédia
  (La Stratégie 1920). 1.Cd2 unique gain, les 14 réponses de la tour
  perdent — fourchettes d5/e6 en chapitres, fin sur fou+cavalier (renvoi
  au cours du mat).
- **eg-kubbel-1927** (Kubbel 1927, 7 pièces) : pions seuls, sourcé ARVES.
  1.a6!! unique gain sur dix coups légaux (axb6? nulle, les six coups de
  roi et même b4 PERDENT). Course des dames : nées le même coup, seule
  celle d'a8 a l'échec (Dd5+/Dd3!/b3+!) — la jumelle de b8 bute sur les
  pions noirs, nulle prouvée, chapitre contraste.

**Abandonné en route, honnêtement** : Behting 1906 (position exacte
trouvée… à 9 pièces, hors oracle) ; les Kubbel 1921/1922 célèbres (8
pièces) ; la chasse Kubbel 1925 h3→a3 (solution narrée partout, position
exacte introuvable en quatre recherches — pas de reconstruction signée
Kubbel) ; Prokeš reste mort, conformément à la consigne.

Audit groupé des six : « ✓ Chaque coup enseigné préserve son verdict
théorique (tablebase) », 212 requêtes, toutes en cache (la vérification
préalable avait déjà tout payé). `author.py` complet repassé (135 cours).
`Localizable.xcstrings` : 6 entrées FR en blocs de 17 lignes après une
entrée complète (102 lignes, `json.load` revalidé).

## Version 1.5 : aide et dossier App Store réalignés, menu « S'entraîner » (19/08)

Demande : tout documenter sous 1.5, puisque ni la 1.3 ni la 1.4 n'ont été
soumises (dernier build chez Apple : le 3, en 1.2.0). Fait :

- **Aide in-app** : six rubriques réécrites — Nouveautés 1.5 (couvre
  1.2 → 1.5), Finales (77 cours, neuf familles, entraînement libre), Progrès
  (filtre 7/30 jours), et la mention du sélecteur de mode dans Ordinateur,
  Puzzles et Ouvertures. Traductions EN régénérées depuis la source Swift
  (l'extraction lit les corps réels, pas une copie qui divergerait).
- **AppStoreSubmission/** : `RELEASE_NOTES-1.5.0.md` réécrites (périmètre
  1.2 → 1.5 explicite, module Finales à 77 cours, entraînement libre,
  sélecteur de mode, contenu 1.4 replié — répertoires personnels, relecture
  moteur, un essai par puzzle) ; `METADATA.md` : « Nouveautés » 1.5 FR
  (2500 car.) / EN (2335 car.), descriptions FR/EN avec un bloc Finales
  dédié, textes promo à « 77 finales prouvées », section version/build à
  1.5.0 build 7 (vérifiée aux deux configurations du pbxproj), historique
  des versions, note de push actualisée ; `CHECKLIST.md` révisée ;
  `RELEASE_NOTES-1.4.0.md` bandeau « jamais soumise, document historique ».
- **Menu « S'entraîner »** dans le lecteur des finales : retour utilisateur
  du matin (« c'est quoi le bouton orange ? je vois pas son intérêt ») —
  l'icône cible nue n'expliquait rien. Les deux modes d'entraînement
  (ligne guidée, entraînement libre) vivent désormais dans UN menu aux
  entrées nommées ; les ouvertures gardent leur bouton direct unique.
  Aide, notes de version et chaînes accordées.

Au passage, Xcode (ouvert pendant la nuit) avait re-trié le catalogue de
chaînes et extrait les clés vides des nouvelles vues — vérifié
non-destructif clé par clé (les 13 chaînes v2 et leurs EN intactes),
conformément au comportement documenté le 18/08.

## Finales : la rangée 1 toujours en bas dans le LECTEUR (19/08)

Retour utilisateur : « elles sont des fois représentées inversées — mieux
d'afficher la ligne 1 en bas ». Inventaire : 27 des 77 cours de finales ont
pour héros le camp noir (défenses, forteresses — Philidor, Vancura,
Cochrane…) et le lecteur orientait le plateau côté héros, comme pour les
répertoires d'ouvertures : ces 27 diagrammes s'affichaient donc inversés
par rapport à tous les livres de finales.

Correctif dans `OpeningReaderViewModel` : pour un cours `kind == endgame`,
l'orientation est TOUJOURS blancs en bas (convention des diagrammes) ; les
ouvertures gardent le côté étudié en bas (un répertoire noir se lit noirs
en bas, comme partout dans l'app). Les écrans d'ENTRAÎNEMENT (ligne guidée,
entraînement libre) gardent le camp JOUÉ en bas : on y joue, on ne lit
plus — même convention que Jouer contre l'ordinateur côté noir.

## Revue de code complète avant 1.5 (19/08, ~34 000 lignes hors Stockfish)

Demandée par l'utilisateur avant soumission. Méthode : balayages par
classes de défauts (force unwraps, @unchecked Sendable, tâches non
annulées, cycles de rétention, try? silencieux, observateurs), puis
lecture ciblée des cœurs à risque (moteur, pendule, autosaves, synchro,
conteneur SwiftData, VMs récents). Les deux gros VMs (Jouer, Analyse —
3 900 lignes) ont été inspectés au niveau cycle de vie/files sérielles,
pas ligne à ligne : leur histoire d'incidents est documentée sur place et
verrouillée par les suites.

**Deux bugs trouvés et corrigés séance tenante :**
1. **Reprise Deux joueurs depuis une position portée** : les trois chemins
   de rejeu (`init?(resuming:)`, `boardAfter(plies:)`, `rebuild(moves:)`)
   repartaient de la position STANDARD — toute partie démarrée via
   « Changer de mode » sur une position reprise devenait irrécupérable
   après un kill de l'app (« Reprise impossible »), et la navigation
   d'historique rejouait sur le mauvais échiquier. Introduit la veille
   avec startFEN. Corrigé (settings.startingPosition partout) +
   `TwoPlayerResumeFromFENTests` (3 tests, racine Lucena).
2. **Course au redémarrage de l'entraînement libre** : `restart()` pendant
   la réflexion de la défense laissait la riposte de l'ANCIENNE partie
   s'appliquer à la nouvelle (ou strander l'écran). Le jeton d'arbitrage
   devient un jeton d'ÉPOQUE, incrémenté aussi par restart/riposte/
   baseline ; toute continuation périmée s'abandonne au retour d'await.

**Recommandations consignées, non traitées (choix assumé avant 1.5) :**
- le tour anti-fuite moteur (`EngineLeakUITests`) ne visite pas encore
  l'écran d'entraînement libre — à étendre ;
- l'entraînement libre fait DEUX recherches par coup accepté (l'éval
  d'arbitrage rend déjà le meilleur coup défensif de la même position :
  ~500 ms gaspillées, réutilisable) — amélioration de fluidité à faire
  hors fenêtre de soumission, elle change le contrat des faux des tests ;
- `OpeningReviewLog` croît sans borne et est rechargé INTÉGRALEMENT à
  chaque apparition d'écran (11 sites via reconcile) — repli/élagage ou
  chargement incrémental à concevoir quand les compteurs grossiront.

**Quitus explicite** (points contrôlés, rien à signaler) : cycle de vie
moteur (compteur d'instances + files sérielles + watchdog + teardowns),
pendule (throttling d'observation, weak self, pause/cancel), annulation
des tâches longues (autoplay, reveal, hint, run de série), politique de
persistance (quarantaine en deux temps, dernier recours mémoire avoué à
l'écran), réconciliateurs de synchro (dédoublonnage, enregistrement
canonique), discipline de localisation, autosaves à champs additifs.

## Les trois recommandations de la revue, traitées à faible risque (19/08)

Demande : « corriger sans prendre trop de risques ». Fait, avec la mesure
du risque explicitée pour chacune :

1. **Tour anti-fuite étendu** (risque nul : test seul) — le parcours
   `EngineLeakUITests` visite désormais l'entraînement libre (lecteur →
   menu S'entraîner → mode libre, moteur réellement démarré), avant
   d'exiger zéro instance à l'accueil.
2. **La défense réutilise la ligne de l'arbitre** (risque faible, contenu
   dans le VM) : l'éval d'arbitrage rend déjà le meilleur coup du camp au
   trait de la position atteinte — c'est la riposte, rejouée telle quelle
   au lieu d'être recalculée (~500 ms gagnées par coup accepté). Repli
   inchangé sur le fournisseur si le coup manque ou est inapplicable ;
   les 9 tests existants passent tels quels, +1 test (le fournisseur
   n'est PAS consulté quand la ligne est fournie).
3. **Réconciliation throttlée aux apparitions d'écran** (l'élagage des
   journaux, lui, attendra la 1.5.1 : les logs tardifs d'un autre
   appareil font partie du contrat de rejeu, y toucher avant soumission
   serait le vrai risque). Nouveau `reconcileIfStale(in:)` (5 min) dans
   les deux réconciliateurs, utilisé par les 6 sites « onAppear »
   (accueil ×2, listes ouvertures/finales, file de puzzles, Progrès) ;
   `reconcile(in:)` intact pour les tests, les Réglages (action
   explicite) et le démarrage de séance (fraîcheur requise).

## Localisation EN complétée + plateaux iPad (nuit du 19/08)

Deux chantiers surgis pendant la préparation des visuels 1.5 :

1. **122 clés sans traduction anglaise.** Les sondes des vidéos EN ont
   montré du français à l'écran (« Suivi », « parties jouées »,
   « Position personnalisée », carte Progrès de l'accueil). Un balayage
   du catalogue a révélé 122 clés sans `en` — dont l'aide des
   répertoires personnels et les crédits. Toutes traduites (épissures
   chirurgicales, `json.load` de contrôle, zéro clé restante). Registre
   britannique aligné sur l'existant (« Analyse », « licence »,
   « memorised »).
2. **Échiquiers timbre-poste sur iPad** (retour utilisateur en direct,
   22 h) : Laboratoire plafonné à 380 pt, lecteur Ouvertures/Finales à
   520/560 pt — des largeurs d'iPhone. Corrigé : LabRunView calcule la
   largeur du bloc éval+plateau d'après la taille visible (classe
   régulière : jusqu'à 780 pt en gardant ~540 pt pour les cartes) ;
   le lecteur passe à 62 % de hauteur (portrait) / 55 % de largeur
   (paysage) sur grand panneau, iPhone inchangé. L'entraînement
   (OpeningTrainView, EndgameFreeTrainView, puzzles) remplissait déjà.

Conséquence : captures EN refaites sur build corrigé (iPhone valides —
layouts compacts intacts —, iPad refaites), et les deux vidéos EN
re-tournées. Le montage iPad utilise désormais `make_preview.swift`
multi-segments (paires début/durée mises bout à bout) pour couper un
temps mort au milieu de la prise sur un écran statique — raccord
invisible, scénario complet du menu au Laboratoire en ≤ 30 s.

**20/08 au matin : campagne close sur décision utilisateur.** Les 12
captures EN sont finales (iPhone 1284×2778, iPad 2064×2752, barre d'état
anglaise homogène « Thu Aug 20 », gros plateaux) ; les deux aperçus
vidéo sont REPORTÉS à la prochaine version (« arrête les captures, on
les fera sur la prochaine version ») — l'outillage reste prêt. Au
passage, la capture 06 avait révélé un piège de List paresseuse (rangée
« hittable » au bord, tap avalé, test « réussi » à 5 fichiers sur 6) :
le test échoue désormais explicitement, et navigue par la puce de
famille « Tours » (nouvel identifiant `endgameFamilyChip_<famille>`)
au lieu de 20 swipes.

## Chantier B — synchronisation iCloud complète (20/08)

**Fait.** B.2 : les réglages suivent iCloud via `NSUbiquitousKeyValueStore`
(`SettingsCloudSync`), couche fine au-dessus des stores `UserDefaults`
existants, qui restent la source lue par l'app. Liste BLANCHE de neuf clés —
six préférences transversales et les trois blocs JSON de mode. Entitlement
`ubiquity-kvstore-identifier` ajouté : il manquait, `NSUbiquitousKeyValueStore`
ne fonctionne pas sans lui.

B.1 était déjà livré le 16/08 (`UserOpeningRecord` en base synchronisée,
migration des fichiers) — le plan était en retard sur le code. Trois manques
comblés : le bug `kind`/`family`, la réconciliation par contenu, et
l'observation de la synchro côté Finales.

**Décisions.**
- *Langue et sons restent locaux* (décision utilisateur du 20/08). Le `didSet`
  de la langue reconstruit tout le bundle de localisation : une valeur poussée
  d'un autre appareil rebasculerait l'interface en pleine session.
- *Les états de machine ne voyagent pas*, par construction de la liste blanche :
  marqueurs de migration et d'amorçage, compteur d'échecs d'ouverture du
  conteneur, horodatage de réconciliation. Et le drapeau `cloudKitSyncEnabled`
  lui-même : synchroniser l'interrupteur de la synchro, c'est se couper le
  canal qui propage l'information au moment où on l'éteint quelque part.
- *Au démarrage, le nuage gagne sur ce qu'il possède déjà, l'appareil comble
  les manques.* C'est ce qui rend le premier appareil fondateur sans écraser un
  compte déjà garni.
- *La réconciliation des cours compare le GRAPHE, pas le fichier entier.* Un
  renommage ne doit pas dédoubler un répertoire ; ajouter une variante, si.

**Pièges.**
- 🐛 `OpeningCourse.init` ne portait ni `kind` ni `family`, et c'est le SEUL
  chemin de recopie d'un cours. Une finale partagée, renommée ou modifiée
  redevenait donc une ouverture : elle quittait l'écran Finales et le lecteur
  la retournait. Trois chemins corrigés, quatre tests de verrou.
- L'empreinte de contenu doit canonicaliser l'ordre des clés JSON : `positions`
  est un dictionnaire, l'encodeur ne trie pas, et deux appareils encodant le
  même cours produisent des octets différents. Sans cela, toute copie passait
  pour divergente.
- Premier essai de réconciliation trop agressif : il forkait sur TOUTE
  différence, donc un simple renommage créait un doublon. Le test existant
  `duplicateRecordsAreCollapsed` l'a attrapé — il avait raison, la règle a été
  resserrée au graphe.

**Vérifié.** 604 tests verts (+17). La validation de bout en bout demande deux
appareils réels : elle reste une checklist manuelle.

## Chantier C.0 — métriques d'analyse persistées (20/08)

**Fait.** Chaque partie entièrement classée dépose son bilan chiffré sur son
`GameRecord` (champs additifs, optionnels) : précision par camp, **perte
moyenne brute** hors théorie, coups classés, coups de théorie, version du
barème. `GameAnalysisMetrics` fait le calcul — fonction pure, 12 tests sur des
valeurs écrites à la main. Bénéfice collatéral attendu depuis l'étape 3 :
l'analyse d'une partie déjà vue se relit au lieu de se recalculer.

**Décisions.**
- *La perte moyenne BRUTE en plus de la précision.* La précision est déjà une
  moyenne de pertes, mais pondérée par la volatilité et écrasée par une
  exponentielle — deux traitements qui servent la lisibilité d'un pourcentage,
  pas la comparaison entre parties. La courbe « perte → Elo » a besoin de la
  grandeur non transformée.
- *La théorie ne compte pas.* Réciter dix coups de Najdorf ne dit rien du
  niveau de personne : la perte y est nulle par construction. Les coups de
  livre sont comptés à part, parce qu'un dénominateur qui fond mérite d'être
  visible.
- *Le lien partie ↔ analyse passe par une empreinte canonique*
  (`analysisKey`, celle du cache disque) et non par une identité propagée :
  l'écran d'analyse ne reçoit qu'un texte PGN, et douze sites de navigation
  auraient dû changer. L'empreinte porte la partie JOUÉE, pas sa mise en forme.

**Piège tranché (C.1, piège n° 1 du plan).** Le slider 800–3190 ne pilote pas
`UCI_Elo` sur toute sa plage : sous 1320 — le plancher natif de Stockfish —
c'est `Skill Level` (0→5) ET la profondeur (1→6) qui font le travail, l'Elo
affiché n'étant qu'une étiquette. Une courbe calibrée en pilotant `UCI_Elo`
directement mentirait sur tout le bas de l'échelle, là où l'estimation
intéresse le plus. La campagne devra donc passer par le Laboratoire, par
valeur de slider : `LabGameSettings` construit le même `EngineStrength` que le
mode Jouer, le Laboratoire EST le produit. Documenté dans
`tools/elo-calibration/README.md` avec le protocole complet.

**Reste à faire.** C.1 (campagne de mesure), C.2 (`EloEstimator` + affichage),
C.3 (validation humaine). Rien ne s'affiche tant que la courbe n'est pas
mesurée : pas de chiffre non vérifié à l'écran.

## Chantier A — lot 1 : Nimzo-Larsen, la dette la plus lourde (21/08)

**Fait.** Cinq trous comblés dans `nimzo-larsen`, le cours à la dette la plus
lourde du catalogue (1,83) : les cinq réponses noires du 2e coup qu'aucun
chapitre n'atteignait — …e6 et …d5 après 1.b3 Cf6 ; …d6 après 1.b3 e5 ; …c5 et
…e6 après 1.b3 d5. Ensemble, elles représentent près de 90 % de ce que
l'adversaire joue réellement là où le cours restait muet. Lignes calculées au
moteur (`suggest.py`, profondeur 22, deux candidats comparés), commentées
FR+EN, rejouées par `author.py`.

**Mesure.** Dette 1,83 → **0,93** (−49 %), trous 37 → 31, positions 72 → 134.
`audit.py` : 0 gaffe enseignée (seuil 150 cp, 62 positions évaluées, contre-
mesure profondeur 24 déclenchée sur 0 arête suspecte). Verrou bundle
`OpeningBlunderRegressionTests` vert.

**Outillage.** `coverage.py` gagne un mode `--offline` : il n'exploite que le
cache local (1 034 réponses Explorer déjà présentes), sans réseau ni jeton. Un
trou trouvé hors ligne est un vrai trou ; une position absente du cache est
traitée comme donnée manquante. **Le rapport ne peut donc que sous-estimer la
dette, jamais l'inverse** — c'est le bon côté sur lequel se tromper pour une
mesure d'avancement.

**Piège de lecture (le mien).** J'ai d'abord classé les cours sur la clé
`gaps` du rapport, qui agrège trois natures : `trou` (vraie lacune), `fin`
(prolongement possible) et `portée` (coup hors sujet — répondre à 1.d4 dans un
cours scandinave). Le classement en sortait faussé. La clé à lire est `holes`,
que l'outil produit déjà filtrée. Dette réelle du catalogue : **41,58** sur
1 475 trous, et non les 61,91 de ma première lecture.

### Lot 2 — Scandinave (21/08)

Quatre coups blancs les plus joués que le répertoire laissait sans réponse :
4.Cxd5 après 3…Cf6 (63 % des parties à cet endroit), 4.De2 dans la ligne
3…De5+, et 3.Cf3 dans les deux ordres (après …Cf6 comme après …Dxd5). Lignes
au moteur (profondeur 24, deux candidats comparés à chaque fois), commentées
FR+EN. Dette **1,70 → 1,35** (−20 %), positions 94 → 138, `audit.py` sans
aucune gaffe enseignée.

Le nombre de trous monte de 51 à 52 : combler une lacune en ouvre de plus
petites derrière elle, plus profondes et moins souvent atteintes. C'est
attendu, et c'est pourquoi la DETTE — pondérée par la probabilité d'arriver
là — est la mesure, pas le compte de trous.

Un piège du format au passage : les lignes de `content/*.py` sont LINÉAIRES.
Une alternative à notre propre coup ne s'y insère pas comme un `role: trap`
(qui, lui, marque un coup adverse joué dans la ligne) — la tentative a produit
un « illegal san » à la compilation. L'avertissement a été replié dans le
commentaire du coup concerné, ce qui le rend d'ailleurs plus lisible.

### Lot 3 — Anglaise (21/08)

Cinq trous, dont un très gros : après 1.c4 Cf6 2.Cc3 g6 3.d4, les Noirs jouent
**…Fg7 trois fois sur quatre** — c'est LA réponse à l'Anglaise — et le cours ne
connaissait que 3…d5. Les quatre autres sont les réponses au 2e coup après
1.c4 c5 2.Cc3 (…Cf6, …e6, …d6) et la Sicilienne inversée 2…e5, là où le cours
ne prévoyait que …Cc6. Dette **1,68 → 1,20** (−29 %), positions 78 → 132,
`audit.py` sans aucune gaffe enseignée, 617 tests verts.

### Lot 4 — Attaque Est-Indienne (22/08)

Cinq trous : …c5 et …dxe4 dans la Française, …e6 dans la Sicilienne (Paulsen),
…Cc6 après 1.Cf3 d5 2.g3 c5 3.Fg2, et …e6 après 2…Cc6 3.d3. Dette **1,58 →
0,86** (−46 %), positions 86 → 139, `audit.py` sans gaffe, 617 tests verts.

**Choix éditorial assumé, contre le moteur.** Sur deux de ces trous, Stockfish
préfère quitter le système : après 1.e4 c5 2.Cf3 e6, il donne 3.d4 (Sicilienne
ouverte) à +0,41 contre −0,07 pour 3.d3. Le cours garde d3. Un répertoire
Attaque Est-Indienne qui bascule en Sicilienne ouverte n'est plus le même
cours : son intérêt — peu de théorie, un plan qui se rejoue partie après
partie — disparaît avec le système. La règle « prouvé, pas deviné » interdit
d'enseigner une gaffe, elle n'oblige pas à jouer le premier choix du moteur
quand un demi-pion se paie en identité de répertoire. L'audit reste le juge :
0 gaffe enseignée.

### Lot 5 — London System (22/08)

Cinq trous : …e6 et …Ff5 après 2.Ff4, …d6 contre …Cf6, le roque dans la ligne
du fianchetto, et …e6 dans la London « Jobava » (3.Cc3). Dette **1,47 → 0,97**
(−34 %), positions 101 → 152, 617 tests verts.

`audit.py` a relevé **1 arête suspecte** au premier passage, blanchie par la
contre-mesure à profondeur 24 — la double passe a fonctionné exactement comme
prévu, et le verdict final est 0 gaffe enseignée.

À noter : sur le trou Jobava, le moteur propose 4.Cb5, un saut de cavalier très
concret. Contrairement au lot 4, ce n'est PAS une sortie de système : c'est
l'idée maîtresse de la Jobava, et le cours couvrait déjà …a6, précisément le
coup qui l'empêche. Retenu sans réserve.

### Lot 6 — Scandinave, seconde passe (22/08)

Cinq trous plus profonds, tous à des positions que le premier lot venait
d'ouvrir : 5.Cf3 dans la ligne 3…Cf6, 4.Fc4 et 5.Fc4 contre la retraite 3…Dd8
(nouveau chapitre), 5.Fd2 dans la ligne 3…Da5, et 4.Cge2 contre 3…De5+.
Dette **1,35 → 0,95** (−30 %), positions 138 → 190. Sur la session complète, la
Scandinave passe de 1,70 à 0,95.

**Piège de méthode, attrapé de justesse.** J'ai d'abord déduit les séquences de
coups en LISANT les FEN à l'œil : **trois sur cinq étaient fausses**. J'aurais
calculé des lignes pour des positions qui n'étaient pas les trous — et rien ne
l'aurait signalé, puisque ces lignes étaient parfaitement saines : `audit.py`
aurait donné son feu vert, la dette n'aurait pas bougé, et le trou serait resté
béant. Une erreur silencieuse, donc, du pire genre.

Correction outillée plutôt que promise : `path_to_hole.py` reconstruit le chemin
EXACT depuis la racine du cours par parcours en largeur du graphe. Le graphe
connaît le chemin, autant le lui demander. **À utiliser systématiquement** pour
tout trou dont la position n'est pas au tout début d'une ligne.

### Lot 7 — Anglaise, seconde passe (22/08)

Cinq trous ouverts par le premier lot, chemins reconstruits par
`path_to_hole.py`. Le plus lourd : le roque après 1.c4 Cf6 2.Cc3 g6 3.d4 Fg7
4.e4 d6 5.Fe2, joué par **plus de quatre Noirs sur cinq** — de très loin le
coup le plus fréquent de tout le répertoire. Les autres : …Cf6, …e6 et …d6
après 1.c4 c5 2.Cc3 Cc6 3.g3, et …Cf6 dans la Sicilienne inversée.
Dette **1,20 → 0,88** (−26 %), positions 132 → 180. Sur la session, l'Anglaise
passe de 1,68 à 0,88.

Un calcul a expiré à profondeur 22 sur la ligne la plus profonde (10 demi-coups
depuis la position initiale) ; relancé à 20, il a abouti. À retenir pour les
positions tardives : la profondeur a un coût qui explose avec le nombre de
coups déjà joués.

**Assumé.** Le nouveau rapport post-lot ne trouve que 18 positions en cache
(les positions nouvellement écrites n'y sont pas) : la dette résiduelle de 0,93
est elle aussi un plancher. Une mesure complète demandera un jeton Lichess
valide — c'est le lot A.2, toujours ouvert.

## Chantier C — abandonné après mesure (21/08)

**Décision.** L'estimation du niveau Elo par partie est abandonnée. Barre posée
par l'utilisateur : ±100-150 Elo, sinon on ne le fait pas. Mesuré : ±699 Elo
pour une partie, ±214 en moyennant dix. Le chantier s'arrête, et c'est un
résultat — pas un renoncement.

**Ce qui a été mesuré.** Deux pilotes (paliers 1100/1700/2300/2900, six parties
chacun, jouées au Laboratoire par valeur de curseur puis repassées dans le
pipeline d'analyse de production). Quatre statistiques candidates :

| Statistique | Séparation 1100→1700 | 1 partie | 10 parties |
|---|---|---|---|
| Perte moyenne | d = 0,53 | ±699 | ±221 |
| Précision affichée | d = 0,50 | ±677 | ±214 |
| Perte hors positions tranchées | d = 0,87 (partiel) | — | — |
| Part de coups fautifs | d = 0,18 (partiel) | — | — |

Deux paliers distants de **600 Elo** sont indiscernables. Le chiffre à retenir
est celui-là.

**Pourquoi.** La dilution : les parties sont longues (jusqu'à 75 coups classés
par camp à 1100), et une fois la position tranchée plus aucun coup ne coûte
rien — des dizaines de coups triviaux noient les quelques décisions qui
distinguent deux joueurs. Restreindre aux positions indécises n'y change presque
rien : cela retire des coups faciles des DEUX côtés. Quant à la part de coups
fautifs, elle est la pire des quatre, et c'est logique après coup : à budget
égal, un moteur bridé à 1100 et un à 1700 se trompent aussi SOUVENT, c'est la
GRAVITÉ qui diffère.

Et ce n'est pas un problème d'échantillon : plus de parties resserrent la
moyenne d'un palier, pas la dispersion d'une partie — qui est exactement ce
qu'il aurait fallu annoncer.

**Ce que le pilote a fait gagner.** 45 minutes de mesure au lieu de ~10 heures
de campagne complète pour une courbe inutilisable. C'est l'argument pour
toujours piloter avant d'industrialiser.

**Conservé, parce que ça ressert.** Le harnais `EloCalibrationHarness` (séries
au Laboratoire + repassage dans l'analyse) est l'instrument exact dont le
chantier D a besoin pour mesurer la force effective d'un style (lot D.1.d) ;
`discriminate.py` dit si une statistique sépare deux paliers ; `fit_curve.py`
et les CSV bruts restent pour que la démonstration soit rejouable. Le lot C.0
(métriques persistées sur `GameRecord`) reste aussi : il rend l'analyse d'une
partie déjà vue relisible au lieu d'être recalculée — un point du backlog depuis
l'étape 3 — et ne dépend pas de l'estimation abandonnée.

**Piège méthodologique noté.** Ne jamais lancer d'audit moteur (`audit.py`,
`suggest.py`) pendant une campagne de mesure : les deux Stockfish se disputent
le processeur, le moteur du Laboratoire explore moins de nœuds dans ses 150 ms
et la classification bute sur son plafond de temps. Les mesures seraient
faussées SILENCIEUSEMENT.

## Chantier D — vérifications amont (21/08), avant toute ligne de code

Trois faits établis sur pièces, dont deux corrigent le plan.

**Stockfish n'a aucune personnalité.** `Contempt`, seul levier stylistique
historique, a été RETIRÉ du moteur (commit `ed436a3`) : nous embarquons la
17.1, il n'existe plus. Restent `Skill Level`, `UCI_LimitStrength` et
`UCI_Elo`, qui règlent la force, pas le caractère. Les moteurs à personnalités
(Komodo) sont propriétaires et non embarquables sous GPLv3. L'approche prévue
en D.1 — MultiPV puis reclassement maison selon des traits — n'est donc pas un
pis-aller faute de mieux : c'est la méthode standard, et il n'existe pas de
raccourci.

**Les poids Maia ne sont pas un problème de taille.** Mesurés, pas estimés :
1,2 Mo par réseau. Trois paliers = 3,6 Mo, les neuf ≈ 11 Mo, face aux 71 Mo de
NNUE déjà embarqués. Licence GPL v3, compatible avec l'app — le point bloquant
n° 4 du gate tombe.

**Mais lc0 n'est pas dans le projet, contrairement à ce qu'affirmait le plan.**
La seule dépendance SPM est `chesskit-swift` (les règles du jeu) ; le moteur
est un CStockfish vendorisé à la main dans `Vendor/`. Aucune trace de lc0 ni de
Leela. D.2 ne consiste donc pas à activer quelque chose de dormant mais à
vendoriser un second moteur C++ complet, compilé pour iOS. Requalifié : projet
autonome précédé d'une étude de faisabilité, et non spike de deux jours.

**Piste ouverte, non arbitrée : le niveau variable (D.3).** Moduler la force en
cours de partie pour garder la rencontre disputée. Technique documentée
(ajustement dynamique de difficulté ; *ChallengeMate*, Stanford, module
profondeur et probabilité de gaffe selon l'état de la partie). Orthogonale à
D.1 comme à D.2 — elle touche la force, pas le choix du coup — et de loin la
moins chère des trois. Condition non négociable : un MODE NOMMÉ dont la
promesse affichée est l'adaptation. Moduler en douce un réglage « Elo 1500 »
ferait mentir le chiffre, exactement ce qu'on vient de refuser en fermant C.

### Lot 8 — Bird (22/08)

Cinq trous, dont deux dans le gambit From (…Fg4 et …Cf6 après 4.Cf3), et trois
dans la Bird classique (…Cc6 après 3.e3, …e6 et …Ff5 après 2.Cf3).
Dette **1,11 → 0,48** (−57 %, la plus forte baisse relative de la session),
positions 68 → 111, audit sans gaffe.

`whiteTimeDecreasesBeforeTheFirstMove` a échoué dans la passe complète, puis
est repassé vert en isolation : c'est le flaky de pendule déjà documenté, pas
une régression — un lot de contenu d'ouvertures n'a aucun rapport avec une
horloge. Rejeu isolé systématique avant de conclure.

### Lots 9-10 — cours vierges : Colle et Écossaise (22/08)

Changement de stratégie décidé après le lot 8 : la file n'ayant plus aucun
cours au-dessus de 1,00, on privilégie les cours **jamais traités**, où le
rendement reste bien meilleur (la Bird avait rendu −57 % en un lot, contre
−26 % pour une troisième passe).

- **Colle** 0,95 → 0,48 (−49 %), positions 70 → 122. Même arbitrage qu'à
  l'Attaque Est-Indienne : le moteur propose systématiquement 3.c4 (Gambit
  Dame), on garde e3 et le système. Un système dont tout l'intérêt est de se
  rejouer à l'identique ne survit pas à un basculement vers une ouverture
  théorique.
- **Écossaise** 0,94 → 0,50 (−47 %), positions 53 → 108. Le trou principal
  était 4…Cxd4, l'échange le plus joué de toute l'Écossaise (deux Noirs sur
  cinq), absent du cours. Deux nouveaux chapitres au passage : contre la
  Petroff et contre la Philidor, que le répertoire ignorait.

**Outil ajouté : `prepare_lot.py`.** Il enchaîne ce qui était fait à la main à
chaque lot — lire le rapport, écarter les faux positifs, reconstruire le chemin
par le graphe, demander la suite au moteur. Il ne rédige rien : les
commentaires bilingues restent le seul vrai travail. Un lot passe de ~20
commandes à deux.

### Lots 11-12 — Italienne et Gambit du roi (22/08)

- **Italienne** 0,91 → 0,64 (−30 %), positions 108 → 163. Deux nouveaux
  chapitres : contre la Petroff et contre la Philidor. Le trou le plus
  instructif est 3…Cc6 dans la Petroff après 3.Cxe5 — l'erreur classique que
  deux Noirs sur cinq commettent (ils défendent le cavalier au lieu de le
  chasser par …d6), et qui vaut +1,70 aux Blancs. Enseignée comme telle.
- **Gambit du roi** 0,90 → 0,58 (−36 %), positions 83 → 127. **Trois des cinq
  trous étaient à la même position** — après 3.Fc4, où le cours ne couvrait que
  …Dh4+ : le chapitre du gambit du fou était quasi vide.

**Note d'honnêteté sur le Gambit du roi.** Plusieurs lignes ajoutées finissent
légèrement en faveur des Noirs (−0,26 à −0,61). C'est le gambit du roi : on
offre un pion pour l'initiative, et le moteur ne s'y trompe pas. `audit.py`
vérifie qu'aucun coup enseigné n'est une GAFFE (seuil 150 cp) ; il n'a jamais
exigé que les lignes soient gagnantes, et il ne faut pas lui faire dire ça.
Enseigner un gambit, c'est enseigner un pari assumé, pas une réfutation.

### Lots 13-14 — Anti-siciliennes et Partie du centre (22/08)

- **Anti-siciliennes** 0,89 → 0,56 (−37 %), positions 147 → 202.
- **Partie du centre** 0,87 → 0,44 (−50 %), positions 47 → 102, avec deux
  chapitres nourris : la ligne 3.Dxd4 (dont le grand roque, signature de
  l'ouverture) et le gambit danois.

**Un arbitrage de périmètre.** Le plus gros trou des anti-siciliennes était
3.d4 — la sicilienne OUVERTE, jouée près d'une fois sur deux. Un cours dont le
sujet est précisément d'y échapper ne peut pas la traiter : l'ouverte est un
répertoire entier, et en donner une ligne unique donnerait l'illusion de la
couvrir. Mais laisser la moitié des parties sans réponse n'est pas tenable non
plus. Choix retenu : une **porte d'entrée** — quelques coups vers le Sveshnikov
— avec un commentaire qui dit explicitement que ce n'est pas un traitement. Le
lecteur n'est pas abandonné, et rien ne lui est promis qui ne soit tenu.

### Lots 15-16 — Ouverture du fou et Quatre Cavaliers (22/08)

- **Ouverture du fou** 0,87 → 0,52 (−40 %), positions 60 → 115, dont le gambit
  Urusov et une ligne tranquille en 4.d3.
- **Quatre Cavaliers** 0,86 → 0,53 (−39 %), positions 64 → 119, avec les
  versions espagnole et écossaise, et un chapitre contre la Petroff.

Un motif revient dans ces deux lots et mérite d'être noté : le trou le plus
fréquent est souvent un **coup d'attente** (…h6) ou une **simplification
prématurée** (…Cxd4), c'est-à-dire précisément ce qu'un joueur de club joue
quand il ne sait pas quoi faire. Ce sont les positions où un répertoire aide le
plus, et celles que les cours écrits « par la théorie » oublient le plus
souvent — la théorie ne s'intéresse qu'aux meilleurs coups.

### Lots 17-18 — Slave et Gambit Dame accepté (22/08)

- **Slave** 0,84 → 0,51 (−39 %), positions 78 → 133.
- **Gambit Dame accepté** 0,83 → 0,44 (−47 %), positions 66 → 114.

Le plus gros trou de tout le chantier jusqu'ici, tous cours confondus, était
dans le second : après 1.d4 d5 2.c4 e6 3.Cc3, **plus d'un Noir sur deux** joue
…Cf6, et le cours ne prévoyait que le clouage …Fb4. Un développement
parfaitement banal, majoritaire, purement absent.

Ces deux cours partagent plusieurs positions (Slave, gambit refusé, gambit
accepté se croisent), et trois trous étaient communs. Le graphe étant indexé
par FEN, chaque cours doit néanmoins les couvrir pour son propre ordre de
coups : le contenu se répète, la couverture non.

### Lots 19-20 — Gambit de l'éléphant et Espagnole (22/08)

- **Gambit de l'éléphant** 0,80 → 0,37 (−53 %), positions 32 → 87.
- **Espagnole** 0,78 → 0,51 (−34 %), positions 94 → 149, dont la défense
  classique 3…Fc5, la variante d'échange et deux chapitres contre la Petroff
  et la Philidor.

**Le cas du gambit de l'éléphant mérite d'être noté.** Plusieurs lignes
ajoutées finissent nettement en faveur des Blancs — jusqu'à −0,91. Ce n'est pas
un défaut du contenu : c'est ce que vaut ce gambit. Le cours le dit désormais
explicitement, y compris dans le commentaire du coup 4.d3 (« contre un
adversaire qui joue simplement, le gambit ne donne rien de plus qu'un pion de
moins ») et dans un nouveau chapitre où, faute de 2.Cf3, on bascule sur une
défense saine — savoir renoncer à son arme favorite fait partie d'un
répertoire.

Enseigner une ouverture douteuse est légitime ; la présenter comme correcte ne
l'est pas. `audit.py` vérifie qu'aucun coup n'est une gaffe, il n'a jamais
prétendu que les lignes étaient bonnes.

### Lots 21-22 — Gambit Dame refusé et Viennoise (22/08)

- **Gambit Dame refusé** 0,79 → 0,48 (−39 %), positions 78 → 133, dont
  l'attaque de minorité expliquée dans la variante d'échange.
- **Viennoise** 0,78 → 0,39 (−49 %), positions 60 → 115.

La Viennoise illustre un défaut de conception fréquent dans ces cours : après
3.Fc4, le répertoire ne couvrait QUE …Cxe4, c'est-à-dire le piège. Un cours
d'ouverture bâti autour de son piège n'apprend à jouer que contre les
adversaires qui se trompent — or un joueur sur trois développe simplement par
…Fc5, et le lecteur se retrouvait alors sans plan. Les deux branches ajoutées
enseignent le jeu de manœuvre, qui est le cas majoritaire.

### Lots 23-24 — Philidor et Blackmar-Diemer (22/08)

- **Philidor** 0,74 → 0,52 (−30 %), positions 62 → 112.
- **Blackmar-Diemer** 0,73 → 0,38 (−48 %), positions 67 → 122.

Un fil conducteur a émergé en écrivant la Philidor et mérite d'être conservé :
la Philidor est une défense de NÉCESSITÉ, pas de principe. Dès que les Blancs
renoncent à d4 — ce qu'ils font une fois sur trois dans les trous comblés —,
…c5 devient le bon coup et la position se retourne. Les trois branches
concernées le disent avec les mêmes mots, ce qui fait du cours autre chose
qu'une liste de variantes.

Même honnêteté que pour le gambit du roi et l'éléphant côté Blackmar-Diemer :
le gambit est objectivement douteux, plusieurs lignes finissent légèrement en
faveur des Noirs, et un chapitre entier explique qu'un gambit refusé se joue
comme une bonne Française plutôt que d'être forcé.

### Lots 25-26 — Ponziani et Sicilienne dragon (22/08)

- **Ponziani** 0,73 → 0,42 (−43 %), positions 40 → 95.
- **Sicilienne dragon** 0,68 → 0,41 (−40 %), positions 115 → 170.

Le dragon révèle le même angle mort que le Ponziani, et il vaut d'être nommé :
**le cours ne prévoyait que 3.d4**, c'est-à-dire uniquement le cas où
l'adversaire coopère. Or une partie sur cinq n'atteint jamais le dragon parce
que les Blancs jouent une anti-sicilienne (Rossolimo, Fc4, Alapin), et le
lecteur se retrouvait alors sans la moindre indication dans une position qu'il
n'avait jamais vue. Un chapitre entier « si les Blancs n'ouvrent pas » a été
ajouté.

Même chose au Ponziani : sans …Cc6, c3 ne sert à rien, et le cours ne
prévoyait QUE …Cc6. Un cours de système doit dire ce qu'on fait quand le
système ne s'applique pas — sinon il n'enseigne que la moitié des parties.

### Lots 27-28 — Gambit Budapest et Française (22/08)

- **Budapest** 0,66 → 0,28 (−57 %), positions 44 → 99.
- **Française** 0,60 → 0,29 (−51 %), positions 129 → 178.

Le plus gros trou de la Française était un **ordre de coups**, pas une
variante : après 1.e4 e6 2.Cf3 d5, deux Blancs sur trois échangent en d5 — et
le cours ne prévoyait que 3.e5. La variante d'échange par cet ordre n'existait
tout simplement pas, alors qu'elle représente la majorité des parties par cette
voie. Un rappel utile : les trous ne sont pas seulement des coups oubliés, ce
sont aussi des chemins oubliés vers des positions par ailleurs connues.

Le Budapest ajoute un chapitre du même genre que le dragon et le Ponziani :
sans c4, il n'y a pas de gambit, et un répertoire de gambit doit dire ce qu'on
joue quand le gambit n'est pas disponible.

### Correctif — les systèmes doivent être ceux qu'on trouve documentés (22/08)

Consigne utilisateur : les deux arbitrages faits contre le moteur (garder e3 au
Colle, d3 à l'Attaque Est-Indienne) sont VALIDÉS, à condition que les systèmes
correspondent à leur forme documentée. Vérification faite plutôt que supposée.

- **Attaque Est-Indienne : conforme.** Le `3.Cd2` puis `4.dxe4` que j'avais
  écrit est exactement la forme standard — `Cd2` est joué précisément pour
  éviter l'échange des dames après `3…dxe4`.
- **Colle : un vrai défaut, corrigé.** J'avais écrit une branche dont le
  coup-clé est **b3**, donc le Colle-**Zukertort**, mais classée dans le
  chapitre « Colle-Koltanowski — c3 » — alors que le cours possède déjà un
  chapitre Zukertort. Le commentaire disait lui-même « la version Zukertort »
  à l'intérieur d'un chapitre Koltanowski. Branche reclassée, et surtout
  **complétée jusqu'à Fb2** : sans le fou sur la grande diagonale, `b3` n'est
  qu'un coup de pion perdu, et la branche montrait le prix du système sans en
  montrer la contrepartie. L'ordre suit désormais la forme canonique — `b3`
  AVANT le roque, pour n'avoir jamais à répondre à `…c4`.

Contrôle ajouté et passé : aucune branche à coup-clé `b3` ne subsiste dans un
chapitre Koltanowski, ni l'inverse.

**Leçon.** Écrire une ligne saine ne suffit pas : elle doit être rangée sous le
bon nom. Un lecteur qui révise le « Colle-Koltanowski » et tombe sur du b3
n'apprend pas un système, il apprend une confusion — et l'audit moteur, qui ne
juge que les coups, ne verra jamais ce défaut-là.

## Backlog vivant, repris de `plan-2008.md` avant sa suppression (22/08)

Le plan d'évolution a été supprimé sur demande. Ce qui suit est ce qu'il
contenait et qui n'existait NULLE PART ailleurs — le reste (chantiers A, B, C,
et les vérifications amont de D) est déjà consigné dans les sections
ci-dessus. Le fichier reste récupérable dans l'historique git si besoin.

### D.1 — Styles heuristiques, conception retenue (non commencé)

Rappel du fait établi le 21/08 : Stockfish n'a aucune option de personnalité,
`Contempt` ayant été retiré du moteur. Reclasser soi-même des coups candidats
est donc la seule méthode, pas un pis-aller.

- **D.1.a — `StyleMoveSelector`, module PUR.** `requestEngineMove` passe en
  MultiPV k=4 ; les candidats situés dans une fenêtre de tolérance par rapport
  au meilleur (≈50 cp en agressif, 30 cp en solide, à caler) sont rejoués sur
  un `Board` pour en extraire des traits, puis notés par style :
  - *Agressif* : échecs, captures, coups vers la zone du roi adverse, poussées
    côté roque adverse, sacrifices corrects bonifiés.
  - *Solide* : roque tôt, développement sans capture, refus de créer pion
    isolé ou doublé, maintien de la tension.
  - *Équilibré* (défaut) : sélecteur court-circuité — zéro régression possible.
  **Bénéfice croisé** : l'extracteur de traits de structure (pion isolé,
  colonne ouverte…) est exactement la brique des futures explications
  positionnelles. À écrire comme module partagé (`StructureTraits`), pas comme
  un privé du sélecteur.
- **D.1.b — Liste des styles** : Équilibré / Agressif / Solide. Trois
  seulement en v1 : chaque style supplémentaire multiplie le travail de calage.
- **D.1.c — Biais d'ouverture** : tags de style sur les nœuds
  d'`opening_book.json` (gambits et lignes tranchantes → agressif ; systèmes
  fermés → solide), multiplicateur de poids par style dans `OpeningBookEngine`.
- **D.1.d — Calage de la force au Laboratoire** : pour chaque style, ≥ 100
  parties style-ON contre style-OFF au même Elo ; `LabStats` donne l'écart Elo
  et son intervalle. Écart < ~50 Elo ⇒ une ligne d'avertissement dans l'UI ;
  plus grand ⇒ compensation documentée et re-mesurée. **Le harnais
  `EloCalibrationHarness`, conservé du chantier C abandonné, est l'instrument
  exact de ce lot.**
- **D.1.e — UI** : sélecteur de style dans `NewGameSetupView` avec une phrase
  par style ; `styleRaw` additif dans `PlayGameSettings` et l'autosave ;
  l'écran de fin de partie mentionne le style joué.
- **Piège à vérifier EN PREMIER** : l'interaction MultiPV × `UCI_LimitStrength`
  dans un moteur bridé — les variantes secondaires peuvent être incohérentes.
  Test de dérisquage : 20 positions, comparer la fenêtre de candidats bridé vs
  plein pot. Si inutilisable, repli : recherche plein pot à budget réduit pour
  la SÉLECTION, coup JOUÉ au niveau demandé.
- **Critères d'acceptation** : `StyleMoveSelectorTests` verts (reconnaissance
  ET non-reconnaissance par trait) ; série de calage commitée en CSV avec
  l'écart Elo ; `EngineLeakUITests` inchangé ; et surtout l'alerte gaffe, les
  indices et l'Analyste **prouvés insensibles au style** par test.

### E — Scanner de vrais échiquiers (non commencé, bloqué)

Étendre la reconnaissance — fiable aujourd'hui sur les diagrammes d'écran — aux
photos de plateaux physiques. C'est un problème de **données** avant d'être un
problème de code : le pipeline (BoardQuad, homographie, 64 vignettes, YOLO ×
gabarits, garde-fous, confirmation obligatoire) existe déjà de bout en bout.

- **E.1 — Le benchmark d'abord, préalable absolu, aucune ligne de modèle
  avant.** Jeu de test réel, étiqueté, versionné : 200–300 photos, variées en
  matériel (bois, plastique, vinyle de tournoi), sets, éclairages (jour, lampe,
  contre-jour) et angles — **verticale d'abord**, puis 30–60°. Chaque photo :
  FEN vérité terrain + les 4 coins. Sources : photos maison (**l'utilisateur
  doit fournir 30–50 photos de ses propres plateaux — c'est le point de départ,
  et le blocage actuel**), complétées par des jeux publics après vérification
  de licence. `scripts/yolo/eval_real.py` : par photo, détection du
  quadrilatère (IoU), précision par case et position exacte ; agrégats par
  angle/éclairage/matériel. **E.1 se termine par la mesure du modèle ACTUEL sur
  ce benchmark** : la baseline chiffrée, probablement mauvaise — c'est le but,
  savoir d'où l'on part.
- **E.2 — Générateur synthétique 3D.** Étendre le générateur 2D existant :
  rendus Blender headless (dans `tools/`, hors app) de sets Staunton 3D sous
  licence permissive vérifiée, textures bois/vinyle, éclairages et angles
  aléatoires (centrés sur la verticale ±20° en v1), annotations automatiques.
  Dizaines de milliers de plateaux. Domain randomization simple plutôt que
  réalisme parfait.
- **E.3 — Réentraînement + gate.** Entraînement hors-session (contrainte
  d'environnement documentée quatre fois le 19/07). **Gate de promotion**,
  industrialisation du processus qui a fait ses preuves avec le rejet de
  l'époque-9 : un modèle doit À LA FOIS améliorer `eval_real.py` ET ne pas
  dégrader le benchmark écrans existant. Échec à l'un des deux ⇒ rejet
  documenté.
- **E.4 — UX de capture guidée (verticale)** : overlay de cadrage carré,
  indicateur d'horizontalité (CoreMotion), déclenchement assisté quand le
  plateau remplit le gabarit. Réutilise le flux caméra existant. Confirmation
  obligatoire inchangée. Libellé honnête sur la limite : « fonctionne mieux à
  la verticale du plateau ».
- **E.5 — Plus tard, sous gate renouvelé** : angles obliques libres,
  occlusions partielles (main, pièces capturées en bord).
- **Seuil de livraison proposé, à confirmer par la mesure** : ≥ 97 % de
  précision par case et ≥ 60 % de positions exactes sur le benchmark vertical.
  Avec la confirmation obligatoire, c'est une expérience « je corrige deux
  cases » acceptable. Si la baseline en est loin, **le chantier continue sans
  rien livrer** — l'app ne promet rien aujourd'hui sur les vrais plateaux, ne
  pas promettre avant d'y être.

### Hors périmètre, décisions toujours en vigueur

- Tout appel réseau dans l'app (import Lichess/Chess.com, Explorer in-app,
  partage centralisé) : jalon 2.0 délibéré.
- Refonte `NavigationPath` → `[Route]` : remède potentiellement pire que le mal.
- Synchro des autosaves de parties en cours : deux appareils, deux parties en
  cours, aucune bonne réponse — documenté dans l'aide.
- Régénération automatique des cours par l'Explorer Lichess : jamais
  (décision du 16/08). L'Explorer est un informateur, pas un générateur.

## 1.5.0 build 7 : soumise et VALIDÉE par Apple le 20/08/2026

Elle est en ligne. Elle succède directement au build 3 de la 1.2 : ni la 1.3 ni
la 1.4 n'avaient été soumises, si bien que les utilisateurs ont reçu d'un coup
tout ce qui a été construit depuis le 9 août — module Ouvertures, répertoires
personnels, module Finales, entraînement libre, filtres, report de mode.

C'est aussi la fin d'un décalage qui s'était creusé : entre le 30 juillet
(dernière soumission réelle) et le 20 août, trois versions avaient été
préparées et documentées sans jamais partir. La documentation de soumission
l'affirmait encore ce matin — corrigé dans `METADATA.md` et
`RELEASE_NOTES-1.5.0.md`, qui disaient le contraire de la réalité et auraient
fait repartir la prochaine version d'une base fausse.

**Point de départ de la prochaine version : 1.5.0 build 7, en ligne.** Tout ce
qui a été livré depuis (chantiers B, C.0 et les lots de contenu A) est du
matériau pour la 1.6.

## Le plateau qui débordait de l'écran : c'était la barre de contrôle (22/08)

**Le signalement.** Nils envoie une capture ENTIÈRE — barre d'état, titre,
barre du bas — où le plateau sort de l'écran d'une demi-colonne de chaque
côté. iPhone 11 Pro, iOS 26.5.

**Le faux coupable, et ce qui l'a démasqué.** Le plateau n'y est pour rien :
sur la même capture, la pastille de « Ordinateur » est coupée à gauche, celle
de « Vous » aussi, et dans la barre du bas le chevron gauche ET le drapeau
sont rognés. **Tout est coupé symétriquement** — signature d'un conteneur plus
large que l'écran, centré, et non d'un plateau mal dimensionné.

**Le mécanisme.** `HStack(spacing: 10)` réserve ses écarts quoi qu'il arrive.
La rangée de contrôle de `PlayView` porte six boutons de 46 pt figés et six
écarts de 10 : **336 pt incompressibles**, mesurés à la décimale (voir plus
bas), soit **360 pt avec la marge du conteneur**. En dessous, la pile devient
plus large que l'écran et centre tous ses enfants à cheval sur les bords. Le
plateau, qui reprend la largeur de la pile et y ajoute ses 24 pt de bord à
bord, est simplement le plus visible des débordements.

**La largeur de Nils : 320 pt.** L'iPhone 11 Pro fait 375×812 pt en natif,
mais **320×693 en Zoom d'affichage**. 320 < 360 : débordement de 40 pt, 20 de
chaque côté — soit une case de 45 pt, ce qui recoupe la géométrie mesurée sur
sa capture.

**Pourquoi personne ne l'avait vu.** C'était écrit ici même, au Lot 3 du
13/08 : « Display Zoom (320 pt) : toujours pas reproductible par argument de
lancement, donc jamais mesuré », et « Vérifié — mesuré sur iPhone SE
(375 pt) ». `LayoutOverflowUITests.testNoOverflowOnPlayScreen` couvre pourtant
le bon écran : il n'a jamais tourné sous 375 pt. Aucun simulateur iOS 26 ne
descend à 320 — l'iPhone SE 1re génération, seul appareil de cette largeur,
est refusé par le runtime 26.5 (vérifié).

**Et la note du 15/08 était fausse.** « Les trois captures "plateau coupé sur
les bords" du testeur sont des recadrages […] Rien à corriger » : le
raisonnement — le plateau est volontairement bord à bord, donc exactement
large comme l'écran — n'était juste qu'à 375 pt. Le testeur signalait déjà
ceci.

**La correction.** La rangée sort de `PlayView` dans un type mesurable,
`PlayControlBar` — même parti pris que `BoardGeometry` : la géométrie qui pose
problème vit dans un type qu'un test peut instancier. L'espacement fixe cède
la place à un **écart élastique** (`Spacer(minLength: 0).frame(maxWidth: 10)`),
qui est un plafond et non un plancher : 10 pt tant qu'il y a la place, 0 quand
elle manque. Les boutons gardent leurs 46 pt — la cible tactile ne se négocie
pas, c'est l'écart qui cède. La pastille « Reprendre ici », seul élément dont
la largeur dépend d'un texte traduit, reçoit `minimumScaleFactor(0.7)`.

**Mesuré, avant et après** (`PlayControlBarLayoutTests`, hors interface : on
héberge la vraie vue et on lui propose les largeurs qu'aucun simulateur ne
sait produire) :

| | Avant | Après |
|---|---|---|
| Rangée, largeur incompressible | 336,0 pt | **276,0 pt** |
| Écran minimal supporté | 360 pt | **300 pt** |
| Écran *Jouer* entier proposé à 320 pt | réclame 440,0 pt | **tient** |
| Rendu à 375 pt | — | inchangé (`BOARD-RATIO 1.000`, capture vérifiée) |

**Ce que le test épingle en plus** : la largeur incompressible est désormais
« les six boutons, et rien d'autre ». Le jour où un septième bouton arrive,
`testIncompressibleWidthIsTheButtonsAlone` échoue — le message dit qu'il faut
en retirer un, pas rétrécir la cible tactile.

**Portée, mesurée et non supposée.** *Deux joueurs* passe à 320 pt (ses
capsules à texte se compriment) — même harnais, test dédié. Les barres
d'*Analyser* portent déjà un `ViewThatFits` depuis le Lot 3.2.

**Vérifié.** `PlayControlBarLayoutTests` : 6 tests verts, et **rouges avant
correction** (336 > 296) — la réplique fidèle de l'ancienne barre a été
remise en place le temps de le prouver. `LayoutOverflowUITests` (6) et
`KeyboardShortcutsUITests` (5) verts sur iPhone 11 Pro / iOS 26.5 : les
raccourcis ←/→, déplacés avec la rangée, fonctionnent toujours.

**L'instrument qui manquait, et qui existait.** Le Lot 3 avait renoncé faute
de pouvoir reproduire le Zoom d'affichage. Deux choses apprises ce jour :

1. **La largeur logique d'un appareil BRANCHÉ se lit sans rien installer** —
   `xcrun devicectl device info displays --device <id>` rend
   `bounds: (0, 0, 960, 2079)` et `pointScale: 3` pour l'iPhone de Nils, soit
   **320 × 693 pt** pour un panneau natif de 1125 × 2436. Le Zoom d'affichage
   se constate donc en une commande, en lecture seule, sans build ni profil de
   provisionnement. C'est l'outil à sortir au prochain signalement de mise en
   page : demander une capture, c'est deviner ; lire `displays`, c'est savoir.
2. **La piste « piloter Réglages depuis XCUITest » est morte** : l'app Réglages
   du simulateur n'a pas d'entrée « Luminosité et affichage » du tout (racine
   vérifiée en entier : Général, Accessibilité, Appareil photo, Apple
   Intelligence, Écran d'accueil, En veille, Recherche, Temps d'écran, Apps,
   Code, Confidentialité, Développement, Game Center, iCloud). Il n'y a donc
   rien à piloter, et le Zoom d'affichage restera hors de portée d'un test UI
   sur simulateur.

**Reste à faire.** Le garde-fou vit donc dans les tests unitaires — mesure de
la vraie vue en `UIHostingController` aux largeurs qu'aucun simulateur ne sait
produire — et non dans `LayoutOverflowUITests`. C'est une limite assumée, pas
un oubli.

## L'accueil à 320 pt : sept modes empilés, remis en deux colonnes (22/08)

**Suite directe du défaut ci-dessus, trouvé sur la même capture.** Une fois le
plateau réparé, l'accueil de Nils montrait toujours ses sept modes les uns
SOUS les autres, là où tous les autres iPhone les rangent en deux colonnes.

**La cause, du même genre : une largeur figée juste assez grande.**
`GridItem(.adaptive(minimum: 160))` avec 20 pt de marge de chaque côté réclame
2 × 160 + 14 = **334 pt pour 335 utiles à 375 pt** — un point de marge. À
320 pt il n'en reste que 280 : la grille adaptative renonce et retombe à une
colonne. Personne n'avait vu la marge d'un point, parce que personne n'avait
mesuré sous 375.

**La correction.** La géométrie de la grille sort de la vue dans
`ModeGridMetrics` — même parti pris que `BoardGeometry` et `PlayControlBar` —
et la largeur mini d'une tuile passe de **160 à 132 pt** : deux colonnes
tiennent dès 316 pt d'écran. Rien ne change au-dessus, la grille adaptative
n'ouvrirait une troisième colonne qu'à 424 pt utiles, hors d'atteinte d'un
iPhone en portrait (verrouillé depuis le Lot 2).

**Le compromis, regardé avant d'être accepté.** À 133 pt de large, la tuile
garde ses 132 pt de haut figés : il n'y reste la place que d'UNE ligne de
sous-titre, donc six sous-titres sur sept sont tronqués (« Force, cadenc… »).
**Le rendu d'avant a été mis à côté pour comparer : à 375 pt, quatre sur sept
le sont déjà.** La troncature est donc le registre existant du composant, pas
une nouveauté ; les titres, eux, restent entiers aux deux largeurs. Deux
colonnes tronquées valent mieux que sept tuiles empilées — mais si l'on veut
mieux, le levier est la copie (`shortSubtitle` existe déjà pour ça), pas la
géométrie.

**L'instrument, à garder.** `ImageRenderer` rend n'importe quelle vue à
n'importe quelle largeur, sans appareil ni simulateur :
`HomeGridLayoutTests.testRenderGridPreviews` écrit les PNG de la grille à 320
et 375 pt, plus le rendu d'avant. Inerte par défaut, activé par
`CHESSLAB_RENDER_PREVIEWS=1`. Avec `devicectl … displays` (largeur réelle d'un
appareil branché) et la mesure en `UIHostingController` (largeur réclamée par
une vraie vue), c'est le troisième outil que ce signalement aura apporté — et
ensemble ils couvrent enfin le trou du Lot 3.

**Vérifié.** `HomeGridLayoutTests` : la hauteur rendue par `LazyVGrid` lui-même
à 320 pt prouve les deux colonnes (c'est SwiftUI qui tranche, pas une
arithmétique parallèle), et un garde-fou en sens inverse interdit une
troisième colonne à 440 pt. `LayoutOverflowUITests` (5) vert, détecteur de
débordement de l'accueil compris.

## Chantier A, lots 29-31 : Scandinave, London, Nimzo-Larsen (nuit du 22-23/08)

Deux lots menés d'affilée, et une leçon de méthode qui vaut plus que les deux.

### Lot 29 — Scandinave : un seul thème, cinq ordres de coups

Le rapport de couverture ne montrait pas 47 trous dispersés : **cinq des douze
plus coûteux étaient le MÊME coup blanc** — Fc4, Fe2 ou Cf3 joué avant d4 —
dans cinq ordres différents. Le club développe avant de pousser ; le cours ne
prévoyait que la poussée. Six lignes écrites d'un coup, commentées FR+EN.

**Un arbitrage contre le moteur, assumé.** Sur 3…Dd6 4.Cf3 Cf6 5.Fc4, le
moteur classe 5…Cc6 en tête et 5…a6 cinquième, à 0,2 de pion. On enseigne
**…a6** : ce chapitre annonce le système de Tiviakov (…a6, …b5, …Fb7), et
changer de plan trois coups après l'avoir annoncé n'apprend rien à personne.
Ailleurs, la règle du cours — « le fou de cases blanches sort AVANT …e6 » —
coïncidait avec le moteur à 0,05 près, donc rien à arbitrer.

**Mesuré** : positions 190 → 248, commentaires 66 → 86. La dette annoncée d'abord
(0,95 → 0,67, −29 %) était une mesure HORS LIGNE des deux côtés — voir la
section « Le biais de la mesure hors ligne » plus bas : la vraie baisse,
mesurée en ligne avant ET après, est de **1,44 → 1,34, soit −6,7 %**. `audit.py` : 0 gaffe enseignée, 0 arête suspecte.
Sur la session complète du 21-22/08, la Scandinave passe de **1,70 à 0,67**,
soit **−61 %**.

### Lot 30 — London : le piège du signe, et l'arbitrage qu'il a failli fausser

Même méthode sur la London, redevenue la pire dette du catalogue (0,97). Cinq
trous, dont **deux fois …Ff5** : le fou noir sort avant que le système soit
posé.

**L'erreur de lecture, attrapée à temps.** `suggest.py` rend son score
**relatif au trait** (`score.pov(board.turn)`). En forçant un coup blanc pour
le mesurer, on lit donc la position *les Noirs au trait* — et un `-0,30`
signifie « les Noirs sont 0,30 moins bien », c'est-à-dire **les Blancs mieux**.
Lu à l'envers, le tableau disait que le système Londres perdait 0,6 à 0,75 de
pion et donnait l'avantage aux Noirs ; j'ai failli enseigner c4 partout sur
cette base. Le vrai tableau après 1.d4 d5 2.Ff4 Cc6 3.e3 Ff5 :

| coup | avantage blanc |
|---|---|
| 4.c4 — quitte le système | +0,44 |
| **4.Fd3 — le système** | **+0,30** |
| 4.Cf3 | +0,26 |
| 4.c3 | +0,16 |

0,14 de pion, pas 0,7. **On garde Fd3**, conformément à la règle posée pendant
la campagne du 16/08 : le meilleur coup du moteur n'est pas toujours le bon
coup du répertoire. Dans l'autre ordre (2…Cf6 3.e3 Ff5), l'écart tombe à 0,05
— autant dire rien.

**Un fait désagréable, écrit plutôt que masqué.** Jobava, 2.Cc3 e6 3.Ff4 Fb4 :
le meilleur coup (4.Dd3) ne donne QUE l'égalité (−0,06), et les alternatives
sont pires. Le commentaire du cours le dit franchement — mieux vaut le savoir
avant la partie qu'après.

**Un détail de rédaction, refusé.** Le moteur voulait 7.Fc4 puis 8.Fe2 dans la
ligne …g6 : un fou qui fait l'aller-retour. On joue 7.Fe2 directement, pour
0,08 de pion. Une ligne d'enseignement doit pouvoir se raconter.

**Mesuré** : positions 152 → 200. Là encore le −35 % annoncé était hors ligne
des deux côtés ; en ligne, **1,20 → 1,06, soit −12,3 %**.
`audit.py` : 1 arête suspecte, contre-mesurée à la profondeur 24, 0 gaffe
enseignée.

### État du catalogue après les deux lots

Trois lots au total cette nuit (29 Scandinave, 30 London, 31 Nimzo-Larsen),
et une mesure EN LIGNE des trois, avant et après, une fois le jeton Explorer
disponible :

| cours | avant | après | écart |
|---|---|---|---|
| scandinavian | 1,44 · 84 trous | **1,34 · 91 trous** | −6,7 % |
| london-system | 1,20 · 47 trous | **1,06 · 59 trous** | −12,3 % |
| nimzo-larsen | 1,39 · 43 trous | **1,32 · 57 trous** | −5,1 % |

## Le biais de la mesure hors ligne (23/08)

**Le fait.** Un jeton Explorer a été fourni dans la nuit. Les mêmes cours,
mesurés en ligne, portent une dette **environ deux fois** supérieure à celle
que rendait `--offline` : 1,34 contre 0,67 pour la Scandinave, 1,06 contre
0,63 pour la London.

**Pourquoi ce n'est pas seulement une question de niveau.** Le Lot 1 du 21/08
justifiait le mode hors ligne ainsi : « le rapport ne peut donc que
sous-estimer la dette, jamais l'inverse — c'est le bon côté sur lequel se
tromper pour une mesure d'avancement. » **Ce raisonnement est faux pour un
écart.** Sous-estimer le NIVEAU est sans danger ; comparer deux
sous-estimations ne l'est pas, parce que le biais n'est pas constant : chaque
lot crée des positions neuves, absentes du cache par construction, dont les
trous restent donc invisibles. Le biais grandit avec le travail fourni, et
toujours dans le sens flatteur.

**L'ampleur, mesurée.** Sur les trois lots de cette nuit, l'écart annoncé hors
ligne était de −29 %, −35 % et (non publié) −33 % ; l'écart réel est de
−6,7 %, −12,3 % et −5,1 %. **Le mode hors ligne a multiplié le progrès apparent
par trois à cinq.**

**Ce que ça implique pour le chantier A.** Les 28 lots des 21 et 22/08 ont tous
été mesurés hors ligne, des deux côtés. Leurs baisses consignées — la
Nimzo-Larsen « 1,83 → 0,93, −49 % » en tête — sont donc à lire comme des
ordres de grandeur flatteurs, pas comme des mesures. Le contenu écrit, lui,
reste bon : il a été calculé au moteur et passé à `audit.py`. C'est la
comptabilité du progrès qui était optimiste, pas les lignes.

**Règle pour la suite** : toute annonce de baisse de dette se mesure EN LIGNE,
avant et après, sur la même version de l'outil. Le mode `--offline` reste utile
pour CLASSER les cours entre eux à un instant donné (le biais y est à peu près
le même partout), jamais pour mesurer un progrès.

### Lot 31 — Nimzo-Larsen : une habitude du cours prise en défaut

Cinq trous comblés, dont le plus fréquent du chapitre …e5 (47 % des parties à
cet endroit, aucune réponse). Et une trouvaille qui vaut pour tout le cours :
après 1.b3 e5 2.Fb2 Cc6 3.e3 Cf6 4.Fb5 d6, **le cours aurait joué Cf3 — il le
joue douze fois ailleurs et n'a jamais joué Ce2 — et c'est une erreur ici** :
avec le pion noir en e5, Cf3 invite …e4 avec tempo. Mesuré : **Ce2 +0,25,
Cf3 −0,10**, un tiers de pion. L'habitude, pas le moteur, était fautive. Le
commentaire du cours l'explique désormais, chiffres compris.

`audit.py` : 0 arête suspecte, 0 gaffe enseignée, 188 positions.

**Vérifié** : `OpeningBlunderRegressionTests` (2 tests, 15 cas) et
`EcoOpeningLookupTests` verts depuis le bundle — 8 tests, 2 suites.

**Piège d'outillage à retenir.** Un filtre `-only-testing` sur une suite
**swift-testing** rapporte « TEST SUCCEEDED » avec *Executed 0 tests* si l'on
ne lit que les lignes XCTest : le vrai verdict est dans les lignes `✔ Test run
with N tests`. J'ai cru la suite verte une première fois alors qu'elle n'avait
pas tourné.

## Revue HIG complète de l'interface (nuit du 22/08)

Demande : revoir l'UI avec la compétence `apple-hig` installée dans la journée.

**Premier constat, méthodologique** : la compétence installée n'était qu'une
**fiche de catalogue** — elle annonce le contenu et renvoie à l'amont sans rien
embarquer. Le vrai matériel est `raintree-technology/hig-doctor`, 11 modules,
~500 Ko de références HIG indexées. Installé, et c'est lui qui a servi.

Ce qui suit est classé par **impact utilisateur × certitude**, et distingue ce
qui est MESURÉ de ce qui relève du jugement.

### A — Accessibilité : le gros morceau

**A1. Le VoiceOver du plateau est monolingue français.** `ChessBoardView`
(`accessibilityLabel(for:)`) renvoie « Case e4, cavalier blanc » en dur, et
`MoveNarration` porte un dictionnaire `"N": "cavalier"` tout aussi figé.
**Vérifié : aucune de ces chaînes n'est au catalogue** — les deux occurrences
de « Case » dans `Localizable.xcstrings` concernent l'aide sur la prise en
passant. Un anglophone qui active VoiceOver entend donc du français sur
l'élément central de l'app. C'est exactement la famille du défaut corrigé le
19/08 (« Ordinateur » collé en littéral malgré la clé existante), mais sur la
couche la moins visible à l'œil — donc la moins susceptible d'être repérée.

**A2. L'étiquette de case ne dit que la pièce, jamais l'état.** Ni
« sélectionnée », ni « coup légal », ni « dernier coup », ni « roi en échec ».
Or les cibles légales ne sont signalées QUE par une pastille colorée. HIG
accessibility : *« Convey information with more than color alone »* et
*« Describe your app's interface and content for VoiceOver »*. **Conséquence
concrète : l'app n'est pas jouable en VoiceOver** — on peut lire le plateau,
pas savoir où l'on a le droit d'aller. A1 et A2 se corrigent ensemble.

**A3. Contraste — deux valeurs sous les seuils, mesurées sur `Theme.swift`.**

| | ratio sur `background` | seuil | verdict |
|---|---|---|---|
| `textPrimary` (blanc 95 %) | 17,16:1 | 4,5 | OK |
| `textSecondary` (blanc 58 %) | 6,81:1 | 4,5 | OK |
| **`textTertiary`** (blanc 38 %) | **3,56:1** | 4,5 | **sous le seuil** (corps de texte) |
| **`stroke`** (blanc 8 %) | **1,21:1** | 3,0 | **sous le seuil** (élément porteur de sens) |
| `strokeStrong` (blanc 16 %) | 1,58:1 | 3,0 | sous le seuil |

Les huit teintes (accent, danger, warning, info, violet, rose, gold, teal)
sont toutes ≥ 5,80:1 — la palette de couleur est saine, c'est la palette de
GRIS qui pèche. Correctifs chiffrés : `textTertiary` à blanc 50 % donne
≈ 4,6:1 ; une bordure qui porte du sens (contour d'un bouton rond) demande
blanc ~30 %.

**A4. Dynamic Type : 29 tailles figées contre 6 mises à l'échelle.** Le helper
`scaledSystemFont` existe et porte le `@ScaledMetric` — il n'est utilisé que
six fois. Les glyphes de pièces, les pastilles de qualité et les boutons ronds
ne grossissent pas. HIG typography : *« Increase the size of meaningful
interface icons as font size increases »*. Déjà consigné au Lot 3 comme
chantier de fond ; toujours ouvert, et désormais chiffré.

**A5. Reduce Motion : deux usages, tous deux dans `ChessBoardView`.** Les
animations `Theme.spring` / `Theme.gentle`, utilisées dans toute l'app, ne sont
conditionnées nulle part. HIG motion : *« Make motion optional »*. Correctif
peu risqué et centralisable, puisque toutes les animations passent par `Theme`.

**A6. Ce qui va bien, et qu'il faut dire.** Les pastilles de qualité de coup
portent un SYMBOLE (`!!`, `★`, `✓`, `✕`), pas seulement une couleur — le point
le plus exposé au daltonisme est déjà traité. `EvalBarView` expose
`accessibilityLabel` + `accessibilityValue`. 50 `accessibilityLabel`, 79
identifiants de test, 27 `accessibilityElement`. Les flèches d'indice, elles,
restent purement visuelles.

### B — Mise en page et adaptabilité

**B1. La leçon du jour, généralisée.** HIG layout liste explicitement
*« External display support, **Display Zoom**, and resizable windows »* parmi
les contextes à supporter. Deux défauts trouvés à 320 pt aujourd'hui (le
plateau, puis l'accueil). Les autres écrans n'ont **jamais** été mesurés à
cette largeur — sauf *Deux joueurs*, mesuré ce soir et conforme. Restent :
Puzzles, Analyser, Ouvertures, Finales, Laboratoire, Réglages, Éditeur de
position, Scanner. **C'est le lot n°1 de la suite**, et l'outillage existe
maintenant pour le faire en série.

**B2. Portrait verrouillé sur iPhone** — HIG iOS : *« Aim to support both
portrait and landscape orientations »*. Déviation assumée au Lot 2, pour une
raison solide (aucun layout paysage n'existait, `verticalSizeClass` n'était lu
nulle part). À reverser un jour : un échiquier est précisément l'app où le
paysage a du sens, et la disposition existe déjà côté iPad (plateau à gauche,
lecture à droite).

**B3. 90 `frame(maxWidth: .infinity)`** — HIG iOS : *« Avoid full-width
buttons »*. La majorité sont des conteneurs, pas des boutons ; à trier au cas
par cas, faible priorité.

### C — Composants, conventions, écriture

Rien de grave, et plusieurs bons points : **97 SF Symbols contre 4 images
custom** ; 14 rôles `.destructive` déclarés sur les confirmations ; 15
raccourcis clavier iPad ; 40 points d'haptique ; la barre d'état n'est jamais
masquée. **La capitalisation des 53 libellés de bouton est uniforme** (capitale
au premier mot seulement) — HIG : *« adopt capitalization rules, then apply
them consistently »*, c'est fait.

Seul point : `presentationDetents` n'est posé que sur 4 des 13 feuilles. Les
autres s'ouvrent en pleine hauteur alors qu'un `.medium` laisserait voir la
position derrière — HIG dialogs, sur les feuilles non modales.

### D — Revue écran par écran (33 vues)

**D1. Le composant `List` est quasi absent.** Trois usages dans toute l'app —
la barre latérale iPad, la liste d'ouvertures, la liste de finales — contre 27
fichiers qui bâtissent leurs listes en `ScrollView` + `VStack`. La conséquence
se mesure : `swipeActions` / `onDelete` n'apparaissent que **deux fois** dans
tout le projet. La bibliothèque de parties réimplémente à la main la sélection
multiple (`Set<PersistentIdentifier>`, coche dessinée, trait `.isSelected`
posé explicitement — c'est du travail soigné), mais **on ne peut pas supprimer
une partie d'un balayage** : il faut d'abord entrer en mode sélection. HIG
`lists-and-tables` donne le balayage, l'`EditMode`, la sémantique VoiceOver de
rangée et la navigation clavier sans rien écrire. C'est le plus gros écart
structurel de l'app — et le plus coûteux à reprendre, donc à décider, pas à
faire dans la foulée.

**D2. Le curseur de force n'a aucune étiquette d'accessibilité.**
`NewGameSetupView` pose un `Slider(value:in:step:)` nu : ni
`minimumValueLabel`, ni `accessibilityLabel`, ni `accessibilityValue` — et
l'écran entier ne contient **aucun** `accessibilityLabel`. C'est le contrôle
principal du mode principal, et en VoiceOver il s'annonce « 47 % » sans dire
de quoi. Correctif de trois lignes.

**D3. Rien n'accueille le nouvel utilisateur.** Zéro TipKit, zéro drapeau de
premier lancement, aucune astuce contextuelle : sept modes sont posés d'un coup
sur la grille d'accueil. L'app a pourtant une aide complète — mais rien ne la
déclenche au moment où elle servirait. HIG `onboarding` recommande justement
des astuces contextuelles plutôt qu'un tunnel d'accueil.

**D4. « Vider » détruit la position sans confirmation ni annulation.** Dans
l'éditeur, `clearBoard()` part directement du bouton. HIG `feedback` : prévenir
avant une perte de données inattendue et irréversible. L'annulation n'existe
nulle part ailleurs que dans le lecteur d'ouvertures (`OpeningReaderViewModel`).

**D5. Les écrans vides sont majoritairement bons.** Plusieurs donnent la marche
à suivre — « Ouvre une ouverture et entraîne-la pour remplir ta file »,
« Ajoutez-en pour retrouver et regrouper vos parties ». Deux restent muets
(« Aucun coup joué », « Aucune partie sur cette période »). Point mineur.

**D6. Et ce qui est conforme, écran par écran.** Barre latérale iPad en
`List(selection:)` — le bon composant ; barres d'outils en `ToolbarItemGroup` ;
19 alertes/dialogues dont 14 avec rôle destructif ; 13 `ProgressView` répartis
sur les attentes réelles (scanner, laboratoire, entraînement) ; aucun
`pickerStyle` exotique ; le réglage de langue offre bien l'option « Langue du
système », donc ne double pas le réglage système ; la barre d'état n'est jamais
masquée.

### Ce que la revue N'A PAS couvert

Par honnêteté sur la portée : les modules `hig-technologies` et
`hig-components-system` (widgets, complications, Siri, App Intents) n'ont pas
été lus — l'app n'expose aucune de ces surfaces. Le volet macOS/Catalyst n'a
été regardé que par les clés du projet, sans exécution. Et les huit écrans
listés en B1 n'ont pas encore été MESURÉS à 320 pt : ils sont conformes en
lecture, pas en mesure.

### L'ordre dans lequel je traiterais tout ça

1. **A1 + A2** — le plateau en VoiceOver, bilingue et avec son état. C'est le
   seul point de la liste qui rend une fonction ENTIÈRE inaccessible, et c'est
   deux fichiers.
2. **A3** — deux constantes à changer dans `Theme.swift`, mesure à l'appui.
3. **B1** — passer les huit écrans restants au harnais 320 pt.
4. **A5** — Reduce Motion centralisé dans `Theme`.
5. **D2** — l'étiquette du curseur de force : trois lignes, mode principal.
6. **D4** — la confirmation sur « Vider ».
7. **A4** — Dynamic Type des gabarits figés : le vrai chantier, à planifier.
8. **D1** — le passage à `List` : à décider avant de faire, c'est une refonte.
9. **D3** — les astuces contextuelles : décision produit.

## Stockage sur appareil : 388 Mo signalés, 328 d'accumulation (22/08)

**Le signalement.** Un utilisateur rapporte 388 Mo de « Documents et données ».

**La mesure, sur conteneurs RÉELS et non par estimation.** Une installation
NEUVE du build courant pèse **60 Mo** : `Puzzles.store` 57,4 (106 094 puzzles
insérés depuis 17,9 Mo de JSON, facteur ×3,2) et `Games.store` 0,1. L'app se
comporte donc correctement sur un téléphone neuf — les 328 Mo restants étaient
de l'accumulation historique.

**Piège de méthode, attrapé de justesse.** Ma première mesure installait un
binaire du 21 JUILLET traîné dans DerivedData. Elle m'a fait « découvrir » que
l'app actuelle créait un `default.store` au lieu des stores nommés — un faux
bug alarmant, entièrement dû à mon propre outil de mesure. Le contrôle qui a
sauvé le rapport : le store fraîchement créé contenait des entités disparues
(`ZREPERTOIRE`) et PAS les champs ajoutés la veille. **Vérifier la date du
binaire avant de conclure quoi que ce soit d'une mesure sur simulateur.**

**Les deux gisements, et leur correction (`LocalStoreMaintenance`).**

1. **`default.store` — 58 Mo de déchet pur.** L'ancien store unique d'avant la
   séparation Games/Puzzles : 106 094 puzzles en DOUBLE et des entités mortes.
   Le code ne l'ouvrait jamais ; le seul chemin qui le mentionnait était la
   quarantaine, qui ne s'exécute qu'après deux échecs consécutifs. Désormais
   supprimé au démarrage — mais SEULEMENT si un store nommé existe, garde-fou
   contre une future refonte qui reviendrait à un store unique.
2. **`StoreQuarantine` — jusqu'à 240 Mo invisibles.** Chaque quarantaine
   archivait les trois stores (~120 Mo) et la rotation en gardait deux, sans
   limite d'âge ni moyen pour l'utilisateur de les voir. Désormais : une seule,
   périmée à 14 jours, et **`Puzzles.store` n'y est plus archivé mais
   supprimé** — 57 Mo régénérables depuis le bundle n'ont jamais rien
   diagnostiqué. `Games.store`, qui porte les données réelles, reste archivé
   intégralement.

**Un détail qui a compté.** L'expiration se fondait d'abord sur la date de
modification du fichier. Le test de bout en bout l'a démasqué : une quarantaine
injectée survivait, sa mtime étant celle du jour. Or c'est exactement le cas
d'un téléphone RESTAURÉ depuis une vieille sauvegarde — tous les fichiers y
portent une date récente. L'âge se lit maintenant dans le NOM du dossier, qui
est un horodatage ISO 8601 écrit à la mise en quarantaine, avec repli sur la
mtime si le nom est illisible.

**Vérifié.** 11 tests unitaires sur dossier jetable (dont les cas de travers :
refus de purger sans preuve de séparation, nom illisible, dossier absent), et
une mesure de bout en bout sur l'app réelle : conteneur **175 Mo → 60 Mo** au
premier lancement. 628 tests verts.

**Non traité, documenté pour plus tard.** `solutionLANs: [String]?` est
sérialisé en bplist NSKeyedArchiver : une solution de 19 caractères utiles
occupe 262 octets, soit 26,6 Mo — près de la moitié de la table des puzzles.
Le passer en chaîne unique rendrait ~25 Mo pour un changement de schéma
additif. `AnalysisCache/` est dans Application Support et non dans Caches :
iOS ne peut donc jamais le purger sous pression, et il part dans les
sauvegardes. Et `OpeningReviewLog` est append-only dans le store SYNCHRONISÉ,
sans aucun élagage — inoffensif en local, coûteux dans CloudKit où chaque ligne
porte un enregistrement système de 0,5 à 2 Ko.

## Module « Ouvertures — Labs » : la même théorie, disséquée (23/08) ✅

Aperçu OPT-IN, éteint par défaut, qui ajoute une tuile d'accueil et une entrée
de barre latérale sans rien retirer : le module Ouvertures en production reste
l'expérience par défaut. Deux écrans, et une chaîne de données neuve.

### Écran A — l'index des lignes, en ARBRE

Refondu le 23/08 sur croquis de l'utilisateur. La première version listait un
chapitre par carte, chacun repartant de la racine : « 1.e4 d5 2.exd5 ♛xd5 » se
relisait douze fois avant d'arriver à ce qui distingue les variantes. L'index
est maintenant un **arbre du graphe** — chaque coup écrit UNE SEULE FOIS :

    1.e4 d5
      ↳ 2.exd5
          ○ 2…♛xd5
              □ 3.♘c3
                  ◇ 3…♛a5
                      △ 4.d4 ♞f6
                          ⬡ 5.♘f3 c6 6.♗c4 ♗f5 7.♗d2 e6
                          ⬡ 5.♗d2 ♗g4 6.f3 ♟d7 …
                      △ 4.♘f3 ♞f6              ← 4.Cf3 avant d4
                      △ 4.b4 ?! ♛xb4 5.♖b1 …   ← Le gambit 4.b4
                  ◇ 3…♛d6 …                    ← Moderne, 3…Dd6
              □ 3.♘f3 ♗g4 …
          ○ 2…♞f6 …                            ← 2…Cf6, l'ordre moderne
      ↳ 2.e5 ?! ♗f5                            ← Les Blancs déclinent

Notation **figurine** (le dessin de la pièce, pas sa lettre : la notation
devient indépendante de la langue, ce qui compte sur un écran qui aligne des
centaines de coups). L'index s'ouvre tout seul en entrant dans une ouverture et
se rappelle par l'icône de la barre.

**Chaque coup est un bouton** : taper le 7ᵉ coup du Fried Liver amène
directement à cette position, fil des coups déjà rempli. C'est ce qui a dicté
l'architecture du lecteur (voir plus bas).

**Une rangée s'arrête à la première DÉVIATION**, et toutes les suites — la
principale comprise — descendent d'un étage. Chaque rangée répond ainsi à une
seule question : « à cette position, quels sont les choix ? ».

Conséquence à assumer : dans un cours qui offre des alternatives dès le
deuxième coup, les premières rangées ne portent qu'un ou deux coups. Ce n'est
pas un défaut d'affichage, c'est l'arbre réel de l'ouverture. J'avais d'abord
pris cet escalier pour un défaut et prolongé la ligne principale à plat
par-dessus les déviations — l'utilisateur a corrigé : cela ment sur l'endroit
où le choix se pose.

**La ligne principale est dépliée AVANT ses alternatives.** 🐛 Sans cette
priorité, une variante qui transpose plus loin dans la ligne principale
réclamait la position avant elle, et c'était la ligne principale qui s'arrêtait
sur un « transposition » — l'inverse de ce qu'on veut lire. Vérifié sur un cas
construit, parce que c'est l'ORDRE D'EXPANSION qu'on veut prouver et qu'il ne
se lit pas dans l'arbre fini : sur la donnée livrée, un rang 0 peut
légitimement transposer vers une position dépliée bien plus tôt, ailleurs.

**Un marqueur par ÉTAGE** (``BranchMarker``) : ↳ ○ □ ◇ △ ⬡, du bleu clair au
violet, plus un rail vertical par niveau traversé. Forme ET couleur, pas l'une
ou l'autre — la couleur seule ne se distingue pas en niveaux de gris ni pour un
daltonien, la forme seule se confond à 8 pt. Le retrait est proportionnel à
l'étage, plafonné à cinq niveaux dessinés ; le marqueur, lui, continue de
distinguer au-delà.

**Les transpositions ne sont dépliées qu'une fois.** La seconde arrivée s'arrête
sur un repère « transposition » cliquable. Sans cette règle, des sous-arbres
entiers apparaîtraient en double — exactement ce que l'arbre supprime — et un
cycle ferait tourner la construction sans fin.

**Les titres écrits à la main sont conservés**, posés sur la branche que leur
chapitre OUVRE. Un chapitre est un chemin, l'arbre est fait de nœuds : il n'y a
pas de correspondance directe. La règle retenue après essais sur la donnée
réelle est celle du **point de divergence** — la première branche de sa colonne
vertébrale qui n'est pas le coup principal de sa position. Elle donne, sans
exception notable : Gambit Evans → 4.b4, Fried Liver → 6.♘xf7, Défense
hongroise → 3…♗e7, Attaque Panov → 3.exd5, Karpov → 4…♞d7. Un chapitre qui ne
quitte jamais la ligne principale n'obtient pas de titre, et c'est correct : la
carte porte déjà le nom de l'ouverture, et c'est de lui qu'il parle.

**Un seul marqueur par pastille : le verdict du moteur.** L'index portait trois
pictogrammes concurrents (coup commenté, coup à mémoriser, rôle) ; sur une
carte de cinquante coups, plus rien ne ressortait. Ne restent que cinq
catégories — gaffe, erreur, imprécision, occasion manquée, coup brillant — en
notation d'échecs (`??`, `?`, `?!`, `!!`), calculées à partir des évaluations
pré-calculées du sidecar (``OpeningMoveQuality``). Mesure sur le catalogue :
**97,2 % des coups ne portent aucune marque**, 166 imprécisions, 25 erreurs,
7 gaffes, 2 coups brillants.

Le contrôle qui valide toute la chaîne : sur le gambit **Englund**, le moteur
retrouve seul 6.♗c3?? (gaffe) ET 6…♗b4! (brillant) — les deux coups du piège,
indépendamment de ce que l'auteur du cours avait marqué. Chaque gaffe détectée
coïncide d'ailleurs avec un coup que l'auteur avait étiqueté « piège ».

### Écran B — le lecteur

Échiquier ancré en haut (jamais dans le défilement : on lit les statistiques EN
REGARDANT la position), flèches vertes/bleues du répertoire conservées, et une
barre d'évaluation **fine** (7 pt) collée dessous, avec la profondeur du calcul
en regard. En dessous, défilant — ou à droite si la fenêtre est plus large que
haute, iPad et Mac compris : fil des coups, commentaire de l'auteur, coups du
répertoire, **coups des maîtres avec leurs pourcentages**, et les **trois
meilleurs coups de Stockfish**.

**Aucun moteur ne tourne sur cet écran.** Tout est pré-calculé (voir la donnée).
Un Stockfish embarqué donnerait les mêmes chiffres après plusieurs secondes,
en chauffant l'appareil, et redémarrerait à chaque coup.

**Labs LIT, il n'entraîne pas.** Un coup de maître hors répertoire s'affiche
(c'est une information) mais n'est pas un bouton : il n'y aurait ni suite, ni
commentaire, ni statistique derrière. L'entraînement en répétition espacée
reste celui du module Ouvertures — un seul moteur FSRS, une seule progression.

### La donnée : un SIDECAR, pas un champ de plus

`ChessLab/Resources/openings_labs/<id>.labs.json`, écrit par
`tools/opening-generator/labs.py`, indexé par la même FEN normalisée que le
graphe. Trois raisons de ne pas enrichir les cours eux-mêmes :

1. **Risque.** Y ajouter des champs fait porter une régression possible à un
   module en production, pour un module en aperçu.
2. **Ce n'est pas la même donnée.** `MoveEdge.gamesMasters` ne décrit que les
   arêtes CURÉES du graphe ; Labs veut tous les coups de maîtres de la position.
3. **Coût.** Chargement paresseux, un seul sidecar en mémoire, et rien du tout
   pour qui n'allume pas l'aperçu.

**Mesuré, chaîne complète exécutée.** 4 980 positions distinctes pour les 58
ouvertures (5 727 entrées de cours, les transpositions fusionnent).

- **Moteur** : MultiPV 3 à profondeur 20, **75 min** sur M2 à 4 travailleurs,
  **100 % des positions couvertes**. Intégralement mis en cache disque —
  relancer ne recalcule rien.
- **Maîtres** : 61,8 % des positions étaient déjà dans le cache partagé avec
  `generate.py` ; les 1 697 manquantes ont été rattrapées en 4 133 requêtes,
  **zéro échec**. Résultat : **85,5 % des positions ont des parties de maîtres**,
  et les 14,5 % restantes ont bien été interrogées — elles n'ont simplement
  **aucune partie de tournoi**, ce qui est la réalité de la base et non un trou
  à combler.
- **Poids** : 58 fichiers, **2,6 Mo** ajoutés au bundle.

**Sans jeton, la chaîne ne casse pas** : mode cache seul, les positions absentes
n'ont pas de bloc `masters`, et l'app le DIT (« aucune partie de maître connue
pour cette position ») au lieu d'inventer un chiffre.

**Les pourcentages ne sont pas stockés.** Ils se dérivent des parties, et se
rapportent au TOTAL de la position, pas à la somme des coups retenus : le
générateur écarte la queue statistique (sous 0,5 %), et renormaliser sur les
survivants afficherait 100 % là où il en manque cinq.

### Trois choses apprises en chemin

**Le bug qui masquait une variante entière.** L'identité d'une rangée était
(demi-coup, coup) de son premier coup. Dans la scandinave, deux branches
partent toutes deux de « 4…♞f6 » et ne divergent qu'au coup blanc suivant
(5.d4 / 5.♗c4) : même identité, donc `ForEach` affichait la première DEUX FOIS
et la variante 5.♗c4 disparaissait de l'index, en silence. Trouvé à la capture
d'écran, pas au test. L'identité est désormais le CHEMIN complet, et deux tests
la verrouillent — dont un qui balaie tout le catalogue.

**La capture d'écran a trouvé ce que les tests ne cherchaient pas.** Ce bug-là,
puis la troncature ci-dessous, puis le tronc coupé par une transposition : les
trois ont été vus à l'œil sur une capture, jamais signalés par une assertion.
Chacun a ensuite reçu son test de non-régression. Les tests disent que ce qu'on
a pensé à vérifier tient ; ils ne disent pas ce que l'écran donne à lire.

**La troncature en `FlowLayout`.** « ♞f6 » s'affichait « ♞… » : un `Text` posé
à sa largeur idéale exacte se rabat sur l'ellipse à un arrondi de rendu près.
`FilterChip` documentait déjà le piège (« Blancs » → « Blan/cs ») ; même
remède, `.lineLimit(1)` + `.fixedSize(horizontal: true, vertical: false)`.

### Vérifié

54 tests unitaires neufs (notation figurine, arbre des lignes, verdicts du
moteur, sidecar, lecteur), dont sept qui balaient la donnée RÉELLEMENT
embarquée : tout chemin de l'arbre se rejoue dans le graphe, le tronc n'est
jamais tronqué par une variante, aucun coup n'apparaît deux fois, tout
identifiant est unique, l'arbre reste borné en rangées et en profondeur, toute
position de sidecar existe dans son cours, tout coup du moteur est légal dans
sa position. **682 tests verts au total**, plus 4 tests d'interface qui
parcourent
l'interrupteur, le saut depuis l'index, les trois sections du lecteur et la
DISPOSITION (panneau sous le plateau en portrait, à droite en paysage — mesurée
géométriquement, et ignorée sur iPhone où la cible est verrouillée en portrait).
Passés sur iPhone 17 Pro ET iPad Pro 11", les deux ossatures d'accueil : la
grille de tuiles et la barre latérale n'exposent pas le même point d'entrée.

### Reste à faire

- **Couverture maîtres partielle en profondeur** : une position de sous-variante
  au 20ᵉ demi-coup n'a jamais été jouée en tournoi, et n'en aura jamais. C'est
  la réalité de la base, pas un trou à combler.
- **Les 58 sidecars pèsent quelques Mo** ajoutés au bundle. À surveiller au
  prochain bilan de stockage — c'est de la donnée statique, jamais recopiée
  dans le conteneur.

## Ouvertures : le module Labs remplace l'ancien (23/08) ✅

Décision de l'utilisateur après essai : le module en aperçu DEVIENT le module
Ouvertures. L'ancien écran est supprimé, le nouveau reprend son nom, son icône
(`books.vertical.fill`, teinte ambre) et **ses identifiants d'accessibilité** —
c'est toujours « Ouvertures », les tests existants restent donc pertinents au
lieu d'être réécrits.

### L'écart, comblé point par point

Recensé avant de supprimer quoi que ce soit, en comparant les deux écrans :

| Ce que l'ancien module portait | Devenu |
|---|---|
| Import PGN / étude Lichess | Repris — **même feuille, même magasin** : un répertoire importé d'un côté était déjà visible de l'autre, il n'y a qu'une bibliothèque |
| Filtres ♙ ♟ Club Avancé | Repris — la puce-pion devient un composant PARTAGÉ (``PieceFilterChip``) |
| Sections « Mes répertoires » / blanc / noir | Reprises |
| Modifier · Partager · Supprimer | Repris, par le menu « … » |
| Entraîner une ligne | Repris (bouton chapeau du lecteur) |
| `@Query` sur les répertoires | Repris — sans lui, un répertoire arrivé par iCloud n'apparaît jamais |
| « Réviser aujourd'hui » | **Abandonné**, décision produit |

### Ce que la bascule a coûté, et qu'il faut savoir

**Le balayage a disparu.** La nouvelle liste est un `ScrollView`, pas une
`List` : `swipeActions` n'y existe pas. Les trois actions passent par le menu
« … », visible en permanence — ce que le code de l'ancien écran jugeait déjà
préférable (« une fonctionnalité qui demande de deviner qu'il faut balayer une
ligne n'existe pas vraiment »). L'aide, qui documentait le balayage, a été
corrigée.

**L'index s'ouvre en entrant dans une ouverture.** C'est l'écran d'entrée du
module ; les parcours de test qui allaient droit au lecteur le referment.

**🐛 La suppression a emporté un point d'appel invisible.** `UserOpeningSeeder`
(le répertoire personnel de test, `-seedUserOpening`) n'était appelé QUE depuis
`OpeningListView.onAppear`. Le supprimer laissait un seeder sans site d'appel —
compilation verte, et deux tests d'interface qui ne trouvaient plus rien.
Rattrapé par `OpeningEditorAccessUITests`, pas par le compilateur.

**Le lecteur de l'ancien module SURVIT.** `OpeningReaderHost` sert aussi aux
Finales : seule la liste a été supprimée. Idem pour `openingTrainDaily`, que
l'écran Finales utilise encore — l'abandon de la révision quotidienne ne vaut
que pour les Ouvertures.

### L'interrupteur d'aperçu n'existe plus

`AppSettings.openingsLabsEnabled` et la section « Aperçus » des réglages sont
retirés : le module ne peut plus être éteint, puisqu'il n'y a plus rien
derrière. `OpeningLabsFeature` se réduit au filtrage du catalogue.

### Vérifié

689 tests unitaires verts. Tests d'interface repassés sur iPhone 17 Pro et
iPad Pro 11" : le module Ouvertures, l'import/ouverture/suppression d'un
répertoire, l'accès à l'éditeur, les captures de localisation anglaise, les
points d'entrée iPad et les débordements de mise en page.

### Les noms remis d'aplomb (dans la foulée)

Le vocabulaire du code disait encore l'histoire du module au lieu de dire ce
qu'il fait. Renommages mécaniques, vérifiés par la suite complète :

- `OpeningReaderView`/`ViewModel`/`Host` → **`EndgameReader*`**, et la route
  `openingReader` → `endgameReader` : ce lecteur ne sert plus qu'aux Finales.
  Les branchements « ouverture » qu'il porte encore sont DÉFENSIFS — le type de
  données reste commun, et un cours mal étiqueté doit s'afficher proprement
  plutôt que de s'orienter à l'envers.
- Dossier `OpeningLabs/` → **`Openings/`**, et les noms libérés par le
  renommage ci-dessus sont repris : `OpeningLabsListView` → `OpeningListView`,
  `OpeningLabsView` → `OpeningReaderView`, `OpeningLabsHost` →
  `OpeningReaderHost`, `OpeningLabsFeature` → `OpeningCatalogFeature`.
- Les données : `LabsMasterMove` → `OpeningMasterMove`, `LabsEngineLine` →
  `OpeningEngineLine`, `LabsPositionData` → `OpeningPositionStats`,
  `OpeningLabsSidecar` → `OpeningStatsSidecar`.
- Sur disque : `Resources/openings_labs/<id>.labs.json` →
  `openings_stats/<id>.stats.json` ; `labs.py` → `opening_stats.py` ;
  `audit_labs.py` → `audit_opening_stats.py`.
- Les identifiants d'accessibilité `labs_*` → `opening_*`.

Le risque de ce genre de passe est la référence manquée qui ne casse rien à la
compilation : le chargeur de sidecar est DÉFENSIF, un chemin faux aurait donné
un module silencieusement vide. Le filet existait —
`OpeningStatsTests.everySidecarPositionExistsInItsCourse` exige
`inspected > 0` — et l'audit de la donnée est repassé vert après coup.

### L'index : des symboles arbitraires à un vrai arbre

Retour utilisateur : « les symboles à gauche sont disparates ». Ils l'étaient.
Six formes de deux alphabets différents — une flèche, puis cercle, carré,
losange, triangle, hexagone — à poids et tailles optiques inégaux, pour encoder
une profondeur que **le retrait et les rails encodaient déjà**. Un marqueur
redondant, dans un vocabulaire arbitraire à apprendre.

Remplacés par un vrai CONNECTEUR d'arbre (``TreeConnector``) : un rail par
étage encore ouvert au-dessus, et un « └ » ou « ├ » à l'étage de la rangée,
selon qu'elle ferme sa fratrie ou non. C'est ainsi que les vues arborescentes
se dessinent depuis toujours, et cela a un mérite qu'aucun jeu de symboles
n'a : **cela ne s'apprend pas**. Le trait MONTRE à quoi la ligne se rattache.

Il a fallu pour cela que chaque nœud connaisse sa lignée (``Node/lineage`` :
pour chaque étage traversé, l'ancêtre était-il le dernier de sa fratrie ?),
calculée en une passe séparée — un nœud ne peut pas savoir s'il ferme sa
fratrie pendant qu'on le construit, c'est son parent qui le sait.

Deux détails qui décidaient du résultat : l'espacement entre rangées est passé
à ZÉRO, l'air étant pris à l'intérieur de chacune, sinon les rails se coupaient
d'une rangée à l'autre et l'arbre se lisait comme une série de tirets ; et le
nom de variante est entré DANS la colonne des connecteurs, posé en dehors il
ouvrait dans les rails un trou de sa propre hauteur.

La couleur par étage reste, mais elle ne porte plus d'information — seulement
une aide à suivre un étage du regard. La légende est passée de six symboles à
une ligne.

## Finales : une leçon fausse, une ligne tronquée, un audit qui clignotait (24/08) ✅

### Le pion passé éloigné enseignait une technique dont sa position n'avait pas besoin

Signalé par l'utilisateur : « le pion passé éloigné n'est pas juste — à revoir
p.ex. en déplaçant le pion en a4 au lieu de a5 ». Il avait raison, et la preuve
tient en deux lignes de tablebase — les pions de l'aile roi retirés :

    8/4k3/8/P3K3/8/8/8/8 w   (pion a5, seul)  →  GAIN
    8/4k3/8/4K3/P7/8/8/8 w   (pion a4, seul)  →  NULLE

Depuis **a5, le pion promeut tout seul** : parti d'e7, le roi noir arrive un
temps trop tard. Le « leurre », la traversée du roi, l'aile roi — tout cela
était décoratif : la position se gagnait par 1.a6 2.a7 3.a8=D. Le cours faisait
d'ailleurs jouer aux Noirs 2…Rc7, qui autorise la promotion immédiate, puis aux
Blancs 3.Re6, qui l'ignore.

Depuis **a4**, le roi noir arrête le pion : le gain ne peut plus venir que du
thème. Nouvelle ligne, chaque coup tranché par l'oracle : `1.a5 Rd7 2.a6 Rc6
3.a7 Rb7 4.Re6! Rxa7 5.Rf7 Rb6 6.Rxg7 Rc5 7.Rxh7`. Le pion ne menace jamais
d'aller à dame — il achète quatre temps, et c'est exactement ce qu'il faut.
(Détail au passage : le roi blanc ne peut pas passer par f6, que le pion g7
contrôle ; f7 lui est ouvert. C'est ce qui rend le plan non trivial.)

### La triangulation s'arrêtait sur une promesse

« La conversion est désormais mécanique » — une phrase facile à écrire, et que
l'élève ne voyait jamais. La ligne principale va maintenant jusqu'au mat
(`16…bxc6 17.Rc7! c5 18.b7+ Ra7 19.b8=D+ Ra6 20.Db6#`), et un second chapitre
montre l'autre défense (`16…Rb8 17.c7+ Ra8 18.c8=D#`).

### Nouvelle finale : Pions électriques

Position et définition fournies par l'utilisateur — un pion passé séparé d'un
autre par UNE colonne, capable de bloquer le roi adverse par menace réciproque.
`8/8/8/2k5/8/P1P5/8/7K b` : gain blanc, mat en 39 à la tablebase. La ligne
montre le mécanisme en six coups : `1…Rc4 2.a4! Rxc3 3.a5 Rb4 4.a6 Rb5 5.a7
Rb6 6.a8=D`. L'écart d'une colonne est le point exact — collés, un seul roi les
arrête ; plus écartés, il n'a même plus à choisir.

### L'audit ne voyait ni l'un ni l'autre — il voit maintenant

Les 77 cours passaient l'audit tablebase, y compris le pion passé éloigné :
tous ses coups préservaient bien leur verdict. Le défaut n'était pas dans les
coups, il était dans la PRÉMISSE. Deux contrôles ajoutés, non bloquants parce
qu'ils jugent la pédagogie et non la vérité :

- **Gain immédiat ignoré** — le cours enseigne un coup correct alors qu'un mat
  en un ou une promotion NON REPRENABLE gagne sur-le-champ. La condition « non
  reprenable » n'est pas un détail : une dame reprise au coup suivant reste
  « gagnante » pour la tablebase alors que c'est souvent le coup thématique
  (les pions liés qui se donnent l'un pour l'autre). Sans elle, le contrôle
  criait au loup sur la moitié des finales de pions.
- **Ligne interrompue** — la ligne s'arrête sur un gain encore lointain ALORS
  QUE l'adversaire a du matériel. La seconde condition fait tout : une ligne
  qui s'achève sur un roi nu a fini son travail, et l'imposer allongerait tous
  les cours pour rien.

🐛 Ma première version de ce second contrôle déduisait le camp défenseur du
TRAIT et se trompait de camp : elle comptait les pions de l'attaquant comme du
matériel de défense. 28 avertissements sont retombés à 16 une fois corrigé.

### Le garde-fou moteur clignotait

Au-delà de sept pièces la tablebase se tait et l'audit se replie sur Stockfish.
Il comparait des CENTIPIONS, avec un seuil de 100. Or ces positions sont
presque toutes des mats annoncés, dont la valeur numérique n'a aucune
stabilité : la MÊME arête du cours « percée » a été notée `+6502 → +9967 (OK)`,
puis `+8308 → +9970 (OK)`, puis `+1344 → +1189 (⚠ perd 155 cp)` sur trois
exécutions du même audit — et le code retour basculait avec elle. Un garde-fou
qui clignote est pire qu'aucun garde-fou.

Le contrôle moteur juge désormais comme le contrôle tablebase : le VERDICT
a-t-il changé (gain / nulle / perte) ? Et, comme lui, il ne tient pour faute
qu'un coup du camp ÉTUDIÉ — un coup adverse sous-optimal est signalé, pas
sanctionné. Deux exécutions consécutives donnent maintenant des verdicts
identiques.

### Vérifié

78 cours de finales audités, **aucun coup enseigné ne casse son verdict
théorique**, 16 avertissements pédagogiques à relire (Lucena, Philidor et
consorts s'arrêtent une fois la méthode acquise — c'est un choix, il est
maintenant visible). 689 tests unitaires verts, tests d'interface Finales et
Ouvertures verts.

### Une erreur à signaler

Mon commit `62f7d95` a emporté, via `git add -A`, une modification du fichier
projet que je n'avais pas relue : `IPHONEOS_DEPLOYMENT_TARGET` de l'app était
passé à **18.6** en cours de session, les cibles de TEST restant à 18.0 — ce
qui est invalide, une cible de test ne pouvant pas être inférieure au module
qu'elle importe. La compilation des tests s'en est trouvée bloquée. J'ai aligné
les deux cibles de test sur 18.6 sans toucher à l'app, dont le passage à 18.6
est une décision produit qui ne m'appartient pas.

**Tranché le 24/08** : cible **18.0** partout, app comprise. Les 696 tests
passent à cette cible.

## 24/08 — « Reprendre ici » : annuler plutôt que confirmer

### Le défaut signalé

Reprendre la partie depuis un coup consulté demandait **trois gestes** :
choisir le coup, toucher « Reprendre ici », puis confirmer dans une feuille
modale. Le troisième interrompait le geste au moment précis où l'utilisateur
avait déjà décidé.

### Ce qui a été fait

La feuille de confirmation est supprimée, des deux modes de partie (*Jouer* et
*Deux joueurs*). La reprise agit au premier toucher, et **l'annulation prend la
place exacte du bouton** qui vient d'être touché : le doigt est déjà là, le
retour en arrière ne coûte qu'un geste au même endroit. L'offre s'efface d'
elle-même au bout de 8 secondes, ou dès qu'un coup est joué sur la ligne
reprise — l'avoir engagée, c'est l'avoir acceptée.

C'est la recommandation d'Apple (*Confirming actions*) : quand l'action est
réversible, agir puis offrir d'annuler vaut mieux que demander avant. Encore
faut-il qu'elle le soit VRAIMENT — c'est la seule chose qui rende ce choix
légitime, et c'est ce que mesurent les sept tests de
`ResumeFromReviewUndoTests` : les coups écartés reviennent à l'identique,
coups ET position, y compris si le moteur a répondu entre-temps (la
reconstruction l'écrase, elle ne l'empile pas).

### Une mesure qui a corrigé le dessin

La pastille portait d'abord une icône « ↺ » devant son texte. Elle réclamait
**312,7 pt** là où l'iPhone en Zoom d'affichage n'en offre que 296 : l'image et
son écart de 5 pt sont incompressibles, contrairement au texte. La rangée
serait redevenue plus large que l'écran — le défaut du 22/08, à l'identique.
Texte seul, elle tombe à 296,0 pt tout juste. Le test
`testUndoOfferedBarFitsOnAZoomedIPhone` fige la mesure.

### Vérifié

**696 tests unitaires verts** (689 + 7). Les deux chaînes de la feuille
supprimée sont retirées du catalogue, les quatre nouvelles y sont traduites.

## 24/08 — Analyse : la pastille passe devant la flèche

La pastille de qualité (gaffe, coup brillant…) se pose sur la case d'ARRIVÉE du
coup joué. C'est exactement là qu'une flèche du moteur commence ou se termine :
elles se disputent les mêmes pixels, et l'ordre du `ZStack` faisait gagner la
flèche. La pastille devenait illisible précisément quand elle compte le plus.

Elle remonte d'un rang (`zIndex(1)`), le fantôme de glissement restant seul
au-dessus d'elle (`zIndex(2)`) — la pièce qui suit le doigt ne doit rien avoir
devant. Le rang plutôt qu'un déplacement dans la pile : la pastille doit rester
collée au-dessus des pièces, même contrainte que le marqueur de dépôt.

Un ordre d'empilement ne se lit dans aucune propriété — il se constate au
rendu. `BoardBadgeStackingTests` dessine donc l'échiquier et lit les pixels :
ajouter une flèche ne doit RIEN changer à ceux de la pastille. Un troisième
test garde le tout honnête en vérifiant que la flèche recouvre bel et bien
l'emplacement — sans lui, les deux autres passeraient aussi bien s'il n'y avait
aucun conflit à trancher. Avant correction, le pixel visé valait `[35, 31, 31]`
(le gris de la flèche) au lieu de `[192, 57, 57]` (le rouge de la gaffe).

## 24/08 — Laboratoire : les libellés disent enfin ce qu'ils mesurent

« LOS », « écart Elo ±42 » : du vocabulaire de tournoi de moteurs. Exact,
compact, et hermétique à qui ne l'a jamais croisé. Chaque tuile de statistique
porte maintenant son explication et la donne sur demande, comme les deux
en-têtes de section — la bande claire autour de la courbe de progression
n'était légendée nulle part.

### Une bulle qui ne s'installe pas

Trois sorties, selon la façon dont elle est venue : l'appui MAINTENU la montre
tant que le doigt reste posé, le toucher simple la laisse dix secondes, et le
toucher suivant la referme (comportement natif de la bulle, son voile capte le
geste). Dix secondes : de quoi parcourir deux courts paragraphes sans les
apprendre par cœur. Plus court, la bulle s'arracherait en pleine lecture ; plus
long, elle cesserait d'être de passage.

### La mesure qui a rattrapé une régression

Le picto « ? » était d'abord posé DANS la rangée de la tuile. Il coûtait 26 pt
(14 de glyphe, 12 d'écart) — et une tuile n'offre que **62 pt** à son libellé
sur un iPhone en Zoom d'affichage, quand « parties jouées » en réclame 74. Les
SIX libellés se coupaient, sur tous les iPhone et pas seulement en Zoom. Rien
ne le disait : les deux versions compilent aussi bien, et le facteur de
réduction masque la coupe en la faisant passer pour un choix.

Passé en incrustation d'angle, le picto ne coûte plus rien et la géométrie
redevient celle d'avant, au point près. `LabStatTileLayoutTests` mesure les
deux : que chaque libellé tient, et que la rangée ne vaut que son contenu.

### Hygiène des chaînes

Deux explications écrites en chaîne multiligne Swift ont vu leurs lignes se
recoller EN GARDANT leur indentation — « la part verte         est ce que ».
Compilation verte, app fonctionnelle, texte abîmé : rien ne regardait le texte.
`LocalizedStringHygieneTests` le regarde maintenant, sur les chaînes RÉELLEMENT
livrées (celles compilées dans le bundle) : aucun espace en double, aucun
espace avant un saut de ligne. Mesuré sur les 1 104 chaînes du catalogue, les
deux invariants tiennent — l'espace FINAL, lui, est laissé libre : cinq chaînes
sont des préfixes destinés à être collés à une valeur.

### Vérifié

712 tests verts (698 swift-testing + 14 XCTest). 17 chaînes ajoutées au
catalogue, traduites en anglais.

## 24/08 — Pions électriques : libellé français et thème développé

### Le libellé

Le nom d'un cours reste en ANGLAIS dans `opening_catalog.json` — c'est
`Localizable.xcstrings` qui le traduit. « Electric Pawns » était le SEUL des
136 cours sans sa traduction : ajouté le 24/08, il s'affichait en anglais au
milieu de titres français. Rien ne le signalait, le catalogue étant valide.
`LocalizedStringHygieneTests` vérifie désormais que chaque nom du catalogue a
sa traduction ; retirer celle des pions électriques fait bien tomber le test.

### Le thème, tel que la tablebase le décrit

La finale était enseignée en une ligne : « le roi touche un pion, on lance
l'autre ». C'est vrai depuis c5 — et FAUX depuis b5. L'oracle est net :

- après 1…♚c4, SEUL `a4` gagne ; tout coup de roi annule ;
- après 1…♚b5, c'est l'inverse : `a4+` ET `c4+` annulent (le roi noir touche
  les deux cases), et il faut ATTENDRE avec le roi.

La règle qui couvre les deux : ne jamais pousser un pion sur une case que le
roi adverse contrôle déjà — et laisser le roi noir désigner lui-même, en
s'approchant, lequel des deux ira à dame.

Trois chapitres ajoutés : le miroir (1…♚b5 2.♔g2! ♚a4 3.c4!, où c'est le pion c
qui fait dame), et deux pièges — pousser avec échec (1…♚b5 2.a4+?? ♚xa4) et
vouloir sauver c3 (1…♚c4 2.♔g2?? ♚xc3, où `a4` arrive un temps trop tard). Le
cours passe de 10 à 33 positions.

Les deux pièges sont prouvés tels : l'audit vérifie qu'une arête marquée
`trap` DÉGRADE réellement le verdict, sinon elle ment. `fake_traps` est vide.

### Vérifié

78 cours de finales audités, aucun coup enseigné ne casse son verdict
théorique. 713 tests verts (699 swift-testing + 14 XCTest).

## 24/08 — Barres d'outils : une capacité, une apparence

### Ce qui n'allait pas

« Continuer ailleurs » vivait sous DEUX apparences. Six écrans — Ouvertures,
Finales, Puzzles — avaient le bouton violet ▦ ; les trois écrans de partie
cachaient les MÊMES destinations dans une section d'un menu annoncé comme
**Exporter** (icône de partage, grise), ou noyées dans un « … » avec le thème
du plateau et le retournement de plateau. Rien ne laissait deviner qu'il
s'agissait de la même chose.

`QuickSwitchMenu` est désormais le seul accès, sur les neuf écrans concernés.
Les menus d'export ne parlent plus que d'export.

Deux défauts trouvés en chemin. *Analyser* proposait « Jouer à partir d'ici »
sous `play.fill`, là où l'accueil et six écrans nomment ce mode « Contre
l'ordinateur » sous `cpu` — même destination, deux noms, deux icônes. Et le
paramètre `excluding` ne savait dire qu'une chose, « je suis ce mode-ci » : il
ne pouvait pas décrire l'analyse, qui propose une partie contre l'ordinateur
mais pas à deux. Les destinations se DÉCLARENT maintenant — chaque écran
fournit les passerelles qui ont un sens chez lui.

Libellés et icônes sont ceux des tuiles de l'accueil, dans le même ordre : le
menu est un raccourci vers la grille, il en reprend les mots. Titre inchangé
(« Changer de mode ») : c'est sous ce nom que l'aide le présente, à trois
endroits. Trois chaînes devenues orphelines ont été retirées du catalogue —
en demandant au COMPILATEUR lesquelles ne sont plus référencées, une recherche
de texte confondant les commentaires avec les usages.

### Thème du plateau, et couleurs de l'accueil

Le sélecteur de thème quitte *Jouer* : changer l'apparence du plateau est un
réglage, pas un geste de partie — et ce menu ne laissait pas deviner qu'il
s'appliquait à TOUS les écrans, ce qu'il faisait pourtant. Il reste dans
Réglages › Thème du plateau (vérifié avant de retirer l'accès).

Progression et Réglages passent en couleur sur l'accueil. En le faisant :
le même bouton n'avait pas la même teinte selon l'appareil — Progression était
verte en barre latérale iPad et grise sur iPhone, l'Aide exactement l'inverse.
Les deux surfaces sont alignées. On perd la mise en avant que le gris donnait
à l'Aide ; c'est un choix assumé, consigné dans le code.

### Aide

Nouveautés 1.6 en huit lignes. Trois textes devenus faux corrigés : le menu
d'export qui « envoie la position » (c'est « Changer de mode »), « 77 cours »
de finales (78 depuis les Pions électriques), et la description des Ouvertures
qui ignorait l'index en arbre, les coups des maîtres et Stockfish. Une carte
**Remerciements** ferme l'aide.

### Un faux plantage, dont j'étais la cause

`BoardHitTestUITests/testBoardIsHittableAtAX3` — 15 s d'habitude — a mis 229 s
et échoué, rapports de plantage à l'appui. Ces `.ips` ne montraient AUCUNE
image ChessLab : seulement `_XCTestMain → exit → std::terminate`, la fin de
session du harnais. Relancé SEUL sur le même build : 19,7 s, vert. J'avais
lancé la suite unitaire en parallèle sur la même machine. La durée anormale
était le signal ; le rapport de plantage, lui, était un leurre.

### Vérifié

699 tests unitaires verts, **72 tests d'interface verts** (5 ignorés), suite
lancée seule.

## 24/08 — Revue de stabilisation : deux régressions de la veille, et un audit qui n'auditait pas

Revue multi-agents sur le delta 62f7d95..HEAD (7 angles), chaque trouvaille
vérifiée sur pièce avant verdict. Rapport complet déposé via l'outil de revue.

### Corrigé

**« Annuler la reprise » pouvait ressusciter une partie terminée.** Un abandon
ou une nulle par accord ne se LISENT pas sur l'échiquier, et `rebuild`
recalcule `outcome` depuis la seule position : reprendre → abandonner dans les
8 s → annuler effaçait le résultat (déjà enregistré en bibliothèque côté Deux
joueurs — la partie s'y serait inscrite une seconde fois). Gardes ajoutés dans
les deux modes, pastille masquée en fin de partie, tests de régression prouvés
en retirant le garde (outcome → nil sans lui).

**Annuler pendant la réflexion du moteur échangeait le plateau sous la
recherche.** `canTakeback` exige `!isEngineThinking` ; mon
`cancelResumeFromReview` ne l'exigeait pas, alors que la reprise elle-même
peut lancer une recherche — le coup calculé pour la position tronquée pouvait
se commettre sur la partie restaurée s'il y était légal par coïncidence.

**`_check_missed_win` gardait les coups PERDANTS.** `move_categories` parle du
point de vue du joueur (« win » = ce coup gagne) ; le filtre testait
`!= "loss"` — la convention de l'API brute. Le contrôle était un no-op
silencieux pour le défaut même qu'il documente. Réparé, il a d'abord crié au
loup sur trois mats (Db1# « ignorant » Dd2#) : un coup enseigné qui mate ou
promeut est lui-même l'évidence, il est maintenant exempté. Reste UN vrai cas
limite, assumé : la coupure verticale joue Tf7 avant d8=D (ligne DTM-optimale,
le commentaire l'explique) — c'est le rôle des avertissements non bloquants.

**`_check_early_stop` était aveugle aux 6-7 pièces** : l'API n'y donne pas de
DTM (`null`), le contrôle rendait la main sans rien dire — repli sur le DTZ,
filet à grosses mailles assumé. Il pliait aussi `cursed-win`/`maybe-win` en
« pas un gain ». Et la sonde réseau part maintenant APRÈS les éliminations
gratuites.

**Moindres** : l'annonce VoiceOver de reprise manquait en Deux joueurs (copie
divergée du mécanisme) ; l'aide du Laboratoire citait « Continuer au
Laboratoire », libellé supprimé par l'harmonisation ; le maintien-pour-lire des
bulles du Laboratoire résiste maintenant au vol de toucher par la présentation
(un « relâchement » dans la demi-seconde bascule sur la minuterie du toucher).

### Consigné sans agir (1.6.1)

Le mécanisme ResumeUndo, le prédicat de recherche et le câblage VoiceOver des
bulles sont chacun dupliqués — les copies ont déjà divergé une fois. À
regrouper hors période de stabilisation. `RELEASE_NOTES-1.4.0.md` supprimé
localement (pas par moi) alors que les notes 1.5.0 le disent conservé :
décision utilisateur en attente.

### Vérifié

701 tests unitaires verts (2 régressions ajoutées, prouvées mordantes).
78 finales auditées, verdicts intacts, 15 avertissements pédagogiques.

## 25/08 — Variantes, lot 1 : la couche de règles Chess960, prouvée par perft

Décisions utilisateur (25/08) : tuile « Variantes », hub « Variantes
d'échecs », première brique Chess960 dans le style de « Contre l'ordinateur »,
position aléatoire + n° Scharnagl saisissable, ET les débranchements
Laboratoire / Deux joueurs / Analyser au périmètre — d'où l'exigence
structurante du lot : la couche de règles est PARTAGÉE, pas enfouie dans un
view model de jeu.

### Ce qui est livré

`Chess960Position` (les 960 départs par numéro de Scharnagl, port fidèle de
python-chess) et `Chess960Game` : coups ordinaires délégués à ChessKit — qui
reçoit le FEN aux droits de roque VIDES, son parseur ignorant les lettres
Shredder sans échouer —, roque « roi prend sa tour » validé et exécuté ici
(chirurgie de FEN), droits par colonnes de tour, FEN Shredder pour le moteur,
UCI au dialecte `UCI_Chess960`, SAN O-O/O-O-O avec suffixe d'échec et de mat.

### L'oracle, et ce qu'il a attrapé

python-chess (Chess960 natif) fait autorité ; le Swift se conforme. Fixtures à
graine fixe (`gen_chess960_fixtures.py`) : les 960 FEN de départ, 40 parties
biaisées vers le roque rejouées coup à coup (2 400 coups, SAN et FEN comparés
après CHACUN), et 1,245 million de nœuds perft sur 39 positions.

La campagne a démasqué un no-op silencieux qui aurait survécu à toute
relecture : le test « case attaquée » lisait `Board.state` après un
`Board(position:)` — or ChessKit rend `.active` À L'INIT, même roi en échec ;
l'état n'est calculé qu'après un coup. Toutes les conditions d'attaque du
roque étaient donc vides, et le perft n'a divergé que de +40 nœuds sur
1,2 million (position 177, un roque autorisé sous échec) : aucun test à la
main n'aurait vu ça. La détection d'attaque est maintenant écrite ici même
(pièces clouées comprises — elles attaquent quand même), et c'est le perft qui
la garantit.

Divergence de convention résolue au passage : python-chess n'écrit la case en
passant que si la prise est légale, ChessKit l'écrit toujours — fixtures
regénérées en convention FIDE (`en_passant="fen"`).

### Coût en routine

Perft scindé : profondeurs 1-3 dans la suite verte (~90 s — c'est la
profondeur 3 qui a attrapé le roque-sous-échec, elle reste), profondeur 4
(1,1 M nœuds, ~3 min 30) à la demande via `CHESS960_PERFT_FULL=1`, même
convention que les captures App Store.

### Vérifié

707 tests verts (6 nouveaux dont un conditionnel). Reste connu, assumé pour le
lot 2 : la reconstruction de plateau qu'exige un roque remet à zéro le
compteur de répétitions interne de ChessKit — la nulle par répétition d'une
partie 960 devra vivre au niveau du view model.

## 25/08 — Variantes, lot 2 : le Chess960 se joue

La tuile **« Variantes »** (violette, dé) est sur l'accueil — grille iPhone et
barre latérale iPad — et ouvre le hub « Variantes d'échecs », dont le Chess960
est la première carte.

### L'écran de réglages

La grammaire de « Contre l'ordinateur » (sections, chips, curseur de force,
familles de cadence), plus la section propre à la variante : position par
tirage aléatoire OU par numéro de Scharnagl saisissable (0-959, champ validé,
bordure rouge sinon), aperçu de la rangée blanche en glyphes de pièces, et la
mention explicite que la 518 est la partie classique. Le dernier numéro est
mémorisé (`Chess960SettingsStore`, décodage défensif champ à champ) — c'est le
« rejouer la même ». Pas de livre (pas de théorie) ; indice et alerte gaffe
annoncés « pour une prochaine version » DANS l'écran, plutôt que absents sans
explication.

### La partie

`Chess960PlayViewModel` : un view model DÉDIÉ et volontairement petit (~450
lignes contre 1 700), la légalité venant de la couche partagée du lot 1. Le
journal est en UCI/SAN — pas en `Move` ChessKit, qu'un roque 960 ne sait pas
représenter. Le moteur reçoit `UCI_Chess960` + FEN Shredder et rend le roque
en roi-prend-tour, le dialecte exact de la couche. Le GESTE de roque à
l'écran est le même que Lichess : toucher le roi montre ses tours comme
cibles.

Repris tels quels : ChessBoardView, PlayControlBar, GameClock, EngineStrength,
EvalBarView, PromotionPickerView, sons. Le pattern « Reprendre ici » du 24/08
est appliqué D'ORIGINE, gardes comprises (outcome, moteur en réflexion) — pas
de dette à rattraper. La nulle par répétition vit dans le view model (clé = 4
champs Shredder) : le compteur interne de ChessKit ne survit pas à la
reconstruction qu'exige un roque. PGN exporté avec les tags
`Variant "Chess960"` / `SetUp` / `FEN`.

### Vérifié

713 tests verts — 6 nouveaux sur la mécanique sans moteur : journaux SAN/UCI,
répétition, reprise et annulation avec gardes, retrait de paire, tags PGN,
cibles de roque. 19 chaînes traduites. Le tour moteur réel (Elo, pendule,
`UCI_Chess960`) ne se teste qu'à la main : ajouté à la checklist du tour.

### Restes assumés (lot 3 et « aides »)

Débranchements (Deux joueurs → Laboratoire → Analyser), indice, alerte gaffe,
autosauvegarde, surlignage du dernier coup après un roque (le `lastMove`
ChessKit ne peut pas le représenter — l'échiquier ne surligne pas ce coup-là).

## 25/08 — Correctif critique : Chess960 remettait chaque coup à zéro

Signalé par l'utilisateur juste après la livraison du lot 2 : « je n'arrive
pas à déplacer des pièces ». La cause n'était ni dans les règles (prouvées
par perft), ni dans le view model (6 tests verts sur sa mécanique) — elle
vivait dans `HomeView.destination(for:)`, qui construisait
`Chess960PlayViewModel(settings: settings)` EN LIGNE au lieu de le confier au
`SessionStore`, comme le font `.activeGame` et `.activeTwoPlayerGame` depuis
le Lot 0. Chaque coup joué invalide l'état observé, `destination(for:)` est
réévalué, et un view model NEUF remplaçait l'ancien : le coup qu'on venait de
jouer disparaissait aussitôt sous une partie remise à zéro, sans erreur ni
écran figé — juste un coup qui semblait avaler.

`Chess960ActiveGameHost` répare la route, à l'identique des deux hôtes déjà
en place. `startNewChess960Game` purge la session stagnante avant d'empiler
la route — même sas que `startNewGame`/`startNewTwoPlayerGame`.

Corrigé au passage : `Chess960PlayView.body` portait un `if` de dernier
niveau après une longue chaîne de modificateurs (la bannière moteur
indisponible) — compile, mais ne se superpose à rien sans conteneur explicite.
Passé en `.overlay`.

### Le test qui aurait dû exister

Aucun test unitaire ne pouvait voir ce défaut : ils appellent le view model
directement, court-circuitant précisément le chemin de routage où il vivait.
`Chess960SessionUITests` navigue depuis l'accueil réel (Variantes → Chess960
→ Commencer → coup) et lit un marqueur `chess960_moveCount` (même convention
que `PlayView.moveCountMarker`). Premier jet du test : `== "1"` après un seul
coup — trop strict, le moteur peut avoir déjà répondu au moment de la lecture
(compteur à « 2 » d'entrée, coup utilisateur ET réponse moteur déjà commis) ;
ce n'était pas le défaut, c'était juste un test qui présumait un moteur plus
lent qu'il ne l'est. Réécrit pour ce qui compte réellement : le compteur ne
retombe JAMAIS à 0 après avoir progressé.

Un second test envisagé (quitter l'écran puis y revenir) présumait un chemin
de reprise qui n'existe pas — « Commencer » relance toujours une partie
neuve, par construction, comme en mode Jouer. Retiré plutôt que forcé à
valider un comportement qui n'est pas censé exister ; la vraie protection de
`SessionStore` (survivre à un rendu de `HomeView` PENDANT que l'écran actif
est affiché) est déjà celle que le premier test exerce de bout en bout.

### Vérifié

713 tests unitaires verts, le test d'interface du défaut vert. Une suite
`GameClockStartTests.whiteTimeDecreasesBeforeTheFirstMove` a échoué en
tournant dans le lot complet (274 s), verte relancée seule — flaky
pré-existant et documenté dans son propre commentaire (contention du
`MainActor` sous charge), sans rapport avec ce travail.

## 25/08 — Correctif critique n°2 : le gel « l'ordinateur ne joue jamais »

Deuxième signalement de l'utilisateur, précisé ensuite en « l'app freeze » (pas
un plantage). Cause distincte du bug de session de la veille :
`Chess960PlayViewModel.updateEvalBar()` appelait
`EngineController.computeBestMove(...)` — l'API à LECTEUR PERMANENT, annotée
dans son propre commentaire « (Laboratoire) », qui démarre
`ensureMoveReader()` : une tâche de fond qui consomme `responseStream` POUR
TOUJOURS. `requestEngineMove()` lit ce MÊME flux à la main, comme partout
ailleurs dans l'app (`PlayViewModel` compris) — `responseStream` est un
`AsyncStream` à consommateur UNIQUE, et `synchronize()` porte une assertion
explicite contre la double-consommation : « deux `next()` concurrents =
fatalError du stdlib ».

Dès que la barre d'éval s'affiche une seule fois (au démarrage, si
l'utilisateur joue les blancs — `start()` l'affiche AVANT le premier coup), le
lecteur permanent reste vivant, et le premier `synchronize()` du coup moteur
suivant heurte l'assertion. Sous débogueur (Xcode Run, le cas normal en
développement), l'app semble GELÉE — c'est le process qui s'arrête sur le
trap, pas un vrai blocage logique.

Réparé en réécrivant `updateEvalBar()` sur le MÊME patron manuel que
`requestEngineMove()` et que `PlayViewModel.updateEvalBar()` — synchronize,
envoi de la position, lecture manuelle du flux sous `EngineWatchdog`, jamais
`computeBestMove`.

### Le test, et sa preuve

`Chess960PlayViewModelTests.engineRepliesAfterFirstMoveWithEvalBarEnabled` —
moteur RÉEL (pas `forceMove`) : c'est la communication moteur qui était en
cause, aucun test mécanique ne pouvait la voir. Retiré le correctif pour
vérifier que le test mord : il reproduit l'assertion À L'IDENTIQUE
(`EngineController.swift:208`, `deux next() concurrents = fatalError du
stdlib`), qui fait s'écrouler le PROCESS de test entier — le même signal que
verrait l'utilisateur. Restauré, vert.

Ce test rejoint la famille de fragilité déjà documentée
(`GameClockStartTests`) : un vrai Stockfish, sous contention de la suite
complète (bancs d'essai moteur inclus), peut dépasser une marge stricte —
vert de façon fiable seul (2-3 s), marge élargie à 60 s par précaution.

## 25/08 — Chess960 : le dernier coup se surligne, roque compris

Demande de l'utilisateur : les cases jouées doivent apparaître en jaune comme
en partie normale. `Chess960PlayView` passait `lastMove: nil` — jamais câblé
depuis le lot 2.

Le piège : le dialecte UCI du moteur (`e1h1`, roi-prend-tour) désigne, pour un
roque, la case de la TOUR comme arrivée — la surligner telle quelle aurait
montré une case où rien n'atterrit. `Chess960Game.displaySquares(forUCI:)`
calculée AVANT `apply` (sur la position qui précède le coup) traduit ça vers
la case RÉELLE du roi (g1/c1), la même convention que le roque classique
ailleurs dans l'app — un seul champ `Move`, celui du roi, jamais celui de la
tour. Un journal parallèle (`displaySquaresLog`) suit `uciLog`/`sanLog`,
tronqué avec eux, recalculé par rejeu à la reconstruction — et
`displayedLastMove` respecte la consultation, comme
`PlayViewModel.displayedLastMove`.

### Vérifié

716 tests unitaires verts (2 nouveaux sur la surbrillance, dont le cas du
roque). 72 tests d'interface Chess960 verts. Les deux suites, relancées
SÉPARÉMENT — j'avais moi-même enfreint la leçon documentée hier en les
lançant en parallèle, produisant un faux échec (« Executed 0 tests ») que j'ai
identifié et écarté avant de conclure.

## 25/08 — Chess960 : composer soi-même la rangée de départ

Demande de l'utilisateur : au-delà d'« Aléatoire », pouvoir choisir le numéro
soi-même (déjà livré au lot 2 — le champ « n° 0-959 ») ET placer les pièces à
la main, sans ouvrir un écran entier — juste la première rangée.

### Le choix retenu

La rangée d'APERÇU devient elle-même l'ÉDITEUR : toucher une case la
sélectionne, en toucher une seconde échange les deux. Un échange PRÉSERVE
TOUJOURS le jeu de pièces (2 tours, 2 cavaliers, 2 fous, 1 dame, 1 roi) — il
n'y a donc jamais de sélecteur de pièce à ouvrir, ni de risque de composer un
jeu incomplet. Restent deux règles du Chess960 qu'un échange PEUT encore
briser : le roi doit rester strictement entre les deux tours (sans quoi le
roque « le roi prend sa tour » ne saurait plus distinguer petit et grand
côté), et les deux fous doivent rester sur des cases de couleurs différentes
(règle FIDE, indépendante de cette app). Une composition qui les brise se
voit — message explicite, « Commencer » désactivé — jamais silencieusement
acceptée.

`Chess960Position.isLegalBackRank(_:)` et `.number(forBackRank:)` (recherche
inverse par balayage des 960 positions, coût négligeable et hors boucle
chaude) vivent dans la couche de règles, pas dans l'écran : `positionNumber`
reste synchronisé après chaque échange légal, et s'IMMOBILISE — sans jamais
pointer vers une position que l'écran ne montre plus — dès qu'un échange rend
l'arrangement invalide.

### Vérifié

- `Chess960RulesTests` : balayage EXHAUSTIF des 960 rangées engendrées —
  chacune se déclare légale et se retrouve à son PROPRE numéro (l'aller-retour
  génération → validation → recherche inverse ne perd personne) — plus quatre
  cas nommés (roi hors intervalle, fous de même couleur, jeu de pièces
  incomplet, la 518 retrouvée depuis RNBQKBNR composée à la main).
- `Chess960SetupUITests` (nouveau fichier) : échanger le roi hors de
  l'intervalle désactive « Commencer » et affiche l'avertissement ; rejouer le
  même échange restaure exactement l'état précédent (une paire d'échanges est
  sa propre inverse) ; un aller-retour neutre (deux cavaliers, indiscernables)
  retrouve bien le n° 518 depuis l'écran réel, pas seulement en test unitaire.

721 tests unitaires verts (5 nouveaux). Suite d'interface Chess960 complète
verte (4 tests, 2 fichiers).

## 25/08 — Chess960 : le pavé numérique du champ « n° » ne se refermait pas

Signalé par l'utilisateur : taper un numéro de position ouvre le clavier
numérique, qui n'a AUCUNE touche pour le refermer — contrairement au clavier
alphabétique, le pavé `.numberPad` d'iOS n'a pas de touche Retour. C'était le
premier champ numérique de toute l'app ; aucune convention existante à
réutiliser.

Ajouté : un `@FocusState`, et une barre d'accessoires du clavier
(`ToolbarItemGroup(placement: .keyboard)`) portant un bouton « Terminé » qui
retire le focus. C'est le patron standard d'iOS pour ce cas précis.

### Vérifié

`Chess960SetupUITests.testKeyboardDismissesViaDoneButton` : touche le champ,
attend l'apparition de « Terminé », le touche, vérifie sa disparition — la
preuve que le clavier se referme VRAIMENT, pas seulement que le bouton existe.
721 tests unitaires verts (les deux échecs rencontrés en suite complète sont
les fragilités déjà documentées — moteur réel, pendule — vertes isolément).

## 25/08 — Variantes, lot 3 (1/3) : le débranchement « Deux joueurs »

Premier des trois débranchements prévus (Deux joueurs → Laboratoire →
Analyser), dans l'ordre du moins cher au plus gros.

`Chess960TwoPlayerSettings` / `Chess960TwoPlayerViewModel` /
`Chess960TwoPlayerView` : même plan que ``Chess960PlayViewModel`` (journal
UCI/SAN, cases affichées, répétition, consultation, « Reprendre ici » avec
annulation) MOINS tout le moteur, PLUS la rotation face-à-face/table de
``TwoPlayerViewModel``. Duplication ASSUMÉE — même ordre que celle, déjà
documentée, entre `PlayViewModel` et `TwoPlayerViewModel` : deux écrans, deux
histoires de réglages, un seul mécanisme de jeu.

`Chess960PlayView` gagne son bouton violet « Changer de mode » (jusqu'ici
absent — seul l'export y vivait). Câblage par `SessionStore`, comme
`.activeGame`/`.activeTwoPlayerGame` — la LEÇON du gel du 25/08 appliquée
d'origine, pas de dette à rattraper.

### Un test qui s'est trompé de coupable — et ce qu'il a fallu pour le voir

Le premier jet du test de débranchement présumait qu'après 1.e4, c'était aux
noirs de jouer — RACE PERDUE contre le moteur, qui répond en général sous la
seconde : la position réellement affichée au moment du débranchement avait
souvent DÉJÀ la réponse noire jouée. `print()` ne remonte pas dans les
journaux `xcodebuild` ; il a fallu forcer un échec (`XCTFail` avec
`app.debugDescription`) pour lire la VRAIE hiérarchie d'accessibilité à
l'écran — qui montrait e6 occupé par un pion noir, e7 vide : le moteur avait
déjà joué. Un test isolé au niveau du view model (sans UI) a confirmé la
mécanique elle-même était correcte du premier coup — la faute était dans
l'hypothèse du test, pas dans le code.

Corrigé en comparant des FEN plutôt qu'en rejouant un coup dont la légalité
dépend du nombre de demi-coups déjà écoulés : un marqueur `chess960_fen`
(même convention que `chess960_moveCount`) expose la position affichée sur
les DEUX écrans, et le test vérifie l'égalité stricte au moment du
débranchement — déterministe, indépendant de la vitesse du moteur.

### Vérifié

730 tests unitaires verts (9 nouveaux sur la mécanique à deux, sans moteur —
donc sans la fragilité du test au moteur réel). Suite d'interface Chess960
complète verte (6 tests, 3 fichiers).

## 25/08 — Chess960 : indice et alerte gaffe, avec leurs interrupteurs

Demande de l'utilisateur : porter l'indice et l'alerte gaffe dans Chess960,
avec des réglages pour les activer ou désactiver.

### L'indice, en salve bornée plutôt qu'en analyse continue

`PlayViewModel.startHintAnalysis()` tourne TANT QUE l'indice reste affiché —
ce qui exige toute une machinerie d'interruption (`isHintAnalyzing`,
`hintTask`, `stopHintIfNeeded`, `interruptHintAnalysisIfNeeded`) pour ne
jamais laisser deux consommateurs se disputer `responseStream`. C'est
EXACTEMENT la classe de défaut qui a gelé cette variante plus tôt aujourd'hui
(`updateEvalBar` appelant la mauvaise API). Plutôt que de répliquer cette
machinerie à l'identique — risque jugé disproportionné après DEUX défauts du
même genre dans la même journée — l'indice Chess960 est une analyse PONCTUELLE
et BORNÉE (~1,5 s, MultiPV 3), passée par la file sérielle comme tout le
reste, dont le résultat est simplement JETÉ s'il arrive après que la position
a changé (garde `hintsWanted`/`sideToMove`/`shredderFEN` revérifiée après
coup) plutôt qu'annulé activement. Contrepartie assumée : les flèches
n'affinent pas leur profondeur en direct, elles apparaissent une fois, au
bout d'~1,5 s.

Les flèches de roque héritent du même piège que la surbrillance du dernier
coup — corrigées par la même fonction, `Chess960Game.displaySquares(forUCI:)`.

### Un vrai bug de production trouvé en écrivant le test

`checkForBlunderRetroactively` enfilait la réponse du moteur AVANT elle-même,
inversé par rapport à `PlayViewModel.commit()`. Conséquence en jeu normal :
la réponse du moteur (même file sérielle) aurait presque TOUJOURS fait
échouer le garde de fraîcheur de la vérification (« aucun autre coup joué
depuis ») avant même qu'elle s'exécute — l'alerte n'aurait quasiment jamais pu
se déclencher. Un test au moteur réel (dame hors-jeu, 1.e4 g6 2.Dh5??) l'a
attrapé immédiatement ; corrigé en réordonnant, comme l'original.

### La VRAIE cause de la fragilité « moteur réel » de toute la journée

En écrivant ces tests, ils échouaient TOUS TROIS quand Swift Testing les
lançait en parallèle (comportement par défaut d'une suite), alors que chacun
passe seul. Ce n'était PAS de la contention générique — `EngineSearchBudgetBenchmark`
documente déjà la cause exacte, mot pour mot : ChessKitEngine détourne
`stdout` comme canal UCI, une ressource GLOBALE au processus ; deux Stockfish
concurrents se corrompent mutuellement. `@Suite(.serialized)` sur
`Chess960PlayViewModelTests` — absent jusqu'ici — règle intégralement le
problème : la suite COMPLÈTE (732 tests) passe maintenant SANS AUCUN flake,
alors qu'elle en portait un depuis le premier test au moteur réel de la
journée. Chaque fragilité « contention de la suite complète » invoquée plus
tôt aujourd'hui pour les tests Chess960 était donc CETTE cause précise, pas
une vague lenteur — leçon qui aurait dû être appliquée dès le premier test au
moteur réel de la session.

### Ce que ça a coûté de tester l'alerte gaffe correctement

Premier jet : trois `forceMove` synchrones (e4, g6, Dh5) sans le moindre
`await` entre eux. La tâche moteur PÉRIMÉE — déclenchée par la transition
vers les noirs après e4, avant que g6 (forcé juste après) n'ait eu la moindre
chance d'être VUE par elle — ne découvre son garde-fou qu'à SON tour
d'exécution sur la file, et retombait alors sur l'état FINAL (après Dh5,
noirs au trait) plutôt que sur l'état intermédiaire qui l'aurait neutralisée :
elle jouait gxh5 elle-même, avant que la vérification de gaffe n'ait sa
chance. Corrigé en laissant explicitement à cette tâche périmée le temps de
s'auto-neutraliser (`Task.sleep(3s)`, le temps que la vérification de gaffe
d'e4 lui-même se termine) avant le coup qui compte.

### Vérifié

732 tests unitaires verts — SUITE COMPLÈTE, sans flake, la première fois de la
journée. 6 tests d'interface Chess960 verts.

## 25/08 — Chess960 : l'analyse de fin de partie, comme en mode « Jouer »

Demande de l'utilisateur : « à la fin de la partie chess960 [...] l'analyse
de la partie démarre comme sur le jeu normal ». Cadrage retenu après
question posée (trois options soumises) : un écran d'analyse Chess960
ALLÉGÉ — plateau, barre d'éval, flèches des meilleurs coups, navigation coup
par coup, export — SANS classification (gaffe/imprécision/erreur), sans
génération de puzzles, sans persistance en bibliothèque. `AnalysisViewModel`
lui-même ne pouvait pas être réutilisé tel quel : il charge une partie via
`Game(pgn:)`/`PGNLoader.reconstruct`, qui construisent tous deux un
`Board(position: .standard)` et ignorent les tags `[FEN]`/`[SetUp]` — un PGN
Chess960 s'y rechargerait depuis la position STANDARD, coups y compris (la
logique de roque de ChessKit code en dur e1/e8/a1/h1).

### `Chess960PGNParser` : le lecteur qu'il fallait pour fermer la boucle

Nouveau parseur dédié, sans dépendre de ChessKit pour la reconstruction :
lit `[FEN]`/`[SetUp]` à la main, puis fait rejouer chaque jeton SAN du
movetext par `Chess960Game.legalMoves()` — en ESSAYANT chaque coup légal et
en comparant le SAN produit par `Chess960Game.apply(_:)` au jeton attendu.
Réutilise les seuls bouts VRAIMENT génériques de `PGNLoader`
(`movetext(of:)`, `tags(of:)`), qui ne présument rien de la position de
départ. Prouvé par aller-retour : exporter une partie Chess960 (roque
compris) puis la reparser doit rendre exactement le même journal SAN/UCI.

### `Chess960AnalysisViewModel` : la même discipline moteur que Chess960PlayViewModel

Salve bornée (MultiPV 3, ~1,5 s) à chaque navigation, plutôt qu'une analyse
continue — même arbitrage que l'indice de coup du 25/08 : éviter une
QUATRIÈME classe de bug de flux à consommateur unique dans la même journée.
Jeton de fraîcheur (`analysisToken`) pour ignorer un résultat périmé si la
navigation a bougé plusieurs fois avant qu'une salve ne conclue — nécessaire
ici précisément parce que l'écran d'analyse permet de naviguer BEAUCOUP plus
vite qu'une partie en direct. Surbrillance du dernier coup et flèches de
roque héritent de la même correction que Chess960PlayViewModel
(`Chess960Game.displaySquares(forUCI:)` : la case RÉELLE du roi, pas celle
où se tenait la tour dans le dialecte UCI roi-prend-tour).

### Câblage : bilan de fin de partie → route → hôte SessionStore

`Chess960PlayView` et `Chess960TwoPlayerView` gagnent un vrai `gameOverPanel`
(Accueil / Analyser), remplaçant le simple bandeau de résultat — même
patron visuel que `PlayView.gameOverPanel`, sans Revanche : relancer une
partie Chess960 repasse par le réglage de la position, pas par un
redémarrage à l'identique. « Analyser » porte le PGN COMPLET
(`exportedPGN`, tags Variant/SetUp/FEN compris), pas la FEN affichée — même
piège déjà documenté pour « Jouer à partir d'ici » : l'analyse doit rejouer
TOUTE la partie. Nouvelle route `activeChess960Analysis(String)` + un
`Chess960AnalysisActiveGameHost` construit paresseusement via `SessionStore`
— même discipline que tous les autres écrans à moteur, non négociable
depuis le bug de gel du 25/08 (construction inline dans `destination(for:)`).

### La contention grandissante rattrape un test de pendule déjà fragile

La suite complète (740 tests désormais, +8 pour ce lot) a fait échouer
`GameClockStartTests.whiteTimeDecreasesBeforeTheFirstMove` — DÉJÀ identifié
et déjà élargi une fois aujourd'hui (120 s) pour la même raison : les bancs
d'essai moteur saturent le `MainActor` pendant la suite complète. Deux
suites Chess960 RÉELLES de plus (jeu + analyse) ajoutent leur propre
contention ; mesuré, un échec à 268,9 s AVEC la fenêtre de 120 s — signe
qu'un seul `Task.sleep` affamé peut, à lui seul, dépasser tout le budget
restant. Fenêtre réélargie à 300 s. Passe seul en quelques secondes : pas
une régression de la pendule, un effet de bord attendu d'avoir ajouté deux
suites au moteur réel de plus dans la même journée.

### Vérifié

740 tests unitaires verts — SUITE COMPLÈTE (unitaires ChessLabTests), sans
échec. 7 tests d'interface Chess960 verts, dont le nouveau bout-en-bout :
partie Chess960 → coup joué → abandon → « Analyser » → écran d'analyse
affichant la partie effectivement rejouée.
