# Métadonnées App Store Connect — ChessLab

**Version courante : 1.6.0** (build à fixer — voir « Version et build » plus bas). Voir `RELEASE_NOTES-1.6.0.md` pour le détail complet des changements depuis la 1.5.

Tout ce qui suit est à copier-coller directement dans les champs correspondants d'App Store Connect. Les limites de caractères d'Apple sont respectées (vérifiées).

> **Convention d'édition** : dans les blocs à coller, JAMAIS de retour à la ligne à l'intérieur d'un paragraphe — App Store Connect rend chaque saut de ligne tel quel, une césure à 78 colonnes hacherait le texte sur la fiche. Une ligne par paragraphe ; les titres EN CAPITALES gardent leur propre ligne.

> **Pour cette mise à jour**, trois champs demandent une action : **Nouveautés de cette version** (ci-dessous, obligatoire), le numéro de build (voir « Version et build » — `CURRENT_PROJECT_VERSION` vaut `8.1` dans le projet, à corriger avant de soumettre), et la **description**, qui gagne un bloc VARIANTES (Chess960 + trois variantes Fairy-Stockfish) et voit son compte de cours de finales passer de 77 à 78 (« Pions électriques »). Le **texte promotionnel** est mis à jour pour le même compte ; nom, sous-titre, mots-clés et catégories restent valables.

---

## Nouveautés de cette version — 1.6 (4000 car. max)

C'est le champ « What's New in This Version ». Rédigé pour l'utilisateur final : ce qu'il va sentir, pas ce qui a été refactorisé.

> ⏳ **Pas encore soumise.** Ce texte couvre 1.5 → 1.6 (20 → 25/08/2026). Point de départ : 1.5.0 build 7, en ligne depuis le 20/08/2026.

### Français (1456 car. — limite 4 000)

```
NOUVEAU : LE MODULE VARIANTES
Chess960 (les échecs Fischer Random) rejoint l'app : position de départ aléatoire, choisie par numéro (0-959), ou composée vous-même. Jouez contre l'ordinateur ou à deux, avec une analyse de fin de partie complète, comme en mode « Jouer ». Trois variantes de plus, présentées en tuiles : Roi de la colline, Trois échecs et Horde — chacune contre l'ordinateur avec indice, alerte gaffe et barre d'évaluation.

OUVERTURES : UN NOUVEAU LECTEUR
L'index devient un arbre des lignes : chaque coup n'apparaît qu'une fois. Sous un échiquier fixe : les coups joués par les maîtres avec leurs pourcentages, les trois meilleurs coups de Stockfish, et une barre d'évaluation — tout précalculé, jamais d'attente.

FINALES : 78 COURS, ET UNE RECHERCHE
« Pions électriques » rejoint le catalogue. Une leçon corrigée (le pion passé éloigné), et un champ de recherche par nom, comme dans Ouvertures.

LES MODES SE PARLENT, AU MÊME ENDROIT PARTOUT
« Changer de mode » — qui bascule vers le Laboratoire, l'ordinateur ou une partie à deux en emportant la position affichée — a désormais la même apparence sur les neuf écrans concernés, au lieu d'être caché dans un menu d'export.

ET AUSSI
Reprendre un coup consulté agit dès le premier appui, avec une annulation à disposition. Le thème du plateau ne se choisit plus que dans les Réglages. Le Laboratoire explique chaque statistique d'un tap. Et une installation neuve pèse 60 Mo au lieu de 175.
```

### English (1343 char. — 4,000 limit)

```
NEW: THE VARIANTS MODULE
Chess960 (Fischer Random Chess) joins the app: a randomly drawn starting position, one chosen by number (0-959), or one you compose yourself. Play against the computer or two players, with a full post-game analysis, just like "Play" mode. Three more variants, in a tile-based hub: King of the Hill, Three-Check and Horde — each against the computer with hints, blunder alerts and an eval bar.

OPENINGS: A NEW READER
The index becomes a tree of lines: every move appears only once. Under a fixed board: the moves masters actually played with their percentages, Stockfish's top three moves, and an eval bar — all precomputed, never a wait.

ENDGAMES: 78 COURSES, AND A SEARCH FIELD
"Electric Pawns" joins the catalogue. A fixed lesson (the distant passed pawn), and a search-by-name field, just like Openings.

THE MODES TALK TO EACH OTHER, THE SAME WAY EVERYWHERE
"Switch mode" — which jumps to the Laboratory, the computer or a two-player game while carrying the displayed position along — now looks the same across all nine relevant screens, instead of being buried in an export menu.

ALSO
Resuming a reviewed move now acts on the first tap, with an undo available. The board theme is now chosen only in Settings. The Laboratory explains each statistic with a tap. And a fresh install now takes 60MB instead of 175.
```

---

## Français (langue principale)

**Nom de l'app** (30 car. max) :
```
ChessLab
```

**Sous-titre** (30 car. max — 28 utilisés) :
```
Jouez, analysez, progressez.
```

**Mots-clés** (100 car. max — 94 utilisés, séparés par des virgules, sans espace) :
```
stockfish,tactique,ouverture,puzzle,gambit,fen,pgn,elo,entrainement,scanner,analyse,ia,plateau
```

**Texte promotionnel** (170 car. max — modifiable sans nouvelle revue) :
```
Analysez vos parties, scannez un échiquier : 58 ouvertures, 78 finales prouvées, Chess960 et 3 variantes, 100 000+ puzzles — 100% local.
```

**Description** (4000 car. max) :
```
ChessLab est un compagnon d'échecs complet pour iPhone et iPad : jouer, analyser, s'entraîner et expérimenter, avec le moteur Stockfish intégré et sans jamais quitter l'application.

CONTRE STOCKFISH
Affrontez Stockfish à la force de votre choix, du débutant (~900 Elo) au niveau maximal (~3190 Elo), avec ou sans pendule. Indice, alerte avant un coup risqué et barre d'évaluation sont activables à tout moment.

DEUX JOUEURS
Jouez à deux sur le même appareil, avec un mode « table » qui retourne les pièces pour rester lisible face à face.

ANALYSER
Passez une partie ou une position au crible de Stockfish : classification de chaque coup (imprécision, erreur, gaffe, coup brillant…), courbe d'évaluation, flèches du meilleur coup et de la menace adverse, lecture automatique. Entrée par PGN, FEN, éditeur de position ou scanner photo.

OUVERTURES
Choisissez une ouverture et avancez coup par coup : chaque coup est expliqué, les variantes sont proposées, et des flèches colorées relient le plateau à la liste des coups. 58 ouvertures rédigées à la main (bilingues), toutes relues au moteur, avec un entraînement en répétition espacée simplifié pour les mémoriser.

LE COIN DES FINALES
78 cours prouvés par table de finales — le verdict mathématique exact : aucun coup enseigné ne lâche le gain, aucune défense proposée ne perd la nulle. Neuf familles, de l'opposition aux études célèbres. Et l'entraînement libre : concluez la position contre la meilleure défense, tout coup qui préserve le verdict est accepté — pas seulement celui de la leçon.

VARIANTES
Chess960 (les échecs Fischer Random) : position de départ aléatoire, choisie par numéro, ou composée soi-même, avec la même analyse de fin de partie qu'en mode « Jouer ». Trois variantes de plus contre l'ordinateur : Roi de la colline, Trois échecs et Horde.

VOS PROPRES RÉPERTOIRES
Importez vos ouvertures au format PGN, variantes comprises, et entraînez-les avec le même système. Partagez un répertoire par simple fichier — aucun compte, aucun serveur. Ce que vous avez déjà mémorisé sur une position vaut aussitôt dans le répertoire importé.

PUZZLES
Plus de 100 000 problèmes tactiques issus de la base Lichess, filtrables par niveau et par thème, plus des puzzles générés automatiquement depuis vos propres erreurs en analyse. Répétition espacée et suivi de vos points forts.

LABORATOIRE
Faites s'affronter deux réglages de Stockfish sur une série de parties pour comparer leur force, avec estimation de l'écart Elo et intervalle de confiance.

ÉDITEUR ET SCANNER
Composez une position à la main, ou scannez-la depuis une capture d'écran ou une photo d'écran — la reconnaissance se corrige avant de jouer ou d'analyser.

CONÇU POUR IPAD
Échiquier grand format et panneaux visibles simultanément (coups, courbe, MultiPV), clavier et trackpad pris en charge, portrait et paysage soignés.

SYNCHRONISATION iCLOUD (optionnelle)
Activez la synchronisation iCloud dans les Réglages pour que vos parties suivent tous vos appareils, via votre iCloud privé. Aucun compte à créer, aucun serveur ChessLab. Désactivée par défaut : l'app fonctionne entièrement hors ligne.

VIE PRIVÉE
Hors ligne par défaut : aucun serveur ChessLab, aucune mesure d'audience, aucune publicité. Vos parties et réglages restent sur votre appareil. La synchronisation iCloud, si vous l'activez, utilise votre propre iCloud privé — vos données ne sont jamais partagées avec le développeur. Bilingue français/anglais.

ChessLab intègre le moteur Stockfish (licence GPLv3) et des jeux de pièces vectorielles libres — cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) et merida (GPLv2+). Code source complet et mentions de licence disponibles depuis l'app (Réglages → Licences).
```

---

## English (secondary localization — App Store Connect: "English (U.S.)")

**Name** (30 char. max):
```
ChessLab
```

**Subtitle** (30 char. max — 23 used):
```
Play, analyze, improve.
```

**Keywords** (100 char. max — 92 used):
```
stockfish,tactics,openings,puzzle,gambit,fen,pgn,elo,training,scanner,analysis,offline,board
```

**Promotional text** (170 char. max):
```
Analyze your games, scan a chessboard: 58 openings, 78 proven endgames, Chess960 and 3 variants, 100,000+ puzzles — fully offline, no ads.
```

**Description** (4000 char. max):
```
ChessLab is a complete chess companion for iPhone and iPad: play, analyze, train and experiment, with the Stockfish engine built in and without ever leaving the app.

PLAY VS STOCKFISH
Take on Stockfish at any strength you like, from beginner (~900 Elo) to maximum (~3190 Elo), with or without a clock. Hints, a warning before risky moves, and an evaluation bar can all be toggled on demand.

TWO PLAYERS
Play locally on the same device, with a "pass-and-play" mode that flips the pieces so both players read the board comfortably.

ANALYZE
Run a game or a position through Stockfish: move-by-move classification (inaccuracy, mistake, blunder, brilliant move…), an evaluation graph, best-move and opponent-threat arrows, and auto-play through the moves. Import by PGN, FEN, position editor, or photo scanner.

OPENINGS
Pick an opening and step through it move by move: every move is explained, the alternatives are offered, and colored arrows link the board to the move list. 58 hand-written openings (bilingual), all reviewed by the engine, with simplified spaced-repetition training to memorize them.

THE ENDGAME CORNER
78 courses proven by endgame tablebases — the exact mathematical verdict: no taught move gives up a win, no recommended defence loses a draw. Nine families, from the opposition to famous studies. And free training: finish the position against best defence, where any move that preserves the verdict is accepted — not just the lesson's move.

VARIANTS
Chess960 (Fischer Random Chess): a randomly drawn starting position, one chosen by number, or one you compose yourself, with a full post-game analysis just like "Play" mode. Three more variants against the computer: King of the Hill, Three-Check and Horde.

YOUR OWN REPERTOIRES
Import your openings as PGN, variations included, and drill them with the same system. Share a repertoire as a single file — no account, no server. What you already know about a position counts right away in the imported repertoire.

PUZZLES
Over 100,000 tactics puzzles from the Lichess database, filterable by rating and theme, plus puzzles generated automatically from your own mistakes in analysis. Spaced repetition and progress tracking included.

LABORATORY
Pit two Stockfish configurations against each other over a series of games to compare their strength, with an estimated Elo gap and confidence interval.

EDITOR AND SCANNER
Set up a position by hand, or scan it from a screenshot or a photo — review and correct the recognized position before playing or analyzing it.

BUILT FOR IPAD
Full-size board with move list, graph and MultiPV visible at once, keyboard and trackpad support, polished portrait and landscape layouts.

iCLOUD SYNC (optional)
Turn on iCloud sync in Settings so your games follow you across all your devices, via your private iCloud. No account to create, no ChessLab server. Off by default: the app works fully offline.

PRIVACY
Offline by default: no ChessLab server, no analytics, no ads. Your games and settings stay on your device. iCloud sync, if you enable it, uses your own private iCloud — your data is never shared with the developer. Fully bilingual, French and English.

ChessLab embeds the Stockfish engine (GPLv3 license) and free vector piece sets — cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) and merida (GPLv2+). Full source code and license notices are available from within the app (Settings → Licenses).
```

---

## Champs communs (indépendants de la langue)

- **Catégorie principale** : Jeux (Games)
- **Sous-catégorie** : Plateau (Board)
- **Catégorie secondaire** (optionnel) : Éducation
- **Copyright** : `© 2026 Thierry Maeder` — déduit du certificat de signature local (« Apple Development: Thierry Maeder (N982QZWW97) »), qui indique un compte individuel. À vérifier contre developer.apple.com/account ▸ Membership pour l'orthographe exacte avant de coller.
- **URL du support** : `https://thmaed.github.io/ChessLab/support.html` (page déposée dans `docs/support.html`, publique — reste à activer GitHub Pages pour qu'elle soit servie, voir `README.md`). En repli immédiat, le temps d'activer Pages : `https://github.com/thmaed/ChessLab/issues`.
- **URL marketing** (optionnel) : `https://github.com/thmaed/ChessLab`
- **URL de la politique de confidentialité** : `https://thmaed.github.io/ChessLab/privacy-policy.html` (page déposée dans `docs/privacy-policy.html`, publique — même remarque sur l'activation de GitHub Pages).
- **Coordonnées de contact** (non publiques, pour Apple uniquement) : nom, adresse, téléphone, email valides — à renseigner dans App Store Connect.

### Export compliance (chiffrement)
`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` est déjà réglé dans le projet. L'app n'implémente aucune cryptographie propre. La seule activité réseau possible, la synchronisation iCloud (optionnelle, désactivée par défaut), passe par CloudKit — chiffrement standard fourni par le système Apple, donc **exempté** au sens de l'export compliance. Si App Store Connect pose la question : aucune cryptographie propriétaire, exempté.

### App Privacy (étiquette de confidentialité)
Réponse à la question « Collectez-vous des données ? » : **Non**. Aucun SDK tiers d'analytics, de publicité ou de suivi n'est intégré (les seules dépendances tierces sont ChessKit et le moteur Stockfish vendorisé, qui tournent entièrement localement). Le champ « scan de l'appareil photo » sert uniquement à la reconnaissance locale d'une position, jamais à un envoi réseau. La synchronisation iCloud (optionnelle) stocke les données dans l'iCloud **privé** de l'utilisateur (base CloudKit privée), à laquelle le développeur n'a aucun accès : Apple ne considère pas cela comme une collecte de données par le développeur. Résultat attendu dans le questionnaire App Store Connect : « Data Not Collected » pour toutes les catégories.

### Classification par âge
Le nouveau questionnaire d'âge (contenu, pas de violence, pas de contenu généré par les utilisateurs partagé publiquement, pas de jeu d'argent, pas d'accès web non restreint) doit répondre « aucun » partout → note **4+**.

### App Accessibility (App Information ▸ Accessibility)
Réponses déduites du code (vérifié, pas deviné) :
- **VoiceOver** : Oui — `accessibilityLabel`/`Value`/`Hint` sur 17 fichiers, coups annoncés en SAN.
- **Larger Text** (Dynamic Type) : Oui — quasi tous les textes utilisent des styles sémantiques (`.body`, `.headline`…), réactifs par défaut.
- **Reduced Motion** : Oui — `accessibilityReduceMotion` géré dans `Theme.swift` et `ChessBoardView.swift`.
- **Dark Interface** : Oui — l'app est en sombre forcé partout (`.preferredColorScheme(.dark)`).
- **Sufficient Contrast** : probablement oui (texte blanc sur fond très sombre), mais pas d'audit WCAG automatisé fait — à confirmer visuellement avant de cocher.
- **Voice Control** : aucune adaptation spécifique trouvée dans le code — ne cocher que si testé manuellement sur appareil.
- **Captions** : non applicable, pas de contenu audio/vidéo narratif.

### Version et build

**1.6.0, build à corriger avant soumission** — nouveautés détaillées dans `RELEASE_NOTES-1.6.0.md`, et le texte prêt à coller est la section « Nouveautés de cette version » en haut de ce fichier.

Vérifié dans `ChessLab.xcodeproj/project.pbxproj` (25/08/2026) : la cible applicative (`com.chesslab.ChessLab`) porte `MARKETING_VERSION = 1.6` aux deux configurations, Debug et Release — correct. Mais `CURRENT_PROJECT_VERSION = 8.1` **aux deux configurations**, ce qui n'est probablement pas volontaire : le dernier build réellement soumis était le 7 (1.5.0). App Store Connect exige un entier (ou une liste d'entiers séparés par des points) strictement supérieur au dernier build soumis — `8` conviendrait, `8.1` est à vérifier avant de soumettre.

⏳ **1.6.0 : pas encore soumise.** Succède au build 7 de la 1.5.0, en ligne depuis le 20/08/2026.

Les cibles de TEST (`ChessLabTests`, `ChessLabUITests`) sont restées en `1.2.0` / build 3. **Sans effet sur la soumission** : leurs bundles ne sont pas livrés. À aligner un jour par propreté, pas avant d'expédier.

Incrémenter `CURRENT_PROJECT_VERSION` à chaque nouveau build renvoyé à Apple, même version marketing.

### ⚠️ À FAIRE AVANT DE SOUMETTRE — pousser le code source

Les notes réviseurs (plus bas) affirment que « the complete source code of the app — **matching this submitted build** — is published publicly at github.com/thmaed/ChessLab ». Ce n'est pas une formule de style : Stockfish étant GPLv3, le binaire ChessLab est une œuvre dérivée GPLv3, et la publication du code correspondant est une **obligation de licence**, pas un argument commercial.

Vérifier donc, juste avant d'archiver :

```
git status -sb        # doit indiquer 'main...origin/main' sans 'ahead'
git push origin main
```

Au 19/08/2026, `main` est poussé au fil de l'eau (la nuit de travail du 18-19/08 a été poussée commit par commit). Vérifier malgré tout au moment de soumettre (`git log --oneline origin/main..HEAD | wc -l` doit rendre 0) : soumettre sans pousser publierait un binaire dont les sources annoncées ne correspondent pas.

### Historique des versions
- **1.6.0** — pas encore soumise : module Variantes (Chess960 complet + trois variantes Fairy-Stockfish), nouveau lecteur d'Ouvertures en arbre, Finales à 78 cours avec recherche, « Changer de mode » uniformisé sur neuf écrans, stockage allégé (175 → 60 Mo) (`RELEASE_NOTES-1.6.0.md` — couvre 1.5 → 1.6).
- **1.5.0** — module Finales (77 cours prouvés par tablebase, 9 familles), entraînement libre arbitré au verdict, correctif majeur iOS 18, ~900 positions ajoutées aux ouvertures, verdicts d'analyse affinés, sélecteur « Changer de mode » avec reprise de position, Stockfish 17.1 (`RELEASE_NOTES-1.5.0.md` — couvre 1.2 → 1.5).
- **1.4.0** — préparée, **jamais soumise** : répertoires d'ouvertures personnels (import PGN + partage par fichier), les 58 ouvertures relues au moteur, un seul essai par puzzle, lecteur d'ouvertures à plateau ancré (`RELEASE_NOTES-1.4.0.md`, conservé comme document historique). Son contenu est livré avec la 1.5.
- **1.3.0** — préparée, **jamais soumise** : échiquier tolérant au doigt, score de précision recalibré, revue d'analyse fiabilisée, iPhone en portrait. Son contenu est livré avec la 1.4 ; aucune note de version distincte n'a été rédigée.
- **1.2.0** — Ouvertures repensées, interface iPad/Mac, synchro iCloud (`RELEASE_NOTES-1.2.0.md`, regroupe 1.0.2 et 1.1.0).

---

## App Review Notes (paste into App Store Connect → App Review Information → Notes)

English, for the Apple reviewer. Frames the app's value proposition (six advanced modes, entirely free), then explains the camera permission, the network call, the licensing situation (GPLv3 engine, public source), and that no login/test account is needed.

```
ChessLab's purpose is to offer an extensive set of advanced chess features — entirely free, with no paywall, no ads, and no in-app purchases. That is the app's core value: depth and quality normally found in paid or subscription chess apps, given away for free as a passion project. It bundles six modes:

1. Play vs the computer (powered by the embedded Stockfish engine) — adjustable strength (Elo ~900 to ~3190), clocks, hints, risky-move warnings, opening book. 2. Two Players — local pass-and-play on a single device. 3. Analyze — full game/position analysis with Stockfish: move-by-move classification, evaluation graph, best-move/threat arrows. 4. Openings — 58 hand-written, annotated openings; step through each one move by move, with variations and simplified spaced-repetition training. 5. Puzzles — over 100,000 tactics puzzles from the Lichess database, plus puzzles auto-generated from the user's own mistakes in Analyze. 6. Laboratory — engine-vs-engine testing to compare Stockfish configurations over a series of games.

There is no account, no server, no login — nothing to set up before reviewing.

CAMERA: the Scanner feature uses the camera only to photograph a chess diagram (a screenshot or a physical board from above) and reconstruct the position with on-device image recognition. Photos are processed entirely on-device and are never uploaded anywhere. If testing on Simulator (no camera), use the "Paste" entry in the Scanner screen with any chess diagram image copied to the clipboard, or the "Import a file" entry (visible on Mac Catalyst) — both skip the camera and exercise the same recognition pipeline.

NETWORK: ChessLab has no first-party or third-party backend — no ChessLab server, no API, no analytics, no ads. The ONLY network activity is an optional iCloud sync, which is OFF by default. When a user turns it on (Settings → Sync), SwiftData/CloudKit syncs their own data — saved games, puzzle progress, and opening-training progress — through the user's OWN private iCloud database (CloudKit private database). The bundled content (the 100,000+ puzzle library and the 58 opening courses) stays local and is never synced. No data is shared with the developer, so the App Privacy answer remains "Data Not Collected". With sync disabled — the default — the app makes no network calls at all.

ENGINE LICENSE (GPLv3): ChessLab embeds the Stockfish chess engine, compiled from its own sources and bundled directly into the app (with ARM NEON optimizations). Because Stockfish is GPLv3, the ChessLab binary as a whole is a GPLv3 derivative work. To comply, the complete source code of the app — matching this submitted build — is published publicly at https://github.com/thmaed/ChessLab. Copyright and license notices for all third-party components (Stockfish/GPLv3, ChessKit/MIT, the chess piece sets cburnett/GPLv2+ & CC BY-SA 3.0, chessnut/Apache 2.0 and merida/GPLv2+, the Lichess puzzle database/CC0) are also shown in-app under Settings → Licenses. All embedded piece sets are free/open-source and license-compatible with the app's GPLv3.

No in-app purchases, no ads, no user-generated content shared publicly, no multiplayer/online play.
```
