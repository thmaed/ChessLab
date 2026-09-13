package com.chesslab.variants

import chesskit.Castling
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import kotlin.math.abs

/**
 * Les règles du Duck Chess, calculées EN KOTLIN — la seule variante du hub
 * dans ce cas, et elle n'avait pas le choix. Pendant de `DuckChessRules.swift`.
 *
 * ## Pourquoi pas le moteur
 *
 * Fairy-Stockfish ignore cette variante, et rien dans la version embarquée ne
 * permet de la décrire : aucun mécanisme de case bloquée. S'ajoute une
 * impossibilité de fond : un coup y est DEUX actions — déplacer une pièce,
 * puis poser le canard sur une case vide — ce que le protocole UCI ne sait pas
 * exprimer, et dont le nombre de combinaisons (coups légaux × cases vides)
 * rendrait la recherche absurde.
 *
 * ## Ce qui change par rapport aux échecs
 *
 * - Le canard occupe une case et la **bloque totalement** : aucune pièce ne
 *   peut s'y poser ni la traverser. Il ne se capture pas, et n'appartient à
 *   personne.
 * - Il n'y a **ni échec, ni mat, ni pat**. Un roi a le droit de se mettre en
 *   prise et d'y rester. On gagne en **capturant le roi**. C'est pourquoi les
 *   coups légaux de `chesskit` ne conviennent pas ici : il les filtre
 *   justement sur l'échec. Ce fichier engendre donc lui-même les coups,
 *   pseudo-légaux au sens classique.
 * - Le roque suit les règles habituelles de cases vides et de droits, mais
 *   sans la contrainte d'échec — et le canard bloque comme n'importe quoi
 *   d'autre.
 */
object DuckChessRules {

    data class Move(val from: Square, val to: Square, val promotion: Piece.Kind? = null) {
        val uci: String
            get() = from.notation + to.notation + when (promotion) {
                Piece.Kind.queen -> "q"
                Piece.Kind.rook -> "r"
                Piece.Kind.bishop -> "b"
                Piece.Kind.knight -> "n"
                else -> ""
            }
    }

    val allSquares: List<Square> = Square.entries.toList()

    /**
     * Tous les coups jouables par le camp au trait, canard compris.
     *
     * [duck] : la case du canard, `null` au tout premier coup de la partie —
     * il n'est pas encore posé.
     */
    fun moves(position: Position, duck: Square?, enPassant: Square? = null): List<Move> {
        val mover = position.sideToMove
        val result = ArrayList<Move>()
        for (piece in position.pieces) {
            if (piece.color == mover) result += movesFor(piece, position, duck, enPassant)
        }
        return result
    }

    /**
     * Cases où le canard peut se poser : toutes les cases vides, sauf celle
     * qu'il occupe déjà — il DOIT bouger à chaque tour.
     */
    fun duckTargets(position: Position, currentDuck: Square?): List<Square> =
        allSquares.filter { position.piece(it) == null && it != currentDuck }

    /** Le coup capture-t-il un roi ? C'est la seule fin de partie. */
    fun capturesKing(move: Move, position: Position): Piece.Color? {
        val captured = position.piece(move.to) ?: return null
        return if (captured.kind == Piece.Kind.king) captured.color else null
    }

    /**
     * La position est-elle légale **au sens des échecs ordinaires** ?
     *
     * Question posée du point de vue de Stockfish, qui conseille l'ordinateur
     * et ne connaît ni le canard ni cette variante. Une position de Duck Chess
     * est illégale pour lui dès que le roi du camp qui vient de jouer reste
     * attaqué — ce qui est ici parfaitement normal, l'échec n'existant pas.
     * Lui envoyer une telle position, c'est lui demander d'évaluer un
     * échiquier où le roi est prenable : il répond n'importe quoi, quand il ne
     * s'arrête pas.
     *
     * Le canard est délibérément IGNORÉ dans le calcul : il ne figure pas dans
     * la FEN transmise, donc il ne peut pas parer une attaque aux yeux du
     * moteur, même quand il la pare vraiment sur le plateau.
     */
    fun isStandardLegal(position: Position): Boolean {
        val kings = position.pieces.filter { it.kind == Piece.Kind.king }
        if (kings.none { it.color == Piece.Color.white } || kings.none { it.color == Piece.Color.black }) return false
        return moves(position, duck = null).none { capturesKing(it, position) != null }
    }

    /**
     * Cases TRAVERSÉES entre deux cases alignées, bornes exclues — vide si
     * elles ne sont ni sur une ligne, ni sur une colonne, ni sur une diagonale
     * (un saut de cavalier ne traverse rien).
     *
     * Sert à poser le canard SUR le chemin d'un coup adverse plutôt que sur sa
     * seule case d'arrivée.
     */
    fun pathBetween(from: Square, to: Square): List<Square> {
        val deltaFile = to.file.number - from.file.number
        val deltaRank = to.rank.value - from.rank.value
        if (deltaFile != 0 && deltaRank != 0 && abs(deltaFile) != abs(deltaRank)) return emptyList()
        val stepFile = if (deltaFile == 0) 0 else deltaFile / abs(deltaFile)
        val stepRank = if (deltaRank == 0) 0 else deltaRank / abs(deltaRank)
        val result = ArrayList<Square>()
        var file = from.file.number + stepFile
        var rank = from.rank.value + stepRank
        while (true) {
            val square = square(file, rank) ?: break
            if (square == to) break
            result += square
            file += stepFile
            rank += stepRank
        }
        return result
    }

    // MARK: Génération par pièce

    private fun movesFor(piece: Piece, position: Position, duck: Square?, enPassant: Square?): List<Move> {
        val from = piece.square
        val file = from.file.number
        val rank = from.rank.value

        return when (piece.kind) {
            Piece.Kind.pawn -> pawnMoves(piece, file, rank, position, duck, enPassant)
            Piece.Kind.knight -> jumps.mapNotNull { (df, dr) ->
                val to = square(file + df, rank + dr) ?: return@mapNotNull null
                if (!isLandable(to, piece.color, position, duck)) null else Move(from, to)
            }
            Piece.Kind.bishop -> slide(from, piece.color, diagonals, position, duck)
            Piece.Kind.rook -> slide(from, piece.color, straights, position, duck)
            Piece.Kind.queen -> slide(from, piece.color, diagonals + straights, position, duck)
            Piece.Kind.king -> (diagonals + straights).mapNotNull { (df, dr) ->
                val to = square(file + df, rank + dr) ?: return@mapNotNull null
                if (!isLandable(to, piece.color, position, duck)) null else Move(from, to)
            } + castles(piece, position, duck)
        }
    }

    private fun pawnMoves(
        piece: Piece, file: Int, rank: Int, position: Position, duck: Square?, enPassant: Square?,
    ): List<Move> {
        val white = piece.color == Piece.Color.white
        val forward = if (white) 1 else -1
        val startRank = if (white) 2 else 7
        val lastRank = if (white) 8 else 1
        val from = piece.square
        val moves = ArrayList<Move>()

        fun add(to: Square) {
            if (to.rank.value == lastRank) {
                for (kind in listOf(Piece.Kind.queen, Piece.Kind.rook, Piece.Kind.bishop, Piece.Kind.knight)) {
                    moves += Move(from, to, kind)
                }
            } else {
                moves += Move(from, to)
            }
        }

        // Poussée simple, puis double — l'une comme l'autre exige une case
        // LIBRE, et le canard occupe une case comme n'importe quelle pièce.
        val one = square(file, rank + forward)
        if (one != null && isEmpty(one, position, duck)) {
            add(one)
            val two = square(file, rank + 2 * forward)
            if (rank == startRank && two != null && isEmpty(two, position, duck)) moves += Move(from, two)
        }
        // Prises en diagonale : sur une pièce adverse, ou en passant. JAMAIS
        // sur le canard, qui ne se capture pas.
        for (side in listOf(-1, 1)) {
            val to = square(file + side, rank + forward) ?: continue
            if (to == duck) continue
            val target = position.piece(to)
            if (target != null && target.color != piece.color) add(to)
            else if (target == null && enPassant != null && to == enPassant) moves += Move(from, to)
        }
        return moves
    }

    private fun castles(king: Piece, position: Position, duck: Square?): List<Move> {
        val white = king.color == Piece.Color.white
        val rank = if (white) 1 else 8
        if (king.square != square(5, rank)) return emptyList()
        val moves = ArrayList<Move>()

        // Petit roque : f et g libres. Grand roque : b, c et d libres.
        val plans = listOf(
            Triple(if (white) Castling.wK else Castling.bK, listOf(6, 7), 7),
            Triple(if (white) Castling.wQ else Castling.bQ, listOf(2, 3, 4), 3),
        )
        for ((right, empties, kingTo) in plans) {
            if (right !in position.legalCastlings) continue
            val squares = empties.mapNotNull { square(it, rank) }
            if (squares.size != empties.size) continue
            if (!squares.all { isEmpty(it, position, duck) }) continue
            val to = square(kingTo, rank) ?: continue
            // Aucune vérification d'échec : en Duck Chess, le roi peut roquer
            // à travers une case attaquée, et même « en échec » — la notion
            // n'existe pas.
            moves += Move(king.square, to)
        }
        return moves
    }

    private fun slide(
        from: Square, color: Piece.Color, directions: List<Pair<Int, Int>>, position: Position, duck: Square?,
    ): List<Move> {
        val moves = ArrayList<Move>()
        for ((df, dr) in directions) {
            var file = from.file.number + df
            var rank = from.rank.value + dr
            while (true) {
                val to = square(file, rank) ?: break
                // Le canard ARRÊTE la ligne sans pouvoir être pris : c'est ce
                // qui le distingue d'une pièce adverse.
                if (to == duck) break
                val occupant = position.piece(to)
                if (occupant != null) {
                    if (occupant.color != color) moves += Move(from, to)
                    break
                }
                moves += Move(from, to)
                file += df
                rank += dr
            }
        }
        return moves
    }

    // MARK: Outils

    private val diagonals = listOf(1 to 1, 1 to -1, -1 to -1, -1 to 1)
    private val straights = listOf(0 to 1, 1 to 0, 0 to -1, -1 to 0)
    private val jumps = listOf(1 to 2, 2 to 1, 2 to -1, 1 to -2, -1 to -2, -2 to -1, -2 to 1, -1 to 2)

    /**
     * La case, ou `null` hors du plateau. `Square(File, Rank)` RAMÈNE toute
     * valeur hors bornes dans le plateau : s'en servir sans ce garde ferait
     * déborder un cavalier de la colonne h à la colonne a.
     */
    fun square(file: Int, rank: Int): Square? {
        if (file !in 1..8 || rank !in 1..8) return null
        return Square(Square.File(file), Square.Rank(rank))
    }

    private fun isEmpty(square: Square, position: Position, duck: Square?): Boolean =
        position.piece(square) == null && square != duck

    /** Une case est atteignable si le canard n'y est pas et qu'elle ne porte pas une pièce AMIE. */
    private fun isLandable(square: Square, color: Piece.Color, position: Position, duck: Square?): Boolean {
        if (square == duck) return false
        val occupant = position.piece(square) ?: return true
        return occupant.color != color
    }
}
