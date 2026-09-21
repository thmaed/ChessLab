package com.chesslab.variants

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import com.chesslab.R
import com.chesslab.play.BlunderSeverity
import com.chesslab.play.GameClock
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.ControlButton
import com.chesslab.ui.EvalBar
import com.chesslab.ui.Palette
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.StatusRow
import com.chesslab.ui.TopBarActions

/**
 * Le Duck Chess : un tour en DEUX temps, et un canard qui bloque une case.
 * Pendant réduit de `DuckChessPlayView.swift`.
 *
 * Les cases où le canard peut se poser s'allument comme des cases de
 * destination : c'est le même geste que jouer une pièce, et c'est ce qui rend
 * un tour en deux temps évident sans l'expliquer.
 */
@Composable
fun DuckChessScreen(
    settings: VariantSettings = VariantSettings(),
    onAnalyze: (String) -> Unit = {},
    /** Revoir la partie : les POSITIONS, pas les coups — le canard n'est dans aucun coup. */
    onReviewGame: (List<String>, List<String>, List<String>) -> Unit = { _, _, _ -> },
    model: DuckChessViewModel = viewModel(),
) {
    LaunchedEffect(settings) { model.apply(settings) }
    val ui = model.ui
    var confirmResign by remember { mutableStateOf(false) }

    DisposableEffect(Unit) {
        model.resumeFromBackground()
        onDispose { model.pauseForBackground() }
    }

    TopBarActions {
        QuickSwitchMenu(onAnalyze = { onAnalyze(ui.position.fen) })
    }

    BoardScaffold(
        header = {
            // Les règles se lisent sur l'écran de RÉGLAGES, avant de lancer la
            // partie — aucun écran de jeu iOS ne les répète. Elles prenaient
            // ici trois lignes au plateau, à chaque coup, pour rien.
            StatusRow(ui.status, busy = ui.thinking)
            Spacer(Modifier.height(8.dp))
            DuckPlayerRow(ui, top = true)
        },
        board = {
            BoardView(
                position = ui.position,
                orientation = ui.userColor,
                selected = ui.selected,
                // Les cases du canard s'allument comme des destinations : le
                // geste est le même, et la phase se lit sans un mot.
                legalTargets = if (ui.phase == DuckPhase.placeDuck) ui.duckTargets else ui.legalTargets,
                lastMove = ui.lastMove,
                duck = ui.duck,
                arrows = ui.hints,
                draggableColor = ui.position.sideToMove,
                enabled = !ui.thinking && !ui.gameOver,
                onSquareTap = model::onSquareTap,
            )
        },
        panel = {
            if (ui.settings.showEvalBar && ui.versusEngine) {
                Spacer(Modifier.height(6.dp))
                EvalBar(cp = ui.evalCp, mate = ui.evalMate)
            }
            Spacer(Modifier.height(6.dp))
            DuckPlayerRow(ui, top = false)
            Spacer(Modifier.height(4.dp))
            Text(
                pluralStringResource(R.plurals.variant_halfmoves, ui.plies, ui.plies),
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("compteur"),
            )
            Spacer(Modifier.height(6.dp))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                ControlButton(
                    Icons.Default.Lightbulb, stringResource(R.string.train_hint),
                    // L'indice vient du moteur : à deux, il n'y en a pas — et
                    // il soufflerait le coup à celui qui n'a pas le trait.
                    enabled = ui.settings.hintsEnabled && ui.versusEngine && !ui.gameOver,
                    tint = if (ui.hintWanted) Palette.background else Palette.textPrimary,
                    background = if (ui.hintWanted) Palette.accent else Palette.surfaceElevated,
                    tag = "indice", onClick = model::toggleHint,
                )
                Spacer(Modifier.weight(1f))
                ControlButton(
                    text = "½", label = stringResource(R.string.play_offer_draw),
                    tint = Palette.info, enabled = !ui.gameOver && !ui.thinking,
                    tag = "nulle", onClick = model::offerDraw,
                )
                Spacer(Modifier.width(10.dp))
                ControlButton(
                    Icons.Default.Flag, stringResource(R.string.play_resign),
                    tint = Palette.danger, enabled = !ui.gameOver,
                    tag = "abandonner", onClick = { confirmResign = true },
                )
            }
            Spacer(Modifier.height(8.dp))
            if (ui.gameOver) {
                Row(
                    Modifier.fillMaxWidth().testTag("fin-de-partie"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
                        Text(stringResource(R.string.new_game), color = Palette.accent)
                    }
                    Spacer(Modifier.weight(1f))
                    TextButton(
                        onClick = { onReviewGame(model.analysisFens(), model.analysisMoves(), model.analysisSans()) },
                        enabled = model.analysisMoves().isNotEmpty(),
                        modifier = Modifier.testTag("analyser-la-partie"),
                    ) {
                        Text(stringResource(R.string.route_analysis), color = Palette.teal)
                    }
                }
            } else {
                TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
                    Text(stringResource(R.string.new_game), color = Palette.accent)
                }
            }
        },
    )

    if (confirmResign) {
        AlertDialog(
            onDismissRequest = { confirmResign = false },
            title = { Text(stringResource(R.string.play_resign)) },
            text = { Text(stringResource(R.string.play_resign_confirm)) },
            confirmButton = {
                // À deux sur le même appareil, « abandonner » ne dit pas de
                // quel côté : on nomme les deux camps, comme iOS.
                if (ui.versusEngine) {
                    TextButton(
                        onClick = { confirmResign = false; model.resign() },
                        modifier = Modifier.testTag("abandonner-oui"),
                    ) { Text(stringResource(R.string.play_resign), color = Palette.danger) }
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        TextButton(
                            onClick = { confirmResign = false; model.resign(Piece.Color.white) },
                            modifier = Modifier.testTag("abandonner-blancs"),
                        ) { Text(stringResource(R.string.color_white), color = Palette.danger) }
                        TextButton(
                            onClick = { confirmResign = false; model.resign(Piece.Color.black) },
                            modifier = Modifier.testTag("abandonner-noirs"),
                        ) { Text(stringResource(R.string.color_black), color = Palette.danger) }
                    }
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmResign = false }) { Text(stringResource(R.string.cancel)) }
            },
            containerColor = Palette.surface,
        )
    }

    // Le refus, dit une fois : sans cela il se perdrait dans la ligne d'état.
    if (ui.drawDeclined) {
        AlertDialog(
            onDismissRequest = model::dismissDrawDeclined,
            title = { Text(stringResource(R.string.play_draw_declined), color = Palette.textPrimary) },
            text = { Text(stringResource(R.string.play_draw_declined_body), color = Palette.textSecondary) },
            confirmButton = {
                TextButton(onClick = model::dismissDrawDeclined) {
                    Text(stringResource(android.R.string.ok), color = Palette.accent)
                }
            },
            containerColor = Palette.surfaceElevated,
        )
    }

    ui.blunderWarning?.let { severity ->
        val message = when (severity) {
            is BlunderSeverity.MissedMate -> stringResource(R.string.blunder_missed_mate)
            is BlunderSeverity.AllowsMate -> stringResource(R.string.blunder_allows_mate)
            is BlunderSeverity.Centipawns ->
                stringResource(R.string.blunder_centipawns, minOf(severity.drop, 1_000) / 100)
        }
        AlertDialog(
            onDismissRequest = model::dismissBlunderWarning,
            title = { Text(stringResource(R.string.blunder_title), color = Palette.textPrimary) },
            text = { Text(message, color = Palette.textSecondary, modifier = Modifier.testTag("alerte-gaffe")) },
            // Pas de « reprendre » ici : un tour de Duck Chess se joue en deux
            // temps, et défaire la moitié d'un tour laisserait le canard posé
            // sur une case qui n'existe plus dans la partie.
            confirmButton = {
                TextButton(onClick = model::dismissBlunderWarning) {
                    Text(stringResource(android.R.string.ok), color = Palette.accent)
                }
            },
            containerColor = Palette.surfaceElevated,
        )
    }
}

/** La pendule d'un camp — celle d'en face au-dessus, la nôtre en dessous. */
/**
 * Le bandeau d'un joueur : qui c'est, s'il réfléchit, sa pendule.
 *
 * Il ne portait qu'une pendule — et disparaissait tout entier SANS cadence :
 * l'écran ne disait alors nulle part qui jouait quoi. C'est le défaut déjà
 * corrigé le 20/09 sur l'écran partagé des variantes, que le Duck Chess avait
 * gardé faute d'y passer.
 */
@Composable
private fun DuckPlayerRow(ui: DuckUiState, top: Boolean) {
    val color = if (top) ui.userColor.opposite else ui.userColor
    val isEngine = ui.versusEngine && color != ui.userColor
    val ms = if (color == Piece.Color.white) ui.whiteClockMs else ui.blackClockMs
    val active = ui.position.sideToMove == color && !ui.gameOver
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (active) Palette.surfaceElevated else Palette.surface)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .testTag(if (top) "joueur-adversaire" else "joueur-moi"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            if (isEngine) Icons.Default.Memory else Icons.Default.Person,
            // Décoratif : le texte juste après porte déjà l'information.
            contentDescription = null,
            tint = if (isEngine) variantTint("duck") else Palette.info,
            modifier = Modifier.size(16.dp),
        )
        Spacer(Modifier.width(8.dp))
        Text(
            // À deux sur le même appareil, personne n'est « l'ordinateur » ni
            // « vous » : c'est la couleur qui désigne le joueur.
            if (!ui.versusEngine) stringResource(
                if (color == Piece.Color.white) R.string.color_white else R.string.color_black
            ) else stringResource(
                if (isEngine) R.string.variant_player_engine else R.string.variant_player_you
            ),
            fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
        )
        if (isEngine && ui.thinking) {
            Spacer(Modifier.width(8.dp))
            CircularProgressIndicator(
                Modifier.size(12.dp), strokeWidth = 2.dp, color = Palette.textSecondary,
            )
        }
        Spacer(Modifier.weight(1f))
        if (ms != null) {
            Text(
                GameClock.format(ms),
                fontSize = 19.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace,
                color = when {
                    ms < 30_000 -> Palette.danger
                    active -> Palette.textPrimary
                    else -> Palette.textTertiary
                },
                modifier = Modifier.testTag(if (top) "pendule-adversaire" else "pendule-moi"),
            )
        }
    }
}
