# Spike Règles — la couche d'échecs en Kotlin

Volet D du dérisquage du portage Android (voir `tools/android-spike/`).
Il ne porte pas sur une conversion de modèle mais sur la **dépendance la plus
transversale de l'app** : `ChessKit`, importé par 126 des 443 fichiers Swift.

**État : les règles du jeu ET la notation sont portées et prouvées.** Perft
exact sur cinq positions de référence, 416 520 coups de vraies parties rejoués
sans un refus, et autant de notations moteur comparées à celles de Lichess.

Au passage, le corpus a révélé **trois bugs dans ChessKit lui-même**, dont un
qui affecte l'app iOS aujourd'hui — voir « Trois bugs d'amont » plus bas.

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

## Ce qui est porté

| Kotlin | lignes | rôle |
| --- | --- | --- |
| `Board.kt` | 349 | légalité des coups, échec, mat, nulles |
| `Attacks.kt` | 157 | tables d'attaques et bitboards magiques |
| `PieceSet.kt` | 142 | les douze bitboards de pièces |
| `Position.kt` | 130 | position, pendule, roques, matériel insuffisant |
| `Castling.kt` | 102 | roque, prise en passant, pendule |
| `FenParser.kt` | 95 | lecture et écriture du FEN |
| `Square.kt` | 88 | case, colonne, rangée |
| `Bitboard.kt` | 52 | translations sur la grille 8×8 |
| `SanParser.kt` | 160 | notation abrégée, celle qui s'affiche |
| `EngineLanParser.kt` | 60 | notation longue des moteurs UCI |
| `Piece.kt` / `Move.kt` | 94 | pièce, coup, annotations |
| **total** | **1 423** | |

Reste de ChessKit : `MoveTree`, `Game` et `PGNParser` — l'arbre de variantes
et le format de partie, ni les règles ni la notation.

## Ce que ça prouve

Cinq tests, 19 cas, **8 secondes**, sur la JVM, sans SDK Android ni émulateur.

### Les tests de ChessKit, repris un pour un

`SquareTest` et `FenParserTest` sont la traduction directe de `SquareTests.swift`
et `FENParserTests.swift`. C'est tout l'intérêt de porter la bibliothèque
plutôt que d'en adopter une autre : sa recette vient avec.

### Perft — le juge de paix de la génération de coups

| Position | Profondeur | Feuilles attendues | Résultat |
| --- | --- | --- | --- |
| Position initiale | 4 | 197 281 | ✅ |
| Kiwipete (roques, clouages) | 3 | 97 862 | ✅ |
| Finale avec prise en passant | 4 | 43 238 | ✅ |
| Promotions multiples | 3 | 9 467 | ✅ |
| Milieu de jeu tactique | 3 | 62 379 | ✅ |

Exact du premier coup, sur les cinq. Perft ne vérifie pas seulement qu'on
accepte les coups légaux : il vérifie qu'on n'en invente aucun et qu'on n'en
oublie aucun. C'est ce qui attrape les erreurs de clouage, de roque au travers
d'un échec ou de prise en passant.

### Le corpus réel

> corpus : 106094 positions, 106094 lues, 0 écart(s) relevé(s)
>
> puzzles : 106094 examinés, **416520 coups joués** (dont 3054 promotions),
> **416520 LAN comparés à Lichess**, 41616 aller-retours SAN, **0 écart**

Trois épreuves sur les mêmes données, dont une à **vérité terrain** :

1. aller-retour FEN sur les 106 094 positions embarquées par l'app ;
2. toutes les solutions de tous les puzzles rejouées sur le plateau porté ;
3. la notation moteur de chaque coup comparée à celle écrite par Lichess —
   ce n'est plus de la cohérence interne, c'est un arbitre extérieur ;
4. et un puzzle sur dix en aller-retour SAN : ce qu'on écrit doit se relire et
   rendre le même coup.

Aucune de ces positions n'a été choisie pour arranger le portage.

## Trois bugs d'amont

Le corpus n'a trouvé **aucune erreur de traduction**. Il a trouvé trois bugs
dans ChessKit, fidèlement reproduits par le port, puis corrigés :

1. **`O-O+` était rejeté.** Le motif de validation oublie `[+#]?` sur la
   branche du roque, alors que le motif du roque l'accepte. Un roque donnant
   échec était donc illisible.
2. **La désambiguïsation était perdue sur les prises.** Le motif n'autorise
   pas le `x` entre l'indication et la case d'arrivée : « R4xf3 » perdait son
   « 4 » et se relisait sur la mauvaise tour.
3. **Un SAN ambigu pouvait être écrit.** `disambiguate` interroge les pièces
   concurrentes sur la position d'AVANT le coup, mais leur validation se fait
   contre la position COURANTE — déjà modifiée. La case libérée ouvre une
   ligne, la pièce concurrente passe pour clouée, et le coup sort sans
   indication. Sur `4r1k1/p4p1p/2p2p2/1pb2B2/3RP3/4R3/PP4PP/6K1 w`, les deux
   tours peuvent aller en d3 et ChessKit écrit « Rd3 ».

**Le troisième touche l'app iOS aujourd'hui** : `PGNExport` délègue à
`Game`, dont la sérialisation écrit `move.san` (`PGNParser.swift:132`). Un PGN
exporté depuis ChessLab peut donc contenir un coup que personne ne saura
relire — y compris ChessLab. À traiter côté Swift, indépendamment d'Android.

## Les écarts assumés

Quatre, tous documentés dans le code :

1. **La casse ne survit pas à la JVM.** `PieceSet` distingue les pièces par la
   casse — `k` le roi noir, `K` le roi blanc. Impossible en Kotlin : les deux
   produisent le même accesseur `getK()` et le compilateur refuse
   (« platform declaration clash »). Les douze champs sont renommés. Type
   interne, aucune API appelante n'en dépend.
2. **`and` et `or` n'ont pas la priorité de `&` et `|`.** En Swift `&` lie plus
   fort que `|` ; en Kotlin ce sont deux fonctions infixes de même priorité,
   évaluées de gauche à droite. Toute expression de bitboard recopiée telle
   quelle serait fausse **en silence**. Elles sont re-parenthésées.
3. **La répétition n'est plus indexée par un hachage.** L'original compte les
   positions dans un dictionnaire indexé par `hashValue` : deux positions
   différentes en collision y comptent comme une répétition, donc comme une
   nulle. On indexe la clé elle-même. C'est le seul endroit où le port
   corrige sciemment l'original.
4. **Les `switch` de 64 branches de `Square` deviennent de l'arithmétique**
   sur l'ordinal, et `Rank` définit `equals`/`hashCode` à la main — une
   `data class` comparerait la valeur demandée et non la valeur bornée.

## Ce qu'il resterait à porter

| Fichier ChessKit | lignes Swift |
| --- | --- |
| `Parsers/PGNParser/` (4 fichiers, dont 270 dépréciées) | 922 |
| `MoveTree/MoveTree.swift` (arbre de variantes) | 430 |
| `Game.swift` | 407 |
| **total** | **1 759** |

Les règles ET la notation sont faites. Il ne reste que l'arbre de variantes et
le format de partie — de la structure de données et de l'analyse lexicale, sans
règle du jeu. À vue de nez, 800 à 1 200 lignes de Kotlin.

## Rejouer

```bash
./gradlew test
```

Prérequis : JDK 21 (`/opt/homebrew/opt/openjdk@21`). Aucun SDK Android, aucun
émulateur. Le corpus est lu dans `ChessLab/Resources/lichess_puzzles.json`.
