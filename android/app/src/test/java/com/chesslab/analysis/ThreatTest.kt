package com.chesslab.analysis

import org.junit.Assert.assertEquals as junitAssertEquals
import org.junit.Assert.assertNull as junitAssertNull
import org.junit.Test

/**
 * « Et si je passais mon tour ? » — la position qui révèle la menace adverse.
 */
class ThreatTest {

    @Test fun `passer son tour donne le trait à l'adversaire`() {
        val flipped = fenWithSideToMoveFlipped("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        junitAssertEquals("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1", flipped)
    }

    @Test fun `le droit de prise en passant ne survit pas au passage de main`() {
        // Garder la case en passant après avoir passé la main produirait un
        // coup fantôme : ce droit ne vaut que pour le coup qu'on ne joue pas.
        val flipped = fenWithSideToMoveFlipped(
            "rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3"
        )
        junitAssertEquals("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 3", flipped)
    }

    @Test fun `on ne passe pas son tour quand on est en échec`() {
        // Roi noir en échec : lui laisser le trait donnerait une position où
        // les Blancs pourraient prendre le roi. Elle n'existe pas.
        junitAssertNull(fenWithSideToMoveFlipped("4R1k1/5p2/6p1/7p/8/8/5PPP/6K1 b - - 0 1"))
    }

    @Test fun `un FEN illisible ne produit rien`() {
        junitAssertNull(fenWithSideToMoveFlipped("pas une fen"))
        junitAssertNull(fenWithSideToMoveFlipped("8/8/8/8/8/8/8/8 w"))
    }
}
