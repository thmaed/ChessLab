# Calibrage « perte moyenne → Elo estimé » (chantier C.1)

Ce dossier prépare la courbe qui permettra d'afficher, sous la précision d'une
partie analysée, une phrase du genre « Niveau estimé de cette partie :
~1450–1750 ». Tant que la courbe n'est pas mesurée, **rien ne s'affiche** :
l'app ne montre pas de chiffre qu'elle n'a pas vérifié.

## Où en est le chantier

| Lot | État |
|---|---|
| C.0 — persister les métriques par partie | **fait** (20/08/2026) |
| C.1 — campagne de calibrage | protocole écrit ci-dessous, campagne à mener |
| C.2 — `EloEstimator` + affichage | à faire, après la courbe |
| C.3 — validation humaine | à faire, avant de retirer la mention « bêta » |

## Ce que C.0 a livré, et qui sert de matière première

Chaque partie entièrement analysée porte désormais son bilan chiffré
(`GameRecord`, champs additifs) :

- `whiteAccuracy` / `blackAccuracy` — la précision affichée ;
- `whiteAverageLoss` / `blackAverageLoss` — **la perte moyenne BRUTE** de
  probabilité de gain, en points de pourcentage, non pondérée et **hors
  théorie** : c'est la grandeur comparable d'une partie à l'autre, celle sur
  laquelle la courbe s'ajuste ;
- `whiteClassifiedCount` / `blackClassifiedCount` — les coups qui comptent ;
- `whiteBookCount` / `blackBookCount` — les coups de théorie écartés ;
- `analysisVersion` — la version du barème, **à ne jamais mélanger** ;
- `analysisKey` — l'empreinte canonique de la partie (position de départ +
  suite des coups), qui relie une session d'analyse à la partie enregistrée.

Le calcul vit dans `GameAnalysisMetrics` : fonction pure, testée sur des
valeurs écrites à la main (`GameAnalysisMetricsTests`).

## Le piège n° 1 du plan, tranché

> « Comment le slider 800–3190 du mode Jouer mappe-t-il la force réelle ? »

Vérifié dans `ChessLab/Play/EngineStrength.swift` : le mappage n'est **pas**
linéaire, et il change de nature en cours de route.

| Plage du slider | Ce qui est réellement envoyé au moteur |
|---|---|
| ≥ 3190 | `UCI_LimitStrength=false`, `Skill Level=20` — pleine puissance |
| 1320 … 3189 | `UCI_LimitStrength=true`, `UCI_Elo=<valeur>`, `Skill Level=20` |
| 800 … 1319 | `UCI_LimitStrength=false`, `Skill Level` interpolé 0→5, **et profondeur plafonnée 1→6** |

Sous 1320, l'Elo affiché est donc une **étiquette**, pas un réglage : Stockfish
n'accepte pas `UCI_Elo` plus bas, et c'est `Skill Level` + la profondeur qui
font le travail. Une courbe calibrée en pilotant `UCI_Elo` directement
mentirait sur tout le bas de l'échelle — exactement là où se trouvent les
joueurs que l'estimation intéresse le plus.

**Conséquence pour la campagne** : les séries doivent être lancées **depuis le
Laboratoire, par valeur de slider**, jamais en envoyant `UCI_Elo` à la main.
C'est acquis sans effort — `LabGameSettings.sideAStrength` construit un
`EngineStrength(sliderValue:)`, le même type et le même mappage que le mode
Jouer. Le Laboratoire est donc, littéralement, le produit.

## Protocole de la campagne

1. **Séries.** Depuis le Laboratoire, une série par palier, **même valeur de
   slider des deux côtés** : 800, 1100, 1400, 1700, 2000, 2300, 2600, 2900.
   Au moins 30 parties par palier (60 pour les paliers sous 1320, dont la
   dispersion est plus forte). Livre d'ouvertures activé des deux côtés, comme
   en partie normale.
2. **Classification.** Chaque partie passe ensuite par le pipeline d'analyse de
   production **à l'identique** — mêmes budgets en nœuds, mêmes seuils, même
   exclusion de la théorie. C'est la condition de validité : une courbe ajustée
   sur des chiffres produits autrement ne décrit pas ce que l'app affichera.
   En pratique, ouvrir chaque partie dans l'Analyste suffit : C.0 écrit les
   métriques en fin de classification.
3. **Extraction.** Exporter les `GameRecord` analysés en CSV (une ligne par
   camp : palier, perte moyenne, coups classés, coups de théorie, précision,
   version du barème).
4. **Ajustement.** `fit_curve.py` (à écrire) : régression **monotone** de la
   perte moyenne vers l'Elo — isotone ou logistique, jamais un polynôme libre
   qui ondulerait. Écart-type par palier → demi-largeur de la fourchette.
5. **Livrable.** La courbe figée en JSON versionné, embarquée dans
   `Resources/`, plus les CSV bruts commités ici : sans les données, la courbe
   n'est pas reproductible et le calibrage n'est qu'une affirmation de plus.

## Pièges à ne pas rejouer

- **Ne jamais moyenner deux versions de barème.** `analysisVersion` est là pour
  filtrer. Elle se change en même temps que `AnalysisEvalStore.engineProfile`,
  qui joue le même rôle pour le cache disque.
- **Un moteur bridé ne se trompe pas comme un humain** : ses erreurs sont plus
  uniformes, avec moins de gaffes isolées. La courbe issue de moteurs seuls est
  donc à valider sur des parties humaines (C.3) avant de retirer la mention
  « bêta ».
- **Les parties courtes et les écrasements** produisent des pertes moyennes non
  représentatives. Le seuil de 15 coups classés hors théorie les écarte ;
  vérifier sur les CSV que la dispersion par palier reste exploitable, sinon
  augmenter le nombre de parties plutôt que d'élargir le seuil.
- **Après l'épisode Nils** : un chiffre douteux coûte plus cher que pas de
  chiffre. La fourchette et le « bêta » ne sont pas négociables en v1.
