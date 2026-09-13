package com.chesslab.variants

import chesskit.FenParser
import chesskit.Square
import kotlin.random.Random

/**
 * Barricades : les échecs ordinaires, avec des cases MURÉES.
 * Pendant de `BarricadesConfiguration.swift`.
 *
 * ## Le problème, et pourquoi ce fichier existe
 *
 * Fairy-Stockfish n'a aucune notion de case-mur : ni `wallingRule`, ni `*`
 * dans son parseur de FEN. Il a en revanche tout ce qu'il faut pour en
 * FABRIQUER une, et c'est ce que fait la définition écrite ci-dessous :
 *
 * - le type de pièce `immobile`, dont la notation Betza est vide — elle ne
 *   peut donc jouer aucun coup ;
 * - `mobilityRegion<Couleur><Pièce>`, qui restreint les cases d'ARRIVÉE d'un
 *   type de pièce, et interdit donc d'y capturer quoi que ce soit ;
 * - `pieceValueMg`/`pieceValueEg`, pour que les murs ne pèsent rien dans
 *   l'évaluation.
 *
 * Les murs sont BLANCS. Les Blancs ne peuvent donc pas les prendre — on ne
 * capture pas ses propres pièces — et il suffit de brider les six types de
 * pièces NOIRES pour que personne ne le puisse.
 *
 * Le blocage des pièces glissantes ne vient PAS de `mobilityRegion`, qui n'est
 * qu'un masque d'arrivée : il vient de l'occupation. Un mur est une pièce,
 * donc il arrête une ligne comme n'importe quelle autre — et un cavalier lui
 * saute par-dessus, comme il saute par-dessus n'importe quoi.
 *
 * ## Une seule source de vérité
 *
 * [wallSquares] commande tout : la FEN de départ, les régions de mobilité, et
 * l'affichage du plateau.
 */
object BarricadesConfiguration {

    const val variantId = "barricades"

    /**
     * La variante SŒUR, où les murs se déplacent à chaque demi-coup.
     *
     * Elle ne peut pas se protéger comme la fixe : `mobilityRegion` est une
     * propriété STATIQUE de la variante, elle ne suit pas des murs qui
     * bougent. Les murs y restent donc capturables aux yeux du moteur, et
     * c'est la vue-modèle qui retire ces coups de la liste — une soustraction
     * d'une ligne, pas une réimplémentation des échecs.
     */
    const val randomVariantId = "randombarricades"

    /** Les cases murées de la variante FIXE. Le nom de la variante vient d'elles. */
    val wallSquares = listOf(Square("d4"), Square("e5"))

    /**
     * Position de départ : les échecs ordinaires, plus les deux murs. Écrite
     * en toutes lettres plutôt que dérivée — une FEN se relit, une
     * construction ne se relit pas. Un test vérifie que les deux disent bien
     * la même chose.
     */
    const val startFen = "rnbqkbnr/pppppppp/8/4W3/3W4/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    /**
     * Position de départ de la variante ALÉATOIRE : les échecs ordinaires.
     * Ses murs sont posés au premier coup, au hasard.
     */
    const val randomStartFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    /**
     * Rangées où un mur mobile a le droit de se poser. Ni la première ni la
     * dernière : un mur surgi sur la rangée de départ enfermerait une tour
     * dans son coin sans que personne y soit pour rien.
     */
    val randomWallRanks = 2..7

    /** Trois murs en tout, dont DEUX se redéploient à chaque demi-coup. */
    const val wallCount = 3

    private val restrictedPieces = listOf("Pawn", "Knight", "Bishop", "Rook", "Queen", "King")

    /**
     * Toutes les cases SAUF les murs, dans la syntaxe des bitboards du moteur :
     * `*n` pour une rangée entière, sinon case par case.
     */
    val openSquaresBitboard: String
        get() {
            val walls = wallSquares.toSet()
            val tokens = ArrayList<String>()
            for (rank in 1..8) {
                if (walls.none { it.rank.value == rank }) {
                    tokens += "*$rank"
                } else {
                    for (file in "abcdefgh") {
                        val square = Square("$file$rank")
                        if (square !in walls) tokens += square.notation
                    }
                }
            }
            return tokens.joinToString(" ")
        }

    /**
     * Le fichier de définition, tel que `VariantPath` l'attend — les DEUX
     * variantes dans un seul fichier, qu'un seul chargement suffit à
     * enseigner au moteur.
     */
    val configurationText: String
        get() {
            val wall = BarricadesFen.wallLetter.lowercaseChar()
            val lines = ArrayList<String>()
            lines += "# Barricades — engendré par BarricadesConfiguration, ne pas éditer à la main."
            lines += "[$variantId:chess]"
            lines += "immobile = $wall"
            lines += "startFen = $startFen"
            lines += "pieceValueMg = $wall:0"
            lines += "pieceValueEg = $wall:0"
            val open = openSquaresBitboard
            restrictedPieces.forEach { lines += "mobilityRegionBlack$it = $open" }
            // La variante ALÉATOIRE n'a PAS de `mobilityRegion` : ses murs se
            // déplacent, aucune région figée ne pourrait les suivre.
            lines += ""
            lines += "[$randomVariantId:chess]"
            lines += "immobile = $wall"
            lines += "startFen = $randomStartFen"
            lines += "pieceValueMg = $wall:0"
            lines += "pieceValueEg = $wall:0"
            return lines.joinToString("\n") + "\n"
        }

    /**
     * Redéploie DEUX des trois murs, tirés au sort ; le troisième reste où il
     * est — mais pas le même d'un coup à l'autre. C'est ce tirage-là, et non
     * un mur figé pour la partie, qui fait la variante : un mur immobile
     * donnerait un point d'appui permanent ; ici, le seul point d'appui dure
     * un coup, et on ne sait pas lequel ce sera.
     *
     * Rend `null` si la position est illisible ou s'il n'y a pas assez de
     * cases libres : la partie continue alors avec les murs qu'elle avait,
     * plutôt que de s'arrêter sur un détail.
     */
    fun relocatingWalls(fen: String, random: Random = Random.Default): String? {
        val cleared = BarricadesFen.forChessKit(fen)
        val position = FenParser.parse(cleared) ?: return null
        val current = BarricadesFen.wallSquares(fen)

        val staying = if (current.size >= wallCount) setOf(current.random(random)) else emptySet()
        val moving = wallCount - staying.size

        val forbidden = position.pieces.mapTo(HashSet()) { it.square } + current
        val candidates = allSquares.filter { it.rank.value in randomWallRanks && it !in forbidden }
        if (candidates.size < moving) return null

        val chosen = staying.toMutableSet()
        while (chosen.size < wallCount) chosen += candidates.random(random)
        return BarricadesFen.inserting(chosen, cleared)
    }

    /** La position d'ouverture : les trois murs posés au hasard. */
    fun openingPosition(random: Random = Random.Default): String =
        relocatingWalls(randomStartFen, random) ?: randomStartFen

    /**
     * Retire les coups qui PRENNENT un mur.
     *
     * Le moteur les propose : faute de `mobilityRegion` — impossible à figer
     * sur des murs mobiles — il voit des pièces blanches immobiles et sans
     * valeur, donc capturables. Les retirer ici est une soustraction sur une
     * liste que le moteur a produite ; tout le reste de la légalité (échec,
     * clouage, roque, prise en passant) reste la sienne, et reste juste.
     *
     * Si un camp n'avait plus QUE des prises de mur, il n'aurait réellement
     * aucun coup : rendre une liste vide est alors la bonne réponse, et la
     * partie se conclut sur un mat ou un pat comme il se doit.
     */
    fun removingWallCaptures(moves: List<String>, fen: String): List<String> {
        val walls = BarricadesFen.wallSquares(fen).mapTo(HashSet()) { it.notation }
        if (walls.isEmpty()) return moves
        return moves.filter { it.length < 4 || it.substring(2, 4) !in walls }
    }

    private val allSquares: List<Square> =
        (1..8).flatMap { rank -> "abcdefgh".map { file -> Square("$file$rank") } }
}
