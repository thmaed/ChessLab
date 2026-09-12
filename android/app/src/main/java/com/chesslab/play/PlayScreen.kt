package com.chesslab.play

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import com.chesslab.R
import com.chesslab.ui.*
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.TopBarActions

/**
 * L'écran de jeu. Pendant de `PlayView` (disposition iPhone).
 *
 * La forme vient d'iOS et elle a ses raisons : les lignes joueurs sont
 * COLLÉES au plateau — identité, pièces prises, avantage et pendule sur une
 * seule ligne chacune — et le plateau va de BORD À BORD, car c'est le seul
 * élément dont chaque point de largeur compte. Tout ce qui suit est à hauteur
 * fixe et toujours là : le plateau ne rétrécit donc pas quand la partie
 * avance.
 */
@Composable
fun PlayScreen(
    settings: PlayGameSettings? = null,
    resume: Boolean = false,
    /** La position envoyée par un autre mode : on joue À PARTIR D'ICI. */
    startFen: String? = null,
    onOpenTwoPlayer: (String) -> Unit = {},
    onAnalyze: (String) -> Unit = {},
    onAnalyzeGame: (String) -> Unit = {},
    onOpenLab: (String) -> Unit = {},
    model: PlayViewModel = viewModel(),
) {
    val ui = model.ui
    var showMoves by remember { mutableStateOf(false) }
    var confirmResign by remember { mutableStateOf(false) }

    LaunchedEffect(settings, resume, startFen) {
        when {
            resume -> model.resumeSaved()
            settings != null -> model.start(settings)
            // « Jouer à partir d'ici » : on reprend les DERNIERS réglages —
            // adversaire, niveau, cadence — et on n'impose que la position et
            // la couleur, celle du camp au trait. C'est ce que fait iOS.
            startFen != null -> model.start(
                model.ui.settings.copy(
                    startFen = startFen,
                    colorChoice = if (chesskit.Position.fromFen(startFen)?.sideToMove == Piece.Color.black)
                        PlayerColorChoice.black else PlayerColorChoice.white,
                )
            )
        }
    }

    // La position AFFICHÉE, et non celle du plateau : en consultation d'un
    // coup passé, c'est celle-là qu'on emporte ailleurs.
    TopBarActions {
        QuickSwitchMenu(
            onOpenTwoPlayer = { onOpenTwoPlayer(model.ui.position.fen) },
            onAnalyze = { onAnalyze(model.ui.position.fen) },
            onOpenLab = { onOpenLab(model.ui.position.fen) },
        )
    }

    // Le temps que le moteur se prépare, l'écran attend plutôt que de montrer
    // un plateau sur lequel on ne peut rien faire.
    if (!ui.started && !resume && startFen == null) {
        Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator(color = Palette.accent) }
        return
    }

    val opponentColor = ui.userColor.opposite
    // La marge est portée par CHAQUE élément, et non par la colonne : le
    // plateau est le seul qui n'en veut pas — il va de bord à bord, et chaque
    // point de largeur gagné est un point sur les 64 cases. (Compose refuse
    // une marge négative, là où SwiftUI l'accepte.)
    val gutter = Modifier.padding(horizontal = 12.dp)
    Column(Modifier.fillMaxSize().padding(vertical = 4.dp)) {
        PlayerRow(
            modifier = gutter,
            name = ui.opponent?.displayName(LocalContext.current) ?: stringResource(R.string.stockfish),
            color = opponentColor,
            active = !ui.gameOver && ui.position.sideToMove == opponentColor,
            captured = ui.captured.captures(opponentColor),
            advantage = ui.captured.advantage(opponentColor),
            clockMs = if (opponentColor == Piece.Color.white) ui.whiteClockMs else ui.blackClockMs,
            thinking = ui.thinking,
            tag = "joueur-adverse",
        )
        Spacer(Modifier.height(6.dp))

        Box(Modifier.fillMaxWidth()) {
            BoardView(
                position = ui.position,
                orientation = ui.userColor,
                selected = ui.selected,
                legalTargets = ui.legalTargets,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                // Pas de flèches en CONSULTATION d'un coup passé : elles
                // porteraient sur une position qu'on ne joue pas. Comme iOS.
                arrows = if (ui.isReviewing) emptyList() else ui.hints,
                enabled = !ui.thinking && !ui.gameOver,
                onSquareTap = model::onSquareTap,
            )
        }

        Spacer(Modifier.height(6.dp))
        PlayerRow(
            modifier = gutter,
            name = stringResource(R.string.you),
            color = ui.userColor,
            active = !ui.gameOver && ui.position.sideToMove == ui.userColor,
            captured = ui.captured.captures(ui.userColor),
            advantage = ui.captured.advantage(ui.userColor),
            clockMs = if (ui.userColor == Piece.Color.white) ui.whiteClockMs else ui.blackClockMs,
            tag = "joueur-vous",
        )

        Spacer(Modifier.height(8.dp))
        if (ui.gameOver) GameOverPanel(
            gutter, ui.outcome ?: ui.status,
            onAnalyze = { onAnalyzeGame(model.currentPgn()) },
            onNewGame = { model.newGame() },
        )
        else ControlBar(
            modifier = gutter,
            ui = ui,
            onPrevious = model::reviewPrevious,
            onNext = model::reviewNext,
            onResumeHere = model::reviewLive,
            onHint = { model.toggleHint() },
            onMoves = { showMoves = true },
            onDraw = { model.offerDraw() },
            onResign = { confirmResign = true },
        )

        Spacer(Modifier.height(6.dp))
        Text(
            ui.status, fontSize = 13.sp, color = Palette.textSecondary,
            modifier = gutter.testTag("statut"),
        )
    }

    if (ui.pendingPromotion != null) PromotionDialog(model::completePromotion)

    if (showMoves) {
        MoveListSheet(ui.sanMoves, ui.displayedPly) { showMoves = false }
    }

    if (confirmResign) {
        AlertDialog(
            onDismissRequest = { confirmResign = false },
            title = { Text(stringResource(R.string.play_resign)) },
            text = { Text(stringResource(R.string.play_resign_confirm)) },
            confirmButton = {
                TextButton(onClick = { confirmResign = false; model.resign() }, modifier = Modifier.testTag("abandonner-oui")) {
                    Text(stringResource(R.string.play_resign), color = Palette.danger)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmResign = false }) { Text(stringResource(R.string.cancel)) }
            },
            containerColor = Palette.surface,
        )
    }
}

/**
 * Une ligne joueur : la pastille de couleur, le nom, les pièces prises,
 * l'avantage, et la pendule. Elle s'allume quand c'est à ce camp de jouer.
 */
@Composable
private fun PlayerRow(
    modifier: Modifier = Modifier,
    name: String,
    color: Piece.Color,
    active: Boolean,
    captured: List<Piece.Kind>,
    advantage: Int,
    clockMs: Long?,
    tag: String,
    thinking: Boolean = false,
) {
    Row(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(if (active) Palette.surfaceElevated else Color.Transparent)
            .border(
                1.dp,
                if (active) Palette.accent.copy(alpha = 0.40f) else Color.Transparent,
                RoundedCornerShape(10.dp),
            )
            .padding(horizontal = 12.dp, vertical = 6.dp)
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(9.dp)
                .clip(CircleShape)
                .background(if (color == Piece.Color.white) Color.White else Color.Black)
                .border(1.dp, Palette.stroke, CircleShape)
        )
        Spacer(Modifier.width(7.dp))
        Text(
            name, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
            color = if (active) Palette.textPrimary else Palette.textSecondary,
        )
        if (thinking) {
            Spacer(Modifier.width(7.dp))
            CircularProgressIndicator(Modifier.size(13.dp), strokeWidth = 2.dp, color = Palette.warning)
        }
        Spacer(Modifier.width(8.dp))
        CapturedTray(captured, color.opposite, advantage)
        Spacer(Modifier.weight(1f))
        if (clockMs != null) {
            Text(
                GameClock.format(clockMs), fontSize = 19.sp, fontWeight = FontWeight.SemiBold,
                color = if (active) Palette.textPrimary else Palette.textTertiary,
                modifier = Modifier.testTag("$tag-pendule"),
            )
        }
    }
}

/** Les pièces prises, en petit, puis l'avantage de matériel s'il y en a. */
@Composable
private fun CapturedTray(kinds: List<Piece.Kind>, glyphColor: Piece.Color, advantage: Int) {
    if (kinds.isEmpty() && advantage <= 0) return
    Row(verticalAlignment = Alignment.CenterVertically) {
        kinds.forEach { kind ->
            Text(
                pieceGlyph(kind),
                fontSize = 13.sp,
                color = if (glyphColor == Piece.Color.white) Palette.textPrimary else Palette.textSecondary,
            )
        }
        if (advantage > 0) {
            Spacer(Modifier.width(4.dp))
            Text("+$advantage", fontSize = 12.sp, color = Palette.textSecondary)
        }
    }
}

/** Les figurines Unicode : elles disent la pièce sans charger une image. */
private fun pieceGlyph(kind: Piece.Kind): String = when (kind) {
    Piece.Kind.king -> "♚"
    Piece.Kind.queen -> "♛"
    Piece.Kind.rook -> "♜"
    Piece.Kind.bishop -> "♝"
    Piece.Kind.knight -> "♞"
    Piece.Kind.pawn -> "♟"
}

/**
 * La rangée de contrôle : à gauche la navigation dans la partie, à droite les
 * actions. Les boutons gardent leurs 46 dp — la cible tactile minimale — et
 * ce sont les ÉCARTS qui cèdent quand la place manque.
 */
@Composable
private fun ControlBar(
    modifier: Modifier = Modifier,
    ui: PlayUiState,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onResumeHere: () -> Unit,
    onHint: () -> Unit,
    onMoves: () -> Unit,
    onDraw: () -> Unit,
    onResign: () -> Unit,
) {
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        ControlButton(Icons.Default.ChevronLeft, stringResource(R.string.previous_move),
            enabled = ui.displayedPly > 0, tag = "precedent", onClick = onPrevious)
        Spacer(Modifier.width(10.dp))
        ControlButton(Icons.Default.ChevronRight, stringResource(R.string.next_move),
            enabled = ui.displayedPly < ui.totalPlies, tag = "suivant", onClick = onNext)

        if (ui.isReviewing) {
            Spacer(Modifier.width(10.dp))
            Text(
                stringResource(R.string.play_resume_here),
                fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Palette.accent)
                    .clickable(onClick = onResumeHere)
                    .padding(horizontal = 12.dp, vertical = 6.dp)
                    .testTag("reprendre-ici"),
            )
        }

        Spacer(Modifier.weight(1f))
        ControlButton(Icons.Default.Lightbulb, stringResource(R.string.train_hint),
            enabled = ui.settings.hintsEnabled && !ui.gameOver,
            tint = if (ui.hints.isNotEmpty()) Palette.accent else Palette.textPrimary,
            tag = "indice", onClick = onHint)
        if (!ui.isReviewing) {
            Spacer(Modifier.width(10.dp))
            ControlButton(Icons.AutoMirrored.Filled.List, stringResource(R.string.play_moves),
                tag = "coups-joues", onClick = onMoves)
        }
        Spacer(Modifier.width(10.dp))
        ControlButton(text = "½", label = stringResource(R.string.play_offer_draw),
            tint = Palette.info, enabled = !ui.gameOver && !ui.thinking, tag = "nulle", onClick = onDraw)
        Spacer(Modifier.width(10.dp))
        ControlButton(Icons.Default.Flag, stringResource(R.string.play_resign),
            tint = Palette.danger, enabled = !ui.gameOver, tag = "abandonner", onClick = onResign)
    }
}

@Composable
private fun ControlButton(
    icon: ImageVector? = null,
    label: String,
    text: String? = null,
    tint: Color = Palette.textPrimary,
    enabled: Boolean = true,
    tag: String,
    onClick: () -> Unit,
) {
    Box(
        Modifier
            .size(46.dp)
            .clip(CircleShape)
            .background(Palette.surfaceElevated)
            .border(1.dp, Palette.stroke, CircleShape)
            .clickable(enabled = enabled, onClick = onClick)
            .testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        val colour = if (enabled) tint else Palette.textTertiary
        if (text != null) Text(text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = colour)
        else if (icon != null) Icon(icon, label, tint = colour, modifier = Modifier.size(21.dp))
    }
}

/** Le panneau de fin : le mot de la fin, et de quoi recommencer. */
@Composable
private fun GameOverPanel(
    modifier: Modifier,
    message: String,
    onAnalyze: () -> Unit,
    onNewGame: () -> Unit,
) {
    Row(
        modifier
            .fillMaxWidth()
            .clip(ControlShape)
            .background(Palette.surfaceElevated)
            .subtleBorder(ControlShape)
            .padding(14.dp)
            .testTag("fin-de-partie"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(message, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
            color = Palette.textPrimary, modifier = Modifier.weight(1f))
        Spacer(Modifier.width(12.dp))
        // « Analyser » mène la partie qu'on vient de jouer vers son bilan :
        // c'est le moment où on veut savoir ce qui s'est passé.
        Text(
            stringResource(R.string.route_analysis),
            fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.teal,
            modifier = Modifier
                .clip(CircleShape)
                .border(1.dp, Palette.teal.copy(alpha = 0.5f), CircleShape)
                .clickable(onClick = onAnalyze)
                .padding(horizontal = 14.dp, vertical = 8.dp)
                .testTag("analyser-la-partie"),
        )
        Spacer(Modifier.width(8.dp))
        Text(
            stringResource(R.string.new_game),
            fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
            modifier = Modifier
                .clip(CircleShape)
                .background(accentGradient)
                .clickable(onClick = onNewGame)
                .padding(horizontal = 14.dp, vertical = 8.dp)
                .testTag("nouvelle"),
        )
    }
}

/** La liste des coups, en feuille : deux colonnes par numéro. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MoveListSheet(moves: List<String>, currentPly: Int, onClose: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onClose, containerColor = Palette.surface) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp)) {
            Text(stringResource(R.string.play_moves), fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
            Spacer(Modifier.height(12.dp))
            if (moves.isEmpty()) {
                Text(stringResource(R.string.no_moves_played), fontSize = 13.sp, color = Palette.textSecondary)
            } else {
                Column(Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState())) {
                    moves.chunked(2).forEachIndexed { index, pair ->
                        Row(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
                            Text("${index + 1}.", fontSize = 13.sp, color = Palette.textTertiary,
                                modifier = Modifier.width(34.dp))
                            pair.forEachIndexed { half, san ->
                                val ply = index * 2 + half + 1
                                Text(
                                    FigurineSan.format(san), fontSize = 14.sp,
                                    fontWeight = if (ply == currentPly) FontWeight.Bold else FontWeight.Normal,
                                    color = if (ply == currentPly) Palette.accent else Palette.textPrimary,
                                    modifier = Modifier.weight(1f).testTag("coup-${ply - 1}"),
                                )
                            }
                            if (pair.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun PromotionDialog(onPick: (Piece.Kind) -> Unit) {
    AlertDialog(
        onDismissRequest = { onPick(Piece.Kind.queen) },
        title = { Text(stringResource(R.string.theme_promotion)) },
        text = { Text(stringResource(R.string.promote_to)) },
        confirmButton = {
            Row {
                listOf(
                    Piece.Kind.queen to R.string.piece_queen,
                    Piece.Kind.rook to R.string.piece_rook,
                    Piece.Kind.bishop to R.string.piece_bishop,
                    Piece.Kind.knight to R.string.piece_knight,
                ).forEach { (kind, label) ->
                    TextButton(onClick = { onPick(kind) }) { Text(stringResource(label)) }
                }
            }
        },
        containerColor = Palette.surface,
    )
}
