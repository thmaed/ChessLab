# Spike Règles — la couche d'échecs en Kotlin

Volet D du dérisquage du portage Android (voir `tools/android-spike/`).
Il ne porte pas sur une conversion de modèle mais sur la **dépendance la plus
transversale de l'app** : `ChessKit`, importé par 126 des 443 fichiers Swift.

## Le constat qui change la stratégie

Au départ, le plan raisonnable semblait être « adopter une bibliothèque
d'échecs Kotlin ». C'est le mauvais plan. Deux mesures le montrent :

| | |
| --- | --- |
| Taille de ChessKit | **5 490 lignes**, 33 fichiers |
| Licence | **MIT** — le port est autorisé |
| Tests fournis | 18 fichiers, 2 561 lignes, **128 tests** |
| Constructions Swift sans équivalent Kotlin | aucune |

Les seules particularités Swift sont `mutating func` (31), `subscript` (3),
`CaseIterable` (6) et un `@propertyWrapper` — toutes mécaniques.

**Porter ChessKit coûte moins cher que le remplacer.** Une bibliothèque tierce
imposerait une autre API, donc de REDESSINER les 126 fichiers qui en dépendent
et de vérifier à la main que chaque notion existe (arbre de variantes, PGN
annoté, roques Chess960). Le port garde l'API : les 126 fichiers se
**traduisent** au lieu d'être repensés. Et la suite de tests de ChessKit
devient la recette du port.

## Ce que ce spike porte, et ce qu'il prouve

Une tranche verticale — celle du FEN, colonne vertébrale de ChessLab :

| Kotlin | lignes |
| --- | --- |
| `Square.kt` (File, Rank, notation, couleur, voisines) | 88 |
| `FenParser.kt` | 95 |
| `Position.kt` (Castling, LegalCastlings, EnPassant, Clock, Position) | 60 |
| `Piece.kt` (Color, Kind, FEN) | 45 |
| **total porté** | **288** |

Et les tests qui vont avec :

| Test | Origine | Résultat |
| --- | --- | --- |
| `SquareTest` (6 cas) | `SquareTests.swift`, repris un pour un | ✅ |
| `FenParserTest` (5 cas) | `FENParserTests.swift`, repris un pour un | ✅ |
| `FenCorpusTest` | **106 094 FEN réelles** de `lichess_puzzles.json` | ✅ |

> corpus : 106094 positions, 106094 lues, 0 écart(s) relevé(s)

Aller-retour exact sur l'intégralité du corpus que l'app embarque déjà :
promotions, prises en passant, roques partiels, pendules à 99 demi-coups.
C'est une garantie autrement plus forte que onze tests unitaires.

**Toute la suite tourne en 3 secondes, sur la JVM, sans émulateur.** C'est
concrètement la boucle de travail du portage : la logique métier se teste sur
la machine, seule l'interface demande un appareil.

## Les deux écarts assumés

1. Les deux `switch` de 64 branches de `Square` (file/rank ↔ case) sont
   remplacés par de l'arithmétique sur l'ordinal. L'ordre des cases est celui
   de ChessKit, donc les deux formulations coïncident case par case — et les
   tests directionnels le vérifient.
2. `Rank` borne sa valeur à la construction comme l'original, mais doit
   définir `equals`/`hashCode` à la main : une `data class` comparerait la
   valeur DEMANDÉE et non la valeur bornée, et `Rank(0)` cesserait d'être égal
   à `Rank(1)`.

`Square.File` et `Square.Rank` restent imbriqués comme dans l'original :
l'API appelante ne change pas.

## Ce qu'il resterait à porter

| Fichier ChessKit | lignes Swift |
| --- | --- |
| `Board.swift` (génération et légalité des coups) | 730 |
| `Parsers/PGNParser/` (4 fichiers) | 922 |
| `MoveTree/MoveTree.swift` (arbre de variantes) | 430 |
| `Game.swift` | 407 |
| `Bitboards/` (Attacks, PieceSet, Bitboard) | 669 |
| `Parsers/SANParser.swift` | 265 |
| `Move.swift` | 163 |
| `Parsers/EngineLANParser.swift` | 123 |
| **total** | **3 709** |

**Attention à ne pas extrapoler le ratio de cette tranche.** Les 288 lignes de
Kotlin en remplacent environ 800 de Swift, mais cette compression tient presque
entièrement aux deux `switch` de 64 branches de `Square`, qui deviennent deux
lignes d'arithmétique. `Board`, `PGNParser` et `MoveTree` sont de la logique
dense, qui se traduit à peu près une ligne pour une.

L'estimation honnête pour la couche complète est donc de l'ordre de **2 500 à
3 500 lignes de Kotlin**, avec les 128 tests de ChessKit comme recette et le
corpus de puzzles comme filet.

Ce n'est plus une inconnue. C'est un lot de travail chiffré.

## Rejouer

```bash
./gradlew test
```

Prérequis : JDK 21 (`/opt/homebrew/opt/openjdk@21`). Aucun SDK Android, aucun
émulateur. Le corpus est lu dans `ChessLab/Resources/lichess_puzzles.json`.
