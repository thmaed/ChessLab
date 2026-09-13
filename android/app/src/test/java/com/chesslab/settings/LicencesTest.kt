package com.chesslab.settings

import com.chesslab.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * La liste des licences est une DONNÉE, et une donnée se vérifie : la
 * GPLv3 n'est honorée que si Stockfish, Fairy-Stockfish et le dépôt des
 * sources y figurent, chacun avec son lien.
 */
class LicencesTest {

    @Test fun `chaque composant porte un identifiant unique et un lien sur`() {
        val entries = Licences.entries
        assertTrue("au moins les dix entrées d'iOS", entries.size >= 10)
        assertEquals(entries.size, entries.map { it.id }.toSet().size)
        entries.forEach { assertTrue(it.url, it.url.startsWith("https://")) }
    }

    @Test fun `la GPLv3 est visible - les deux moteurs et le depot des sources`() {
        val gpl = Licences.entries.filter { it.licence == R.string.lic_gplv3 || it.licence == R.string.lic_gplv3_whole }
        assertTrue(gpl.any { it.id == "stockfish" && it.url == "https://stockfishchess.org" })
        assertTrue(gpl.any { it.id == "fairy" && it.url == "https://fairy-stockfish.github.io" })
        assertTrue(gpl.any { it.id == "source" && it.url == "https://github.com/thmaed/ChessLab" })
    }

    @Test fun `ce qu'Android seul embarque est declare`() {
        val ids = Licences.entries.map { it.id }
        assertTrue("ONNX Runtime exécute les réseaux", "onnx" in ids)
        assertTrue("le détecteur du scanner", "yolo" in ids)
        assertTrue("l'attribution des pièces cburnett", "cburnett" in ids)
    }
}
