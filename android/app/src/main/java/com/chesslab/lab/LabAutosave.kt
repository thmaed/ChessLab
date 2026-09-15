package com.chesslab.lab

import android.content.Context
import com.chesslab.play.BookWidth
import com.chesslab.maia.OpponentGallery
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * La série en cours, écrite sur le disque après CHAQUE partie. Pendant de
 * `LabAutosaveStore` (`LabGameSettings.swift`).
 *
 * Une série de cent parties tourne un quart d'heure. Fermer l'app par
 * inadvertance, ou la voir évincée par le système, jetait jusqu'ici tout le
 * travail — sans même le dire. Le fichier tient les réglages ET les parties
 * déjà jouées : c'est ce qu'il faut pour reprendre exactement là où l'on en
 * était, et pas seulement pour recommencer avec les mêmes chiffres.
 *
 * La relecture est TOLÉRANTE : un fichier écrit par une version antérieure,
 * ou abîmé, ne rend rien plutôt que de faire échouer l'ouverture de l'écran.
 */
object LabAutosave {

    private fun file(context: Context) = File(context.filesDir, "lab_series.json")

    /** Ce qu'une reprise ramène : les réglages, et les parties déjà jouées. */
    data class Snapshot(val settings: LabSeriesSettings, val completed: List<LabCompletedGame>) {
        val isComplete: Boolean get() = completed.size >= settings.gameCount
    }

    fun save(context: Context, settings: LabSeriesSettings, completed: List<LabCompletedGame>) {
        val games = JSONArray()
        for (game in completed) {
            games.put(
                JSONObject()
                    .put("index", game.index)
                    .put("aWasWhite", game.aWasWhite)
                    .put("pgnResult", game.pgnResult)
                    .put("reasonLabel", game.reasonLabel)
                    .put("plyCount", game.plyCount)
                    .put("pgn", game.pgn)
            )
        }
        val root = JSONObject()
            .put("settings", settings.toJson())
            .put("completed", games)
            .put("savedAt", System.currentTimeMillis())
        runCatching { file(context).writeText(root.toString()) }
    }

    fun load(context: Context): Snapshot? = runCatching {
        val f = file(context)
        if (!f.exists()) return@runCatching null
        val root = JSONObject(f.readText())
        val settings = LabSeriesSettings.fromJson(root.getJSONObject("settings"))
        val array = root.optJSONArray("completed") ?: JSONArray()
        val games = (0 until array.length()).map { i ->
            val o = array.getJSONObject(i)
            LabCompletedGame(
                index = o.optInt("index", i),
                aWasWhite = o.optBoolean("aWasWhite", true),
                pgnResult = o.optString("pgnResult", "1/2-1/2"),
                reasonLabel = o.optString("reasonLabel", ""),
                plyCount = o.optInt("plyCount", 0),
                pgn = o.optString("pgn", ""),
            )
        }
        Snapshot(settings, games)
    }.getOrNull()

    fun clear(context: Context) {
        runCatching { file(context).delete() }
    }
}

/**
 * Les réglages d'une série, isolés de l'état d'affichage pour être écrits et
 * relus tels quels. Pendant de `LabGameSettings`.
 */
data class LabSeriesSettings(
    val sideAProfileId: String? = null,
    val sideBProfileId: String? = null,
    val sideALevel: Double = 1800.0,
    val sideBLevel: Double = 1500.0,
    val movetimeMs: Int = 200,
    val gameCount: Int = 20,
    val alternateColors: Boolean = true,
    val resignationEnabled: Boolean = true,
    val drawAgreementEnabled: Boolean = true,
    val liveVisualization: Boolean = true,
    val bookA: Boolean = true,
    val bookB: Boolean = true,
    val bookWidth: BookWidth = BookWidth.includeSidelines,
    val keepAwakeSetting: Boolean? = null,
    val startFen: String? = null,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("sideAProfileId", sideAProfileId ?: JSONObject.NULL)
        .put("sideBProfileId", sideBProfileId ?: JSONObject.NULL)
        .put("sideALevel", sideALevel)
        .put("sideBLevel", sideBLevel)
        .put("movetimeMs", movetimeMs)
        .put("gameCount", gameCount)
        .put("alternateColors", alternateColors)
        .put("resignationEnabled", resignationEnabled)
        .put("drawAgreementEnabled", drawAgreementEnabled)
        .put("liveVisualization", liveVisualization)
        .put("bookA", bookA)
        .put("bookB", bookB)
        .put("bookWidth", bookWidth.name)
        .put("keepAwakeSetting", keepAwakeSetting ?: JSONObject.NULL)
        .put("startFen", startFen ?: JSONObject.NULL)

    companion object {
        fun fromJson(o: JSONObject): LabSeriesSettings {
            val d = LabSeriesSettings()
            fun text(key: String): String? =
                if (o.has(key) && !o.isNull(key)) o.optString(key).ifEmpty { null } else null
            return LabSeriesSettings(
                sideAProfileId = text("sideAProfileId"),
                sideBProfileId = text("sideBProfileId"),
                sideALevel = o.optDouble("sideALevel", d.sideALevel),
                sideBLevel = o.optDouble("sideBLevel", d.sideBLevel),
                movetimeMs = o.optInt("movetimeMs", d.movetimeMs),
                gameCount = o.optInt("gameCount", d.gameCount),
                alternateColors = o.optBoolean("alternateColors", d.alternateColors),
                resignationEnabled = o.optBoolean("resignationEnabled", d.resignationEnabled),
                drawAgreementEnabled = o.optBoolean("drawAgreementEnabled", d.drawAgreementEnabled),
                liveVisualization = o.optBoolean("liveVisualization", d.liveVisualization),
                bookA = o.optBoolean("bookA", d.bookA),
                bookB = o.optBoolean("bookB", d.bookB),
                bookWidth = runCatching { BookWidth.valueOf(o.optString("bookWidth")) }
                    .getOrDefault(d.bookWidth),
                keepAwakeSetting = if (o.has("keepAwakeSetting") && !o.isNull("keepAwakeSetting"))
                    o.optBoolean("keepAwakeSetting") else null,
                startFen = text("startFen"),
            )
        }
    }

    /** Le camp A tel que l'écran l'attend : un personnage, ou Stockfish. */
    val sideA: LabSide get() = LabSide(sideAProfileId?.let { OpponentGallery.byId(it) }, sideALevel)
    val sideB: LabSide get() = LabSide(sideBProfileId?.let { OpponentGallery.byId(it) }, sideBLevel)
}
