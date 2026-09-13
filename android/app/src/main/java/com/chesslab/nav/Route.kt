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

    /**
     * Vrai quand l'écran porte DÉJÀ son grand titre : la barre n'en montre
     * alors qu'une flèche de retour. Deux fois le même mot, l'un sous
     * l'autre, ne dit rien de plus.
     */
    open val hasOwnTitle: Boolean get() = false

    data object Home : Route(R.string.route_home)
    /**
     * La CONFIGURATION d'une partie, comme sur iOS : on choisit couleur,
     * adversaire, niveau et cadence AVANT de voir un plateau.
     */
    data object NewGame : Route(R.string.route_new_game)

    /**
     * La partie elle-même. [settings] vient de l'écran de configuration ;
     * [resume] reprend celle qui a été interrompue.
     */
    data class PlayVsEngine(
        val settings: com.chesslab.play.PlayGameSettings? = null,
        val resume: Boolean = false,
        /** La position d'où partir, quand on arrive par « Changer de mode ». */
        val startFen: String? = null,
    ) : Route(R.string.route_play)

    /**
     * La CONFIGURATION d'une partie à deux : noms, présentation du plateau,
     * cadence. Comme pour le mode « contre l'ordinateur », on décide avant de
     * voir un plateau.
     */
    data object TwoPlayerSetup : Route(R.string.route_two_players)

    /**
     * La partie à deux elle-même. [startFen] la fait commencer à la position
     * qu'un autre mode vient d'envoyer ; [resume] reprend l'interrompue.
     */
    data class TwoPlayer(
        val settings: com.chesslab.twoplayer.TwoPlayerSettings? = null,
        val startFen: String? = null,
        val resume: Boolean = false,
    ) : Route(R.string.route_two_players)
    /** Le CHOIX de la source : scanner, bibliothèque, dernière partie, coller. */
    data object Analysis : Route(R.string.route_analysis)

    /**
     * L'analyse elle-même. [fen] vient du scanner ou de l'éditeur, [pgn]
     * d'une partie rangée ; les deux nuls ouvrent sur le champ de saisie.
     */
    data class AnalysisBoard(val fen: String? = null, val pgn: String? = null) :
        Route(R.string.route_analysis)
    /** [theme] : une série ciblée sur un thème — l'entrée depuis la progression. */
    data class Puzzles(val theme: String? = null) : Route(R.string.route_puzzles)
    data object Openings : Route(R.string.route_openings) {
        override val hasOwnTitle get() = true
    }
    data object Endgames : Route(R.string.route_endgames) {
        override val hasOwnTitle get() = true
    }
    /** Le Laboratoire. [startFen] impose la position de départ de la série. */
    data class Laboratory(val startFen: String? = null) : Route(R.string.route_lab)
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

    /**
     * L'entraînement LIBRE d'une finale : conclure la position contre la
     * meilleure défense, tout coup qui préserve le verdict étant accepté.
     */
    data class EndgameFree(val courseId: String, val name: String) :
        Route(R.string.endgame_free, name)

    /** L'ajout d'un répertoire personnel : PGN collé ou fichier. */
    data object OpeningImport : Route(R.string.import_title)

    /** Un cours ouvert : ouverture ou finale, même écran. */
    data class CourseReader(val id: String, val name: String) : Route(R.string.route_openings, name)

    /** Une variante en cours de partie. */
    data class VariantGame(val id: String, val name: String) : Route(R.string.route_variants, name)
}
