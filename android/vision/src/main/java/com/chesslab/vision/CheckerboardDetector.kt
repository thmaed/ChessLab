package com.chesslab.vision

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Un cadre en pixels de l'image d'origine. */
data class BoardRect(val x: Double, val y: Double, val width: Double, val height: Double) {
    val right: Double get() = x + width
    val bottom: Double get() = y + height
}

/**
 * Détecte automatiquement un plateau **aligné sur les axes** — une capture
 * d'écran ou une photo bien cadrée — en cherchant son motif de damier 8×8.
 *
 * Porté de `CheckerboardDetector.swift`, sans une ligne de dépendance à
 * Android : l'entrée est une image en niveaux de gris déjà mise au carré
 * d'analyse, si bien que le détecteur se teste sur la JVM en quelques
 * millisecondes.
 *
 * Pourquoi un détecteur dédié plutôt qu'une détection de rectangles : sur un
 * diagramme, le plateau remplit souvent l'image (aucun bord franc), les pièces
 * cassent les arêtes, et un cadre trop grand de quelques pour cent suffit à
 * ruiner la reconnaissance. Un damier, lui, a une signature imparable : huit
 * bandes claires et sombres alternées, dans les deux directions.
 *
 * Le cas dimensionnant est la VRAIE capture de téléphone : image portrait,
 * plateau pleine largeur qui TOUCHE les bords et n'occupe qu'une BANDE de la
 * hauteur, interface chargée au-dessus et en dessous. D'où trois choix :
 * - les deux axes se cherchent d'abord séparément, puis l'axe trouvé sert
 *   d'ANCRE à l'autre — le plateau est carré EN PIXELS — avec un profil
 *   restreint à sa bande, car hors de la bande l'interface noie le signal ;
 * - une ligne de grille coupée par le bord de l'image est EXCUSÉE : elle n'a
 *   aucun gradient à offrir ;
 * - toutes les longueurs se comparent en pixels d'origine, jamais en unités
 *   du carré d'analyse — une image portrait étire ses deux axes différemment.
 *
 * Le résultat n'est JAMAIS une vérité : il pré-positionne les quatre poignées
 * du cadrage manuel, qui reste le filet de sécurité.
 */
object CheckerboardDetector {

    data class Result(
        /** Le cadre du plateau, en pixels de l'image d'origine. */
        val rect: BoardRect,
        /** Qualité du damier trouvé, 0…1. */
        val score: Double,
    )

    /**
     * Côté de l'image d'analyse. 384 px : assez fin pour situer le plateau
     * précisément, assez petit pour que le balayage reste instantané.
     */
    const val ANALYSIS_SIDE = 384

    /**
     * @param gray l'image en niveaux de gris (0…1), de [ANALYSIS_SIDE]² valeurs,
     *   ligne par ligne.
     * @param imageWidth, [imageHeight] les dimensions de l'image D'ORIGINE :
     *   c'est en pixels d'origine que le plateau est carré.
     */
    fun detect(
        gray: DoubleArray,
        imageWidth: Int,
        imageHeight: Int,
        side: Int = ANALYSIS_SIDE,
        minimumScore: Double = 0.55,
    ): Result? {
        require(gray.size == side * side) { "l'image d'analyse doit être carrée" }
        val scaleX = imageWidth.toDouble() / side
        val scaleY = imageHeight.toDouble() / side

        // Passe 1 : chaque axe pour lui-même, profil sur toute l'image. Suffit
        // quand le plateau domine (diagramme recadré serré).
        val vertical = axisProfile(gray, side, alongColumns = true, from = 0, until = side)
        val horizontal = axisProfile(gray, side, alongColumns = false, from = 0, until = side)
        var xs = bestBoardSpan(vertical)?.takeIf { it.score >= minimumScore }
        var ys = bestBoardSpan(horizontal)?.takeIf { it.score >= minimumScore }

        // Passe 2 : la capture de téléphone. Le plateau pleine largeur n'occupe
        // qu'une BANDE de la hauteur : le profil vertical le voit — chaque
        // ligne du damier traverse toute l'image — mais le profil horizontal
        // est mort, car sur une colonne la MÉDIANE des gradients tombe dans
        // l'interface. On refait alors l'axe manquant sur la bande de l'autre,
        // avec sa cellule imposée.
        if (xs == null && ys != null) {
            xs = crossSpan(gray, side, ys, scaleY, scaleX, alongColumns = true, minimumScore = minimumScore)
        }
        if (ys == null && xs != null) {
            ys = crossSpan(gray, side, xs, scaleX, scaleY, alongColumns = false, minimumScore = minimumScore)
        }
        var x = xs ?: return null
        var y = ys ?: return null

        // Réconciliation EN PIXELS : si les deux longueurs divergent, l'axe le
        // moins sûr s'est trompé (typiquement sur un sous-motif) ; on le refait
        // ancré sur l'autre.
        var widthPx = x.length * scaleX
        var heightPx = y.length * scaleY
        if (abs(widthPx - heightPx) > 0.08 * max(widthPx, heightPx)) {
            if (x.score >= y.score) {
                y = crossSpan(gray, side, x, scaleX, scaleY, alongColumns = false, minimumScore = minimumScore)
                    ?: return null
            } else {
                x = crossSpan(gray, side, y, scaleY, scaleX, alongColumns = true, minimumScore = minimumScore)
                    ?: return null
            }
            widthPx = x.length * scaleX
            heightPx = y.length * scaleY
            if (abs(widthPx - heightPx) > 0.08 * max(widthPx, heightPx)) return null
        }

        // Recalage sur l'ALTERNANCE des couleurs. Le score de grille ne sait
        // pas distinguer le vrai plateau d'un cadre décalé d'une case : le
        // décalé réutilise 8 des 9 lignes, et une crête accidentelle dans
        // l'interface lui suffit pour la neuvième. L'alternance clair/sombre,
        // elle, s'effondre dès qu'une rangée tombe hors du plateau.
        val cellWidth = x.length / 8
        val cellHeight = y.length / 8
        // Le point de départ est la détection elle-même : on ne bouge QUE sur
        // une preuve nette, sinon deux candidats à égalité laisseraient le
        // premier de la boucle l'emporter — un décalage inventé.
        var bestAlternation = alternation(gray, side, x.start, y.start, cellWidth, cellHeight)
        var shiftX = 0.0
        var shiftY = 0.0
        for (dx in -1..1) for (dy in -1..1) {
            if (dx == 0 && dy == 0) continue
            val value = alternation(
                gray, side,
                x.start + dx * cellWidth, y.start + dy * cellHeight,
                cellWidth, cellHeight,
            )
            // Moitié plus net, pas seulement « un peu mieux » : c'est ce qui
            // distingue un vrai recalage d'un écart de mesure.
            if (value > bestAlternation * 1.5) {
                bestAlternation = value
                shiftX = dx.toDouble(); shiftY = dy.toDouble()
            }
        }
        val startX = x.start + shiftX * cellWidth
        val startY = y.start + shiftY * cellHeight

        val sidePx = min(widthPx, heightPx)
        var rect = BoardRect(
            x = startX * scaleX + (widthPx - sidePx) / 2,
            y = startY * scaleY + (heightPx - sidePx) / 2,
            width = sidePx, height = sidePx,
        )

        // Une marge de sécurité : la détection donne le plateau au pixel PRÈS,
        // et « près » ne suffit pas — un cadrage 1 % trop court décale
        // cumulativement les cases. On élargit d'un chouïa pour l'ENGLOBER,
        // borné à l'image.
        val margin = rect.width * 0.02
        rect = BoardRect(
            x = max(0.0, rect.x - margin),
            y = max(0.0, rect.y - margin),
            width = min(imageWidth.toDouble(), rect.right + margin) - max(0.0, rect.x - margin),
            height = min(imageHeight.toDouble(), rect.bottom + margin) - max(0.0, rect.y - margin),
        )

        val score = min(x.score, y.score)
        return if (score >= minimumScore) Result(rect, score) else null
    }

    // MARK: Alternance du damier

    /**
     * Force de l'alternance clair/sombre d'un damier candidat, jugée par sa
     * rangée (ou colonne) la PLUS FAIBLE.
     *
     * Même philosophie de maillon faible que [spanScore], mais sur la COULEUR :
     * une rangée qui déborde sur l'interface n'alterne pas et effondre le
     * minimum. Un plateau décalé d'une case garde pourtant sept rangées
     * valides sur huit — d'où le minimum plutôt qu'une moyenne, qui les
     * absorberait.
     */
    private fun alternation(
        gray: DoubleArray, side: Int,
        x: Double, y: Double, cellWidth: Double, cellHeight: Double,
    ): Double {
        val luminance = Array(8) { DoubleArray(8) }
        for (row in 0 until 8) for (column in 0 until 8) {
            val value = cellLuminance(
                gray, side,
                x + (column + 0.5) * cellWidth, y + (row + 0.5) * cellHeight,
                cellWidth, cellHeight,
            ) ?: return 0.0
            luminance[row][column] = value
        }
        var worst = Double.MAX_VALUE
        for (i in 0 until 8) {
            worst = min(worst, alternationOfLine(luminance[i]))
            worst = min(worst, alternationOfLine(DoubleArray(8) { luminance[it][i] }))
        }
        return worst
    }

    /**
     * Écart de luminance entre cases paires et impaires d'une ligne. Médiane et
     * non moyenne : une case porte parfois une pièce, qui change sa luminance
     * sans rien dire du damier.
     */
    private fun alternationOfLine(values: DoubleArray): Double {
        val even = ArrayList<Double>(4)
        val odd = ArrayList<Double>(4)
        values.forEachIndexed { i, v -> if (i % 2 == 0) even += v else odd += v }
        return abs(median(even) - median(odd))
    }

    /**
     * Luminance médiane du CENTRE d'une case (36 % du côté) — assez petit pour
     * ignorer les bordures, assez grand pour rester stable. `null` si la case
     * sort de l'image d'analyse.
     */
    private fun cellLuminance(
        gray: DoubleArray, side: Int,
        x: Double, y: Double, cellWidth: Double, cellHeight: Double,
    ): Double? {
        if (x < 0 || y < 0 || x >= side || y >= side) return null
        val halfWidth = cellWidth * 0.18
        val halfHeight = cellHeight * 0.18
        var row = max(0, kotlin.math.floor(y - halfHeight).toInt())
        val rowLimit = min(side - 1, kotlin.math.ceil(y + halfHeight).toInt())
        val columnStart = max(0, kotlin.math.floor(x - halfWidth).toInt())
        val columnLimit = min(side - 1, kotlin.math.ceil(x + halfWidth).toInt())
        if (row > rowLimit || columnStart > columnLimit) return null

        val values = ArrayList<Double>((rowLimit - row + 1) * (columnLimit - columnStart + 1))
        while (row <= rowLimit) {
            for (column in columnStart..columnLimit) values += gray[row * side + column]
            row++
        }
        return if (values.isEmpty()) null else median(values)
    }

    // MARK: Profil de transitions

    /**
     * Force des transitions le long d'un axe : médiane des |gradients| par
     * colonne (ou ligne), sur les seuls indices de la bande. Les neuf lignes du
     * damier traversent toute la bande et dominent ce profil ; le bord d'une
     * pièce, non — d'où la médiane, qui ignore les contributions locales.
     */
    private fun axisProfile(
        gray: DoubleArray, side: Int, alongColumns: Boolean, from: Int, until: Int,
    ): DoubleArray {
        val profile = DoubleArray(side)
        val line = ArrayList<Double>(until - from)
        for (index in 1 until side - 1) {
            line.clear()
            for (other in from until until) {
                val before = if (alongColumns) gray[other * side + index - 1] else gray[(index - 1) * side + other]
                val after = if (alongColumns) gray[other * side + index + 1] else gray[(index + 1) * side + other]
                line += abs(after - before)
            }
            profile[index] = median(line)
        }
        return profile
    }

    // MARK: Recherche du plateau sur un axe

    private data class Span(var start: Double, val length: Double, val score: Double)

    /**
     * Cherche l'étendue qui aligne **neuf lignes équidistantes** sur les crêtes
     * du profil : la signature d'un damier de huit cases. Balayage exhaustif
     * (cellule × début) — une grille complète de neuf lignes ne s'aligne pas
     * par hasard, là où un seul pic pourrait tromper.
     */
    private fun bestBoardSpan(profile: DoubleArray): Span? {
        val n = profile.size.toDouble()
        val mean = profile.average()
        if (mean <= 0) return null

        // Le plateau qu'on scanne remplit son axe : son côté vaut au moins 36 %
        // du profil. Ce plancher écarte les faux positifs à petite échelle —
        // sur un damier VIDE, une sous-région de mini-cases s'aligne aussi bien
        // que le vrai plateau, et sans lui le détecteur retenait un coin.
        var best: Span? = null
        var cell = n / 22
        while (cell <= n / 8) {
            val span = bestStart(profile, cell, mean)
            if (span != null && (best == null || span.score > best!!.score)) best = span
            cell += 0.5
        }
        return best
    }

    /**
     * Recherche de l'axe MANQUANT, ancrée sur l'axe trouvé : profil restreint à
     * la bande de l'ancre, cellule imposée par elle (à ±2 %, l'ancre porte une
     * petite erreur) ; seule la PHASE reste à trouver.
     */
    private fun crossSpan(
        gray: DoubleArray, side: Int, anchor: Span,
        anchorScale: Double, otherScale: Double,
        alongColumns: Boolean, minimumScore: Double,
    ): Span? {
        val lower = max(0, anchor.start.roundToInt())
        val upper = min(side, (anchor.start + anchor.length).roundToInt())
        if (upper - lower <= 8) return null

        val profile = axisProfile(gray, side, alongColumns, lower, upper)
        val mean = profile.average()
        if (mean <= 0) return null

        // La cellule de l'ancre, convertie via les pixels d'origine — les deux
        // axes du carré d'analyse n'ont pas la même échelle.
        val baseCell = anchor.length * anchorScale / 8 / otherScale
        var best: Span? = null
        for (factor in doubleArrayOf(0.98, 0.99, 1.0, 1.01, 1.02)) {
            val span = bestStart(profile, baseCell * factor, mean)
            if (span != null && (best == null || span.score > best!!.score)) best = span
        }
        return best?.takeIf { it.score >= minimumScore }
    }

    /** Meilleure phase pour une cellule donnée. */
    private fun bestStart(profile: DoubleArray, cell: Double, mean: Double): Span? {
        val n = profile.size.toDouble()
        val boardLength = cell * 8
        val maxStart = n - boardLength
        // Un léger débordement est toléré : la dernière ligne, coupée par le
        // bord, sera excusée par [spanScore].
        if (maxStart < -1) return null

        // Fenêtre de tolérance autour de chaque ligne : la période n'est jamais
        // pile un entier de pixels, et un flottement cumulé sur huit cases
        // ferait rater une crête étroite.
        val onRadius = max(n / 200, 2.0)
        var best: Span? = null
        var start = 0.0
        val limit = max(maxStart, 0.0)
        while (start <= limit) {
            val score = spanScore(profile, start, cell, onRadius, mean)
            if (best == null || score > best!!.score) best = Span(start, boardLength, score)
            start += 1
        }
        return best
    }

    /** Score d'un damier candidat (début, cellule) sur un profil. */
    private fun spanScore(
        profile: DoubleArray, start: Double, cell: Double, onRadius: Double, mean: Double,
    ): Double {
        val n = profile.size.toDouble()

        // Les neuf lignes doivent TOUTES tomber sur une crête, et l'on juge par
        // la PLUS FAIBLE : une demi-période (cellule deux fois trop petite)
        // aligne ses lignes une sur deux sur les vraies crêtes et garde une
        // moyenne haute — mais son minimum s'effondre. Le minimum distingue le
        // vrai plateau d'un sous-motif, et il est insensible aux pièces, qui ne
        // créent pas neuf crêtes équidistantes pleine hauteur.
        //
        // EXCEPTION : une ligne au bord de l'image est excusée — un plateau
        // pleine largeur y est COUPÉ, il n'a aucun gradient à offrir. Au plus
        // les deux lignes extrêmes sont concernées : il en reste toujours sept.
        var onMin = Double.MAX_VALUE
        var counted = 0
        for (k in 0..8) {
            val position = start + k * cell
            if (position < onRadius + 1 || position > n - 2 - onRadius) continue
            onMin = min(onMin, sampleMax(profile, position, onRadius))
            counted++
        }
        if (counted < 7) return 0.0

        // Le centre des cases doit être CREUX : un vrai damier a ses
        // transitions AUX bordures. On échantillonne les centres avec la MÊME
        // fenêtre que les lignes, sinon le biais du maximum rendrait un bruit
        // sans structure « contrasté ». Médiane des huit et non moyenne :
        // quelques centres portent une pièce et sont, eux, chargés.
        val offSamples = ArrayList<Double>(8)
        for (k in 0 until 8) offSamples += sampleMax(profile, start + (k + 0.5) * cell, onRadius)
        val off = median(offSamples)

        val contrast = (onMin - off) / (onMin + off + 1e-6)
        val strength = min(onMin / (mean * 2), 1.0)
        // Chaque ligne excusée COÛTE : sinon un cadre décalé d'une case dont la
        // neuvième ligne « sort » de l'image bat le vrai plateau — son minimum,
        // pris sur un SOUS-ENSEMBLE des vraies lignes, lui est mécaniquement
        // supérieur ou égal.
        return max(0.0, contrast) * strength * (counted / 9.0)
    }

    /**
     * Plus forte valeur du profil dans une fenêtre ±rayon : « une crête
     * passe-t-elle près d'ici ? », insensible à un léger décalage de période.
     */
    private fun sampleMax(profile: DoubleArray, position: Double, radius: Double): Double {
        var index = max(0, kotlin.math.floor(position - radius).toInt())
        val limit = min(profile.size - 1, kotlin.math.ceil(position + radius).toInt())
        var peak = 0.0
        while (index <= limit) {
            peak = max(peak, profile[index])
            index++
        }
        return peak
    }

    /** Médiane — celle de `Sample.median`, moyenne des deux centrales si pair. */
    private fun median(values: List<Double>): Double {
        if (values.isEmpty()) return 0.0
        val sorted = values.sorted()
        val mid = sorted.size / 2
        return if (sorted.size % 2 == 1) sorted[mid] else (sorted[mid - 1] + sorted[mid]) / 2
    }

    private fun median(values: DoubleArray): Double = median(values.toList())
}
