package com.chesslab.analysis

import android.app.Application
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import chesskit.Piece
import com.chesslab.courses.RepertoireExitDetector
import com.chesslab.library.LibraryDatabase
import com.chesslab.training.FsrsRating
import com.chesslab.training.recordReview

/**
 * Les SUITES d'une analyse terminée (A2, A3) — quand l'utilisateur a ouvert l'analyse d'une de ses
 * parties contre l'ordinateur et que la revue vient de s'achever : ses erreurs et ses mats manqués
 * deviennent des puzzles « Mes parties », et la position où il a quitté son répertoire rejoint les
 * révisions. Pendant de `AnalysisFollowUpService.swift`.
 *
 * L'analyse AUTOMATIQUE en arrière-plan (A1) a été retirée le 27/10/2026 : elle se bloquait, coûtait de
 * la batterie et demandait une question hors contexte. Ces suites restent — elles se jouent sous les
 * yeux de l'utilisateur, à la fin de SON analyse.
 */
object AnalysisFollowUpService {

    /** A2 : au plus ce nombre de puzzles tirés d'une partie, les mats d'abord. */
    const val MAX_PUZZLES_PER_GAME = 3

    private const val PREFS = "auto_analysis"
    private const val DONE = "followUpDone"
    private const val RETAINED = 300

    /** Puzzles créés depuis la dernière visite des puzzles : la pastille de l'accueil. */
    var newPuzzleCount by mutableStateOf(0)
        private set

    /** A3 : sorties de répertoire repérées depuis la dernière visite des ouvertures. */
    var repertoireExitCount by mutableStateOf(0)
        private set

    fun loadPending(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        newPuzzleCount = prefs.getInt("newPuzzles", 0)
        repertoireExitCount = prefs.getInt("repertoireExits", 0)
    }

    fun acknowledgeNewPuzzles(context: Context) {
        newPuzzleCount = 0
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove("newPuzzles").apply()
    }

    fun acknowledgeRepertoireExits(context: Context) {
        repertoireExitCount = 0
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove("repertoireExits").apply()
    }

    // ---- Une fois par partie

    /** Les parties dont les suites ont déjà été jouées : rouvrir une analyse ne doit rien refaire. */
    fun hasProcessed(context: Context, key: String): Boolean =
        keys(context).contains(key)

    fun markProcessed(context: Context, key: String) {
        val all = keys(context)
        if (key in all) return
        val kept = (all + key).takeLast(RETAINED)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(DONE, kept.joinToString("\n")).apply()
    }

    private fun keys(context: Context): List<String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(DONE, "")!!.split("\n").filter { it.isNotEmpty() }

    /**
     * Les suites d'une analyse terminée. La sortie de répertoire (A3) s'enregistre d'elle-même, une
     * fois par partie. Les puzzles (A2) ne se créent PAS d'office : on rend ce que l'app peut créer,
     * et l'écran le propose — `null` s'il n'y a rien à proposer ou si la partie a déjà été décidée.
     * [color] est le camp de l'utilisateur dans la partie ENREGISTRÉE contre l'ordinateur.
     */
    suspend fun followUp(application: Application, viewModel: AnalysisViewModel, key: String, color: Piece.Color): PuzzleOffer? {
        if (!hasProcessed(application, "exit:$key")) {
            markProcessed(application, "exit:$key")
            recordRepertoireExit(application, viewModel, color)
        }
        if (hasProcessed(application, "puz:$key")) return null
        val candidates = viewModel.proposePuzzles(color, MAX_PUZZLES_PER_GAME)
        if (candidates.isEmpty()) {
            markProcessed(application, "puz:$key")
            return null
        }
        return PuzzleOffer(key, candidates)
    }

    /** La décision est prise (accepté ou refusé) : la partie ne sera plus proposée. */
    fun puzzlesDecided(application: Application, key: String, created: Int) {
        markProcessed(application, "puz:$key")
        if (created > 0) {
            newPuzzleCount += created
            application.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putInt("newPuzzles", newPuzzleCount).apply()
        }
    }

    /**
     * A3 — la position où l'utilisateur a quitté son répertoire rejoint les révisions FSRS : ce qu'on
     * a raté en partie est revu. L'adversaire qui quitte la théorie le premier n'est PAS une sortie.
     */
    suspend fun recordRepertoireExit(application: Application, viewModel: AnalysisViewModel, color: Piece.Color) {
        val (positions, moves) = viewModel.mainLine
        val (courses, studied) = RepertoireExitDetector.followedCourses(application, color)
        val exit = RepertoireExitDetector.firstExit(positions, moves, color, courses, studied) ?: return
        LibraryDatabase.get(application).training().recordReview(exit.fenKey, FsrsRating.again)
        repertoireExitCount += 1
        application.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putInt("repertoireExits", repertoireExitCount).apply()
    }
}
