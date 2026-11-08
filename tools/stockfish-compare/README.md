# Comparer deux versions de Stockfish avant d'en changer

Mesures faites le **08/11/2026** pour le passage de Stockfish 17.1 à 19. À refaire
à CHAQUE changement de version : un nouveau moteur change l'échelle de ses scores,
sa vitesse et parfois sa mémoire, et rien de cela ne fait échouer un test.

## Ce qu'on mesure

1. **L'échelle des centipions** — `compare_engines.py` fait évaluer par les deux
   moteurs les mêmes ~3 500 positions de vraies parties (`ChessLabTests/Fixtures_nils.pgn`
   et `tools/maia3-spike/calibration/camille-1100-2200.pgn`), à nombre de nœuds fixe
   (150 000, un fil), puis `analyze_cmp.py` rejoue la classification de l'app
   (sigmoïde de `MoveClassification.swift`, seuils 2 / 5 / 10 / 20 points de gain) et
   compte combien de coups changent de catégorie, et surtout combien de « gaffes ».
2. **Une courbe de correction** — `calibrate_curve.py` ajuste cp(nouveau) → équivalent
   cp(ancien) par tranches sur la moitié des parties, la vérifie sur l'autre
   (validation croisée), et imprime la table à recopier dans
   `Vendor/CStockfish/Sources/CStockfish/shim.cpp` (`kLegacyScale`).
3. **La vitesse et la mémoire sur un téléphone réel** — `build_engines.sh` compile aussi
   les deux moteurs en exécutables Android (NDK) ; on les pousse avec `adb` et on lance
   `bench 128 1 14` (hash 128, un fil, profondeur 14), en relevant `VmHWM` pour le pic
   mémoire. Pour iOS : un test temporaire sur l'appareil qui lance `go movetime 2000`
   sur quatre positions et lit les `info nodes/time` (un test jetable : ne pas le commiter).

## Ce qu'on a trouvé (17.1 → 19)

- **Échelle** : à peu près égale près de l'égalité, puis la 19 annonce **+30 à +45 %**
  entre +2 et +6 pions. Sans correction, les « gaffes » passent de 68 à 105 sur le corpus
  (+54 %), et 79,6 % seulement des coups gardent leur catégorie. Avec la courbe :
  gaffes 41/43 et 27/30 (contre 41/63 et 27/42) sur les moitiés de validation ; l'accord
  monte à 81–83 %, le reste est un vrai désaccord entre réseaux.
- **Probabilité de gain du moteur (WDL)** : bien plus stable d'une version à l'autre
  (88,4 % d'accord entre les deux moteurs), mais d'une autre échelle que la sigmoïde de
  l'app (les « gaffes » seraient ×2,7 pour le MÊME moteur). Piste pour plus tard, avec
  une recalibration des seuils ; pas adoptée pour ne pas changer le comportement.
- **Vitesse** : Galaxy A16 −15 % (188 000 contre 221 000 nœuds/s) ; iPhone XS Max
  à peu près égale en milieu de partie ; Mac Apple Silicon +21 %.
- **Mémoire** : pas de différence (pic 365 contre 362 Mo, hash 128 Mo).

## Les pièges rencontrés

- `make clean` dans le dossier d'un binaire en cours d'utilisation le détruit : une
  compilation par dossier (`build_engines.sh` s'en charge).
- Le Makefile de la 17.1 ajoute `-mdynamic-no-pic` quand l'hôte est macOS, et clang
  Android le refuse : `KERNEL=Linux` pour cette version.
- Les réseaux de la 17.1 se retrouvent dans l'historique Git (`ChessLab/Resources/`
  avant le commit « Stockfish 17.1 -> 19 ») ; leur nom est le début de leur SHA-256.
- Ninja (CMake Android) garde d'anciens .o si les fichiers sources du tarball sont plus
  vieux : `touch` les sources vendorisées avant de recompiler.
