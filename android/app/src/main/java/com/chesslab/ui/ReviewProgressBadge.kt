package com.chesslab.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R

/**
 * L'avancement de l'analyse d'une partie : une capsule qui SE REMPLIT d'orange vif, coup par coup.
 *
 * Pendant de `ClassificationProgressBadge` (iOS). Elle remplace le petit compteur de la barre de
 * boutons : une ligne grise de 11 sp se lit à peine, et la place y manque (retour d'un
 * utilisateur, 08/11/2026 : « l'avancement est peu visible »). Largeur FIXE : la jauge ne change
 * pas de longueur quand le compteur gagne un chiffre.
 */
@Composable
fun ReviewProgressBadge(done: Int, total: Int) {
    val fraction = (done.toFloat() / total).coerceIn(0f, 1f)
    val label = stringResource(R.string.analysis_progress, done, total)
    Box(
        Modifier
            .width(250.dp)
            .height(26.dp)
            .clip(CircleShape)
            .background(Palette.surface)
            .border(1.5.dp, Palette.progress, CircleShape)
            .semantics(mergeDescendants = true) { contentDescription = label }
            .testTag("revue-en-cours"),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .align(Alignment.CenterStart)
                .fillMaxHeight()
                .fillMaxWidth(fraction)
                .background(Palette.progress.copy(alpha = 0.65f))
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 2.dp, color = Palette.textPrimary)
            Spacer(Modifier.width(8.dp))
            Text(label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary, maxLines = 1)
        }
    }
}
