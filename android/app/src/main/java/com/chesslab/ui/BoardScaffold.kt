package com.chesslab.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp

/** Vrai quand l'écran est plus large que haut. */
@Composable
fun isLandscape(): Boolean {
    val c = LocalConfiguration.current
    return c.screenWidthDp > c.screenHeightDp
}

/**
 * L'agencement d'un écran de jeu : le plateau et ce qui l'accompagne.
 *
 * En portrait, l'un sous l'autre, le tout défilant — c'est la forme naturelle
 * d'un téléphone tenu droit.
 *
 * En paysage, CÔTE À CÔTE. Empiler en paysage ne marche pas : le panneau
 * (adversaire, coups, évaluation) mange les 400 dp de hauteur disponibles et
 * le plateau passe sous la ligne de flottaison — il faut faire défiler pour
 * voir la partie, ce qui n'est pas jouable. Le plateau prend donc la gauche,
 * borné par la hauteur, et le panneau la droite, où il défile seul.
 *
 * Le contenu est le MÊME dans les deux cas : un écran n'écrit sa mise en page
 * qu'une fois.
 */
@Composable
fun BoardScaffold(
    modifier: Modifier = Modifier,
    /** Ce qui doit rester visible en tête : statut, sélecteur d'adversaire. */
    header: @Composable ColumnScope.() -> Unit = {},
    board: @Composable () -> Unit,
    panel: @Composable ColumnScope.() -> Unit,
) {
    if (isLandscape()) {
        Row(modifier.fillMaxSize().padding(horizontal = 16.dp)) {
            Box(Modifier.weight(1f).fillMaxSize(), Alignment.Center) { board() }
            Spacer(Modifier.width(12.dp))
            Column(
                Modifier.weight(1f).fillMaxSize().verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.Top,
            ) {
                header()
                panel()
                Spacer(Modifier.height(24.dp))
            }
        }
    } else {
        Column(
            modifier.fillMaxSize().padding(horizontal = 16.dp).verticalScroll(rememberScrollState())
        ) {
            header()
            Box(Modifier.fillMaxWidth(), Alignment.Center) { board() }
            panel()
            Spacer(Modifier.height(24.dp))
        }
    }
}
