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
    data class NewGame(
        /** La position venue d'un autre écran, ou rapportée par l'éditeur. */
        val startFen: String? = null,
    ) : Route(if (startFen == null) R.string.route_new_game else R.string.route_continue_game)

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
    data class TwoPlayerSetup(
        /**
         * La position venue d'un autre écran. Arriver avec une position ne
         * saute plus les réglages : on passe par le même écran, dont le titre
         * dit alors qu'on CONTINUE une partie — comme sur iOS.
         */
        val startFen: String? = null,
    ) : Route(if (startFen == null) R.string.route_two_players else R.string.route_continue_game)

    /**
     * La partie à deux elle-même. [startFen] la fait commencer à la position
     * qu'un autre mode vient d'envoyer ; [resume] reprend l'interrompue.
     */
    data class TwoPlayer(
        val settings: com.chesslab.twoplayer.TwoPlayerSettings? = null,
        val startFen: String? = null,
        val resume: Boolean = false,
    ) : Route(R.string.route_two_players)
    /**
     * Revoir une partie de VARIANTE, aux règles de la variante. L'analyse
     * ordinaire juge aux règles orthodoxes : sur une Horde ou un Roi de la
     * colline, son chiffre serait faux, ce qui est pire que pas de chiffre.
     */
    data class VariantAnalysis(
        val variantId: String,
        val startFen: String?,
        val uciLog: List<String>,
    ) : Route(R.string.route_analysis)

    /** Le CHOIX de la source : scanner, bibliothèque, dernière partie, coller. */
    data object Analysis : Route(R.string.route_analysis)

    /**
     * La BIBLIOTHÈQUE des parties : rechercher, filtrer, étiqueter, supprimer,
     * importer. Un écran à part, et non une liste coincée sous l'analyse :
     * c'est un classeur, pas un raccourci vers la dernière partie.
     */
    data object AnalysisLibrary : Route(R.string.analysis_library)

    /**
     * L'analyse elle-même. [fen] vient du scanner ou de l'éditeur, [pgn]
     * d'une partie rangée ; les deux nuls ouvrent sur le champ de saisie.
     */
    data class AnalysisBoard(val fen: String? = null, val pgn: String? = null) :
        Route(R.string.route_analysis)
    /** [theme] : une série ciblée sur un thème — l'entrée depuis la progression. */
    /**
     * Le CHOIX de la séance : niveau, phase, type. Comme sur iOS, on décide ce
     * qu'on travaille avant de résoudre — sans quoi le puzzle courant change
     * sous les doigts à chaque réglage.
     */
    data object PuzzleQueue : Route(R.string.route_puzzles)

    data class Puzzles(
        val theme: String? = null,
        val filter: com.chesslab.puzzles.PuzzleFilter? = null,
    ) : Route(R.string.route_puzzles)
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
    /** Les licences des composants embarqués, depuis les réglages. */
    /** Les sources des données d'ouvertures — réglages › Ouvertures. */
    data object Sources : Route(R.string.sources_title)

    data object Licences : Route(R.string.licences_title)
    /** [forSetup] : la position lue repart vers l'écran de réglage d'une partie. */
    data class Scanner(val forSetup: Boolean = false) : Route(R.string.route_scanner)
    data class PositionEditor(val forSetup: Boolean = false) : Route(R.string.route_editor)

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

    /** L'éditeur d'arbre d'un répertoire personnel. */
    data class OpeningEditor(val id: String, val name: String) :
        Route(R.string.route_openings, name)

    /** Un cours ouvert : ouverture ou finale, même écran. */
    data class CourseReader(val id: String, val name: String) : Route(R.string.route_openings, name)

    /** Le réglage d'une partie de Chess960 : le NUMÉRO de position, et à deux ou non. */
    data object Chess960Setup : Route(R.string.variant_chess960)

    /** Le Duck Chess : ses règles vivent dans l'app, pas dans le moteur. */
    data object DuckGame : Route(R.string.variant_duck)

    /** Le Coup Volé : le tour double est tenu par l'app. */
    data object StolenMoveGame : Route(R.string.variant_stolen)

    /** Une variante en cours de partie. */
    data class VariantGame(
        val id: String,
        val name: String,
        /** La position Chess960 choisie ; `null` = tirage au sort. */
        val chess960Number: Int? = null,
        val twoPlayer: Boolean = false,
    ) : Route(R.string.route_variants, name)
}
