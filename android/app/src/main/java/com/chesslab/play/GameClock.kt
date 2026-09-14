package com.chesslab.play

import chesskit.Piece

/**
 * La double pendule. Pendant de `GameClock.swift`.
 *
 * Elle ne tourne pas toute seule : le modèle de vue lui donne l'heure à
 * intervalle régulier. C'est ce qui la rend testable — une pendule qui
 * s'appuie sur un minuteur interne ne se vérifie qu'en attendant.
 */
class GameClock(val control: TimeControl) {

    private var whiteMs = control.initialSeconds * 1000L
    private var blackMs = control.initialSeconds * 1000L
    private var running: Piece.Color? = null
    private var lastTick = 0L

    val hasClock: Boolean get() = control.hasClock

    /**
     * Repose les deux pendules là où elles étaient — à la reprise d'une partie
     * interrompue. Sans cela on reprenait à temps PLEIN, ce qui est un cadeau
     * que personne n'a demandé.
     */
    fun restore(whiteMs: Long?, blackMs: Long?) {
        if (whiteMs != null) this.whiteMs = whiteMs
        if (blackMs != null) this.blackMs = blackMs
    }

    /** Le temps restant, en millisecondes, jamais négatif. */
    fun remaining(color: Piece.Color): Long =
        (if (color == Piece.Color.white) whiteMs else blackMs).coerceAtLeast(0)

    fun flagged(color: Piece.Color): Boolean = hasClock && remaining(color) == 0L

    /** Démarre le décompte pour [color] à l'instant [now]. */
    fun start(color: Piece.Color, now: Long) {
        if (!hasClock) return
        tick(now)
        running = color
        lastTick = now
    }

    /**
     * Arrête le camp qui jouait et lui crédite son incrément.
     *
     * L'incrément s'ajoute APRÈS le décompte, comme le veut la règle Fischer :
     * l'ajouter avant offrirait un temps qu'un joueur au drapeau n'a plus.
     */
    fun stopAndIncrement(now: Long) {
        if (!hasClock) return
        tick(now)
        val color = running ?: return
        if (remaining(color) > 0) add(color, control.incrementSeconds * 1000L)
        running = null
    }

    /**
     * Suspend le décompte SANS rendre la main : le camp qui jouait reste le
     * même, on ne compte simplement plus. Sert quand l'écran disparaît ou que
     * l'app passe en arrière-plan — contre un moteur local, perdre au temps
     * parce qu'on a répondu à un message serait absurde.
     */
    fun pause(now: Long) {
        if (!hasClock) return
        tick(now)
        paused = running
        running = null
    }

    /** Reprend le décompte du camp suspendu, s'il y en avait un. */
    fun resume(now: Long) {
        if (!hasClock) return
        val color = paused ?: return
        paused = null
        running = color
        lastTick = now
    }

    private var paused: Piece.Color? = null

    /** Reporte le temps écoulé depuis le dernier appel sur le camp qui joue. */
    fun tick(now: Long) {
        if (!hasClock) return
        val color = running ?: return
        val elapsed = (now - lastTick).coerceAtLeast(0)
        add(color, -elapsed)
        lastTick = now
    }

    private fun add(color: Piece.Color, ms: Long) {
        if (color == Piece.Color.white) whiteMs += ms else blackMs += ms
    }

    companion object {
        /**
         * « 03:24 », ou les dixièmes sous dix secondes — le zeitnot se lit.
         *
         * La langue est un PARAMÈTRE, pas un hasard : `String.format` sans
         * `Locale` suit celle de la machine, et le séparateur décimal changeait
         * donc en silence d'un appareil à l'autre. Ici c'est un choix — une
         * pendule est un texte lu par un humain, elle suit sa langue.
         */
        fun format(ms: Long, locale: java.util.Locale = java.util.Locale.getDefault()): String {
            val clamped = ms.coerceAtLeast(0)
            if (clamped < 10_000) return String.format(locale, "%.1f", clamped / 1000.0)
            val seconds = (clamped + 500) / 1000
            return String.format(locale, "%02d:%02d", seconds / 60, seconds % 60)
        }
    }
}
