package com.chesslab.nav

import android.content.Context
import androidx.annotation.StringRes
import com.chesslab.R

/**
 * Les destinations de l'app. Pendant réduit de `HomeView.Route`.
 *
 * Pas de bibliothèque de navigation : une pile explicite suffit, et elle rend
 * le comportement du bouton « retour » lisible d'un coup d'œil.
 *
 * Le titre est une RESSOURCE, sauf pour les écrans qui en portent un venu des
 * données — un nom de cours, une variante — auquel cas [dynamicTitle] prime.
 */
sealed class Route(@StringRes val titleRes: Int, val dynamicTitle: String? = null) {

    fun title(context: Context): String = dynamicTitle ?: context.getString(titleRes)

    data object Home : Route(R.string.route_home)
    /** [resume] : reprendre la partie interrompue plutôt que d'en commencer une. */
    data class PlayVsEngine(val resume: Boolean = false) : Route(R.string.route_play)
    data object TwoPlayer : Route(R.string.route_two_players)
    /** [fen] : une position à charger d'emblée (venue du scanner ou de l'éditeur). */
    data class Analysis(val fen: String? = null) : Route(R.string.route_analysis)
    data object Puzzles : Route(R.string.route_puzzles)
    data object Openings : Route(R.string.route_openings)
    data object Endgames : Route(R.string.route_endgames)
    data object Laboratory : Route(R.string.route_lab)
    data object Variants : Route(R.string.route_variants)
    data object Progression : Route(R.string.route_progress)
    data object Settings : Route(R.string.route_settings)
    data object Help : Route(R.string.route_help)
    data object Scanner : Route(R.string.route_scanner)
    data object PositionEditor : Route(R.string.route_editor)

    /**
     * Une séance d'entraînement. [courseId] n'est rempli que pour « une
     * ligne » ; sinon la séance est quotidienne ou ciblée sur les difficiles.
     */
    data class Train(val kind: String, val courseId: String? = null, val label: String? = null) :
        Route(R.string.route_training, label)

    /** Un cours ouvert : ouverture ou finale, même écran. */
    data class CourseReader(val id: String, val name: String) : Route(R.string.route_openings, name)

    /** Une variante en cours de partie. */
    data class VariantGame(val id: String, val name: String) : Route(R.string.route_variants, name)
}
