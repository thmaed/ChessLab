package com.chesslab.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.analysis.AutoAnalysisService
import com.chesslab.discovery.DiscoveryTourController
import com.chesslab.discovery.DiscoveryTourMemory
import com.chesslab.settings.SettingsStore
import kotlinx.coroutines.delay

/**
 * A1 (2.0) — l'interface de l'analyse automatique : l'indicateur d'avancement
 * quand une partie est en cours. Pendant de `AutoAnalysisHost.swift`.
 *
 * La PROPOSITION n'est plus une boîte au démarrage (25/10/2026 : hors contexte,
 * jargon, aucun bénéfice dit) : elle vit sur l'écran de fin de partie —
 * [AutoAnalysisOfferCard] — au moment où l'utilisateur a une partie à analyser.
 */
@Composable
fun AutoAnalysisHost(tour: DiscoveryTourController) {
    if (AutoAnalysisService.isRunning || AutoAnalysisService.queue.isNotEmpty()) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.BottomCenter) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(Palette.surface)
                    .navigationBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 10.dp)
                    .testTag("auto_analysis_banner"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.auto_analysis_running), fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
                    AutoAnalysisService.progress?.let { (done, total) ->
                        Text(stringResource(R.string.auto_analysis_progress, done, total),
                            fontSize = 11.sp, color = Palette.textTertiary)
                    }
                }
                TextButton(onClick = { AutoAnalysisService.stop() }, modifier = Modifier.testTag("auto_analysis_stop")) {
                    Text(stringResource(R.string.auto_analysis_stop))
                }
            }
        }
    }
}
