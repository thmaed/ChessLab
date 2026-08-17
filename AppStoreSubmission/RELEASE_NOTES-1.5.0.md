# Notes de version — ChessLab 1.5.0 (build 7)

Texte prêt à coller dans App Store Connect, en français puis en anglais.
Limite Apple : 4 000 caractères. Les deux versions tiennent largement.

---

## Français

**Un correctif important pour les iPhone plus anciens**

Sur iOS 18, aucune pièce ne répondait au doigt : ni au tap, ni au glisser, sur
tous les écrans de jeu. L'échiquier s'affichait normalement mais restait
inerte. C'est corrigé, et l'app est désormais vérifiée sur appareil réel en
iOS 18 comme en iOS 26.

**Les 58 cours d'ouverture, tous revus**

Vos adversaires ne jouent pas toujours le coup prévu par la leçon. Nous avons
mesuré, position par position, ce que les joueurs de club jouent réellement, et
comblé les réponses manquantes — en commençant par celles qui arrivent le plus
souvent. **Près de 900 positions ont été ajoutées**, dans les 58 cours.

Un exemple parmi d'autres : tous les répertoires noirs contre 1.d4 supposaient
que les Blancs enchaînent 2.c4. En club, une partie sur six voit 2.Ff4, la
London — et le cours s'arrêtait là. Vous sortiez de votre répertoire au
deuxième coup, avant même que l'ouverture choisie ait pu apparaître. C'est
comblé, tout comme la Philidor et la Petroff face à 1.e4 e5.

Là où l'ouverture ne survit pas au coup de l'adversaire, le cours le dit
franchement plutôt que de faire semblant : sans c4, un gambit Budapest ou Benko
n'est plus un gambit, et mieux vaut l'apprendre dans la leçon que devant
l'échiquier.

Chaque variante ajoutée a été vérifiée par le moteur : aucune ligne n'enseigne
un coup qui perd.

**Des verdicts d'analyse plus sûrs**

Un coup jugé « Imprécision » plutôt que « Erreur » à quelques dixièmes près,
c'est un verdict que vous lisez et retenez. Nous avons mesuré sur des parties
de tournoi réelles la fréquence de ces basculements : environ un coup sur 22
recevait une étiquette qu'une analyse plus profonde aurait contredite.

Désormais, quand un verdict tombe près d'une frontière, ChessLab reprend la
position avec dix fois plus d'effort avant de trancher. Les erreurs
d'étiquetage baissent de 85 %. L'analyse d'une partie demande un peu plus de
temps ; sur un appareil lent ou déjà chaud, ce supplément est abandonné plutôt
que de vous faire attendre.

**Analyser : plus simple**

« Coller un PGN » et « Position FEN » ne font plus qu'une entrée, **Analyser
PGN / FEN** : collez ce que vous avez, le format est reconnu tout seul. Vous
n'avez plus à savoir nommer ce que contient votre presse-papiers.

L'import d'un fichier, qui ne s'ouvrait pas, fonctionne — et accepte aussi bien
un `.pgn` qu'un `.fen`.

**Bibliothèque : doublons et suppression**

Réimporter un fichier n'ajoute plus les parties en double : une partie déjà
présente est reconnue même si elle vient d'un autre site, avec d'autres
en-têtes et d'autres commentaires. Et vous pouvez enfin supprimer une partie
(appui long, avec confirmation).

**Répertoires personnels : l'éditeur**

Vous pouvez maintenant modifier un répertoire importé directement dans l'app :
jouez un coup sur l'échiquier pour l'ajouter, retirez une variante, écrivez
votre propre commentaire.

**Les modes se parlent**

Depuis une partie en cours — contre l'ordinateur ou à deux — le menu d'export
envoie la position affichée directement vers l'analyse ou le Laboratoire, sans
copier-coller. Votre partie vous attend au retour, pendule en pause. Depuis
l'analyse, « Continuer au Laboratoire » fait jouer la position par deux
moteurs ; en fin de série au Laboratoire, un bouton ouvre la dernière partie
dans l'analyse.

Et partout, les sélecteurs disent où vous en êtes : le thème de plateau actif
porte sa coche, le mode d'orientation « Deux joueurs » explique chaque choix
en toutes lettres, et les parties récentes de l'accueil affichent le résultat
aux couleurs de l'échiquier, comme la bibliothèque.

**Moteur mis à jour**

Stockfish 17.1 remplace Stockfish 17. Analyse plus fine, à taille d'app
identique.

---

## English

**An important fix for older iPhones**

On iOS 18, no piece responded to touch — neither tap nor drag, on every playing
screen. The board looked perfectly normal but was inert. This is fixed, and the
app is now verified on real devices running iOS 18 as well as iOS 26.

**All 58 opening courses revised**

Your opponents don't always play the move the lesson expects. We measured,
position by position, what club players actually play, and filled in the
missing replies — starting with the ones that come up most often. **Nearly 900
positions have been added**, across all 58 courses.

One example among many: every Black repertoire against 1.d4 assumed White would
follow with 2.c4. In club play, one game in six sees 2.Bf4, the London — and
the course stopped there. You left your repertoire on move two, before the
opening you chose could even appear. That gap is filled, as are the Philidor
and the Petroff against 1.e4 e5.

Where an opening simply doesn't survive the opponent's move, the course now
says so plainly instead of pretending otherwise: without c4, a Budapest or
Benko Gambit is no longer a gambit, and it is better to learn that in the
lesson than at the board.

Every added line was verified by the engine: no course teaches a losing move.

**More reliable analysis verdicts**

A move called “Inaccuracy” rather than “Mistake” by a few tenths is still a
verdict you read and remember. We measured how often those flips happen on real
tournament games: about one move in 22 carried a label that deeper analysis
would have contradicted.

Now, whenever a verdict lands near a boundary, ChessLab re-examines the
position with ten times the effort before deciding. Mislabelled moves drop by
85%. Analysing a game takes a little longer; on a slow or already-warm device
that extra work is dropped rather than keeping you waiting.

**Analyse: simpler**

“Paste a PGN” and “FEN position” are now a single entry, **Analyse PGN / FEN**:
paste what you have and the format is detected automatically. You no longer
need to know what's in your clipboard.

Importing a file, which didn't open at all, now works — and accepts `.fen` as
readily as `.pgn`.

**Library: duplicates and deletion**

Re-importing a file no longer adds games twice: a game already in your library
is recognised even when it comes from another site, with different headers and
different comments. And you can finally delete a game (long press, with
confirmation).

**Personal repertoires: the editor**

You can now edit an imported repertoire right in the app: play a move on the
board to add it, remove a line, write your own comment.

**The modes talk to each other**

From a game in progress — against the computer or two-player — the export menu
sends the displayed position straight to analysis or the Laboratory, no
copy-paste. Your game is waiting when you come back, clock paused. From
analysis, "Continue in the Laboratory" has two engines play the position out;
when a Laboratory series ends, one tap opens the last game in analysis.

And selectors now tell you where you stand: the active board theme carries its
checkmark, the two-player orientation modes explain each choice in plain
words, and recent games on the home screen show their result in chessboard
colours, matching the library.

**Engine updated**

Stockfish 17.1 replaces Stockfish 17. Sharper analysis, same app size.

---

## Notes internes (ne pas coller dans App Store Connect)

- **Le correctif iOS 18 est la raison d'être de cette version.** Le défaut
  rendait l'app inutilisable pour tout utilisateur en iOS 18 — c'est-à-dire
  tous les iPhone antérieurs au 11 inclus qui n'ont pas migré. Il est passé au
  travers de 330 tests verts parce que tous les runtimes installés sont en
  iOS 26. Voir `PROGRESS.md`, section « Le plateau injouable en iOS 18 ».
- **Le moteur change, donc les évaluations changent.** L'audit complet des 58
  cours a été rejoué sous 17.1 avant publication : aucune gaffe enseignée.
- **L'analyse est environ trois fois plus lente** qu'en 1.4.0 sur les parties
  qui contiennent des verdicts limites (×2,95 mesuré sur 887 coups). C'est le
  prix assumé de l'affinage. Deux garde-fous : la seconde passe est abandonnée
  si l'appareil est en régulation thermique, et plafonnée en temps par
  position. Si des retours signalent une attente excessive, le levier est la
  bande d'affinage (`refinementBand`) : la ramener à ±1 rend le coût à ×1,96 et
  conserve 59 % du bénéfice — la courbe mesurée est dans le code.
- **Argument de vente à ne pas surestimer.** Le ratio arêtes/positions des
  cours reste à 0,99 : ce sont des lignes, pas des arbres touffus. La campagne
  a supprimé les sorties de répertoire au deuxième coup, pas transformé les
  cours en encyclopédies. Le dire ainsi évite une déception au premier
  utilisateur fort.
- **Taille de l'app inchangée** : le réseau NNUE de la 17.1 pèse 71 Mo, comme
  celui de la 17. C'est ce qui a fait préférer la 17.1 à la 18, dont le réseau
  pèse 104 Mo (+33 Mo pour l'utilisateur, et le seuil de téléchargement
  cellulaire d'iOS s'en rapproche dangereusement).
- **Licence** : la GPLv3 de Stockfish impose que le code source publié
  corresponde au binaire soumis. Pousser le dépôt AVANT de soumettre.
