package com.chesslab.variants

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import com.chesslab.R
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.Palette
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.StatusRow
import com.chesslab.ui.TopBarActions
import com.chesslab.ui.accentGradient

/**
 * Le Coup Volé : un jeton tous les N coups, et deux coups d'affilée quand on
 * le dépense. Pendant réduit de `StolenMovePlayView.swift`.
 *
 * Le jeton se DÉPENSE avant de jouer, pas après : c'est une annonce, et
 * l'écran la reprend dans son statut pour qu'on sache où l'on en est dans un
 * tour qui, ce coup-là, n'a pas la forme habituelle.
 */
@Composable
fun StolenMoveScreen(
    onAnalyze: (String) -> Unit = {},
    model: StolenMoveViewModel = viewModel(),
) {
    val ui = model.ui

    TopBarActions {
        QuickSwitchMenu(onAnalyze = { onAnalyze(ui.position.fen) })
    }

    BoardScaffold(
        header = {
            Text(
                stringResource(R.string.variant_stolen_blurb, ui.tokenInterval),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
            Spacer(Modifier.height(6.dp))
            StatusRow(ui.status, busy = ui.thinking)
            Spacer(Modifier.height(8.dp))
        },
        board = {
            BoardView(
                position = ui.position,
                selected = ui.selected,
                legalTargets = ui.legalTargets,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                enabled = ui.outcome == null && !ui.thinking && ui.mover == Piece.Color.white,
                onSquareTap = model::onSquareTap,
            )
        },
        panel = {
            Spacer(Modifier.height(10.dp))

            // Le jeton : ce que l'on a, et ce qu'on peut en faire. Rien du tout
            // quand on n'en a pas — une ligne grise qui dit « aucun jeton »
            // occupe autant de place qu'une qui en annonce un.
            if ((ui.tokens[Piece.Color.white] ?: 0) > 0) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.testTag("jeton"),
                ) {
                    Icon(Icons.Default.Bolt, null, tint = Palette.gold, modifier = Modifier.size(18.dp))
                    Text(
                        stringResource(R.string.stolen_token), fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold, color = Palette.gold,
                    )
                    if (model.canSpendNow) {
                        Text(
                            stringResource(R.string.stolen_spend),
                            fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                            modifier = Modifier
                                .clip(CircleShape)
                                .background(accentGradient)
                                .clickable(onClick = model::spendToken)
                                .padding(horizontal = 14.dp, vertical = 7.dp)
                                .testTag("depenser"),
                        )
                    }
                }
                Spacer(Modifier.height(10.dp))
            }

            Text(
                pluralStringResource(R.plurals.variant_halfmoves, ui.sanMoves.size, ui.sanMoves.size),
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("compteur"),
            )

            // Le rythme des jetons, réglable de 4 à 8 comme sur iOS. Changer
            // le réglage recommence la partie : le compte des coups serait
            // faux à cheval sur deux intervalles.
            Spacer(Modifier.height(10.dp))
            Text(
                stringResource(R.string.stolen_interval, ui.tokenInterval),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
            Spacer(Modifier.height(4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                StolenMoveRules.tokenIntervalRange.forEach { value ->
                    val active = value == ui.tokenInterval
                    Text(
                        "$value", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                        color = if (active) Palette.background else Palette.textSecondary,
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(if (active) Palette.accent else Palette.surfaceElevated)
                            .clickable { model.setInterval(value) }
                            .padding(horizontal = 12.dp, vertical = 6.dp)
                            .testTag("intervalle-$value"),
                    )
                }
            }

            TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
                Text(stringResource(R.string.new_game), color = Palette.accent)
            }
        },
    )
}
