package com.chesslab.ui

import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.Science
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.chesslab.R

/**
 * Le raccourci qui emporte la position affichée vers un autre grand mode.
 * Pendant de `QuickSwitchMenu.swift`.
 *
 * Un seul bouton, quel que soit le nombre de destinations : un bouton par
 * destination surchargeait les écrans qui ont déjà leurs propres commandes.
 *
 * Les destinations se DÉCLARENT et ne s'excluent pas : chaque écran fournit
 * les actions qui ont un sens chez lui, et seules celles-là s'affichent.
 * L'analyse, par exemple, propose une partie contre l'ordinateur mais pas une
 * partie à deux.
 *
 * Libellés et icônes sont ceux des TUILES DE L'ACCUEIL, dans le même ordre :
 * le menu est un raccourci vers la grille, il en reprend les mots.
 */
@Composable
fun QuickSwitchMenu(
    onPlayVsEngine: (() -> Unit)? = null,
    onOpenTwoPlayer: (() -> Unit)? = null,
    onAnalyze: (() -> Unit)? = null,
    onOpenLab: (() -> Unit)? = null,
) {
    var open by remember { mutableStateOf(false) }
    IconButton(onClick = { open = true }, modifier = Modifier.testTag("changer-de-mode")) {
        Icon(
            Icons.Default.GridView,
            stringResource(R.string.switch_mode),
            tint = Palette.violet,
            modifier = Modifier.size(22.dp),
        )
    }
    DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
        Destination(open, R.string.route_play, Icons.Default.Memory, Palette.accent, onPlayVsEngine) { open = false }
        Destination(open, R.string.route_two_players, Icons.Default.People, Palette.info, onOpenTwoPlayer) { open = false }
        Destination(open, R.string.route_analysis, Icons.Default.ShowChart, Palette.teal, onAnalyze) { open = false }
        Destination(open, R.string.route_lab, Icons.Default.Science, Palette.rose, onOpenLab) { open = false }
    }
}

@Composable
private fun Destination(
    @Suppress("UNUSED_PARAMETER") open: Boolean,
    label: Int,
    icon: ImageVector,
    tint: androidx.compose.ui.graphics.Color,
    action: (() -> Unit)?,
    dismiss: () -> Unit,
) {
    if (action == null) return
    DropdownMenuItem(
        text = { Text(stringResource(label), color = Palette.textPrimary) },
        leadingIcon = { Icon(icon, null, tint = tint, modifier = Modifier.size(20.dp)) },
        onClick = { dismiss(); action() },
        modifier = Modifier.testTag("bascule-${label}"),
    )
}

/**
 * L'emplacement que la barre du haut réserve aux actions de l'écran courant.
 *
 * Les écrans sont composés SOUS la barre, ils ne peuvent donc pas y poser un
 * bouton directement. Chacun s'y inscrit, et s'en retire en partant — ce qui
 * garantit qu'aucun écran n'hérite du bouton du précédent.
 */
class TopBarSlot {
    var content by mutableStateOf<(@Composable RowScope.() -> Unit)?>(null)
}

val LocalTopBarSlot = staticCompositionLocalOf { TopBarSlot() }

/** L'écran pose ses actions dans la barre du haut ; elles partent avec lui. */
@Composable
fun TopBarActions(content: @Composable RowScope.() -> Unit) {
    val slot = LocalTopBarSlot.current
    val latest by rememberUpdatedState(content)
    DisposableEffect(slot) {
        val mine: @Composable RowScope.() -> Unit = { latest() }
        slot.content = mine
        // On ne vide que SI c'est bien le nôtre : quand un écran en remplace
        // un autre, le nouveau s'inscrit avant que l'ancien ne se retire.
        onDispose { if (slot.content === mine) slot.content = null }
    }
}
