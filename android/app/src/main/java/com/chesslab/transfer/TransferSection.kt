package com.chesslab.transfer

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.SyncAlt
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.ui.Palette
import com.chesslab.ui.SettingsSection
import kotlinx.coroutines.launch

/**
 * Le transfert d'un appareil à l'autre, dans les Réglages.
 *
 * Pas de compte, pas de serveur, rien qui sorte tout seul : un fichier que
 * l'utilisateur écrit là où il veut et rouvre où il veut. C'est la seule
 * forme de synchronisation compatible avec ce que l'aide promet — aucune
 * donnée ne part sans qu'on l'ait demandé.
 *
 * L'import FUSIONNE, il ne remplace pas : le journal des révisions est réuni,
 * et l'état de chaque position est recalculé en le rejouant. Importer deux
 * fois le même fichier ne change donc rien, et l'ordre des échanges non plus.
 */
@Composable
fun TransferSection() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var message by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    val exportedOne = stringResource(R.string.transfer_exported_one)
    val exportedMany = stringResource(R.string.transfer_exported_many)
    val failed = stringResource(R.string.transfer_failed)
    val notOurs = stringResource(R.string.transfer_not_ours)
    val tooNew = stringResource(R.string.transfer_too_new)
    val nothingNew = stringResource(R.string.transfer_nothing_new)

    val save = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/octet-stream")
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            busy = true
            val result = TransferService.export(context, uri)
            busy = false
            message = result.fold(
                onSuccess = { if (it <= 1) exportedOne else String.format(exportedMany, it) },
                onFailure = { failed },
            )
        }
    }

    val open = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            busy = true
            val result = TransferService.import(context, uri)
            busy = false
            message = result.fold(
                onSuccess = { summary ->
                    if (summary.isEmpty) nothingNew
                    else context.resources.getQuantityString(
                        R.plurals.transfer_imported, summary.newReviews, summary.newReviews,
                    ) + if (summary.newGames > 0) {
                        " · " + context.resources.getQuantityString(
                            R.plurals.transfer_imported_games, summary.newGames, summary.newGames,
                        )
                    } else ""
                },
                onFailure = { error ->
                    when ((error as? TransferFile.DecodeError)?.failure) {
                        is TransferFile.Companion.Failure.TooNew -> tooNew
                        TransferFile.Companion.Failure.NotOurs -> notOurs
                        null -> failed
                    }
                },
            )
        }
    }

    SettingsSection(stringResource(R.string.transfer_title), Icons.Default.SyncAlt) {
        Text(
            stringResource(R.string.transfer_explanation),
            fontSize = 12.sp, color = Palette.textSecondary,
        )
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ActionButton(
                Icons.Default.FileUpload, stringResource(R.string.transfer_export),
                Modifier.weight(1f).testTag("exporter"), enabled = !busy,
            ) { save.launch(TransferService.suggestedName()) }
            ActionButton(
                Icons.Default.FileDownload, stringResource(R.string.transfer_import),
                Modifier.weight(1f).testTag("importer"), enabled = !busy,
            ) { open.launch(arrayOf("*/*")) }
        }
        message?.let {
            Spacer(Modifier.height(10.dp))
            Text(it, fontSize = 12.sp, color = Palette.accent, modifier = Modifier.testTag("transfert-message"))
        }
    }
}

@Composable
private fun ActionButton(
    icon: ImageVector,
    label: String,
    modifier: Modifier,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier
            .clip(CircleShape)
            .background(Palette.surfaceElevated)
            .border(1.dp, Palette.stroke, CircleShape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val tint = if (enabled) Palette.textPrimary else Palette.textTertiary
        Icon(icon, null, tint = tint, modifier = Modifier.size(17.dp))
        Spacer(Modifier.width(7.dp))
        Text(label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = tint, textAlign = TextAlign.Center)
    }
}
