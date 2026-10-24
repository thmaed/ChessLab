# Volet C — Audit de l'interface (24/10/2026)

Premier temps de la revue demandée : *moderniser les menus, les rendre plus
attractifs et colorés*. Ce document décrit l'existant et propose ; **rien n'est
modifié** avant validation. Captures de référence : accueil, Nouvelle partie,
Puzzles, Ouvertures, Finales, Analyser, Laboratoire, Variantes, Deux joueurs,
Bibliothèque (iPhone 17 Pro, simulateur) ; Android : accueil, Puzzles, fin de
partie, Woodpecker (Galaxy A16).

## 1. Ce qui marche déjà — à conserver

- **Un langage cohérent** : fond sombre vert-nuit, cartes arrondies, une teinte
  PAR MODE (vert Ordinateur, bleu Deux joueurs, violet Puzzles, ambre
  Ouvertures, orange Finales, teal Analyser, rose Laboratoire, indigo
  Variantes). Les icônes sont dans des pastilles dégradées.
- **Les écrans à facettes** (Puzzles) : une teinte par groupe de puces
  (violet / rose / vert / bleu / ambre), icônes dans les puces. C'est le plus
  réussi.
- **La galerie des personnages** : portraits colorés, seule vraie touche de
  « personnalité » de l'app.
- **Le hub des variantes** : tuiles colorées, une couleur par jeu.
- Les couleurs qui portent un SENS (vert de la revue, gris de l'analyse en
  direct, rouge de la menace) : ne pas y toucher.

## 2. Ce qui est terne, daté ou incohérent

| # | Constat | Où |
|---|---|---|
| 1 | **Les tuiles de l'accueil sont presque toutes grises** : seule la petite icône est colorée, le reste de la carte est un gris sombre quasi identique. La couleur de mode existe mais n'envahit pas la carte. | Accueil |
| 2 | **Deux styles de titre cohabitent** : titre inline centré (« Puzzles », « Analyser », « Laboratoire », « Variantes ») et grand titre à gauche (« Ouvertures », « Finales »). | tous les écrans |
| 3 | **Les en-têtes de section sont colorés ici, ternes là** : Nouvelle partie, Laboratoire et Deux joueurs ont des icônes teintées devant « COULEUR », « MOTEURS »… ; Puzzles a les mêmes groupes mais sans icône. | Puzzles, Analyser |
| 4 | **L'action principale n'a pas une forme unique** : pastille « Commencer » en haut à droite (Nouvelle partie, Deux joueurs), « Lancer » (Laboratoire), grand bouton dégradé en bas (Puzzles). | Nouvelle partie / Puzzles |
| 5 | **Les écrans de liste sont très denses et monochromes** : Ouvertures et Finales sont des murs de texte gris, sans visuel (pas de vignette de plateau, pas de pastille de niveau colorée). | Ouvertures, Finales |
| 6 | **« Analyser » est très vide** : deux cartes et un grand blanc ; la Bibliothèque vide est grisée. | Analyser |
| 7 | **L'écran de fin de partie et le bilan Woodpecker sont sobres** : bonne lisibilité, peu de célébration (les confettis existent mais pas de récapitulatif visuel : courbe, médaille). | fin de partie |
| 8 | **L'accueil ne dit rien de vous** : aucune donnée personnelle (à revoir aujourd'hui, série, dernière précision), alors que tout est là pour le faire. | Accueil |
| 9 | **Le thème est sombre uniquement** (à confirmer) : pas d'alternative claire. | global |

## 3. Propositions, classées par rapport effet / coût

### Rapide et très visible
- **C1 — Tuiles d'accueil teintées.** Dégradé de la couleur du mode sur toute
  la carte (10 à 20 % d'opacité, plus marqué en haut), icône agrandie, filigrane
  déjà présent conservé. *Effet immédiat, coût : un composant.*
- **C2 — Un seul style de titre** (grand titre à gauche qui se réduit au
  défilement, standard iOS). *Coût faible, gain de cohérence.*
- **C3 — En-têtes de section avec icône teintée partout** (reprendre le gabarit
  de Nouvelle partie dans Puzzles, Analyser, Ouvertures…). *Coût : un
  composant de plus, adopté partout.*

### Moyen
- **C4 — L'action principale toujours au même endroit et sous la même forme** :
  un bouton plein dégradé collé en bas, teinté du mode, pour « Commencer »,
  « Lancer », « Jouer ». Les pastilles du haut disparaissent. *Touche beaucoup
  d'écrans et leurs tests d'interface (identifiants à conserver).*
- **C5 — Ouvertures et Finales vivantes** : vignette de plateau (la position
  clé du cours), pastille de niveau colorée (Débutant → Avancé, mêmes teintes
  que les puzzles), barre de progression de maîtrise sur chaque carte. *Données
  déjà disponibles.*
- **C6 — « Analyser » repensé** : cartes plus grandes avec visuel, dernière
  partie analysée en tête, accès direct « Mats manqués ».

### Gros, à lier à la 2.0
- **C7 — L'accueil personnalisé** : en tête, une carte **« Séance du jour »**
  (A5) avec le nombre de choses à revoir et la série ; sous les modes, un
  bandeau de progression (précision récente, cote de puzzle). *C'est la
  rencontre du volet C avec le volet A : la boucle devient visible.*
- **C8 — Célébrations et bilans** : fin de partie avec récapitulatif visuel
  (précision, courbe d'évaluation miniature, coups clés) ; médailles pour les
  séries ; cycle Woodpecker avec comparaison graphique.
- **C9 — Un thème clair** (et suivi du réglage système) : gros chantier — les
  couleurs sont des constantes sombres (`Theme.swift`) ; à n'entreprendre que
  si vous le voulez vraiment.

## 4. Ce que je recommande

Un premier lot **C1 + C2 + C3**, livrable vite et visible sur l'accueil
dès la première seconde. Puis **C7** avec A5 (la « Séance du jour » donne enfin
une raison à un accueil plus riche), puis **C5** et **C8**. **C4** et **C9**
après arbitrage : ils changent des habitudes et ont un coût de tests.

## 5. Garde-fous

- iOS fait foi ; Android suit dans le même lot (même teintes, mêmes
  libellés — c'est déjà le cas pour l'accueil).
- Contrastes WCAG AA au minimum sur les nouveaux fonds teintés ; Dynamic Type
  et cibles de 44 pt conservés ; réduire les animations respecté.
- Les identifiants d'accessibilité des 21 suites d'interface ne bougent pas.
- Maquettes à valider avant de coder (étape 2 de la méthode), pas de refonte
  « à l'aveugle ».

## 6. Décisions à prendre

1. Premier lot **C1 + C2 + C3** : on lance ?
2. Le **thème clair** (C9) est-il souhaité, ou l'identité sombre est-elle un
   choix assumé ?
3. **C4** : un bouton d'action unique en bas de chaque écran de réglage, ou
   garder les pastilles du haut ?
