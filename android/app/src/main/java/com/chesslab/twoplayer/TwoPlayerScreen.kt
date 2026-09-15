package com.chesslab.twoplayer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.FirstPage
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.LastPage
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import com.chesslab.ui.isLandscape
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import com.chesslab.R
import com.chesslab.play.GameClock
import com.chesslab.play.PromotionDialog
import com.chesslab.ui.Announce
import com.chesslab.ui.BoardView
import com.chesslab.ui.CelebrationOverlay
import com.chesslab.ui.ControlShape
import com.chesslab.ui.ExportMenu
import com.chesslab.ui.Palette
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.TopBarActions
import com.chesslab.ui.accentGradient
import com.chesslab.ui.sanText
import com.chesslab.ui.subtleBorder

/**
 * Une partie à deux sur le même appareil. Pendant de `TwoPlayerGameView`.
 *
 * L'ÉVALUATION et la NOTATION restent masquées pendant la partie : c'est le
 * parti pris d'iOS, et il a une raison — deux joueurs qui s'affrontent
 * n'arbitrent pas leur partie au moteur. La liste des coups se révèle sur
 * l'écran de résultat, quand il n'y a plus rien à décider.
 */
@Composable
fun TwoPlayerScreen(
    settings: TwoPlayerSettings? = null,
    resume: Boolean = false,
    /** La position envoyée par un autre mode. */
    startFen: String? = null,
    onPlayVsEngine: (String) -> Unit = {},
    onAnalyze: (String) -> Unit = {},
    onAnalyzeGame: (String) -> Unit = {},
    onOpenLab: (String) -> Unit = {},
    /** Revenir à l'accueil depuis le panneau de fin de partie. */
    onHome: () -> Unit = {},
    /** La revanche : mêmes réglages, couleurs échangées. */
    onRematch: (TwoPlayerSettings) -> Unit = {},
    model: TwoPlayerViewModel = viewModel(),
) {
    val ui = model.ui
    var confirmResign by remember { mutableStateOf(false) }
    var confirmDraw by remember { mutableStateOf(false) }

    // La partie ne se relance PAS en revenant sur l'écran : aller voir
    // l'analyse et revenir détruisait la partie en cours.
    LaunchedEffect(settings, resume, startFen) {
        if (ui.started && settings == null && !resume && startFen == null) return@LaunchedEffect
        when {
            resume -> model.resumeSaved()
            settings != null -> model.start(settings)
            startFen != null -> model.startFrom(startFen)
        }
    }

    // La pendule s'arrête quand l'écran s'en va ou que l'app passe derrière.
    // Sans cela, le drapeau tombait pendant qu'on regardait l'analyse ouverte
    // depuis le menu d'export.
    val owner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            when (event) {
                androidx.lifecycle.Lifecycle.Event.ON_PAUSE -> model.pauseForBackground()
                androidx.lifecycle.Lifecycle.Event.ON_RESUME -> model.resumeFromBackground()
                else -> Unit
            }
        }
        owner.lifecycle.addObserver(observer)
        onDispose {
            owner.lifecycle.removeObserver(observer)
            model.pauseForBackground()
        }
    }

    TopBarActions {
        ExportMenu(
            fen = { model.displayedFen() },
            pgn = { model.currentPgn() },
            hasGame = ui.hasGameToExport,
        )
        QuickSwitchMenu(
            onPlayVsEngine = { onPlayVsEngine(model.displayedFen()) },
            onAnalyze = { onAnalyze(model.displayedFen()) },
            onOpenLab = { onOpenLab(model.displayedFen()) },
        )
    }

    Announce(ui.announcement)

    val tabletop = ui.settings.rotation == TwoPlayerSettings.RotationMode.tabletop
    val top = ui.orientation.opposite
    val gutter = Modifier.padding(horizontal = 12.dp)

    // Le contenu ne s'écrit QU'UNE FOIS : seule la disposition change entre le
    // portrait (tout empilé) et le paysage (plateau à gauche, le reste à
    // droite). Empilé en paysage, tout ce qui suit le plateau passait sous la
    // ligne de flottaison — on ne pouvait plus ni abandonner ni consulter.
    val topZone: @Composable () -> Unit = {
        // En mode « autour d'une table », la zone du haut porte AUSSI les
        // commandes, le tout retourné à 180° : le joueur d'en face lit son
        // nom, sa pendule et ses boutons à l'endroit, sans jamais avoir à
        // faire tourner l'appareil.
        if (tabletop) {
            Column(Modifier.rotate(180f)) {
                PlayerRow(gutter, top, ui, model, "joueur-haut")
                Spacer(Modifier.height(8.dp))
                if (!ui.gameOver) {
                    ControlsBar(gutter, "haut", onResign = { confirmResign = true }) {
                        confirmDraw = true
                    }
                }
            }
        } else {
            PlayerRow(gutter, top, ui, model, "joueur-haut")
        }
    }
    val board: @Composable () -> Unit = {
        BoardView(
            position = ui.position,
            orientation = ui.orientation,
            selected = ui.selected,
            legalTargets = ui.legalTargets,
            lastMove = ui.lastMove,
            checkedKing = ui.checkedKing,
            // Les pièces se retournent quand c'est au joueur d'EN FACE de
            // jouer : c'est lui qui regarde le plateau à ce moment-là.
            piecesRotated = tabletop && !ui.isReviewing && ui.position.sideToMove == top,
            draggableColor = ui.position.sideToMove,
            enabled = !ui.gameOver && !ui.isReviewing,
            onSquareTap = model::onSquareTap,
        )
    }
    val below: @Composable () -> Unit = {
        PlayerRow(gutter, ui.orientation, ui, model, "joueur-bas")

        if (ui.totalPlies > 0) {
            Spacer(Modifier.height(8.dp))
            TransportBar(
                gutter, ui,
                onStart = model::reviewToStart,
                onPrevious = model::reviewPrevious,
                onPick = model::reviewTo,
                onNext = model::reviewNext,
                onLive = model::reviewToLive,
                onResumeHere = model::resumeFromReview,
                onCancelResume = model::cancelResumeFromReview,
            )
        }

        Spacer(Modifier.height(10.dp))
        if (ui.gameOver) {
            GameOverPanel(
                gutter,
                message = ui.outcome.orEmpty(),
                moves = ui.sanMoves,
                onHome = onHome,
                onAnalyze = { onAnalyzeGame(model.currentPgn()) },
                onRematch = { onRematch(model.rematchSettings()) },
            )
        } else {
            ControlsBar(gutter, "bas", onResign = { confirmResign = true }) { confirmDraw = true }
        }
    }

    Box(Modifier.fillMaxSize()) {
        if (isLandscape()) {
            Row(Modifier.fillMaxSize().padding(vertical = 4.dp)) {
                Box(Modifier.weight(1f).fillMaxHeight(), Alignment.Center) { board() }
                Column(
                    Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState()),
                ) {
                    topZone()
                    Spacer(Modifier.height(6.dp))
                    below()
                    Spacer(Modifier.height(20.dp))
                }
            }
        } else Column(Modifier.fillMaxSize().padding(vertical = 4.dp)) {
            topZone()
            Spacer(Modifier.height(6.dp))
            board()
            Spacer(Modifier.height(6.dp))
            below()
        }

        // Seuls les confettis passent PAR-DESSUS : le bilan s'affiche sous le
        // plateau, qui reste visible et consultable.
        if (ui.gameOver && ui.winner != null) CelebrationOverlay(Modifier.fillMaxSize())
    }

    if (ui.pendingPromotion != null) {
        PromotionDialog(
            onPick = model::completePromotion,
            onCancel = model::cancelPromotion,
            rotated = tabletop && ui.pendingPromotion.piece.color == top,
        )
    }

    // Qui abandonne ? Sur un appareil posé entre deux joueurs, la question
    // n'est pas rhétorique — c'est la réponse qui décide du résultat.
    if (confirmResign) {
        AlertDialog(
            onDismissRequest = { confirmResign = false },
            title = { Text(stringResource(R.string.two_who_resigns), color = Palette.textPrimary) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    listOf(
                        Piece.Color.white to model.whiteName(),
                        Piece.Color.black to model.blackName(),
                    ).forEach { (color, name) ->
                        Text(
                            "$name (${stringResource(if (color == Piece.Color.white) R.string.color_white else R.string.color_black)})",
                            color = Palette.danger, fontSize = 15.sp,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .clickable { confirmResign = false; model.resign(color) }
                                .padding(vertical = 10.dp)
                                .testTag("abandon-${color.name}"),
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { confirmResign = false }) {
                    Text(stringResource(R.string.cancel), color = Palette.textSecondary)
                }
            },
            containerColor = Palette.surface,
        )
    }

    if (confirmDraw) {
        AlertDialog(
            onDismissRequest = { confirmDraw = false },
            title = { Text(stringResource(R.string.two_draw_agree), color = Palette.textPrimary) },
            confirmButton = {
                TextButton(
                    onClick = { confirmDraw = false; model.agreeToDraw() },
                    modifier = Modifier.testTag("nulle-confirmer"),
                ) {
                    Text(stringResource(R.string.two_draw_confirm), color = Palette.accent)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmDraw = false }) {
                    Text(stringResource(R.string.cancel), color = Palette.textSecondary)
                }
            },
            containerColor = Palette.surface,
        )
    }
}

/** Une ligne joueur : la pastille du camp, son nom, ses prises, sa pendule. */
@Composable
private fun PlayerRow(
    modifier: Modifier,
    color: Piece.Color,
    ui: TwoPlayerUiState,
    model: TwoPlayerViewModel,
    tag: String,
) {
    val active = !ui.gameOver && ui.position.sideToMove == color
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
            // La ligne se lit d'un bloc : « Camille, 3:24 », et non trois
            // fragments que le lecteur d'écran annonce séparément.
            .semantics(mergeDescendants = true) {}
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
            if (color == Piece.Color.white) model.whiteName() else model.blackName(),
            fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
            color = if (active) Palette.textPrimary else Palette.textTertiary,
        )
        Spacer(Modifier.width(8.dp))
        val kinds = ui.captured.captures(color)
        if (kinds.isNotEmpty()) {
            Text(
                kinds.joinToString("") { glyph(it) },
                fontSize = 13.sp, color = Palette.textSecondary,
            )
        }
        val advantage = ui.captured.advantage(color)
        if (advantage > 0) {
            Spacer(Modifier.width(4.dp))
            Text("+$advantage", fontSize = 12.sp, color = Palette.textSecondary)
        }
        Spacer(Modifier.weight(1f))
        val millis = if (color == Piece.Color.white) ui.whiteClockMs else ui.blackClockMs
        if (millis != null) {
            Text(
                GameClock.format(millis),
                fontSize = 19.sp, fontWeight = FontWeight.SemiBold,
                fontFamily = FontFamily.Monospace,
                color = when {
                    millis < 10_000 -> Palette.danger
                    active -> Palette.textPrimary
                    else -> Palette.textTertiary
                },
                modifier = Modifier.testTag("pendule-${color.name}"),
            )
        }
    }
}

/**
 * La barre de transport : on remonte la partie sans la toucher, et
 * « Reprendre ici » la relance depuis le coup consulté — hors pendule, car
 * on ne rend pas du temps déjà écoulé.
 */
@Composable
private fun TransportBar(
    modifier: Modifier,
    ui: TwoPlayerUiState,
    onStart: () -> Unit,
    onPrevious: () -> Unit,
    onPick: (Int) -> Unit,
    onNext: () -> Unit,
    onLive: () -> Unit,
    onResumeHere: () -> Unit,
    onCancelResume: () -> Unit,
) {
    Column(modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            NavButton(Icons.Default.FirstPage, stringResource(R.string.two_first_move),
                ui.displayedPly > 0, "debut", onStart)
            Spacer(Modifier.width(6.dp))
            NavButton(Icons.Default.ChevronLeft, stringResource(R.string.previous_move),
                ui.displayedPly > 0, "precedent", onPrevious)
            Slider(
                value = ui.displayedPly.toFloat(),
                onValueChange = { onPick(it.toInt()) },
                valueRange = 0f..ui.totalPlies.toFloat(),
                steps = (ui.totalPlies - 1).coerceAtLeast(0),
                colors = com.chesslab.ui.chessLabSliderColors(
                    if (ui.isReviewing) Palette.warning else Palette.accent
                ),
                modifier = Modifier.weight(1f).padding(horizontal = 6.dp).testTag("transport"),
            )
            NavButton(Icons.Default.ChevronRight, stringResource(R.string.next_move),
                ui.displayedPly < ui.totalPlies, "suivant", onNext)
            Spacer(Modifier.width(6.dp))
            NavButton(Icons.Default.LastPage, stringResource(R.string.two_last_move),
                ui.isReviewing, "direct", onLive)
        }

        if (ui.isReviewing) {
            Spacer(Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.two_review_state, ui.displayedPly, ui.totalPlies),
                    fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Palette.warning,
                    modifier = Modifier.testTag("consultation"),
                )
                Spacer(Modifier.weight(1f))
                if (ui.canResumeFromReview) {
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
            }
        } else ui.resumeUndo?.let { undo ->
            // La reprise a eu lieu : au même endroit, de quoi la défaire
            // pendant huit secondes.
            Spacer(Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.two_resume_undo_label, ui.totalPlies, undo.discarded.size),
                    fontSize = 12.sp, color = Palette.textSecondary, modifier = Modifier.weight(1f),
                )
                Text(
                    stringResource(R.string.cancel),
                    fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.warning,
                    modifier = Modifier
                        .clip(CircleShape)
                        .border(1.dp, Palette.warning.copy(alpha = 0.6f), CircleShape)
                        .clickable(onClick = onCancelResume)
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                        .testTag("annuler-reprise"),
                )
            }
        }
    }
}

@Composable
private fun NavButton(
    icon: ImageVector,
    label: String,
    enabled: Boolean,
    tag: String,
    onClick: () -> Unit,
) {
    Box(
        Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(Palette.surface)
            .border(1.dp, Palette.stroke, CircleShape)
            .clickable(enabled = enabled, onClick = onClick)
            .testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon, label,
            tint = if (enabled) Palette.textPrimary else Palette.textTertiary,
            modifier = Modifier.size(20.dp),
        )
    }
}

/** Abandonner, ou convenir de la nulle : les deux seules commandes du mode. */
@Composable
private fun ControlsBar(
    modifier: Modifier,
    side: String,
    onResign: () -> Unit,
    onDraw: () -> Unit,
) {
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        PillButton(Icons.Default.Flag, stringResource(R.string.play_resign), Palette.danger,
            "abandonner-$side", onResign)
        Spacer(Modifier.weight(1f))
        PillButton(null, stringResource(R.string.two_draw_button), Palette.textPrimary,
            "nulle-$side", onDraw, glyph = "½")
    }
}

@Composable
private fun PillButton(
    icon: ImageVector?,
    label: String,
    tint: Color,
    tag: String,
    onClick: () -> Unit,
    glyph: String? = null,
) {
    Row(
        Modifier
            .clip(CircleShape)
            .background(Palette.surface)
            .border(1.dp, Palette.stroke, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
        else if (glyph != null) Text(glyph, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = tint)
        Spacer(Modifier.width(8.dp))
        Text(label, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = tint)
    }
}

/**
 * Le panneau de fin : le résultat AVEC LES NOMS, la notation enfin révélée,
 * et de quoi continuer — accueil, analyse, revanche.
 */
@Composable
private fun GameOverPanel(
    modifier: Modifier,
    message: String,
    moves: List<String>,
    onHome: () -> Unit,
    onAnalyze: () -> Unit,
    onRematch: () -> Unit,
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(ControlShape)
            .background(Palette.surfaceElevated)
            .subtleBorder(ControlShape)
            .padding(14.dp)
            .testTag("fin-de-partie"),
    ) {
        Text(message, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
        if (moves.isNotEmpty()) {
            Spacer(Modifier.height(6.dp))
            val rendered = moves.map { sanText(it) }
            Text(
                rendered.joinToString(" "),
                fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = Palette.textSecondary,
                maxLines = 2,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                modifier = Modifier.testTag("notation-finale"),
            )
        }
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(R.string.play_home),
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
                modifier = Modifier
                    .clip(CircleShape)
                    .border(1.dp, Palette.stroke, CircleShape)
                    .clickable(onClick = onHome)
                    .padding(horizontal = 14.dp, vertical = 8.dp)
                    .testTag("accueil"),
            )
            Spacer(Modifier.weight(1f))
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
                stringResource(R.string.two_rematch),
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(accentGradient)
                    .clickable(onClick = onRematch)
                    .padding(horizontal = 14.dp, vertical = 8.dp)
                    .testTag("revanche"),
            )
        }
    }
}

private fun glyph(kind: Piece.Kind): String = when (kind) {
    Piece.Kind.king -> "♚"
    Piece.Kind.queen -> "♛"
    Piece.Kind.rook -> "♜"
    Piece.Kind.bishop -> "♝"
    Piece.Kind.knight -> "♞"
    Piece.Kind.pawn -> "♟"
}
