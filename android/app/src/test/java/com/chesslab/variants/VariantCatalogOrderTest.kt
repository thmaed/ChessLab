package com.chesslab.variants

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * L'ordre des douze variantes dans le hub, verrouillé.
 *
 * Il n'est ni alphabétique ni technique : il va du plus familier au plus
 * dépaysant, et c'est celui d'iOS (`VariantsHubView`). Six tuiles sur douze
 * étaient à la mauvaise place — le Crazyhouse avant les Antéchecs, le Duck
 * Chess avant le Coup Volé, et les Barricades au milieu alors qu'elles
 * ferment la marche.
 *
 * Ce genre d'écart ne casse rien et ne se voit qu'en posant les deux
 * téléphones côte à côte. D'où ce test : ajouter une variante demandera de
 * décider explicitement où elle va, des deux côtés.
 */
class VariantCatalogOrderTest {

    /** L'ordre d'iOS, relevé dans `VariantsHubView.swift`. */
    private val ordreIOS = listOf(
        "chess960",        // on y joue aux échecs ordinaires, depuis ailleurs
        "kingofthehill",   // puis celles qui ajoutent une condition de victoire
        "3check",
        "horde",
        "racingkings",
        "atomic",          // puis celles qui changent les règles du mouvement
        "antichess",
        "crazyhouse",
        "stolenmove",
        "duck",
        "barricades",      // et celles qui modifient l'échiquier ferment la marche
        "randombarricades",
    )

    @Test fun `les douze variantes sont dans l'ordre du hub iOS`() {
        assertEquals(ordreIOS, VariantCatalog.all.map { it.id })
    }

    @Test fun `il y en a douze, ni plus ni moins`() {
        assertEquals(12, VariantCatalog.all.size)
        assertEquals(12, VariantCatalog.all.map { it.id }.toSet().size)
    }

    @Test fun `chacune se retrouve par son identifiant`() {
        for (id in ordreIOS) {
            assertTrue("« $id » introuvable au catalogue", VariantCatalog.byId(id) != null)
        }
    }

    /**
     * Les cinq dont le nom ne tient pas sur une tuile étroite ont un nom
     * court ; les autres gardent le leur. C'est la règle d'iOS, où le nom
     * court sert sur iPhone et le long sur iPad.
     */
    @Test fun `seules les variantes au nom long en ont un court`() {
        val aNomCourt = VariantCatalog.all
            .filter { it.shortTitleRes != it.titleRes }
            .map { it.id }
            .toSet()
        assertEquals(
            setOf("kingofthehill", "3check", "racingkings", "duck", "randombarricades"),
            aNomCourt,
        )
    }

    /** Une variante sans description de règles serait un écran vide. */
    @Test fun `chacune porte un titre, un sous-titre et ses règles`() {
        for (v in VariantCatalog.all) {
            assertTrue("${v.id} : titre", v.titleRes != 0)
            assertTrue("${v.id} : sous-titre", v.shortRes != 0)
            assertTrue("${v.id} : règles", v.blurbRes != 0)
        }
    }
}
