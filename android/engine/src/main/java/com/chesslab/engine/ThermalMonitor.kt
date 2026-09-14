package com.chesslab.engine

import android.content.Context
import android.os.Build
import android.os.PowerManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Surveille l'état thermique de l'appareil pour LEVER LE PIED sur le moteur.
 * Pendant de `ThermalMonitor.swift`.
 *
 * Stockfish est, de loin, ce que l'app fait de plus coûteux : une série de
 * laboratoire ou une analyse en continu peut faire chauffer le téléphone au
 * point que le système finisse par brider le processeur — l'app devient
 * alors lente ET chaude. Mieux vaut réduire nous-mêmes, pendant qu'on décide
 * encore de ce qu'on sacrifie.
 *
 * Côté Android l'état vient de [PowerManager.getCurrentThermalStatus], qui
 * n'existe qu'à partir d'Android 10. En dessous, on considère l'appareil
 * froid : mieux vaut ne rien brider que brider au hasard.
 */
object ThermalMonitor {

    private val _throttling = MutableStateFlow(false)

    /**
     * Vrai quand il faut lever le pied. `SEVERE` et au-delà : le système
     * bride déjà, ou s'apprête à couper. `MODERATE` ne déclenche rien —
     * c'est l'état normal d'un appareil qui calcule.
     */
    val throttling: StateFlow<Boolean> get() = _throttling

    val isThrottling: Boolean get() = _throttling.value

    private var listener: PowerManager.OnThermalStatusChangedListener? = null

    /** Branche l'écoute. Idempotent : l'app peut l'appeler à chaque écran. */
    fun start(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || listener != null) return
        val power = context.applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return
        _throttling.value = isSevere(power.currentThermalStatus)
        val l = PowerManager.OnThermalStatusChangedListener { status ->
            _throttling.value = isSevere(status)
        }
        listener = l
        runCatching { power.addThermalStatusListener(l) }
    }

    private fun isSevere(status: Int): Boolean =
        status >= PowerManager.THERMAL_STATUS_SEVERE

    /**
     * Le budget de réflexion, raboté de moitié en surchauffe — c'est le
     * réglage le plus direct : deux fois moins de temps par coup.
     */
    fun movetimeMs(preferred: Int): Int =
        if (isThrottling) (preferred / 2).coerceAtLeast(1) else preferred

    /**
     * L'équivalent pour les budgets exprimés en NŒUDS (la classification des
     * coups). Séparé du budget de TEMPS à dessein : appliquer une réduction
     * de temps à une recherche bornée en nœuds serait contradictoire — les
     * deux limites se combattraient, et la première atteinte gagnerait au
     * hasard de la charge, ruinant justement la reproductibilité qu'on
     * cherche en passant aux nœuds.
     *
     * La surchauffe rabote donc le TRAVAIL demandé, pas le temps accordé : le
     * verdict reste comparable d'une exécution à l'autre, seulement rendu sur
     * une recherche moins profonde.
     */
    fun nodes(preferred: Long): Long =
        if (isThrottling) (preferred / 2).coerceAtLeast(1) else preferred

    /**
     * Les fils du PROCHAIN démarrage de moteur : un seul en surchauffe.
     * « Prochain » seulement — changer `Threads` sur un Stockfish en pleine
     * recherche n'a pas de comportement défini côté UCI.
     */
    fun threads(preferred: Int): Int = if (isThrottling) 1 else preferred

    /**
     * La profondeur de l'analyse en continu, rabotée en surchauffe : la
     * position affichée est réévaluée à chaque navigation, autant y mettre
     * moins de travail quand l'appareil chauffe. Seize plis suffisent à des
     * flèches justes sans tourner les cœurs à fond.
     */
    fun liveDepth(preferred: Int): Int = if (isThrottling) minOf(preferred, 16) else preferred

    /** Pour les tests : impose l'état, sans écouter le système. */
    fun forceForTesting(throttling: Boolean) {
        _throttling.value = throttling
    }
}
