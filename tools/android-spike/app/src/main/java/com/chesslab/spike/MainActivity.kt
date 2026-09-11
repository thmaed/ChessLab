package com.chesslab.spike

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme(colorScheme = darkColorScheme()) { SpikeScreen() } }
    }
}

@Composable
private fun SpikeScreen() {
    val context = LocalContext.current
    val steps = remember { mutableStateListOf<Step>() }
    val logLines = remember { mutableStateListOf<String>() }
    var running by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Text("ChessLab — spike Android", style = MaterialTheme.typography.headlineSmall)
        Spacer(Modifier.height(4.dp))
        Text(
            "Stockfish 17.1, mêmes sources que l'app iOS, compilé au NDK.",
            style = MaterialTheme.typography.bodySmall
        )
        Spacer(Modifier.height(12.dp))

        fun startRun() {
            steps.clear(); logLines.clear(); running = true
            scope.launch {
                withContext(Dispatchers.IO) {
                    SpikeScenario.run(
                        context,
                        emit = { step -> scope.launch { steps.add(step) } },
                        log = { line ->
                            scope.launch {
                                if (logLines.size > 400) logLines.removeAt(0)
                                logLines.add(line)
                            }
                        },
                    )
                }
                running = false
            }
        }

        // Le scénario part tout seul au lancement : le spike doit pouvoir
        // tourner sans interaction (émulateur piloté par adb).
        LaunchedEffect(Unit) { startRun() }

        Button(enabled = !running, onClick = { startRun() }) {
            Text(if (running) "En cours…" else "Rejouer le spike")
        }

        Spacer(Modifier.height(12.dp))
        steps.forEach { StepRow(it) }

        if (logLines.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            HorizontalDivider()
            Spacer(Modifier.height(8.dp))
            Text("Trace UCI", style = MaterialTheme.typography.labelLarge)
            LogPane(logLines)
        }
    }
}

@Composable
private fun StepRow(step: Step) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.Top) {
        Text(
            when (step.ok) { true -> "✓"; false -> "✗"; null -> "…" },
            color = when (step.ok) {
                true -> Color(0xFF4CAF50); false -> Color(0xFFE53935); null -> Color.Gray
            },
            modifier = Modifier.width(24.dp)
        )
        Column {
            Text(step.name, style = MaterialTheme.typography.bodyMedium)
            if (step.detail.isNotEmpty()) {
                Text(
                    step.detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun LogPane(lines: SnapshotStateList<String>) {
    val scroll = rememberScrollState()
    LaunchedEffect(lines.size) { scroll.animateScrollTo(scroll.maxValue) }
    Column(Modifier.fillMaxWidth().heightIn(max = 320.dp).verticalScroll(scroll)) {
        lines.forEach {
            Text(it, fontFamily = FontFamily.Monospace, fontSize = 10.sp, maxLines = 1)
        }
    }
}
