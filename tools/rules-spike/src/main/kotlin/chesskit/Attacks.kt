package chesskit

/**
 * Traduction Kotlin de `Attacks.swift` (ChessKit, MIT).
 *
 * Tables d'attaques pré-calculées. Un seul écart : là où l'original indexe des
 * dictionnaires par `Square.bb`, on indexe des tableaux par l'ordinal de la
 * case — c'est la même information, sans hachage.
 *
 * Les nombres magiques sont ceux de l'original (dérivés par Pradyumna Kannan) ;
 * la génération suit la technique « Carry-Rippler » de Stockfish.
 */
object Attacks {

    private var initialized = false

    private val kingTable = ULongArray(64)
    private val knightTable = ULongArray(64)
    private lateinit var rookMagics: Array<Magic>
    private lateinit var bishopMagics: Array<Magic>

    @Synchronized
    fun create() {
        if (initialized) return
        createKingAttacks()
        createKnightAttacks()
        rookMagics = createMagics(Sliding.rook)
        bishopMagics = createMagics(Sliding.bishop)
        initialized = true
    }

    fun king(square: Square): Bitboard = kingTable[square.ordinal]
    fun knight(square: Square): Bitboard = knightTable[square.ordinal]
    fun rook(square: Square, occupancy: Bitboard): Bitboard = rookMagics[square.ordinal].attacks(occupancy)
    fun bishop(square: Square, occupancy: Bitboard): Bitboard = bishopMagics[square.ordinal].attacks(occupancy)
    fun queen(square: Square, occupancy: Bitboard): Bitboard = rook(square, occupancy) or bishop(square, occupancy)

    private fun createKingAttacks() {
        for (square in Square.entries) {
            val sq = square.bb
            var attacks = sq.east() or sq.west()
            val horizontal = sq or attacks
            attacks = attacks or horizontal.north() or horizontal.south()
            kingTable[square.ordinal] = attacks
        }
    }

    private fun createKnightAttacks() {
        for (square in Square.entries) {
            val sq = square.bb
            var result: Bitboard = 0uL
            for (shift in intArrayOf(17, 15, 10, 6)) {
                val up = sq shl shift
                if (distance(sq, up) <= 2) result = result or up
                val down = sq shr shift
                if (distance(sq, down) <= 2) result = result or down
            }
            knightTable[square.ordinal] = result
        }
    }

    /** Distance de Tchebychev ; `Int.MAX_VALUE` si l'une des cases est hors plateau. */
    private fun distance(sq1: Bitboard, sq2: Bitboard): Int {
        val s1 = squareOf(sq1) ?: return Int.MAX_VALUE
        val s2 = squareOf(sq2) ?: return Int.MAX_VALUE
        return maxOf(
            kotlin.math.abs(s1.file.number - s2.file.number),
            kotlin.math.abs(s1.rank.value - s2.rank.value),
        )
    }

    private enum class Sliding { rook, bishop }

    private fun createMagics(kind: Sliding): Array<Magic> = Array(64) { index ->
        val sq = Square.entries[index]
        // bords du plateau, la case courante exclue
        val edges = ((BB.RANK_1 or BB.RANK_8) and sq.rank.bb.inv()) or
            ((BB.A_FILE or BB.H_FILE) and sq.file.bb.inv())

        val m = Magic(
            magic = if (kind == Sliding.rook) rookMagicNumbers[index] else bishopMagicNumbers[index],
            mask = slidingAttacks(kind, sq, 0uL) and edges.inv(),
        )

        // Carry-Rippler : énumère tous les sous-ensembles du masque, c'est-à-dire
        // toutes les configurations de pièces bloquantes possibles.
        var subset: Bitboard = 0uL
        do {
            m.table[m.key(subset)] = slidingAttacks(kind, sq, subset)
            subset = (subset - m.mask) and m.mask
        } while (subset != 0uL)

        m
    }

    private fun slidingAttacks(kind: Sliding, square: Square, occupancy: Bitboard): Bitboard {
        val directions: List<(Bitboard) -> Bitboard> = when (kind) {
            Sliding.rook -> listOf({ b: Bitboard -> b.north() }, { b -> b.south() }, { b -> b.east() }, { b -> b.west() })
            Sliding.bishop -> listOf({ b: Bitboard -> b.northEast() }, { b -> b.northWest() }, { b -> b.southEast() }, { b -> b.southWest() })
        }

        var attacks: Bitboard = 0uL
        for (d in directions) {
            var next = square.bb
            do {
                next = d(next)
                attacks = attacks or next
            } while (next != 0uL && (occupancy and next) == 0uL)
        }
        return attacks
    }

    private class Magic(val magic: Bitboard, val mask: Bitboard) {
        private val shift: Int = 64 - mask.oneBits()
        val table = HashMap<Bitboard, Bitboard>()
        fun key(subset: Bitboard): Bitboard = (subset * magic) shr shift
        fun attacks(occupancy: Bitboard): Bitboard = table[key(occupancy and mask)] ?: 0uL
    }

    private val bishopMagicNumbers = ulongArrayOf(
        0x0002020202020200uL, 0x0002020202020000uL, 0x0004010202000000uL, 0x0004040080000000uL,
        0x0001104000000000uL, 0x0000821040000000uL, 0x0000410410400000uL, 0x0000104104104000uL,
        0x0000040404040400uL, 0x0000020202020200uL, 0x0000040102020000uL, 0x0000040400800000uL,
        0x0000011040000000uL, 0x0000008210400000uL, 0x0000004104104000uL, 0x0000002082082000uL,
        0x0004000808080800uL, 0x0002000404040400uL, 0x0001000202020200uL, 0x0000800802004000uL,
        0x0000800400A00000uL, 0x0000200100884000uL, 0x0000400082082000uL, 0x0000200041041000uL,
        0x0002080010101000uL, 0x0001040008080800uL, 0x0000208004010400uL, 0x0000404004010200uL,
        0x0000840000802000uL, 0x0000404002011000uL, 0x0000808001041000uL, 0x0000404000820800uL,
        0x0001041000202000uL, 0x0000820800101000uL, 0x0000104400080800uL, 0x0000020080080080uL,
        0x0000404040040100uL, 0x0000808100020100uL, 0x0001010100020800uL, 0x0000808080010400uL,
        0x0000820820004000uL, 0x0000410410002000uL, 0x0000082088001000uL, 0x0000002011000800uL,
        0x0000080100400400uL, 0x0001010101000200uL, 0x0002020202000400uL, 0x0001010101000200uL,
        0x0000410410400000uL, 0x0000208208200000uL, 0x0000002084100000uL, 0x0000000020880000uL,
        0x0000001002020000uL, 0x0000040408020000uL, 0x0004040404040000uL, 0x0002020202020000uL,
        0x0000104104104000uL, 0x0000002082082000uL, 0x0000000020841000uL, 0x0000000000208800uL,
        0x0000000010020200uL, 0x0000000404080200uL, 0x0000040404040400uL, 0x0002020202020200uL,
    )

    private val rookMagicNumbers = ulongArrayOf(
        0x0080001020400080uL, 0x0040001000200040uL, 0x0080081000200080uL, 0x0080040800100080uL,
        0x0080020400080080uL, 0x0080010200040080uL, 0x0080008001000200uL, 0x0080002040800100uL,
        0x0000800020400080uL, 0x0000400020005000uL, 0x0000801000200080uL, 0x0000800800100080uL,
        0x0000800400080080uL, 0x0000800200040080uL, 0x0000800100020080uL, 0x0000800040800100uL,
        0x0000208000400080uL, 0x0000404000201000uL, 0x0000808010002000uL, 0x0000808008001000uL,
        0x0000808004000800uL, 0x0000808002000400uL, 0x0000010100020004uL, 0x0000020000408104uL,
        0x0000208080004000uL, 0x0000200040005000uL, 0x0000100080200080uL, 0x0000080080100080uL,
        0x0000040080080080uL, 0x0000020080040080uL, 0x0000010080800200uL, 0x0000800080004100uL,
        0x0000204000800080uL, 0x0000200040401000uL, 0x0000100080802000uL, 0x0000080080801000uL,
        0x0000040080800800uL, 0x0000020080800400uL, 0x0000020001010004uL, 0x0000800040800100uL,
        0x0000204000808000uL, 0x0000200040008080uL, 0x0000100020008080uL, 0x0000080010008080uL,
        0x0000040008008080uL, 0x0000020004008080uL, 0x0000010002008080uL, 0x0000004081020004uL,
        0x0000204000800080uL, 0x0000200040008080uL, 0x0000100020008080uL, 0x0000080010008080uL,
        0x0000040008008080uL, 0x0000020004008080uL, 0x0000800100020080uL, 0x0000800041000080uL,
        0x00FFFCDDFCED714AuL, 0x007FFCDDFCED714AuL, 0x003FFFCDFFD88096uL, 0x0000040810002101uL,
        0x0001000204080011uL, 0x0001000204000801uL, 0x0001000082000401uL, 0x0001FFFAABFAD1A2uL,
    )
}
