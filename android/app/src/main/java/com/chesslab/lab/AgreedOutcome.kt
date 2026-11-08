package com.chesslab.lab

/**
 * L'abandon et la nulle par accord d'une série du Laboratoire — ce qu'un moteur ne déclare pas tout
 * seul. Pendant exact de `resignationOrAgreedDraw` (iOS) : mêmes fenêtres, mêmes seuils.
 *
 * Les évaluations sont au point de vue des BLANCS. Elles arrivaient au point de vue du camp au trait,
 * donc de signe alternant d'un demi-coup à l'autre : « toutes ≤ −800 » n'était jamais vrai, et
 * l'abandon ne se déclenchait pas (revue du 08/11/2026).
 */
object AgreedOutcome {
    /** Huit pions d'écart, tenus sur six demi-coups : c'est perdu. */
    const val RESIGN_CP = 800
    const val RESIGN_PLIES = 6

    /** Zéro (à 15 cp près) tenu sur dix demi-coups, après soixante : c'est nul. */
    const val DRAW_CP = 15
    const val DRAW_PLIES = 10
    const val DRAW_MIN_PLIES = 60

    /** `"1-0"`, `"0-1"`, `"1/2-1/2"`, ou `null` si la partie continue. */
    fun of(whiteEvals: List<Int>, plies: Int, resignationEnabled: Boolean, drawAgreementEnabled: Boolean): String? {
        if (drawAgreementEnabled && plies >= DRAW_MIN_PLIES && whiteEvals.size >= DRAW_PLIES &&
            whiteEvals.takeLast(DRAW_PLIES).all { kotlin.math.abs(it) <= DRAW_CP }
        ) return "1/2-1/2"
        if (resignationEnabled && whiteEvals.size >= RESIGN_PLIES) {
            val recent = whiteEvals.takeLast(RESIGN_PLIES)
            if (recent.all { it >= RESIGN_CP }) return "1-0"
            if (recent.all { it <= -RESIGN_CP }) return "0-1"
        }
        return null
    }
}
