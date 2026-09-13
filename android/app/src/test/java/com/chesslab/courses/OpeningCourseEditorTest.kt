package com.chesslab.courses

import chesskit.Position
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * Édition d'un répertoire personnel : ajouter, retirer, commenter. Pendant
 * d'`OpeningCourseEditorTests.swift`, mêmes cas.
 *
 * Le test qui porte le reste est `retirer garde les positions transposées` :
 * le graphe est indexé par FEN, donc retirer une variante ne doit PAS emporter
 * les positions qu'une autre ligne atteint encore. Une purge naïve du
 * sous-arbre passerait tous les autres tests et casserait précisément ce qui
 * fait la valeur du graphe.
 *
 * Second garde-fou de fond : chaque cours produit doit passer
 * [OpeningCourseValidator] — c'est ce que fait `UserOpeningStore.save`, et un
 * éditeur qui fabrique un graphe invalide échoue à l'enregistrement, pas à
 * l'écran.
 */
class OpeningCourseEditorTest {

    private val root = CourseRepository.key(Position.standard)

    /** La clé canonique après une suite de coups UCI, calculée par le validateur. */
    private fun key(vararg ucis: String): String {
        var key = root
        for (uci in ucis) key = OpeningCourseValidator.resultingKey(uci, key)!!
        return key
    }

    /** 1.e4 e5 2.Cf3 Cc6, sur lequel on greffe — plus un chapitre qui cite tout. */
    private fun base(): Course {
        var course = Course(
            id = "user-edit", name = "Test", summary = "", side = "white",
            rootFEN = root, chapters = emptyList(), positions = mapOf(root to emptyList()),
        )
        var at = root
        for (uci in listOf("e2e4", "e7e5", "g1f3", "b8c6")) {
            course = OpeningCourseEditor.addMove(uci, at, course = course)
            at = OpeningCourseValidator.resultingKey(uci, at)!!
        }
        return course.copy(
            chapters = listOf(Chapter("ch1", "Ligne", course.positions.keys.toList())),
        )
    }

    private fun assertValid(course: Course) =
        assertEquals("graphe invalide", emptyList<OpeningCourseValidator.Issue>(), OpeningCourseValidator.validate(course))

    // MARK: Ajout

    @Test fun `ajouter cree l'arete et la position d'arrivee`() {
        val course = base()
        val from = key("e2e4", "e7e5")
        val edited = OpeningCourseEditor.addMove("f1c4", from, course = course)

        val edge = edited.moves(from).first { it.uci == "f1c4" }
        assertEquals("Bc4", edge.san)
        assertNotNull("la position d'arrivée doit exister", edited.positions[edge.toFEN])
        assertValid(edited)
    }

    /** Le SAN n'est jamais celui que l'appelant prétend : il est recalculé. */
    @Test fun `ajouter derive le SAN du plateau`() {
        val from = key("e2e4", "e7e5", "g1f3")
        val edited = OpeningCourseEditor.addMove("d7d6", from, course = base())
        assertEquals("d6", edited.moves(from).first { it.uci == "d7d6" }.san)
    }

    @Test fun `ajouter un coup illegal echoue`() {
        val from = key("e2e4", "e7e5")
        val error = errorOf { OpeningCourseEditor.addMove("e1e8", from, course = base()) }
        assertTrue(error is OpeningCourseEditor.EditError.IllegalMove)
    }

    /**
     * `canMove`/`legalMoves` ignorent le trait : sans garde explicite, on
     * fabriquerait une arête vers une position inatteignable, que le
     * validateur ne verrait pas puisqu'il rejoue avec la même mécanique.
     */
    @Test fun `ajouter un coup hors tour echoue`() {
        val course = base()
        // Racine : les Blancs ont le trait. On tente un coup NOIR.
        val error = errorOf { OpeningCourseEditor.addMove("e7e5", course.rootFEN, course = course) }
        assertTrue(error is OpeningCourseEditor.EditError.IllegalMove)
        assertNull(OpeningCourseEditor.play("e7e5", course.rootFEN))
    }

    @Test fun `ajouter depuis une position inconnue echoue`() {
        val error = errorOf { OpeningCourseEditor.addMove("e2e4", "PAS UNE FEN", course = base()) }
        assertTrue(error is OpeningCourseEditor.EditError.UnknownPosition)
    }

    @Test fun `ajouter deux fois le meme coup echoue`() {
        val from = key("e2e4", "e7e5")
        val once = OpeningCourseEditor.addMove("f1c4", from, course = base())
        val error = errorOf { OpeningCourseEditor.addMove("f1c4", from, course = once) }
        assertEquals(OpeningCourseEditor.EditError.DuplicateMove("Bc4"), error)
    }

    /**
     * Une transposition REJOINT le nœud existant au lieu d'en créer un second :
     * c'est la raison d'être du graphe indexé par FEN.
     */
    @Test fun `un coup qui transpose reutilise le noeud existant`() {
        // 1.e4 e5 2.Cf3 Cc6 existe déjà. On greffe 2.Cc3 puis on transpose.
        var course = base()
        course = OpeningCourseEditor.addMove("b1c3", key("e2e4", "e7e5"), course = course)
        course = OpeningCourseEditor.addMove("b8c6", key("e2e4", "e7e5", "b1c3"), course = course)

        val before = course.positions.size
        // 3.Cf3 depuis 2.Cc3 Cc6 mène à la MÊME position que 2.Cf3 Cc6 3.Cc3.
        course = OpeningCourseEditor.addMove("g1f3", key("e2e4", "e7e5", "b1c3", "b8c6"), course = course)

        assertNotNull(course.positions[key("e2e4", "e7e5", "b1c3", "b8c6", "g1f3")])
        assertEquals("un seul nœud neuf", before + 1, course.positions.size)
        assertValid(course)
    }

    // MARK: Retrait

    @Test fun `retirer enleve l'arete et ce qui devient inatteignable`() {
        val course = base()
        val afterE4 = key("e2e4")
        val edited = OpeningCourseEditor.removeMove("e7e5", afterE4, course)

        assertEquals(emptyList<CourseMove>(), edited.moves(afterE4))
        assertNull("la suite devient inatteignable", edited.positions[key("e2e4", "e7e5")])
        assertNull(edited.positions[key("e2e4", "e7e5", "g1f3", "b8c6")])
        assertNotNull("la racine survit toujours", edited.positions[edited.rootFEN])
        assertValid(edited)
    }

    /**
     * LE test de fond : une position encore atteinte par une autre ligne
     * SURVIT au retrait. Une purge du sous-arbre la supprimerait à tort.
     */
    @Test fun `retirer garde les positions transposees`() {
        var course = base()
        val afterE5 = key("e2e4", "e7e5")
        // Deuxième chemin vers 1.e4 e5 2.Cf3 Cc6 : 2.Cc3 Cc6 3.Cf3, transposition.
        course = OpeningCourseEditor.addMove("b1c3", afterE5, course = course)
        course = OpeningCourseEditor.addMove("b8c6", key("e2e4", "e7e5", "b1c3"), course = course)
        course = OpeningCourseEditor.addMove("g1f3", key("e2e4", "e7e5", "b1c3", "b8c6"), course = course)

        val shared = key("e2e4", "e7e5", "b1c3", "b8c6", "g1f3")
        assertNotNull(course.positions[shared])

        // On coupe la ligne 2.Cf3 : la position partagée reste jointe par 2.Cc3.
        val edited = OpeningCourseEditor.removeMove("g1f3", afterE5, course)
        assertNull("la branche coupée part", edited.positions[key("e2e4", "e7e5", "g1f3")])
        assertNotNull("mais la transposition la maintient jointe", edited.positions[shared])
        assertValid(edited)
    }

    @Test fun `retirer un coup absent ne change rien`() {
        val course = base()
        val edited = OpeningCourseEditor.removeMove("h2h4", course.rootFEN, course)
        assertEquals(course.positions.size, edited.positions.size)
    }

    /**
     * Un chapitre qui citerait une position disparue ferait échouer la
     * validation : les chapitres sont donc nettoyés en même temps.
     */
    @Test fun `retirer nettoie les chapitres qui pendent`() {
        val course = base()
        val removed = key("e2e4", "e7e5", "g1f3")
        assertTrue(course.chapters.first().positionFENs.contains(removed))

        val edited = OpeningCourseEditor.removeMove("g1f3", key("e2e4", "e7e5"), course)
        assertTrue(edited.chapters.flatMap { it.positionFENs }.none { it == removed })
        assertValid(edited)
    }

    /**
     * Vider un répertoire de toutes ses variantes reste légal : le fichier
     * doit rester valide, pas devenir irrécupérable. Le chapitre SURVIT en ne
     * gardant que la racine.
     */
    @Test fun `un repertoire vide reste valide`() {
        val course = base()
        val edited = OpeningCourseEditor.removeMove("e2e4", course.rootFEN, course)
        assertEquals(1, edited.positions.size)
        val referenced = edited.chapters.flatMap { it.positionFENs }
        assertEquals(listOf(edited.rootFEN), referenced)
        assertValid(edited)
    }

    // MARK: Commentaire

    /**
     * Le texte de l'auteur est écrit comme `validated`, sinon il resterait
     * invisible : la règle « pas de brouillon affiché » vise le contenu
     * GÉNÉRÉ, pas ce que l'auteur écrit de sa main. C'est [CourseJson] qui
     * porte le statut, donc le test passe par un aller-retour sur le fichier.
     */
    @Test fun `le commentaire est ecrit et se relit`() {
        val course = OpeningCourseEditor.setComment(
            "On occupe le centre.", "e2e4", base().rootFEN, base(),
        )
        assertEquals("On occupe le centre.", course.moves(course.rootFEN).first().comment)

        val reread = CourseRepository.parse(CourseJson.encode(course))
        assertEquals("On occupe le centre.", reread.moves(reread.rootFEN).first().comment)
    }

    @Test fun `un commentaire vide l'efface`() {
        var course = OpeningCourseEditor.setComment("À effacer", "e2e4", base().rootFEN, base())
        course = OpeningCourseEditor.setComment("   ", "e2e4", course.rootFEN, course)
        assertNull(course.moves(course.rootFEN).first().comment)

        val reread = CourseRepository.parse(CourseJson.encode(course))
        assertNull(reread.moves(reread.rootFEN).first().comment)
    }

    @Test fun `commenter un coup absent ne change rien`() {
        val course = base()
        assertEquals(course, OpeningCourseEditor.setComment("Texte", "h2h4", course.rootFEN, course))
    }

    // MARK: Renommage

    @Test fun `renommer taille les espaces et refuse le vide`() {
        val course = base()
        assertEquals("Ma Scandinave", OpeningCourseEditor.rename(course, "  Ma Scandinave  ").name)
        assertEquals(course.name, OpeningCourseEditor.rename(course, "   ").name)
    }

    private fun errorOf(block: () -> Unit): OpeningCourseEditor.EditError? {
        try {
            block()
        } catch (e: OpeningCourseEditor.EditException) {
            return e.error
        }
        fail("une erreur d'édition était attendue")
        return null
    }
}
