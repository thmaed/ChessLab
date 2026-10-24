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
 * A1 (2.0) — l'interface de l'analyse automatique : la PROPOSITION (une fois,
 * une fois la visite guidée passée) et l'indicateur d'avancement quand une
 * partie est en cours. Pendant de `AutoAnalysisHost.swift`.
 *
 * Les builds débogables ne proposent rien (les tests d'interface ne doivent
 * jamais voir la boîte), sauf si l'intent porte l'extra `autoAnalysisPrompt`.
 */
@Composable
fun AutoAnalysisHost(tour: DiscoveryTourController) {
    val context = LocalContext.current
    val settings by SettingsStore.state.collectAsState()
    var showProposal by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        val debuggable = (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val forced = (context as? android.app.Activity)?.intent?.getBooleanExtra("autoAnalysisPrompt", false) == true
        if (debuggable && !forced) return@LaunchedEffect
        // Attend la fin de la visite guidée : une seule question à la fois.
        delay(3000)
        if (settings.autoAnalysis == "undecided" && !DiscoveryTourMemory.shouldOffer(context) && !tour.isActive) {
            showProposal = true
        }
    }

    if (showProposal) {
        AlertDialog(
            onDismissRequest = { showProposal = false },
            title = { Text(stringResource(R.string.auto_analysis_title)) },
            text = { Text(stringResource(R.string.auto_analysis_message)) },
            confirmButton = {
                TextButton(
                    onClick = { SettingsStore.setAutoAnalysis(context, "on"); showProposal = false },
                    modifier = Modifier.testTag("auto_analysis_enable"),
                ) { Text(stringResource(R.string.auto_analysis_enable)) }
            },
            dismissButton = {
                Row {
                    TextButton(onClick = { showProposal = false }) { Text(stringResource(R.string.auto_analysis_later)) }
                    TextButton(onClick = { SettingsStore.setAutoAnalysis(context, "off"); showProposal = false }) {
                        Text(stringResource(R.string.auto_analysis_no))
                    }
                }
            },
        )
    }

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
