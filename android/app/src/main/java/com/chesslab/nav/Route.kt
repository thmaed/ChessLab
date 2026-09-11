package com.chesslab.nav

/**
 * Les destinations de l'app. Pendant réduit de `HomeView.Route`.
 *
 * Pas de bibliothèque de navigation : une pile explicite suffit, et elle rend
 * le comportement du bouton « retour » lisible d'un coup d'œil.
 */
sealed class Route(val title: String) {
    data object Home : Route("ChessLab")
    data object PlayVsEngine : Route("Contre l'ordinateur")
    data object TwoPlayer : Route("Deux joueurs")
    data object Analysis : Route("Analyser")
    data object Puzzles : Route("Puzzles")
    data object Openings : Route("Ouvertures")
    data object Endgames : Route("Finales")
    data object Laboratory : Route("Laboratoire")
    data object Variants : Route("Variantes")
    data object Progression : Route("Progression")
    data object Settings : Route("Réglages")
    data object Help : Route("Aide")

    /** Un cours ouvert : ouverture ou finale, même écran. */
    data class CourseReader(val id: String, val name: String) : Route(name)

    /** Une variante en cours de partie. */
    data class VariantGame(val id: String, val name: String) : Route(name)
}
