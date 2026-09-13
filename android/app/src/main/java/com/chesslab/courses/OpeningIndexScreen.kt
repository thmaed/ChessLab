package com.chesslab.courses

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.analysis.MoveQuality
import com.chesslab.ui.CardShape
import com.chesslab.ui.FigurineSan
import com.chesslab.ui.Palette
import com.chesslab.ui.subtleBorder
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * **L'index des lignes, en arbre.** Pendant d'`OpeningIndexView`.
 *
 * Le tronc commun écrit UNE FOIS, puis les débranchements successifs. Chaque
 * coup est un bouton : taper le 7ᵉ coup de la ligne « Fried Liver » amène
 * directement à cette position, avec le fil des coups déjà rempli — pas « au
 * début de la ligne, puis sept fois Suivant ».
 *
 * Les coups du chemin COURANT sont surlignés dans tout l'arbre : rouvrir
 * l'index en cours de lecture montre où l'on est et par où l'on est passé.
 *
 * @param currentPath le chemin UCI de la position affichée par le lecteur.
 * @param destinationRow l'identifiant de la rangée qui déplie vraiment la
 *   position où une branche transpose — le renvoi du repère « transposition ».
 */
@Composable
fun OpeningIndexScreen(
    course: Course,
    rows: List<OpeningLineTree.Node>,
    currentPath: List<String>,
    destinationRow: (OpeningLineTree.Node) -> String?,
    onSelect: (List<String>) -> Unit,
    onClose: () -> Unit,
) {
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    /**
     * La rangée mise en évidence après un renvoi de transposition — le temps
     * de la retrouver du regard, puis elle s'éteint. Une surbrillance qui
     * reste se confondrait avec celle de la position courante.
     */
    var highlighted by remember { mutableStateOf<String?>(null) }

    // Rouvrir l'index en cours de lecture doit montrer OÙ l'on est, pas le
    // haut de l'arbre. Les rangées commencent à l'index 1 (l'en-tête est 0).
    LaunchedEffect(Unit) {
        if (currentPath.isEmpty()) return@LaunchedEffect
        val at = rows.indexOfFirst { row -> row.moves.any { it.path == currentPath } }
        if (at >= 0) listState.scrollToItem(at + 1)
    }

    fun revealDestination(row: OpeningLineTree.Node) {
        val id = destinationRow(row) ?: return
        val at = rows.indexOfFirst { it.id == id }
        if (at < 0) return
        highlighted = id
        scope.launch {
            listState.animateScrollToItem(at + 1)
            delay(2_500)
            if (highlighted == id) highlighted = null
        }
    }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.index_title),
                fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary,
                modifier = Modifier.weight(1f),
            )
            Box(
                Modifier.size(34.dp).clip(CircleShape).background(Palette.surfaceElevated)
                    .clickable(onClick = onClose).testTag("index-fermer"),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Default.Close, stringResource(R.string.index_close), tint = Palette.textPrimary, modifier = Modifier.size(18.dp)) }
        }

        LazyColumn(state = listState, contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp)) {
            item(key = "entete") { Header(course, rows); Spacer(Modifier.height(14.dp)) }

            itemsIndexed(rows, key = { _, row -> row.id }) { index, row ->
                // Espacement NUL entre les rangées, l'air étant pris à
                // l'intérieur de chacune : sinon les rails verticaux se
                // coupent d'une rangée à l'autre.
                Column(
                    Modifier
                        .fillMaxWidth()
                        .then(
                            when (index) {
                                0 -> Modifier.clip(RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp))
                                rows.lastIndex -> Modifier.clip(RoundedCornerShape(bottomStart = 18.dp, bottomEnd = 18.dp))
                                else -> Modifier
                            }
                        )
                        .background(Palette.surface)
                        .padding(horizontal = 14.dp)
                        .then(if (index == 0) Modifier.padding(top = 14.dp) else Modifier)
                        .then(if (index == rows.lastIndex) Modifier.padding(bottom = 14.dp) else Modifier),
                ) {
                    TreeRow(row, index, currentPath, highlighted == row.id, destinationRow(row) != null,
                        onSelect = onSelect, onTransposition = { revealDestination(row) })
                }
            }

            item(key = "legende") { Spacer(Modifier.height(14.dp)); Legend(rows); Spacer(Modifier.height(24.dp)) }
        }
    }
}

// MARK: En-tête

/** Le nom de l'ouverture, son résumé, et trois repères chiffrés. */
@Composable
private fun Header(course: Course, rows: List<OpeningLineTree.Node>) {
    // Les rangées de DÉBRANCHEMENT — le tronc n'en est pas une.
    val branches = maxOf(0, rows.size - 1)
    Column(
        Modifier.fillMaxWidth().clip(CardShape).background(Palette.surface).subtleBorder().padding(16.dp),
    ) {
        Text(course.name, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary)
        if (course.summary.isNotEmpty()) {
            Spacer(Modifier.height(6.dp))
            Text(course.summary, fontSize = 13.sp, color = Palette.textSecondary)
        }
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill(pluralStringResource(R.plurals.index_variants, branches, branches))
            Pill(pluralStringResource(R.plurals.course_positions, course.positions.size, course.positions.size))
            Pill(stringResource(if (course.side == "black") R.string.index_side_black else R.string.index_side_white))
        }
    }
}

@Composable
private fun Pill(text: String) {
    Text(
        text, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
        modifier = Modifier.clip(CircleShape).background(Palette.surfaceElevated)
            .padding(horizontal = 8.dp, vertical = 4.dp),
    )
}

// MARK: L'arbre

/** La largeur d'un étage de connecteur : assez pour se voir, assez peu pour qu'une profondeur 6 garde de la place. */
private val indentStep = 13.dp

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TreeRow(
    row: OpeningLineTree.Node,
    index: Int,
    currentPath: List<String>,
    highlighted: Boolean,
    canReveal: Boolean,
    onSelect: (List<String>) -> Unit,
    onTransposition: () -> Unit,
) {
    // Le nom de la branche est DANS la colonne des connecteurs, pas au-dessus :
    // posé en dehors, il ouvrait dans les rails un trou de sa propre hauteur.
    val label = row.chapterTitle ?: row.ecoName?.takeIf { row.depth > 0 }

    Row(
        Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clip(RoundedCornerShape(8.dp))
            .background(if (highlighted) Palette.info.copy(alpha = 0.16f) else Color.Transparent)
            .testTag("index-rangee-$index"),
        verticalAlignment = Alignment.Top,
    ) {
        // Un vrai ARBRE, dessiné comme on dessine les arbres : un rail par
        // étage encore ouvert au-dessus, et un connecteur « └ » ou « ├ » à
        // l'étage de la rangée. Le connecteur ne s'apprend pas : il montre à
        // quoi la ligne se rattache.
        for (level in 0 until row.depth) {
            val isLast = row.lineage.getOrNull(level) ?: true
            val isElbow = level == row.depth - 1
            // Le coude vise le MILIEU de ce que la rangée montre en premier :
            // la première ligne de pastilles, ou le nom de variante.
            val elbowY = if (label == null) 18.dp else 11.dp
            TreeConnector(isLast, isElbow, elbowY, BranchMarker.tint(level + 1).copy(alpha = 0.55f))
        }

        Column(
            Modifier
                .weight(1f)
                // L'air est porté par le CONTENU, pas par la rangée : posé à
                // l'extérieur, il tombait hors des connecteurs.
                .padding(vertical = 4.dp)
                .padding(start = if (row.depth > 0) 5.dp else 0.dp),
        ) {
            if (label != null) {
                Text(
                    label, fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                    color = if (row.chapterTitle != null) BranchMarker.tint(row.depth) else Palette.textTertiary,
                    maxLines = 2,
                )
                Spacer(Modifier.height(3.dp))
            }
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(5.dp),
                verticalArrangement = Arrangement.spacedBy(7.dp),
            ) {
                row.moves.forEachIndexed { position, move ->
                    MoveChip(move, isFirstOfLine = position == 0, isOnMainLine = row.isOnMainLine, currentPath, onSelect)
                }
                if (row.isTransposition) TranspositionChip(canReveal, onTransposition)
            }
        }
    }
}

/** Un segment d'arbre : le rail d'un étage encore ouvert, ou le connecteur « └ » / « ├ » de la rangée. */
@Composable
private fun TreeConnector(isLast: Boolean, isElbow: Boolean, elbowY: androidx.compose.ui.unit.Dp, tint: Color) {
    Canvas(Modifier.width(indentStep).fillMaxHeight()) {
        val x = size.width / 2
        val y = minOf(elbowY.toPx(), size.height)
        val stop = if (isElbow && isLast) y else size.height
        val stroke = 1.5.dp.toPx()
        drawLine(tint, Offset(x, 0f), Offset(x, stop), strokeWidth = stroke)
        if (isElbow) drawLine(tint, Offset(x, y), Offset(size.width, y), strokeWidth = stroke)
    }
}

/**
 * « La suite est ailleurs » : la position a déjà été dépliée par un autre
 * chemin. On le DIT plutôt que de couper en silence, et c'est un RENVOI : taper
 * la puce fait défiler l'index jusqu'à la rangée qui déplie vraiment cette
 * position. Sans cela, « transposition » serait une impasse.
 */
@Composable
private fun TranspositionChip(canReveal: Boolean, onClick: () -> Unit) {
    val tint = if (canReveal) Palette.info else Palette.textTertiary
    Row(
        Modifier
            .clip(CircleShape)
            .background(if (canReveal) Palette.info.copy(alpha = 0.14f) else Palette.surfaceElevated.copy(alpha = 0.5f))
            .border(1.dp, if (canReveal) Palette.info.copy(alpha = 0.4f) else Color.Transparent, CircleShape)
            .clickable(enabled = canReveal, onClick = onClick)
            .padding(horizontal = 7.dp, vertical = 7.dp)
            .testTag("index-transposition"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Icon(Icons.Default.SwapHoriz, stringResource(R.string.index_transposition_hint), tint = tint, modifier = Modifier.size(11.dp))
        Text(stringResource(R.string.index_transposition), fontSize = 9.sp, fontWeight = FontWeight.Medium, color = tint)
    }
}

/**
 * Une pastille de coup. La ligne PRINCIPALE se lit en gras et en texte plein,
 * les variantes en demi-teinte — c'est la hiérarchie qu'on cherche du regard
 * en ouvrant l'index.
 */
@Composable
private fun MoveChip(
    move: IndexedMove,
    isFirstOfLine: Boolean,
    isOnMainLine: Boolean,
    currentPath: List<String>,
    onSelect: (List<String>) -> Unit,
) {
    val isCurrent = move.path == currentPath
    val isOnPath = move.path.size <= currentPath.size && currentPath.subList(0, move.path.size) == move.path
    val shape = RoundedCornerShape(7.dp)
    val background = when {
        isCurrent -> Palette.accent.copy(alpha = 0.22f)
        isOnPath -> Palette.accent.copy(alpha = 0.10f)
        else -> Palette.surfaceElevated.copy(alpha = if (isOnMainLine) 0.9f else 0.4f)
    }
    val border = when {
        isCurrent -> Palette.accent
        isOnMainLine -> Palette.strokeStrong
        else -> Palette.stroke
    }
    Row(
        Modifier
            .clip(shape)
            .background(background)
            .border(if (isCurrent) 1.5.dp else 1.dp, border, shape)
            .clickable { onSelect(move.path) }
            .padding(horizontal = 7.dp, vertical = 7.dp)
            .testTag("index-coup-${move.ply}-${move.uci}"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        move.numberPrefix(isFirstOfLine)?.let { prefix ->
            // Un numéro de coup est du PETIT texte : la teinte secondaire, pas
            // la tertiaire, sinon il passe sous le seuil de contraste.
            Text(prefix, fontSize = 10.sp, fontFamily = FontFamily.Monospace, color = Palette.textSecondary, maxLines = 1)
        }
        Text(
            FigurineSan.format(move.san),
            fontSize = 12.sp, fontFamily = FontFamily.Monospace,
            fontWeight = if (isOnMainLine || isCurrent) FontWeight.ExtraBold else FontWeight.Medium,
            color = when {
                isCurrent -> Palette.accent
                isOnMainLine -> Palette.textPrimary
                else -> Palette.textSecondary
            },
        )
        // UN SEUL marqueur par pastille, et seulement quand il y a quelque
        // chose à signaler : sur une carte de cinquante coups, trois
        // pictogrammes concurrents ne laissaient plus rien ressortir.
        move.quality?.let { QualityBadge(it) }
    }
}

/** Le verdict du moteur, en notation d'échecs quand elle existe — un joueur la lit sans légende. */
@Composable
private fun QualityBadge(quality: MoveQuality) {
    Text(
        quality.symbol ?: "", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = quality.tint,
        maxLines = 1, modifier = Modifier.padding(start = 2.dp),
    )
}

// MARK: Légende

/** L'ordre de la légende : du plus glorieux au plus douloureux, comme `MoveQuality` lui-même. */
private val legendQualities = listOf(
    MoveQuality.brilliant, MoveQuality.inaccuracy, MoveQuality.mistake, MoveQuality.miss, MoveQuality.blunder,
)

@Composable
private fun Legend(rows: List<OpeningLineTree.Node>) {
    // Les verdicts RÉELLEMENT présents dans cette ouverture : annoncer
    // « occasion manquée » alors qu'aucun coup n'en porte fait chercher pour rien.
    val present = rows.flatMap { it.moves }.mapNotNull { it.quality }.toSet()
    Column(
        Modifier.fillMaxWidth().clip(CardShape).background(Palette.surface).subtleBorder().padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            stringResource(R.string.index_legend).uppercase(),
            fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Palette.textTertiary,
        )
        LegendRow(stringResource(R.string.index_legend_variant)) {
            Box(Modifier.width(14.dp).height(18.dp)) {
                TreeConnector(isLast = true, isElbow = true, elbowY = 9.dp, tint = BranchMarker.tint(1).copy(alpha = 0.7f))
            }
        }
        for (quality in legendQualities.filter { it in present }) {
            LegendRow(stringResource(quality.labelRes)) { QualityBadge(quality) }
        }
        LegendRow(stringResource(R.string.index_legend_transposition)) {
            Icon(Icons.Default.SwapHoriz, null, tint = Palette.info, modifier = Modifier.size(11.dp))
        }
    }
}

@Composable
private fun LegendRow(text: String, mark: @Composable () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.width(16.dp), contentAlignment = Alignment.Center) { mark() }
        Text(text, fontSize = 12.sp, color = Palette.textSecondary)
    }
}

/**
 * La TEINTE d'un étage de débranchement. Elle n'est pas porteuse
 * d'information — le retrait et les rails la portent déjà — seulement une
 * aide à suivre un étage du regard. Famille FROIDE, du bleu clair au violet :
 * elle ne doit jamais se confondre avec les verdicts du moteur, qui vont du
 * jaune au rouge.
 */
object BranchMarker {
    private val tints = listOf(
        Color(0.353f, 0.651f, 1.000f),
        Color(0.294f, 0.518f, 0.949f),
        Color(0.290f, 0.388f, 0.878f),
        Color(0.435f, 0.365f, 0.902f),
        Color(0.580f, 0.400f, 0.906f),
        Color(0.706f, 0.443f, 0.878f),
    )

    fun tint(depth: Int): Color = if (depth < 1) Palette.textTertiary else tints[(depth - 1) % tints.size]
}
