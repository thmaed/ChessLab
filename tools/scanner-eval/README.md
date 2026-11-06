# Banc de mesure du scanner (captures synthétiques réalistes)

Pourquoi : le scanner n'avait que 3 images réelles pour se juger. Ici, des
milliers de captures AVEC vérité terrain exacte, rendues par **chessground**
(la bibliothèque d'échiquier de Lichess, GPL-3, outil de développement : rien
n'en est livré dans l'app) avec les jeux de pièces libres de Lichess, des
positions de la base de problèmes Lichess (CC0), et les éléments d'interface
qui piègent le modèle : points de coups légaux, flèches, surbrillances,
coordonnées, miniatures de pièces capturées.

Lichess.org lui-même est derrière un contrôle anti-robot Cloudflare : on ne le
contourne pas, d'où le rendu local.

## Reproduire
    npm i chessground chess.js puppeteer-core          # dans un dossier de travail
    curl -r 0-12000000 https://database.lichess.org/lichess_db_puzzle.csv.zst | zstd -dc > puzzles.csv
    # positions.json : [{fen, last:[from,to]|null}] tiré des FEN du CSV (+ 1er coup)
    SETMODE=train|held node gen.mjs positions.json OUT N SEED
    python baseline.py OUT 300      # taxonomie des erreurs du modèle
    python to_yolo.py OUT DATASET train   # dataset d'entraînement YOLO

Les chemins (jeux de pièces, modèle) sont codés en tête de gen.mjs / common.py.
`SETMODE=held` n'utilise que 6 jeux gardés de côté (merida xkcd celtic pixel
governor mpchess) : la mesure de généralisation à des jeux INCONNUS.
Jeux chess.com (`cc_*`) et chesskid exclus du rendu.

## Réentraîner (recette qui a marché le 06/11/2026)

    # 1. données : 2 × 2200 captures « train » (jeux hors held), 300 « val », 500 « held »
    # 2. python to_yolo.py ... (UNE case = une boîte ; deux dossiers sources → noms
    #    en collision : lancer avec des préfixes distincts ou accepter 2200)
    # 3. python finetune.py 6         # depuis les poids livrés, SGD doux, val=False
    # 4. WEIGHTS=...pt python baseline.py HELD 500     # taxonomie des erreurs
    # 5. WEIGHTS=...pt python calib.py                  # seuil de doute des pièces
    # 6. python real_overlay.py                         # vraies captures + surcharges PIL
    # 7. export Core ML (nms=True, imgsz=640) puis ONNX (opset 17) ; fixtures iOS + Android

Pièges payés cher :
- `optimizer=auto` ignore `lr0` et choisit un AdamW qui abîme des poids convergés ;
  fixer `optimizer='SGD'`.
- La validation intégrée d'Ultralytics sous MPS et machine chargée tronque la NMS
  (« NMS time limit exceeded ») : rappel faussement à 0,2. `val=False` + son propre banc.
- Export Core ML : coremltools 9 + numpy 2.3 → « only 0-dimensional arrays » ;
  `pip install --target DIR numpy==2.2.6` puis `PYTHONPATH=DIR`.
- lichess.org est derrière Cloudflare : ne pas le contourner, rendre en local.

Résultats (500 captures, jeux INCONNUS) : fausses pièces 5,25 % → 0,016 % des cases,
plateaux sans aucune erreur ~45 % → 97,6 %. Sur vraies captures chess.com avec points
et flèches peints par PIL : 124 fausses pièces sur 768 cases → 0.
