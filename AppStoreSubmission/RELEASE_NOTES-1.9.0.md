# Notes de version — ChessLab 1.9.0

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> ⏳ **Pas encore soumise.** Version `1.9.0`, build `15` (la 1.8.1, build 14, est READY_FOR_SALE). Couvre le 30/09 → 13/10/2026. Compilée avec Xcode 27.1 et le SDK iOS 27.1 : c'est ce SDK qui fait passer l'app en plein écran sur l'iPhone Duo, barres d'outils verticales comprises.

> 📸 **Nouveaux visuels** : captures iPhone Duo (écran intérieur en paysage, écran extérieur en portrait) et aperçu vidéo, déposés par l'API « asset library » d'App Store Connect — le format iPhone Duo n'existe pas dans l'ancienne API des jeux de captures. Les captures et aperçus iPhone/iPad de la 1.8 restent valables.

---

## Français

**L'iPhone Duo, fermé et ouvert.** Fermé, l'écran extérieur (466 × 678 pt) reçoit la disposition iPhone ; avec le SDK 27.1 les barres d'outils y passent à la verticale sous la barre d'état, et l'accueil, dont les trois boutons formaient une barre horizontale à part, suit désormais. Ouvert, l'écran intérieur (951 × 669 pt) est de classe régulière dans les deux sens et reçoit la disposition iPad.

**L'échiquier sur l'écran ouvert.** La barre latérale et la barre d'état laissaient une colonne presque carrée, et les plateaux y tombaient à 184-350 pt. Trois règles, toutes fondées sur la place disponible :
- sur un écran d'échiquier, dans une fenêtre plus large que haute et plus étroite que 1 024 pt, la barre latérale se replie ; elle revient en quittant l'échiquier, et un choix de l'utilisateur est respecté ;
- au-delà d'un rapport largeur/hauteur de 1,3, les commandes passent à droite du plateau (variantes, analyses, entraînements, Laboratoire) ;
- contre l'ordinateur, quand c'est la hauteur qui borne le plateau, les plaques des joueurs passent dans la colonne de droite (adversaire en haut, soi en bas).
Résultat sur l'écran ouvert : 527 pt contre l'ordinateur, ~487 en analyse, ~420 à ~510 dans les variantes, ~513 dans les entraînements, ~430 au Laboratoire. Aucun iPad en plein écran barre ouverte n'est touché.

**Les orientations.** Ouvert, le système fait tourner l'app avec l'appareil, et ChessLab passe en disposition iPhone pleine largeur quand l'écran est tenu en hauteur. Fermé, l'app reste en portrait : la règle dépend désormais de la taille de l'écran (petit côté ≥ 600 pt pour tourner), et la question est reposée au système à chaque passage d'un écran à l'autre — sans quoi l'écran extérieur héritait des orientations de l'intérieur.

**Corrigé au passage.** En rouvrant l'appareil sur une partie, le système réécrivait la visibilité de la barre latérale juste après son repli ; c'est annulé. L'entraînement libre des finales ne couvrait que sa colonne : deux bandes noires sur le Duo, et sur iPad en paysage.

## English

**iPhone Duo, closed and open.** Closed, the outer display (466 × 678 pt) gets the iPhone layout; with the 27.1 SDK toolbars stand vertically below the status bar, and the home screen — whose three buttons formed a separate horizontal bar — now follows. Open, the inner display (951 × 669 pt) is regular in both directions and gets the iPad layout.

**The board on the open display.** The sidebar and status bar left a near-square column, and boards fell to 184-350 pt. Three rules, all based on available room: on board screens, in a window wider than tall and narrower than 1,024 pt, the sidebar folds (and comes back when leaving the board, respecting the user's own choice); beyond a 1.3 width/height ratio, controls move to the right of the board; against the computer, when height bounds the board, the player plates move into the right column. Result on the open display: 527 pt against the computer, ~487 in analysis, ~420-510 in variants, ~513 in training, ~430 in the Laboratory. No full-screen iPad with the sidebar open is affected.

**Orientations.** Open, the system rotates the app with the device, and ChessLab takes the full-width iPhone layout when the display is held upright. Closed, the app stays in portrait: the rule now depends on the screen size (short side ≥ 600 pt to rotate), and the question is asked again whenever the app moves between displays.

**Also fixed.** Reopening the device on a game no longer brings the sidebar back over the board. Endgame free training now fills the screen in landscape (no black bands, on iPhone Duo and iPad).
