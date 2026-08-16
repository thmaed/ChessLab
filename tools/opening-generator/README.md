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

## Deux chaînes, et une seule alimente l'app

C'est la source de confusion à connaître avant de toucher quoi que ce soit :

| chaîne | entrée | sortie | réseau |
|---|---|---|---|
| **`author.py`** | `content/<ouverture>.py`, écrit à la main | `ChessLab/Resources/openings/` — **ce que l'app embarque** | aucun |
| `generate.py` | API Lichess Explorer | `out/openings/` — jamais copié tel quel | oui |

Les 58 cours embarqués sortent **tous** de `author.py`, donc de variantes
tapées à la main. `generate.py` (exploration statistique, branchement,
transpositions) reste inutilisé pour la production : d'où des cours en
arborescence quasi linéaire, sans les défenses alternatives réelles.

```bash
python3 author.py                       # (ré)écrit les 58 cours embarqués
python3 author.py --only scandinavian
```

## L'audit moteur est OBLIGATOIRE après toute modification de contenu

`validate.py` ne contrôle que l'intégrité du graphe : un coup peut être
parfaitement légal et parfaitement stupide. Des gaffes sont passées comme ça
jusqu'aux testeurs (…Cd5 qui perd une pièce dans le Blackmar-Diemer, …Db4 qui
laisse une tour gratuite dans l'Englund). `audit.py` rejoue chaque arête sous
Stockfish et refuse celles qui perdent :

```bash
python3 author.py && python3 audit.py --stockfish "$(which stockfish)"
```

Deux niveaux, parce que les deux fautes n'ont pas la même gravité :

- **erreur (sortie ≠ 0)** — un coup de NOTRE répertoire qui perd ≥ 1,50, ou une
  fin de chapitre qui perd : dans les deux cas on enseigne une faute, ou on
  laisse la variante s'achever sur une gaffe inexpliquée.
- **avertissement** — un coup de l'ADVERSAIRE en milieu de ligne qui n'est pas
  le meilleur : on ne ment pas, mais on ne couvre pas sa meilleure défense.
  Lacune de couverture, à combler en approfondissant (`--strict` pour bloquer
  là-dessus aussi).

Un mauvais coup VOLONTAIRE — le piège qu'on veut montrer — s'annote
`"role": "trap"` ou `"inaccuracy"` dans le contenu : l'app l'affiche alors avec
sa pastille et l'audit le laisse passer. Les gambits nommés, que le moteur
condamnera toujours, sont listés dans `WAIVERS` en tête d'`audit.py`, avec leur
raison écrite.

## Utilisation

### Jeton Lichess — obligatoire depuis 2026

L'Opening Explorer n'accepte plus les requêtes anonymes : sans jeton, **toute**
requête de données répond `401 Authorization Required`. Vérifié le 15/08/2026
depuis trois sorties réseau différentes, sur les deux noms d'hôte, avec et sans
User-Agent descriptif ; la spec OpenAPI de Lichess déclare bien
`security: OAuth2: []` sur ces routes, même si l'exemple `curl` de sa
description n'a pas suivi.

Créer un jeton (gratuit, **aucune permission à cocher** — il ne sert qu'à
s'identifier) sur <https://lichess.org/account/oauth/token>, puis :

```bash
export LICHESS_TOKEN=lip_xxxxxxxxxxxx
```

Le jeton se lit dans l'environnement (`LICHESS_TOKEN`, ou `LICHESS_API_TOKEN`)
et **jamais** en argument de ligne de commande : un argument finit dans
l'historique du shell et dans la liste des processus. `generate.py` refuse de
démarrer sans lui, avant même de charger les noms ECO — sinon le lot tournerait
une heure pour ne produire que du vide. Seul `--dry-run` s'en passe, puisqu'il
ne sort pas sur le réseau.

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
  — `explorer.lichess.org/masters` (parties de maîtres) et
  `explorer.lichess.org/lichess` (parties en ligne, filtrées par tranche Elo).
  Noms d'hôte **documentés** ; les anciens `.ovh` répondent encore, à
  l'identique. Jeton OAuth requis, voir « Utilisation » ci-dessus.
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
