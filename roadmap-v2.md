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
  - **✅ VALIDÉ (30/07/2026)** : synchro réelle **testée sur 2 appareils** — parties et progression puzzle se synchronisent correctement. Conteneur CloudKit provisionné à la 1re compilation device. L'Axe C côté synchro est donc bouclé et prouvé.
- 24/07/2026 (soir) — **Correctifs après premier essai réel de la synchro** :
  - Ajout du mode d'arrière-plan **`remote-notification`** (Info.plist à la racine, fusionné avec le plist généré) — SwiftData+CloudKit l'exige pour les push silencieux ; sans lui, faute « BUG IN CLIENT OF CLOUDKIT ». Corrigé, vérifié.
  - **✅ CORRIGÉ (même jour)** : le store est désormais **séparé en deux** (`ChessLabApp.makeModelContainer`) — `Games` (parties, synchronisable iCloud) et `Puzzles` (bibliothèque embarquée + progression, **local-only, jamais synchronisé**). Fini le flood des 100k puzzles / CKError 429 : seules les parties partent en iCloud. Sur décision de l'utilisateur, **pas de migration** — les parties/puzzles locaux existants sont réinitialisés (la bibliothèque se re-seed depuis le bundle). Vérifié : l'app lance sans crash, accueil rendu (les deux stores requêtés séparément). Textes (Réglages/Aide/METADATA) corrigés : seules les **parties** se synchronisent.
    - **✅ FAIT (27/07/2026)** : la *progression* puzzle se synchronise désormais entre appareils. Nouveau `@Model` **`PuzzleProgress`** (dans le store `Games`, synchronisé), miroir de la progression personnelle porté par `Puzzle` (clé `externalID` Lichess). `PuzzleProgressSync.mirror` recopie à chaque résolution ; `PuzzleProgressSync.reconcile` refusionne (max des compteurs, SRS le plus avancé) à l'ouverture de l'accueil, de la Progression et de la file. La bibliothèque embarquée reste **local-only**. Conservation **illimitée** (aucune purge/expiration). Tests verts (340/53 suites, dont 4 dédiés), app vérifiée au lancement.

---

- 24/07/2026 — **Axe D entamé : thèmes de plateau & jeux de pièces**.
  - Plateaux : 4 curés (Classique/vert, Bleu, Noyer/bois, Contraste élevé/accessibilité). « Ardoise » retiré (repli automatique sur Classique).
  - Jeux de pièces : 3 (cburnett/Classique déjà là + maestro/Moderne + merida/Contrasté, SVG Lichess importés dans `Assets.xcassets/Pieces`). `PieceSet` + `AppSettings.pieceSetID` + `PieceGlyphView` paramétré.
  - Réglages : sélecteurs avec **aperçu des vraies pièces** sur cases colorées (vérifié à l'écran). Attribution ajoutée dans LicensesView.
  - **⚠️ AVANT PUBLICATION** : confirmer la licence EXACTE de `maestro` et `merida` dans `github.com/lichess-org/lila` → `public/piece/COPYING.md`, et compléter l'attribution auteur si nécessaire. L'app étant déjà GPLv3 (Stockfish), les jeux GPL/CC sont compatibles ; ne PAS ajouter de jeu à licence restrictive (surtout jamais les `cc_*` = chess.com).
    - **✅ RÉSOLU (30/07/2026)** : `maestro` était CC BY-NC-SA 4.0 (NON commercial → incompatible GPLv3), remplacé par `chessnut` (Apache 2.0). `merida` = GPLv2+ (OK). Voir le journal du 30/07.

- 09/08/2026 — **Refonte de l'intégration Stockfish** (perf + freezes) :
  - Constat : ChessKitEngine 0.7.0 compilait SF17 **sans les chemins SIMD ARM** (NNUE en scalaire → 2-4× trop lent sur A13+), embarquait **25 Mo de lc0 inutiles**, et parsait la sortie moteur **sur le thread principal** (`readInBackgroundAndNotify` sur le run loop principal) → freezes sous le flot d'`info`.
  - **Package local `Vendor/CStockfish`** : Stockfish 17 vendorisé, compilé avec **USE_NEON=8 + USE_POPCNT + -O3 -DNDEBUG** (dotprod volontairement écarté : planterait A10/A11), **sans lc0**. Transport propre (shim C++) : redirige `std::cin/std::cout` du C++ et exécute la boucle UCI sur un **thread dédié** — plus de parsing sur le thread principal, plus de `dup2` sur le fd du process (donc plus de SIGPIPE).
  - **ChessKitEngine RETIRÉ** du projet. `EngineController` réécrit sur `CStockfishKit` (API publique inchangée → aucun appelant modifié). Réseau NNUE trouvé via `binaryPath = <bundle>/stockfish`.
  - Vérifié : package testé isolément (cycle UCI réel), app compile, moteur tourne à l'exécution (test UI « contre l'ordinateur » vert), suite 343/54 verte, 0 crash.
  - **Reste possible (non fait)** : mesurer le gain NPS réel sur appareil ; envisager dotprod avec dispatch runtime ; réduire les threads aux cœurs perf sur petits appareils ; petit net sur ≤4 Go.

- 30/07/2026 — **Consolidation vers la publication 1.1** (4 lots) :
  - **Licences pièces réglées** : la confirmation (COPYING.md officiel de lila) a révélé que **`maestro` est en CC BY-NC-SA 4.0** (clause NON commerciale, **incompatible GPLv3**). Retiré et **remplacé par `chessnut` (Apache 2.0)**, même créneau « Moderne ». `merida` confirmé **GPLv2+** (conservé). LicensesView + METADATA corrigés (3 jeux, tous compatibles GPLv3). Le ⚠️ licences ci-dessus est donc **levé**.
  - **Axe A — pointeur/trackpad FAIT** : anneau de survol sous le pointeur sur la case (iPad trackpad/souris, Mac), couleur adaptée à la case, inerte au doigt. Reste de l'Axe A : **multi-fenêtres/Stage Manager** (seul item non fait) et menus contextuels approfondis.
  - **Axe C — bibliothèque de parties FAITE** : recherche (joueurs + étiquettes), filtres mode (Ordinateur/Deux joueurs/Importées) et résultat (Gagnées/Nulles/Perdues), **étiquettes** libres (`GameRecord.tagsCSV`, éditeur + filtre), **import PGN multi-parties** (`GameLibraryService.importPGNCollection`, en-têtes via ChessKit `Game.tags`, mode `.imported`). Tests : 3 dédiés + suite complète 343/54 verte.
  - **Release 1.1.0 prête** : `MARKETING_VERSION` 1.1.0, build 2, RELEASE_NOTES + METADATA à jour, build Release vérifié. **Reste l'étape manuelle** : archive + upload App Store Connect (signature device).

## ⏸️ Pause — reprise prévue ~31/07/2026

**Fait à ce jour** : Axe A (socle iPad + pointeur/trackpad ; **reste multi-fenêtres/Stage Manager**), **synchro iCloud validée sur 2 appareils** (parties + progression puzzle), **Axe C bibliothèque de parties complète** (recherche/filtres/tags/import PGN multi), **Axe D thèmes** (licences réglées : cburnett/chessnut/merida), **release 1.1.0 prête à archiver**.

**Reprise — options par ordre de valeur** :
1. **Publier la 1.1** : archive + upload App Store Connect (étape manuelle, signature device) — tout le reste est prêt.
2. Suite de l'**Axe C** : tablebases Syzygy (arbitrer la taille du bundle), entraînement de répertoire, puzzles approfondis (streak, puzzle du jour), annotations persistantes, widgets/App Intents.
3. **Axe A — finition** : multi-fenêtres/Stage Manager (dernier item).
4. **Axe B** : association de fichiers .pgn/.fen (ouvrir depuis Fichiers/Finder), export diagramme.
