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

## La force du moteur bridé (mesure du 08/11/2026, `strength_match.py`)

78 parties par niveau, la 19 contre la 17.1 **aux mêmes réglages que l'app** (`EngineStrength.swift`),
150 ms par coup, un fil, ouvertures tirées des parties de `Fixtures_nils.pgn` et du banc Maia,
couleurs échangées. Score de la 19 (50 % = même force) :

| Niveau | Score de la 19 | Écart Elo (IC 95 %) |
|---|---|---|
| Elo 1500 (bridé) | 55,8 % | +40 (−35 à +119) — non significatif |
| Elo 2000 (bridé) | 69,2 % | +141 (+68 à +227) |
| Elo 2500 (bridé) | 62,2 % | +86 (+15 à +166) |
| Elo 3000 (bridé) | 60,3 % | +72 (+21 à +127) |
| Elo ~1000 (Skill 2, profondeur 3) | 70,5 % | +151 (+79 à +240) |
| Elo ~1200 (Skill 4, profondeur 5) | 73,1 % | +173 (+101 à +263) |
| Maximum | 58,3 % | +58 (+22 à +96) |

**À réglage égal, la 19 joue plus fort que la 17.1**, de 40 à 170 Elo : le meilleur réseau pèse
surtout quand la recherche est courte (niveaux bridés et débutants). Les curseurs d'Elo de l'app n'ont
jamais été des Elo absolus (le niveau des personnages suit l'échelle Maia/Lichess, pas Stockfish),
mais un joueur retrouve un adversaire plus dur au même cran.

Compensation mesurée (`strength_compensation.py`, la 19 réglée plus bas contre la 17.1 inchangée) :
débutants, **un cran de Skill ET un de profondeur en moins** ramène la parité (~1000 : Skill 1,
profondeur 2 → +45 ; ~1200 : Skill 3, profondeur 4 → +40, intervalles compatibles avec 0) ; bridé à
2000 : `UCI_Elo` 1850 → +27 (1900 → +91). **Non appliquée** : le même `EngineStrength` sert Fairy-Stockfish
(inchangé), et les mesures bridées sont trop bruitées pour fonder une règle. Décision produit à prendre.

## Les pièges rencontrés

- `make clean` dans le dossier d'un binaire en cours d'utilisation le détruit : une
  compilation par dossier (`build_engines.sh` s'en charge).
- Le Makefile de la 17.1 ajoute `-mdynamic-no-pic` quand l'hôte est macOS, et clang
  Android le refuse : `KERNEL=Linux` pour cette version.
- Les réseaux de la 17.1 se retrouvent dans l'historique Git (`ChessLab/Resources/`
  avant le commit « Stockfish 17.1 -> 19 ») ; leur nom est le début de leur SHA-256.
- Ninja (CMake Android) garde d'anciens .o si les fichiers sources du tarball sont plus
  vieux : `touch` les sources vendorisées avant de recompiler.
