package com.chesslab.variants

import chesskit.Piece
import com.chesslab.play.GameClock
import com.chesslab.play.TimeControl
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * La pendule d'un écran de variante : le minuteur, le drapeau, et le budget de
 * réflexion du moteur. Pendant de ce que `ClockLabel` + `GameClock` font
 * ensemble côté iOS.
 *
 * Elle existe parce que TROIS écrans en ont besoin — Fairy, Duck Chess, Coup
 * Volé — et que trois copies d'un décompte dérivent toujours : l'une oublie
 * l'incrément, l'autre laisse le drapeau tomber pendant que le moteur cherche.
 * [GameClock] ne tourne pas toute seule, c'est voulu ; c'est ici qu'on lui
 * donne l'heure.
 */
class VariantClock(private val scope: CoroutineScope) {

    private var clock: GameClock? = null
    private var ticker: Job? = null

    /** Appelé dix fois par seconde tant qu'un camp décompte. */
    var onTick: (Long?, Long?) -> Unit = { _, _ -> }

    /** Appelé UNE fois, quand un camp arrive à zéro. */
    var onFlag: (Piece.Color) -> Unit = {}

    val hasClock: Boolean get() = clock?.hasClock == true

    fun remaining(color: Piece.Color): Long? = clock?.takeIf { it.hasClock }?.remaining(color)

    /** Une nouvelle partie : la pendule repart à plein, ou disparaît. */
    fun reset(control: TimeControl) {
        ticker?.cancel()
        ticker = null
        clock = control.takeIf { it.hasClock }?.let { GameClock(it) }
        publish()
    }

    /** Le trait passe à [color] : son décompte commence. */
    fun startTurn(color: Piece.Color) {
        val c = clock ?: return
        if (!c.hasClock) return
        c.start(color, System.currentTimeMillis())
        ticker?.cancel()
        ticker = scope.launch {
            while (true) {
                delay(100)
                c.tick(System.currentTimeMillis())
                publish()
                val flagged = Piece.Color.entries.firstOrNull { c.flagged(it) }
                if (flagged != null) {
                    ticker?.cancel()
                    onFlag(flagged)
                    return@launch
                }
            }
        }
    }

    /**
     * Le camp qui vient de jouer arrête son décompte et touche son incrément —
     * APRÈS le décompte, comme le veut la règle Fischer.
     */
    fun stopAndIncrement() {
        val c = clock ?: return
        c.stopAndIncrement(System.currentTimeMillis())
        publish()
    }

    /**
     * L'écran s'en va, ou l'app passe derrière : on ne compte plus. Perdre au
     * temps contre un moteur local parce qu'on a répondu à un message serait
     * absurde.
     */
    fun pause() {
        clock?.pause(System.currentTimeMillis())
        ticker?.cancel()
        ticker = null
    }

    fun stop() {
        ticker?.cancel()
        ticker = null
        clock?.pause(System.currentTimeMillis())
    }

    /**
     * Le temps que s'accorde le moteur. Sans pendule, celui que l'utilisateur a
     * choisi dans les réglages — le même que le mode « Contre l'ordinateur »,
     * puisque c'est le même bouton. Avec une pendule, il se rationne comme un
     * joueur : un trentième de ce qui reste, plus le gros de l'incrément, borné
     * par le quart de ce qui reste.
     */
    fun movetimeFor(mover: Piece.Color): Int {
        val c = clock ?: return reglage()
        if (!c.hasClock) return reglage()
        val remaining = c.remaining(mover) / 1000.0
        val increment = c.control.incrementSeconds.toDouble()
        val base = remaining / 30 + increment * 0.8
        val ceiling = minOf(30.0, remaining / 4)
        return (base.coerceIn(0.15, maxOf(0.15, ceiling)) * 1000).toInt()
    }

    private fun publish() {
        onTick(remaining(Piece.Color.white), remaining(Piece.Color.black))
    }

    /** Le temps choisi dans les réglages, et 900 ms si rien n'a été choisi. */
    private fun reglage(): Int =
        com.chesslab.settings.SettingsStore.state.value.engineMoveTimeMs
}
