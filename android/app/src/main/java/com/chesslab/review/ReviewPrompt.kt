package com.chesslab.review

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import com.chesslab.dailysession.TrainingDays
import com.chesslab.ui.Palette

/**
 * Quand inviter à laisser un avis. Pendant de `ReviewPrompt.swift` — même règle :
 * juste APRÈS une réussite (partie gagnée contre l'ordinateur, cycle Woodpecker
 * bouclé), à quelqu'un qui revient (trois jours d'entraînement), deux réussites au
 * moins, une fois par version au plus, et pas plus d'une fois tous les 120 jours.
 *
 * **Écart assumé avec iOS.** iOS présente la demande SYSTÈME d'Apple. L'équivalent
 * Google (In-App Review) est une bibliothèque propriétaire : la lier à une app
 * GPLv3, et la rendre impropre à F-Droid, n'en vaut pas la peine. Android montre
 * donc une invitation dans l'app, qui ouvre la fiche Play — sans permission réseau :
 * c'est l'app Play Store qui s'ouvre, pas ChessLab qui se connecte.
 */
data class ReviewPromptPolicy(
    val positiveMoments: Int = 0,
    val trainingDays: Int = 0,
    val lastAskedVersion: String? = null,
    /** Millisecondes depuis l'époque, `null` si jamais demandé. */
    val lastAskedAt: Long? = null,
) {
    fun shouldAsk(version: String, nowMillis: Long): Boolean {
        if (positiveMoments < MINIMUM_POSITIVE_MOMENTS || trainingDays < MINIMUM_TRAINING_DAYS) return false
        if (lastAskedVersion == version) return false
        val last = lastAskedAt ?: return true
        return (nowMillis - last) / DAY_MS >= MINIMUM_DAYS_BETWEEN_ASKS
    }

    companion object {
        const val MINIMUM_POSITIVE_MOMENTS = 2
        const val MINIMUM_TRAINING_DAYS = 3
        const val MINIMUM_DAYS_BETWEEN_ASKS = 120
        private const val DAY_MS = 24L * 60 * 60 * 1000
    }
}

object ReviewPrompt {
    private const val FILE = "review_prompt"
    private const val POSITIVES = "positive_moments"
    private const val VERSION = "last_asked_version"
    private const val ASKED_AT = "last_asked_at"
    /** La fiche de l'app publiée — la variante de débogage porte un suffixe. */
    private const val STORE_PACKAGE = "com.maeder.chesslab"

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    private fun version(context: Context): String = runCatching {
        context.packageManager.getPackageInfo(context.packageName, 0).versionName
    }.getOrNull() ?: "?"

    fun policy(context: Context): ReviewPromptPolicy {
        val p = prefs(context)
        return ReviewPromptPolicy(
            positiveMoments = p.getInt(POSITIVES, 0),
            trainingDays = TrainingDays.all(context).size,
            lastAskedVersion = p.getString(VERSION, null),
            lastAskedAt = if (p.contains(ASKED_AT)) p.getLong(ASKED_AT, 0) else null,
        )
    }

    /**
     * Une réussite vient d'avoir lieu. Renvoie `true` s'il est temps d'inviter —
     * l'invitation est alors notée comme faite, qu'on y donne suite ou non.
     */
    fun recordPositiveMoment(context: Context, nowMillis: Long = System.currentTimeMillis()): Boolean {
        val p = prefs(context)
        p.edit().putInt(POSITIVES, p.getInt(POSITIVES, 0) + 1).apply()
        val version = version(context)
        if (!policy(context).shouldAsk(version, nowMillis)) return false
        p.edit().putString(VERSION, version).putLong(ASKED_AT, nowMillis).apply()
        return true
    }

    /** Ouvre la fiche Play : l'app Play Store si elle est là, le navigateur sinon. */
    fun openStorePage(context: Context) {
        val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$STORE_PACKAGE"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(market)
        } catch (_: ActivityNotFoundException) {
            runCatching {
                context.startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$STORE_PACKAGE"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
        }
    }
}

/** L'invitation, discrète, sous le bilan d'une réussite. Disparaît dès qu'on y répond. */
@Composable
fun ReviewInvite(modifier: Modifier = Modifier, onDone: () -> Unit) {
    val context = LocalContext.current
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Palette.accent.copy(alpha = 0.10f))
            .border(1.dp, Palette.accent.copy(alpha = 0.30f), shape)
            .padding(14.dp)
            .testTag("invitation-avis"),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(stringResource(R.string.review_invite_title), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
        Text(stringResource(R.string.review_invite_body), fontSize = 12.sp, color = Palette.textSecondary)
        Row(Modifier.padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(R.string.review_invite_rate),
                fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Palette.accent)
                    .clickable { ReviewPrompt.openStorePage(context); onDone() }
                    .padding(horizontal = 14.dp, vertical = 7.dp)
                    .testTag("invitation-avis-noter"),
            )
            Spacer(Modifier.width(12.dp))
            Text(
                stringResource(R.string.review_invite_later),
                fontSize = 13.sp, color = Palette.textSecondary,
                modifier = Modifier
                    .clip(CircleShape)
                    .clickable(onClick = onDone)
                    .padding(horizontal = 10.dp, vertical = 7.dp)
                    .testTag("invitation-avis-plus-tard"),
            )
        }
    }
}
