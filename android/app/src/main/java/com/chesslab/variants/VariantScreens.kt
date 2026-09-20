package com.chesslab.variants

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.ControlButton
import com.chesslab.ui.EvalBar
import com.chesslab.ui.BoardView
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.FlutterDash
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Looks3
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import com.chesslab.ui.CardShape
import com.chesslab.ui.IconBadge
import com.chesslab.ui.cardGradient
import com.chesslab.ui.tintedCardBorder
import androidx.compose.material3.Icon
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.fillMaxSize
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow
import androidx.compose.ui.res.stringResource
import com.chesslab.R
import androidx.compose.ui.res.pluralStringResource
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.TopBarActions
import androidx.compose.foundation.border
import chesskit.Piece
import chesskit.Square
import com.chesslab.ui.PieceIcon
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.text.font.FontFamily

@Composable
fun VariantListScreen(onOpen: (String) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columns = ((maxWidth - 40.dp) / 174.dp).toInt().coerceAtLeast(2)
        // Le nom COURT quand la tuile est étroite — « Roi colline » plutôt que
        // « Roi de la colline ». iOS fait le même choix, sur sa classe de taille
        // compacte : c'est la place disponible qui décide, pas la variante.
        val largeurTuile = (maxWidth - 40.dp - 14.dp * (columns - 1)) / columns.toFloat()
        val etroit = largeurTuile < 200.dp
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                stringResource(R.string.variants_intro),
                fontSize = 14.sp, color = Palette.textSecondary,
            )
            VariantCatalog.all.chunked(columns).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    row.forEach { variant ->
                        Box(Modifier.weight(1f)) { VariantCard(variant, etroit, onOpen) }
                    }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

/**
 * Une tuile de variante : le même langage que les tuiles de l'accueil —
 * pastille d'icône, flèche de lancement, icône fantôme, bordure teintée.
 */
@Composable
private fun VariantCard(variant: Variant, etroit: Boolean, onOpen: (String) -> Unit) {
    val tint = variantTint(variant.id)
    val icon = variantIcon(variant.id)
    Box(
        Modifier
            .testTag("variante-${variant.id}")
            .height(132.dp)
            .clip(CardShape)
            .background(cardGradient)
            .tintedCardBorder(tint)
            .clickable { onOpen(variant.id) }
    ) {
        Icon(
            icon, null, tint = tint.copy(alpha = 0.08f),
            modifier = Modifier.align(Alignment.BottomEnd).offset(x = 28.dp, y = 22.dp).size(96.dp),
        )
        Icon(
            Icons.Default.NorthEast, null, tint = tint.copy(alpha = 0.6f),
            modifier = Modifier.align(Alignment.TopEnd).padding(13.dp).size(14.dp),
        )
        Column(Modifier.fillMaxSize().padding(16.dp)) {
            IconBadge(icon, tint)
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(if (etroit) variant.shortTitleRes else variant.titleRes),
                fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                color = Palette.textPrimary, maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
            Text(
                stringResource(variant.shortRes), fontSize = 12.sp, color = Palette.textSecondary,
                modifier = Modifier.padding(top = 2.dp), maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/**
 * La réserve d'un camp : les pièces prises qui attendent d'être posées.
 *
 * Rien du tout quand elle est vide — une bande vide sous un plateau ne dit
 * rien et vole de la place à l'échiquier, qui en manque toujours. La sienne se
 * touche pour choisir la pièce à poser ; celle d'en face ne se touche pas.
 */
@Composable
private fun Reserve(ui: VariantUiState, color: Piece.Color, model: VariantPlayViewModel) {
    val hand = ui.pocket[color].orEmpty()
    if (hand.isEmpty()) return
    val mine = color == Piece.Color.white
    Row(
        Modifier.fillMaxWidth().padding(vertical = 2.dp).testTag("reserve-${if (mine) "blancs" else "noirs"}"),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CrazyhouseFen.order.forEach { kind ->
            val count = hand[kind] ?: 0
            if (count == 0) return@forEach
            val selected = mine && ui.selectedDrop == kind
            Row(
                Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (selected) Palette.accent.copy(alpha = 0.28f) else Color.Transparent)
                    .border(
                        1.5.dp,
                        if (selected) Palette.accent else Color.Transparent,
                        RoundedCornerShape(8.dp),
                    )
                    .clickable(enabled = mine) { model.selectPocketPiece(kind) }
                    .padding(horizontal = 6.dp, vertical = 3.dp)
                    .testTag("reserve-${CrazyhouseFen.letter(kind)}-${if (mine) "moi" else "lui"}"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                PieceIcon(Piece(kind, color, Square("a1")), Modifier.size(26.dp))
                if (count > 1) {
                    Text(
                        "$count", fontSize = 11.sp, fontWeight = FontWeight.Bold,
                        color = Palette.textSecondary,
                    )
                }
            }
        }
    }
}

/**
 * Une couleur par variante, RELEVÉE sur l'écran iOS.
 *
 * Trois divergeaient : les Barricades étaient grises au lieu d'ambrées, et le
 * Duck Chess et le Coup Volé avaient leurs teintes ÉCHANGÉES. Une couleur de
 * tuile n'est pas un détail : c'est ce à quoi on reconnaît une variante d'un
 * coup d'œil, et deux apps qui ne s'accordent pas là-dessus désorientent celui
 * qui passe de l'une à l'autre.
 */
private fun variantTint(id: String): Color = when (id) {
    "chess960" -> Palette.violet
    "kingofthehill" -> Palette.gold
    "3check" -> Palette.danger
    "horde" -> Palette.teal
    "racingkings" -> Palette.info
    "atomic" -> Palette.danger
    "antichess" -> Palette.rose
    "crazyhouse" -> Palette.accent
    "stolenmove" -> Palette.gold
    "duck" -> Palette.warning
    "barricades" -> Palette.warning
    "randombarricades" -> Palette.violet
    else -> Palette.rose
}

/**
 * L'icône d'une variante, au plus près de celle d'iOS.
 *
 * Material ne porte pas les mêmes symboles que SF Symbols : là où iOS met une
 * montagne, un dé ou une grille, on prend l'équivalent le plus proche. Une
 * seule était franchement fausse — le Duck Chess portait une PATTE, alors que
 * la variante doit son nom à un canard qu'on voit ensuite sur le plateau.
 */
private fun variantIcon(id: String): ImageVector = when (id) {
    "chess960" -> Icons.Default.Casino               // dé
    "kingofthehill" -> Icons.Default.Terrain         // montagne
    "3check" -> Icons.Default.Looks3                 // le chiffre trois
    "horde" -> Icons.Default.Groups                  // la foule
    "racingkings" -> Icons.Default.SportsScore       // drapeau à damier
    "atomic" -> Icons.Default.Whatshot               // l'explosion
    "antichess" -> Icons.Default.SwapVert            // l'inversion
    "crazyhouse" -> Icons.Default.Inventory2         // la réserve
    "stolenmove" -> Icons.Default.Bolt               // l'éclair du jeton
    "duck" -> Icons.Default.FlutterDash              // un canard, enfin
    "barricades" -> Icons.Default.GridOn             // la grille murée
    "randombarricades" -> Icons.Default.Shuffle      // le tirage
    else -> Icons.Default.SwapVert
}

@Composable
fun VariantPlayScreen(
    variantId: String,
    /** La position Chess960 choisie au réglage ; `null` = tirage au sort. */
    chess960Number: Int? = null,
    twoPlayer: Boolean = false,
    /** Ce qui a été réglé avant de commencer : force, camp, cadence, aides. */
    settings: VariantSettings = VariantSettings(),
    /**
     * Seule l'analyse est proposée : les autres modes jouent aux règles
     * ORTHODOXES, et y envoyer une position de Horde ou de Roi de la colline
     * donnerait une partie qui n'a plus rien à voir. iOS fait le même
     * choix sur son écran Chess960.
     */
    onAnalyze: (String) -> Unit = {},
    /** Revoir la partie AUX RÈGLES DE LA VARIANTE : l'analyse ordinaire ment ici. */
    onReviewGame: (String, String?, List<String>) -> Unit = { _, _, _ -> },
    model: VariantPlayViewModel = viewModel(),
) {
    LaunchedEffect(variantId, chess960Number, twoPlayer, settings) {
        model.load(variantId, chess960Number, twoPlayer, settings)
    }
    val ui = model.ui
    var confirmResign by remember { mutableStateOf(false) }

    // L'écran s'en va : la pendule s'arrête, et repart au retour. Le modèle de
    // vue survit à la navigation — sans ces deux gestes, aller voir l'analyse
    // faisait tomber le drapeau sans que personne n'ait joué, et la pendule ne
    // repartait jamais.
    DisposableEffect(Unit) {
        model.resumeFromBackground()
        onDispose { model.pauseForBackground() }
    }

    TopBarActions {
        QuickSwitchMenu(onAnalyze = { onAnalyze(model.ui.position.fen) })
    }

    val settings by com.chesslab.settings.SettingsStore.state.collectAsState()
    val autoFlip = settings.autoFlipTwoPlayer

    BoardScaffold(
        header = {
            ui.variant?.let {
                Text(stringResource(it.blurbRes), fontSize = 11.sp, color = Palette.textTertiary)
                Spacer(Modifier.height(6.dp))
            }
            StatusRow(ui.status, busy = ui.thinking)
            Spacer(Modifier.height(8.dp))
            VariantClockRow(ui, top = true)
            // La réserve ADVERSE, au-dessus du plateau comme le camp qu'elle
            // sert : un relevé de ce qui peut nous tomber dessus.
            Reserve(ui, Piece.Color.black, model)
            ui.chess960Number?.let {
                Text(
                    stringResource(R.string.chess960_number) + " $it",
                    fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = Palette.textTertiary,
                    modifier = Modifier.testTag("numero-position"),
                )
            }
        },
        board = {
            BoardView(
                position = ui.position,
                // À deux sur un seul appareil, le plateau se retourne pour
                // celui qui doit jouer — le même réglage que le mode Deux
                // joueurs ordinaire le commande.
                orientation = if (ui.twoPlayer && autoFlip) ui.position.sideToMove
                else ui.userColor,
                selected = ui.selected,
                legalTargets = ui.legalTargets,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                walls = ui.walls,
                arrows = ui.hints,
                draggableColor = ui.position.sideToMove,
                enabled = ui.ready && !ui.thinking && !ui.gameOver,
                onSquareTap = model::onSquareTap,
            )
        },
        panel = {
            if (ui.settings.showEvalBar) {
                Spacer(Modifier.height(6.dp))
                EvalBar(cp = ui.evalCp, mate = ui.evalMate)
            }
            Spacer(Modifier.height(6.dp))
            VariantClockRow(ui, top = false)
            // La NÔTRE, sous le plateau, du côté où l'on joue.
            Reserve(ui, Piece.Color.white, model)
            Spacer(Modifier.height(4.dp))
            if (!ui.twoPlayer) {
                VariantControlBar(
                    ui = ui,
                    onHint = model::toggleHint,
                    onDraw = model::offerDraw,
                    onResign = { confirmResign = true },
                )
                Spacer(Modifier.height(8.dp))
            }
            Text(
                pluralStringResource(R.plurals.variant_halfmoves, ui.plies, ui.plies),
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("compteur"),
            )
            if (ui.gameOver) {
                // Le panneau de fin, comme dans les autres modes : le mot de
                // la fin, et de quoi continuer. « Analyser » passe par
                // l'analyse DE LA VARIANTE — l'orthodoxe jugerait une position
                // de Horde à des règles qui n'y sont pas.
                Spacer(Modifier.height(10.dp))
                Row(
                    Modifier.fillMaxWidth().testTag("fin-de-partie"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
                        Text(stringResource(R.string.new_game), color = Palette.accent)
                    }
                    Spacer(Modifier.weight(1f))
                    TextButton(
                        onClick = { onReviewGame(ui.variant?.id ?: "", model.startFen(), ui.uciLog) },
                        enabled = ui.uciLog.isNotEmpty(),
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
                TextButton(
                    onClick = { confirmResign = false; model.resign() },
                    modifier = Modifier.testTag("abandonner-oui"),
                ) { Text(stringResource(R.string.play_resign), color = Palette.danger) }
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
            is com.chesslab.play.BlunderSeverity.MissedMate -> stringResource(R.string.blunder_missed_mate)
            is com.chesslab.play.BlunderSeverity.AllowsMate -> stringResource(R.string.blunder_allows_mate)
            is com.chesslab.play.BlunderSeverity.Centipawns ->
                stringResource(R.string.blunder_centipawns, minOf(severity.drop, 1_000) / 100)
        }
        AlertDialog(
            onDismissRequest = model::dismissBlunderWarning,
            title = { Text(stringResource(R.string.blunder_title), color = Palette.textPrimary) },
            text = { Text(message, color = Palette.textSecondary, modifier = Modifier.testTag("alerte-gaffe")) },
            confirmButton = {
                TextButton(
                    onClick = model::takebackAfterBlunderWarning,
                    modifier = Modifier.testTag("reprendre-le-coup"),
                ) { Text(stringResource(R.string.play_takeback), color = Palette.accent) }
            },
            dismissButton = {
                TextButton(onClick = model::dismissBlunderWarning) {
                    Text(stringResource(R.string.blunder_keep), color = Palette.textSecondary)
                }
            },
            containerColor = Palette.surfaceElevated,
        )
    }
}

/**
 * Les deux pendules, quand la cadence en demande. Celle d'en face au-dessus du
 * plateau, la nôtre en dessous : la même géographie que le mode « Contre
 * l'ordinateur », pour qu'on n'ait pas à chercher.
 */
@Composable
private fun VariantClockRow(ui: VariantUiState, top: Boolean) {
    val white = ui.whiteClockMs ?: return
    val black = ui.blackClockMs ?: return
    val color = if (top) ui.userColor.opposite else ui.userColor
    val ms = if (color == Piece.Color.white) white else black
    val active = ui.position.sideToMove == color && !ui.gameOver
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(if (active) Palette.surfaceElevated else Color.Transparent)
            .padding(horizontal = 12.dp, vertical = 5.dp)
            .testTag(if (top) "pendule-adversaire" else "pendule-moi"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(9.dp)
                .clip(androidx.compose.foundation.shape.CircleShape)
                .background(if (color == Piece.Color.white) Color.White else Color.Black)
                .border(1.dp, Palette.stroke, androidx.compose.foundation.shape.CircleShape)
        )
        Spacer(Modifier.weight(1f))
        Text(
            com.chesslab.play.GameClock.format(ms),
            fontSize = 19.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace,
            color = when {
                ms < 30_000 -> Palette.danger
                active -> Palette.textPrimary
                else -> Palette.textTertiary
            },
        )
    }
}

/** Indice, nulle, abandon — les trois actions que toute partie doit offrir. */
@Composable
private fun VariantControlBar(
    ui: VariantUiState,
    onHint: () -> Unit,
    onDraw: () -> Unit,
    onResign: () -> Unit,
) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        ControlButton(
            Icons.Default.Lightbulb, stringResource(R.string.train_hint),
            enabled = ui.settings.hintsEnabled && !ui.gameOver,
            tint = if (ui.hintWanted) Palette.background else Palette.textPrimary,
            background = if (ui.hintWanted) Palette.accent else Palette.surfaceElevated,
            tag = "indice", onClick = onHint,
        )
        Spacer(Modifier.weight(1f))
        ControlButton(
            text = "½", label = stringResource(R.string.play_offer_draw),
            tint = Palette.info, enabled = !ui.gameOver && !ui.thinking,
            tag = "nulle", onClick = onDraw,
        )
        Spacer(Modifier.width(10.dp))
        ControlButton(
            Icons.Default.Flag, stringResource(R.string.play_resign),
            tint = Palette.danger, enabled = !ui.gameOver, tag = "abandonner", onClick = onResign,
        )
    }
}
