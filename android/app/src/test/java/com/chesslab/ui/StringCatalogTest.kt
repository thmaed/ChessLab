package com.chesslab.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Les DEUX catalogues, comparés clé par clé.
 *
 * Une clé présente d'un seul côté ne casse rien à la compilation : elle
 * retombe sur l'autre langue, et l'app parle français au milieu d'un écran
 * anglais — exactement le défaut d'`LocalizationController.string()` côté iOS,
 * où toute clé neuve doit être ajoutée à la main. Ici, elle se voit.
 *
 * Le second cas vérifié est celui des ARGUMENTS : `%1$s` d'un côté et `%1$d`
 * de l'autre plante à l'exécution, dans une seule langue, et seulement quand
 * l'écran s'affiche.
 */
class StringCatalogTest {

    private val english = File("src/main/res/values/strings_app.xml")
    private val french = File("src/main/res/values-fr/strings_app.xml")

    private fun entries(file: File): Map<String, String> {
        require(file.exists()) { "catalogue introuvable : ${file.absolutePath}" }
        val text = file.readText()
        return Regex("""<string name="([^"]+)">(.*?)</string>""", RegexOption.DOT_MATCHES_ALL)
            .findAll(text)
            .associate { it.groupValues[1] to it.groupValues[2] }
    }

    @Test fun `les deux langues portent exactement les memes cles`() {
        val en = entries(english)
        val fr = entries(french)
        assertEquals("clés sans traduction française", emptySet<String>(), en.keys - fr.keys)
        assertEquals("clés françaises sans anglais", emptySet<String>(), fr.keys - en.keys)
        assertTrue("le catalogue devrait être fourni", en.size > 400)
    }

    @Test fun `aucune cle n'est declaree deux fois`() {
        for (file in listOf(english, french)) {
            val names = Regex("""<string name="([^"]+)"""").findAll(file.readText())
                .map { it.groupValues[1] }.toList()
            val doubles = names.groupingBy { it }.eachCount().filterValues { it > 1 }.keys
            assertEquals("clés en double dans ${file.name}", emptySet<String>(), doubles)
        }
    }

    @Test fun `les arguments de format coincident`() {
        val en = entries(english)
        val fr = entries(french)
        val argument = Regex("""%(\d+)\$([sdf])""")
        for ((key, value) in en) {
            val other = fr[key] ?: continue
            // Les arguments sont comparés en ENSEMBLE, pas en liste : une
            // traduction a le droit de les remettre dans un autre ordre — c'est
            // même à cela que servent les indices positionnels.
            val here = argument.findAll(value).map { it.value }.toSet()
            val there = argument.findAll(other).map { it.value }.toSet()
            assertEquals("arguments différents pour « $key »", here, there)
        }
    }
}
