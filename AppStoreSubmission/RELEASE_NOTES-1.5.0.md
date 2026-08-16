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

**Les cours d'ouverture beaucoup plus complets**

Vos adversaires ne jouent pas toujours le coup prévu par la leçon. Nous avons
mesuré, position par position, ce que les joueurs de club jouent réellement, et
comblé les réponses manquantes — en commençant par celles qui arrivent le plus
souvent. Plusieurs cours répondent maintenant à des coups qui apparaissent dans
une partie sur trois et qui n'étaient traités nulle part.

Chaque variante ajoutée a été vérifiée par le moteur : aucune ligne n'enseigne
un coup qui perd.

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

**Moteur mis à jour**

Stockfish 17.1 remplace Stockfish 17. Analyse plus fine, à taille d'app
identique.

---

## English

**An important fix for older iPhones**

On iOS 18, no piece responded to touch — neither tap nor drag, on every playing
screen. The board looked perfectly normal but was inert. This is fixed, and the
app is now verified on real devices running iOS 18 as well as iOS 26.

**Much more complete opening courses**

Your opponents don't always play the move the lesson expects. We measured,
position by position, what club players actually play, and filled in the
missing replies — starting with the ones that come up most often. Several
courses now answer moves that occur in one game out of three and were covered
nowhere.

Every added line was verified by the engine: no course teaches a losing move.

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
  cours a été rejoué sous 17.1 avant publication.
- **Taille de l'app inchangée** : le réseau NNUE de la 17.1 pèse 71 Mo, comme
  celui de la 17. C'est ce qui a fait préférer la 17.1 à la 18, dont le réseau
  pèse 104 Mo (+33 Mo pour l'utilisateur, et le seuil de téléchargement
  cellulaire d'iOS s'en rapproche dangereusement).
- **Licence** : la GPLv3 de Stockfish impose que le code source publié
  corresponde au binaire soumis. Pousser le dépôt AVANT de soumettre.
