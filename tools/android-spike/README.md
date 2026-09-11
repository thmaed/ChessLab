# Spike Android — dérisquage du portage de ChessLab

Ce dossier **n'est pas un début de portage**. C'est un banc d'essai qui
répond aux trois questions capables d'annuler le projet :

> **A.** les sources Stockfish de l'app iOS, recompilées avec le NDK Android,
> démarrent-elles et jouent-elles correctement ?
>
> **B.** le réseau Maia3, converti en ONNX, rend-il les MÊMES coups que côté
> iOS ?
>
> **C.** le détecteur de pièces du Scanner, converti et sa NMS réécrite,
> retrouve-t-il les MÊMES pièces que le Core ML embarqué ?

Il ne contient aucune interface de ChessLab, aucun échiquier, aucune règle du
jeu. Juste un écran qui déroule la séquence et affiche les résultats.

## Ce qui est réutilisé tel quel

Rien n'est dupliqué ni modifié dans `Vendor/` : le `CMakeLists.txt` pointe
directement sur les sources de l'app iOS.

| Fichier | Origine | Modification |
| --- | --- | --- |
| Les 23 `.cpp` de Stockfish 17.1 | `Vendor/CStockfish/Sources/CStockfish/stockfish/` | aucune |
| `shim.cpp` (boucle UCI, flux détournés) | `Vendor/CStockfish/Sources/CStockfish/` | aucune |
| Réseaux `nn-*.nnue` | `ChessLab/Resources/` | copiés dans les assets au build |
| Fixtures Maia (56 cas) | `ChessLabTests/Fixtures_maia3.json` | prémâchées par `convert_maia3_onnx.py` |
| Modèle YOLO | `ChessLab/ChessPiecesYOLO.mlpackage` + `runs/.../train-6` | réexporté en ONNX |
| Images du scanner | `ChessLabTests/ScannerFixtures/` | recadrées en 640 × 640 |

C'est le point important : le shim est du C++ standard (`std::thread`,
`std::streambuf`), sans une seule API Apple. Il traverse la frontière sans
retouche.

## Ce qui est nouveau (et minuscule)

- `app/src/main/cpp/jni_bridge.cpp` — ~90 lignes. Le pont JNI.
- `app/src/main/java/.../Stockfish.kt` — les déclarations `external`.
- `app/src/main/java/.../EngineSession.kt` — file de lignes, l'équivalent
  rudimentaire d'`EngineController`.
- `app/src/main/java/.../SpikeScenario.kt` — le scénario mesuré.
- `app/src/main/java/.../MaiaBench.kt` — le volet Maia : ONNX Runtime, la
  softmax restreinte aux coups légaux, la comparaison aux fixtures.
- `app/src/main/java/.../YoloBench.kt` — le volet Scanner : ONNX Runtime et
  la NMS, que l'export Core ML embarque mais pas l'export ONNX.

L'encodeur Maia n'est **pas** porté ici, et c'est délibéré : les entrées
viennent des fixtures iOS (64 cases × 96 bits en hexadécimal, ce que produit
`MaiaEncoder.swift`). Le spike mesure donc le modèle, pas une réimplémentation
— le portage de l'encodeur est du travail ordinaire, pas un risque.

## Les deux pièges Android trouvés en route

1. **Piles de threads.** Android donne 1 Mo de pile aux threads secondaires,
   trop peu pour la recherche profonde de Stockfish. `thread_win32_osx.h`
   règle déjà le problème, mais ne s'active que sur `__APPLE__` — d'où le
   `-DUSE_PTHREADS` du `CMakeLists.txt`, qui redonne les piles de 8 Mo.
2. **Les assets ne sont pas des fichiers.** Sur iOS, Stockfish lit les
   réseaux NNUE directement dans le bundle. Sur Android, il faut les
   extraire une fois vers le stockage privé de l'app avant de démarrer le
   moteur (75 Mo à recopier au premier lancement).

Bonne surprise à l'inverse : Stockfish gère Android en amont. `numa.h`
l'exclut explicitement du code NUMA, `misc.cpp` et `memory.cpp` ont leurs
branches `__ANDROID__`. Rien à corriger de ce côté.

## Lancer

```bash
./run-spike.sh          # build + émulateur + install + lancement
./run-spike.sh build    # build seulement
```

Prérequis (installés par le spike) : JDK 21, SDK Android 35, NDK 27.2,
CMake 3.22, émulateur arm64.

## Résultats — 11/09/2026, émulateur Pixel 7 (Android 15, arm64, 4 cœurs)

Les trois volets passent.

### A. Stockfish

| Étape | Résultat |
| --- | --- |
| Extraction des réseaux NNUE | 74,8 Mo (premier lancement seulement) |
| Poignée de main UCI | `Stockfish 17.1` |
| Chargement des réseaux | 3 threads |
| Mat en un | `f3f7` attendu, `f3f7` obtenu |
| Recherche profondeur 20 | atteinte |
| Arrêt propre | aucun thread orphelin |

Aucun plantage, aucune fuite JNI, aucune ligne de `shim.cpp` modifiée.

### B. Maia3

| Étape | Résultat |
| --- | --- |
| Modèle ONNX fp16 chargé | 43 Mo |
| Accord avec les fixtures iOS | **56/56** en top-1 |

Le modèle rend exactement les mêmes coups que côté iOS, sur les 56 cas qui
servent déjà aux tests de l'app — promotions, roques, prises en passant et
historiques longs compris.

**Deux écarts de probabilité, à ne pas confondre.** L'app Android mesure
0,003 sur le coup de tête ; le script de conversion mesure 0,076 sur le pire
des cinq premiers coups. La seconde est la mesure exigeante, et elle dépasse
la tolérance de 0,04 des fixtures iOS. Comme Maia échantillonne dans la
distribution, c'est à trancher au portage réel — détail dans le README de
`tools/maia3-spike/`.

### C. Scanner

| Étape | Résultat |
| --- | --- |
| Détecteur YOLO ONNX chargé | 10 Mo, 3 images |
| Accord avec le Core ML embarqué | **75/76 détections (99 %)**, IoU min 0,981 |

L'export Core ML d'ultralytics embarque la NMS dans le modèle, l'export ONNX
non : le post-traitement est donc du code neuf (`YoloBench.postProcess`). Il
rend le MÊME 75/76 que la référence Python — l'unique écart est une boîte
limite que le fp16 du Core ML et le fp32 de l'ONNX ne tranchent pas pareil,
pas un défaut du portage. Détail dans `tools/yolo-spike/`.

### Les latences ne sont pas exploitables

C'est le résultat le plus important de la journée, et il est négatif.

| Mesure | Étendue observée sur 3 lancements |
| --- | --- |
| Recherche Stockfish | 0,2 à 1,4 M nœuds/s |
| Inférence Maia3 (médiane) | 28 à 216 ms |
| Détection YOLO (médiane) | 415 à 456 ms |

Un facteur 7 sur Maia entre deux lancements du MÊME binaire sur la MÊME
machine. L'émulateur emprunte le CPU du M2 de l'hôte et son ordonnancement
est imprévisible : ces chiffres ne disent rien d'un téléphone, ni en bien ni
en mal. **Toute la calibration Elo des personnages dépend de mesures qu'on ne
peut pas faire ici.** C'est l'argument matériel pour acheter un appareil
avant d'aller plus loin.

### Tailles produites

| | |
| --- | --- |
| `libchesslab_engine.so` (Stockfish complet) | 1,5 Mo |
| Réseaux NNUE | 75 Mo |
| Maia3 en ONNX fp16 | 43 Mo |
| Détecteur YOLO en ONNX fp32 | 10 Mo |
| **APK de débogage, les trois volets** | **139 Mo** |

À rapporter au plafond de téléchargement de Google Play (~200 Mo pour un
bundle sans Play Asset Delivery). L'app complète ajouterait les puzzles
Lichess (19 Mo), les ouvertures et les assets, soit de l'ordre de 165 Mo.
On passe, mais sans marge — d'où l'intérêt de trancher tôt entre « tout
embarquer » et « télécharger les gros réseaux au premier lancement ».

### Les deux corrections qu'il a fallu faire

**Maia, 48/56 au premier passage.** La conversion n'était pas en cause (ONNX
était à 4,6e-06 de torch) : le harnais passait le même Elo pour le joueur et
pour l'adversaire, alors que les fixtures en portent deux distincts et que
Maia est conditionné par les deux. Corrigé, 56/56 avec un écart nul en fp32.

**Scanner, critère de réussite.** Exiger l'égalité stricte avec le Core ML
était le mauvais bar : les deux modèles n'ont ni la même précision ni la même
NMS. Le seuil est à 95 %, et le code dit pourquoi.

### Détail cosmétique

L'écran ne gère pas les encoches système (le titre passe sous la barre
d'état). Un `Modifier.safeDrawingPadding()` suffirait ; sans intérêt pour un
banc d'essai.

## Ce qui reste à dérisquer

**Un téléphone réel, et lui seul.** Les trois conversions sont faites et
vérifiées ; ce qui manque est la vitesse et le comportement thermique, que
l'émulateur ne peut pas approcher. Tout le reste du portage (interface,
persistance, rectification du scanner) est du travail ordinaire : long, mais
sans inconnue.
