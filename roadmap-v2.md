# ChessLab — Roadmap v2

Analyse fraîche (24/07/2026), après suppression des anciens fichiers roadmap.
Ancrée dans le code réel, pas générique.

## État des lieux (vérifié dans le code)

- **Plateformes** : iPhone + iPad + **Mac (Catalyst, macOS 15)** déjà actifs (`SUPPORTS_MACCATALYST = YES`, `TARGETED_DEVICE_FAMILY = "1,2"`). L'axe macOS est du **polissage**, pas de la création.
- **Navigation** : `NavigationStack` partout, **`NavigationSplitView` = 0 fichier**. Layout « téléphone » agrandi, sans barre latérale — le plus gros gisement iPad/Mac.
- **Adaptation grand écran inégale** : Play et Analyse s'adaptent (HStack, plateau borné) ; **Deux joueurs et Puzzles = 0 adaptation**.
- **Offline intégral** : aucun `URLSession` dans tout le code. Puzzles Lichess **embarqués** (`lichess_puzzles.json`, CC0).
- **iCloud** : `GameRecord`/`Puzzle` **CloudKit-ready**, synchro **désactivée** (stub `CloudSyncSettingsStore`, pas d'entitlement). Terrain prêt.
- **Mac** : barre de menus + raccourcis **partiels** (⌘N, ⌘O, ⇧⌘P, ⌘,…).
- **Modes existants** : Play vs Stockfish, Deux joueurs, Puzzles (Lichess + génération depuis parties), Ouvertures (répertoires PGN), Analyse (PGN/FEN/scan, classification, précision, courbe d'éval), Laboratoire (Elo A/B + IC), Scanner YOLO, Progression, éditeur de position.

---

## Axe A — Interface iPad (structurel, plus gros levier) 🔥

| Item | Impact | Effort | Statut |
|---|---|---|---|
| **`NavigationSplitView`** (barre latérale modes → détail) comme ossature | Élevé | Moyen-élevé | ⏳ en cours |
| Adapter **Deux joueurs & Puzzles** au grand écran (plateau + panneau latéral) | Élevé | Moyen | ⏳ |
| Multi-colonnes Analyse (plateau + coups + courbe simultanés) | Moyen | Moyen | ⏳ |
| Multi-fenêtres / Stage Manager (analyse en nouvelle fenêtre) | Moyen | Moyen | ⏳ |
| Pointeur/trackpad : survol des cases, menus contextuels | Moyen | Faible | ⏳ |

La bascule `NavigationSplitView` conditionne presque tout iPad/Mac : chantier fondateur.

## Axe B — Version macOS (polir le Catalyst existant)

| Item | Impact | Effort |
|---|---|---|
| Compléter menus + raccourcis (nav coups ⌘←/→, retourner plateau, tous les modes) | Élevé | Faible |
| Association `.pgn`/`.fen` (ouvrir depuis Finder/Files, glisser sur le Dock) | Élevé | Moyen |
| Gestion de fenêtre (taille mini, restauration, une fenêtre par partie) | Moyen | Faible-moyen |
| Export diagramme (image/PDF), impression feuille de partie | Moyen | Moyen |

## Axe C — Fonctionnalités

| Item | Impact | Effort | Offline |
|---|---|---|---|
| **Synchro iCloud optionnelle** (parties/puzzles/progression) | Élevé | Faible-moyen | Off par défaut, iCloud perso |
| Tablebases Syzygy embarquées (3-4-5 pièces) | Élevé | Moyen-élevé | Bundle volumineux à arbitrer |
| Bibliothèque de parties (recherche/filtre/tags, import PGN multi) | Élevé | Moyen | Oui |
| Entraînement de répertoire (répétition espacée, sortie de répertoire) | Élevé | Moyen | Oui |
| Puzzles approfondis (rating Glicko, streak, puzzle du jour, re-test) | Moyen-élevé | Moyen | Oui |
| Annotations persistantes (commentaires, flèches, export PGN annoté) | Moyen | Moyen | Oui |
| Widgets + App Intents/Siri (puzzle du jour, reprendre la partie) | Moyen | Faible-moyen | Oui |

## Axe D — UX

| Item | Impact | Effort |
|---|---|---|
| Thèmes de plateau & pièces (recycler les **71 jeux de pièces** du YOLO) | Élevé | Faible-moyen |
| Prémouvements en Play | Élevé | Moyen |
| Onboarding premier lancement | Moyen | Faible |
| Flèches/cercles à main levée sur le plateau | Moyen | Moyen |
| Accessibilité approfondie (VoiceOver plateau, daltonisme, Dynamic Type) | Moyen | Moyen |

## Axe E — Fondations techniques (habilitantes)

- **`NavigationSplitView`** : socle iPad/Mac (Axe A).
- **Architecture document-based** pour les parties → active Files + multi-fenêtres + association fichiers.
- **Limite moteur connue** : ChessKitEngine détourne le `stdout` global (un seul Stockfish par processus) → l'analyse multi-moteurs parallèle est **bloquée**. À documenter avant tout projet qui la suppose.

---

## Séquencement

1. **Fondation** : `NavigationSplitView` + adapter Deux joueurs/Puzzles au grand écran.
2. **Gains rapides** : menus/raccourcis Mac, thèmes plateau/pièces, synchro iCloud.
3. **Différenciation** : bibliothèque de parties, entraînement de répertoire, tablebases.
4. **Finitions** : widgets/App Intents, annotations, prémouvements, accessibilité.

## Journal d'avancement

- 24/07/2026 — Roadmap v2 créée. Démarrage Axe A (`NavigationSplitView` + fondations).
- 24/07/2026 — **Axe A, socle livré** :
  - `NavigationSplitView` iPad/Mac (barre latérale + détail), iPhone garde sa grille en pile. Chemin stack vérifié (tests UI iPhone verts), split-view vérifié (rendu + sélection de mode → détail).
  - Renommage « Contre Stockfish » → « Contre l'ordinateur » (UI + catalogue fr/en + ~10 fichiers de test).
  - Échiquier **bord à bord** sur iPad en Play (paysage : plateau pleine hauteur, éval en colonne droite ; portrait : pleine largeur). Vérifié sur iPad Pro 13″.
- 24/07/2026 — **Axe A terminé** :
  - **Uniformisation** « Ordinateur » au lieu de « Stockfish » côté joueur (adversaire, indicateurs, réglages, nom stocké, catalogue fr/en). Conservé : attribution légale (licences) et aide (qui explique le moteur), à la demande.
  - **Deux joueurs & Puzzles** adaptés au grand écran : Puzzles en deux colonnes (plateau | infos) en paysage régulier ; plateau de Deux joueurs borné pour tenir en hauteur (ne débordait plus).
  - **Menus macOS** complétés : Ouvertures ⇧⌘O, Laboratoire ⇧⌘L, Progression ⇧⌘R. Nav coup par coup gardée en raccourcis par écran (design existant).
- 24/07/2026 — **Axe C entamé : synchronisation iCloud (optionnelle)** livrée côté code/config :
  - Entitlement `ChessLab.entitlements` (CloudKit + conteneur `iCloud.com.chesslab.ChessLab`), câblé `CODE_SIGN_ENTITLEMENTS` sur les deux configs. Build simulateur signé OK.
  - Toggle « Synchroniser via iCloud » dans Réglages (off par défaut, effet au prochain lancement). Modèles vérifiés CloudKit-compatibles.
  - Aide (module iCloud) + catalogue fr/en + doc App Store Connect (METADATA : réseau/confidentialité/export nuancés) + RELEASE_NOTES-1.1.0.
  - **⚠️ Reste à faire côté iCloud** : (1) provisionner le conteneur — automatique à la 1re compilation *device* via la signature d'équipe ; (2) **tester la synchro réelle sur 2 appareils** (non vérifiable en simulateur).

---

- 24/07/2026 — **Axe D entamé : thèmes de plateau & jeux de pièces**.
  - Plateaux : 4 curés (Classique/vert, Bleu, Noyer/bois, Contraste élevé/accessibilité). « Ardoise » retiré (repli automatique sur Classique).
  - Jeux de pièces : 3 (cburnett/Classique déjà là + maestro/Moderne + merida/Contrasté, SVG Lichess importés dans `Assets.xcassets/Pieces`). `PieceSet` + `AppSettings.pieceSetID` + `PieceGlyphView` paramétré.
  - Réglages : sélecteurs avec **aperçu des vraies pièces** sur cases colorées (vérifié à l'écran). Attribution ajoutée dans LicensesView.
  - **⚠️ AVANT PUBLICATION** : confirmer la licence EXACTE de `maestro` et `merida` dans `github.com/lichess-org/lila` → `public/piece/COPYING.md`, et compléter l'attribution auteur si nécessaire. L'app étant déjà GPLv3 (Stockfish), les jeux GPL/CC sont compatibles ; ne PAS ajouter de jeu à licence restrictive (surtout jamais les `cc_*` = chess.com).

## ⏸️ Pause — reprise prévue ~31/07/2026

**Fait à ce jour** : Axe A complet (NavigationSplitView, renommage « Ordinateur », plateau bord à bord iPad, adaptation Deux joueurs/Puzzles, menus Mac) + Axe C entamé (synchro iCloud, à tester sur device).

**Reprise — options par ordre de valeur** :
1. **Thèmes de plateau & pièces** (Axe D) — 100 % local, gain visuel rapide, valorise les 71 jeux de pièces déjà collectés pour le YOLO.
2. Finir l'**Axe C** : tester la synchro iCloud sur device, puis bibliothèque de parties (recherche/tags) ou tablebases Syzygy.
3. **Axe B** : association de fichiers .pgn/.fen (ouvrir depuis Fichiers/Finder), export diagramme.
