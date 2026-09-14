package com.chesslab.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.chesslab.R

/**
 * Copier ou partager la position et la partie. Pendant du menu d'export de
 * `PlayView` / `TwoPlayerGameView`.
 *
 * Une partie qui ne sort pas de l'app n'existe que là : la FEN va vers un
 * site d'analyse, le PGN vers un ami ou un logiciel. C'est le seul chemin
 * d'export d'une partie EN COURS — la bibliothèque, elle, ne voit que les
 * parties finies.
 *
 * Le retour « Copié » passe par un `Toast` là où iOS montre une alerte : le
 * message est le même, la forme est celle de la plateforme.
 */
@Composable
fun ExportMenu(
    fen: () -> String,
    pgn: () -> String,
    /** Faux avant le premier coup : il n'y a pas encore de partie. */
    hasGame: Boolean,
) {
    val context = LocalContext.current
    var open by remember { mutableStateOf(false) }

    IconButton(onClick = { open = true }, modifier = Modifier.testTag("exporter")) {
        Icon(
            Icons.Default.IosShare,
            stringResource(R.string.export_title),
            tint = Palette.textSecondary,
            modifier = Modifier.size(22.dp),
        )
    }
    DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
        Item(R.string.export_copy_fen, Icons.Default.GridOn, "export-fen") {
            open = false
            copy(context, fen(), context.getString(R.string.export_copied_fen))
        }
        if (hasGame) {
            Item(R.string.export_copy_pgn, Icons.Default.ContentCopy, "export-pgn") {
                open = false
                copy(context, pgn(), context.getString(R.string.export_copied_pgn))
            }
        }
        HorizontalDivider(color = Palette.stroke)
        Item(R.string.export_share_fen, Icons.Default.Share, "partager-fen") {
            open = false
            share(context, fen())
        }
        if (hasGame) {
            Item(R.string.export_share_pgn, Icons.Default.Share, "partager-pgn") {
                open = false
                share(context, pgn())
            }
        }
    }
}

@Composable
private fun Item(label: Int, icon: ImageVector, tag: String, onClick: () -> Unit) {
    DropdownMenuItem(
        text = { Text(stringResource(label), color = Palette.textPrimary) },
        leadingIcon = { Icon(icon, null, tint = Palette.textSecondary, modifier = Modifier.size(20.dp)) },
        onClick = onClick,
        modifier = Modifier.testTag(tag),
    )
}

private fun copy(context: Context, text: String, message: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
    clipboard.setPrimaryClip(ClipData.newPlainText("ChessLab", text))
    // Depuis Android 13 le système affiche lui-même la confirmation de copie :
    // en ajouter une seconde ferait double emploi.
    if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.TIRAMISU) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }
}

private fun share(context: Context, text: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
    }
    context.startActivity(Intent.createChooser(intent, context.getString(R.string.export_title)))
}
