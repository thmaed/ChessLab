# Étude — un affinage à trois niveaux ?

*18 août 2026. Demande : « certains coups prennent beaucoup plus de temps ;
étudie si une approche à trois niveaux pourrait être bénéfique — analyse
seulement, ne code pas. » Voici l'analyse ; rien n'a été codé.*

## La méthode

Aucune estimation : les 887 coups des neuf parties de tournoi ont leurs
évaluations **déjà mesurées** à quatre budgets (300 k, 1 M, 3 M, 10 M nœuds).
Une cascade se simule donc hors ligne en recombinant ces mesures — c'est une
rediffusion du réel, pas un modèle. Référence de vérité : 10 M. Coût d'une
paire de positions : 236 ms (300 k) et 3 093 ms (3 M), mesurés ; 906 ms (1 M),
interpolé par la loi coût ~ nœuds^1,117 issue des deux points mesurés (la
sensibilité au modèle linéaire ne change aucun classement).

## Réponse courte : non — trois REDÉMARRAGES ne sont pas bénéfiques

À coût égal, le système à deux niveaux domine ou égale la cascade partout :

| Système | Coût | Verdicts faux restants |
|---|---|---|
| 2 niveaux, bande ±1,5 (300 k → 3 M) | ×2,42 | **2,25 %** |
| 3 niveaux ±2 puis ±1 (300 k → 1 M → 3 M) | ×2,40 | 2,37 % |
| 2 niveaux, bande ±2 (actuel) | ×2,95 | **1,92 %** |
| 3 niveaux ±2 puis ±2 | ×2,97 | 2,03 % |

La raison est celle que le chronométrage du 16/08 avait déjà établie :
**redémarrer une recherche ne rembourse rien** (un coup affiné coûte ×13,1,
pas ×10 — l'arbre se repaie entier). Un étage intermédiaire à 1 M ajoute donc
un redémarrage de plus, et son filtre est bruité : il laisse passer des cas
que le 3 M direct aurait corrigés. Et pour la latence perçue, la cascade
AGGRAVE le pire cas : un coup doublement limite paie 0,24 + 0,9 + 3,1 =
4,2 s contre 3,3 s aujourd'hui.

## Trois découvertes en passant, dont une correction de mes propres chiffres

1. **Le résidu réel du système actuel est 1,92 %, pas 0,68 %.** Le calcul de
   samedi supposait qu'un coup recalculé à 3 M était corrigé. Faux : sur les
   41 verdicts graves, 28 sont corrigés, 7 restent faux à 3 M… et 3 M en
   INTRODUIT 4 (la base avait juste, 3 M contredit 10 M — les budgets
   intermédiaires ne sont pas monotones). Le gain vrai de l'affinage est
   4,62 % → 1,92 %, soit −59 %, pas −85 %. Le PDF de Nils et le commentaire
   de `refinementBand` devront être corrigés à la prochaine retouche.
2. **Le coût réel de l'app est ×2,73, pas ×2,95** : le chronométrage repayait
   le parent à chaque affinage, alors que l'app le garde en cache — et les
   coups consécutifs s'enchaînent (l'enfant du coup n est le parent du coup
   n+1).
3. **Le vécu utilisateur, chiffré** : 11,5 % des coups bloquent plus de
   2,5 s. C'est exactement « certains coups prennent beaucoup plus de
   temps ».

## Ce qui serait bénéfique : trois niveaux DANS une seule recherche

Le bon découpage n'est pas trois recherches, c'est **une seule recherche
profonde qu'on arrête tôt quand elle a déjà tranché**. Le moteur émet ses
évaluations profondeur par profondeur pendant la recherche : au lieu de
lancer un 3 M aveugle, on le lance et on l'ARRÊTE (commande UCI `stop`) dès
que le verdict est stable et loin d'une frontière.

Mesuré sur les données : **47 % des coups affinés étaient déjà stables à 1 M
nœuds** (même étiquette qu'à 3 M, à plus d'un point des frontières). Ces
coups-là s'arrêteraient au tiers du coût — sans repayer l'arbre, puisque
c'est LA MÊME recherche qui continue ou s'arrête.

Projection : coût total ×2,73 → **≈ ×2,2**, et les arrêts > 2,5 s passent
d'environ 11,5 % à ≈ 6 % des coups, sans perdre un seul verdict (on ne
s'arrête que quand le verdict est déjà celui que 3 M aurait rendu). Aucun
étage de plus, un seul mécanisme nouveau : « stop si stable ».

## Les alternatives écartées, et pourquoi

- **Cascade 300 k → 1 M → 3 M** : dominée partout (tableau ci-dessus), pire
  cas de latence aggravé.
- **Réduire la bande à ±1,5** : simple (une constante), ×2,42 → ≈ ×2,2 avec
  le cache parent, mais résidu 2,25 % ET ne réduit pas la DURÉE d'un arrêt —
  seulement leur nombre. C'est le repli honnête si « stop si stable » paraît
  trop d'ouvrage.
- **Afficher tout de suite, affiner en arrière-plan** : latence perçue
  nulle, mais 39 % des coups affinés changent d'étiquette après coup et 24 %
  changent de camp signalé — un verdict sur 25 se retournerait sous les yeux
  du lecteur. Contraire à ce que l'affinage vend (des verdicts stables).

## Recommandation

1. **Ne pas faire** la cascade à trois redémarrages.
2. **Faire** (sur feu vert) : l'arrêt anticipé de la recherche d'affinage —
   « trois niveaux » obtenus gratuitement à l'intérieur d'une seule
   recherche. ≈ ×2,2 au total, moitié moins d'arrêts longs, zéro perte de
   qualité.
3. **Corriger au passage** les chiffres optimistes de samedi (0,68 % → 1,92 %)
   dans le code et le PDF de Nils.
