package com.chesslab.settings

import android.app.LocaleManager
import android.content.Context
import android.content.ContextWrapper
import android.os.Build
import android.os.LocaleList
import java.util.Locale

/**
 * La langue de l'app : celle du système, ou un choix explicite.
 *
 * Pendant d'`AppSettings.appLanguage` côté iOS, avec deux chemins selon la
 * version d'Android — chacun étant LE bon pour sa plateforme :
 *
 * - **Android 13 et au-delà** : le système tient un réglage « langue de
 *   l'application », visible dans ses propres Réglages. On l'écrit chez lui,
 *   il redémarre l'activité, et il n'y a qu'une seule vérité. C'est aussi ce
 *   qui fait apparaître ChessLab dans la liste système (voir
 *   `res/xml/locales_config.xml`).
 * - **avant Android 13** : rien de tel n'existe. Le choix vit dans un
 *   `SharedPreferences` — et non dans notre DataStore, qui est asynchrone :
 *   il faut le lire dans `attachBaseContext`, avant que la moindre ressource
 *   ne soit résolue.
 *
 * `AppCompatDelegate.setApplicationLocales` aurait fait les deux, mais il ne
 * sait recréer que des `AppCompatActivity` : dans une app Compose posée sur
 * une `ComponentActivity`, l'appel partait dans le vide sans rien signaler.
 */
enum class AppLanguage(val tag: String) {
    system(""),
    french("fr"),
    english("en");

    companion object {
        private const val PREFS = "chesslab.language"
        private const val KEY = "tag"

        private fun of(tag: String?): AppLanguage = when {
            tag == null -> system
            tag.startsWith("fr") -> french
            tag.startsWith("en") -> english
            else -> system
        }

        /** La langue actuellement demandée. */
        fun current(context: Context): AppLanguage =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val locales = context.getSystemService(LocaleManager::class.java)?.applicationLocales
                of(if (locales == null || locales.isEmpty) null else locales[0].language)
            } else {
                of(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null))
            }

        /**
         * Applique le choix. Sur Android 13+, le système recrée l'activité ;
         * avant, c'est à l'appelant de le faire — d'où le `recreate`.
         */
        fun apply(context: Context, language: AppLanguage, recreate: () -> Unit) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.getSystemService(LocaleManager::class.java)?.applicationLocales =
                    if (language == system) LocaleList.getEmptyLocaleList()
                    else LocaleList.forLanguageTags(language.tag)
            } else {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .apply { if (language == system) remove(KEY) else putString(KEY, language.tag) }
                    .apply()
                recreate()
            }
        }

        /**
         * Le contexte à donner à l'activité avant Android 13. Sans effet
         * au-delà : le système s'en charge lui-même.
         */
        fun wrap(base: Context): Context {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return base
            val tag = base.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
                ?: return base
            val config = android.content.res.Configuration(base.resources.configuration)
            val locale = Locale.forLanguageTag(tag)
            Locale.setDefault(locale)
            config.setLocales(LocaleList(locale))
            return ContextWrapper(base.createConfigurationContext(config))
        }
    }
}
