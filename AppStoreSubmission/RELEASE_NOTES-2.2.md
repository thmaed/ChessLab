# Notes de version — ChessLab 2.2

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> Version `2.2`, build `22` (la 2.1, build 21, est en vente depuis le 05/11/2026 ; le 22 n'a jamais été téléversé). iOS et Android partent ensemble (Play : voir `android/PARITE.md`). Préparée le 09/11/2026 ; le build n'est pas archivé, la version n'est pas soumise.

## Ce qui est nouveau

- **Scanner** : détecteur réentraîné — les points de coups légaux et les pointes de flèches ne sont plus lus comme des pions (fausses pièces 5,25 % → 0,016 % sur jeux de pièces inconnus) ; photos d'écran (flou, moiré, reflets) : sur des dégradations SYNTHÉTIQUES, 28 % → 80,7 % de plateaux lus exactement (aucune vraie photo d'écran mesurée) ; revue des cases douteuses une à une avec la vignette de l'image d'origine ; deuxième hypothèse proposée d'un toucher ; trait deviné d'après un roi en échec ; gabarits préchargés à l'ouverture de l'écran. Trois sorties depuis l'éditeur et la confirmation (Jouer / Analyser / Départ du Laboratoire).
- **« Partager › ChessLab »** (nouvelle cible `ChessLabShare`, identifiant `com.chesslab.ChessLab.Share`, groupe d'app `group.com.chesslab.ChessLab`) : l'image est déposée dans le conteneur de groupe et le scanner s'ouvre dessus à la réactivation de l'app. Une extension iOS ne peut pas lancer l'app : elle affiche « Ouvrez ChessLab » (écart de plateforme, consigné dans `android/PARITE.md`). Vérifié sur iPhone depuis Photos.
- **Collections de puzzles** : export PGN depuis le menu de la collection (l'en-tête `[PuzzleSetup]` permet de relire le fichier à l'identique) ; copie iCloud des collections importées (iOS seulement — iCloud est hors périmètre Android) ; programme Woodpecker stocké compressé pour tenir sous la limite d'un enregistrement CloudKit ; réglage « Afficher le thème du puzzle » (demande de Ron, allumé par défaut) ; « fourchette » exige de vraies cibles ; les captures désambiguïsées (`Rfxd7+`) sont lues sur la bonne pièce (contournement d'un défaut de ChessKit 0.17.0).
- **Laboratoire Chess960** : séries par numéro de position (0-959) ou position tirée par paire de parties, export et analyse des parties.
- **Stockfish 19** (17.1 avant) : un seul réseau (98,5 Mo), +21 % de nœuds/s mesurés sur Apple Silicon, `UCI_Elo` toujours 1320-3190. Les scores sont ramenés sur l'échelle de la 17.1 (les jauges et les seuils de précision gardent leur sens) ; la force des personnages à bas niveau a été mesurée, la compensation proposée n'est pas appliquée (`tools/stockfish-compare/README.md`). Les analyses enregistrées sont refaites (nouveau profil de cache).
- **Analyse** : l'avancement du calcul est une jauge orange vive au-dessus du plateau (plus de capsule d'état) ; une partie rechargée garde ses promotions ; une position invalide n'arrête plus l'app.
- **Coup volé** : la position du second coup d'un tour ne porte plus de case de prise en passant du mauvais côté.
- **Revue du code depuis la 2.1** : dix constats vérifiés, huit corrigés (voir `PROGRESS.md`).

## Vérifié avant la fiche

- iOS : 1282 tests unitaires verts (simulateur iPhone) ; interface iPhone (simulateur) 132 tests, 0 échec ; iPad en français : 7 tests pensés pour la barre d'outils iPhone échouent (mise en page iPad en barre latérale), sans défaut de l'app.
- Android : tests JVM verts ; instrumentés 187/187 sur Galaxy A16.
- Les tests d'interface sur appareils physiques (iPhone XS, iPhone 11, iPhone3) n'ont pas pu tourner : « Timed out while enabling automation mode » (réglage Développeur à réactiver).

## Fiche App Store

- Textes FR et EN-GB : `METADATA.md` (nouveautés, notes pour la révision avec le parcours de l'extension de partage).
- Captures rafraîchies : voir `screenshots/` (la capture « coach » montrait la capsule « Moteur en attente » supprimée).

---

## English

Version 2.2 (build 22). New: a more reliable Scanner (screen photos, one-by-one review of doubtful squares, second guess, side to move guessed), Share → ChessLab from Photos (new share extension), puzzle collections exported as PGN and copied to iCloud (iOS), a "Show the puzzle theme" setting, a Chess960 Laboratory, Stockfish 19 (scores kept on the 17.1 scale), and a visible progress gauge during analysis. Details above (French).
