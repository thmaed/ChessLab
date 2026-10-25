package com.chesslab.ui

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.settings.SettingsStore

/**
 * L'offre d'analyse automatique, à la fin d'une partie contre l'ordinateur — là
 * où l'utilisateur a quelque chose à analyser, et où le bénéfice se dit avec des
 * mots simples. Remplace la boîte du démarrage (25/10/2026). Pendant de
 * `AutoAnalysisOfferCard` (iOS).
 *
 * N'apparaît que tant que le choix n'est pas fait ("undecided"), et au plus
 * [MAX_SHOWINGS] fois : une offre qu'on ignore deux fois est une réponse.
 */
object AutoAnalysisOffer {
    const val MAX_SHOWINGS = 2
    private const val PREFS = "auto_analysis_offer"
    private const val KEY = "showings"

    fun shouldShow(context: Context): Boolean {
        // Les builds débogables ne proposent rien (les tests d'interface ne doivent
        // jamais voir l'offre), sauf si l'intent porte l'extra `autoAnalysisPrompt`.
        val debuggable = (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val forced = (context as? android.app.Activity)?.intent?.getBooleanExtra("autoAnalysisPrompt", false) == true
        if (debuggable && !forced) return false
        return SettingsStore.state.value.autoAnalysis == "undecided" &&
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt(KEY, 0) < MAX_SHOWINGS
    }

    fun noteShown(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putInt(KEY, prefs.getInt(KEY, 0) + 1).apply()
    }
}

/** [onAccept] : la partie qui vient de finir rejoint la file (elle a été rangée AVANT le choix). */
@Composable
fun AutoAnalysisOfferCard(onAccept: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val settings by SettingsStore.state.collectAsState()
    if (settings.autoAnalysis != "undecided") return
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Palette.teal.copy(alpha = 0.10f))
            .border(1.dp, Palette.teal.copy(alpha = 0.30f), RoundedCornerShape(12.dp))
            .padding(12.dp)
            .testTag("offre-analyse-auto"),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(stringResource(R.string.auto_analysis_offer_title), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
        Text(stringResource(R.string.auto_analysis_offer_body), fontSize = 12.sp, color = Palette.textSecondary)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(R.string.auto_analysis_offer_yes), fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                color = Palette.background,
                modifier = Modifier
                    .clip(CircleShape).background(Palette.teal)
                    .clickable { SettingsStore.setAutoAnalysis(context, "on"); onAccept() }
                    .padding(horizontal = 12.dp, vertical = 8.dp)
                    .testTag("offre-analyse-oui"),
            )
            Text(
                stringResource(R.string.auto_analysis_offer_no), fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                color = Palette.textSecondary,
                modifier = Modifier
                    .clip(CircleShape)
                    .clickable { SettingsStore.setAutoAnalysis(context, "off") }
                    .padding(horizontal = 12.dp, vertical = 8.dp)
                    .testTag("offre-analyse-non"),
            )
        }
        Text(stringResource(R.string.auto_analysis_offer_note), fontSize = 10.sp, color = Palette.textTertiary)
    }
}
