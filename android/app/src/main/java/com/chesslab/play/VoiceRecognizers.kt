package com.chesslab.play

import android.content.Context
import android.content.Intent
import android.os.Build
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.util.Locale

/**
 * La reconnaissance vocale SUR L'APPAREIL, et elle seule : pendant de `VoiceRecognizers` (iOS). Jamais le
 * reconnaisseur Google ordinaire, qui peut passer par le réseau — la promesse « aucune donnée qui sort de
 * l'appareil » l'exclut (et le manifeste ne déclare toujours pas `INTERNET`).
 *
 * `createOnDeviceSpeechRecognizer` n'existe qu'à partir d'Android 12 : avant, la ligne « Coups à la voix » est
 * grisée et dit pourquoi, comme un iPhone sans reconnaissance sur l'appareil dans la langue.
 */
object VoiceRecognizers {
    /** [downloadable] : la langue existe sur l'appareil, mais son modèle n'est pas encore installé. */
    enum class Availability { available, downloadable, unavailable }

    /** Les langues de l'app → les locales de reconnaissance par défaut (comme iOS : fr-FR, en-US, es-ES, de-DE, it-IT). */
    fun defaultLocale(language: String): String = when (language.take(2)) {
        "en" -> "en-US"
        "es" -> "es-ES"
        "de" -> "de-DE"
        "it" -> "it-IT"
        else -> "fr-FR"
    }

    /**
     * La variante de la langue À DEMANDER au reconnaisseur. Android ne reconnaît que la variante dont le paquet est
     * installé : un Galaxy réglé en français de Suisse a « fr-CH » et répond « langue indisponible » (erreur 13) à
     * « fr-FR » (constaté le 19/11/2026). Donc : la variante du téléphone si elle est installée, sinon celle par
     * défaut si elle l'est, sinon n'importe quelle variante installée de la langue ; rien d'installé → celle du
     * téléphone si c'est la même langue (Android 12 ne dit pas ce qui est installé), sinon celle par défaut.
     */
    fun locale(language: String, installed: List<String> = emptyList(), device: Locale = Locale.getDefault()): String {
        val fallback = defaultLocale(language)
        val wanted = Locale.forLanguageTag(fallback).language
        val deviceTag = device.toLanguageTag().takeIf { device.language == wanted && device.country.isNotEmpty() }
        val sameLanguage = installed.filter { Locale.forLanguageTag(it).language == wanted }
        fun installedAs(tag: String?) = tag?.let { t -> sameLanguage.firstOrNull { it.equals(t, ignoreCase = true) } }
        return installedAs(deviceTag) ?: installedAs(fallback) ?: sameLanguage.firstOrNull() ?: deviceTag ?: fallback
    }

    /** La variante retenue par la dernière vérification ([availability]), langue par langue. */
    private val chosen = java.util.concurrent.ConcurrentHashMap<String, String>()

    fun intent(language: String): Intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        .putExtra(RecognizerIntent.EXTRA_LANGUAGE, chosen[language.take(2)] ?: locale(language))
        .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)

    /**
     * La reconnaissance sur l'appareil existe-t-elle ici, dans cette langue ? Android 13+ le dit langue par langue ;
     * Android 12 ne dit que « oui en général ». Rendu sur le fil principal. Ne télécharge RIEN : la demande au système
     * ouvre sa propre fenêtre par-dessus l'app — voir [requestModel], appelée quand on allume la fonction.
     */
    fun availability(context: Context, language: String, onResult: (Availability) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        ) {
            onResult(Availability.unavailable)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            onResult(Availability.available)
            return
        }
        val wanted = Locale.forLanguageTag(defaultLocale(language)).language
        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        val intent = intent(language)
        recognizer.checkRecognitionSupport(intent, context.mainExecutor, object : RecognitionSupportCallback {
            override fun onSupportResult(support: RecognitionSupport) {
                fun has(list: List<String>) = list.any { Locale.forLanguageTag(it).language == wanted }
                // Une variante installée (ou en cours) devient celle qu'on demandera ; sinon celle qu'on téléchargerait.
                val ready = support.installedOnDeviceLanguages + support.pendingOnDeviceLanguages
                chosen[language.take(2)] = locale(language, if (has(ready)) ready else support.supportedOnDeviceLanguages)
                val result = when {
                    has(ready) -> Availability.available
                    has(support.supportedOnDeviceLanguages) -> Availability.downloadable
                    else -> Availability.unavailable
                }
                recognizer.destroy()
                onResult(result)
            }

            override fun onError(error: Int) {
                recognizer.destroy()
                // Le service ne sait pas répondre : on laisse essayer, l'écoute dira si rien ne vient.
                onResult(Availability.available)
            }
        })
    }

    /**
     * Demande au SYSTÈME de télécharger le modèle de la langue (l'app, elle, n'a pas le réseau). Android ouvre sa
     * fenêtre de téléchargement : on ne l'appelle que sur un geste de l'utilisateur (allumer « Coups à la voix »).
     */
    fun requestModel(context: Context, language: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        recognizer.triggerModelDownload(intent(language))
        recognizer.destroy()
    }
}
