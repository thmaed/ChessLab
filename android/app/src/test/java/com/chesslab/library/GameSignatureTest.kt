package com.chesslab.library

import com.chesslab.settings.SettingsStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Reconnaître une partie déjà rangée. Pendant de `LibraryDuplicateTests.swift`.
 *
 * L'import Android n'écartait aucun doublon : réimporter le même fichier
 * doublait la bibliothèque.
 */
class GameSignatureTest {

    private val scholars = """
        [Event "Test"]
        [White "Alice"]
        [Black "Bob"]
        [Result "1-0"]

        1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0
    """.trimIndent()

    @Test fun laSuiteDeCoupsNeGardeQueLesCoups() {
        assertEquals("e4 e5 Bc4 Nc6 Qh5 Nf6 Qxf7#", GameSignature.movetext(scholars))
    }

    @Test fun commentairesEtVariantesSontIgnores() {
        val annotated = """
            [White "Alice"]
            [Black "Bob"]

            1. e4 {une bonne case} e5 2. Bc4 (2. Nf3 Nc6) 2... Nc6 3. Qh5!? Nf6?? 4. Qxf7# 1-0
        """.trimIndent()
        assertEquals(GameSignature.movetext(scholars), GameSignature.movetext(annotated))
    }

    /** LE cas réel : mêmes coups, mêmes joueurs, présentation différente. */
    @Test fun laMemePartieDeDeuxSourcesEstUneSeulePartie() {
        val other = """
            [Event "Autre tournoi"]
            [Site "Ailleurs"]
            [Date "2024.01.01"]
            [White "alice"]
            [Black "BOB"]
            [Result "1-0"]
            [ECO "C20"]

            1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6 4.Qxf7# 1-0
        """.trimIndent()
        assertEquals(GameSignature.of(scholars), GameSignature.of(other))
    }

    /** Le garde-fou inverse : mêmes coups, autres joueurs, deux parties. */
    @Test fun dAutresJoueursFontUneAutrePartie() {
        val other = scholars.replace("Alice", "Carole").replace("Bob", "David")
        assertNotEquals(GameSignature.of(scholars), GameSignature.of(other))
    }

    /**
     * « ? » vaut ABSENT : une partie rangée avant que l'app n'émette les sept
     * balises, puis réimportée depuis un export qui note l'inconnu « ? », est
     * la MÊME partie.
     */
    @Test fun unJoueurInconnuVautPasDeJoueurDuTout() {
        val bare = "1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0"
        val questionMarks = """
            [White "?"]
            [Black "?"]
            [Result "1-0"]

            1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0
        """.trimIndent()
        assertEquals(GameSignature.of(bare), GameSignature.of(questionMarks))
    }

    @Test fun unPgnIllisibleNaPasDeSignature() {
        assertNull(GameSignature.of(""))
    }

    // ------------------------------------------------------- le nom choisi

    /** Ce nom part dans des balises PGN : ni guillemet, ni crochet, ni saut de ligne, et borné. */
    @Test fun leNomChoisiEstNettoye() {
        assertEquals("Ron Rocket Lasser", SettingsStore.sanitizedPlayerName("Ron \"Rocket\" Lasser"))
        assertEquals("Ron Lasser", SettingsStore.sanitizedPlayerName("[Ron]\nLasser"))
        // Les espaces survivent à la frappe : on les coupe à la lecture.
        assertEquals("Ron ", SettingsStore.sanitizedPlayerName("Ron "))
        assertEquals(
            SettingsStore.PLAYER_NAME_MAX_LENGTH,
            SettingsStore.sanitizedPlayerName("a".repeat(200)).length,
        )
    }
}
