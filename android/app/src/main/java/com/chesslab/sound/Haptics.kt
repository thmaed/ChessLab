package com.chesslab.sound

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.chesslab.settings.SettingsStore

/**
 * Retour haptique des événements du plateau. Pendant de `Haptics.swift`.
 *
 * Le vocabulaire est celui d'iOS — un coup, une prise, un échec, une fin de
 * partie, un coup refusé — et il se traduit bien : là où UIKit a des
 * générateurs nommés, Android a des effets prédéfinis depuis l'API 29, et une
 * durée en millisecondes en deçà.
 *
 * Aucune permission n'est requise pour `VIBRATE`… si, elle l'est, mais elle est
 * accordée à l'installation sans rien demander à l'utilisateur : ce n'est pas
 * une permission dangereuse. Elle est déclarée au manifeste.
 */
object Haptics {

    private var vibrator: Vibrator? = null

    /** À appeler une fois au démarrage : trouver le vibreur coûte un peu. */
    fun prepare(context: Context) {
        if (vibrator != null) return
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    /** Un coup ordinaire : le plus léger des retours. */
    fun move() = tick(EFFECT_TICK, 12)

    /** Une prise : plus franc, on a enlevé quelque chose du plateau. */
    fun capture() = tick(EFFECT_CLICK, 22)

    /** Un échec : un double battement, pour qu'il ne passe pas inaperçu. */
    fun check() = pattern(longArrayOf(0, 18, 60, 18))

    /** La partie est finie. */
    fun gameEnded() = pattern(longArrayOf(0, 14, 50, 14, 50, 30))

    /** Un coup refusé : sec et unique, la grammaire de l'erreur. */
    fun illegal() = tick(EFFECT_HEAVY_CLICK, 40)

    /**
     * Le retour qui convient à un coup, dans le même ordre de priorité que le
     * son : l'échec l'emporte sur la prise, qui l'emporte sur le coup simple.
     * Une prise reste une prise même quand elle donne échec — c'est l'échec
     * qu'on veut sentir.
     */
    fun forMove(isCapture: Boolean, isCastle: Boolean, isCheck: Boolean) = when {
        isCheck -> check()
        isCastle || isCapture -> capture()
        else -> move()
    }

    // MARK: la mécanique

    private const val EFFECT_TICK = 2          // VibrationEffect.EFFECT_TICK
    private const val EFFECT_CLICK = 0         // VibrationEffect.EFFECT_CLICK
    private const val EFFECT_HEAVY_CLICK = 5   // VibrationEffect.EFFECT_HEAVY_CLICK

    /**
     * Un effet PRÉDÉFINI quand le système en a un — ils sont calibrés par le
     * constructeur et se sentent justes sur son matériel — et une durée brute
     * en repli. Une durée ne remplace pas un effet calibré, mais elle vaut
     * mieux que rien.
     */
    private fun tick(predefined: Int, fallbackMs: Long) {
        val v = enabled() ?: return
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                v.vibrate(VibrationEffect.createPredefined(predefined))
            } else {
                v.vibrate(VibrationEffect.createOneShot(fallbackMs, VibrationEffect.DEFAULT_AMPLITUDE))
            }
        }
    }

    private fun pattern(timings: LongArray) {
        val v = enabled() ?: return
        runCatching { v.vibrate(VibrationEffect.createWaveform(timings, -1)) }
    }

    /** Le vibreur, si l'appareil en a un ET que l'utilisateur le veut. */
    private fun enabled(): Vibrator? =
        vibrator?.takeIf { it.hasVibrator() && SettingsStore.state.value.hapticsEnabled }
}
