package com.chesslab.nav

/**
 * Les destinations de l'app. Pendant réduit de `HomeView.Route`.
 *
 * Pas de bibliothèque de navigation : une pile explicite suffit, et elle rend
 * le comportement du bouton « retour » lisible d'un coup d'œil.
 */
sealed class Route(val title: String) {
    data object Home : Route("ChessLab")
    /** [resume] : reprendre la partie interrompue plutôt que d'en commencer une. */
    data class PlayVsEngine(val resume: Boolean = false) : Route("Contre l'ordinateur")
    data object TwoPlayer : Route("Deux joueurs")
    /** [fen] : une position à charger d'emblée (venue du scanner ou de l'éditeur). */
    data class Analysis(val fen: String? = null) : Route("Analyser")
    data object Puzzles : Route("Puzzles")
    data object Openings : Route("Ouvertures")
    data object Endgames : Route("Finales")
    data object Laboratory : Route("Laboratoire")
    data object Variants : Route("Variantes")
    data object Progression : Route("Progression")
    data object Settings : Route("Réglages")
    data object Help : Route("Aide")
    data object Scanner : Route("Scanner un échiquier")
    data object PositionEditor : Route("Éditeur de position")

    /**
     * Une séance d'entraînement. [courseId] n'est rempli que pour « une
     * ligne » ; sinon la séance est quotidienne ou ciblée sur les difficiles.
     */
    data class Train(val kind: String, val courseId: String? = null, val label: String = "Entraînement") : Route(label)

    /** Un cours ouvert : ouverture ou finale, même écran. */
    data class CourseReader(val id: String, val name: String) : Route(name)

    /** Une variante en cours de partie. */
    data class VariantGame(val id: String, val name: String) : Route(name)
}
