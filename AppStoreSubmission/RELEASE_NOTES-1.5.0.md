# Notes de version — ChessLab 1.5.0 (build 7)

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> **Ces notes couvrent 1.2 → 1.5.** Ni la 1.3 ni la 1.4 n'ont été soumises : le dernier build envoyé à Apple reste le build 3 de la 1.2 (commit `a211763`). Un utilisateur passe donc directement de la 1.2 à la 1.5 — tout le contenu des 1.3 (échiquier tolérant au doigt, précision recalibrée, le « pourquoi » des erreurs…) et 1.4 (répertoires personnels, relecture moteur des 58 cours, un essai par puzzle, plateau ancré) est replié ici et dans le texte « Nouveautés » de `METADATA.md`. Détail : ce fichier plus `RELEASE_NOTES-1.4.0.md`, conservé comme document historique.

---

## Français

**Un correctif important pour les iPhone plus anciens**

Sur iOS 18, aucune pièce ne répondait au doigt : ni au tap, ni au glisser, sur tous les écrans de jeu. L'échiquier s'affichait normalement mais restait inerte. C'est corrigé, et l'app est désormais vérifiée sur appareil réel en iOS 18 comme en iOS 26.

**Les 58 cours d'ouverture, tous revus**

Vos adversaires ne jouent pas toujours le coup prévu par la leçon. Nous avons mesuré, position par position, ce que les joueurs de club jouent réellement, et comblé les réponses manquantes — en commençant par celles qui arrivent le plus souvent. **Près de 900 positions ont été ajoutées**, dans les 58 cours.

Un exemple : tous les répertoires noirs contre 1.d4 supposaient 2.c4. En club, une partie sur six voit 2.Ff4, la London — et le cours s'arrêtait là : vous sortiez du répertoire au deuxième coup. C'est comblé, comme la Philidor et la Petroff face à 1.e4 e5.

Là où l'ouverture ne survit pas au coup adverse, le cours le dit franchement. Chaque variante ajoutée a été vérifiée par le moteur : aucune ligne n'enseigne un coup qui perd.

**Des verdicts d'analyse plus sûrs**

Sur des parties de tournoi réelles, environ un coup sur 22 recevait une étiquette (« Imprécision », « Erreur »…) qu'une analyse plus profonde aurait contredite. Désormais, quand un verdict tombe près d'une frontière, ChessLab reprend la position avec dix fois plus d'effort avant de trancher : ces erreurs baissent de 85 %. L'analyse prend un peu plus de temps ; sur un appareil lent ou déjà chaud, le supplément est abandonné plutôt que de vous faire attendre.

**Analyser : plus simple**

« Coller un PGN » et « Position FEN » ne font plus qu'une entrée, **Analyser PGN / FEN** : collez ce que vous avez, le format est reconnu tout seul. Vous n'avez plus à savoir nommer ce que contient votre presse-papiers.

L'import d'un fichier, qui ne s'ouvrait pas, fonctionne — et accepte aussi bien un `.pgn` qu'un `.fen`.

**Bibliothèque : doublons et suppression**

Réimporter un fichier n'ajoute plus les parties en double : une partie déjà présente est reconnue même si elle vient d'un autre site, avec d'autres en-têtes et d'autres commentaires. Et vous pouvez enfin supprimer une partie (appui long, avec confirmation).

**Vos répertoires d'ouvertures : import, partage, éditeur**

Importez un répertoire au format PGN — variantes comprises : les parenthèses deviennent de vraies alternatives jouables, et les positions identiques atteintes par des ordres de coups différents fusionnent. Vos annotations suivent (? et ?? deviennent des pièges signalés, ?! des imprécisions, les commentaires s'affichent sous le plateau). Partagez-le d'un simple fichier — AirDrop, Messages, Fichiers — sans compte ni serveur : le fichier EST le répertoire. Ce que vous avez déjà mémorisé d'une position compte immédiatement dans un répertoire importé, la mémorisation étant attachée aux positions. Et modifiez-le directement dans l'app : jouez un coup sur l'échiquier pour l'ajouter, retirez une variante, écrivez votre commentaire.

Au passage, les 58 cours livrés ont aussi été relus au moteur : quinze coups fautifs corrigés, quatre défenses manquantes ajoutées, et un garde-fou permanent rejoue désormais chaque arête du catalogue sous Stockfish avant toute publication.

**Nouveau : le module Finales — 77 cours prouvés**

Soixante-dix-sept cours pour enfin convertir vos finales, groupés en neuf familles : pions (opposition, règle du carré, percée, cases conjuguées…), tours (Lucena, Philidor, Vancura, défenses de flanc et frontale…), fous, cavaliers, déséquilibres matériels (les forteresses de Karstedt et de Cochrane, tour contre fou…), dames, les quatre mats élémentaires (tour, dame, deux fous, fou et cavalier), huit études célèbres (Réti, Saavedra, l'escalier de Lasker 1890, Troitsky, Mattison, Rinck, Kubbel, Grigoriev) et des thèmes transversaux — le principe des deux faiblesses, la domination, le pat comme ressource, le roi actif. Les pièges classiques — le pat du zèle, l'échange qui perd — sont signalés là où on les commet, et deux « règles » classiques que la table de finales contredit (Bahr, Horwitz-Kling) sont enseignées telles quelles : corrigées.

Leur particularité : chaque ligne est vérifiée par table de finales, le verdict mathématique exact. Aucun coup enseigné ne lâche le gain, aucune défense proposée ne perd la nulle — une garantie qu'aucun livre ne peut donner. Et comme les ouvertures : révision espacée, entraînement, synchro iCloud.

**L'entraînement libre : concluez, à votre façon**

Depuis le lecteur d'une finale, le menu « S'entraîner » propose la ligne guidée ou l'entraînement LIBRE : vous jouez la position contre la meilleure défense, et tout coup qui préserve le verdict théorique est accepté — pas seulement celui de la leçon. Un coup qui lâche le gain est repris, avec le verdict avant/après en toutes lettres et le meilleur coup en correction ; le bilan final compte vos reprises, et « conversion propre » se mérite. L'arbitrage est vérifié par le moteur (l'écran le dit) — le pat, lui, est arbitré par les règles.

**Les modes se parlent — et emportent la position**

Un bouton « Changer de mode » (en haut à droite des Puzzles, Ouvertures, Finales et des deux modes de jeu) bascule vers le Laboratoire, une partie contre l'ordinateur ou une partie à deux — en EMPORTANT la position affichée : la position du puzzle, celle du lecteur d'ouverture, celle de la partie en cours. Depuis une partie, le menu d'export l'envoie aussi vers l'analyse ; votre partie vous attend au retour, pendule en pause. Depuis l'analyse, « Continuer au Laboratoire » fait jouer la position par deux moteurs ; en fin de série au Laboratoire, un bouton ouvre la dernière partie dans l'analyse.

Et partout, les sélecteurs disent où vous en êtes : le thème de plateau actif porte sa coche, le mode d'orientation « Deux joueurs » explique chaque choix en toutes lettres, et les parties récentes de l'accueil affichent le résultat aux couleurs de l'échiquier, comme la bibliothèque.

**Puzzles : un seul essai, comme un vrai exercice**

Un essai par défaut : un puzzle se résout en calculant la variante jusqu'au bout, pas en tentant un coup pour voir. Les trois essais restent disponibles dans les Réglages. Et le lecteur d'ouvertures garde l'échiquier à l'écran pendant que vous lisez — seul le texte défile.

**Petites retouches partout**

L'aide est accessible depuis l'accueil et décrit chaque mode. Le bilan « Progrès » contre l'ordinateur se filtre sur 7 jours, 30 jours ou tout l'historique. Les tuiles de l'accueil ne tronquent plus sur iPhone. En anglais, les joueurs du mode à deux s'appellent enfin White et Black. Et l'échiquier pardonne le doigt pressé : relâcher une pièce un peu à côté joue quand même le coup, la case visée s'allume pendant le glissement.

**Moteur mis à jour**

Stockfish 17.1 remplace Stockfish 17. Analyse plus fine, à taille d'app identique.

---

## English

**An important fix for older iPhones**

On iOS 18, no piece responded to touch — neither tap nor drag, on every playing screen. The board looked perfectly normal but was inert. This is fixed, and the app is now verified on real devices running iOS 18 as well as iOS 26.

**All 58 opening courses revised**

Your opponents don't always play the move the lesson expects. We measured, position by position, what club players actually play, and filled in the missing replies — starting with the ones that come up most often. **Nearly 900 positions have been added**, across all 58 courses.

One example among many: every Black repertoire against 1.d4 assumed White would follow with 2.c4. In club play, one game in six sees 2.Bf4, the London — and the course stopped there. You left your repertoire on move two, before the opening you chose could even appear. That gap is filled, as are the Philidor and the Petroff against 1.e4 e5.

Where an opening simply doesn't survive the opponent's move, the course now says so plainly. Every added line was verified by the engine: no course teaches a losing move.

**More reliable analysis verdicts**

On real tournament games, about one move in 22 carried a label (“Inaccuracy”, “Mistake”…) that deeper analysis would have contradicted. Now, whenever a verdict lands near a boundary, ChessLab re-examines the position with ten times the effort before deciding: those errors drop by 85%. Analysis takes a little longer; on a slow or already-warm device the extra work is dropped rather than keeping you waiting.

**Analyse: simpler**

“Paste a PGN” and “FEN position” are now a single entry, **Analyse PGN / FEN**: paste what you have and the format is detected automatically. You no longer need to know what's in your clipboard.

Importing a file, which didn't open at all, now works — and accepts `.fen` as readily as `.pgn`.

**Library: duplicates and deletion**

Re-importing a file no longer adds games twice: a game already in your library is recognised even when it comes from another site, with different headers and different comments. And you can finally delete a game (long press, with confirmation).

**Your opening repertoires: import, sharing, editor**

Import a repertoire as PGN — variations included: parentheses become real playable alternatives, and identical positions reached through different move orders merge. Your annotations follow (? and ?? become flagged traps, ?! inaccuracies, comments show under the board). Share it as a single file — AirDrop, Messages, Files — no account, no server: the file IS the repertoire. What you already know about a position counts immediately in an imported repertoire, since memorisation is attached to positions. And edit it right in the app: play a move on the board to add it, remove a line, write your own comment.

Along the way, the 58 bundled courses were also engine-reviewed: fifteen faulty moves fixed, four missing defences added, and a permanent guard now replays every edge of the catalogue under Stockfish before any release.

**New: the Endgames module — 77 proven courses**

Seventy-seven courses to finally convert your endings, grouped in nine families: pawns (opposition, rule of the square, breakthrough, corresponding squares…), rooks (Lucena, Philidor, Vancura, short-side and frontal defences…), bishops, knights, material imbalances (the Karstedt and Cochrane fortresses, rook vs bishop…), queens, the four elementary mates (rook, queen, two bishops, bishop and knight), eight famous studies (Réti, Saavedra, Lasker's 1890 ladder, Troitsky, Mattison, Rinck, Kubbel, Grigoriev) and cross-cutting themes — the principle of two weaknesses, domination, stalemate as a resource, the active king. Classic pitfalls — the eager stalemate, the losing trade — are flagged right where they happen, and two classical "rules" that the tablebase refutes (Bahr, Horwitz-Kling) are taught as they truly are: corrected.

Their distinctive feature: every line is verified against endgame tablebases, the exact mathematical verdict. No taught move gives up a win, no recommended defence loses a draw — a guarantee no book can offer. And like the openings: spaced repetition, training, iCloud sync.

**Free training: finish it your way**

From an endgame's reader, the "Train" menu offers the guided line or FREE training: you play the position out against best defence, and any move that preserves the theoretical verdict is accepted — not just the lesson's move. A move that lets the win slip is taken back, with the before/after verdicts spelled out and the best move as correction; the final report counts your take-backs, and "clean conversion" has to be earned. Arbitration is engine-checked (the screen says so) — stalemate itself is ruled by the rules.

**The modes talk to each other — and carry the position**

A "Switch mode" button (top right of Puzzles, Openings, Endgames and both playing modes) jumps to the Laboratory, a game against the computer or a two-player game — CARRYING the displayed position along: the puzzle's position, the opening reader's, the game in progress's. From a game, the export menu also sends it to analysis; your game is waiting when you come back, clock paused. From analysis, "Continue in the Laboratory" has two engines play the position out; when a Laboratory series ends, one tap opens the last game in analysis.

And selectors tell you where you stand: the active board theme carries its checkmark, the two-player orientation modes explain each choice in plain words, and recent games on the home screen show their result in chessboard colours, matching the library.

**Puzzles: one attempt, like a real exercise**

One attempt by default: a puzzle is solved by calculating the line to the end, not by trying a move to see. Three attempts remain available in Settings. And the opening reader keeps the board on screen while you read — only the text scrolls.

**Small touches everywhere**

Help is reachable from the home screen and describes every mode. The "Progress" record against the computer can be filtered to 7 days, 30 days or the whole history. Home tiles no longer truncate on iPhone. In English, the two-player names are finally White and Black. And the board forgives a hasty finger: releasing a piece slightly off-square still plays the move, and the target square lights up while you drag.

**Engine updated**

Stockfish 17.1 replaces Stockfish 17. Sharper analysis, same app size.

---

## Notes internes (ne pas coller dans App Store Connect)

- **Le correctif iOS 18 est la raison d'être de cette version.** Le défaut rendait l'app inutilisable pour tout utilisateur en iOS 18 — c'est-à-dire tous les iPhone antérieurs au 11 inclus qui n'ont pas migré. Il est passé au travers de 330 tests verts parce que tous les runtimes installés sont en iOS 26. Voir `PROGRESS.md`, section « Le plateau injouable en iOS 18 ».
- **Le moteur change, donc les évaluations changent.** L'audit complet des 58 cours a été rejoué sous 17.1 avant publication : aucune gaffe enseignée.
- **L'analyse est plus lente qu'en 1.2** sur les parties qui contiennent des verdicts limites : ×2,95 mesuré à l'origine (887 coups), ramené à ≈×2,2 par l'arrêt anticipé de la recherche d'affinage puis les gardes théorie/coup forcé (nuit du 18/08). Garde-fous : la seconde passe est abandonnée en régulation thermique ET en mode économie d'énergie, et plafonnée en temps. Si des retours signalent une attente excessive, le levier est la bande d'affinage (`refinementBand`) : ±1 rend le coût à ×1,96 et conserve 59 % du bénéfice — la courbe mesurée est dans le code.
- **L'entraînement libre est arbitré MOTEUR, pas prouvé** — l'écran le dit. Les deux voies exactes sont des décisions produit différées : embarquer les tables Syzygy WDL nécessaires pèserait 177 Mo minimum (chiffré contre l'index réel du miroir Lichess — l'estimation initiale « 15-25 Mo » était fausse), et le sondage en ligne serait le PREMIER appel réseau de l'app. La couture `EndgameVerdictJudging` est prête pour brancher l'un ou l'autre.
- **Argument de vente à ne pas surestimer.** Le ratio arêtes/positions des cours reste à 0,99 : ce sont des lignes, pas des arbres touffus. La campagne a supprimé les sorties de répertoire au deuxième coup, pas transformé les cours en encyclopédies. Le dire ainsi évite une déception au premier utilisateur fort.
- **Taille de l'app inchangée** : le réseau NNUE de la 17.1 pèse 71 Mo, comme celui de la 17. C'est ce qui a fait préférer la 17.1 à la 18, dont le réseau pèse 104 Mo (+33 Mo pour l'utilisateur, et le seuil de téléchargement cellulaire d'iOS s'en rapproche dangereusement).
- **Licence** : la GPLv3 de Stockfish impose que le code source publié corresponde au binaire soumis. Pousser le dépôt AVANT de soumettre.
