# Notes de version — ChessLab 1.6.0

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> ⏳ **PAS ENCORE SOUMISE.** Couvre tout ce qui a été livré depuis la 1.5.0 (build 7, en ligne depuis le 20/08/2026) : nettoyage du stockage, refonte du lecteur d'Ouvertures, corrections aux Finales, toilettage des barres d'outils, et le nouveau module Variantes (Chess960 + trois variantes Fairy-Stockfish). Voir « Notes internes » en bas de fichier avant de soumettre — notamment le numéro de build à vérifier dans le projet.

---

## Français

**Nouveau : le module Variantes**

Chess960 (les échecs Fischer Random) rejoint l'app : position de départ tirée au hasard, choisie par numéro (0 à 959), ou composée vous-même en échangeant les pièces de la première rangée. Jouez contre l'ordinateur — force réglable, indice, alerte gaffe, barre d'évaluation — ou à deux sur le même appareil, avec une analyse de fin de partie identique à celle du mode « Jouer » (pastilles de qualité comprises).

Trois nouvelles variantes s'y ajoutent, présentées dans un même hub en tuiles : **Roi de la colline** (le premier roi au centre du plateau gagne), **Trois échecs** (le troisième échec délivré gagne) et **Horde** (les Blancs n'ont que des pions contre une armée noire au complet). Chacune se joue contre l'ordinateur avec les mêmes aides que Chess960, et son écran de réglages détaille désormais la règle avant de commencer.

**Ouvertures : un nouveau lecteur**

L'écran d'index devient un arbre des lignes : chaque coup n'apparaît qu'une seule fois, plus besoin de relire douze fois « 1.e4 d5 2.exd5 Dxd5 » avant d'arriver à ce qui distingue vraiment les variantes. Le lecteur affiche, sous un échiquier fixe : une barre d'évaluation, les coups joués par les maîtres avec leurs pourcentages, et les trois meilleurs coups de Stockfish — tout est précalculé, l'app n'attend jamais après un moteur. Des marques (??, ?, ?!, !!) signalent gaffes, erreurs, imprécisions et coups brillants directement dans la ligne.

**Finales : 78 cours, et une recherche**

Un nouveau cours, « Pions électriques » (pions passés voisins qui avancent ensemble), rejoint le catalogue — 78 cours au total. Une leçon qui enseignait une technique inutile sur sa position (le pion passé éloigné) a été corrigée, ainsi qu'une ligne qui s'arrêtait avant le mat promis. Et comme dans Ouvertures, un champ de recherche par nom se cumule désormais avec les filtres de niveau et de famille.

**Les modes se parlent, au même endroit partout**

Le bouton violet « Changer de mode » — qui bascule vers le Laboratoire, l'ordinateur ou une partie à deux en emportant la position affichée — est maintenant identique sur les neuf écrans concernés. Il était auparavant cause dans les écrans de partie, dans un menu annoncé comme « Exporter ».

**Reprendre un coup, plus direct**

Reprendre une partie depuis un coup consulté agit désormais dès le premier appui, avec un bouton « Annuler » qui prend sa place quelques secondes — plus besoin de confirmer avant d'agir.

**Laboratoire : les statistiques s'expliquent**

Touchez n'importe quelle statistique (LOS, écart Elo…) pour savoir précisément ce qu'elle mesure.

**Stockage allégé**

Une installation neuve occupe 60 Mo au lieu de 175 : les déchets qui pouvaient s'accumuler d'une version à l'autre (jusqu'à 240 Mo) sont désormais nettoyés automatiquement au démarrage.

**Petites retouches**

Le thème du plateau ne se choisit plus que dans les Réglages — un seul endroit, qui s'applique déjà à tout l'écran de toute façon. La pastille de qualité d'un coup, en analyse, ne se cache plus derrière une flèche. Et l'aide intégrée reflète toutes les nouveautés de cette version.

---

## English

**New: the Variants module**

Chess960 (Fischer Random Chess) joins the app: a randomly drawn starting position, one chosen by number (0 to 959), or one you compose yourself by swapping pieces on the back rank. Play against the computer — adjustable strength, hints, blunder alerts, an eval bar — or two players on the same device, with a full post-game analysis just like "Play" mode, move-quality badges included.

Three new variants join it in a shared tile-based hub: **King of the Hill** (the first king to reach the centre wins), **Three-Check** (the third check delivered wins) and **Horde** (White has nothing but pawns against a full Black army). Each plays against the computer with the same aids as Chess960, and its setup screen now spells out the rule before you start.

**Openings: a new reader**

The index screen becomes a tree of lines: every move appears only once, no more reading "1.e4 d5 2.exd5 Qxd5" a dozen times before reaching what actually distinguishes the variations. The reader shows, under a fixed board: an eval bar, the moves masters actually played with their percentages, and Stockfish's top three moves — all precomputed, so the app never makes you wait on an engine. Marks (??, ?, ?!, !!) flag blunders, mistakes, inaccuracies and brilliancies right in the line.

**Endgames: 78 courses, and a search field**

A new course, "Electric Pawns" (neighbouring passed pawns advancing together), joins the catalogue — 78 courses in total. A lesson that taught an unnecessary technique on its own position (the distant passed pawn) has been fixed, along with a line that stopped short of the mate it promised. And just like Openings, a search field now stacks with the level and family filters.

**The modes talk to each other, the same way everywhere**

The purple "Switch mode" button — which jumps to the Laboratory, the computer or a two-player game while carrying the displayed position along — now looks identical across all nine relevant screens. It used to be buried in the playing screens, inside a menu labelled "Export".

**Resuming a move, more direct**

Resuming a game from a reviewed move now acts on the first tap, with an "Undo" button taking its place for a few seconds — no more confirmation needed before it happens.

**Laboratory: stats explain themselves**

Tap any statistic (LOS, Elo gap…) to see exactly what it measures.

**Lighter on storage**

A fresh install now takes 60MB instead of 175: leftover debris that could accumulate from version to version (up to 240MB) is now cleaned up automatically on launch.

**Small touches**

The board theme is now chosen only in Settings — one place, since it already applied to the whole app anyway. A move's quality badge, in analysis, no longer hides behind an engine arrow. And the built-in Help reflects everything new in this version.

---

## Notes internes (ne pas coller dans App Store Connect)

- **`CURRENT_PROJECT_VERSION` vaut actuellement `8.1`** dans `project.pbxproj` (cible ChessLab, Debug et Release) — un nombre à virgule, alors que la 1.5.0 avait été soumise en `build 7` (entier). À vérifier/corriger avant de soumettre : App Store Connect exige un entier, ou une liste d'entiers séparés par des points, strictement croissant par rapport au build précédent en ligne (7).
- **`MARKETING_VERSION` est déjà à `1.6`** dans le projet — probablement fixé lors d'un travail antérieur à cette note ; aucune action nécessaire de ce côté.
- **Portée exacte** : ce texte couvre tout ce qui a été livré entre le build 7 (1.5.0, en ligne le 20/08) et aujourd'hui, soit cinq jours de travail (20 → 25/08). Le plus gros morceau, de loin, est le module Variantes (livré le 25/08) : Chess960 complet (règles, hub, jeu, indice, alerte gaffe, analyse) puis trois variantes de plus via un second moteur d'échecs (Fairy-Stockfish) vendorisé dans l'app. Voir `PROGRESS.md`, sections du 25/08, pour le détail technique complet.
- **Deux correctifs critiques survenus PENDANT le développement du module Variantes** (avant toute soumission, donc jamais vus par un utilisateur en ligne) : Chess960 remettait chaque coup à zéro juste après l'avoir joué, et l'ordinateur pouvait rester figé sans jamais répondre. Un troisième, plus subtil, découvert après coup : le second moteur (Fairy-Stockfish) pouvait cesser de répondre en changeant d'écran, à cause d'un partage de ressource (`std::cin`/`std::cout`) entre les deux moteurs de l'app — corrigé au niveau de l'application. Aucun de ces trois défauts n'a jamais été en ligne.
- **Pas de réseau NNUE pour les trois nouvelles variantes** — décision produit assumée : chaque variante aurait besoin de son propre réseau (aucun partage possible), pour un poids de 20 à 40 Mo chacun. L'évaluation classique de Fairy-Stockfish suffit à produire un adversaire crédible ; revisitable variante par variante si demandé.
- **Poids de l'app** : le second moteur (Fairy-Stockfish, sans réseau NNUE) ajoute environ 1,5 Mo à l'exécutable — négligeable à côté du nettoyage de stockage (175 → 60 Mo) qui touche, lui, le conteneur de données et non le poids de téléchargement.
- **Licence** : la GPLv3 de Stockfish ET de Fairy-Stockfish impose que le code source publié corresponde au binaire soumis. Pousser le dépôt AVANT de soumettre — cela vaut maintenant pour DEUX moteurs vendorés (`Vendor/CStockfish` et `Vendor/CFairyStockfish`).
- **Historique des fichiers de notes** : `RELEASE_NOTES-1.4.0.md`, qui documentait un build jamais soumis (voir la note de la 1.5.0 ci-dessus), a été supprimé du dépôt — toute la matière qu'il couvrait est déjà repliée dans le texte de la 1.5.0. Seuls restent désormais `RELEASE_NOTES-1.5.0.md` (en ligne) et ce fichier.
