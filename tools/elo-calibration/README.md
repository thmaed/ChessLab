# Estimation du niveau Elo — chantier ABANDONNÉ le 21/08/2026

**Ne pas relancer ce chantier sans lire ce qui suit.** Il a été mesuré, pas
abandonné par lassitude : deux pilotes montrent que l'estimation visée n'est pas
atteignable avec la précision exigée, et les mesures sont conservées ici pour
que la démonstration soit rejouable.

## Ce qui était visé

Afficher, sous la précision d'une partie analysée, une fourchette du genre
« Niveau estimé de cette partie : ~1450–1750 », plus un estimé glissant dans
l'écran Progrès. Barre produit fixée par l'utilisateur le 21/08 : **±100 à
150 Elo, sinon on abandonne**.

## Ce qui a été mesuré

Deux pilotes, paliers 1100 / 1700 / 2300 / 2900, six parties par palier, jouées
au Laboratoire **par valeur de curseur** (donc avec le mappage exact du mode
Jouer) puis repassées dans le pipeline d'analyse de production, budgets et
seuils inchangés. Mesures brutes dans `mesures/`.

Quatre statistiques candidates ont été éprouvées :

| Statistique | Séparation 1100→1700 | Fourchette 1 partie | Sur 10 parties |
|---|---|---|---|
| Perte moyenne | d = 0,53 | ±699 Elo | ±221 Elo |
| Précision affichée | d = 0,50 | ±677 Elo | ±214 Elo |
| Perte hors positions tranchées | d = 0,87 (partiel) | — | — |
| Part de coups fautifs | d = 0,18 (partiel) | — | — |

Le *d* est l'écart entre deux paliers rapporté au bruit : en dessous de 1, les
deux distributions se recouvrent largement. Ici, **deux paliers distants de
600 Elo sont indiscernables** — 1100 et 1700 produisent presque les mêmes
chiffres.

## Pourquoi ça ne marche pas

**La dilution.** Les parties du Laboratoire sont longues (jusqu'à 75 coups
classés par camp au palier 1100). Une fois la position tranchée, plus aucun coup
ne coûte rien à personne : des dizaines de coups triviaux noient les quelques
décisions qui distinguent réellement deux joueurs. Restreindre la moyenne aux
positions encore indécises n'y change presque rien (0,87 contre 0,78) : cela
retire des coups faciles **des deux côtés** à la fois.

**La fréquence n'est pas le bon signal.** La part de coups fautifs est la pire
des quatre (d = 0,18), et c'est logique après coup : à budget de recherche
égal, un moteur bridé à 1100 et un à 1700 se trompent à des fréquences voisines
— c'est la **gravité** de leurs erreurs qui diffère, pas leur nombre.

**Et ce n'est pas un problème d'échantillon.** Jouer 30 parties au lieu de 6
resserrerait la moyenne de chaque palier, donc le centre de la courbe. Cela ne
resserre pas la dispersion d'**une** partie, qui est précisément ce qu'il
faudrait annoncer. Même l'estimé glissant sur dix parties reste à ±214 Elo,
au-delà de la barre.

## Ce qui reste, et pourquoi

Rien n'est supprimé, parce que tout ressert ailleurs :

- `ChessLabTests/EloCalibrationHarness.swift` — fait jouer des séries au
  Laboratoire à un niveau donné puis les repasse dans le pipeline d'analyse.
  C'est exactement l'instrument dont le **chantier D** a besoin pour mesurer la
  force effective d'un style d'adversaire (lot D.1.d). Éteint par défaut, ne
  s'allume que sur `CHESSLAB_CALIBRATION=1`.
- `discriminate.py` — dit si une statistique sépare deux paliers, et traduit sa
  dispersion en Elo. Réutilisable tel quel pour D.
- `fit_curve.py` — ajustement monotone perte → Elo, avec ses garde-fous
  (refus de mélanger deux barèmes, seuil de 15 coups classés).
- `mesures/` — les CSV des deux pilotes. Sans eux, ce document ne serait
  qu'une affirmation.

Les métriques persistées par le lot **C.0** restent également en place
(`GameRecord.whiteAverageLoss`, `analysisVersion`…) : elles rendent l'analyse
d'une partie déjà vue relisible au lieu d'être recalculée, ce qui était un point
du backlog depuis l'étape 3, et sont indépendantes de l'estimation abandonnée.

## Si quelqu'un veut réessayer un jour

Ce qui n'a **pas** été testé, et qui serait la seule piste sérieuse : ne plus
chercher à estimer un niveau à partir d'une moyenne, mais à partir de la
**distribution des pertes sur les positions critiques uniquement** — celles où
plusieurs coups raisonnables existent et où un seul tient. Cela suppose de
détecter ces positions (écart entre le premier et le deuxième coup du moteur),
donc un budget de recherche bien supérieur, et une campagne autrement plus
longue. À ne lancer qu'avec une hypothèse précise et une barre de réussite
posée d'avance — comme celle-ci.
