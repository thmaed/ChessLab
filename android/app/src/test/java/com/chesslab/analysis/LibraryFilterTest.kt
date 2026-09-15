package com.chesslab.analysis

import com.chesslab.library.GameRecord
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Le tri de la bibliothèque : recherche, mode, résultat, étiquette.
 *
 * Fonction pure, donc vérifiable sans écran — et c'est ce qu'on veut, parce
 * qu'un filtre faux ne se voit pas : il MASQUE des parties, et on croit
 * simplement ne pas les avoir jouées.
 */
class LibraryFilterTest {

    private fun game(
        id: Long, white: String = "Vous", black: String = "Maia",
        result: String = "1-0", source: String = "engine",
        engineColor: String? = "black", tags: String? = null,
    ) = GameRecord(
        id = id, playedAt = id, white = white, black = black, result = result,
        source = source, moveCount = 20, pgn = "", engineColor = engineColor, tags = tags,
    )

    private val library = listOf(
        game(1, tags = "ouverture, à revoir"),
        game(2, result = "0-1"),
        game(3, result = "1/2-1/2"),
        game(4, white = "Thierry", black = "Camille", source = "twoPlayer", engineColor = null),
        game(5, white = "Carlsen", black = "Nepo", source = "imported", engineColor = null, tags = "classique"),
    )

    @Test fun `sans filtre, tout passe`() {
        assertEquals(5, filter(library, "", null, ResultFilter.all, null).size)
    }

    @Test fun `la recherche porte sur les noms`() {
        val found = filter(library, "camille", null, ResultFilter.all, null)
        assertEquals(listOf(4L), found.map { it.id })
    }

    @Test fun `la recherche porte aussi sur les etiquettes`() {
        val found = filter(library, "à revoir", null, ResultFilter.all, null)
        assertEquals(listOf(1L), found.map { it.id })
    }

    @Test fun `la recherche ignore la casse`() {
        assertEquals(1, filter(library, "CARLSEN", null, ResultFilter.all, null).size)
    }

    @Test fun `le mode filtre par source`() {
        assertEquals(listOf(4L), filter(library, "", "twoPlayer", ResultFilter.all, null).map { it.id })
        assertEquals(listOf(5L), filter(library, "", "imported", ResultFilter.all, null).map { it.id })
    }

    /**
     * Le résultat est celui de L'UTILISATEUR, pas celui du PGN : une partie
     * « 0-1 » est une victoire quand il avait les Noirs.
     */
    @Test fun `gagnee se lit du point de vue de l utilisateur`() {
        val won = filter(library, "", null, ResultFilter.wins, null)
        assertEquals(listOf(1L), won.map { it.id })

        val blackWin = game(9, result = "0-1", engineColor = "white")
        assertEquals(ResultFilter.wins, userResult(blackWin))
    }

    @Test fun `perdue et nulle se lisent pareil`() {
        assertEquals(listOf(2L), filter(library, "", null, ResultFilter.losses, null).map { it.id })
        assertEquals(listOf(3L), filter(library, "", null, ResultFilter.draws, null).map { it.id })
    }

    /** Une partie à deux n'a pas de « vous » : elle reste neutre, jamais perdue. */
    @Test fun `une partie a deux n est ni gagnee ni perdue`() {
        assertEquals(ResultFilter.all, userResult(library[3]))
        assertEquals(0, filter(library, "", null, ResultFilter.losses, null).count { it.id == 4L })
    }

    @Test fun `l etiquette filtre sans tenir compte de la casse`() {
        assertEquals(listOf(1L), filter(library, "", null, ResultFilter.all, "OUVERTURE").map { it.id })
    }

    @Test fun `les filtres se combinent`() {
        val found = filter(library, "vous", "engine", ResultFilter.wins, "ouverture")
        assertEquals(listOf(1L), found.map { it.id })
    }

    @Test fun `les etiquettes se decoupent et se nettoient`() {
        assertEquals(listOf("ouverture", "à revoir"), library[0].tagList)
        assertEquals(emptyList<String>(), library[1].tagList)
    }
}
