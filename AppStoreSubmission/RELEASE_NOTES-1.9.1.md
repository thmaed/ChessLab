# Notes de version — ChessLab 1.9.1

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> Version `1.9.1`, build `16` (la 1.9.0, build 15, est READY_FOR_SALE). Version de correction, née d'un signalement de joueur le 22/10/2026. Rien du contenu n'a changé : les captures et aperçus de la 1.9.0 restent valables.

---

## Le signalement

« Ma dame en h1 est soudainement impossible à sélectionner », partie aux Noirs contre Maia, PGN joint. Le défaut survivait à la relance de l'app, au redémarrage du téléphone et au collage des coups dans l'éditeur. Le joueur était en iOS 18.7.10, et l'a reproduit ensuite avec une tour en h1.

## La cause

Les règles n'y étaient pour rien : dans la position finale, ChessKit donne bien onze coups à la dame, et le plateau sélectionnait la pièce normalement sur nos simulateurs iOS 26.

Depuis le correctif d'août (« plateau injouable en iOS 18 »), chaque pièce était placée par `.offset` : DESSINÉE sur sa case, mais MISE EN PAGE à l'origine du plateau — le coin haut gauche, a8, ou h1 plateau retourné. Les cadres des dix-sept pièces s'y empilaient, et en iOS 18 un toucher sur cette case était avalé : rien ne se sélectionnait, ni au tap ni au glisser. Partout ailleurs le plateau répondait, d'où un défaut qui n'apparaît que le jour où l'on veut jouer DEPUIS ce coin. En iOS 26, le système ne laisse plus la zone vide d'une vue capter le toucher : le défaut y est invisible.

Reproduit sur un iPhone XS en iOS 18.7.9 avec la partie exacte du joueur : rouge avant correction, vert après.

## La correction

- **Échiquier** : les pièces sont rangées dans une grille 8×8 calquée sur celle des cases ; chacune est mise en page DANS sa case. Plus rien ne s'empile nulle part, quelle que soit la version d'iOS.
- **Scanner** : les quatre poignées du recadrage manuel avaient la même construction. Elles ne portent plus de geste : l'image entière en porte un, qui saisit le coin le plus proche du doigt dans un rayon de 48 points — exactement le principe du recadrage Android, qui n'a jamais eu ce défaut.

## Les tests

- `OriginSquareSelectionUITests` rejoue la partie du joueur (route DEBUG `-openRoute blackQueenOnOrigin`) : dame h1 → h4 au tap-tap. Il ne prouve quelque chose que sur un appareil iOS 18.
- `CropHandleDragUITests` traîne les quatre poignées ; `CropHandleGrabTests` vérifie le choix du coin le plus proche.
- Android : `OriginSquareTapTest` vérifie sur la même partie qu'un toucher au coin haut gauche du plateau retourné arrive sur h1 — vert sur le Galaxy A16. Le plateau Compose reçoit tous les touchers à un seul endroit : rien à porter.

---

## English

A player reported that their queen on h1 "suddenly could not be selected", playing Black against Maia on iOS 18.7.10. Since August's iOS 18 fix, pieces were placed with `.offset`: drawn on their square but laid out at the board's origin — the top-left corner, a8, or h1 with the board flipped. All seventeen frames stacked there, and on iOS 18 a touch on that square was swallowed. Pieces are now laid out in an 8×8 grid, each inside its own square. The Scanner's crop handles had the same construction; the whole image now carries one gesture that picks the closest corner, as on Android. Reproduced and verified on an iPhone XS running iOS 18.7.9.
