package com.chesslab.play

import com.chesslab.maia.OpponentGallery
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Le VRAI fichier de répertoires, pas un livre inventé pour le test.
 *
 * Ce qui est vérifié ici n'est pas le tirage — `OpeningBookTest` s'en charge —
 * mais l'ACCORD entre les données et le code : un identifiant qui ne
 * correspondrait pas ferait échouer la recherche en silence, et chaque
 * personnage jouerait sans son répertoire sans que rien ne le dise. C'était
 * exactement la situation avant le 12/09 : le fichier était embarqué, et
 * personne ne le lisait.
 */
class OpponentBooksTest {

    /**
     * Le fichier vit chez iOS et est recopié dans les assets au build. Les
     * tests JVM tournent depuis `android/app`, d'où la remontée de deux crans.
     */
    private fun resource(name: String): File {
        val f = File("../../ChessLab/Resources/$name")
        require(f.exists()) { "fichier introuvable : ${f.absolutePath}" }
        return f
    }

    private val json by lazy { resource("opponent_books.json").readText() }

    @Test fun `chaque personnage du fichier existe dans la galerie`() {
        val books = OpeningBookStore.parseOpponents(json)
        assertTrue("le fichier devrait porter plusieurs répertoires", books.size >= 8)
        books.keys.forEach { id ->
            assertTrue("personnage inconnu dans la galerie : $id", OpponentGallery.byId(id) != null)
        }
    }

    @Test fun `chaque répertoire propose un premier coup`() {
        OpeningBookStore.parseOpponents(json).forEach { (id, roots) ->
            val premier = OpeningBookPicker.pick(roots, emptyList(), BookWidth.includeSidelines)
            assertTrue("$id n'a pas de premier coup", premier != null)
        }
    }

    @Test fun `les personnages n'ouvrent pas tous pareil`() {
        // C'est TOUT l'intérêt du répertoire. Attention : ils proposent tous
        // les mêmes QUATRE premiers coups (e4, d4, c4, Cf3) — ce qui les
        // distingue, ce sont les POIDS, donc la fréquence à laquelle chacun
        // sort. Comparer les ensembles de coups ne dirait rien.
        val poids = OpeningBookStore.parseOpponents(json).mapValues { (_, roots) ->
            roots.associate { it.san to it.weight }
        }
        assertTrue("tous les répertoires ont les mêmes poids : $poids", poids.values.toSet().size > 1)

        // Et le coup PRÉFÉRÉ n'est pas le même pour tout le monde.
        val prefere = poids.mapValues { (_, w) -> w.maxByOrNull { it.value }?.key }
        assertTrue("tous préfèrent le même premier coup : $prefere", prefere.values.toSet().size > 1)
    }

    @Test fun `un répertoire descend sur plusieurs coups`() {
        val books = OpeningBookStore.parseOpponents(json)
        val profondeur = books.values.maxOf { profondeur(it) }
        assertTrue("un livre d'un seul coup ne sert à rien : $profondeur", profondeur >= 4)
    }

    private fun profondeur(nodes: List<BookNode>): Int =
        if (nodes.isEmpty()) 0 else 1 + nodes.maxOf { profondeur(it.children) }

    @Test fun `le livre général se lit aussi`() {
        val roots = OpeningBookStore.parse(resource("opening_book.json").readText())
        assertTrue("le livre général est vide", roots.isNotEmpty())
        assertTrue("pas de premier coup", OpeningBookPicker.pick(roots, emptyList(), BookWidth.mainLinesOnly) != null)
    }
}
