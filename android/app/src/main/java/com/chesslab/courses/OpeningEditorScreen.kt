package com.chesslab.courses

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.*
import androidx.compose.runtime.*
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
import com.chesslab.R
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.CardShape
import com.chesslab.ui.CircleIconButton
import com.chesslab.ui.Palette
import com.chesslab.ui.TopBarActions
import com.chesslab.ui.accentGradient
import com.chesslab.ui.cardGradient
import com.chesslab.ui.subtleBorder

/**
 * L'éditeur d'arbre d'un répertoire PERSONNEL : jouer un coup sur l'échiquier
 * l'ajoute, une variante se supprime d'un tap, un commentaire s'écrit sur
 * place. Pendant d'`OpeningEditorView.swift`.
 *
 * Même disposition que le lecteur — plateau d'abord, le texte dessous — pour
 * la raison qui l'avait imposée là-bas : on écrit une variante en REGARDANT la
 * position.
 *
 * Le geste central est l'ajout : il n'y a pas de bouton « ajouter un coup »,
 * on joue le coup. Le reste de l'app apprend déjà à jouer sur un échiquier ;
 * un éditeur qui demanderait de saisir « Cf3 » au clavier serait un formulaire
 * déguisé en jeu d'échecs.
 */
@Composable
fun OpeningEditorScreen(courseId: String, onBack: () -> Unit) {
    // Le cours est relu à l'ouverture : l'écran d'avant peut l'avoir renommé.
    val loaded = remember(courseId) { UserOpeningStore.course(courseId) }
    if (loaded == null) {
        NotFound(onBack)
        return
    }
    val state = remember(courseId) { OpeningEditorState(loaded) }
    var renaming by remember { mutableStateOf(false) }
    var commenting by remember { mutableStateOf<CourseMove?>(null) }

    TopBarActions {
        CircleIconButton(
            Icons.Default.Edit, stringResource(R.string.repedit_rename),
            Palette.accent, "renommer",
        ) { renaming = true }
    }

    BoardScaffold(
        board = {
            BoardView(
                position = state.position,
                orientation = state.orientation,
                selected = state.selected,
                legalTargets = state.legalTargets,
                lastMove = state.lastMove,
                // L'éditeur de répertoire JOUE des coups : on y traîne le
                // camp au trait, comme sur un plateau de partie.
                draggableColor = state.position.sideToMove,
                enabled = true,
                onSquareTap = state::tap,
            )
        },
        panel = {
            Spacer(Modifier.height(10.dp))
            if (state.trail.isNotEmpty()) Trail(state)
            Hint(state)
            Spacer(Modifier.height(12.dp))
            MovesSection(state, onComment = { commenting = it })
            Spacer(Modifier.height(12.dp))
            ControlBar(state)
        },
    )

    if (renaming) {
        RenameDialog(state.course.name, onDismiss = { renaming = false }) {
            state.rename(it)
            renaming = false
        }
    }
    commenting?.let { edge ->
        CommentDialog(
            edge = edge,
            initial = edge.comment.orEmpty(),
            onDismiss = { commenting = null },
        ) { text ->
            state.setComment(text, edge)
            commenting = null
        }
    }
    state.error?.let { error ->
        AlertDialog(
            onDismissRequest = state::dismissError,
            containerColor = Palette.surface,
            title = { Text(stringResource(R.string.repedit_error_title), color = Palette.textPrimary) },
            text = {
                Text(
                    error.detail?.let { stringResource(error.messageRes, it) }
                        ?: stringResource(error.messageRes),
                    color = Palette.textSecondary,
                    modifier = Modifier.testTag("erreur-edition"),
                )
            },
            confirmButton = {
                TextButton(onClick = state::dismissError) {
                    Text(stringResource(android.R.string.ok), color = Palette.accent)
                }
            },
        )
    }
}

/** Les coups parcourus, en fil : un tap ramène à n'importe lequel. */
@Composable
private fun Trail(state: OpeningEditorState) {
    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        state.trail.forEachIndexed { index, step ->
            val current = index == state.trail.size - 1
            Text(
                if (index % 2 == 0) "${index / 2 + 1}. ${step.san}" else step.san,
                fontSize = 12.sp, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold,
                color = if (current) Palette.background else Palette.textSecondary,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(if (current) Palette.accent else Palette.surface)
                    .clickable { state.jump(index + 1) }
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            )
        }
    }
    Spacer(Modifier.height(10.dp))
}

/**
 * La consigne est PERMANENTE.
 *
 * Côté iOS, elle ne s'affichait que sur une position sans suite ; dès qu'un
 * coup existait, l'écran ressemblait à une liste en lecture seule et
 * l'utilisateur a demandé si l'éditeur « ne servait qu'à renommer ou
 * supprimer ». L'ajout est pourtant le geste CENTRAL, et il n'a pas de bouton
 * — on joue le coup. Un geste sans bouton doit être annoncé, sinon il n'existe
 * pas. Le ton change avec le contexte : invitation quand la position est
 * vierge, rappel discret ensuite.
 */
@Composable
private fun Hint(state: OpeningEditorState) {
    val first = state.moves.isEmpty()
    Row(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(Icons.Default.TouchApp, null, tint = Palette.accent, modifier = Modifier.size(18.dp))
        Text(
            stringResource(if (first) R.string.repedit_hint_first else R.string.repedit_hint_more),
            fontSize = 13.sp,
            color = if (first) Palette.textSecondary else Palette.textTertiary,
            modifier = Modifier.testTag("consigne"),
        )
    }
}

@Composable
private fun MovesSection(state: OpeningEditorState, onComment: (CourseMove) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            stringResource(R.string.repedit_moves_here),
            fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textTertiary,
            modifier = Modifier.weight(1f),
        )
        Text(
            pluralStringResource(R.plurals.repedit_positions, state.positionCount, state.positionCount),
            fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = Palette.textTertiary,
            modifier = Modifier.testTag("compte-positions"),
        )
    }

    // Ce que font les deux icônes de chaque ligne. Une bulle et une corbeille
    // se devinent, mais « commenter » ne se devine pas comme « écrire ce que
    // l'élève lira pendant sa révision ».
    if (state.moves.isNotEmpty()) {
        Spacer(Modifier.height(4.dp))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(Icons.AutoMirrored.Filled.Chat, null, tint = Palette.accent, modifier = Modifier.size(12.dp))
            Text(stringResource(R.string.repedit_legend_comment), fontSize = 10.sp, color = Palette.textTertiary)
            Spacer(Modifier.width(6.dp))
            Icon(Icons.Default.Delete, null, tint = Palette.danger, modifier = Modifier.size(12.dp))
            Text(stringResource(R.string.repedit_legend_delete), fontSize = 10.sp, color = Palette.textTertiary)
        }
    }

    Spacer(Modifier.height(8.dp))
    state.moves.forEach { edge ->
        MoveRow(edge, onEnter = { state.enter(edge) }, onComment = { onComment(edge) }) {
            state.delete(edge)
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun MoveRow(
    edge: CourseMove,
    onEnter: () -> Unit,
    onComment: () -> Unit,
    onDelete: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .padding(12.dp)
            .testTag("arete-${edge.uci}"),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(
            Modifier.weight(1f).clickable(onClick = onEnter).testTag("entrer-${edge.uci}"),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Text(
                edge.san, fontSize = 16.sp, fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
            )
            edge.comment?.let {
                Text(it, fontSize = 11.sp, color = Palette.textSecondary, maxLines = 2)
            }
        }
        Icon(
            Icons.AutoMirrored.Filled.Chat,
            stringResource(R.string.repedit_comment_title, edge.san),
            tint = Palette.accent,
            modifier = Modifier.size(20.dp).clickable(onClick = onComment).testTag("commenter-${edge.uci}"),
        )
        Icon(
            Icons.Default.Delete,
            stringResource(R.string.repedit_delete_move, edge.san),
            tint = Palette.danger,
            modifier = Modifier.size(20.dp).clickable(onClick = onDelete).testTag("supprimer-${edge.uci}"),
        )
    }
}

/**
 * Navigation SYMÉTRIQUE : reculer et avancer.
 *
 * « Suivant » suit la ligne principale ; la liste reste le moyen de prendre
 * une autre branche, et le coup à venir est NOMMÉ — dans un arbre, « suivant »
 * ne dit pas où l'on va.
 */
@Composable
private fun ControlBar(state: OpeningEditorState) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        NavButton(
            Icons.Default.ChevronLeft, stringResource(R.string.course_previous),
            enabled = !state.isAtRoot, filled = false,
            modifier = Modifier.weight(1f).testTag("editeur-precedent"),
            onClick = state::back,
        )
        val next = state.nextEdge
        NavButton(
            Icons.Default.ChevronRight,
            stringResource(R.string.course_next) + (next?.let { " ${it.san}" } ?: ""),
            enabled = next != null, filled = true,
            modifier = Modifier.weight(1f).testTag("editeur-suivant"),
            onClick = state::forward,
        )
    }
}

@Composable
private fun NavButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    enabled: Boolean,
    filled: Boolean,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    Row(
        modifier
            .clip(CircleShape)
            .then(
                if (filled && enabled) Modifier.background(accentGradient)
                else Modifier.background(Palette.surfaceElevated)
            )
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 13.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val colour = when {
            !enabled -> Palette.textTertiary
            filled -> Palette.background
            else -> Palette.textPrimary
        }
        Icon(icon, null, tint = colour, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(6.dp))
        Text(label, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = colour)
    }
}

@Composable
private fun RenameDialog(initial: String, onDismiss: () -> Unit, onSave: (String) -> Unit) {
    var draft by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Palette.surface,
        title = { Text(stringResource(R.string.repedit_rename_title), color = Palette.textPrimary) },
        text = {
            OutlinedTextField(
                value = draft, onValueChange = { draft = it }, singleLine = true,
                label = { Text(stringResource(R.string.import_name)) },
                modifier = Modifier.fillMaxWidth().testTag("champ-nom"),
            )
        },
        confirmButton = {
            TextButton(onClick = { onSave(draft) }, modifier = Modifier.testTag("valider-nom")) {
                Text(stringResource(R.string.repedit_save), color = Palette.accent)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel), color = Palette.textSecondary) }
        },
    )
}

@Composable
private fun CommentDialog(
    edge: CourseMove,
    initial: String,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit,
) {
    var draft by remember(edge.uci) { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Palette.surface,
        title = { Text(stringResource(R.string.repedit_comment_title, edge.san), color = Palette.textPrimary) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    stringResource(R.string.repedit_comment_help, edge.san),
                    fontSize = 11.sp, color = Palette.textTertiary,
                )
                OutlinedTextField(
                    value = draft, onValueChange = { draft = it },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 100.dp).testTag("champ-commentaire"),
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(draft) }, modifier = Modifier.testTag("valider-commentaire")) {
                Text(stringResource(R.string.repedit_save), color = Palette.accent)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel), color = Palette.textSecondary) }
        },
    )
}

@Composable
private fun NotFound(onBack: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            stringResource(R.string.repedit_not_found),
            fontSize = 15.sp, color = Palette.textSecondary,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            stringResource(R.string.back), fontSize = 14.sp, color = Palette.accent,
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(Palette.surface)
                .clickable(onClick = onBack)
                .padding(horizontal = 14.dp, vertical = 8.dp),
        )
    }
}

private val unusedTint: Color = Color.Transparent
