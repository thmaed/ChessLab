# Notes de version — ChessLab 1.7.0

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> ⏳ **PAS ENCORE SOUMISE.** Couvre ce qui a été livré depuis la 1.6, soumise le 28/08/2026. Deux variantes de plus au hub — Crazyhouse et Duck Chess —, un défaut moteur récurrent des Variantes corrigé, et une passe de mise en page menée écran par écran sur les deux extrêmes du parc : la très grande fenêtre et le très petit iPhone.

---

## Français

**Deux variantes de plus : Crazyhouse et Duck Chess**

Le hub passe à dix façons de jouer.

**Crazyhouse** — toute pièce que vous capturez change de camp et rejoint votre réserve, d'où vous pouvez la reposer sur n'importe quelle case vide, y compris pour donner mat. Une bande sous chaque joueur montre les pièces en main : la vôtre se touche pour choisir, celle d'en face vous prévient de ce qui peut tomber. Un pion ne se pose ni sur la 1re ni sur la 8e rangée, et un pion promu capturé redevient un simple pion. Jouable contre l'ordinateur, à toutes les forces.

**Duck Chess** — un canard 🦆 occupe une case et la bloque totalement : aucune pièce ne peut s'y poser ni la traverser, et il ne se capture pas. Chaque tour se joue en deux temps — vous déplacez une pièce, puis vous posez le canard où vous voulez, en changeant de case à chaque fois. Il n'y a ni échec ni mat : un roi a le droit de rester sous une attaque, et on gagne en le capturant. Jouable **contre l'ordinateur**, avec tout ce qu'offrent les autres variantes : choix de la couleur, force réglable, cadence, barre d'évaluation, indice, alerte gaffe, reprise d'un coup, et une analyse de fin de partie qui rejoue la partie canard compris. L'ordinateur pose son canard là où il gêne le plus — sur la case d'arrivée du coup qu'il vous prête, ou en travers de son chemin.

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

---

## English

**Two more variants: Crazyhouse and Duck Chess**

The hub grows to ten ways to play.

**Crazyhouse** — every piece you capture switches sides and joins your reserve, from which you can drop it back onto any empty square, including to deliver mate. A strip under each player shows the pieces in hand: yours is tappable, your opponent's warns you what may land. A pawn cannot be dropped on the 1st or 8th rank, and a promoted pawn that is captured returns as a plain pawn. Playable against the computer, at every strength.

**Duck Chess** — a duck 🦆 sits on a square and blocks it completely: no piece may land on it or move through it, and it cannot be captured. Every turn has two steps — you move a piece, then you place the duck wherever you like, on a different square each time. There is no check and no checkmate: a king may stay under attack, and you win by capturing it. Playable **against the computer**, with everything the other variants offer: colour choice, adjustable strength, time control, eval bar, hints, blunder alerts, takebacks, and a post-game analysis that replays the game with the duck in place. The computer drops its duck where it hurts most — on the arrival square of the move it expects from you, or across its path.

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

- **Version et build** — `MARKETING_VERSION` passe à `1.7.0`. Le numéro de build reste à fixer DÉLIBÉRÉMENT juste avant `Product ▸ Archive` : il doit être strictement supérieur à celui effectivement soumis pour la 1.6, que ce dépôt ne connaît pas (il porte `8.4`, mais rien ne garantit que ce soit la valeur partie). Vérifier dans App Store Connect avant d'archiver.

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

- **Le piège de localisation, en détail.** `Text("…")` et les autres vues SwiftUI localisent un `LocalizedStringKey` ; elles ne localisent PAS un `String`. Un littéral français typé `String` échappe donc à la fois à la traduction ET à l'extraction automatique du catalogue : rien ne le signale, l'app démarre, l'écran s'affiche. Deux formes du défaut coexistaient. La première : un composant dont le paramètre était typé `String` (`EngineUnavailableBanner.message`, neuf appelants ; `TextImportSheet.title`/`placeholder`/`confirmLabel`) — corrigée en typant le paramètre `LocalizedStringKey`, ce qui met la contrainte dans le type. La seconde : un texte composé à l'exécution, qui doit passer par `LocalizationController.string(_:)` — corrigée site par site (validateur FEN, scanner, éditeur de position, alerte gaffe, import PGN/FEN, répertoire), avec les clés ajoutées à la main au catalogue, `string(_:)` n'étant pas extrait automatiquement. Deux contrôles nouveaux dans `LocalizedStringHygieneTests` : toute chaîne française livrée doit avoir sa version anglaise, et un échantillon par famille de textes composés à l'exécution doit être réellement traduit.

- **À surveiller.** Le Duck Chess **à deux sur le même appareil** n'est plus atteignable depuis le hub : l'écran de réglages est désormais celui, commun, des autres variantes, qui ne propose pas ce choix. Le modèle et la vue le gèrent toujours (`DuckChessViewModel(versusEngine: false)`, seul montage sous lequel les tests peuvent jouer les deux camps) — à rebrancher si on le veut, par une option sur l'écran de réglages partagé. `OpeningBadge` (dans `OpeningCoverage.swift`) n'a plus aucun appelant : ses libellés restent donc hors catalogue, volontairement — à supprimer plutôt qu'à traduire. L'accroche longue des variantes (`tagline`) n'a plus aucun lecteur depuis que les tuiles utilisent la forme courte : à supprimer ou à réemployer. Et `OpeningsModuleUITests/testTheModuleSurvivesTheLargestTextSize` échoue sur iPhone SE — en AX5 la liste paresseuse n'instancie jamais `opening_scandinavian` ; défaut du test, vérifié préexistant par bissection, jamais lancé sur cet appareil auparavant.

- **Historique des fichiers de notes** — `RELEASE_NOTES-1.5.0.md` et `RELEASE_NOTES-1.6.0.md` ont été supprimés du dépôt une fois leurs versions soumises, comme l'avait été `RELEASE_NOTES-1.4.0.md` avant eux. L'historique résumé des versions vit dans `METADATA.md`, et le détail complet reste dans l'historique Git.
