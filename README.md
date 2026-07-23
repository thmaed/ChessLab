# ChessLab

Compagnon d'échecs iOS/iPadOS — Jouer · Analyser · S'entraîner ·
Expérimenter. Application 100 % locale (voir `PROMPT-ChessLab.md` pour le
cahier des charges complet et `PROGRESS.md` pour le suivi d'avancement et
les décisions d'architecture).

## ⚠️ Licence — important avant toute distribution

Le moteur d'échecs utilisé est **Stockfish**, intégré via le paquet Swift
[`ChessKitEngine`](https://github.com/chesskit-app/chesskit-engine).
Stockfish (et Lc0, présent dans le même paquet mais non utilisé par
ChessLab) est distribué sous **licence GPLv3**.

`ChessKitEngine` et `ChessKit` (le paquet de règles/FEN/PGN/SAN) sont
eux-mêmes sous licence MIT, mais **ChessKitEngine embarque et compile les
sources de Stockfish** : le binaire final de ChessLab est donc une œuvre
dérivée sous GPLv3 dans son ensemble.

**Conséquence concrète : toute distribution de ChessLab (App Store,
TestFlight, binaire partagé, etc.) impose la conformité à la GPLv3**,
notamment :
- mettre à disposition le code source complet de l'application
  (correspondant exactement au binaire distribué) ;
- conserver les mentions de copyright et de licence ;
- ne pas ajouter de restriction supplémentaire à l'usage du code.

Avant toute publication, consulter un avis juridique si nécessaire.
Voir [Copying.txt de Stockfish](https://github.com/official-stockfish/Stockfish/blob/sf_17/Copying.txt).

## Dépendances

| Paquet | Rôle | Licence |
| --- | --- | --- |
| [ChessKit](https://github.com/chesskit-app/chesskit-swift) 0.17.0 | Règles du jeu, FEN/PGN/SAN, structures de coups/positions | MIT |
| [ChessKitEngine](https://github.com/chesskit-app/chesskit-engine) 0.7.0 | Intégration UCI de Stockfish (et Lc0) | MIT (wrapper) — **GPLv3 pour Stockfish embarqué** |

## Réseaux de neurones (NNUE)

Stockfish 17 nécessite des fichiers de réseau NNUE pour évaluer les
positions ; `ChessKitEngine` ne les embarque pas (taille du paquet).
Ils sont donc téléchargés et bundlés manuellement dans
`ChessLab/Resources/` :
- `nn-1111cefa1111.nnue` — réseau principal
- `nn-37f18f62d772.nnue` — réseau small (finales)

Source : https://tests.stockfishchess.org (réseaux officiels Stockfish).
`ChessKitEngine` les résout automatiquement dans le bundle de l'app via
`Bundle.main.url(forResource:withExtension:)` — aucune configuration
supplémentaire nécessaire.

## Assets graphiques et sonores

- Icône de l'app (`chesslab-icon2.png`) : asset propre au projet.
- **Pièces d'échiquier** : set vectoriel **cburnett**, par
  [Colin M.L. Burnett](https://commons.wikimedia.org/wiki/User:Cburnett),
  sous licence **[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/)**
  (attribution requise + partage dans les mêmes conditions). Récupéré
  depuis Wikimedia Commons (fichiers `Chess_*45.svg`) et embarqué en SVG
  dans `Assets.xcassets/Pieces/` (12 imagesets `piece_wK`…`piece_bP`).
  C'est le même set que celui utilisé par Wikipédia et Lichess.
- **Sons de plateau** (coup, prise, roque, échec) : générés par synthèse
  (sinusoïdes + enveloppe percussive, voir `SoundPlayer.swift`), aucun
  fichier audio embarqué — aucune licence à documenter.
- **Thèmes de plateau** : couleurs définies en code (`BoardTheme.swift`),
  pas d'asset. Le reste de l'interface (accueil, réglages, panneaux) suit
  une palette sombre propre à l'app, définie dans `Theme.swift`.

## Build

Prérequis : Xcode 16+ (projet testé avec Xcode 26.6, Swift 6.3),
SDK iOS 17+.

```bash
open ChessLab.xcodeproj
```

Ou en ligne de commande :

```bash
xcodebuild -project ChessLab.xcodeproj -scheme ChessLab \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Au premier build, Xcode résout automatiquement les paquets Swift
(ChessKit, ChessKitEngine) depuis GitHub.

## Architecture (résumé)

- SwiftUI + MVVM, Swift 6 (concurrency stricte).
- `EngineController` (actor) : enveloppe une instance `ChessKitEngine.Engine`,
  sérialise les commandes UCI envoyées et expose les réponses parsées
  (`AsyncStream<EngineResponse>`).
- Projet Xcode utilisant les groupes synchronisés au système de fichiers
  (Xcode 16+) : ajouter un fichier dans `ChessLab/`, `ChessLabTests/` ou
  `ChessLabUITests/` l'inclut automatiquement dans la cible correspondante,
  sans édition manuelle de `project.pbxproj`.

Détails et décisions au fil de l'eau : voir `PROGRESS.md`.
