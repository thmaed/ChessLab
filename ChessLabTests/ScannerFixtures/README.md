# Fixtures du scanner — images réelles

Ce dossier tient les images RÉELLES qui répondent à la seule question que les
tests synthétiques ne peuvent pas trancher : « ça marche sur de vraies
images ? ». Les tests synthétiques (`BoardScannerTests`) rendent leurs
gabarits ET leurs plateaux avec le même moteur : ils prouvent la cohérence du
pipeline, pas sa robustesse au réel.

Tant que `manifest.json` est vide, `ScannerFixtureTests` ne produit aucun cas
et la suite reste verte — c'est voulu.

Le chemin testé est CELUI DE L'APP : YOLO d'abord, recroisé avec les gabarits,
et passé par les garde-fous de cohérence (`BoardConsistency`). `minCorrectSquares`
mesure la justesse ; `maxSilentlyWrong` mesure ce qui compte vraiment — une
erreur NON signalée, la seule que l'utilisateur ne peut pas rattraper à la
confirmation. Relever `minCorrectSquares` au fur et à mesure des progrès du
modèle.

Les cases encore fausses tiennent surtout à la confusion de TYPE du modèle sur
un jeu non-cburnett (fou↔pion, dame↔roi) : le remède est le réentraînement sur
de **vraies silhouettes** (`scripts/yolo`, option `--piece-sets-dir`), pas un
réglage de seuil.

## Ce qu'il faut fournir (action utilisateur)

Déposer les images ici et décrire chacune dans `manifest.json` :

```json
[
  { "file": "lichess_screenshot.png", "source": "screenshot",
    "fen": "r1bq1rk1/pp2bppp/2n1pn2/2pp4/3P1B2/2PBPN2/PP1N1PPP/R2Q1RK1",
    "minCorrectSquares": 64 },
  { "file": "screen_photo.jpg", "source": "screenPhoto",
    "fen": "…", "minCorrectSquares": 60 },
  { "file": "physical_top_good_light.jpg", "source": "physicalTopDown",
    "fen": "…", "minCorrectSquares": 61 }
]
```

- `file` : nom du fichier déposé dans ce dossier.
- `source` : `screenshot` | `screenPhoto` | `physicalTopDown`.
- `fen` : le **placement** exact (premier champ d'un FEN suffit), vu du côté
  des Blancs. C'est la vérité attendue.
- `minCorrectSquares` : plancher de cases correctes (sur 64).
- `rotation` (optionnel) : quarts de tour, quand l'orientation de la prise de
  vue est CONNUE. Une fixture mesure la RECONNAISSANCE ; laisser en plus
  deviner l'orientation mélangerait deux échecs distincts dans un seul
  chiffre. À ne pas mettre pour tester justement la devinette.
- `maxSilentlyWrong` (optionnel, défaut 2) : cases fausses ET données pour
  sûres tolérées. Une erreur signalée se rattrape à l'écran de confirmation ;
  une erreur silencieuse, non.
- `corners` (optionnel) : `[[x,y], …]` en pixels de l'image, origine en haut à
  gauche, si la détection automatique échoue sur cette image.

## Images attendues

Les 3 fixtures actuelles sont toutes proches de cburnett, en `rotation:0`, et
clairsemées (finales + 1 ouverture). Elles prouvent la géométrie, pas la
généralisation. À compléter, par ordre de valeur :

1. **Autres jeux de pièces** — 1 capture chess.com « neo », 1 Lichess « alpha »
   ou « merida » : c'est là que se joue la confusion de type. Sans ces images,
   aucun test ne mesure le vrai point faible.
2. **Milieux de partie DENSES** (20+ pièces) : les amas et les cases voisines
   occupées sont le cas dur, absent des finales actuelles.
3. **Les deux orientations** — au moins une capture « Noirs en bas », SANS
   `rotation` dans le manifeste, pour éprouver `suggestedRotation`.
4. **1 photo d'un écran** (`screenPhoto`) : moiré, reflets, exposition inégale.

Chacune avec son FEN exact.
