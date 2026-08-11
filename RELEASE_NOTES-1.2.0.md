# ChessLab 1.2 — notes de version / release notes

> Regroupe toutes les nouveautés depuis la 1.0.1, versions intermédiaires
> 1.0.2 et 1.1.0 incluses.

---

## Nouveautés (français)

### Ouvertures — module entièrement repensé
- **Un lecteur simple et guidé.** Choisissez une ouverture, puis avancez coup
  par coup : chaque coup est expliqué, et les autres coups jouables à cette
  position sont proposés. Fini l'ancien explorateur touffu.
- **58 ouvertures rédigées à la main**, bilingues (français / anglais), des
  grandes lignes vérifiées : toutes les grandes ouvertures (Espagnole,
  Italienne, siciliennes Najdorf/Dragon/Sveshnikov/Taïmanov…, Française,
  Caro-Kann, est-indienne, Nimzo-indienne, Grünfeld, gambit dame…) et de
  nombreux systèmes et gambits.
- **Des flèches colorées** sur l'échiquier, reliées à la liste des coups :
  vert = le coup recommandé, bleus = les autres coups, rouge = un piège,
  orange = une imprécision.
- **Entraînement simplifié.** La répétition espacée fonctionne toute seule :
  vous retrouvez le coup, puis cliquez « Continuer » — l'app planifie vos
  révisions à votre place, sans réglages compliqués.
- **Liste triée par ordre alphabétique**, noms d'ouvertures en français, et
  progression **synchronisée via iCloud** (si la synchro est activée).

### iPad & Mac
- **Interface repensée** : barre latérale persistante (modes + suivi) avec zone
  de détail, au lieu d'une mise en page iPhone agrandie. L'iPhone garde sa
  grille de tuiles.
- **Échiquier bord à bord** en « Contre l'ordinateur » (pleine hauteur en
  paysage, pleine largeur en portrait). Deux joueurs et Puzzles s'adaptent
  aussi au grand écran.
- **Pointeur & trackpad** : la case sous le curseur est mise en évidence.
- **Menus Mac** : un raccourci clavier pour chaque mode.

### Synchronisation iCloud (optionnelle)
- Activez-la dans les Réglages : vos **parties**, votre **progression de
  puzzles** et vos **ouvertures** suivent vos appareils, via votre iCloud
  privé. Aucun compte, aucun serveur ChessLab. Désactivée par défaut — l'app
  marche entièrement hors ligne.

### Analyse, Puzzles, Progrès
- **Analyse — suivez la meilleure ligne coup par coup** : un bouton rejoue la
  meilleure suite de Stockfish, un demi-coup à la fois.
- **Progrès** — un tableau de bord depuis l'accueil : votre bilan face à
  l'ordinateur et vos statistiques de puzzles, avec un set ciblé en un tap sur
  chaque thème à travailler.
- **Scanner** — indicateur de traitement, calcul hors du fil principal, et
  reconnaissance des pièces nettement plus fiable.

### Confort
- **« Contre l'ordinateur »** : l'adversaire est appelé « l'ordinateur » plutôt
  que « Stockfish » (toujours crédité dans l'Aide et les Licences).
- **Thèmes d'échiquier et de pièces** : quatre plateaux, trois jeux de pièces,
  aperçu en direct dans les Réglages.
- **Aide → « Contacter le développeur »** pour envoyer un retour ou signaler un
  bug par e-mail.

### Corrections & sous le capot
- Correction d'un plantage possible en quittant l'écran d'Analyse ; cycle de
  vie du moteur entièrement fiabilisé.
- **Moteur Stockfish recompilé depuis les sources** avec optimisations ARM
  (NEON) et piloté hors du fil principal : analyse plus rapide, plus aucune
  saccade pendant que le moteur réfléchit. Force et réglages adaptés à chaque
  appareil.
- Analyse d'après-partie servie depuis le cache (le moteur ne recalcule plus à
  chaque coup revu).

---

## What's new (English)

### Openings — completely rebuilt
- **A simple, guided reader.** Pick an opening, then step through it move by
  move: every move is explained, and the other playable moves at each position
  are offered. The cluttered old explorer is gone.
- **58 hand-written openings**, bilingual (French / English), with verified
  main lines: all the major openings (Ruy Lopez, Italian, Sicilian
  Najdorf/Dragon/Sveshnikov/Taimanov…, French, Caro-Kann, King's Indian,
  Nimzo-Indian, Grünfeld, Queen's Gambit…) plus many systems and gambits.
- **Colored arrows** on the board, linked to the move list: green = the
  recommended move, blues = the other moves, red = a trap, orange = an
  inaccuracy.
- **Simplified training.** Spaced repetition runs itself: recall the move, then
  tap "Continue" — the app schedules your reviews for you, no fiddly settings.
- **Alphabetically sorted list**, French opening names, and progress **synced
  via iCloud** (when sync is on).

### iPad & Mac
- **Redesigned interface**: a persistent sidebar (modes + tracking) with a
  detail area, instead of a scaled-up phone layout. iPhone keeps its tile grid.
- **Edge-to-edge board** in "Play vs the computer" (full height in landscape,
  full width in portrait). Two Players and Puzzles adapt to the large screen too.
- **Pointer & trackpad**: the square under the cursor is highlighted.
- **Mac menus**: a keyboard shortcut for every mode.

### iCloud sync (optional)
- Turn it on in Settings: your **games**, **puzzle progress** and **openings**
  follow you across devices, via your private iCloud. No account, no ChessLab
  server. Off by default — the app works fully offline.

### Analyze, Puzzles, Progress
- **Analyze — follow the best line move by move**: a button walks Stockfish's
  best continuation one half-move at a time.
- **Progress** — a home-screen dashboard: your record against the computer and
  your puzzle stats, with a targeted set one tap away for each weak theme.
- **Scanner** — a processing indicator, off-main-thread work, and much more
  reliable piece recognition.

### Comfort
- **"Play vs the computer"**: the opponent is now called "the computer" rather
  than "Stockfish" (still credited in Help and Licenses).
- **Board & piece themes**: four boards, three piece sets, with a live preview
  in Settings.
- **Help → "Contact the developer"** to send feedback or report a bug by email.

### Fixes & under the hood
- Fixed a possible crash when leaving the Analysis screen; the engine lifecycle
  is fully hardened.
- **Stockfish recompiled from source** with ARM (NEON) optimizations and driven
  off the main thread: faster analysis and no more stutter while the engine
  thinks. Strength and settings tuned per device.
- Post-game analysis served from cache (the engine no longer recomputes on each
  reviewed move).
