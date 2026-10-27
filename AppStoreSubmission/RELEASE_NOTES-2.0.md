# Notes de version — ChessLab 2.0

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> Version `2.0`, build `18` (la 1.9.2, build 17, est la dernière soumise). iOS et Android partent ensemble (Play : versionName 2.0, voir `android/PLAY-2.0.md`). Préparée le 27/10/2026 ; le build n'est pas encore archivé.

## Ce qui est nouveau

- **Séance du jour** : une carte en tête de l'accueil rassemble ce qu'il faut revoir aujourd'hui — positions d'ouverture dues (plafond réglable 2/5/8), puzzles ratés, une finale — avec la série de jours et des médailles par palier.
- **Analyse → puzzles** : l'analyse automatique en arrière-plan a été RETIRÉE (elle se bloquait sur l'avant-dernier coup). À la place, quand une analyse manuelle se termine, un récapitulatif propose de créer des puzzles depuis la partie : mats manqués d'abord, puis les erreurs les plus coûteuses, trois au plus, sur de petits échiquiers. L'utilisateur accepte ou refuse ; rien n'est créé sans lui. Les boutons « Mats manqués » ont disparu des écrans Jouer et Analyser.
- **Profil de faiblesses** dans Progrès (phases, thèmes, tendances), alimenté par les analyses.
- **Le Coach** : sous un coup, la part des joueurs de votre niveau qui le jouent (Maia-3, sur l'appareil) — erreur typique, accident, coup rare.
- **Cote de puzzle** personnelle (Glicko) et « À mon niveau ».
- **Ouvertures** : cartes illustrées, filtres Camp et Niveau, les 19 « classiques ».
- **Reprise d'une partie** : carte « Reprendre » sur l'écran de réglages d'une nouvelle partie, et confirmation avant de remplacer une partie en cours.
- **Limite de temps** en option (un interrupteur, dernier choix retenu).
- **Sorties de répertoire** : la position où l'on a quitté son répertoire rejoint les révisions FSRS.
- Visite guidée de la 2.0 pour qui met à jour (6 étapes), Aide mise à jour.

## Deux défauts corrigés avant la sortie

1. **Plantage à la reprise** (signalé sur appareil le 27/10) : ChessKit garde un droit de roque après la prise de la tour dans son coin (ici Fxa8 → FEN avec « q »). Stockfish, dans `Position::set`, cherche la tour du roque sans borne et sort de l'échiquier. Le plantage revenait à chaque reprise, la position étant rejouée à l'identique. Un garde-fou (`UCIPositionSanitizer`, `UciPositionSanitizer.kt` côté Android) corrige la FEN avant qu'elle n'atteigne le moteur, pour Stockfish et Fairy-Stockfish. La bibliothèque elle-même n'est pas corrigée (le droit périmé reste dans l'export).
2. **Le coup de mat n'était jamais classé** : `Board(position:)` examine les coups du camp qui vient de jouer, donc une position matée restait « active » ; Stockfish ne répond rien dessus, le dernier coup n'avait pas de verdict et le bilan de la partie ne se complétait jamais (ni précision, ni puzzles proposés) pour toute partie finie par un mat. `AnalysisViewModel.terminalState(of:)` donne le trait à l'autre camp avant de lire l'état. Android n'avait pas le défaut (correction déjà dans son port de ChessKit). Et le récapitulatif se déclenche maintenant sur un compteur de passes (`classificationPassCount`), pas sur la bascule de `isClassifying`, invisible quand tout est déjà en cache.

## Fiche App Store

- Textes FR et EN-GB : `METADATA.md` (description 3 995 / 3 976 caractères sur 4 000).
- Captures : un jeu par langue (`screenshots/<format>/<fr|en>/`), iPhone 6,5" (1284 × 2778), iPad 13" (2064 × 2752), iPhone Duo fermé et ouvert (voir `tools/asc/asc.py duo`).
- Notes pour la révision : première ligne de la section « App Review Notes ».

---

## English

Version 2.0 (build 18). New: Daily session with a streak and medals; after a manual analysis, a recap sheet offers to turn missed mates and costly mistakes into puzzles (background auto-analysis removed); weakness profile in Progress; the Coach (what players at your level play, Maia-3, on device); personal puzzle rating and “At my level”; illustrated opening cards with Side and Level filters; resume card for an interrupted game with a replace confirmation; optional time limit; repertoire exits feed the FSRS reviews. Two defects fixed before release: a crash on resuming a game after a rook was captured on its corner (stale castling right sent to Stockfish — now sanitised before it reaches the engine), and the mating move never being graded, which kept the accuracy and the puzzle recap from appearing after any game won by checkmate.
