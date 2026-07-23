import CoreGraphics
import Foundation

/// Détecte automatiquement un plateau d'échecs **aligné sur les axes** (une
/// capture ou une photo d'écran bien cadrée) en cherchant son motif de damier
/// 8×8, sans passer par Vision.
///
/// Pourquoi : la détection de rectangles de Vision est peu fiable sur un
/// diagramme — le plateau remplit souvent l'image (aucun bord franc), les
/// pièces cassent les arêtes, et un cadre trop grand de quelques pour cent
/// suffit à ruiner la reconnaissance. Un damier, lui, a une signature
/// imparable : huit bandes claires/sombres alternées, dans les deux
/// directions. On la cherche directement.
///
/// Le cas dimensionnant est la VRAIE capture de téléphone (vérifié sur une
/// capture chess.com) : image portrait, plateau pleine largeur qui TOUCHE les
/// bords, et qui n'occupe qu'une BANDE de la hauteur, interface chargée
/// au-dessus et en dessous. D'où trois choix :
/// - les deux axes se cherchent d'abord indépendamment, puis l'axe trouvé
///   sert d'ANCRE à l'autre (le plateau est carré **en pixels**) avec un
///   profil restreint à sa bande — hors de la bande, l'interface noie le
///   signal ;
/// - une ligne de grille coupée par le bord de l'image est EXCUSÉE (elle n'a
///   aucun gradient à offrir) ;
/// - toutes les longueurs se comparent en pixels d'origine, jamais en unités
///   du carré d'analyse (une image portrait étire différemment ses deux axes).
///
/// Renvoie un carré aligné (pas un quadrilatère en perspective) : pour un
/// écran, c'est le cas normal. Les vraies photos en perspective (plateau réel
/// incliné) restent du ressort de Vision + ajustement manuel.
///
/// Pur et testable.
enum CheckerboardDetector {

    struct Result {
        /// Cadre du plateau, en pixels de l'image d'origine.
        var rect: CGRect
        /// Qualité du damier trouvé, 0...1 — sert à décider si on fait
        /// confiance à la détection ou si on demande un cadrage manuel.
        var score: Double
    }

    /// Côté de l'image d'analyse. 384 px : assez fin pour situer le plateau
    /// précisément, tout en gardant le balayage quasi instantané.
    private static let analysisSide = 384

    /// - returns: le meilleur damier trouvé, ou `nil` si le score reste trop
    ///   faible (image sans plateau clair).
    static func detect(in image: CGImage, minimumScore: Double = 0.55) -> Result? {
        let side = analysisSide
        guard let gray = ImagePatch.grayscale(of: image, side: side) else { return nil }

        let scaleX = Double(image.width) / Double(side)
        let scaleY = Double(image.height) / Double(side)

        // Passe 1 : chaque axe pour lui-même, profil sur toute l'image.
        // Suffit quand le plateau domine l'image (diagramme recadré serré).
        let vertical = axisProfile(gray, side: side, alongColumns: true, band: 0..<side)
        let horizontal = axisProfile(gray, side: side, alongColumns: false, band: 0..<side)
        var xSpan = bestBoardSpan(vertical).flatMap { $0.score >= minimumScore ? $0 : nil }
        var ySpan = bestBoardSpan(horizontal).flatMap { $0.score >= minimumScore ? $0 : nil }

        // Passe 2 : le cas de la capture de téléphone. Le plateau pleine
        // largeur n'occupe qu'une BANDE de la hauteur : le profil vertical le
        // voit (chaque ligne horizontale du damier traverse toute l'image),
        // mais le profil horizontal est mort — sur une colonne, la MÉDIANE des
        // gradients tombe dans l'interface, pas dans le plateau. On refait
        // alors l'axe manquant avec un profil restreint à la bande de l'axe
        // trouvé, et une cellule IMPOSÉE par lui (le plateau est carré).
        if xSpan == nil, let anchor = ySpan {
            xSpan = crossSpan(
                gray, side: side, anchor: anchor,
                anchorScale: scaleY, otherScale: scaleX,
                alongColumns: true, minimumScore: minimumScore
            )
        }
        if ySpan == nil, let anchor = xSpan {
            ySpan = crossSpan(
                gray, side: side, anchor: anchor,
                anchorScale: scaleX, otherScale: scaleY,
                alongColumns: false, minimumScore: minimumScore
            )
        }
        guard var xs = xSpan, var ys = ySpan else { return nil }

        // Réconciliation EN PIXELS : le plateau est carré dans l'image
        // d'origine, pas dans le carré d'analyse. Si les deux longueurs
        // divergent, l'axe le moins sûr s'est trompé (typiquement un
        // sous-motif) : on le refait ancré sur l'autre.
        func pixelLengths() -> (Double, Double) { (xs.length * scaleX, ys.length * scaleY) }
        var (widthPx, heightPx) = pixelLengths()
        if abs(widthPx - heightPx) > 0.08 * max(widthPx, heightPx) {
            if xs.score >= ys.score {
                guard let redone = crossSpan(
                    gray, side: side, anchor: xs,
                    anchorScale: scaleX, otherScale: scaleY,
                    alongColumns: false, minimumScore: minimumScore
                ) else { return nil }
                ys = redone
            } else {
                guard let redone = crossSpan(
                    gray, side: side, anchor: ys,
                    anchorScale: scaleY, otherScale: scaleX,
                    alongColumns: true, minimumScore: minimumScore
                ) else { return nil }
                xs = redone
            }
            (widthPx, heightPx) = pixelLengths()
            guard abs(widthPx - heightPx) <= 0.08 * max(widthPx, heightPx) else { return nil }
        }

        // Recalage sur l'ALTERNANCE des couleurs. Le score de grille ne sait
        // pas distinguer le vrai plateau d'un span décalé d'une case : le
        // décalé réutilise 8 des 9 lignes et il lui suffit d'une crête
        // accidentelle dans l'interface (le bord d'une barre d'app) pour la
        // 9e. Les deux scores se tiennent alors à 1 %, et le départage bascule
        // sur du bruit de rééchantillonnage. L'alternance clair/sombre, elle,
        // s'effondre dès qu'une rangée tombe hors du plateau — c'est le
        // discriminant qui manquait.
        let cellWidth = xs.length / 8
        let cellHeight = ys.length / 8
        // Le point de départ est la détection elle-même : on ne bouge QUE sur
        // une preuve nette. Sans ce biais, deux candidats à égalité (par
        // exemple tous à zéro sur un damier de synthèse sans marge lisible)
        // laisseraient le premier de la boucle l'emporter — un décalage
        // inventé de toutes pièces.
        var bestAlternation = alternation(
            gray, side: side, x: xs.start, y: ys.start,
            cellWidth: cellWidth, cellHeight: cellHeight
        )
        var shift = (x: 0.0, y: 0.0)
        for dx in [-1.0, 0, 1] {
            for dy in [-1.0, 0, 1] where dx != 0 || dy != 0 {
                let value = alternation(
                    gray, side: side,
                    x: xs.start + dx * cellWidth, y: ys.start + dy * cellHeight,
                    cellWidth: cellWidth, cellHeight: cellHeight
                )
                // Moitié plus net, pas seulement « un peu mieux » : c'est ce
                // qui distingue un vrai recalage d'un écart de mesure.
                if value > bestAlternation * 1.5 {
                    bestAlternation = value
                    shift = (dx, dy)
                }
            }
        }
        xs.start += shift.x * cellWidth
        ys.start += shift.y * cellHeight

        let sidePx = min(widthPx, heightPx)
        var rect = CGRect(
            x: xs.start * scaleX + (widthPx - sidePx) / 2,
            y: ys.start * scaleY + (heightPx - sidePx) / 2,
            width: sidePx, height: sidePx
        )

        // Marge de sécurité : la détection donne le plateau au pixel PRÈS, mais
        // « près » ne suffit pas — un cadrage 1 % trop court décale
        // cumulativement les cases. On élargit d'un chouïa pour ENGLOBER tout
        // le plateau, à charge pour ``BoardGridFinder`` de recaler la grille
        // au pixel exact ensuite (il est fait pour ça). Borné à l'image.
        let margin = rect.width * 0.02
        rect = rect.insetBy(dx: -margin, dy: -margin)
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            .integral

        let score = min(xs.score, ys.score)
        guard score >= minimumScore else { return nil }
        return Result(rect: rect, score: score)
    }

    // MARK: Alternance du damier

    /// Force de l'alternance clair/sombre d'un damier candidat, jugée par sa
    /// rangée (ou colonne) la PLUS FAIBLE.
    ///
    /// Même philosophie de maillon faible que ``spanScore``, mais sur la
    /// COULEUR et non sur les gradients : une rangée qui déborde sur
    /// l'interface n'alterne pas, et effondre le minimum. Un plateau décalé
    /// d'une case garde pourtant 7 rangées valides sur 8, d'où le minimum
    /// plutôt qu'une moyenne, qui les absorberait.
    private static func alternation(
        _ gray: [Double], side: Int,
        x: Double, y: Double, cellWidth: Double, cellHeight: Double
    ) -> Double {
        var luminance = [[Double]](repeating: [Double](repeating: 0, count: 8), count: 8)
        for row in 0..<8 {
            for column in 0..<8 {
                guard let value = cellLuminance(
                    gray, side: side,
                    x: x + (Double(column) + 0.5) * cellWidth,
                    y: y + (Double(row) + 0.5) * cellHeight,
                    cellWidth: cellWidth, cellHeight: cellHeight
                ) else { return 0 }
                luminance[row][column] = value
            }
        }

        var worst = Double.greatestFiniteMagnitude
        for index in 0..<8 {
            worst = min(worst, alternationOfLine(luminance[index]))
            worst = min(worst, alternationOfLine((0..<8).map { luminance[$0][index] }))
        }
        return worst
    }

    /// Écart de luminance entre cases paires et impaires d'une ligne. Médiane
    /// et non moyenne : une case porte parfois une pièce, qui change sa
    /// luminance sans rien dire du damier.
    private static func alternationOfLine(_ values: [Double]) -> Double {
        var even = [Double](), odd = [Double]()
        for (index, value) in values.enumerated() {
            if index.isMultiple(of: 2) { even.append(value) } else { odd.append(value) }
        }
        return abs(Sample.median(even) - Sample.median(odd))
    }

    /// Luminance médiane du CENTRE d'une case (36 % du côté) — assez petit
    /// pour ignorer les bordures, assez grand pour rester stable.
    /// `nil` si la case sort de l'image d'analyse.
    private static func cellLuminance(
        _ gray: [Double], side: Int,
        x: Double, y: Double, cellWidth: Double, cellHeight: Double
    ) -> Double? {
        guard x >= 0, y >= 0, x < Double(side), y < Double(side) else { return nil }
        let halfWidth = cellWidth * 0.18
        let halfHeight = cellHeight * 0.18

        var values = [Double]()
        var row = max(0, Int((y - halfHeight).rounded(.down)))
        let rowLimit = min(side - 1, Int((y + halfHeight).rounded(.up)))
        let columnStart = max(0, Int((x - halfWidth).rounded(.down)))
        let columnLimit = min(side - 1, Int((x + halfWidth).rounded(.up)))
        guard row <= rowLimit, columnStart <= columnLimit else { return nil }

        while row <= rowLimit {
            for column in columnStart...columnLimit {
                values.append(gray[row * side + column])
            }
            row += 1
        }
        return values.isEmpty ? nil : Sample.median(values)
    }

    // MARK: Profil de transitions

    /// Force des transitions le long d'un axe : médiane des |gradients| par
    /// colonne (ou ligne), calculée sur les seuls indices de `band`. Les 9
    /// lignes du damier traversent toute la bande et dominent ce profil ; le
    /// bord d'une pièce, non — d'où la médiane, qui ignore les contributions
    /// locales (même principe que `BoardGridFinder`).
    private static func axisProfile(
        _ gray: [Double], side: Int, alongColumns: Bool, band: Range<Int>
    ) -> [Double] {
        var profile = [Double](repeating: 0, count: side)
        var line = [Double](repeating: 0, count: band.count)
        for index in 1..<(side - 1) {
            var position = 0
            for other in band {
                let before = alongColumns ? gray[other * side + index - 1] : gray[(index - 1) * side + other]
                let after = alongColumns ? gray[other * side + index + 1] : gray[(index + 1) * side + other]
                line[position] = abs(after - before)
                position += 1
            }
            profile[index] = Sample.median(line)
        }
        return profile
    }

    // MARK: Recherche du plateau sur un axe

    private struct Span {
        var start: Double
        var length: Double
        var score: Double
    }

    /// Cherche l'étendue (début, longueur) qui aligne **9 lignes équidistantes**
    /// sur les crêtes du profil : c'est la signature d'un damier de 8 cases.
    ///
    /// Balayage exhaustif (cellule × début) : une grille complète de 9 lignes
    /// ne s'aligne pas par hasard, là où un seul pic pourrait tromper.
    private static func bestBoardSpan(_ profile: [Double]) -> Span? {
        let n = Double(profile.count)
        let mean = ImagePatch.mean(profile)
        guard mean > 0 else { return nil }

        // Le plateau qu'on scanne remplit son axe : on borne son côté à ≥ 36 %
        // du profil (8 cases). Ce plancher écarte les faux positifs à petite
        // échelle — sur un damier VIDE, une sous-région de mini-cases s'aligne
        // aussi bien que le vrai plateau, et sans lui le détecteur retenait un
        // coin.
        var best: Span?
        var cell = n / 22
        while cell <= n / 8 {
            if let span = bestStart(profile, cell: cell, mean: mean),
               best == nil || span.score > best!.score {
                best = span
            }
            cell += 0.5
        }
        return best
    }

    /// Recherche de l'axe MANQUANT, ancrée sur l'axe trouvé : profil restreint
    /// à la bande de l'ancre, cellule imposée par elle (à ±2 %, l'ancre porte
    /// une petite erreur), seule la PHASE reste à trouver.
    private static func crossSpan(
        _ gray: [Double], side: Int, anchor: Span,
        anchorScale: Double, otherScale: Double,
        alongColumns: Bool, minimumScore: Double
    ) -> Span? {
        let lower = max(0, Int(anchor.start.rounded()))
        let upper = min(side, Int((anchor.start + anchor.length).rounded()))
        guard upper - lower > 8 else { return nil }

        let profile = axisProfile(gray, side: side, alongColumns: alongColumns, band: lower..<upper)
        let mean = ImagePatch.mean(profile)
        guard mean > 0 else { return nil }

        // La cellule de l'ancre, convertie via les pixels d'origine — les deux
        // axes du carré d'analyse n'ont pas la même échelle.
        let baseCell = anchor.length * anchorScale / 8 / otherScale

        var best: Span?
        for factor in [0.98, 0.99, 1.0, 1.01, 1.02] {
            if let span = bestStart(profile, cell: baseCell * factor, mean: mean),
               best == nil || span.score > best!.score {
                best = span
            }
        }
        guard let best, best.score >= minimumScore else { return nil }
        return best
    }

    /// Meilleure phase pour une cellule donnée.
    private static func bestStart(_ profile: [Double], cell: Double, mean: Double) -> Span? {
        let n = Double(profile.count)
        let boardLength = cell * 8
        let maxStart = n - boardLength
        // Un léger débordement est toléré : la dernière ligne, coupée par le
        // bord, sera excusée par `spanScore`.
        guard maxStart >= -1 else { return nil }

        // Fenêtre de tolérance autour de chaque ligne : la période n'est
        // jamais pile un entier de pixels, et un flottement cumulé sur 8 cases
        // ferait rater une crête étroite. Le MAX du profil dans ±`onRadius` px
        // demande « y a-t-il une ligne près d'ici ? » — assez large pour
        // absorber la dérive, trop étroit pour qu'un creux capte une crête.
        let onRadius = max(n / 200, 2)

        var best: Span?
        var start = 0.0
        let limit = max(maxStart, 0)
        while start <= limit {
            let score = spanScore(profile, start: start, cell: cell, onRadius: onRadius, mean: mean)
            if best == nil || score > best!.score {
                best = Span(start: start, length: boardLength, score: score)
            }
            start += 1
        }
        return best
    }

    /// Score d'un damier candidat (début, cellule) sur un profil.
    private static func spanScore(
        _ profile: [Double], start: Double, cell: Double, onRadius: Double, mean: Double
    ) -> Double {
        let n = Double(profile.count)

        // Les 9 lignes du damier doivent TOUTES tomber sur une crête. On juge
        // par la PLUS FAIBLE des 9, pas par leur moyenne : une demi-période
        // (cellule deux fois trop petite) aligne ses lignes une sur deux sur
        // les vraies crêtes et sa moyenne reste haute — mais son minimum
        // s'effondre. Le minimum distingue le vrai plateau d'un sous-motif, et
        // il est insensible aux pièces (elles ne créent pas 9 crêtes
        // équidistantes pleine hauteur).
        //
        // EXCEPTION : une ligne au bord de l'image est excusée — un plateau
        // pleine largeur y est COUPÉ, il n'y a aucun gradient à mesurer au
        // bord. Au plus les deux lignes extrêmes sont concernées : il reste
        // toujours ≥ 7 lignes exigées.
        var onMin = Double.greatestFiniteMagnitude
        var counted = 0
        for k in 0...8 {
            let position = start + Double(k) * cell
            if position < onRadius + 1 || position > n - 2 - onRadius { continue }
            onMin = min(onMin, sampleMax(profile, at: position, radius: onRadius))
            counted += 1
        }
        guard counted >= 7 else { return 0 }

        // Le centre des cases doit être CREUX (aplat de couleur) : un vrai
        // damier a ses transitions AUX bordures. On échantillonne les centres
        // avec la MÊME fenêtre que les lignes, sinon le biais du max rendrait
        // un bruit sans structure « contrasté ». Médiane des 8 et non
        // moyenne : quelques centres portent une pièce et sont, eux, chargés ;
        // la médiane les ignore.
        var offSamples = [Double]()
        offSamples.reserveCapacity(8)
        for k in 0..<8 {
            offSamples.append(sampleMax(profile, at: start + (Double(k) + 0.5) * cell, radius: onRadius))
        }
        let off = Sample.median(offSamples)

        let contrast = (onMin - off) / (onMin + off + 1e-6)
        let strength = min(onMin / (mean * 2), 1)
        // Chaque ligne excusée COÛTE : sinon, un span décalé d'une case dont
        // la 9e ligne « sort » de l'image bat le vrai plateau — son minimum,
        // pris sur un SOUS-ENSEMBLE des vraies lignes, est mécaniquement
        // supérieur ou égal. Un vrai plateau pleine largeur (2 lignes coupées)
        // garde 7/9 ≈ 0.78, bien au-dessus du seuil.
        return max(0, contrast) * strength * (Double(counted) / 9)
    }

    /// Plus forte valeur du profil dans une fenêtre `±radius` autour de la
    /// position : « une crête passe-t-elle près d'ici ? », insensible à un
    /// léger décalage de la période.
    private static func sampleMax(_ profile: [Double], at position: Double, radius: Double) -> Double {
        let lower = Int((position - radius).rounded(.down))
        let upper = Int((position + radius).rounded(.up))
        var peak = 0.0
        var index = max(0, lower)
        let limit = min(profile.count - 1, upper)
        while index <= limit {
            peak = max(peak, profile[index])
            index += 1
        }
        return peak
    }
}
