package com.chesslab.variants

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.FirstPage
import androidx.compose.material.icons.filled.LastPage
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.R
import com.chesslab.analysis.EvalCurve
import com.chesslab.analysis.MoveQuality
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.EvalBar
import com.chesslab.ui.ExportMenu
import com.chesslab.ui.TopBarActions
import com.chesslab.ui.MoveStrip
import com.chesslab.ui.BoardView
import com.chesslab.ui.Palette

/**
 * Revoir une partie de VARIANTE. Pendant de `VariantAnalysisView`.
 *
 * Volontairement plus simple que l'analyse orthodoxe — ni ouvertures, ni
 * puzzles, ni coups candidats : aucune théorie ne porte sur ces jeux. On
 * navigue, on lit l'évaluation que Fairy-Stockfish rend POUR CETTE VARIANTE,
 * et les pastilles disent où la partie a basculé.
 */
@Composable
fun VariantAnalysisScreen(
    variantId: String,
    startFen: String?,
    uciLog: List<String>,
    /** Les positions, quand les coups ne les reproduisent pas (canard, tour double). */
    fenLog: List<String> = emptyList(),
    /** La notation, quand la partie l'a écrite en la jouant. */
    sanLog: List<String> = emptyList(),
    model: VariantAnalysisViewModel = viewModel(),
) {
    LaunchedEffect(variantId, startFen, uciLog, fenLog) {
        model.load(variantId, startFen, uciLog, fenLog, sanLog)
    }
    val ui = model.ui

    // Copier ou partager, comme iOS le propose depuis la barre du haut de cet
    // écran : une partie qui ne sort pas de l'app n'existe que là.
    TopBarActions {
        ExportMenu(
            fen = model::displayedFen,
            pgn = model::exportedPgn,
            hasGame = ui.sanMoves.isNotEmpty(),
        )
    }

    BoardScaffold(
        header = {
            com.chesslab.ui.ThermalBadge()
            if (ui.engineUnavailable) {
                Text(
                    stringResource(R.string.play_engine_down),
                    fontSize = 12.sp, color = Palette.danger,
                    modifier = Modifier.testTag("moteur-absent"),
                )
                Spacer(Modifier.height(8.dp))
            }
            // La barre d'évaluation JUSTE au-dessus du plateau, et le score
            // écrit dedans — comme iOS. Le nom de la variante est dans le
            // titre (« Analyse — Horde »), et le score n'est plus répété en
            // ligne d'état : deux fois le même chiffre à deux endroits, c'est
            // un de trop.
            EvalBar(cp = ui.evalCp, mate = ui.evalMate)
            Spacer(Modifier.height(8.dp))
        },
        board = {
            BoardView(
                position = ui.position,
                lastMove = ui.lastMove,
                walls = ui.walls,
                qualityBadge = ui.qualityBadge,
                enabled = false,
            )
        },
        panel = {
            Spacer(Modifier.height(10.dp))
            NavigationCard(ui, model)


            // La courbe d'évaluation, comme en mode « Contre l'ordinateur » :
            // elle dit d'un coup d'œil OÙ la partie a basculé, et un appui y
            // saute directement. Dans une carte, comme la liste des coups juste
            // dessous — posée à nu sur le fond, elle avait l'air d'un reste de
            // mise en page. Le rembourrage horizontal dégage aussi le repère de
            // position au tout premier et au tout dernier coup, sinon collé au
            // bord et coupé en deux.
            if (ui.curve.size > 1) {
                Spacer(Modifier.height(10.dp))
                Box(
                    Modifier
                        .fillMaxWidth()
                        .clip(com.chesslab.ui.CardShape)
                        .background(Palette.surface)
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    EvalCurve(ui.curve, currentPly = ui.displayedPly, onSelect = model::goTo)
                }
            }

            AccuracyCard(ui)

            Spacer(Modifier.height(10.dp))
            // La MÊME bande qu'en analyse orthodoxe : capsules, bordure de la
            // catégorie, coup courant en dégradé d'accent. iOS partage aussi
            // ce langage entre ses deux écrans (`VariantMoveStripView`).
            MoveStrip(
                moves = ui.sanMoves,
                selected = (ui.displayedPly - 1).takeIf { it >= 0 },
                qualities = ui.qualities,
                onSelect = { model.goTo(it + 1) },
            )
            Spacer(Modifier.height(12.dp))
        },
    )
}

/**
 * La barre de navigation, dans une carte — pendant du `navigationBar` d'iOS.
 *
 * Le compteur « 4 / 10 » est AU MILIEU, entre les deux paires de flèches : il
 * dit où l'on en est sans qu'on ait à compter les capsules, et la progression
 * de la passe vient se loger à côté de lui plutôt que sur une ligne à elle.
 */
@Composable
private fun NavigationCard(ui: VariantAnalysisUiState, model: VariantAnalysisViewModel) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(com.chesslab.ui.CardShape)
            .background(Palette.surface)
            .padding(horizontal = 4.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(
            onClick = model::toStart, enabled = ui.canGoPrevious,
            modifier = Modifier.testTag("debut"),
        ) { Icon(Icons.Default.FirstPage, stringResource(R.string.two_first_move), tint = Palette.textPrimary) }
        IconButton(
            onClick = model::previous, enabled = ui.canGoPrevious,
            modifier = Modifier.testTag("precedent"),
        ) { Icon(Icons.Default.ChevronLeft, stringResource(R.string.previous_move), tint = Palette.textPrimary) }

        Spacer(Modifier.weight(1f))
        if (ui.classifying) {
            CircularProgressIndicator(
                Modifier.size(12.dp), strokeWidth = 2.dp, color = Palette.textTertiary,
            )
            Spacer(Modifier.width(6.dp))
            Text(
                "${ui.done}/${ui.total}",
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("revue-en-cours"),
            )
            Spacer(Modifier.width(8.dp))
        } else if (ui.thinking) {
            CircularProgressIndicator(
                Modifier.size(12.dp), strokeWidth = 2.dp, color = Palette.textSecondary,
            )
            Spacer(Modifier.width(8.dp))
        }
        Text(
            "${ui.displayedPly} / ${ui.totalPlies}",
            fontSize = 13.sp, fontFamily = FontFamily.Monospace, color = Palette.textSecondary,
            modifier = Modifier.testTag("compteur-demi-coups"),
        )
        Spacer(Modifier.weight(1f))

        IconButton(
            onClick = model::next, enabled = ui.canGoNext,
            modifier = Modifier.testTag("suivant"),
        ) { Icon(Icons.Default.ChevronRight, stringResource(R.string.next_move), tint = Palette.textPrimary) }
        IconButton(
            onClick = model::toEnd, enabled = ui.canGoNext,
            modifier = Modifier.testTag("fin"),
        ) { Icon(Icons.Default.LastPage, stringResource(R.string.two_last_move), tint = Palette.textPrimary) }
    }
}

/**
 * La précision de chaque camp, une fois les premiers coups jugés.
 *
 * Elle vaut ce que vaut l'évaluation dont elle sort, approximative dans la
 * plupart des variantes — c'est la même approximation que les pastilles de
 * qualité juste à côté, et montrer les deux vaut mieux que n'en montrer
 * qu'une.
 */
@Composable
private fun AccuracyCard(ui: VariantAnalysisUiState) {
    if (ui.accuracyWhite == null && ui.accuracyBlack == null) return
    Spacer(Modifier.height(10.dp))
    Row(
        Modifier
            .fillMaxWidth()
            .clip(com.chesslab.ui.CardShape)
            .background(Palette.surface)
            .padding(horizontal = 14.dp, vertical = 8.dp)
            .testTag("precision"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        listOf(true to ui.accuracyWhite, false to ui.accuracyBlack).forEach { (white, score) ->
            if (score == null) return@forEach
            Row(
                Modifier.padding(end = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // La pastille dit DE QUEL CAMP on parle sans un mot — et il
                // faut la cercler, sinon celle des Noirs disparaît dans le fond.
                Box(
                    Modifier
                        .size(11.dp)
                        .clip(CircleShape)
                        .background(if (white) Color.White else Color.Black)
                        .border(1.dp, Palette.strokeStrong, CircleShape)
                )
                Spacer(Modifier.width(9.dp))
                Column {
                    Text(
                        "${kotlin.math.round(score).toInt()}%",
                        fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary,
                    )
                    Text(
                        stringResource(R.string.variant_accuracy_caption),
                        fontSize = 10.sp, color = Palette.textSecondary,
                    )
                }
            }
        }
    }
}
