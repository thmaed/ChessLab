# Spike Scanner — le détecteur de pièces sur Android

Volet C du dérisquage du portage Android (voir `tools/android-spike/`).
Une seule question :

> le détecteur YOLO embarqué dans l'app iOS, converti en ONNX, retrouve-t-il
> les mêmes pièces sur Android ?

## Portée — ce que ce spike ne fait PAS

Il mesure **le modèle**, pas le pipeline du scanner. Ne sont pas portés ici :

- la détection du plateau dans la photo (`VNDetectRectanglesRequest`) ;
- la rectification et le calage de la grille (`BoardRectifier`, `BoardGridFinder`) ;
- les garde-fous de cohérence (`BoardConsistency`).

Ce sont ~3 700 lignes de géométrie et d'heuristique, sans dépendance à Core ML :
du travail ordinaire à refaire en Kotlin/OpenCV, pas un risque de conversion.
Le spike leur substitue un recadrage grossier — un balayage de carrés qui
retient celui où le modèle voit le plus de pièces — ce qui suffit à obtenir une
image de plateau exploitable pour comparer deux runtimes.

**Conséquence à ne pas mal lire** : le nombre de pièces détectées (41 sur la
position de départ, alors qu'il y en a 32) ne dit rien de la justesse du
scanner. Le chiffre qui compte est l'ACCORD entre les deux runtimes sur les
mêmes entrées.

## Ce qui est comparé

| | |
| --- | --- |
| Référence | `ChessLab/ChessPiecesYOLO.mlpackage` — le modèle **réellement livré** |
| Candidat | le même réseau exporté en ONNX depuis `runs/detect/.../train-6/best.pt` |
| Entrées | les 3 images de `ChessLabTests/ScannerFixtures/`, recadrées en 640 × 640 |

Le checkpoint est confirmé comme étant le bon : YOLO11n, 2 584 492 paramètres,
12 classes dans le même ordre — ce qui correspond exactement aux 5,2 Mo de
poids fp16 du `.mlpackage`.

## Une différence structurelle à connaître

L'export **Core ML d'ultralytics embarque la NMS dans le modèle** (d'où les
sorties `confidence` / `coordinates` que Vision sait lire directement).
L'export **ONNX ne l'embarque pas** : il sort les boîtes brutes
`(4 + 12) × 8400`, et le post-traitement est à écrire.

C'est donc du code neuf des deux côtés — `onnx_detect()` ici en numpy,
`YoloBench.postProcess()` en Kotlin — et c'est précisément ce que le spike
vérifie. Le Python sert de référence au Kotlin.

## Reproduire

```bash
../maia3-spike/mlenv/bin/python convert_yolo_onnx.py
```

L'environnement Python est partagé avec le spike Maia (`tools/maia3-spike/mlenv`),
qui porte déjà torch ; il faut y ajouter `ultralytics`, `coremltools`, `pillow`.

## Résultats — 11/09/2026

Comparaison Core ML (embarqué, fp16) vs ONNX (fp32), sur Mac M2 :

| Image | Core ML | ONNX | appariées | IoU min | Δconf max |
| --- | --- | --- | --- | --- | --- |
| `chesscom_endgame_rook` | 19 | 19 | 19/19 | 0,987 | 0,008 |
| `chesscom_endgame_pawns` | 16 | 17 | 16/16 | 0,988 | 0,006 |
| `chesslab_ipad_opening` | 41 | 41 | 40/41 | 0,981 | 0,016 |

**75 détections sur 76**, boîtes superposées à mieux que 0,98 d'IoU. La seule
qui manque est une boîte limite du côté du seuil : le fp16 du Core ML et le
fp32 de l'ONNX ne la tranchent pas pareil.

Sur Android, ONNX Runtime avec la NMS réécrite en Kotlin donne **exactement le
même 75/76 et la même IoU minimale** : le portage reproduit fidèlement la
référence Python, et l'écart restant est celui, connu, entre les deux
précisions — pas un défaut du portage.

Tailles et latences :

| | |
| --- | --- |
| ONNX fp32 | 10,1 Mo |
| Core ML fp16 embarqué | 5,2 Mo |
| Latence ONNX Runtime CPU (Mac M2) | 47,6 ms |
| Latence Core ML CPU (Mac M2) | 20,5 ms |

Passer l'ONNX en fp16 ramènerait la taille vers 5 Mo ; ça n'a pas été fait,
10 Mo n'étant pas le problème à côté des 118 Mo de réseaux d'échecs.
