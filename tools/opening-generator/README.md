# Générateur d'ouvertures ChessLab

Script **hors application** (jamais compilé dans la cible iOS) qui pré-génère
les cours d'ouvertures embarqués : un graphe de variantes par ouverture,
indexé par **FEN normalisée**, directement décodable par le modèle Swift
`OpeningCourse` (`ChessLab/OpeningGraph/OpeningCourse.swift`).

Aucune donnée réseau à l'exécution de l'app : tout est figé ici, hors ligne.

## Installation

```bash
cd tools/opening-generator
python3 -m pip install -r requirements.txt   # python-chess, requests
```

## Utilisation

```bash
python3 generate.py --selftest                    # auto-test hors ligne (aucun réseau)
python3 generate.py --only scandinavian           # une ouverture
python3 generate.py --only scandinavian,italian-game,anti-sicilians   # le pilote J5
python3 generate.py                               # tout le catalogue
python3 generate.py --resume                      # reprend, saute ce qui existe déjà
python3 generate.py --dry-run                     # n'utilise QUE le cache (aucune requête)
python3 generate.py --stockfish "$(which stockfish)"          # + évals & détection de pièges (optionnel)
```

Sortie dans `out/` : `out/openings/<id>.json` (un fichier par ouverture) +
`out/opening_catalog.json` (index léger). `out/` et `.cache/` sont **gitignorés**
et **ne doivent jamais** entrer dans la cible iOS ; les fichiers finaux validés
sont copiés à la main dans `ChessLab/Resources/openings/` au jalon d'intégration.

## Sources et licences

- **Noms & codes ECO** : jeu de données public
  [`lichess-org/chess-openings`](https://github.com/lichess-org/chess-openings)
  (`a.tsv`..`e.tsv`), **domaine public**. Sert uniquement à nommer les positions
  atteintes (`ecoName`). Téléchargé et mis en cache automatiquement, ou fourni
  via `--chess-openings-dir`.
- **Coups réels & statistiques** : [API Lichess Opening Explorer](https://lichess.org/api#tag/Opening-Explorer)
  — `explorer.lichess.ovh/masters` (parties de maîtres) et
  `explorer.lichess.ovh/lichess` (parties en ligne, filtrées par tranche Elo).
  **Double pondération** conservée : maîtres (théoriquement correct) ET club
  1400-2000 (ce que le joueur affronte vraiment).
- **Évaluations** : Stockfish local (optionnel, `--stockfish`), en batch, pour
  annoter les coups et repérer les pièges (chute d'évaluation). Installe-le via
  `brew install stockfish` puis `--stockfish "$(which stockfish)"`. Chemin
  absent/faux → on prévient et on génère SANS évaluations (jamais d'échec).

Ces mentions doivent apparaître dans l'écran « Sources » de l'app (jalon J9).

## Profils de génération

| profil     | profondeur | branches | seuil popularité | élagage cumulé |
|------------|-----------:|---------:|-----------------:|---------------:|
| `core`     | 18         | 4        | ≥ 2 %            | 0,5 %          |
| `extended` | 10         | 2        | ≥ 5 %            | 1 %            |
| `trap`     | 14         | 3        | ≥ 3 %            | 0,5 %          |

**Élagage intelligent** : une branche n'est pas approfondie si la probabilité
CUMULÉE d'occurrence (produit des popularités depuis l'entrée) tombe sous le
seuil — ce qui garde ce qui arrive vraiment sur l'échiquier sans explosion
combinatoire. Le coup le plus joué d'un nœud est toujours conservé.

## Robustesse (l'API a connu 429 & indisponibilités)

- **Cache disque** de chaque réponse, indexé par FEN normalisée : re-lancer ne
  refait aucune requête déjà faite (transpositions incluses). Le cache EST la
  reprise.
- **Backoff exponentiel** sur HTTP 429 (respecte `Retry-After`), délai minimal
  configurable entre requêtes.
- `--resume` saute les ouvertures déjà écrites ; `--dry-run` n'utilise que le
  cache. Les positions en échec sont journalisées (`out/failed_positions.json`,
  rejouable).

## Format de sortie

Miroir exact du modèle Codable Swift (`models.py` ⇄ `OpeningCourse.swift`).
Les champs nuls sont omis (fichiers compacts, décodage défensif côté Swift).
La clé de chaque nœud est la **FEN normalisée** (`fen.py` ⇄ `OpeningFENKey.swift`,
sémantique identique vérifiée : 4 champs, e.p. légale seulement). Avant écriture,
`validate.py` rejoue chaque coup et compare à `toFEN` — le validateur Swift
`OpeningCourseValidator` refait le même contrôle sur le fichier embarqué.

## Commentaires pédagogiques

Le générateur **ne rédige aucun commentaire** (règle stricte : les explications
sont écrites et relues à la main). Les brouillons éventuels porteront
`commentStatus: "draft"` et ne sont jamais affichés comme définitifs par l'app.
Un outil d'édition en masse (CSV/YAML) arrive au jalon J5.

## Poids du bundle

Le rapport de génération donne le poids total. Si l'ensemble dépasse quelques
dizaines de Mo : compression (gzip par fichier), format binaire, ou On-Demand
Resources en gardant le noyau embarqué pour l'usage hors ligne. Le chargement
est **paresseux, un fichier par ouverture** (jamais un gros monolithe).
