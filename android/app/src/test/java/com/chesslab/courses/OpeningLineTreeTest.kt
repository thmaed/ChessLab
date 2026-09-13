package com.chesslab.courses

import chesskit.Board
import chesskit.Piece
import chesskit.Position
import chesskit.SanParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * L'ARBRE des lignes : chaque coup écrit une fois, les débranchements
 * imbriqués, et surtout le CHEMIN derrière chaque coup — c'est lui qui fait
 * atterrir au bon endroit quand on tape un coup au milieu d'une variante.
 *
 * Les cas sont ceux d'`OpeningLineTreeTests.swift`, un à un ; les bornes
 * mesurées sur le catalogue livré sont les mêmes des deux côtés.
 */
class OpeningLineTreeTest {

    // MARK: Fixtures

    /**
     * Un cours à DEUX branches partageant leur début :
     *
     *     1.e4 e5 2.Cf3  →  2…Cc6 3.Fb5   (« espagnole », ligne principale)
     *                    →  2…Cf6         (« russe »)
     */
    private fun branchingCourse(): Course {
        val edges = LinkedHashMap<String, MutableList<CourseMove>>()

        fun walk(sans: List<String>, role: String): List<String> {
            val board = Board(Position.standard)
            val keys = arrayListOf(CourseRepository.key(board.position))
            for (san in sans) {
                val parsed = SanParser.parse(san, board.position) ?: break
                val applied = board.move(parsed.start, parsed.end) ?: break
                val from = keys.last()
                val to = CourseRepository.key(board.position)
                val list = edges.getOrPut(from) { ArrayList() }
                if (list.none { it.toFEN == to }) {
                    list += CourseMove(applied.san, applied.lan, to, role, null, null, null)
                }
                keys += to
            }
            return keys
        }

        val spanish = walk(listOf("e4", "e5", "Nf3", "Nc6", "Bb5"), "mainLine")
        val russian = walk(listOf("e4", "e5", "Nf3", "Nf6"), "sideline")
        val positions = (spanish + russian).toSet().associateWith { edges[it].orEmpty().toList() }
        return Course(
            id = "fixture-tree", name = "Deux branches", summary = "", side = "white",
            rootFEN = spanish.first(),
            chapters = listOf(
                Chapter("spanish", "Espagnole", spanish),
                Chapter("russian", "Russe", russian),
            ),
            positions = positions,
        )
    }

    /** Les cours vivent chez iOS et sont recopiés dans les assets au build. */
    private val dir = File("../../ChessLab/Resources/openings").also {
        require(it.isDirectory) { "cours introuvables : ${it.absolutePath}" }
    }

    private fun shippedOpenings(): List<Course> =
        dir.listFiles { f -> f.name.endsWith(".json") && f.name != "opening_catalog.json" && !f.name.startsWith("eg-") }!!
            .sortedBy { it.name }
            .map { CourseRepository.parse(it.readText()) }

    // MARK: Structure

    @Test fun `une rangee s'arrete a la premiere deviation`() {
        val root = OpeningLineTree.build(branchingCourse())!!
        assertEquals(0, root.depth)
        assertEquals("la rangée s'arrête là où le choix se pose, pas après",
            listOf("e4", "e5", "Nf3"), root.moves.map { it.san })
        assertEquals("les deux suites descendent d'un étage", 2, root.children.size)

        val all = root.flattened.flatMap { it.moves }.map { it.id }
        assertEquals("un coup apparaît deux fois dans l'arbre", all.toSet().size, all.size)
    }

    @Test fun `toutes les suites descendent d'un etage, la principale comprise`() {
        val root = OpeningLineTree.build(branchingCourse())!!
        val branches = root.children
        assertEquals(listOf("Nc6", "Nf6"), branches.map { it.moves.first().san })
        assertEquals("la ligne principale est le rang 0, pas une exception", listOf(0, 1), branches.map { it.rank })
        assertTrue(branches.all { it.depth == 1 })
        assertEquals("la branche court jusqu'à la déviation suivante", listOf("Nc6", "Bb5"), branches[0].moves.map { it.san })
    }

    @Test fun `la ligne principale se suit par les rangs zero`() {
        val root = OpeningLineTree.build(branchingCourse())!!
        assertTrue("la rangée de tête est la ligne principale", root.isOnMainLine)
        assertTrue("le rang 0 la prolonge", root.children[0].isOnMainLine)
        assertFalse("un rang 1 n'en fait pas partie", root.children[1].isOnMainLine)
    }

    @Test fun `une variante ne redevient jamais la ligne principale`() {
        val offenders = ArrayList<String>()
        for (course in shippedOpenings()) {
            val root = OpeningLineTree.build(course) ?: continue
            fun check(node: OpeningLineTree.Node) {
                for (child in node.children) {
                    if (child.isOnMainLine && !node.isOnMainLine) offenders += "${course.id} : ${child.moves.first().san}"
                }
                node.children.forEach(::check)
            }
            check(root)
        }
        assertTrue("des variantes redeviennent ligne principale : ${offenders.take(5)}", offenders.isEmpty())
    }

    @Test fun `la ligne principale existe et reste minoritaire`() {
        var main = 0; var total = 0
        for (course in shippedOpenings()) {
            val rows = (OpeningLineTree.build(course) ?: continue).flattened
            val onMain = rows.count { it.isOnMainLine }
            assertTrue("${course.id} : aucune ligne principale", onMain > 0)
            main += onMain; total += rows.size
        }
        assertTrue(total > 500)
        val share = main.toDouble() / total
        assertTrue("la ligne principale couvre $share des rangées : le gras ne distingue plus", share < 0.5)
    }

    @Test fun `l'aplatissement suit l'ordre de lecture`() {
        val rows = OpeningLineTree.build(branchingCourse())!!.flattened
        assertEquals(3, rows.size)
        assertEquals(listOf(0, 1, 1), rows.map { it.depth })
        assertEquals(listOf("e4", "Nc6", "Nf6"), rows.map { it.moves.firstOrNull()?.san })
        assertEquals("deux rangées partagent leur identifiant", rows.size, rows.map { it.id }.toSet().size)
    }

    // MARK: Sauts

    @Test fun `chaque coup porte le chemin complet qui y mene`() {
        val course = branchingCourse()
        val root = OpeningLineTree.build(course)!!

        val bb5 = root.children.first().moves.last()
        assertEquals("Bb5", bb5.san)
        assertEquals(listOf("e2e4", "e7e5", "g1f3", "b8c6", "f1b5"), bb5.path)

        val nf6 = root.children.last().moves.first()
        assertEquals("Nf6", nf6.san)
        assertEquals("chaque branche repart de son point de déviation", listOf("e2e4", "e7e5", "g1f3", "g8f6"), nf6.path)

        for (move in listOf(bb5, nf6)) {
            var key = CourseRepository.fenKey(course.rootFEN)
            for (uci in move.path) {
                val edge = course.moves(key).first { it.uci == uci }
                key = CourseRepository.fenKey(edge.toFEN)
            }
            assertEquals("${move.san} n'atterrit pas sur sa position", move.toFEN, key)
        }
    }

    @Test fun `le numero de coup suit la ligne, blancs impairs`() {
        val root = OpeningLineTree.build(branchingCourse())!!
        val trunk = root.moves
        val spanish = root.children.first().moves

        assertEquals(listOf(1, 2, 3), trunk.map { it.ply })
        assertEquals(listOf(Piece.Color.white, Piece.Color.black, Piece.Color.white), trunk.map { it.color })
        // Une branche garde le numéro de coup de la ligne : elle part du
        // 4ᵉ demi-coup, elle s'annonce « 2…Cc6 ».
        assertEquals(listOf(4, 5), spanish.map { it.ply })
        assertEquals("2…", spanish[0].numberPrefix(isFirstOfLine = true))
        assertNull(spanish[0].numberPrefix(isFirstOfLine = false))
        assertEquals("3.", spanish[1].numberPrefix(isFirstOfLine = false))
    }

    // MARK: Transpositions et cycles

    @Test fun `une transposition s'arrete au lieu de se deplier deux fois`() {
        val base = branchingCourse()
        // La fin de l'espagnole renvoie vers la position après 2.Cf3 : cycle.
        val spanishEnd = base.chapters[0].positionFENs.last()
        val afterNf3 = base.chapters[1].positionFENs[3]
        val positions = base.positions.toMutableMap()
        positions[spanishEnd] = listOf(CourseMove("→", "a1a1", afterNf3, "sideline", null, null, null))
        val cyclic = base.copy(positions = positions)

        val rows = OpeningLineTree.build(cyclic)!!.flattened
        assertTrue("la boucle doit être signalée", rows.any { it.isTransposition })
        val all = rows.flatMap { it.moves }.map { it.id }
        assertEquals("aucun coup dupliqué malgré le cycle", all.toSet().size, all.size)
    }

    // MARK: Titres de chapitre

    @Test fun `un titre de chapitre se pose sur sa branche`() {
        val root = OpeningLineTree.build(branchingCourse())!!
        assertNull("la rangée de tête ne porte pas de titre : c'est l'ouverture", root.chapterTitle)
        assertNull("l'espagnole EST la ligne principale", root.children[0].chapterTitle)
        assertEquals("la russe s'annonce sur sa branche", "Russe", root.children[1].chapterTitle)
    }

    @Test fun `un cours sans coup ne produit pas d'arbre`() {
        val empty = Course(
            id = "vide", name = "Vide", summary = "", side = "white", rootFEN = "8/8/8/8/8/8/8/K6k w - -",
            chapters = emptyList(), positions = mapOf("8/8/8/8/8/8/8/K6k w - -" to emptyList()),
        )
        assertNull(OpeningLineTree.build(empty))
    }

    // MARK: L'arbre des cours RÉELLEMENT livrés

    @Test fun `tout chemin de l'arbre se rejoue dans le graphe livre`() {
        var checked = 0
        for (course in shippedOpenings().take(12)) {
            val root = OpeningLineTree.build(course)
            assertNotNull("${course.id} : pas d'arbre", root)
            for (row in root!!.flattened) for (move in row.moves) {
                var key = CourseRepository.fenKey(course.rootFEN)
                for (uci in move.path) {
                    val edge = course.moves(key).firstOrNull { it.uci == uci }
                    assertNotNull("${course.id} : chemin rompu sur $uci", edge)
                    key = CourseRepository.fenKey(edge!!.toFEN)
                }
                assertEquals("${course.id} : ${move.san} n'atterrit pas sur sa position", move.toFEN, key)
                checked++
            }
        }
        assertTrue("l'échantillon doit être significatif (obtenu : $checked)", checked > 500)
    }

    @Test fun `les identifiants de rangees et de coups sont uniques`() {
        var courses = 0
        for (course in shippedOpenings()) {
            val rows = (OpeningLineTree.build(course) ?: continue).flattened
            val rowIds = rows.map { it.id }
            assertEquals("${course.id} : deux rangées partagent leur identifiant", rowIds.toSet().size, rowIds.size)
            val moveIds = rows.flatMap { it.moves }.map { it.id }
            assertEquals("${course.id} : un coup apparaît deux fois", moveIds.toSet().size, moveIds.size)
            courses++
        }
        assertTrue("tout le catalogue doit être couvert (obtenu : $courses)", courses > 50)
    }

    /**
     * À une déviation, la LIGNE PRINCIPALE est dépliée avant ses alternatives.
     * Sinon une variante qui transpose plus loin dans la ligne principale
     * réclame la position avant elle, et c'est la ligne principale qui
     * s'arrête sur un « transposition » — l'inverse de ce qu'on veut lire.
     */
    @Test fun `la ligne principale est depliee avant ses alternatives`() {
        val edges = LinkedHashMap<String, MutableList<CourseMove>>()
        fun line(sans: List<String>, role: String): List<String> {
            val board = Board(Position.standard)
            val keys = arrayListOf(CourseRepository.key(board.position))
            for (san in sans) {
                val parsed = SanParser.parse(san, board.position) ?: break
                val applied = board.move(parsed.start, parsed.end) ?: break
                val from = keys.last(); val to = CourseRepository.key(board.position)
                val list = edges.getOrPut(from) { ArrayList() }
                if (list.none { it.toFEN == to }) list += CourseMove(applied.san, applied.lan, to, role, null, null, null)
                keys += to
            }
            return keys
        }
        // Deux ordres de coups qui MÈNENT À LA MÊME POSITION : la ligne
        // principale doit être celle qui se déplie, la seconde hérite du repère.
        val main = line(listOf("d4", "d5", "Nf3", "Nf6"), "mainLine")
        line(listOf("Nf3", "d5", "d4", "Nf6"), "sideline")
        val positions = HashMap<String, List<CourseMove>>()
        for ((key, moves) in edges) positions[key] = moves
        for (key in main) positions.putIfAbsent(key, emptyList())
        val course = Course("fixture-transpo", "Transposition", "", "white", main.first(), emptyList(), positions)

        val rows = OpeningLineTree.build(course)!!.flattened
        // Le tronc de ce montage est VIDE (le choix se pose dès le premier
        // coup) : on regarde le premier coup s'il existe, comme `first?.san`.
        val mainBranch = rows.first { it.moves.firstOrNull()?.san == "d4" }
        val sideBranch = rows.first { it.moves.firstOrNull()?.san == "Nf3" }
        assertEquals(0, mainBranch.rank)
        assertFalse("la ligne principale doit se déplier", mainBranch.isTransposition)
        assertTrue("c'est la ligne principale qui porte la suite, pas l'alternative",
            mainBranch.moves.size > sideBranch.moves.size)
        val all = rows.flatMap { it.moves }.map { it.id }
        assertEquals(all.toSet().size, all.size)
    }

    /** L'arbre doit rester LISIBLE : si ces bornes explosent, l'écran redevient un pavé. */
    @Test fun `l'arbre livre reste borne en rangees et en profondeur`() {
        val rowCounts = ArrayList<Int>(); var deepest = 0
        for (course in shippedOpenings()) {
            val rows = (OpeningLineTree.build(course) ?: continue).flattened
            rowCounts += rows.size
            deepest = maxOf(deepest, rows.maxOf { it.depth })
        }
        assertTrue(rowCounts.size > 50)
        val biggest = rowCounts.max()
        assertTrue("une ouverture produit $biggest rangées : l'arbre ne compresse plus", biggest <= 200)
        assertTrue("débranchement de profondeur $deepest : le retrait n'a plus de place", deepest <= 12)
        assertTrue("aucune imbrication : l'arbre ne débranche plus", deepest >= 3)
    }

    /** Sur la donnée livrée, les titres écrits à la main doivent trouver leur branche. */
    @Test fun `les titres de chapitre trouvent leur branche`() {
        val course = CourseRepository.parse(File(dir, "italian-game.json").readText())
        val rows = OpeningLineTree.build(course)!!.flattened
        fun head(title: String) = rows.firstOrNull { it.chapterTitle?.contains(title) == true }?.moves?.first()?.san

        assertEquals("le gambit Evans s'annonce sur 4.b4", "b4", head("Evans"))
        assertEquals("Nxd5", head("Fried Liver"))
        assertEquals("Be7", head("ongroise"))
        assertEquals("Bc5", head("Traxler"))

        val titles = rows.mapNotNull { it.chapterTitle }
        assertEquals("un titre est posé sur deux branches", titles.toSet().size, titles.size)
    }
}
