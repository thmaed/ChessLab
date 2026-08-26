# Notes de version — ChessLab 1.6.0

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> ⏳ **PAS ENCORE SOUMISE.** Couvre tout ce qui a été livré depuis la 1.5.0 (build 7, en ligne depuis le 20/08/2026) : nettoyage du stockage, refonte du lecteur d'Ouvertures, corrections aux Finales, toilettage des barres d'outils, et le module Variantes — porté en une seule nuit (25→26/08) de 4 façons de jouer (Chess960 + 3) à 8 : Roi de la colline, Trois échecs, Horde, Course des rois, Antéchecs, Atomique, et Coup Volé (variante maison). Voir « Notes internes » en bas de fichier avant de soumettre — notamment le numéro de build à fixer délibérément dans le projet.

---

## Français

**Nouveau : le module Variantes, de 4 à 8 façons de jouer en une nuit**

Chess960 (les échecs Fischer Random) rejoint l'app : position de départ tirée au hasard, choisie par numéro (0 à 959), ou composée vous-même en échangeant les pièces de la première rangée. Jouez contre l'ordinateur — force réglable, indice, alerte gaffe, barre d'évaluation — ou à deux sur le même appareil, avec une analyse de fin de partie identique à celle du mode « Jouer » (pastilles de qualité comprises).

Sept variantes de plus s'y ajoutent, toutes présentées dans un même hub en tuiles, chacune avec sa propre analyse de fin de partie et les mêmes aides que Chess960 (indice, alerte gaffe, barre d'évaluation — activée par défaut) :

- **Roi de la colline** — le premier roi au centre du plateau gagne.
- **Trois échecs** — le troisième échec délivré gagne.
- **Horde** — les Blancs n'ont que des pions contre une armée noire au complet.
- **Course des rois** — amenez votre roi sur la 8e rangée avant l'adversaire ; aucun coup ne peut mettre l'adversaire en échec, sauf à gagner sur-le-champ.
- **Antéchecs** — but inversé : perdez toutes vos pièces, ou restez bloqué sans coup possible. Capturer est obligatoire dès que c'est possible.
- **Atomique** — toute capture fait exploser la case d'arrivée et son voisinage (sauf les pions) ; la partie se termine dès qu'un roi explose.
- **Coup Volé** — variante maison, sans équivalent ailleurs : tous les 7 coups (réglable de 4 à 8 dans les options), vous gagnez un jeton, jamais plus d'un en stock. Le dépenser vous fait jouer deux coups d'affilée, sauf si le premier met l'adversaire en échec. Seule variante du hub à tourner sur le moteur Stockfish standard (avec son réseau de neurones), les six autres utilisant Fairy-Stockfish, un second moteur vendorisé pour arbitrer leurs règles propres.

Chaque écran de réglages détaille désormais la règle avant de commencer.

**Ouvertures : un nouveau lecteur**

L'écran d'index devient un arbre des lignes : chaque coup n'apparaît qu'une seule fois, plus besoin de relire douze fois « 1.e4 d5 2.exd5 Dxd5 » avant d'arriver à ce qui distingue vraiment les variantes. Le lecteur affiche, sous un échiquier fixe : une barre d'évaluation, les coups joués par les maîtres avec leurs pourcentages, et les trois meilleurs coups de Stockfish — tout est précalculé, l'app n'attend jamais après un moteur. Des marques (??, ?, ?!, !!) signalent gaffes, erreurs, imprécisions et coups brillants directement dans la ligne.

**Finales : 78 cours, et une recherche**

Un nouveau cours, « Pions électriques » (pions passés voisins qui avancent ensemble), rejoint le catalogue — 78 cours au total. Une leçon qui enseignait une technique inutile sur sa position (le pion passé éloigné) a été corrigée, ainsi qu'une ligne qui s'arrêtait avant le mat promis. Et comme dans Ouvertures, un champ de recherche par nom se cumule désormais avec les filtres de niveau et de famille.

**Les modes se parlent, au même endroit partout**

Le bouton violet « Changer de mode » — qui bascule vers le Laboratoire, l'ordinateur ou une partie à deux en emportant la position affichée — est maintenant identique sur les neuf écrans concernés. Il était auparavant cause dans les écrans de partie, dans un menu annoncé comme « Exporter ».

**Reprendre un coup, plus direct**

Reprendre une partie depuis un coup consulté agit désormais dès le premier appui, avec un bouton « Annuler » qui prend sa place quelques secondes — plus besoin de confirmer avant d'agir.

**Laboratoire : les statistiques s'expliquent, et l'intervalle de confiance mieux calculé**

Touchez n'importe quelle statistique (LOS, écart Elo…) pour savoir précisément ce qu'elle mesure. L'intervalle de confiance à 95 % sur l'écart Elo utilise désormais la correction statistique usuelle (Bessel) plutôt qu'une variance légèrement sous-estimée, et ne peut plus s'effondrer à une largeur nulle après une poignée de parties toutes identiques (ex. deux nulles d'affilée).

**Fiabilité du moteur d'échecs**

Plusieurs correctifs autour du démarrage et de l'arrêt du moteur, en particulier lors des changements rapides d'écran (par exemple : quitter une partie de variante pour ouvrir son analyse) — moins de risque de voir « moteur indisponible » s'afficher à tort. Une revue complète du code a aussi corrigé deux défauts plus rares : reprendre une partie pile au moment où l'ordinateur venait de répondre pouvait désynchroniser l'historique des coups, et toucher le bouton de promotion d'un pion juste après la fin d'une partie (drapeau tombé, mat de l'ordinateur) pouvait rejouer un coup sur une partie déjà terminée.

**Stockage allégé**

Une installation neuve occupe 60 Mo au lieu de 175 : les déchets qui pouvaient s'accumuler d'une version à l'autre (jusqu'à 240 Mo) sont désormais nettoyés automatiquement au démarrage.

**Petites retouches**

Le thème du plateau ne se choisit plus que dans les Réglages — un seul endroit, qui s'applique déjà à tout l'écran de toute façon. La pastille de qualité d'un coup, en analyse, ne se cache plus derrière une flèche. Et l'aide intégrée reflète toutes les nouveautés de cette version.

---

## English

**New: the Variants module, from 4 to 8 ways to play in one night**

Chess960 (Fischer Random Chess) joins the app: a randomly drawn starting position, one chosen by number (0 to 959), or one you compose yourself by swapping pieces on the back rank. Play against the computer — adjustable strength, hints, blunder alerts, an eval bar — or two players on the same device, with a full post-game analysis just like "Play" mode, move-quality badges included.

Seven more variants join it, all in a shared tile-based hub, each with its own post-game analysis and the same aids as Chess960 (hints, blunder alerts, an eval bar — now on by default):

- **King of the Hill** — the first king to reach the centre of the board wins.
- **Three-Check** — the third check delivered wins.
- **Horde** — White has nothing but pawns against a full Black army.
- **Racing Kings** — race your king to the 8th rank before your opponent; no move may check the opponent's king unless it wins outright.
- **Antichess** — the goal is reversed: lose all your pieces, or be left with no legal move. Capturing is mandatory whenever possible.
- **Atomic** — every capture blows up the destination square and its neighbours (pawns excepted); the game ends the instant a king explodes.
- **Stolen Move** — a house variant with no equivalent elsewhere: every 7 moves (adjustable 4-8 in settings), you earn a token, never more than one in stock. Spending it lets you play two moves in a row, unless the first one checks your opponent. The only variant in the hub running on the standard Stockfish engine (with its neural network) — the other six use Fairy-Stockfish, a second vendored engine that referees their own rules.

Every setup screen now spells out the rule before you start.

**Openings: a new reader**

The index screen becomes a tree of lines: every move appears only once, no more reading "1.e4 d5 2.exd5 Qxd5" a dozen times before reaching what actually distinguishes the variations. The reader shows, under a fixed board: an eval bar, the moves masters actually played with their percentages, and Stockfish's top three moves — all precomputed, so the app never makes you wait on an engine. Marks (??, ?, ?!, !!) flag blunders, mistakes, inaccuracies and brilliancies right in the line.

**Endgames: 78 courses, and a search field**

A new course, "Electric Pawns" (neighbouring passed pawns advancing together), joins the catalogue — 78 courses in total. A lesson that taught an unnecessary technique on its own position (the distant passed pawn) has been fixed, along with a line that stopped short of the mate it promised. And just like Openings, a search field now stacks with the level and family filters.

**The modes talk to each other, the same way everywhere**

The purple "Switch mode" button — which jumps to the Laboratory, the computer or a two-player game while carrying the displayed position along — now looks identical across all nine relevant screens. It used to be buried in the playing screens, inside a menu labelled "Export".

**Resuming a move, more direct**

Resuming a game from a reviewed move now acts on the first tap, with an "Undo" button taking its place for a few seconds — no more confirmation needed before it happens.

**Laboratory: stats explain themselves, and a better-calculated confidence interval**

Tap any statistic (LOS, Elo gap…) to see exactly what it measures. The 95% confidence interval on the Elo gap now uses the standard statistical correction (Bessel) instead of a slightly underestimated variance, and can no longer collapse to zero width after a handful of identical games (e.g. two draws in a row).

**Chess engine reliability**

Several fixes around starting and stopping the engine, especially when switching screens quickly (for example: leaving a variant game to open its analysis) — less chance of a spurious "engine unavailable" message. A full code review also fixed two rarer defects: resuming a game right as the computer had just replied could desynchronize the move history, and tapping a pawn-promotion button right after a game ended (flag fall, computer checkmate) could replay a move on an already-finished game.

**Lighter on storage**

A fresh install now takes 60MB instead of 175: leftover debris that could accumulate from version to version (up to 240MB) is now cleaned up automatically on launch.

**Small touches**

The board theme is now chosen only in Settings — one place, since it already applied to the whole app anyway. A move's quality badge, in analysis, no longer hides behind an engine arrow. And the built-in Help reflects everything new in this version.

---

## Notes internes (ne pas coller dans App Store Connect)

- **`CURRENT_PROJECT_VERSION` dérive tout seul** dans `project.pbxproj` (cible ChessLab, Debug et Release) — `8.1` le 25/08, `8.2` observé le 26/08, sans qu'aucune action délibérée n'ait fixé cette valeur (très probablement un incrément à chaque build local). La 1.5.0 avait été soumise en `build 7` (entier). Ne PAS archiver avec la valeur trouvée « par hasard » — la fixer consciemment (`8` suffit) juste avant `Product ▸ Archive`, pas avant.
- **`MARKETING_VERSION` est déjà à `1.6`** dans le projet — probablement fixé lors d'un travail antérieur à cette note ; aucune action nécessaire de ce côté.
- **Portée exacte** : ce texte couvre tout ce qui a été livré entre le build 7 (1.5.0, en ligne le 20/08) et aujourd'hui, soit six jours de travail (20 → 26/08). Le plus gros morceau, de loin, est le module Variantes, construit en DEUX nuits : Chess960 complet + trois variantes Fairy-Stockfish (Roi de la colline, Trois échecs, Horde) le 25/08, puis dans la nuit du 25 au 26/08 trois variantes de plus où Fairy-Stockfish devient l'arbitre de légalité lui-même (Course des rois, Antéchecs, Atomique), une 8e variante maison (Coup Volé), le module d'analyse étendu aux 7 non-Chess960, une revue HIG du module, et une revue complète du code de toute l'app. Voir `PROGRESS.md`, sections du 25/08 et du 26/08, pour le détail technique complet.
- **Deux correctifs critiques survenus PENDANT le développement du module Variantes** (avant toute soumission, donc jamais vus par un utilisateur en ligne) : Chess960 remettait chaque coup à zéro juste après l'avoir joué, et l'ordinateur pouvait rester figé sans jamais répondre. Un troisième, plus subtil, découvert après coup : le second moteur (Fairy-Stockfish) pouvait cesser de répondre en changeant d'écran, à cause d'un partage de ressource (`std::cin`/`std::cout`) entre les deux moteurs de l'app — corrigé au niveau de l'application, et complété la nuit suivante par un second correctif symétrique (le garde ne couvrait que l'AUTRE type de moteur, jamais le sien) et un budget de démarrage doublé après avoir reproduit le symptôme original en suite de tests complète sous charge système.
- **Pas de réseau NNUE pour les six variantes Fairy-Stockfish** — décision produit assumée : chaque variante aurait besoin de son propre réseau (aucun partage possible), pour un poids de 20 à 40 Mo chacun. L'évaluation classique de Fairy-Stockfish suffit à produire un adversaire crédible ; revisitable variante par variante si demandé. Coup Volé fait exception : tournant sur Stockfish STANDARD (aucune option UCI de variante n'existe pour son mécanisme de tour double), elle profite du réseau NNUE déjà embarqué pour le mode « Jouer ».
- **Poids de l'app** : le second moteur (Fairy-Stockfish, sans réseau NNUE) ajoute environ 1,5 Mo à l'exécutable — négligeable à côté du nettoyage de stockage (175 → 60 Mo) qui touche, lui, le conteneur de données et non le poids de téléchargement.
- **Licence** : la GPLv3 de Stockfish ET de Fairy-Stockfish impose que le code source publié corresponde au binaire soumis. Pousser le dépôt AVANT de soumettre — cela vaut maintenant pour DEUX moteurs vendorés (`Vendor/CStockfish` et `Vendor/CFairyStockfish`).
- **Revue complète du code (26/08)** : six agents indépendants, un par sous-système. Deux bugs à confiance haute corrigés partout où ils apparaissaient (`completePromotion()` sans garde sur une partie déjà finie ; l'offre d'annulation d'une reprise qui ne se nettoyait que sur un coup utilisateur, désynchronisant les journaux d'une partie si le moteur répondait entretemps), plus deux correctifs plus mineurs (un pion promu qui se sacrifiait aussitôt ne comptait que pour un pion dans le classement des coups ; un redémarrage moteur raté dans le Laboratoire laissait une série s'épuiser en silence). Une nuance statistique sur l'intervalle de confiance du Laboratoire (Bessel + terme de continuité) a été signalée puis corrigée sur confirmation explicite. Détail complet dans `PROGRESS.md`.
- **Historique des fichiers de notes** : `RELEASE_NOTES-1.4.0.md`, qui documentait un build jamais soumis (voir la note de la 1.5.0 ci-dessus), a été supprimé du dépôt — toute la matière qu'il couvrait est déjà repliée dans le texte de la 1.5.0. Seuls restent désormais `RELEASE_NOTES-1.5.0.md` (en ligne) et ce fichier.
