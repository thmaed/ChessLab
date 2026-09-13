package com.chesslab.courses

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

/**
 * Le magasin des répertoires personnels : ce qui entre est validé, ce qui est
 * écrit se relit au format des cours embarqués, et ce qu'on supprime disparaît.
 */
class UserOpeningStoreTest {

    private lateinit var dir: File

    @Before fun setUp() {
        dir = Files.createTempDirectory("user-openings").toFile()
        UserOpeningStore.attach(dir)
    }

    @After fun tearDown() { dir.deleteRecursively() }

    private fun imported(pgn: String = "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *", name: String = "Espagnole") =
        OpeningPgnImporter.course(pgn, name, "white", UserOpeningStore.newIdentifier(), "Répertoire importé") { "Chapitre $it" }.course

    @Test fun `un cours enregistre se relit tel quel`() {
        val course = imported()
        val entry = UserOpeningStore.save(course)
        assertTrue(UserOpeningStore.isUserCourse(entry.id))
        assertEquals("club", entry.level)
        assertEquals(6, entry.maxDepth)

        // Relu depuis le DISQUE, par le même décodeur que les cours embarqués.
        UserOpeningStore.reload()
        val back = UserOpeningStore.course(course.id)!!
        assertEquals(course.positions.keys, back.positions.keys)
        assertEquals(course.moves(course.rootFEN).map { it.san }, back.moves(back.rootFEN).map { it.san })
        assertEquals(listOf(entry.id), UserOpeningStore.catalog().map { it.id })
    }

    @Test fun `un graphe incoherent n'entre pas`() {
        val course = imported()
        val broken = course.copy(positions = course.positions + (course.rootFEN to listOf(
            CourseMove("Ke5", "e1e5", "nulle-part", "sideline", null, null, null)
        )))
        try { UserOpeningStore.save(broken); fail("un graphe incohérent devrait être refusé") }
        catch (e: UserOpeningStore.StoreException) { assertTrue(e.issues.isNotEmpty()) }
        assertTrue(UserOpeningStore.catalog().isEmpty())
    }

    @Test fun `supprimer retire le fichier et l'entree`() {
        val entry = UserOpeningStore.save(imported())
        assertTrue(File(dir, "${entry.id}.json").exists())
        UserOpeningStore.delete(entry.id)
        assertTrue(!File(dir, "${entry.id}.json").exists())
        assertNull(UserOpeningStore.course(entry.id))
        assertTrue(UserOpeningStore.catalog().isEmpty())
    }

    @Test fun `un fichier partage entre sous une nouvelle identite`() {
        val entry = UserOpeningStore.save(imported(name = "À partager"))
        val json = UserOpeningStore.exportJson(entry.id)!!
        val received = UserOpeningStore.importCourseFile(json)
        assertTrue(received.id != entry.id)
        assertEquals("À partager", received.name)
        assertEquals(2, UserOpeningStore.catalog().size)
        // Et les deux graphes sont les mêmes : seule l'identité a changé.
        assertEquals(UserOpeningStore.course(entry.id)!!.positions.keys, UserOpeningStore.course(received.id)!!.positions.keys)
    }

    @Test fun `le format ecrit est celui des cours embarques`() {
        val course = imported("1. e4 {Le centre} e5 *")
        val json = org.json.JSONObject(CourseJson.encode(course))
        assertEquals(1, json.getInt("schemaVersion"))
        assertEquals("opening", json.getString("kind"))
        assertEquals("white", json.getString("side"))
        val root = json.getJSONObject("positions").getJSONObject(course.rootFEN)
        val e4 = root.getJSONArray("moves").getJSONObject(0)
        assertEquals("e4", e4.getString("san"))
        assertEquals("validated", e4.getString("commentStatus"))
        assertEquals("Le centre", e4.getJSONObject("comment").getString("fr"))
        assertNotNull(json.getJSONArray("chapters").getJSONObject(0).getJSONObject("title").getString("en"))
    }
}
