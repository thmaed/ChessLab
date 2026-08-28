# Notes de version — ChessLab 1.7.0

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> ⏳ **PAS ENCORE SOUMISE.** Couvre ce qui a été livré depuis la 1.6, soumise le 28/08/2026. Une version de finition, sans nouveau module : un défaut moteur récurrent des Variantes, et une passe de mise en page menée écran par écran sur les deux extrêmes du parc — la très grande fenêtre et le très petit iPhone.

---

## Français

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

**Petites retouches**

Un grain très léger a été ajouté au fond : il supprime les bandes que les grands dégradés sombres laissent voir sur les écrans larges. Le tableau de bord de l'iPad reçoit un damier fantôme, très pâle, coupé par le bord — le même parti pris décoratif que les tuiles de l'accueil. Et la feuille d'import de répertoire, dont le titre se tronquait entre ses deux boutons sur un petit écran, en porte un plus court.

---

## English

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

**Small touches**

A very light grain has been added to the background: it removes the banding that large dark gradients show on wide screens. The iPad dashboard gets a ghost chessboard, very pale, cut off by the edge — the same decorative device as the home tiles. And the repertoire import sheet, whose title was truncated between its two buttons on a small screen, now carries a shorter one.

---

## Notes internes (ne pas coller dans App Store Connect)

- **Version et build** — `MARKETING_VERSION` passe à `1.7.0`. Le numéro de build reste à fixer DÉLIBÉRÉMENT juste avant `Product ▸ Archive` : il doit être strictement supérieur à celui effectivement soumis pour la 1.6, que ce dépôt ne connaît pas (il porte `8.4`, mais rien ne garantit que ce soit la valeur partie). Vérifier dans App Store Connect avant d'archiver.

- **Origine du lot : une revue Mac Catalyst.** L'essentiel de cette version vient d'une revue de l'app compilée pour Mac et pilotée en fenêtre réelle sur onze gabarits, du minimum autorisé au plein écran 27 pouces. Le Mac n'est PAS proposé sur la fiche App Store (décision inchangée, voir `CHECKLIST.md`) — mais la fenêtre Mac redimensionnable est le meilleur banc d'essai qui soit pour les mises en page en classe *regular*, celles-là mêmes que servent l'iPad plein écran, le Split View et le Stage Manager. Tout ce qui a été corrigé là bénéficie donc à l'iPad, qui est bien sur la fiche.

- **Le défaut moteur, en détail.** `FairyStockfishEngine.stop()` termine son `AsyncStream` de lignes, et un `AsyncStream` terminé l'est définitivement. Le view model survit à la navigation (`SessionStore` le conserve exprès), donc son `FairyEngineController` et son instance de moteur aussi : au retour, `startReader()` itérait un flux mort, aucun `uciok` ne remontait, et le démarrage expirait sur `isEngineUnavailable` — alors que le process, lui, tournait et gardait `isProcessBusy`. `EngineController` documentait déjà ce piège dans `restart()` (« Nouvelle instance : le flux de lignes précédent est clos ») et `PlayViewModel` crée de toute façon un contrôleur neuf à chaque partie, d'où l'immunité du mode classique. Correctif dans `FairyEngineController.start()`. Le test `engineRestartsAfterLeavingAndComingBack` reproduit le scénario et échouait avant.

- **Un détecteur de plus.** `LayoutProbe` ne savait mesurer que les débordements de LARGEUR — c'est pourquoi la troncature du plateau des variantes n'a été trouvée qu'à l'œil. Il mesure désormais aussi la coupe verticale, de façon ciblée (un balayage général crierait au loup sur chaque `ScrollView`). Les tests qui s'appuient dessus disent franchement ce qu'ils ne prouvent pas : ils n'ont pas été vus échouer sur le code fautif, aucune géométrie de simulateur ne reproduisant la fenêtre Mac de 820 × 680, et les trois tentatives sont consignées dans leur en-tête.

- **Outil de revue.** `SmallPhoneTourUITests` dépose les captures de quinze écrans dans `/tmp/cl-small-phone/` — un outil à lancer à la demande, pas un test de non-régression, comme les captures App Store.

- **À surveiller.** L'accroche longue des variantes (`tagline`) n'a plus aucun lecteur depuis que les tuiles utilisent la forme courte : à supprimer ou à réemployer. Et `OpeningsModuleUITests/testTheModuleSurvivesTheLargestTextSize` échoue sur iPhone SE — en AX5 la liste paresseuse n'instancie jamais `opening_scandinavian` ; défaut du test, vérifié préexistant par bissection, jamais lancé sur cet appareil auparavant.

- **Historique des fichiers de notes** — `RELEASE_NOTES-1.5.0.md` et `RELEASE_NOTES-1.6.0.md` ont été supprimés du dépôt une fois leurs versions soumises, comme l'avait été `RELEASE_NOTES-1.4.0.md` avant eux. L'historique résumé des versions vit dans `METADATA.md`, et le détail complet reste dans l'historique Git.
