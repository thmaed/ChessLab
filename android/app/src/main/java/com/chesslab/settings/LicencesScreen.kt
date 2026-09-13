package com.chesslab.settings

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Category
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.DeveloperBoard
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.Face
import androidx.compose.material.icons.filled.Hub
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.ui.CardShape
import com.chesslab.ui.IconBadge
import com.chesslab.ui.Palette
import com.chesslab.ui.cardGradient
import com.chesslab.ui.subtleBorder

/**
 * Un composant tiers embarqué dans l'app : ce qu'il fait, sous quelle
 * licence, et où le trouver. [id] sert aux tests et aux étiquettes.
 */
data class LicenceEntry(
    val id: String,
    val icon: ImageVector,
    val tint: Color,
    @StringRes val name: Int,
    @StringRes val licence: Int,
    @StringRes val body: Int,
    val url: String,
)

/**
 * Les licences des composants tiers embarqués dans ChessLab. Pendant de
 * `LicensesView.swift`.
 *
 * La liste existe pour deux raisons à la fois : honorer l'attribution
 * requise par la CC BY-SA des pièces cburnett, et rendre VISIBLES — donc
 * difficiles à ignorer en revue — les mentions GPLv3 de Stockfish et de
 * Fairy-Stockfish (voir `PUBLIER.md` §0 pour les obligations). Deux entrées
 * n'existent que sur Android parce que le binaire Android seul les embarque :
 * ONNX Runtime, qui exécute les réseaux là où iOS s'en remet à Core ML, et
 * le détecteur du scanner, un YOLO11 sous AGPLv3 comme Maia-3.
 */
object Licences {
    val entries: List<LicenceEntry> = listOf(
        LicenceEntry(
            "stockfish", Icons.Default.Memory, Palette.accent,
            R.string.lic_stockfish_name, R.string.lic_gplv3, R.string.lic_stockfish_body,
            "https://stockfishchess.org",
        ),
        LicenceEntry(
            "fairy", Icons.Default.Casino, Palette.violet,
            R.string.lic_fairy_name, R.string.lic_gplv3, R.string.lic_fairy_body,
            "https://fairy-stockfish.github.io",
        ),
        LicenceEntry(
            "maia", Icons.Default.Face, Palette.teal,
            R.string.lic_maia_name, R.string.lic_agplv3, R.string.lic_maia_body,
            "https://github.com/CSSLab/maia3",
        ),
        LicenceEntry(
            "yolo", Icons.Default.PhotoCamera, Palette.accentSecondary,
            R.string.lic_yolo_name, R.string.lic_agplv3, R.string.lic_yolo_body,
            "https://github.com/ultralytics/ultralytics",
        ),
        LicenceEntry(
            "source", Icons.Default.Code, Palette.info,
            R.string.lic_source_name, R.string.lic_gplv3_whole, R.string.lic_source_body,
            "https://github.com/thmaed/ChessLab",
        ),
        LicenceEntry(
            "chesskit", Icons.Default.Inventory2, Palette.teal,
            R.string.lic_chesskit_name, R.string.lic_mit, R.string.lic_chesskit_body,
            "https://github.com/chesskit-app/chesskit-swift",
        ),
        LicenceEntry(
            "cburnett", Icons.Default.Category, Palette.warning,
            R.string.lic_cburnett_name, R.string.lic_ccbysa, R.string.lic_cburnett_body,
            "https://commons.wikimedia.org/wiki/User:Cburnett",
        ),
        LicenceEntry(
            "chessnut", Icons.Default.Category, Palette.warning,
            R.string.lic_chessnut_name, R.string.lic_apache, R.string.lic_chessnut_body,
            "https://github.com/LexLuengas/chessnut-pieces",
        ),
        LicenceEntry(
            "merida", Icons.Default.Category, Palette.warning,
            R.string.lic_merida_name, R.string.lic_gplv2plus, R.string.lic_merida_body,
            "https://github.com/lichess-org/lila/tree/master/public/piece/merida",
        ),
        LicenceEntry(
            "puzzles", Icons.Default.Extension, Palette.violet,
            R.string.lic_puzzles_name, R.string.lic_cc0, R.string.lic_puzzles_body,
            "https://database.lichess.org/#puzzles",
        ),
        LicenceEntry(
            "nnue", Icons.Default.Hub, Palette.rose,
            R.string.lic_nnue_name, R.string.lic_gplv3, R.string.lic_nnue_body,
            "https://tests.stockfishchess.org",
        ),
        LicenceEntry(
            "onnx", Icons.Default.DeveloperBoard, Palette.gold,
            R.string.lic_onnx_name, R.string.lic_mit, R.string.lic_onnx_body,
            "https://onnxruntime.ai",
        ),
    )

    /**
     * Le lien est confié au navigateur, et seulement quand on le touche.
     * L'app, elle, ne déclare pas la permission réseau et n'en a pas besoin
     * pour cela : c'est la même chose qu'un `Link` SwiftUI. Sans navigateur,
     * l'adresse reste lisible à l'écran.
     */
    fun open(context: Context, url: String) {
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        } catch (_: ActivityNotFoundException) {
        }
    }
}

/** L'écran Licences : une carte par composant, comme sur iOS. */
@Composable
fun LicencesScreen() {
    val context = LocalContext.current
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            stringResource(R.string.licences_intro),
            fontSize = 13.sp, color = Palette.textSecondary,
            modifier = Modifier.padding(bottom = 2.dp),
        )
        Licences.entries.forEach { entry ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(CardShape)
                    .background(cardGradient)
                    .subtleBorder()
                    .padding(14.dp)
                    .testTag("licence-${entry.id}"),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                IconBadge(entry.icon, entry.tint, 42.dp)
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        stringResource(entry.name), fontSize = 15.sp,
                        fontWeight = FontWeight.Bold, color = Palette.textPrimary,
                    )
                    Text(
                        stringResource(entry.licence), fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold, color = entry.tint,
                    )
                    Text(
                        stringResource(entry.body), fontSize = 13.sp, color = Palette.textSecondary,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                    Text(
                        entry.url, fontSize = 11.sp, color = Palette.accent,
                        maxLines = 1, overflow = TextOverflow.Ellipsis,
                        modifier = Modifier
                            .padding(top = 2.dp)
                            .clickable { Licences.open(context, entry.url) }
                            .testTag("lien-${entry.id}"),
                    )
                }
            }
        }
        Spacer(Modifier.height(12.dp))
    }
}
