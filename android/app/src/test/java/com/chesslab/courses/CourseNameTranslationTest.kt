package com.chesslab.courses

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Les NOMS des cours, en français.
 *
 * Le nom d'un cours est une chaîne unique dans `opening_catalog.json`, en
 * anglais (« Italian Game », « The Opposition ») : iOS s'en sert comme clé de
 * traduction et affiche « Partie italienne ». Android lisait le nom brut — cent
 * trente-six titres anglais dans une app en français, dont les 78 finales.
 *
 * Ce que ce test protège n'est pas le rendu, c'est la SOURCE : chaque nom du
 * catalogue doit avoir sa traduction dans `Localizable.xcstrings`, d'où la
 * table Android est générée au build. Ajouter un cours sans le traduire
 * repasserait un titre en anglais sans que rien ne le signale.
 */
class CourseNameTranslationTest {

    private val catalog = File("../../ChessLab/Resources/openings/opening_catalog.json").also {
        require(it.isFile) { "catalogue introuvable : ${it.absolutePath}" }
    }
    private val strings = File("../../ChessLab/Localizable.xcstrings").also {
        require(it.isFile) { "catalogue de localisation introuvable : ${it.absolutePath}" }
    }

    private fun names(): List<Pair<String, String>> {
        val array = JSONArray(catalog.readText())
        return (0 until array.length()).map { i ->
            val o = array.getJSONObject(i)
            o.optString("kind", "opening") to o.getString("name")
        }
    }

    private fun french(): Map<String, String> {
        val table = JSONObject(strings.readText()).getJSONObject("strings")
        val out = HashMap<String, String>()
        for (key in table.keys()) {
            val value = table.optJSONObject(key)
                ?.optJSONObject("localizations")
                ?.optJSONObject("fr")
                ?.optJSONObject("stringUnit")
                ?.optString("value")
                ?.takeIf { it.isNotEmpty() }
            if (value != null) out[key] = value
        }
        return out
    }

    @Test fun `chaque cours a un nom francais`() {
        val fr = french()
        val missing = names().filter { (_, name) -> fr[name] == null }
        assertTrue(
            "sans traduction française : " + missing.joinToString { "${it.first}/${it.second}" },
            missing.isEmpty(),
        )
    }

    /** Les 78 finales en font partie : c'est là que le défaut se voyait le plus. */
    @Test fun `les finales aussi`() {
        val fr = french()
        val endgames = names().filter { it.first == "endgame" }
        assertEquals(78, endgames.size)
        assertTrue(endgames.all { fr[it.second] != null })
        // Et la traduction dit VRAIMENT autre chose que l'anglais, au moins
        // là où les deux langues diffèrent : une clé recopiée telle quelle
        // passerait ce test sans rien traduire.
        assertEquals("L'opposition", fr["The Opposition"])
    }

    @Test fun `les ouvertures aussi`() {
        val fr = french()
        assertEquals("Partie italienne", fr["Italian Game"])
        assertEquals("Défense sicilienne", fr["Sicilian Defense"])
    }
}
