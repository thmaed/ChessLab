package com.chesslab.visualization

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.filled.Tag
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.R
import com.chesslab.play.CheckItem
import com.chesslab.play.GameCard
import com.chesslab.play.MenuButton
import com.chesslab.play.RowDivider
import com.chesslab.play.SettingRow
import com.chesslab.ui.BoardTheme
import com.chesslab.ui.BoardView
import com.chesslab.ui.ControlShape
import com.chesslab.ui.Palette
import com.chesslab.ui.TopBarActions
import com.chesslab.ui.accentGradient
import kotlin.math.ceil

/**
 * L'écran Visualisation : les réglages (les marches, la série), la série, le bilan. Pendant de
 * `VisualizationView.swift` — même langage que « Nouvelle partie » : des cartes aux lignes d'un seul style, une
 * couleur d'accent.
 */
@Composable
fun VisualizationScreen(session: Long, model: VisualizationViewModel = viewModel()) {
    LaunchedEffect(session) { model.open(session) }
    val owner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            when (event) {
                androidx.lifecycle.Lifecycle.Event.ON_PAUSE -> model.pause()
                androidx.lifecycle.Lifecycle.Event.ON_RESUME -> model.resume()
                else -> Unit
            }
        }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    val ui = model.ui
    when (ui.phase) {
        VisualizationPhase.setup -> Setup(model, ui)
        VisualizationPhase.playing -> Playing(model, ui)
        VisualizationPhase.finished -> Summary(model, ui)
    }
}

// MARK: Les réglages

@Composable
private fun Setup(model: VisualizationViewModel, ui: VisualizationUi) {
    val settings = ui.settings
    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(top = 8.dp, bottom = 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(stringResource(R.string.vis_intro), fontSize = 15.sp, color = Palette.textSecondary, modifier = Modifier.padding(horizontal = 4.dp))
            SectionTitle(stringResource(R.string.vis_steps))
            GameCard {
                VisualizationStep.entries.forEachIndexed { index, step ->
                    if (index > 0) RowDivider()
                    StepRow(step, step in settings.steps, ui.stats.accuracy(step)) { model.toggle(step) }
                }
            }
            SectionTitle(stringResource(R.string.vis_series))
            GameCard {
                SettingRow(Icons.Default.Tag, stringResource(R.string.vis_length)) {
                    MenuButton(stringResource(lengthLabel(settings.length)), highlighted = false, tag = "menu-longueur") { close ->
                        VisualizationLength.entries.forEach { length ->
                            CheckItem(stringResource(lengthLabel(length)), settings.length == length, "longueur-${length.name}") {
                                model.updateSettings(settings.copy(length = length)); close()
                            }
                        }
                    }
                }
                RowDivider()
                SettingRow(Icons.Default.SwapVert, stringResource(R.string.vis_from_black)) {
                    Switch(
                        checked = settings.fromBlack, onCheckedChange = { model.updateSettings(settings.copy(fromBlack = it)) },
                        colors = SwitchDefaults.colors(checkedTrackColor = Palette.accent),
                        modifier = Modifier.testTag("vu-des-noirs"),
                    )
                }
                RowDivider()
                SettingRow(Icons.Default.Timer, stringResource(R.string.vis_timer)) {
                    val seconds = settings.secondsPerQuestion
                    MenuButton(
                        if (seconds == null) stringResource(R.string.vis_timer_none) else stringResource(R.string.vis_seconds, seconds),
                        highlighted = seconds != null, tag = "menu-chrono",
                    ) { close ->
                        CheckItem(stringResource(R.string.vis_timer_none), seconds == null, "chrono-sans") {
                            model.updateSettings(settings.copy(secondsPerQuestion = null)); close()
                        }
                        VisualizationSettings.SECONDS_CHOICES.forEach { s ->
                            CheckItem(stringResource(R.string.vis_seconds, s), seconds == s, "chrono-$s") {
                                model.updateSettings(settings.copy(secondsPerQuestion = s)); close()
                            }
                        }
                    }
                }
            }
            if (ui.reviewCount > 0) {
                Row(Modifier.padding(horizontal = 4.dp).testTag("a-revoir"), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Replay, null, tint = Palette.textSecondary, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(stringResource(R.string.vis_review_waiting, ui.reviewCount), fontSize = 13.sp, color = Palette.textSecondary)
                }
            }
        }
        BottomButton(stringResource(R.string.vis_start), "visualisation-commencer") { model.start() }
    }
}

@Composable
private fun StepRow(step: VisualizationStep, isOn: Boolean, accuracy: Int?, onToggle: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle)
            .semantics(mergeDescendants = true) { selected = isOn; role = Role.Checkbox }
            .padding(horizontal = 14.dp, vertical = 12.dp)
            .testTag("marche-${step.name}"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier.size(30.dp).clip(CircleShape).background(if (isOn) Palette.accent else Palette.accent.copy(alpha = 0.14f)),
            contentAlignment = Alignment.Center,
        ) {
            Text("${step.number}", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = if (isOn) Palette.background else Palette.accent)
        }
        Column(Modifier.weight(1f)) {
            Text(stringResource(stepTitle(step)), fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
            Text(stringResource(stepDetail(step)), fontSize = 12.sp, color = Palette.textSecondary)
        }
        accuracy?.let { Text("$it %", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary) }
        Icon(
            if (isOn) Icons.Default.CheckCircle else Icons.Outlined.Circle, null,
            tint = if (isOn) Palette.accent else Palette.textTertiary, modifier = Modifier.size(24.dp),
        )
    }
}

// MARK: La série

@Composable
private fun Playing(model: VisualizationViewModel, ui: VisualizationUi) {
    TopBarActions {
        TextButton(onClick = { model.stop() }, modifier = Modifier.testTag("visualisation-arreter")) {
            Text(stringResource(R.string.vis_stop), color = Palette.textPrimary)
        }
    }
    val question = ui.question
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(top = 8.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                val remaining = model.seriesRemainingMs()
                val count = ui.settings.length.questionCount
                if (remaining != null) {
                    Icon(Icons.Default.Timer, null, tint = Palette.textPrimary, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(clock(remaining), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                        style = androidx.compose.ui.text.TextStyle(fontFeatureSettings = "tnum"))
                } else if (count != null) {
                    Text(
                        // Le numéro de la question EN COURS : pendant le retour sur une réponse, c'est encore elle.
                        "${minOf(if (ui.feedback == null) ui.answered.size + 1 else ui.answered.size, count)} / $count",
                        fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
                        color = Palette.textPrimary, modifier = Modifier.testTag("visualisation-progression"),
                    )
                }
                Spacer(Modifier.weight(1f))
                Icon(Icons.Default.Check, null, tint = Palette.accent, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(4.dp))
                Text("${ui.correctCount}", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.accent,
                    modifier = Modifier.testTag("visualisation-score"))
            }
            model.questionTimeFraction()?.let { fraction ->
                Box(Modifier.fillMaxWidth().height(5.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.1f))) {
                    Box(
                        Modifier.fillMaxWidth(fraction).fillMaxHeight().clip(CircleShape)
                            .background(if (fraction < 0.3f) Palette.danger else Palette.accent)
                    )
                }
            }
        }
        if (question != null) {
            Scene(question)
            Text(
                prompt(question), fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
                    .padding(top = if (question.kind.usesBoard || question.pieces.isNotEmpty() || question.moves.isNotEmpty()) 0.dp else 24.dp)
                    .testTag("visualisation-question"),
            )
            if (question.kind.usesBoard) QuestionBoard(model, ui, question)
            if (question.choices.isNotEmpty()) Choices(model, ui, question)
            FeedbackLine(ui, question)
        }
    }
}

private val emptyPosition: Position = Position.fromFen("8/8/8/8/8/8/8/8 w - - 0 1") ?: Position.standard

/** Un plateau vide, sans coordonnées — c'est l'exercice. */
@Composable
private fun QuestionBoard(model: VisualizationViewModel, ui: VisualizationUi, question: VQuestion) {
    val target = question.squares[0]
    val showTarget = question.kind == VisualizationKind.nameSquare || ui.feedback != null
    Box(Modifier.widthIn(max = 420.dp).fillMaxWidth().aspectRatio(1f).clip(RoundedCornerShape(8.dp)).testTag("visualisation-plateau")) {
        BoardView(
            position = emptyPosition,
            orientation = if (ui.settings.fromBlack) Piece.Color.black else Piece.Color.white,
            selected = if (showTarget) Square(target.notation) else null,
            enabled = question.kind == VisualizationKind.findSquare && ui.feedback == null,
            showCoordinates = false,
            onSquareTap = { square -> VSquare.parse(square.notation)?.let { model.answer(VAnswer.Square(it)) } },
        )
    }
}

@Composable
private fun Choices(model: VisualizationViewModel, ui: VisualizationUi, question: VQuestion) {
    val columns = if (question.choices.size == 6) 3 else 2
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        question.choices.chunked(columns).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { choice -> Box(Modifier.weight(1f)) { ChoiceButton(model, ui, question, choice) } }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun ChoiceButton(model: VisualizationViewModel, ui: VisualizationUi, question: VQuestion, choice: VAnswer) {
    val feedback = ui.feedback
    val tint: Color? = when {
        feedback == null -> null
        choice == question.answer -> Palette.accent
        feedback.given == choice -> Palette.danger
        else -> null
    }
    val shape = RoundedCornerShape(14.dp)
    val spoken = answerLabel(choice, question)
    val settings by com.chesslab.settings.SettingsStore.state.collectAsState()
    val theme = BoardTheme.all.firstOrNull { it.id == settings.boardThemeId } ?: BoardTheme.classic
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 54.dp)
            .clip(shape)
            .background(tint?.copy(alpha = 0.16f) ?: Palette.surfaceElevated)
            .border(if (tint == null) 1.dp else 2.dp, tint ?: Palette.stroke, shape)
            .clickable(enabled = feedback == null) { model.answer(choice) }
            .semantics { contentDescription = spoken }
            .testTag("choix-${choice.tag}"),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val piece = pieceFor(choice, question)
        if (piece != null) {
            PieceImage(piece, 28.dp)
            if (choice is VAnswer.Square) Text(piece.square.notation, fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = tint ?: Palette.textPrimary)
        } else if (choice == VAnswer.Light || choice == VAnswer.Dark) {
            Box(
                Modifier.size(18.dp).clip(RoundedCornerShape(4.dp))
                    .background(if (choice == VAnswer.Light) theme.lightSquare else theme.darkSquare)
            )
            Spacer(Modifier.width(8.dp))
        }
        if (piece == null) Text(answerLabel(choice, question), fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = tint ?: Palette.textPrimary)
    }
}

@Composable
private fun FeedbackLine(ui: VisualizationUi, question: VQuestion) {
    val feedback = ui.feedback ?: run { Spacer(Modifier.height(24.dp)); return }
    val (icon, text, color) = when {
        feedback.isCorrect -> Triple(Icons.Default.CheckCircle, stringResource(R.string.vis_correct), Palette.accent)
        feedback.given == null -> Triple(Icons.Default.Timer, stringResource(R.string.vis_timeout_answer, answerLabel(question.answer, question)), Palette.danger)
        else -> Triple(Icons.Default.Cancel, stringResource(R.string.vis_wrong_answer, answerLabel(question.answer, question)), Palette.danger)
    }
    Row(Modifier.testTag("visualisation-retour"), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = color, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(6.dp))
        Text(text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = color)
    }
}

// MARK: Le bilan

@Composable
private fun Summary(model: VisualizationViewModel, ui: VisualizationUi) {
    TopBarActions {
        TextButton(onClick = { model.backToSetup() }, modifier = Modifier.testTag("visualisation-reglages")) {
            Text(stringResource(R.string.vis_settings), color = Palette.textPrimary)
        }
    }
    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Column(Modifier.fillMaxWidth().padding(vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "${ui.correctCount} / ${ui.answered.size}", fontSize = 48.sp, fontWeight = FontWeight.Bold,
                    color = Palette.textPrimary, modifier = Modifier.testTag("visualisation-bilan"),
                )
                Text(
                    stringResource(if (ui.settings.length == VisualizationLength.oneMinute) R.string.vis_correct_in_minute else R.string.vis_correct_plain),
                    fontSize = 15.sp, color = Palette.textSecondary,
                )
            }
            if (ui.summaryByKind.isNotEmpty()) {
                SectionTitle(stringResource(R.string.vis_by_exercise))
                GameCard {
                    ui.summaryByKind.forEachIndexed { index, (kind, correct, total) ->
                        if (index > 0) RowDivider()
                        Row(Modifier.fillMaxWidth().heightIn(min = 46.dp).padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(stringResource(kindTitle(kind)), fontSize = 16.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f))
                            Text("$correct / $total", fontSize = 16.sp, color = if (correct == total) Palette.accent else Palette.textSecondary)
                        }
                    }
                }
            }
            if (ui.misses.isNotEmpty()) {
                SectionTitle(stringResource(R.string.vis_to_review))
                GameCard {
                    ui.misses.forEachIndexed { index, item ->
                        if (index > 0) RowDivider()
                        Column(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Scene(item.question, compact = true)
                            Text(prompt(item.question), fontSize = 14.sp, color = Palette.textPrimary)
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                                Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Text(stringResource(R.string.vis_answer_label), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.accent)
                                    AnswerInline(item.question.answer, item.question, Palette.accent)
                                }
                                val given = item.given
                                if (given != null) {
                                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                                        Text(stringResource(R.string.vis_you_label), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.danger)
                                        AnswerInline(given, item.question, Palette.danger)
                                    }
                                } else {
                                    Text(stringResource(R.string.vis_timeout), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.danger)
                                }
                            }
                        }
                    }
                }
                Text(stringResource(R.string.vis_misses_return), fontSize = 13.sp, color = Palette.textSecondary, modifier = Modifier.padding(horizontal = 4.dp))
            }
        }
        BottomButton(stringResource(R.string.vis_restart), "visualisation-recommencer") { model.start() }
    }
}

// MARK: Les mots et les briques

@Composable
private fun prompt(q: VQuestion): String {
    val s = q.squares.map { it.notation }
    return when (q.kind) {
        VisualizationKind.squareColor -> stringResource(R.string.vis_q_squareColor, s[0])
        VisualizationKind.findSquare -> stringResource(R.string.vis_q_findSquare, s[0])
        VisualizationKind.nameSquare -> stringResource(R.string.vis_q_nameSquare)
        VisualizationKind.sameDiagonal -> stringResource(R.string.vis_q_sameDiagonal, s[0], s[1])
        VisualizationKind.lineIntersection -> when (val line = q.line) {
            is VLine.File -> stringResource(R.string.vis_q_intersection_file, VSquare.FILES[line.file], q.diagonal?.name.orEmpty())
            is VLine.Rank -> stringResource(R.string.vis_q_intersection_rank, "${line.rank + 1}", q.diagonal?.name.orEmpty())
            null -> ""
        }
        VisualizationKind.knightDistance -> stringResource(R.string.vis_q_knight, s[0], s[1])
        VisualizationKind.pathCheck -> stringResource(R.string.vis_q_pathCheck)
        VisualizationKind.attackAfter -> stringResource(R.string.vis_q_attackAfter, s[0])
        VisualizationKind.twoPieces -> stringResource(R.string.vis_q_twoPieces, s[0])
        VisualizationKind.isCheck -> stringResource(R.string.vis_q_isCheck)
        VisualizationKind.hangingPiece -> stringResource(R.string.vis_q_hangingPiece)
        VisualizationKind.squareAttacked -> stringResource(R.string.vis_q_squareAttacked, s[0])
    }
}

@Composable
private fun answerLabel(a: VAnswer, q: VQuestion): String = when (a) {
    VAnswer.Light -> stringResource(R.string.vis_light)
    VAnswer.Dark -> stringResource(R.string.vis_dark)
    VAnswer.Yes -> stringResource(R.string.vis_yes)
    VAnswer.No -> stringResource(R.string.vis_no)
    is VAnswer.Square -> q.pieces.firstOrNull { it.square == a.square }?.label ?: a.square.notation
    is VAnswer.Number -> "${a.value}"
    is VAnswer.Option -> when (a.name) {
        "first" -> q.pieces.firstOrNull()?.figurine.orEmpty()
        "second" -> q.pieces.getOrNull(1)?.figurine.orEmpty()
        "both" -> stringResource(R.string.vis_both)
        else -> stringResource(R.string.vis_none)
    }
}

/** La pièce que désigne une réponse (« ♞h6 », « le cavalier »), pour la montrer en image. */
private fun pieceFor(a: VAnswer, q: VQuestion): VPiece? = when {
    a is VAnswer.Square -> q.pieces.firstOrNull { it.square == a.square }
    a == VAnswer.Option("first") -> q.pieces.firstOrNull()
    a == VAnswer.Option("second") -> q.pieces.getOrNull(1)
    else -> null
}

/** Une pièce en image (jeu de pièces des réglages) ; une noire est cernée de clair pour se voir sur le fond sombre. */
@Composable
private fun PieceImage(piece: VPiece, size: androidx.compose.ui.unit.Dp) {
    val kind = when (piece.kind) {
        VPieceKind.king -> Piece.Kind.king
        VPieceKind.queen -> Piece.Kind.queen
        VPieceKind.rook -> Piece.Kind.rook
        VPieceKind.bishop -> Piece.Kind.bishop
        VPieceKind.knight -> Piece.Kind.knight
        VPieceKind.pawn -> Piece.Kind.pawn
    }
    val chessPiece = Piece(kind, if (piece.isWhite) Piece.Color.white else Piece.Color.black, Square("a1"))
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        if (!piece.isWhite) {
            androidx.compose.foundation.Image(
                painter = androidx.compose.ui.res.painterResource(com.chesslab.ui.drawableFor(chessPiece, pieceSetId())),
                contentDescription = null,
                colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(Color.White.copy(alpha = 0.85f)),
                modifier = Modifier.size(size + 3.dp),
            )
        }
        com.chesslab.ui.PieceIcon(chessPiece, Modifier.size(size).clearAndSetSemantics {})
    }
}

@Composable
private fun pieceSetId(): String {
    val settings by com.chesslab.settings.SettingsStore.state.collectAsState()
    return settings.pieceSetId
}

/** Une réponse dans une ligne : la pièce en image, sinon le mot. */
@Composable
private fun AnswerInline(a: VAnswer, q: VQuestion, color: Color) {
    val piece = pieceFor(a, q)
    if (piece != null) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            PieceImage(piece, 18.dp)
            if (a is VAnswer.Square) Text(piece.square.notation, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = color)
        }
    } else {
        Text(answerLabel(a, q), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = color)
    }
}

/** Ce que l'exercice met en scène : un trajet, deux pièces et leurs coups, une position — en images de pièces. */
@Composable
private fun Scene(q: VQuestion, compact: Boolean = false) {
    val glyph = if (compact) 20.dp else 30.dp
    val font = if (compact) 14.sp else 20.sp
    val rows: List<Pair<String?, List<VPiece>>> = when (q.kind) {
        VisualizationKind.pathCheck, VisualizationKind.attackAfter -> listOf(null to q.moves)
        VisualizationKind.twoPieces -> listOf(stringResource(R.string.vis_row_start) to q.pieces, stringResource(R.string.vis_row_moves) to q.moves)
        VisualizationKind.isCheck, VisualizationKind.hangingPiece, VisualizationKind.squareAttacked ->
            listOf(stringResource(R.string.vis_row_white) to q.pieces.filter { it.isWhite },
                stringResource(R.string.vis_row_black) to q.pieces.filter { !it.isWhite })
        else -> emptyList()
    }
    if (rows.isEmpty()) return
    val spoken = rows.joinToString(". ") { (title, pieces) ->
        if (title == null) pieces.first().figurine + " " + pieces.joinToString(", ") { it.square.notation }
        else title + " " + pieces.joinToString(", ") { it.label }
    }
    Column(
        Modifier
            .fillMaxWidth()
            .then(if (compact) Modifier else Modifier.padding(top = 12.dp).clip(RoundedCornerShape(14.dp))
                .background(Palette.surfaceElevated).border(1.dp, Palette.stroke, RoundedCornerShape(14.dp)).padding(16.dp))
            // L'étiquette de test AVANT l'effacement des sémantiques : placée après, elle était effacée avec le reste.
            .then(if (compact) Modifier else Modifier.testTag("visualisation-scene"))
            .clearAndSetSemantics { contentDescription = spoken },
        verticalArrangement = Arrangement.spacedBy(if (compact) 4.dp else 10.dp),
    ) {
        rows.forEach { (title, pieces) ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(if (title == null) 6.dp else 10.dp)) {
                if (title == null) {
                    PieceImage(pieces.first(), glyph)
                    Text(pieces.joinToString(" → ") { it.square.notation }, fontSize = font, fontWeight = FontWeight.SemiBold,
                        color = Palette.textPrimary, maxLines = 1)
                } else {
                    Text(title, fontSize = font, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary)
                    pieces.forEach { piece ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            PieceImage(piece, glyph)
                            Text(piece.square.notation, fontSize = font, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary, maxLines = 1)
                        }
                    }
                }
            }
        }
    }
}

private fun stepTitle(step: VisualizationStep) = when (step) {
    VisualizationStep.squares -> R.string.vis_step_squares
    VisualizationStep.lines -> R.string.vis_step_lines
    VisualizationStep.pieces -> R.string.vis_step_pieces
    VisualizationStep.position -> R.string.vis_step_position
}
private fun stepDetail(step: VisualizationStep) = when (step) {
    VisualizationStep.squares -> R.string.vis_step_squares_detail
    VisualizationStep.lines -> R.string.vis_step_lines_detail
    VisualizationStep.pieces -> R.string.vis_step_pieces_detail
    VisualizationStep.position -> R.string.vis_step_position_detail
}

private fun lengthLabel(length: VisualizationLength) = when (length) {
    VisualizationLength.ten -> R.string.vis_len_ten
    VisualizationLength.twenty -> R.string.vis_len_twenty
    VisualizationLength.oneMinute -> R.string.vis_len_minute
}

private fun kindTitle(kind: VisualizationKind) = when (kind) {
    VisualizationKind.squareColor -> R.string.vis_kind_squareColor
    VisualizationKind.findSquare -> R.string.vis_kind_findSquare
    VisualizationKind.nameSquare -> R.string.vis_kind_nameSquare
    VisualizationKind.sameDiagonal -> R.string.vis_kind_sameDiagonal
    VisualizationKind.lineIntersection -> R.string.vis_kind_lineIntersection
    VisualizationKind.knightDistance -> R.string.vis_kind_knightDistance
    VisualizationKind.pathCheck -> R.string.vis_kind_pathCheck
    VisualizationKind.attackAfter -> R.string.vis_kind_attackAfter
    VisualizationKind.twoPieces -> R.string.vis_kind_twoPieces
    VisualizationKind.isCheck -> R.string.vis_kind_isCheck
    VisualizationKind.hangingPiece -> R.string.vis_kind_hangingPiece
    VisualizationKind.squareAttacked -> R.string.vis_kind_squareAttacked
}

private fun clock(ms: Long): String {
    val total = ceil(ms / 1000.0).toInt()
    return "%d:%02d".format(total / 60, total % 60)
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text.uppercase(), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
        letterSpacing = 0.5.sp, modifier = Modifier.padding(start = 4.dp),
    )
}

/** Le bouton du bas, toujours visible, comme « Commencer » de « Nouvelle partie ». */
@Composable
private fun BottomButton(label: String, tag: String, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().background(Palette.background.copy(alpha = 0.94f)).padding(horizontal = 20.dp, vertical = 14.dp)) {
        Box(
            Modifier.fillMaxWidth().clip(ControlShape).background(accentGradient).clickable(onClick = onClick)
                .padding(vertical = 14.dp).testTag(tag),
            contentAlignment = Alignment.Center,
        ) {
            Text(label, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.background)
        }
    }
}
