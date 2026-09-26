package com.chesslab.play

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le barème de l'alerte, vérifié sur des valeurs écrites à la main.
 *
 * Rappel de la convention, qui est le seul vrai piège : `before` est du point
 * de vue de CELUI QUI JOUE, `after` de celui de l'ADVERSAIRE, puisque le trait
 * a changé.
 */
class BlunderAlertTest {

    @Test fun `un coup qui donne un mat forcé alerte`() {
        assertEquals(
            BlunderSeverity.AllowsMate,
            BlunderAlert.severity(beforeCp = 20, beforeMate = null, afterCp = 10_000, afterMate = 3),
        )
    }

    @Test fun `une position déjà perdue avec mat annoncé n'alerte plus`() {
        // Sans ce garde, l'alerte se redéclencherait à CHAQUE coup dans une
        // position perdue où l'adversaire a déjà son mat.
        assertNull(
            BlunderAlert.severity(beforeCp = -10_000, beforeMate = -4, afterCp = 10_000, afterMate = 3)
        )
    }

    @Test fun `laisser filer son propre mat alerte`() {
        assertEquals(
            BlunderSeverity.MissedMate,
            BlunderAlert.severity(beforeCp = 10_000, beforeMate = 2, afterCp = 30, afterMate = null),
        )
    }

    @Test fun `un mat qui tient encore n'alerte pas`() {
        // On avait le mat, on l'a toujours : l'adversaire est au trait et se
        // fait mater (mate négatif de son point de vue).
        assertNull(
            BlunderAlert.severity(beforeCp = 10_000, beforeMate = 2, afterCp = -10_000, afterMate = -2)
        )
    }

    // Les deux régressions du 26/09 : un MAT n'est pas une position à
    // l'équilibre. Le moteur annonce « score mate N » OU « score cp N », jamais
    // les deux ; ramener le `cp` absent à zéro plaçait la position à 50 % et
    // faisait prévenir sur le MEILLEUR coup. Trouvé à la Horde, où le moteur
    // rend l'extinction de la horde comme un mat, donc bien plus souvent.

    @Test fun `un mat vaut dix mille centipions, pas zéro`() {
        assertEquals(10_000, BlunderAlert.centipawns(cp = null, mate = 3))
        assertEquals(-10_000, BlunderAlert.centipawns(cp = null, mate = -3))
        assertEquals("le cp prime quand il existe", 42, BlunderAlert.centipawns(cp = 42, mate = null))
        assertNull("sans score, rien à convertir", BlunderAlert.centipawns(cp = null, mate = null))
    }

    @Test fun `le coup qui FORCE le mat n'est pas un coup risqué`() {
        // On gagne nettement (+400), notre coup mate en 3 : l'adversaire au
        // trait voit « mate -3 ». C'est le meilleur coup possible.
        val cp = BlunderAlert.centipawns(cp = null, mate = -3)!!
        assertNull(
            "avec un cp ramené à zéro, l'app annonçait « -31 points, 4 pions perdus »",
            BlunderAlert.severity(beforeCp = 400, beforeMate = null, afterCp = cp, afterMate = -3),
        )
        // Et voici ce que faisait l'ancien code, pour que la raison d'être de
        // `centipawns` soit écrite noir sur blanc plutôt que déduite.
        assertTrue(
            "le zéro d'autrefois produisait bien une fausse alerte",
            BlunderAlert.severity(
                beforeCp = 400, beforeMate = null, afterCp = 0, afterMate = -3,
            ) is BlunderSeverity.Centipawns,
        )
    }

    @Test fun `sortir d'un mat subi n'est pas un coup risqué`() {
        // On était maté en 4 ; le coup l'évite, au prix d'une position encore
        // inférieure (+400 pour l'adversaire). La partie était perdue : le
        // plancher des 25 % doit faire taire l'alerte.
        val cp = BlunderAlert.centipawns(cp = null, mate = -4)!!
        assertNull(
            "avec un cp ramené à zéro, on partait de 50 % au lieu de 0 %",
            BlunderAlert.severity(beforeCp = cp, beforeMate = -4, afterCp = 400, afterMate = null),
        )
        assertTrue(
            "le zéro d'autrefois produisait bien une fausse alerte",
            BlunderAlert.severity(
                beforeCp = 0, beforeMate = -4, afterCp = 400, afterMate = null,
            ) is BlunderSeverity.Centipawns,
        )
    }

    @Test fun `une perte franche dans une position vive alerte`() {
        // +0,30 pour nous, puis +3,00 pour l'adversaire : on a lâché une pièce.
        val verdict = BlunderAlert.severity(beforeCp = 30, beforeMate = null, afterCp = 300, afterMate = null)
        assertTrue("attendu une alerte, obtenu $verdict", verdict is BlunderSeverity.Centipawns)
        assertEquals(330, (verdict as BlunderSeverity.Centipawns).drop)
    }

    @Test fun `une petite perte ne dérange personne`() {
        assertNull(BlunderAlert.severity(beforeCp = 30, beforeMate = null, afterCp = 60, afterMate = null))
    }

    @Test fun `une partie déjà largement perdue n'alerte pas`() {
        // Sous 25 % de probabilité de gain avant le coup, un pas de plus vers
        // le fond n'est pas une alerte utile.
        assertNull(BlunderAlert.severity(beforeCp = -400, beforeMate = null, afterCp = 900, afterMate = null))
    }

    @Test fun `une partie encore largement gagnée n'alerte pas`() {
        // Au-dessus de 75 % après le coup, inutile de proposer de reprendre.
        assertNull(BlunderAlert.severity(beforeCp = 900, beforeMate = null, afterCp = -400, afterMate = null))
    }
}
