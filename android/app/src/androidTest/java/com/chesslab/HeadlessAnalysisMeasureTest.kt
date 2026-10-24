package com.chesslab

import android.app.Application
import android.os.PowerManager
import android.util.Log
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.analysis.AnalysisViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.junit.Test

/**
 * S1 (2.0) — MESURE de l'analyse complète d'une partie sur l'appareil : durée,
 * demi-coups classés, état thermique et température de la batterie avant/après.
 * C'est elle qui décide si l'analyse automatique (A1) peut tourner en arrière-plan.
 * Les chiffres sortent dans le journal (étiquette `S1`).
 */
class HeadlessAnalysisMeasureTest {

    private val app = InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as Application

    private val games = listOf(
        // partie 5 (52 coups)
        "1. e4 d5 2. exd5 Qxd5 3. Nc3 Qa5 4. Nf3 Nf6 5. h3 Bf5 6. d3 e6 7. Bd2 Nbd7 8. a3 c5 9. Be2 Qb6 10. Na4 Qc6 11. c4 Bd6 12. O-O O-O 13. Nh2 Bxd3 14. Bxd3 Bxh2+ 15. Kxh2 Qd6+ 16. Bf4 Qxf4+ 17. g3 Qd4 18. Qc2 Ne5 19. Rad1 Nxd3 20. Rxd3 Qe5 21. Nc3 Rfd8 22. Rfd1 Rxd3 23. Qxd3 h6 24. b4 cxb4 25. axb4 Rc8 26. Rd2 a6 27. Re2 Qc7 28. Ne4 Qxc4 29. Nxf6+ gxf6 30. Qe3 Kh7 31. Rb2 f5 32. Rb3 Qf1 33. g4 Rc2 34. Kg3 Qg1+ 35. Kf3 Qh1+ 36. Kg3 Qg1+ 37. Kf3 fxg4+ 38. hxg4 Qh1+ 39. Kg3 Qg1+ 40. Kf3 Qd1+ 41. Kg3 Rc4 42. f3 Qd6+ 43. f4 Rxb4 44. Rd3 Qb6 45. Qe1 Qb5 46. Qe3 a5 47. Rc3 a4 48. Qd2 Rb2 49. Qd4 Qe2 50. f5 Qe1+ 51. Kf4 e5+ 52. Qxe5 Rf2+ *",
        // partie 2 (28 coups)
        "1. e4 e5 2. Nf3 Nc6 3. d4 exd4 4. Nxd4 Bc5 5. Be3 Nxd4 6. Bxd4 Bxd4 7. Qxd4 Nf6 8. e5 Qe7 9. Be2 c5 10. exf6 Qxe2+ 11. Kxe2 cxd4 12. fxg7 Rg8 13. Rd1 d5 14. Rxd4 Be6 15. Nd2 Rc8 16. c3 Rxg7 17. g3 Rg5 18. Nf1 Ke7 19. Ne3 b5 20. a4 a6 21. axb5 axb5 22. Ra5 Rb8 23. Rb4 Bd7 24. Ra6 Rbg8 25. Rd4 Re5 26. Rxd5 Rgg5 27. Rd4 b4 28. Ra7 1-0",
        // partie 1 (66 coups)
        "1. e4 e6 2. c4 d5 3. cxd5 exd5 4. exd5 Nf6 5. Bb5+ Nbd7 6. Nc3 Bd6 7. Nge2 O-O 8. O-O a6 9. Bc4 Ne5 10. d3 Nfg4 11. f4 Bc5+ 12. d4 Nxc4 13. Qd3 Bd6 14. Qxc4 f5 15. h3 Nf6 16. Bd2 b5 17. Qb3 Bb7 18. a3 Qe8 19. Rae1 Qf7 20. Nc1 Rae8 21. Nd3 Ne4 22. Nxe4 fxe4 23. Ne5 Qxd5 24. Qe3 c5 25. Bc3 b4 26. axb4 cxb4 27. Bd2 a5 28. b3 Bc7 29. Bc1 Bb6 30. Bb2 Rc8 31. Nc4 Rxc4 32. bxc4 Qxc4 33. Rc1 Qd5 34. Kh1 a4 35. Ba1 Rd8 36. Rfd1 Rd7 37. Rb1 Qd6 38. Qd2 b3 39. Bc3 Bc7 40. Ra1 Qc6 41. d5 Qc5 42. Qd4 Qd6 43. Qxe4 Re7 44. Be5 Qf6 45. Qxa4 Rxe5 46. fxe5 Qxe5 47. Kg1 Bb6+ 48. Kf1 b2 49. Rab1 Qf5+ 50. Ke2 Qe5+ 51. Kd3 Qf5+ 52. Kc3 Qe5+ 53. Kb3 Bxd5+ 54. Rxd5 Qxd5+ 55. Qc4 Qxc4+ 56. Kxc4 Bc7 57. Rxb2 Be5 58. Rb7 h6 59. Kd5 Bf6 60. Ke6 Kh7 61. Kf7 h5 62. Rb6 Be5 63. Rb5 Bf4 64. Rxh5+ Bh6 65. g4 g6 66. Rh4 1-0",
    )

    private fun battery(): Pair<Int, Int> {
        val i = app.registerReceiver(null, android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED))
        return (i?.getIntExtra("temperature", 0) ?: 0) to (i?.getIntExtra("level", 0) ?: 0)
    }

    @Test fun measureFullReview() = runBlocking {
        val power = app.getSystemService(PowerManager::class.java)
        val only = InstrumentationRegistry.getArguments().getString("game")?.toIntOrNull()
        for ((index, moves) in games.withIndex()) {
            if (only != null && only != index) continue
            val (t0, level0) = battery()
            val thermal0 = power.currentThermalStatus
            val start = System.currentTimeMillis()
            val model = withContext(Dispatchers.Main) { AnalysisViewModel(app) }
            withContext(Dispatchers.Main) {
                // Le jeton de résultat de la partie reste TEL QUEL : en ajouter un second
                // faisait refuser le PGN.
                val text = if (moves.trimEnd().let { it.endsWith("*") || it.endsWith("1-0") || it.endsWith("0-1") || it.endsWith("1/2-1/2") }) moves else "$moves *"
                model.onInputChange("[Event \"S1\"]\n[Result \"*\"]\n\n$text")
                model.load()
            }
            withTimeout(420_000) { while (model.ui.summary == null || model.ui.reviewing) delay(500) }
            val seconds = (System.currentTimeMillis() - start) / 1000.0
            val plies = model.ui.sanMoves.size
            val (t1, level1) = battery()
            Log.i("S1", "partie $index | $plies demi-coups | %.1f s | %.2f s/demi-coup | batterie %.1f→%.1f °C, niveau %d→%d %% | thermique %d→%d"
                .format(seconds, seconds / plies, t0 / 10.0, t1 / 10.0, level0, level1, thermal0, power.currentThermalStatus))
            withContext(Dispatchers.Main) { model.handleViewDisappear() }
            delay(1_000)
        }
    }
}
