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
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.Timeline
import androidx.compose.material.icons.filled.Route
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.VisibilityOff
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
    // D'une série ou d'un bilan, le retour mène aux réglages de Visualisation, pas à l'accueil (retour de
    // l'utilisateur, 18/11/2026, comme iOS) ; ce qui a été répondu reste compté.
    androidx.activity.compose.BackHandler(enabled = ui.phase != VisualizationPhase.setup) { model.backToSetup() }
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
            // Plus de couleur (18/11/2026, comme iOS) : un en-tête aux teintes des marches.
            val heroShape = RoundedCornerShape(20.dp)
            Row(
                Modifier.fillMaxWidth().clip(heroShape)
                    .background(androidx.compose.ui.graphics.Brush.linearGradient(listOf(
                        Palette.teal.copy(alpha = 0.26f), Palette.info.copy(alpha = 0.14f), Palette.violet.copy(alpha = 0.10f))))
                    .border(1.dp, Palette.teal.copy(alpha = 0.3f), heroShape)
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                com.chesslab.ui.IconBadge(Icons.Default.Visibility, Palette.teal, size = 46.dp)
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(stringResource(R.string.vis_hero_title), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
                    Text(stringResource(R.string.vis_hero_detail), fontSize = 13.sp, color = Palette.textSecondary)
                }
            }
            // On ne voyait pas QUELLES marches la série jouerait (retour du 18/11/2026, comme iOS) : décochée = éteinte,
            // cochée = teintée, et une phrase dit ce que la série mélange.
            SectionTitle(stringResource(R.string.vis_series_steps))
            GameCard {
                VisualizationStep.entries.forEachIndexed { index, step ->
                    if (index > 0) RowDivider()
                    StepRow(step, step in settings.steps, ui.stats.accuracy(step)) { model.toggle(step) }
                }
            }
            val mix = VisualizationStep.entries.filter { it in settings.steps }.map { stringResource(stepTitle(it)) }
            Text(
                stringResource(R.string.vis_series_mix, mix.joinToString(", ")), fontSize = 13.sp, color = Palette.textSecondary,
                modifier = Modifier.padding(horizontal = 4.dp).testTag("visualisation-melange"),
            )
            SectionTitle(stringResource(R.string.vis_series))
            GameCard {
                // Des PASTILLES plutôt que des menus (18/11/2026, comme iOS) : toutes les options se voient.
                PickerRow(Icons.Default.HourglassEmpty, stringResource(R.string.vis_length)) {
                    SegmentedPills(
                        VisualizationLength.entries.map { it to stringResource(lengthLabel(it)) }, settings.length,
                        tag = { "longueur-${it.name}" },
                    ) { model.updateSettings(settings.copy(length = it)) }
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
                PickerRow(Icons.Default.Timer, stringResource(R.string.vis_timer)) {
                    SegmentedPills(
                        listOf<Pair<Int?, String>>(null to stringResource(R.string.vis_timer_none)) +
                            VisualizationSettings.SECONDS_CHOICES.map { it to stringResource(timerTitle(it)) },
                        settings.secondsPerQuestion,
                        tag = { if (it == null) "chrono-sans" else "chrono-$it" },
                    ) { model.updateSettings(settings.copy(secondsPerQuestion = it)) }
                    settings.secondsPerQuestion?.let { base ->
                        Spacer(Modifier.height(8.dp))
                        Text(
                            stringResource(R.string.vis_timer_scale, base * VisualizationStep.squares.number, base * VisualizationStep.position.number),
                            fontSize = 12.sp, color = Palette.textSecondary, modifier = Modifier.testTag("chrono-echelle"),
                        )
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
            .background(if (isOn) step.tint.copy(alpha = 0.12f) else Color.Transparent)
            .clickable(onClick = onToggle)
            .semantics(mergeDescendants = true) { selected = isOn; role = Role.Checkbox }
            .padding(horizontal = 14.dp, vertical = 12.dp)
            .testTag("marche-${step.name}"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier.size(30.dp).clip(CircleShape)
                .background(if (isOn) step.tint else Color.White.copy(alpha = 0.06f))
                .border(1.dp, if (isOn) Color.Transparent else Palette.stroke, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text("${step.number}", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = if (isOn) Palette.background else Palette.textTertiary)
        }
        Column(Modifier.weight(1f)) {
            Text(stringResource(stepTitle(step)), fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                color = if (isOn) Palette.textPrimary else Palette.textTertiary)
            Text(stringResource(stepDetail(step)), fontSize = 12.sp, color = if (isOn) Palette.textSecondary else Palette.textTertiary)
        }
        accuracy?.let {
            Text("$it %", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = if (isOn) Palette.textSecondary else Palette.textTertiary)
        }
        Icon(
            if (isOn) Icons.Default.CheckCircle else Icons.Outlined.Circle, null,
            tint = if (isOn) step.tint else Palette.textTertiary, modifier = Modifier.size(24.dp),
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
    // Marche 5 : le plateau est l'exercice — il prend toute la place libre (retour de l'utilisateur, 18/11), donc pas
    // de défilement : il mesure le plus grand carré qui tient sous l'énoncé. Comme iOS.
    val calculating = question?.kind?.step == VisualizationStep.calculation
    Column(
        Modifier.fillMaxSize().then(if (calculating) Modifier else Modifier.verticalScroll(rememberScrollState()))
            .padding(horizontal = 16.dp).padding(top = 8.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(if (calculating) 12.dp else 18.dp),
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
            ProgressDots(ui)
        }
        if (question != null) {
            QuestionCard(model, ui, question)
            if (calculating) CalculationBoard(model, ui, question, Modifier.weight(1f))
            else if (question.kind.usesBoard) QuestionBoard(model, ui, question)
            if (question.choices.isNotEmpty()) Choices(model, ui, question)
            FeedbackLine(ui, question)
        }
    }
}

private val emptyPosition: Position = Position.fromFen("8/8/8/8/8/8/8/8 w - - 0 1") ?: Position.standard

/**
 * Marche 5 : la position du puzzle, montrée le temps de la mémoriser ; puis le plateau CACHÉ, où l'on joue le coup en
 * touchant départ et arrivée. Après la réponse, les pièces reviennent et la bonne réponse est fléchée. Comme iOS.
 */
@Composable
private fun CalculationBoard(model: VisualizationViewModel, ui: VisualizationUi, question: VQuestion, modifier: Modifier = Modifier) {
    val memorizing = ui.isMemorizing
    val revealed = ui.feedback != null
    val board = if (memorizing) VisualizationCalc.board(question, plies = 0) else VisualizationCalc.board(question)
    val expected = (question.answer as? VAnswer.Move)?.lan
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // Toute la place libre, en largeur comme en hauteur : le plus grand carré qui y tient.
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
        Box(Modifier.aspectRatio(1f, matchHeightConstraintsFirst = true).clip(RoundedCornerShape(8.dp)).testTag("visualisation-plateau")) {
            BoardView(
                position = board?.position ?: emptyPosition,
                orientation = VisualizationCalc.sideToFind(question),
                selected = ui.selectedFrom?.let { Square(it.notation) },
                hint = if (revealed && expected != null) Square(expected.take(2)) to Square(expected.drop(2).take(2)) else null,
                enabled = !memorizing && !revealed,
                pieceMask = if (memorizing || revealed) com.chesslab.ui.PieceMask.None
                    else com.chesslab.ui.PieceMask(hidden = setOf(Piece.Color.white, Piece.Color.black)),
                onSquareTap = { square -> VSquare.parse(square.notation)?.let { model.tapCalculationSquare(it) } },
            )
        }
        }
        if (memorizing) {
            Row(
                Modifier.fillMaxWidth().heightIn(min = 50.dp).clip(RoundedCornerShape(16.dp))
                    .background(question.kind.step.tint).clickable { model.hidePosition() }.testTag("visualisation-cacher"),
                horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.VisibilityOff, null, tint = Palette.background, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.vis_hide), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.background)
            }
        }
    }
}

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
    val shape = RoundedCornerShape(16.dp)
    val stepTint = question.kind.step.tint
    val spoken = answerLabel(choice, question)
    val settings by com.chesslab.settings.SettingsStore.state.collectAsState()
    val theme = BoardTheme.all.firstOrNull { it.id == settings.boardThemeId } ?: BoardTheme.classic
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 54.dp)
            .clip(shape)
            .background(Palette.surfaceElevated)
            .background((tint ?: stepTint).copy(alpha = if (tint == null) 0.10f else 0.18f))
            .border(if (tint == null) 1.dp else 2.dp, tint ?: stepTint.copy(alpha = 0.32f), shape)
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
            ScoreRing(ui)
            if (ui.summaryByKind.isNotEmpty()) {
                SectionTitle(stringResource(R.string.vis_by_exercise))
                GameCard {
                    ui.summaryByKind.forEachIndexed { index, (kind, correct, total) ->
                        if (index > 0) RowDivider()
                        Row(
                            Modifier.fillMaxWidth().heightIn(min = 46.dp).padding(horizontal = 14.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Box(Modifier.size(8.dp).clip(CircleShape).background(kind.step.tint))
                            Text(stringResource(kindTitle(kind)), fontSize = 16.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f))
                            Box(Modifier.width(56.dp).height(6.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.1f))) {
                                Box(Modifier.fillMaxWidth(correct.toFloat() / maxOf(total, 1)).fillMaxHeight().clip(CircleShape).background(kind.step.tint))
                            }
                            Text("$correct / $total", fontSize = 16.sp, color = if (correct == total) Palette.accent else Palette.textSecondary,
                                textAlign = TextAlign.End, modifier = Modifier.widthIn(min = 44.dp))
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
private fun prompt(q: VQuestion, memorizing: Boolean = false): String {
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
        VisualizationKind.memorizePlay, VisualizationKind.calculateNext -> when {
            memorizing -> stringResource(R.string.vis_q_memorize)
            q.kind == VisualizationKind.memorizePlay -> stringResource(
                if (VisualizationCalc.sideToFind(q) == Piece.Color.white) R.string.vis_q_white_to_move else R.string.vis_q_black_to_move
            )
            else -> stringResource(R.string.vis_q_after, givenLine(q))
        }
    }
}

/** « 1. Fxf7+ Rxf7 » : les coups donnés par l'énoncé, numérotés, dans la notation de l'utilisateur. */
@Composable
private fun givenLine(q: VQuestion): String {
    val settings by com.chesslab.settings.SettingsStore.state.collectAsState()
    val position = Position.fromFen(q.puzzleFen.orEmpty()) ?: return ""
    val sans = com.chesslab.ui.SanFormatter.display(VisualizationCalc.givenSans(q), settings.pieceNotation)
    var number = position.clock.fullmoves
    var white = position.sideToMove == Piece.Color.white
    val parts = mutableListOf<String>()
    sans.forEachIndexed { index, san ->
        parts += when {
            white -> "$number. $san"
            index == 0 -> "$number… $san"
            else -> san
        }
        if (!white) number++
        white = !white
    }
    return parts.joinToString(" ")
}

@Composable
private fun answerLabel(a: VAnswer, q: VQuestion): String = when (a) {
    VAnswer.Light -> stringResource(R.string.vis_light)
    VAnswer.Dark -> stringResource(R.string.vis_dark)
    VAnswer.Yes -> stringResource(R.string.vis_yes)
    VAnswer.No -> stringResource(R.string.vis_no)
    is VAnswer.Square -> q.pieces.firstOrNull { it.square == a.square }?.label ?: a.square.notation
    is VAnswer.Number -> "${a.value}"
    is VAnswer.Move -> {
        val settings by com.chesslab.settings.SettingsStore.state.collectAsState()
        VisualizationCalc.san(a.lan, q)?.let { com.chesslab.ui.SanFormatter.display(it, settings.pieceNotation) }
            ?: "${a.lan.take(2)}–${a.lan.drop(2).take(2)}"
    }
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
            .then(if (compact) Modifier else Modifier.clip(RoundedCornerShape(14.dp))
                .background(Color.Black.copy(alpha = 0.22f)).padding(14.dp))
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
    VisualizationStep.calculation -> R.string.vis_step_calc
}
private fun stepDetail(step: VisualizationStep) = when (step) {
    VisualizationStep.squares -> R.string.vis_step_squares_detail
    VisualizationStep.lines -> R.string.vis_step_lines_detail
    VisualizationStep.pieces -> R.string.vis_step_pieces_detail
    VisualizationStep.position -> R.string.vis_step_position_detail
    VisualizationStep.calculation -> R.string.vis_step_calc_detail
}

private fun timerTitle(seconds: Int) = when {
    seconds <= 5 -> R.string.vis_timer_short
    seconds <= 10 -> R.string.vis_timer_medium
    else -> R.string.vis_timer_long
}

private fun lengthLabel(length: VisualizationLength) = when (length) {
    VisualizationLength.ten -> R.string.vis_len_ten
    VisualizationLength.twenty -> R.string.vis_len_twenty
    VisualizationLength.oneMinute -> R.string.vis_len_minute
    VisualizationLength.twoMinutes -> R.string.vis_len_two_minutes
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
    VisualizationKind.memorizePlay -> R.string.vis_kind_memorizePlay
    VisualizationKind.calculateNext -> R.string.vis_kind_calculateNext
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

// MARK: Couleurs et briques (18/11/2026 : « colore un peu mieux l'interface », comme iOS)

/** La couleur d'une marche — une seule à l'écran à la fois pendant la série. */
val VisualizationStep.tint: Color
    get() = when (this) {
        VisualizationStep.squares -> Palette.teal
        VisualizationStep.lines -> Palette.info
        VisualizationStep.pieces -> Palette.violet
        VisualizationStep.position -> Palette.gold
        VisualizationStep.calculation -> Palette.rose
    }

private val VisualizationStep.icon: androidx.compose.ui.graphics.vector.ImageVector
    get() = when (this) {
        VisualizationStep.squares -> Icons.Default.GridOn
        VisualizationStep.lines -> Icons.Default.Timeline
        VisualizationStep.pieces -> Icons.Default.Route
        VisualizationStep.position -> Icons.Default.Visibility
        VisualizationStep.calculation -> Icons.Default.Psychology
    }

/** La question dans une carte à la couleur de sa marche : l'exercice en étiquette, la scène, l'énoncé, le chrono. */
@Composable
private fun QuestionCard(model: VisualizationViewModel, ui: VisualizationUi, question: VQuestion) {
    val tint = question.kind.step.tint
    val feedback = ui.feedback
    val frame = when {
        feedback == null -> tint.copy(alpha = 0.35f)
        feedback.isCorrect -> Palette.accent
        else -> Palette.danger
    }
    val shape = RoundedCornerShape(22.dp)
    val calculating = question.kind.step == VisualizationStep.calculation
    Column(
        Modifier.fillMaxWidth().clip(shape)
            .background(androidx.compose.ui.graphics.Brush.verticalGradient(listOf(tint.copy(alpha = 0.24f), Palette.surfaceElevated)))
            .border(if (feedback == null) 1.dp else 2.dp, frame, shape)
            .padding(if (calculating) 14.dp else 18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(if (calculating) 10.dp else 14.dp),
    ) {
        Row(
            Modifier.clip(CircleShape).background(tint.copy(alpha = 0.16f)).padding(horizontal = 10.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(question.kind.step.icon, null, tint = tint, modifier = Modifier.size(14.dp))
            Text(stringResource(kindTitle(question.kind)), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = tint)
        }
        Scene(question)
        Text(
            prompt(question, ui.isMemorizing), fontSize = if (calculating) 19.sp else 22.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
            textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().testTag("visualisation-question"),
        )
        model.questionTimeFraction()?.let { fraction ->
            Box(Modifier.fillMaxWidth().height(5.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.1f))) {
                Box(Modifier.fillMaxWidth(fraction).fillMaxHeight().clip(CircleShape).background(if (fraction < 0.3f) Palette.danger else tint))
            }
        }
    }
}

/** Une pastille par question : verte juste, rouge ratée, blanche en cours, éteinte à venir. */
@Composable
private fun ProgressDots(ui: VisualizationUi) {
    val count = ui.settings.length.questionCount
    val total = count ?: (ui.answered.size + 1)
    val shown = if (count == null) (maxOf(0, total - 20) until total).toList() else (0 until total).toList()
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        shown.forEach { i ->
            val color = when {
                i < ui.answered.size -> if (ui.answered[i].isCorrect) Palette.accent else Palette.danger
                i == ui.answered.size -> Color.White.copy(alpha = 0.85f)
                else -> Color.White.copy(alpha = 0.12f)
            }
            Box((if (count == null) Modifier.width(10.dp) else Modifier.weight(1f)).height(6.dp).clip(CircleShape).background(color))
        }
    }
}

/** Le score dans un anneau : la part de justes. */
@Composable
private fun ScoreRing(ui: VisualizationUi) {
    val total = ui.answered.size
    val ratio = if (total == 0) 0f else ui.correctCount.toFloat() / total
    Box(Modifier.fillMaxWidth().padding(vertical = 12.dp), contentAlignment = Alignment.Center) {
        Box(Modifier.size(180.dp), contentAlignment = Alignment.Center) {
            androidx.compose.foundation.Canvas(Modifier.fillMaxSize()) {
                val stroke = 12.dp.toPx()
                val inset = stroke / 2
                val arcSize = androidx.compose.ui.geometry.Size(size.width - stroke, size.height - stroke)
                val topLeft = androidx.compose.ui.geometry.Offset(inset, inset)
                drawArc(Color.White.copy(alpha = 0.08f), 0f, 360f, false, topLeft, arcSize,
                    style = androidx.compose.ui.graphics.drawscope.Stroke(stroke))
                drawArc(
                    androidx.compose.ui.graphics.Brush.sweepGradient(listOf(Palette.teal, Palette.accent, Palette.teal)),
                    -90f, 360f * ratio, false, topLeft, arcSize,
                    style = androidx.compose.ui.graphics.drawscope.Stroke(stroke, cap = androidx.compose.ui.graphics.StrokeCap.Round),
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("${ui.correctCount} / $total", fontSize = 38.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary,
                    modifier = Modifier.testTag("visualisation-bilan"))
                Text(
                    stringResource(when (ui.settings.length) {
                        VisualizationLength.oneMinute -> R.string.vis_correct_in_minute
                        VisualizationLength.twoMinutes -> R.string.vis_correct_in_two_minutes
                        else -> R.string.vis_correct_plain
                    }),
                    fontSize = 15.sp, color = Palette.textSecondary,
                )
            }
        }
    }
}

/** Un réglage à choix : son titre, et les pastilles dessous, sur toute la largeur. */
@Composable
private fun PickerRow(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Icon(icon, null, tint = Palette.accent, modifier = Modifier.width(26.dp).size(20.dp))
            Text(title, fontSize = 16.sp, color = Palette.textPrimary)
        }
        Spacer(Modifier.height(10.dp))
        content()
    }
}

/** Un choix parmi quelques options, en pastilles : la choisie est pleine (accent). Pendant de `SegmentedPills` (iOS). */
@Composable
private fun <T> SegmentedPills(options: List<Pair<T, String>>, selected: T, tag: (T) -> String, onSelect: (T) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(CircleShape).background(Color.Black.copy(alpha = 0.28f))
            .border(1.dp, Palette.stroke, CircleShape).padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        options.forEach { (value, label) ->
            val isOn = value == selected
            Box(
                Modifier.weight(1f).heightIn(min = 36.dp).clip(CircleShape)
                    .background(if (isOn) Palette.accent else Color.Transparent)
                    .clickable { onSelect(value) }
                    .semantics { this.selected = isOn; role = Role.RadioButton }
                    .testTag(tag(value)),
                contentAlignment = Alignment.Center,
            ) {
                Text(label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
                    color = if (isOn) Palette.background else Palette.textSecondary)
            }
        }
    }
}
