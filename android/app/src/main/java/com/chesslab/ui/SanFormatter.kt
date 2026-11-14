package com.chesslab.ui

import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.chesslab.settings.PieceNotation

/**
 * La notation d'un coup, dans la langue de l'utilisateur. Pendant de
 * `SANFormatter.swift`.
 *
 * « Nf3 » en anglais, « Cf3 » en français. Transformation d'AFFICHAGE et rien
 * d'autre : jamais sur un SAN stocké, comparé ou exporté — le standard PGN est
 * en lettres anglaises, et un PGN français ne serait lu par personne.
 *
 * À ne pas confondre avec [FigurineSan], qui remplace la lettre par le dessin
 * de la pièce. Les deux coexistent chez iOS et pour la même raison ici : le
 * lecteur d'ouvertures montre des figurines — c'est la notation des livres —,
 * tout le reste suit le réglage de l'utilisateur.
 */
object SanFormatter {

    /**
     * Lettres de pièce, MAJUSCULES uniquement : les minuscules sont des
     * colonnes (a–h), et un « b » de colonne n'a rien à voir avec le fou.
     */
    private val french = mapOf(
        'K' to 'R',  // King → Roi
        'Q' to 'D',  // Queen → Dame
        'R' to 'T',  // Rook → Tour
        'B' to 'F',  // Bishop → Fou
        'N' to 'C',  // Knight → Cavalier
    )

    /** Espagnol : Rey, Dama, Torre, Alfil, Caballo. */
    private val spanish = mapOf('K' to 'R', 'Q' to 'D', 'R' to 'T', 'B' to 'A', 'N' to 'C')

    /** Italien : Re, Donna, Torre, Alfiere, Cavallo (mêmes lettres que l'espagnol). */
    private val italian = mapOf('K' to 'R', 'Q' to 'D', 'R' to 'T', 'B' to 'A', 'N' to 'C')

    /** Allemand : König, Dame, Turm, Läufer, Springer. */
    private val german = mapOf('K' to 'K', 'Q' to 'D', 'R' to 'T', 'B' to 'L', 'N' to 'S')

    /** La table de la notation, `null` pour l'anglaise (rien à traduire). */
    private fun letters(notation: PieceNotation): Map<Char, Char>? = when (notation) {
        PieceNotation.english -> null
        PieceNotation.french -> french
        PieceNotation.spanish -> spanish
        PieceNotation.german -> german
        PieceNotation.italian -> italian
    }

    /**
     * Conversion CARACTÈRE PAR CARACTÈRE, en une seule passe. Des
     * remplacements successifs seraient faux : « R → T » puis « K → R »
     * retraduirait les T fraîchement écrits, et un roi finirait en tour.
     *
     * `O-O`, `x`, `+`, `#`, les chiffres et les colonnes minuscules ne sont
     * dans aucune table : ils traversent intacts. `=Q` devient `=D` par la
     * même passe, et c'est voulu.
     */
    fun display(san: String, notation: PieceNotation): String {
        val table = letters(notation) ?: return san
        return san.map { table[it] ?: it }.joinToString("")
    }

    fun display(sans: List<String>, notation: PieceNotation): List<String> =
        if (notation == PieceNotation.english) sans else sans.map { display(it, notation) }
}

/**
 * Le SAN tel que l'utilisateur veut le lire — l'usage courant côté écran.
 *
 * Composable, donc les listes de coups se réécrivent d'elles-mêmes quand le
 * réglage change, sans qu'aucun écran n'ait à s'en occuper.
 */
@androidx.compose.runtime.Composable
fun sanText(san: String): String {
    val settings by com.chesslab.settings.SettingsStore.state
        .collectAsState()
    return SanFormatter.display(san, settings.pieceNotation)
}
