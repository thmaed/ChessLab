package com.chesslab.puzzles

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CallSplit
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.chesslab.R
import com.chesslab.ui.Palette

/**
 * Le palier de difficulté d'un puzzle, d'après sa cote Lichess. Pendant de
 * `DifficultyTier.swift`.
 */
enum class DifficultyTier(@StringRes val labelRes: Int, val range: IntRange) {
    beginner(R.string.tier_beginner, 0..1199),
    intermediate(R.string.tier_intermediate, 1200..1599),
    advanced(R.string.tier_advanced, 1600..1999),
    expert(R.string.tier_expert, 2000..Int.MAX_VALUE);

    /**
     * La difficulté se lit à sa COULEUR, du vert au rose — quatre paliers,
     * quatre teintes, les mêmes qu'iOS. Android affichait la cote brute en
     * vert-bleu-jaune-rouge : ni le même barème, ni les mêmes couleurs.
     */
    val tint: Color
        get() = when (this) {
            beginner -> Palette.accent
            intermediate -> Palette.info
            advanced -> Palette.warning
            expert -> Palette.rose
        }

    companion object {
        fun forRating(rating: Int): DifficultyTier =
            entries.firstOrNull { rating in it.range } ?: expert
    }
}

/** La phase de partie d'où vient la position. Pendant de `GamePhase.swift`. */
enum class GamePhase(val raw: String, @StringRes val labelRes: Int) {
    opening("opening", R.string.phase_opening),
    middlegame("middlegame", R.string.phase_middlegame),
    endgame("endgame", R.string.phase_endgame);

    /** L'icône la dit sans qu'on lise : un drapeau, un éclair, une couronne. */
    val icon: ImageVector
        get() = when (this) {
            opening -> Icons.Outlined.Flag
            middlegame -> Icons.Default.Bolt
            endgame -> Icons.Default.WorkspacePremium
        }

    val tint: Color
        get() = when (this) {
            opening -> Palette.teal
            middlegame -> Palette.violet
            endgame -> Palette.warning
        }

    companion object {
        fun of(raw: String?): GamePhase? = entries.firstOrNull { it.raw == raw }

        /**
         * La phase d'une position, lue sur sa FEN. Pendant EXACT de
         * `GamePhaseClassifier.classify` (iOS), mêmes seuils :
         * - finale : peu de pièces hors pions et rois — 2 au plus avec une
         *   dame sur l'échiquier, 6 sans ;
         * - ouverture : coup ≤ 10, au moins 14 pions et 12 pièces ;
         * - milieu de partie : tout le reste.
         *
         * Sert aux puzzles MAISON, qui n'avaient pas de phase sur Android :
         * un filtre de phase les excluait tous (PARITE.md, 23/10/2026).
         */
        fun classify(fen: String): GamePhase {
            val position = chesskit.Position.fromFen(fen) ?: return middlegame
            val pieces = position.pieces
            val hasQueen = pieces.any { it.kind == chesskit.Piece.Kind.queen }
            val majorMinor = pieces.count { it.kind != chesskit.Piece.Kind.pawn && it.kind != chesskit.Piece.Kind.king }
            if (majorMinor <= if (hasQueen) 2 else 6) return endgame
            val pawns = pieces.count { it.kind == chesskit.Piece.Kind.pawn }
            val fullmove = fen.trim().split(" ").lastOrNull()?.toIntOrNull() ?: Int.MAX_VALUE
            if (fullmove <= 10 && pawns >= 14 && majorMinor >= 12) return opening
            return middlegame
        }
    }
}

/** Les huit thèmes tactiques, dans l'ordre d'iOS. */
enum class PuzzleThemeKind(val raw: String, @StringRes val labelRes: Int) {
    checkmate("checkmate", R.string.theme_mate),
    hangingPiece("hangingPiece", R.string.theme_hanging),
    fork("fork", R.string.theme_fork),
    pin("pin", R.string.theme_pin),
    skewer("skewer", R.string.theme_skewer),
    discoveredAttack("discoveredAttack", R.string.theme_discovered),
    sacrifice("sacrifice", R.string.theme_sacrifice),
    tactic("tactic", R.string.theme_tactic);

    /** Les mêmes symboles qu'iOS, dans leur équivalent Material. */
    val icon: ImageVector
        get() = when (this) {
            checkmate -> Icons.Default.SportsScore
            hangingPiece -> Icons.Default.Warning
            fork -> Icons.Default.CallSplit
            pin -> Icons.Default.PushPin
            skewer -> Icons.Default.SwapHoriz
            discoveredAttack -> Icons.Default.Visibility
            sacrifice -> Icons.Default.LocalFireDepartment
            tactic -> Icons.Default.Extension
        }
}

/**
 * Ce qu'on demande à la file de puzzles. Pendant de `PuzzleSessionFilter`.
 *
 * Tout est facultatif : sans filtre, on tire dans les 106 094 positions, ce qui
 * est le comportement d'origine. **Avec** filtre, on travaille une faiblesse
 * précise — les fourchettes, les finales, ou les deux —, et c'est tout
 * l'intérêt d'une base de cette taille.
 */
data class PuzzleFilter(
    val difficulty: DifficultyTier? = null,
    val phase: GamePhase? = null,
    val theme: PuzzleThemeKind? = null,
    /**
     * `null` = les deux. Le choix vivait sur l'écran de résolution, au-dessus
     * du plateau ; iOS le pose ici, avec les autres critères de la séance.
     */
    val source: PuzzleSource? = null,
    /**
     * Seulement les puzzles ratés à la DERNIÈRE tentative : un échec remet
     * `repetitions` à zéro, un succès l'incrémente — `failureCount > 0 &&
     * repetitions == 0` le dit sans champ nouveau. L'échéance est ignorée :
     * ce qu'on vient de rater ne serait dû que demain. Réussi avec l'indice =
     * réussi. Pendant de `PuzzleSessionFilter.missedOnly`.
     */
    val missedOnly: Boolean = false,
    /**
     * Seulement les puzzles PARTIELS de la dernière tentative ([PuzzleResult.partial]) :
     * un coup juste au moins, mais pas la séquence propre. Exclusif avec
     * [missedOnly]. Pendant de `PuzzleSessionFilter.reviewOnly`.
     */
    val reviewOnly: Boolean = false,
    /**
     * Fenêtre de cotes « À mon niveau » ([PuzzleRating.window]), calculée au
     * lancement de la série. Prime sur [difficulty] : les deux disent la même
     * chose, l'un par palier, l'autre par la cote du joueur.
     */
    val ratingWindow: IntRange? = null,
    /** Nombre de puzzles au plus pour la série (la séance du jour) ; `null` = sans fin. */
    val limit: Int? = null,
) {
    val ratings: IntRange get() = ratingWindow ?: difficulty?.range ?: 0..4000
    val isEmpty: Boolean
        get() = difficulty == null && phase == null && theme == null && source == null &&
            !missedOnly && !reviewOnly && ratingWindow == null
}
