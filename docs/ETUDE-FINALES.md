# Étude — le module Finales

*17 août 2026. Étude préalable à la construction, menée en autonomie ;
les décisions ci-dessous sont argumentées pour pouvoir être défaites.*

## Ce qu'on veut

Un module qui soit un **coach de finales** : des cours complets, avec de
nombreuses variantes et des commentaires, pour TRAVAILLER les finales — pas
une encyclopédie de plus. Le testeur de l'app est un joueur de club ; le
public visé sait ce qu'est une finale de tours mais perd la Lucena une fois
sur deux en cadence lente.

## Les trois options étudiées

### A. Embarquer une tablebase (Syzygy 3-4-5)

Les tables Syzygy 3-4-5 pièces pèsent ~940 Mo compressées. L'app en fait 160.
Verdict immédiat : **non** — la 17.1 a été préférée à Stockfish 18 pour
33 Mo de réseau NNUE, on ne va pas multiplier la taille de l'app par six.
Une sous-sélection (K+P vs K, ~vingt Mo) resterait envisageable un jour pour
un « entraînement libre » ; hors du périmètre v1.

### B. Interroger une tablebase en ligne depuis l'app

L'API `tablebase.lichess.ovh` est gratuite et sans jeton. Mais la règle de
l'app est déjà posée et elle est bonne : **aucun appel réseau depuis
l'app** — tout fonctionne hors ligne, l'utilisateur l'a explicitement voulu
(« je ne veux pas d'appel direct de l'app vers Lichess »). Verdict : **non**
pour l'app, **oui** pour l'outillage.

### C. Des cours rédigés, vérifiés par tablebase à la génération

C'est l'architecture des ouvertures, qui a fait ses preuves sur 58 cours :
du contenu rédigé en Python (`content/*.py`), compilé en JSON embarqué,
audité automatiquement avant publication. Pour les finales, l'audit est même
PLUS fort que pour les ouvertures : jusqu'à 7 pièces, la tablebase donne le
verdict EXACT (gain/nulle/perte) de chaque position et de chaque coup. Un
cours de finale peut donc être **prouvé** : aucun coup enseigné qui lâche le
gain, aucune défense proposée qui perde une position nulle — pas
« évaluation +2,3 », mais *gagnant*, mathématiquement.

**Verdict : C.** Réutilisation maximale (lecteur, entraîneur, répétition
espacée, synchro iCloud fonctionnent tels quels), taille marginale (~300 Ko
de JSON), et une garantie de justesse qu'aucun livre imprimé n'offre.

## Ce que « reprendre des bases publiées » veut dire ici

Trois sources, trois usages distincts :

1. **Les positions canoniques** — Lucena (~1634), Philidor (1749), Vančura
   (1924), l'étude de Réti (1921), la position du trébuchet… Ce sont des
   POSITIONS, vieilles de décennies ou de siècles : des faits, pas des
   œuvres. On les reprend telles quelles, c'est le canon que tout manuel
   partage.
2. **La tablebase Lichess/Syzygy** — des FAITS calculés (gain/nulle/perte,
   distance au mat). C'est notre oracle d'audit et notre générateur de
   défenses optimales.
3. **Les textes des manuels** (Dvoretsky, de la Villa, 100 Endgames You Must
   Know…) — PAS repris : le texte d'un livre appartient à son auteur. Les
   commentaires sont rédigés pour l'app, dans son style, en français et en
   anglais, comme les 58 cours d'ouvertures.

## Architecture retenue

### Côté contenu (outillage)

- `tools/opening-generator/` apprend deux nouveautés, rétrocompatibles :
  - `spec["rootFEN"]` : un cours peut partir d'une position arbitraire
    (aujourd'hui : position initiale codée en dur) ;
  - `spec["kind"] = "endgame"` et `spec["family"]` (pawns/rooks/queens/
    minor/mates) : transportés jusqu'au JSON et au catalogue.
- `content_endgames/*.py` : un fichier par cours, même schéma que les
  ouvertures (lignes, chapitres, commentaires bilingues, `role`,
  `critical`).
- `tablebase.py` : client de l'API Lichess (cache disque, throttling), même
  discipline que `explorer.py`.
- `audit_endgames.py` : pour CHAQUE arête d'un cours de finale ≤ 7 pièces,
  vérifie que le coup enseigné **préserve le verdict théorique** de la
  position. Un coup du camp étudiant qui transforme un gain en nulle est un
  échec d'audit ; une défense adverse sous-optimale est signalée (on a le
  DROIT d'enseigner contre la défense la plus coriace ET contre la défense
  naturelle, mais il faut le faire exprès).

### Côté app

- `OpeningCourse`/`OpeningCatalogEntry` : champ optionnel `kind` (absent =
  ouverture — les 58 cours existants ne changent pas d'un octet) et
  `family`.
- `OpeningListView` filtre les finales ; nouvelle vue `EndgameListView`
  groupée par famille (Pions, Tours, Dames, Mats élémentaires).
- Accueil : tuile « Finales » (7e mode), même route lecteur/entraîneur que
  les ouvertures — le lecteur, l'entraînement FSRS, « Continuer contre
  Stockfish » et la synchro iCloud sont hérités sans une ligne de code.

### Ce que le coach fait en v1, et ce qu'il ne fait pas

- **Fait** : leçon pas à pas commentée ; variantes nombreuses (défenses
  naturelles ET coriaces) ; entraînement par rappel actif (répétition
  espacée, comme les ouvertures) ; jouer la position contre Stockfish.
- **Ne fait pas (v2 notée)** : l'entraînement LIBRE arbitré par tablebase —
  accepter n'importe quel coup qui préserve le gain, pas seulement celui de
  la leçon. Cela demande soit une tablebase embarquée partielle (option A
  réduite), soit un arbitrage moteur à forte profondeur. La v1 contourne
  honnêtement : les cours enseignent LA méthode (le pont, l'opposition), et
  c'est la méthode qu'on révise.

## Le catalogue v1 (12 cours)

Choisis pour couvrir ce qu'un joueur de club rencontre vraiment, du plus
fréquent au plus décisif :

| Famille | Cours | Position canonique |
|---|---|---|
| Pions | L'opposition | K+P vs K, pion e5 |
| Pions | La règle du carré | course roi contre pion |
| Pions | Pions cavaliers et tours : les exceptions | pion a/h, mauvaise case |
| Pions | La percée | 3 pions contre 3, percée b6 |
| Tours | La position de Lucena | le pont |
| Tours | La position de Philidor | la 6e rangée |
| Tours | Tour contre pion | la course |
| Tours | La coupure du roi | cut-off vertical |
| Dames | Dame contre pion en 7e | b/d/e/g puis les exceptions a/c/f/h |
| Mats | Le mat à la tour | l'escalier |
| Mats | Le mat aux deux fous | la boîte qui rétrécit |
| Pratique | L'étude de Réti | le roi qui court deux lièvres |

Chaque cours : ligne principale commentée coup par coup + variantes pour les
défenses que l'adversaire joue VRAIMENT + les pièges (pat !) marqués
`role: trap`. L'audit tablebase tourne sur tout.

## Risques notés

- **La répétition espacée mélange ouvertures et finales** dans la file « à
  réviser » du jour : acceptable (c'est même souhaitable, une séance mixte),
  mais l'écran Ouvertures ne doit compter que les siennes — vérifié à
  l'implémentation.
- **`normalize_fen` écrase les compteurs de coups** : sans conséquence ici
  (aucun cours ne repose sur la règle des 50 coups), noté pour mémoire.
- **Le pat** : dans les finales de dame contre pion et de mats élémentaires,
  la faute typique de l'élève est le pat. La tablebase les attrape
  (catégorie `draw` sur un coup du camp fort) — c'est précisément le genre
  de variante qu'il faut ENSEIGNER, marquée piège.
