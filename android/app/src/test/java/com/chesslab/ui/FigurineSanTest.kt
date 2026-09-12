package com.chesslab.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/** Porté des cas de `FigurineSANTests.swift`. */
class FigurineSanTest {

    @Test fun `la lettre de pièce devient une figurine`() {
        assertEquals("♞f3", FigurineSan.format("Nf3"))
        assertEquals("♛xd5+", FigurineSan.format("Qxd5+"))
        assertEquals("♜ae1", FigurineSan.format("Rae1"))
    }

    @Test fun `un coup de pion passe intact`() {
        assertEquals("e4", FigurineSan.format("e4"))
        assertEquals("exd5", FigurineSan.format("exd5"))
    }

    @Test fun `le b minuscule est la colonne b, pas le fou`() {
        assertEquals("bxc3", FigurineSan.format("bxc3"))
        assertEquals("♝b5", FigurineSan.format("Bb5"))
    }

    @Test fun `le roque n'a pas de figurine`() {
        assertEquals("O-O", FigurineSan.format("O-O"))
        assertEquals("O-O-O+", FigurineSan.format("O-O-O+"))
    }

    @Test fun `la promotion prend la figurine de la pièce promue`() {
        assertEquals("e8=♛", FigurineSan.format("e8=Q"))
        assertEquals("exd8=♞#", FigurineSan.format("exd8=N#"))
    }

    @Test fun `une chaîne vide reste vide`() {
        assertEquals("", FigurineSan.format(""))
    }
}
