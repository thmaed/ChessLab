package com.chesslab.courses

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.ui.Palette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * La liste des cours — ouvertures ou finales selon [endgames].
 *
 * Pendant réduit d'`OpeningListView` et `EndgameListView`. Les deux partagent
 * le même format de cours, donc le même écran.
 */
@Composable
fun CourseListScreen(endgames: Boolean, onOpen: (String) -> Unit) {
    val context = LocalContext.current
    var entries by remember { mutableStateOf<List<CatalogEntry>?>(null) }
    var query by remember { mutableStateOf("") }

    LaunchedEffect(endgames) {
        entries = withContext(Dispatchers.IO) {
            runCatching { CourseRepository.catalog(context.assets) }
                .getOrDefault(emptyList())
                .filter { it.isEndgame == endgames }
                .sortedBy { it.name }
        }
    }

    val list = entries
    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            label = { Text(if (endgames) "Chercher une finale" else "Chercher une ouverture") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("recherche"),
        )
        Spacer(Modifier.height(8.dp))

        if (list == null) {
            Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator(color = Palette.accent) }
            return@Column
        }

        val filtered = list.filter {
            query.isBlank() || it.name.contains(query, true) || it.summary.contains(query, true)
        }
        Text(
            "${filtered.size} ${if (endgames) "finales" else "ouvertures"}",
            fontSize = 12.sp, color = Palette.textTertiary,
            modifier = Modifier.padding(bottom = 6.dp).testTag("compte"),
        )

        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(filtered) { entry -> CourseRow(entry, onOpen) }
        }
    }
}

@Composable
private fun CourseRow(entry: CatalogEntry, onOpen: (String) -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .testTag("cours-${entry.id}")
            .clip(RoundedCornerShape(12.dp))
            .background(Palette.surface)
            .clickable { onOpen(entry.id) }
            .padding(12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                entry.name, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                color = Palette.textPrimary, modifier = Modifier.weight(1f),
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
            Tag(entry.sideLabel, if (entry.side == "white") Palette.textSecondary else Palette.info)
            Spacer(Modifier.width(5.dp))
            Tag(entry.levelLabel, if (entry.level == "advanced") Palette.warning else Palette.accent)
        }
        if (entry.summary.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            Text(
                entry.summary, fontSize = 12.sp, color = Palette.textSecondary,
                maxLines = 3, overflow = TextOverflow.Ellipsis,
            )
        }
        if (entry.eco.isNotEmpty() || entry.positionCount > 0) {
            Spacer(Modifier.height(6.dp))
            Text(
                listOfNotNull(
                    entry.eco.joinToString("–").ifEmpty { null },
                    "${entry.positionCount} positions".takeIf { entry.positionCount > 0 },
                ).joinToString(" · "),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
        }
    }
}

@Composable
private fun Tag(text: String, tint: androidx.compose.ui.graphics.Color) {
    Text(
        text, fontSize = 10.sp, color = tint,
        modifier = Modifier
            .clip(RoundedCornerShape(5.dp))
            .background(tint.copy(alpha = 0.14f))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    )
}
