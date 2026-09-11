# Spike Android — dérisquage du portage de ChessLab

Ce dossier **n'est pas un début de portage**. C'est un banc d'essai qui
répond aux deux questions capables d'annuler le projet :

> **A.** les sources Stockfish de l'app iOS, recompilées avec le NDK Android,
> démarrent-elles et jouent-elles correctement ?
>
> **B.** le réseau Maia3, converti en ONNX, rend-il les MÊMES coups que côté
> iOS, et à quelle vitesse ?

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

Les deux volets passent. Stockfish a fonctionné dès la première exécution ;
le volet Maia a demandé une correction (voir plus bas).

### A. Stockfish

| Étape | Résultat |
| --- | --- |
| Extraction des réseaux NNUE | 74,8 Mo (premier lancement seulement) |
| Poignée de main UCI | `Stockfish 17.1` en 911 ms |
| Chargement des réseaux | 34 ms, 3 threads |
| Mat en un | `f3f7` attendu, `f3f7` obtenu |
| Recherche profondeur 20 | 758 ms, ~1,4 M nœuds/s |
| Arrêt propre | aucun thread orphelin |

Aucun plantage, aucune fuite JNI, aucune ligne de `shim.cpp` modifiée.

### B. Maia3

| Étape | Résultat |
| --- | --- |
| Modèle ONNX fp16 chargé | 43 Mo, 56 cas en 2 203 ms |
| Accord avec les fixtures iOS | **56/56** en top-1 |
| Latence par coup | médiane **27,9 ms**, p90 28,9 ms, 3 threads |

Le modèle rend exactement les mêmes coups que côté iOS, sur les 56 cas qui
servent déjà aux tests de l'app — promotions, roques, prises en passant et
historiques longs compris.

**Deux écarts de probabilité, à ne pas confondre.** L'app Android mesure
0,003 sur le coup de tête ; le script de conversion mesure 0,076 sur le pire
des cinq premiers coups. La seconde est la mesure exigeante, et elle dépasse
la tolérance de 0,04 des fixtures iOS. Comme Maia échantillonne dans la
distribution, c'est à trancher au portage réel — détail dans le README de
`tools/maia3-spike/`.

**Le chiffre de nœuds/seconde ne veut rien dire**, et celui de latence Maia
est optimiste : l'émulateur emprunte le CPU du M2 de la machine hôte. Seul un
téléphone réel dira ce que valent la recherche et l'inférence — et c'est de
ces mesures que dépend la calibration Elo des personnages.

### Tailles produites

| | |
| --- | --- |
| `libchesslab_engine.so` (Stockfish complet) | 1,5 Mo |
| Réseaux NNUE | 75 Mo |
| Maia3 en ONNX fp16 | 43 Mo |
| **APK de débogage, les deux volets** | **131 Mo** |
| Build complet à froid | 1 min 51 s |

À rapporter au plafond de téléchargement de Google Play (~200 Mo pour un
bundle sans Play Asset Delivery). L'app complète ajouterait les puzzles
Lichess (19 Mo), les ouvertures et les assets, soit de l'ordre de 160 Mo.
On passe, mais sans marge — d'où l'intérêt de trancher tôt entre « tout
embarquer » et « télécharger les gros réseaux au premier lancement ».

### La correction qu'il a fallu faire

Le premier passage donnait 48/56. La conversion n'était pas en cause (ONNX
était à 4,6e-06 de torch) : le harnais de vérification passait le même Elo
pour le joueur et pour l'adversaire, alors que les fixtures en portent deux
distincts. Maia est conditionné par les DEUX. Corrigé, on est à 56/56 avec un
écart nul en fp32.

### Détail cosmétique

L'écran ne gère pas les encoches système (le titre passe sous la barre
d'état). Un `Modifier.safeDrawingPadding()` suffirait ; sans intérêt pour un
banc d'essai.

## Ce qui reste à dérisquer

1. **Un téléphone réel.** L'émulateur ne peut pas répondre sur la vitesse ni
   sur le comportement thermique, dont dépend toute la calibration des
   niveaux.
2. **Le Scanner.** Vision + YOLO Core ML → CameraX + OpenCV + TFLite. C'est le
   module dont la parité de qualité est la moins garantie.
