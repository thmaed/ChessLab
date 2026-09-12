package com.chesslab.analysis

import android.content.Context
import chesskit.Board
import chesskit.Move
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.R

/**
 * Pourquoi un coup était mauvais — en une phrase vraie. Pendant de
 * `MoveExplanation.swift`.
 *
 * Le bandeau coach sait dire « e5 — Erreur, −12 % » : il sait donc COMBIEN un
 * coup coûte, et ne sait pas dire CE QUI le punit. L'utilisateur apprend qu'il
 * a eu tort, pas ce qu'il n'a pas vu, et rejouera le même coup.
 *
 * La réponse est lue sur la RÉFUTATION DU MOTEUR — la variante qu'il enchaîne
 * après le coup joué. Aucun modèle de langage n'entre ici : tout est rejoué sur
 * un plateau, donc rien ne peut être inventé.
 */
data class MoveExplanation(
    /** Le motif qui punit, quand il est nommable. `null` est fréquent. */
    val motif: TacticalMotif?,
    /** Matériel net perdu sur la réfutation, POV du joueur qui vient de jouer. */
    val materialLoss: Int?,
    /** Le premier coup de la réfutation, en SAN. */
    val refutationSan: String,
) {
    /**
     * La phrase, dans la langue active. Construite à la LECTURE et non à
     * l'analyse : un changement de langue doit la retraduire, pas la laisser
     * figée dans celle qui avait cours au moment du calcul.
     */
    fun sentence(context: Context): String {
        val san = refutationSan
        val motif = motif
            ?: return materialLoss?.let { context.getString(R.string.explain_material, san, it) } ?: ""

        var mentionsCost = true
        val head = when (motif) {
            is TacticalMotif.Checkmate -> {
                // Le matériel ne veut plus rien dire quand la ligne mate.
                mentionsCost = false
                when {
                    motif.inMoves <= 1 && motif.isBackRank -> context.getString(R.string.explain_back_rank, san)
                    motif.inMoves <= 1 -> context.getString(R.string.explain_mate, san)
                    motif.isBackRank -> context.getString(R.string.explain_back_rank_in, san, motif.inMoves)
                    else -> context.getString(R.string.explain_mate_in, san, motif.inMoves)
                }
            }
            is TacticalMotif.HangingPiece -> {
                // Le coût est le nom de la pièce : le répéter en points serait du bruit.
                mentionsCost = false
                context.getString(R.string.explain_hanging, san, kindName(context, motif.kind))
            }
            is TacticalMotif.Fork -> {
                // Deux cibles nommées suffisent — une fourchette triple se
                // raconte aussi bien par ses deux plus grosses prises.
                val named = motif.targets.take(2).map { kindName(context, it) }
                if (named.size == 2) context.getString(R.string.explain_fork_two, san, named[0], named[1])
                else context.getString(R.string.explain_fork, san)
            }
            // La pièce qui démasque n'est PAS nommée : la flèche sur le plateau
            // montre déjà laquelle, et l'accord de genre coûterait un gabarit
            // par pièce pour un gain nul.
            is TacticalMotif.DiscoveredCheck -> context.getString(R.string.explain_discovered, san)
            // Tournure NOMINALE (« clouage de votre… ») et non « votre tour est
            // clouée » : le participe s'accorderait en genre avec la pièce, ce
            // qu'un gabarit à trous ne sait pas faire.
            is TacticalMotif.Pin -> context.getString(
                R.string.explain_pin, san, kindName(context, motif.victim), kindName(context, motif.behind)
            )
        }

        val loss = materialLoss
        if (!mentionsCost || loss == null) return head
        return head + " " + context.getString(R.string.explain_cost, loss)
    }

    /**
     * Le nom de la pièce EN MINUSCULES : la phrase la met au milieu (« votre
     * tour était en prise »), pas en tête. `lowercase()` sans locale, donc
     * invariant — les deux langues de l'app s'en accommodent.
     */
    private fun kindName(context: Context, kind: Piece.Kind): String = context.getString(
        when (kind) {
            Piece.Kind.king -> R.string.piece_king
            Piece.Kind.queen -> R.string.piece_queen
            Piece.Kind.rook -> R.string.piece_rook
            Piece.Kind.bishop -> R.string.piece_bishop
            Piece.Kind.knight -> R.string.piece_knight
            Piece.Kind.pawn -> R.string.piece_pawn
        }
    ).lowercase()
}

/**
 * Fabrique l'explication d'un coup à partir de la réfutation du moteur.
 *
 * Entièrement PUR : une position, une liste de coups en LAN, et rien d'autre.
 * Aucune requête moteur n'est faite ici — la variante est déjà payée par la
 * classification. L'explication est donc gratuite en temps de calcul, ce qui
 * la rend acceptable sur une revue de quarante coups.
 */
object MoveExplainer {

    /**
     * Au-delà, la ligne ne raconte plus la faute mais la partie qui suit.
     * Six coups couvrent largement une tactique.
     */
    const val MAX_PLIES = 12

    /**
     * En deçà, la « perte » relève du bruit d'horizon : une variante coupée à
     * une profondeur arbitraire peut montrer un pion d'écart qui n'existe pas.
     */
    const val MINIMUM_MATERIAL_LOSS = 2

    /**
     * @param positionAfterMove position APRÈS le coup à expliquer —
     *   l'adversaire est au trait.
     * @param refutationLans variante principale du moteur à cette position.
     *   Son premier élément est la réponse de l'adversaire : la punition.
     *
     * Rend `null` quand la ligne ne dit rien d'exploitable : ni mat, ni motif,
     * ni perte matérielle nette. Mieux vaut se taire que meubler.
     */
    fun explain(positionAfterMove: Position, refutationLans: List<String>): MoveExplanation? {
        val board = Board(positionAfterMove)
        val mover = positionAfterMove.sideToMove.opposite
        val startingBalance = materialBalance(board.position, mover)

        val plies = mutableListOf<Move>()
        /**
         * Bilan matériel après chaque demi-coup, et si la position y est
         * « calme » — c'est-à-dire si rien ne peut reprendre sur la case
         * d'arrivée. Lire le matériel au milieu d'un échange donnerait un
         * chiffre faux dans un sens ou dans l'autre.
         */
        val balances = mutableListOf<Pair<Int, Boolean>>()
        var boardAfterFirstPly: Board? = null
        var mateInMoves: Int? = null

        for (lan in refutationLans.take(MAX_PLIES)) {
            val move = apply(lan, board) ?: break
            plies += move
            balances += materialBalance(board.position, mover) to !canRecapture(move.end, board)
            if (plies.size == 1) boardAfterFirstPly = Board(board.position.copy())

            val state = board.state
            if (state is Board.State.Checkmate) {
                // L'adversaire joue en premier dans la réfutation : il mate donc
                // aux demi-coups impairs (1, 3, 5…), soit (n + 1) / 2 coups.
                if (state.color == mover) mateInMoves = (plies.size + 1) / 2
                break
            }
        }

        val firstPly = plies.firstOrNull() ?: return null
        val afterFirst = boardAfterFirstPly ?: return null

        val motif = mateInMoves?.let {
            TacticalMotif.Checkmate(it, TacticalMotifDetector.isBackRankMate(mover, board))
        } ?: TacticalMotifDetector.detect(firstPly, afterFirst)

        // Le verdict matériel se lit au dernier point CALME de la ligne. Sans
        // ça, une variante tronquée juste après une prise annoncerait une perte
        // de dame que la reprise du demi-coup suivant aurait effacée.
        val settled = balances.lastOrNull { it.second } ?: balances.lastOrNull()
        val loss = settled?.let { startingBalance - it.first }
        val materialLoss = if ((loss ?: 0) >= MINIMUM_MATERIAL_LOSS) loss else null

        if (motif == null && materialLoss == null) return null
        return MoveExplanation(motif, materialLoss, firstPly.san)
    }

    /** Bilan matériel du point de vue de [color] (positif = il a plus de bois). */
    private fun materialBalance(position: Position, color: Piece.Color): Int =
        position.pieces.sumOf { if (it.color == color) pieceValue(it.kind) else -pieceValue(it.kind) }

    /**
     * Un camp peut-il reprendre sur [square] ? La case porte la pièce qui vient
     * d'arriver, donc tout coup vers elle est une prise.
     */
    private fun canRecapture(square: Square, board: Board): Boolean =
        board.position.pieces
            .filter { it.color == board.position.sideToMove }
            .any { board.canMove(it.square, square) }

    /** Applique un coup en LAN (« e2e4 », « e7e8q »), promotion comprise. */
    private fun apply(lan: String, board: Board): Move? {
        if (lan.length < 4) return null
        val move = board.move(Square(lan.substring(0, 2)), Square(lan.substring(2, 4))) ?: return null
        if (board.state is Board.State.Promotion) {
            val kind = if (lan.length == 5) kindFor(lan.last()) else Piece.Kind.queen
            return board.completePromotion(move, kind)
        }
        return move
    }

    private fun kindFor(letter: Char): Piece.Kind = when (letter.lowercaseChar()) {
        'n' -> Piece.Kind.knight
        'b' -> Piece.Kind.bishop
        'r' -> Piece.Kind.rook
        else -> Piece.Kind.queen
    }
}
