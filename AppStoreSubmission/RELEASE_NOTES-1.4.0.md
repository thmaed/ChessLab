# ChessLab 1.4.0 (build 6) — JAMAIS SOUMISE, document historique

> **Cette version n'a jamais été envoyée à Apple.** Son contenu est replié
> dans la 1.5.0 (`RELEASE_NOTES-1.5.0.md`, section « Nouveautés » de
> `METADATA.md`). Ce fichier est conservé tel quel comme trace du découpage
> d'origine.

Notes de version détaillées — pour le dépôt, pas pour App Store Connect. Le
texte destiné aux utilisateurs est la section « Nouveautés de cette version »
de `METADATA.md`.

> **Ces notes couvrent 1.2 → 1.4.** La 1.3 a été préparée (bump de version,
> texte de nouveautés) mais **jamais soumise** : le dernier build envoyé à Apple
> est le build 3 de la 1.2, commit `a211763`. Tout ce qui suit est donc
> nouveau pour un utilisateur qui a la 1.2 installée.

## Nouveautés

### Répertoires d'ouvertures personnels — import et partage

La demande d'un testeur classé : « que les utilisateurs puissent écrire leur
base d'ouvertures dans l'app… et se la partager ».

- **Import PGN, variantes comprises.** Les parenthèses d'un PGN de répertoire
  deviennent de vraies alternatives jouables, pas une ligne principale amputée.
  Les positions identiques atteintes par des ordres de coups différents
  fusionnent : un empilement d'arbres PGN devient un graphe.
- **Les annotations de l'auteur sont lues** : `?`/`??` deviennent un piège
  signalé, `?!` une imprécision, et les commentaires `{…}` suivent.
- **Partage par simple fichier.** Un cours utilisateur est stocké au format
  exact des cours livrés ; l'exporter, c'est donner le fichier, l'importer,
  c'est le décodeur du démarrage. Aucun serveur, aucun compte.
- **La progression suit.** Elle est indexée par position et non par cours : un
  répertoire importé hérite immédiatement de ce que l'utilisateur sait déjà de
  ces positions, y compris appris dans une ouverture livrée.

Limites connues : le fichier ne se synchronise pas entre appareils (la
progression, si), et il n'y a pas d'éditeur d'arbre dans l'app — on écrit
ailleurs (Lichess Studies, par exemple) et on importe.

### Les 58 ouvertures relues au moteur

Le même testeur a trouvé, en deux captures, des coups que la base donnait pour
bons et qui perdaient une pièce ou une tour. Il y en avait quinze.

- **15 lignes réécrites**, chaque remplacement calculé coup par coup sous
  Stockfish 17.
- **4 défenses manquantes ajoutées** là où l'adversaire avait mieux que ce qui
  était couvert.
- **4 coups adverses volontairement perdants** portent désormais leur
  annotation « piège » — ils étaient présentés comme des coups normaux.
- **Un garde-fou permanent** (`tools/opening-generator/audit.py`) rejoue les
  3 135 arêtes du catalogue sous le moteur et refuse toute gaffe enseignée. La
  validation ne portait jusque-là que sur l'intégrité du graphe : un coup
  absurde mais légal passait.

### Puzzles — un seul essai

Trois essais invitaient à tenter un coup pour voir ; un puzzle s'entraîne en
calculant la variante jusqu'au bout. Un essai par défaut, trois toujours
disponibles dans Réglages → Puzzles.

### Lecteur d'ouvertures — le plateau ne quitte plus l'écran

Le plateau était dans le même défilement que le texte : lire les variantes
sortait la position de l'écran, alors qu'on lit les coups en la regardant. Le
plateau est ancré, seul le panneau texte défile. En paysage (iPad), plateau à
gauche et lecture à droite.

## Contenu de la 1.3, jamais livré jusqu'ici

- **Échiquier tolérant au doigt** : relâcher un peu à côté joue quand même le
  coup, la case visée s'allume pendant le glissement, la pièce se soulève.
  Même tolérance au clic-clic.
- **Score de précision recalibré** : les coups joués dans une position déjà
  gagnée ne le gonflent plus.
- **Le « pourquoi »** : l'app nomme le motif tactique qui condamne un coup,
  lu sur la réfutation du moteur.
- **Revue d'analyse reprise** : une analyse quittée trop tôt ne reste plus
  bloquée sur « Moteur en attente ».
- **Jouer** : contrôles en une seule rangée ; l'alerte « coup risqué » raisonne
  en probabilité de gain ; la pendule décompte dès le premier coup.
- **Mise en page** : iPhone verrouillé en portrait, plus aucun débordement
  horizontal même en taille de texte maximale, feuilles iPad en pleine page,
  partie qui survit au passage en Split View.
- **Corrections** : import PGN depuis le web (fins de ligne Windows), position
  de départ conservée à l'export, cadrage du scanner, traductions anglaises.

## Vérification

- Suites unitaire et UI vertes.
- `audit.py` : 0 gaffe enseignée sur les 58 cours, 1 lacune de couverture
  documentée (Blackmar-Diemer 8…h6).
- Corrections d'ouvertures verrouillées par `OpeningBlunderRegressionTests`,
  qui les relit depuis le bundle à chaque exécution des tests.

## Avant de soumettre

`main` doit être poussé sur GitHub : les notes réviseurs promettent des sources
publiques **correspondant au binaire soumis**, ce qui est une obligation GPLv3
(Stockfish embarqué), pas un argument commercial. Voir `METADATA.md`, section
« À FAIRE AVANT DE SOUMETTRE ».
