# Notes de version — ChessLab 1.7.1

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> ⏳ **PAS ENCORE SOUMISE.** Couvre tout ce qui a été livré depuis la 1.6 (soumise le 28/08/2026) : la 1.7.0 jamais partie — quatre variantes de plus, nulle partout, mise en page — PLUS la 1.7.1 du 05/09 : visite guidée bilingue, coups en ligne colorés dans toutes les analyses de variantes, accueil iPad/Mac, stabilité moteur en profondeur. Build : 10.1.

---

## Français

**Quatre variantes de plus : Crazyhouse, Duck Chess et les deux Barricades**

Le hub passe à douze façons de jouer.

**Crazyhouse** — toute pièce que vous capturez change de camp et rejoint votre réserve, d'où vous pouvez la reposer sur n'importe quelle case vide, y compris pour donner mat. Une bande sous chaque joueur montre les pièces en main : la vôtre se touche pour choisir, celle d'en face vous prévient de ce qui peut tomber. Un pion ne se pose ni sur la 1re ni sur la 8e rangée, et un pion promu capturé redevient un simple pion. Jouable contre l'ordinateur, à toutes les forces.

**Duck Chess** — un canard 🦆 occupe une case et la bloque totalement : aucune pièce ne peut s'y poser ni la traverser, et il ne se capture pas. Chaque tour se joue en deux temps — vous déplacez une pièce, puis vous posez le canard où vous voulez, en changeant de case à chaque fois. Il n'y a ni échec ni mat : un roi a le droit de rester sous une attaque, et on gagne en le capturant. Jouable **contre l'ordinateur**, avec tout ce qu'offrent les autres variantes : choix de la couleur, force réglable, cadence, barre d'évaluation, indice, alerte gaffe, reprise d'un coup, et une analyse de fin de partie qui rejoue la partie canard compris. L'ordinateur pose son canard là où il gêne le plus — sur la case d'arrivée du coup qu'il vous prête, ou en travers de son chemin.

**Barricades** — les règles des échecs, à un détail près : les cases d4 et e5 sont murées dès le départ. Aucune pièce ne peut s'y poser ni les traverser, et un mur ne se capture pas — il ne bougera pas de la partie. Tours, fous et dames butent donc dessus comme sur une pièce, tandis que les cavaliers leur sautent par-dessus sans pouvoir s'y arrêter. Tout le reste — échec, mat, pat, roque, prise en passant, promotion — est inchangé. Deux cases en moins au centre, et l'ouverture n'est déjà plus la même : d2-d4 n'existe pas.

**Barricades aléatoires** — les mêmes murs, mais qui ne tiennent pas en place : après chaque coup ils sautent sur deux cases vides tirées au hasard entre la 2e et la 7e rangée. Un fou qui tenait une diagonale la perd au coup suivant, une tour cloue puis ne cloue plus. Calculer loin n'y sert pas à grand-chose, et c'est tout l'intérêt.

**Proposer nulle, partout**

Le bouton « ½ » existait dans les écrans de variantes sans rien faire. Il fonctionne maintenant dans les douze modes, avec la même règle qu'en mode « Contre l'ordinateur » : l'ordinateur accepte s'il ne se voit pas mieux qu'une quasi-égalité sur son dernier coup, refuse sinon, et vous le dit. À deux sur le même appareil, la nulle est actée d'un tap.

**Les nulles par manque de matériel sont déclarées**

Roi et fou contre roi seul ne mène nulle part : la partie s'arrête sur une nulle au lieu de tourner à vide. La règle ne s'applique qu'aux variantes où l'on gagne EN MATANT — Barricades, Crazyhouse (réserves vides), Coup Volé, Chess960. Elle est volontairement écartée là où un fou seul gagne encore : l'Atomique fait exploser un roi sans le mater, le Duck Chess le capture, la Course des rois et le Roi de la colline se gagnent en arrivant quelque part, et Trois échecs en donnant trois échecs.

**Une courbe d'évaluation dans toutes les analyses**

L'analyse de fin de partie du mode « Contre l'ordinateur » montrait où la partie avait basculé ; celles des variantes, non. Elles l'ont maintenant toutes — Chess960, les huit variantes, Duck Chess : la courbe s'affiche au-dessus de la liste des coups, se remplit au fil du classement, épingle les moments critiques, et un appui saute au coup correspondant.

**« Moteur indisponible » au retour d'une analyse : la vraie fin**

Le cas restant du bandeau : finir une partie de variante, l'analyser, revenir en arrière — et le moteur se déclarait indisponible. Deux défauts superposés. D'abord une contradiction de gardes : au retour sur une partie finie, l'écran refusait de redémarrer le moteur tout en l'interrogeant quand même. Ensuite, plus profond : le flux par lequel remontent les réponses du moteur mourait définitivement au premier délai dépassé — chaque écran vivait ensuite avec des évaluations et des indices muets, sans le moindre message. Chaque lecture a désormais son propre flux, et le scénario complet — mat, analyse, retour, consultation avec barre d'évaluation — est rejoué par des tests.

**Le moteur des Variantes ne décroche plus**

Le message « le moteur n'a pas pu être démarré » revenait régulièrement dans le mode Variantes — typiquement après la fin d'une partie suivie de son analyse, ou après être revenu en arrière pour relancer. Il ne se produisait jamais dans le mode « Jouer » classique.

La cause : en quittant un écran de variante, le canal par lequel l'app lit les réponses du moteur était refermé **définitivement**. L'écran, lui, est conservé pour qu'on le retrouve tel qu'on l'a laissé — et avec lui ce canal mort. Au retour, l'app parlait à un moteur qui avait pourtant parfaitement démarré, sans jamais entendre sa réponse, et concluait au bout de cinq secondes à une panne. Pire : le moteur restait vivant en arrière-plan, occupant la place pour l'écran suivant, ce qui expliquait que le défaut revienne par grappes plutôt qu'isolément.

Le mode « Jouer » y échappait parce qu'il repart d'un canal neuf à chaque partie. Les quatre écrans concernés — partie, variantes arbitrées, Coup Volé, analyse — font désormais pareil.

**Les écrans de variantes tiennent dans toutes les fenêtres**

Sur un iPad en paysage, en Split View ou en Stage Manager, le plateau des variantes réservait 62 % de la hauteur sans compter les bandeaux joueurs, la barre de contrôle et la bande des coups empilés autour. Dans une fenêtre courte, le total débordait : la première rangée du plateau passait sous le bandeau du bas et la barre de contrôle disparaissait — au moment précis où il fallait l'atteindre pour abandonner ou lancer l'analyse. Le plateau mesure maintenant la place réellement disponible et cède ce qu'il faut. Bénéfice au passage : aux grandes tailles de texte, il se réduit tout seul.

Dans une fenêtre large, ces mêmes écrans étiraient bandeaux et commandes d'un bord à l'autre, le retour au coup précédent d'un côté et l'abandon à l'autre. Ils restent désormais à la largeur du plateau.

**iPad : des colonnes à la bonne largeur**

La barre latérale prenait plus de place qu'il ne lui en fallait en portrait — près de 80 points de vide à droite du plus long libellé, autant de pris sur la colonne de contenu, la plus serrée dans cette orientation. Elle est resserrée.

L'Aide, les Réglages et la Progression étiraient leurs paragraphes sur toute la largeur disponible : sur un grand écran, la ligne devenait trop longue pour que l'œil retrouve la suivante. Ils adoptent une mesure de lecture. Le hub des Variantes fait de même, au lieu d'aligner ses huit tuiles sur une seule rangée écrasée. Dans le lecteur d'Ouvertures, l'échiquier et le panneau de droite partent maintenant du même bord haut. Et dans les Puzzles, le plateau ne touche plus le bas de l'écran, tandis que la colonne latérale respire au lieu d'être figée.

**Petits iPhone : des libellés entiers, un écran plus léger**

Sur un iPhone SE, cinq tuiles de variantes sur huit coupaient leur description en plein mot, et trois tuiles de l'accueil faisaient de même. Chaque variante porte désormais une accroche courte, taillée pour la largeur réelle d'une tuile.

L'en-tête de l'accueil mangeait plus de la moitié de la hauteur avant la première tuile : sur les écrans les plus courts il se resserre, et trois rangées apparaissent au lieu de deux et demie. Les iPhone plus grands ne changent pas.

Dans les réglages de partie, la grille des niveaux passe à une seule colonne quand l'écran est étroit — « Intermédiaire confirmé » s'y coupait en plein mot avant de se faire tronquer.

**Flèches d'indice à l'échelle du plateau**

La flèche du meilleur coup se dessinait dans une taille fixe, réglée pour un plateau moyen : elle écrasait la position sur un petit iPhone et devenait un trait de crayon sur un grand écran. Elle se mesure maintenant en fraction de case, et garde la même allure partout.

**L'app en anglais l'est vraiment**

Une cinquantaine de textes restaient en français dans l'app en anglais : les messages du validateur de position (FEN), ceux du scanner d'échiquier et du cadrage, l'aide de l'éditeur de position, l'alerte « coup risqué », la feuille d'import PGN/FEN, les erreurs du répertoire d'ouvertures et la bannière « Moteur indisponible ». Tous traduits.

La cause était la même partout : ces textes-là ne sont pas écrits directement dans un écran, ils se composent au moment où ils s'affichent — et rien, à la compilation, ne signalait qu'ils n'étaient jamais passés par le catalogue de traductions. Un contrôle automatique les surveille maintenant : il refuse toute chaîne livrée sans sa version anglaise.

**Petites retouches**

Un grain très léger a été ajouté au fond : il supprime les bandes que les grands dégradés sombres laissent voir sur les écrans larges. Le tableau de bord de l'iPad reçoit un damier fantôme, très pâle, coupé par le bord — le même parti pris décoratif que les tuiles de l'accueil. Et la feuille d'import de répertoire, dont le titre se tronquait entre ses deux boutons sur un petit écran, en porte un plus court.

**Et depuis, la 1.7.1**

**Une visite guidée** — au premier lancement (et depuis l'Aide, à volonté), onze étapes en trois courtes sections présentent l'essentiel : un voile sombre percé d'un trou sur le vrai contrôle, une flèche qui pointe dedans, une carte qui explique. Le trou glisse d'une cible à la suivante, la barre de progression dit où l'on est, « Passer » est toujours là — et tout existe en anglais selon la langue du système.

**Les coups en ligne dans toutes les analyses de variantes** — comme en mode « Contre l'ordinateur » : une capsule par coup, chaque coup remarquable entouré de la couleur de sa catégorie d'évaluation, et la bande comme la courbe se touchent pour naviguer dans la partie.

**L'accueil iPad et Mac habité** — la grille des huit modes remplit le panneau de détail, au lieu d'un logo posé dans une fenêtre vide.

**Stabilité du moteur des variantes, en profondeur** — six mécanismes de défaillance distincts traqués jusqu'à leur cause et corrigés, dont le « moteur indisponible » au retour d'un écran ; une suite de torture (bascule rapide des douze variantes, rafales d'annulations, relais entre moteurs) les verrouille pour de bon.

**L'Aide à jour d'elle-même** — le titre des nouveautés lit la version de l'app, le module Variantes décrit les douze tuiles réelles.


---

## English

**Four more variants: Crazyhouse, Duck Chess and both Barricades**

The hub grows to twelve ways to play.

**Crazyhouse** — every piece you capture switches sides and joins your reserve, from which you can drop it back onto any empty square, including to deliver mate. A strip under each player shows the pieces in hand: yours is tappable, your opponent's warns you what may land. A pawn cannot be dropped on the 1st or 8th rank, and a promoted pawn that is captured returns as a plain pawn. Playable against the computer, at every strength.

**Duck Chess** — a duck 🦆 sits on a square and blocks it completely: no piece may land on it or move through it, and it cannot be captured. Every turn has two steps — you move a piece, then you place the duck wherever you like, on a different square each time. There is no check and no checkmate: a king may stay under attack, and you win by capturing it. Playable **against the computer**, with everything the other variants offer: colour choice, adjustable strength, time control, eval bar, hints, blunder alerts, takebacks, and a post-game analysis that replays the game with the duck in place. The computer drops its duck where it hurts most — on the arrival square of the move it expects from you, or across its path.

**Barricades** — the rules of chess, with one twist: d4 and e5 are walled off from the start. No piece may land on them or move through them, and a wall cannot be captured — it will not move for the whole game. Rooks, bishops and queens therefore stop against a wall as they would against a piece, while knights leap over one without being able to stop on it. Everything else — check, checkmate, stalemate, castling, en passant, promotion — is unchanged. Two squares fewer in the centre, and the opening is already a different game: d2-d4 does not exist.

**Shifting Barricades** — the same walls, except they will not stay put: after every move they jump to two empty squares drawn at random between the 2nd and 7th ranks. A bishop that held a diagonal loses it next move, a rook pins and then does not. Calculating far ahead is worth very little here, and that is rather the point.

**Offering a draw, everywhere**

The "½" button was present on the variant screens and did nothing. It now works in all twelve modes, with the same rule as "Play the computer": the computer accepts if it does not see itself better than near-equality on its last move, declines otherwise, and tells you so. With two players on one device, a draw is agreed with a single tap.

**Draws by insufficient material are declared**

King and bishop against a bare king leads nowhere: the game now ends in a draw instead of running on. The rule applies only to variants that are won BY CHECKMATE — Barricades, Crazyhouse (empty hands), Stolen Move, Chess960. It is deliberately left out where a lone bishop can still win: Atomic blows a king up without mating it, Duck Chess captures it, Racing Kings and King of the Hill are won by arriving somewhere, and Three-Check by giving three checks.

**An evaluation curve in every analysis**

The post-game analysis in "Play the computer" showed where a game turned; the variants' did not. They all have it now — Chess960, the eight variants, Duck Chess: the curve sits above the move list, fills in as the classification runs, pins the critical moments, and a tap jumps to the matching move.

**"Engine unavailable" after returning from an analysis: the real ending**

The remaining case of the banner: finish a variant game, analyse it, go back — and the engine declared itself unavailable. Two defects stacked. First a contradiction between guards: returning to a finished game, the screen refused to restart the engine yet queried it anyway. Then, deeper: the stream that carries the engine's replies died permanently on the first missed deadline — every screen then lived with silent evaluations and hints, with no message at all. Every read now gets its own stream, and the full scenario — mate, analysis, return, review with the eval bar — is replayed by tests.

**The Variants engine no longer drops out**

The message "the engine could not be started" kept coming back in Variants mode — typically after a game ended and its analysis was opened, or after going back to start again. It never happened in the regular "Play" mode.

The cause: on leaving a variant screen, the channel the app uses to read the engine's replies was closed **for good**. The screen itself is kept so you find it as you left it — and with it that dead channel. On returning, the app was talking to an engine that had in fact started perfectly, never hearing its answer, and after five seconds concluded it had failed. Worse, the engine stayed alive in the background, holding the slot for the next screen, which is why the fault came in clusters rather than alone.

"Play" mode escaped it because it starts from a fresh channel for every game. The four screens concerned — game, refereed variants, Stolen Move, analysis — now do the same.

**Variant screens fit every window**

On an iPad in landscape, in Split View or Stage Manager, the variant board claimed 62% of the height without counting the player bars, the control bar and the move strip stacked around it. In a short window the total overflowed: the board's first rank slipped under the bottom bar and the control bar disappeared — exactly when you needed it to resign or open the analysis. The board now measures the space actually available and gives up what it must. A side benefit: at large text sizes it shrinks by itself.

In a wide window, those same screens stretched bars and controls from edge to edge, with "previous move" at one end and "resign" at the other. They now stay the width of the board.

**iPad: columns at the right width**

The sidebar took more room than it needed in portrait — nearly 80 points of emptiness to the right of the longest label, all of it taken from the content column, the tighter of the two in that orientation. It has been narrowed.

Help, Settings and Progress stretched their paragraphs across the full width: on a large screen the line grew too long for the eye to find the next one. They now keep a readable measure. The Variants hub does the same, instead of lining its eight tiles up in one cramped row. In the Openings reader, the board and the right-hand panel now start from the same top edge. And in Puzzles, the board no longer touches the bottom of the screen, while the side column breathes instead of being frozen at one width.

**Small iPhones: whole labels, a lighter screen**

On an iPhone SE, five variant tiles out of eight cut their description mid-word, and three home tiles did the same. Every variant now carries a short tagline, cut to the real width of a tile.

The home header ate more than half the height before the first tile: on the shortest screens it tightens up, and three rows appear instead of two and a half. Larger iPhones are unchanged.

In the game setup, the level grid drops to a single column when the screen is narrow — "Intermédiaire confirmé" used to break mid-word there and then get truncated.

**Hint arrows scale with the board**

The best-move arrow was drawn at a fixed size, tuned for a mid-sized board: it overwhelmed the position on a small iPhone and became a pencil stroke on a large screen. It is now measured as a fraction of a square, and keeps the same look everywhere.

**The English app really is in English**

About fifty texts were still showing in French in the English app: the position (FEN) validator messages, the board scanner and cropping guidance, the position editor's hint line, the "risky move" alert, the PGN/FEN import sheet, the opening repertoire errors and the "Engine unavailable" banner. All translated.

The cause was the same everywhere: those texts are not written straight into a screen, they are composed at the moment they appear — and nothing at compile time flagged that they had never gone through the translation catalogue. An automatic check now watches them: it rejects any shipped string that has no English counterpart.

**Small touches**

A very light grain has been added to the background: it removes the banding that large dark gradients show on wide screens. The iPad dashboard gets a ghost chessboard, very pale, cut off by the edge — the same decorative device as the home tiles. And the repertoire import sheet, whose title was truncated between its two buttons on a small screen, now carries a shorter one.

---

## Notes internes (ne pas coller dans App Store Connect)

- **Version et build — FIXÉS le 30/08.** `MARKETING_VERSION = 1.7.0`,
  `CURRENT_PROJECT_VERSION = 10` aux deux configurations de la cible
  applicative. Un ENTIER, délibérément : la valeur dérivait de décimale en
  décimale (`8.1` → `8.2` → `8.4` → `9.0`) et repartait à chaque fois d'un
  chiffre trouvé par hasard. `10` est strictement supérieur à tout ce que ce
  dépôt a porté, donc à tout ce qui a pu être soumis pour la 1.6.

  **La dérive vient de l'IDE, pas de la ligne de commande.** Vérifié le
  30/08 : une dizaine de `xcodebuild build`/`test` d'affilée laissent la
  valeur intacte ; le passage de `8.4` à `9.0`, lui, s'est glissé dans un
  commit pendant que le projet était ouvert dans Xcode. À surveiller au
  `git diff` avant chaque archive — c'est là qu'elle bouge.

  Reste à confirmer dans App Store Connect que le dernier build de la 1.6
  était bien inférieur à 10 (le dépôt ne le sait pas).

- **Origine du lot : une revue Mac Catalyst.** L'essentiel de cette version vient d'une revue de l'app compilée pour Mac et pilotée en fenêtre réelle sur onze gabarits, du minimum autorisé au plein écran 27 pouces. Le Mac n'est PAS proposé sur la fiche App Store (décision inchangée, voir `CHECKLIST.md`) — mais la fenêtre Mac redimensionnable est le meilleur banc d'essai qui soit pour les mises en page en classe *regular*, celles-là mêmes que servent l'iPad plein écran, le Split View et le Stage Manager. Tout ce qui a été corrigé là bénéficie donc à l'iPad, qui est bien sur la fiche.

- **Le défaut moteur, en détail.** `FairyStockfishEngine.stop()` termine son `AsyncStream` de lignes, et un `AsyncStream` terminé l'est définitivement. Le view model survit à la navigation (`SessionStore` le conserve exprès), donc son `FairyEngineController` et son instance de moteur aussi : au retour, `startReader()` itérait un flux mort, aucun `uciok` ne remontait, et le démarrage expirait sur `isEngineUnavailable` — alors que le process, lui, tournait et gardait `isProcessBusy`. `EngineController` documentait déjà ce piège dans `restart()` (« Nouvelle instance : le flux de lignes précédent est clos ») et `PlayViewModel` crée de toute façon un contrôleur neuf à chaque partie, d'où l'immunité du mode classique. Correctif dans `FairyEngineController.start()`. Le test `engineRestartsAfterLeavingAndComingBack` reproduit le scénario et échouait avant.

- **Un détecteur de plus.** `LayoutProbe` ne savait mesurer que les débordements de LARGEUR — c'est pourquoi la troncature du plateau des variantes n'a été trouvée qu'à l'œil. Il mesure désormais aussi la coupe verticale, de façon ciblée (un balayage général crierait au loup sur chaque `ScrollView`). Les tests qui s'appuient dessus disent franchement ce qu'ils ne prouvent pas : ils n'ont pas été vus échouer sur le code fautif, aucune géométrie de simulateur ne reproduisant la fenêtre Mac de 820 × 680, et les trois tentatives sont consignées dans leur en-tête.

- **Duck Chess : un arbitre en Swift, un joueur en Stockfish.** C'est la seule variante du hub dont la légalité ne vient pas d'un moteur. Fairy-Stockfish l'ignore et n'a aucun mécanisme de case bloquée (`variants.ini` n'a pas de `wallingRule`) ; surtout, un coup y est DEUX actions, ce que le protocole UCI ne sait pas exprimer et dont le nombre de combinaisons (coups légaux × cases vides) rendrait la recherche absurde. Les coups légaux de ChessKit ne conviennent pas davantage, et pour une raison qui EST la variante : ils sont filtrés sur l'échec, notion absente ici. D'où `DuckChessRules`, avec son propre générateur, et `DuckChessFEN` qui compose le plateau résultant à la main — ChessKit refuserait d'appliquer ces coups. Le canard ne figure pas dans la FEN produite : il n'est pas une pièce, ce qui garde la FEN ordinaire et tout l'affichage réutilisable.

- **Duck Chess : l'adversaire, sans écrire de moteur.** Arbitrer la variante et y jouer sont deux problèmes différents. Stockfish standard reste un excellent joueur d'échecs : il suffit de ne jamais le laisser choisir hors des coups que le canard autorise, ce que fait `searchmoves` (ajouté à `UCIProtocol`, en PREMIER dans la commande `go` comme l'exige la spécification). `DuckChessEngine` lui interdit trois situations où il répondrait n'importe quoi : le roi adverse prenable (position illégale aux échecs — on joue la prise sans le consulter), une position que `DuckChessRules.isStandardLegal(_:)` juge illégale de son point de vue (un roi qui reste sous une attaque est normal ici, interdit là-bas — et le canard, absent de la FEN, ne peut pas parer une attaque à ses yeux), et une liste de coups qu'il tient tous pour illégaux (`bestmove (none)`, repli sur une heuristique locale). Pour le canard, on lui demande le meilleur coup de l'ADVERSAIRE — sur la position au trait retourné, ce détail-là étant le bug principal de la première version — et on bloque sa case d'arrivée, sinon son trajet. Il ignore le canard dans son évaluation : c'est le compromis, énoncé au joueur dans la règle affichée à l'écran de réglages.

- **Duck Chess : l'analyse a son propre écran.** `VariantAnalysisViewModel` n'était pas réutilisable : il interroge Fairy-Stockfish avec un identifiant de variante, que le Duck Chess n'a pas. `DuckChessAnalysisViewModel` s'adosse au même `DuckChessEngine` et juge le TOUR ENTIER (coup + canard) — la seule unité qui ait un sens ici. Rien n'est écrit dans `AnalysisEvalStore` : sa clé est faite des coups joués, or deux parties de Duck Chess peuvent partager la même liste de coups avec des canards différents, donc des évaluations différentes.

- **Duck Chess : cinq journaux, pas un rejeu.** La reprise d'un coup ne rejoue pas la partie depuis le départ : ni la position du canard ni la case de prise en passant ne se redéduisent des coups. La vue-modèle tient donc `sanLog`/`uciLog`/`moveLog`/`fenLog`/`duckLog`/`enPassantLog` alignés sur un même index, et reculer revient à relire une ligne. La notation porte le canard (`e4@e5`), en partie comme à l'export PGN.

- **`ClockLabel` n'existe plus qu'une fois.** Elle vivait en cinq copies `private` rigoureusement identiques (Fairy, Légalité, Coup Volé, Chess960, Chess960 à deux) ; le Duck Chess en réclamait une sixième. Extraite dans `VariantClockLabel.swift`, les cinq copies supprimées.

- **Crazyhouse, à l'inverse**, n'a presque rien coûté côté règles : Fairy-Stockfish la joue nativement, donc les cases de pose légales sont filtrées parmi les coups qu'il énumère, jamais calculées ici. Deux trous de plomberie ont dû être bouchés, tous deux silencieux : le filtre de coups rejetait les poses (`P@e4`, majuscule en tête, là où il exigeait une minuscule), et rien ne lisait la réserve pourtant écrite dans la FEN.

- **Outil de revue.** `SmallPhoneTourUITests` dépose les captures de quinze écrans dans `/tmp/cl-small-phone/` — un outil à lancer à la demande, pas un test de non-régression, comme les captures App Store.

- **Barricades : une case-mur, sur un moteur qui n'en a pas.** Le Fairy-Stockfish vendorisé est la version 14 : son parseur de FEN n'a aucun cas pour `*`, `position.h` n'a aucune notion de case bloquée, et la liste des options de `parser.cpp` ne contient ni `wallingRule` ni équivalent. Le mur est donc FABRIQUÉ avec ce que ce build offre : le type de pièce `immobile` (notation Betza vide, donc aucun coup) posé sur d4 et e5 pour bloquer les lignes, `mobilityRegionBlack<Pièce>` pour interdire ces deux cases aux six types de pièces noires — les Blancs n'y peuvent rien poser non plus, ce sont leurs propres pièces — et `pieceValueMg`/`pieceValueEg` à zéro pour que les murs ne pèsent rien dans l'évaluation. Le blocage des glissantes ne vient PAS de `mobilityRegion`, qui n'est qu'un masque d'arrivée appliqué après le calcul des attaques (`position.h`, `board_bb(c, pt)`), mais de l'occupation : un mur est une pièce, donc il arrête une ligne, et un cavalier lui saute par-dessus. La définition est ENGENDRÉE par l'app (`BarricadesConfiguration`) à partir d'une seule ligne, `wallSquares`, puis chargée par l'option UCI `VariantPath` avant `UCI_Variant` — l'ordre inverse laisserait le moteur refuser un nom qu'il ne connaît pas encore, sans rien dire. `BarricadesEngineSpikeTests` valide chacun de ces points contre le moteur RÉEL, et a été écrite avant la moindre ligne d'interface.

- **Le faux échec de la suite complète, enfin expliqué.** Un test de variante échouait au hasard en suite COMPLÈTE — jamais en isolation — sur « moteur indisponible », depuis des semaines. Ce n'était pas le moteur : `FairyEngineController.captureRawLines` abandonnait au bout de 4 s, et ces 4 s ne mesurent PAS le calcul du moteur (`d` et `go perft 1` répondent en millisecondes) mais le temps que ses lignes mettent à remonter, chemin qui passe par le MainActor. Sous la charge d'une suite complète, il le dépassait ; `queryPosition` rendait `nil`, et l'appelant en concluait à une panne. Budget porté à 15 s, un second essai avant de conclure, et `EngineIntegrationGate` ne relâche plus son verrou en silence quand les moteurs ne se libèrent pas — il le SIGNALE sur le test fautif, au lieu de laisser échouer le suivant. La suite complète passe désormais en entier (898 tests).

- **Barricades aléatoires : trois murs, dont un fixe.** Le mur fixe est tiré à la création de la partie et gardé par la vue-modèle : rien dans la FEN ne distingue un mur fixe d'un mur mobile. Les deux autres se redéploient à chaque demi-coup.

- **Barricades aléatoires : deux mécanismes que la variante fixe n'avait pas.** D'abord, la position ne se REJOUE plus depuis le départ : le tirage des murs ne figure dans aucun coup, donc `startFEN + uciLog` ne le reproduirait pas. `EngineLegalityPlayViewModel` enchaîne désormais de position en position (`chainFEN`/`chainMoves`) — sans réécriture, ces deux variables valent exactement `startFEN` et `uciLog`, si bien que les cinq autres variantes de la famille ne changent pas d'un iota. Ensuite, `mobilityRegion` est figé par variante et ne peut pas suivre des murs mobiles : les prises de mur sont retirées de la liste que le moteur produit, et cette même liste lui est réimposée en `searchmoves` pour qu'il n'échafaude pas de plan autour. Tout le reste de la légalité — échec, clouage, roque, prise en passant — reste la sienne, et reste juste : un mur EST une pièce sur son échiquier. Garde-fou : si un tirage laisse le camp au trait sans aucun coup, on retire les murs au sort jusqu'à cinq fois, pour que deux murs mal tombés ne matent pas quelqu'un que personne n'a attaqué — un VRAI mat, lui, résiste à tous les tirages.

- **Le mat de Barricades qui ne se voyait pas.** Signalé par l'utilisateur : un mat subi ne terminait pas la partie. La variante avait été ajoutée au catalogue sans toucher au `switch` de fin de partie, où seuls Atomique et Crazyhouse étaient nommés pour le mat classique — tout le reste tombait sur `return nil`. Le cas classique est devenu le DÉFAUT et les fins de partie particulières sont les exceptions nommées : une variante ajoutée sans y penser hérite maintenant des règles des échecs au lieu de n'en avoir aucune. Un test paramétré vérifie que chaque variante du catalogue conclut sur une position sans coup légal.

- **Ce que la sonde a démenti.** L'hypothèse de départ était que la lettre du mur corromprait la rangée côté ChessKit, comme le fait la réserve du Crazyhouse. Faux, et mesuré : ChessKit 0.17.0 avance d'une case sur un caractère inconnu au MILIEU d'une rangée, si bien que `3pW1n1` se relit correctement `3p2n1`. La corruption du Crazyhouse venait d'ailleurs — sa réserve arrive APRÈS la 8e colonne, `Square.File` plafonne, et les caractères en trop s'empilent sur h1. `BarricadesFEN` existe quand même, pour ne pas dépendre d'une tolérance que rien ne promet, et `VariantFEN` compose les deux nettoyages pour qu'aucun écran n'ait à savoir laquelle des deux variantes enrichit sa FEN. Au passage : l'écran d'ANALYSE, lui, ne filtrait rien — une partie de Crazyhouse s'y relisait donc avec sa dernière rangée abîmée depuis le début. Corrigé.

- **Le piège de localisation, en détail.** `Text("…")` et les autres vues SwiftUI localisent un `LocalizedStringKey` ; elles ne localisent PAS un `String`. Un littéral français typé `String` échappe donc à la fois à la traduction ET à l'extraction automatique du catalogue : rien ne le signale, l'app démarre, l'écran s'affiche. Deux formes du défaut coexistaient. La première : un composant dont le paramètre était typé `String` (`EngineUnavailableBanner.message`, neuf appelants ; `TextImportSheet.title`/`placeholder`/`confirmLabel`) — corrigée en typant le paramètre `LocalizedStringKey`, ce qui met la contrainte dans le type. La seconde : un texte composé à l'exécution, qui doit passer par `LocalizationController.string(_:)` — corrigée site par site (validateur FEN, scanner, éditeur de position, alerte gaffe, import PGN/FEN, répertoire), avec les clés ajoutées à la main au catalogue, `string(_:)` n'étant pas extrait automatiquement. Deux contrôles nouveaux dans `LocalizedStringHygieneTests` : toute chaîne française livrée doit avoir sa version anglaise, et un échantillon par famille de textes composés à l'exécution doit être réellement traduit.

- **Ménage du 29/08.** Le Duck Chess **à deux sur le même appareil** est rebranché : l'écran de réglages partagé porte un interrupteur « Deux joueurs », affiché seulement pour les variantes qui le déclarent (`PlayableVariant.supportsTwoPlayers`), et qui masque alors les réglages sans objet — couleur, force, aides. Le bouton « ½ » ne s'affiche plus là où il ne faisait rien : `PlayControlBar.onOfferDraw` est devenu optionnel, `nil` le masque, et sept écrans le passent ainsi. `OpeningBadge` garde son calcul (dérivé, testé) mais perd ses libellés et ses icônes, qu'aucun écran n'affichait — c'est pourquoi ils traînaient en français hors du catalogue. L'accroche longue des variantes (`tagline`) n'a plus aucun lecteur depuis que les tuiles utilisent la forme courte : à supprimer ou à réemployer. Et `OpeningsModuleUITests/testTheModuleSurvivesTheLargestTextSize` passe désormais sur iPhone SE : le test ne rangeait pas le clavier après avoir tapé sa recherche, et en AX5 le clavier plus le texte géant ne laissent rien d'autre à l'écran — le résultat filtré était là, dessous. Diagnostiqué en faisant dire à l'échec quels boutons il voyait : quatre touches de clavier.

- **Historique des fichiers de notes** — `RELEASE_NOTES-1.5.0.md` et `RELEASE_NOTES-1.6.0.md` ont été supprimés du dépôt une fois leurs versions soumises, comme l'avait été `RELEASE_NOTES-1.4.0.md` avant eux. L'historique résumé des versions vit dans `METADATA.md`, et le détail complet reste dans l'historique Git.

**And since then, 1.7.1**

**A guided tour** — on first launch (and from Help, anytime), eleven steps in three short sections present the essentials: a dark veil with a hole punched over the real control, an arrow pointing into it, a card that explains. The hole glides from one target to the next, the progress bar tells you where you are, "Skip" is always there — and everything exists in English, following the system language.

**Inline moves in every variant analysis** — just like the "Against the computer" mode: one capsule per move, each notable move outlined with the color of its evaluation category, and both the strip and the curve can be tapped to navigate the game.

**A lived-in iPad and Mac home** — the grid of eight modes fills the detail pane, instead of a logo floating in an empty window.

**Deep stability work on the variants engine** — six distinct failure mechanisms traced to their root cause and fixed, including "engine unavailable" when returning to a screen; a torture suite (rapid switching across all twelve variants, cancellation storms, engine handoffs) locks them down for good.

**Help that keeps itself current** — the what's-new title reads the app version, and the Variants module describes the actual twelve tiles.

