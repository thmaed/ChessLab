package com.chesslab.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le réglage « Temps de réflexion du moteur » existe, et il DOIT servir.
 *
 * Il était enregistré dans DataStore et jamais relu : ses quatre choix —
 * rapide, normal, posé, long — ne changeaient rien, et le moteur prenait
 * 900 ms quoi qu'on choisisse. Quatre boutons décoratifs.
 *
 * Ce test ne peut pas démarrer un moteur ; il tient la seule chose vérifiable
 * hors appareil : que les valeurs proposées par l'écran sont celles que le
 * modèle sait porter, et que la valeur d'usine n'a pas dérivé.
 */
class EngineMoveTimeTest {

    /** Les quatre choix de l'écran de réglages. */
    private val proposes = listOf(200, 400, 1000, 3000)

    @Test fun `la valeur d'usine est l'un des choix proposés`() {
        assertTrue(AppSettings().engineMoveTimeMs in proposes)
    }

    @Test fun `la valeur d'usine reste 400 ms`() {
        // Changer ce chiffre change le rythme de TOUTES les parties sans
        // pendule : qu'il faille le vouloir explicitement.
        assertEquals(400, AppSettings().engineMoveTimeMs)
    }

    @Test fun `les choix vont du plus rapide au plus long, sans doublon`() {
        assertEquals(proposes.sorted(), proposes)
        assertEquals(proposes.size, proposes.toSet().size)
    }
}
