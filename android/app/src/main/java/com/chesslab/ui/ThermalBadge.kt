package com.chesslab.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Thermostat
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.engine.ThermalMonitor

/**
 * « Appareil chaud — moteur bridé ». Pendant de `ThermalBadge.swift`.
 *
 * Il n'occupe AUCUNE place tant que l'appareil est froid, et vit dans le flux
 * plutôt qu'en superposition : posé par-dessus, il recouvrirait le plateau.
 *
 * Il existe parce que le bridage se voit autrement : le moteur joue plus vite
 * et moins bien, et sans cette ligne on croirait à une panne.
 */
@Composable
fun ThermalBadge(modifier: Modifier = Modifier) {
    val throttling by ThermalMonitor.throttling.collectAsState()
    if (!throttling) return
    Row(
        modifier
            .clip(CircleShape)
            .background(Palette.warning.copy(alpha = 0.12f))
            .padding(horizontal = 12.dp, vertical = 5.dp)
            .testTag("bandeau-thermique"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(Icons.Default.Thermostat, null, tint = Palette.warning, modifier = Modifier.size(15.dp))
        Text(
            stringResource(R.string.thermal_throttled),
            fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Palette.warning,
        )
    }
}
