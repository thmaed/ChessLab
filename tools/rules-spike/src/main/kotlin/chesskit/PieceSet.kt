package chesskit

/**
 * Traduction Kotlin de `PieceSet.swift` (ChessKit, MIT).
 *
 * **Renommage obligatoire.** L'original distingue les pièces par la CASSE :
 * `k` le roi noir, `K` le roi blanc. Impossible sur la JVM, où les deux
 * donneraient le même accesseur `getK()` — le compilateur refuse
 * (« platform declaration clash »). Les douze champs sont donc nommés
 * explicitement. C'est un type interne à la bibliothèque, aucune API
 * appelante n'en dépend.
 *
 * `data class` avec douze champs `ULong` : `copy()` est donc une vraie copie,
 * ce qui rend la sémantique de valeur du `struct` Swift. C'est indispensable —
 * `Board.validate` travaille sur un jeu d'essai, et un partage de référence
 * corromprait la position réelle.
 */
data class PieceSet(
    var bKing: Bitboard = 0uL, var bQueen: Bitboard = 0uL, var bRook: Bitboard = 0uL,
    var bBishop: Bitboard = 0uL, var bKnight: Bitboard = 0uL, var bPawn: Bitboard = 0uL,
    var wKing: Bitboard = 0uL, var wQueen: Bitboard = 0uL, var wRook: Bitboard = 0uL,
    var wBishop: Bitboard = 0uL, var wKnight: Bitboard = 0uL, var wPawn: Bitboard = 0uL,
) {
    constructor(pieces: List<Piece>) : this() {
        pieces.forEach { add(it) }
    }

    val black: Bitboard get() = bKing or bQueen or bRook or bBishop or bKnight or bPawn
    val white: Bitboard get() = wKing or wQueen or wRook or wBishop or wKnight or wPawn
    val all: Bitboard get() = black or white

    val kings: Bitboard get() = bKing or wKing
    val queens: Bitboard get() = bQueen or wQueen
    val rooks: Bitboard get() = bRook or wRook
    val bishops: Bitboard get() = bBishop or wBishop
    val knights: Bitboard get() = bKnight or wKnight
    val pawns: Bitboard get() = bPawn or wPawn

    val diagonals: Bitboard get() = wQueen or bQueen or wBishop or bBishop
    val lines: Bitboard get() = wQueen or bQueen or wRook or bRook

    val pieces: List<Piece>
        get() = buildList {
            addAll(bKing.squares.map { Piece(Piece.Kind.king, Piece.Color.black, it) })
            addAll(bQueen.squares.map { Piece(Piece.Kind.queen, Piece.Color.black, it) })
            addAll(bRook.squares.map { Piece(Piece.Kind.rook, Piece.Color.black, it) })
            addAll(bBishop.squares.map { Piece(Piece.Kind.bishop, Piece.Color.black, it) })
            addAll(bKnight.squares.map { Piece(Piece.Kind.knight, Piece.Color.black, it) })
            addAll(bPawn.squares.map { Piece(Piece.Kind.pawn, Piece.Color.black, it) })
            addAll(wKing.squares.map { Piece(Piece.Kind.king, Piece.Color.white, it) })
            addAll(wQueen.squares.map { Piece(Piece.Kind.queen, Piece.Color.white, it) })
            addAll(wRook.squares.map { Piece(Piece.Kind.rook, Piece.Color.white, it) })
            addAll(wBishop.squares.map { Piece(Piece.Kind.bishop, Piece.Color.white, it) })
            addAll(wKnight.squares.map { Piece(Piece.Kind.knight, Piece.Color.white, it) })
            addAll(wPawn.squares.map { Piece(Piece.Kind.pawn, Piece.Color.white, it) })
        }

    fun get(color: Piece.Color): Bitboard = if (color == Piece.Color.white) white else black

    fun get(kind: Piece.Kind): Bitboard = when (kind) {
        Piece.Kind.pawn -> pawns
        Piece.Kind.knight -> knights
        Piece.Kind.bishop -> bishops
        Piece.Kind.rook -> rooks
        Piece.Kind.queen -> queens
        Piece.Kind.king -> kings
    }

    fun get(square: Square): Piece? {
        val s = square.bb
        return when {
            bKing and s != 0uL -> Piece(Piece.Kind.king, Piece.Color.black, square)
            bQueen and s != 0uL -> Piece(Piece.Kind.queen, Piece.Color.black, square)
            bRook and s != 0uL -> Piece(Piece.Kind.rook, Piece.Color.black, square)
            bBishop and s != 0uL -> Piece(Piece.Kind.bishop, Piece.Color.black, square)
            bKnight and s != 0uL -> Piece(Piece.Kind.knight, Piece.Color.black, square)
            bPawn and s != 0uL -> Piece(Piece.Kind.pawn, Piece.Color.black, square)
            wKing and s != 0uL -> Piece(Piece.Kind.king, Piece.Color.white, square)
            wQueen and s != 0uL -> Piece(Piece.Kind.queen, Piece.Color.white, square)
            wRook and s != 0uL -> Piece(Piece.Kind.rook, Piece.Color.white, square)
            wBishop and s != 0uL -> Piece(Piece.Kind.bishop, Piece.Color.white, square)
            wKnight and s != 0uL -> Piece(Piece.Kind.knight, Piece.Color.white, square)
            wPawn and s != 0uL -> Piece(Piece.Kind.pawn, Piece.Color.white, square)
            else -> null
        }
    }

    fun add(piece: Piece, to: Square = piece.square) {
        val s = to.bb
        when (piece.color) {
            Piece.Color.black -> when (piece.kind) {
                Piece.Kind.king -> bKing = bKing or s
                Piece.Kind.queen -> bQueen = bQueen or s
                Piece.Kind.rook -> bRook = bRook or s
                Piece.Kind.bishop -> bBishop = bBishop or s
                Piece.Kind.knight -> bKnight = bKnight or s
                Piece.Kind.pawn -> bPawn = bPawn or s
            }
            Piece.Color.white -> when (piece.kind) {
                Piece.Kind.king -> wKing = wKing or s
                Piece.Kind.queen -> wQueen = wQueen or s
                Piece.Kind.rook -> wRook = wRook or s
                Piece.Kind.bishop -> wBishop = wBishop or s
                Piece.Kind.knight -> wKnight = wKnight or s
                Piece.Kind.pawn -> wPawn = wPawn or s
            }
        }
    }

    fun remove(piece: Piece) {
        val s = piece.square.bb.inv()
        when (piece.color) {
            Piece.Color.black -> when (piece.kind) {
                Piece.Kind.king -> bKing = bKing and s
                Piece.Kind.queen -> bQueen = bQueen and s
                Piece.Kind.rook -> bRook = bRook and s
                Piece.Kind.bishop -> bBishop = bBishop and s
                Piece.Kind.knight -> bKnight = bKnight and s
                Piece.Kind.pawn -> bPawn = bPawn and s
            }
            Piece.Color.white -> when (piece.kind) {
                Piece.Kind.king -> wKing = wKing and s
                Piece.Kind.queen -> wQueen = wQueen and s
                Piece.Kind.rook -> wRook = wRook and s
                Piece.Kind.bishop -> wBishop = wBishop and s
                Piece.Kind.knight -> wKnight = wKnight and s
                Piece.Kind.pawn -> wPawn = wPawn and s
            }
        }
    }

    /** Remplace le type d'une pièce — la promotion. */
    fun replace(kind: Piece.Kind, piece: Piece) {
        remove(piece)
        add(piece.copy(kind = kind))
    }

    fun move(piece: Piece, to: Square) {
        remove(piece)
        add(piece, to)
    }
}
