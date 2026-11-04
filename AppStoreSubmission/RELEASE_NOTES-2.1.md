# Notes de version — ChessLab 2.1

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> Version `2.1`, build `20` (la 2.0, build 19, est en vente). iOS et Android partent ensemble (Play : voir `android/PARITE.md`). Préparée le 03/11/2026 ; le build n'est pas encore archivé.

## Ce qui est nouveau

- **Collections de puzzles importées** (demande de Ron, iPad). Un fichier PGN = une collection, chaque partie = un puzzle. L'en-tête `[FEN]` donne la position AVANT le premier coup ; le premier coup est la PRÉPARATION (le coup de l'adversaire, joué d'avance, convention Lichess) et il est surligné au départ ; la solution suit. Une partie sans FEN, illisible, ou qui n'a que sa préparation est écartée et le bilan dit pourquoi. Fichiers multiples, texte collé, renommer, supprimer, « Refaire les ratés », programme Woodpecker sur TOUTE la collection. Les collections sont hors du tirage général, de « Ratés », de la séance du jour et des statistiques ; locales à l'appareil (le fichier d'origine fait office de sauvegarde). Format validé sur le fichier réel de l'utilisateur (sept puzzles).
- **Écran Puzzles repensé** : quatre séries prêtes au toucher (À mon niveau, Ratés, À revoir, Mes parties), « Série sur mesure » en feuille, Woodpecker sur une ligne, thème à travailler en tête.
- **Réussite partielle** : trois issues (maîtrisé, partiel, raté) ; un partiel rejoint « À revoir » (SM-2, retour à 2 jours).
- **Bibliothèque de puzzles** : 106 094 → 130 935 ; barre de progression du préchargement.
- **« S'entraîner »** (ouvertures et finales) travaille la variante affichée par le lecteur (demande d'un utilisateur).
- **Découvrabilité** : bouton « Modes », sources d'Analyse dépliées, « Questions fréquentes » dans l'Aide, version dans les Réglages ; « Analyser ici » en consultation d'une partie avec pendule ; noms d'ouvertures traduits à l'affichage.
- **Demande d'avis** (StoreKit) : au plus une fois par version, après une partie gagnée ou un cycle Woodpecker bouclé, avec trois jours d'entraînement et deux réussites au moins, 120 jours d'écart.

## Fiche App Store

- Textes FR et EN-GB : `METADATA.md`.
- Notes pour la révision : première ligne de la section « App Review Notes » (avec un PGN de deux lignes à coller pour essayer l'import sans fichier).

---

## English

Version 2.1 (build 20). New: import your own puzzles from PGN files, each file a collection kept apart from the library (the first move of each game is the set-up, played for you and highlighted); a redesigned Puzzles screen with four ready-made series; partial credit for puzzles solved only in part; 24,841 more bundled puzzles (130,935); “Practice” follows the variation being read; a “Modes” button, a frequently-asked-questions section in Help, and more discoverable Analyse sources.
