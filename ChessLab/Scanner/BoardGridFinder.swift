import CoreGraphics
import Foundation

/// Recalage de la grille 8×8 sur une image de plateau **déjà redressée**.
///
/// Raison d'être (défaut réel, trouvé en jouant le parcours complet) : la
/// détection automatique de Vision rend un quadrilatère **~3 % trop grand**
/// sur une capture pourtant parfaite. Après redressement, le plateau se
/// retrouve donc réduit et décalé d'environ 14 px dans une image de 800 —
/// soit ~0,14 case. Découper en huitièmes exacts fait alors mordre chaque
/// vignette sur sa voisine, et le template matching s'effondre : sur la
/// Sicilienne, il ne restait QUE les pions (petits et centrés, ils gardent du
/// jeu), les 24 autres pièces passaient à la trappe. Aucun cadrage manuel ne
/// sera jamais meilleur, et une vraie photo fera pire.
///
/// La correction : l'image redressée porte elle-même la vérité — les lignes du
/// damier. On retrouve leur **pas** et leur **phase**, et l'on découpe
/// là-dessus plutôt que sur une hypothèse.
///
/// Pur et sans état : testable directement.
enum BoardGridFinder {

    /// Bornes des 9 lignes de la grille, en pixels de l'image redressée.
    struct Grid: Equatable {
        /// 9 abscisses, de la bordure gauche à la droite.
        var columns: [Double]
        /// 9 ordonnées, du haut vers le bas.
        var rows: [Double]

        /// Grille naïve : huit parts égales. Le repli quand le recalage
        /// n'inspire pas confiance.
        static func uniform(width: Int, height: Int) -> Grid {
            Grid(
                columns: (0...8).map { Double($0) * Double(width) / 8 },
                rows: (0...8).map { Double($0) * Double(height) / 8 }
            )
        }
    }

    /// Tolérance de recherche autour du pas théorique (`côté / 8`) : au-delà,
    /// ce n'est plus un recalage mais un cadrage à refaire à la main.
    private static let periodTolerance = 0.12
    /// Décalage exploré, en fraction du pas.
    private static let phaseTolerance = 0.30

    /// Recale la grille sur les lignes du damier.
    ///
    /// - returns: la grille recalée, ou la grille uniforme si l'image ne
    ///   présente aucune structure périodique exploitable (plateau hors
    ///   cadre, photo floue) — on ne remplace jamais une hypothèse discutable
    ///   par une hypothèse pire.
    static func grid(in image: CGImage) -> Grid {
        let width = image.width
        let height = image.height
        let side = min(width, height, maximumAnalysisSide)
        guard side >= 64, let luminance = ImagePatch.grayscale(of: image, side: side)
        else { return .uniform(width: width, height: height) }

        let vertical = edgeProfile(luminance, side: side, alongColumns: true)
        let horizontal = edgeProfile(luminance, side: side, alongColumns: false)

        let uniform = Grid.uniform(width: width, height: height)
        let columns = lines(from: vertical, scale: Double(width) / Double(side))
        let rows = lines(from: horizontal, scale: Double(height) / Double(side))

        // Bornage : une grille qui déborde ferait rogner la découpe en
        // silence (`CGImage.cropping` rend l'intersection, sans rien dire) —
        // les vignettes des bords sortiraient plus petites ET décalées.
        return Grid(
            columns: clamped(columns ?? uniform.columns, to: width),
            rows: clamped(rows ?? uniform.rows, to: height)
        )
    }

    private static func clamped(_ lines: [Double], to size: Int) -> [Double] {
        lines.map { min(max($0, 0), Double(size)) }
    }

    /// L'analyse se fait à la résolution de l'image redressée (800 px), SANS
    /// la réduire.
    ///
    /// Une réduction paraissait gratuite — les lignes du damier sont des
    /// structures à basse fréquence. Elle introduisait en réalité un décalage
    /// d'un demi-pixel entre les deux grilles de pixels, soit 2,5 px une fois
    /// remis à l'échelle : de quoi désaxer chaque vignette et faire chuter la
    /// reconnaissance sur un plateau pourtant parfaitement cadré. Le plafond
    /// ne sert qu'à borner le coût d'une image inhabituellement grande.
    private static let maximumAnalysisSide = 1024

    // MARK: Profil de contours

    /// Force des contours le long d'une direction, mesurée par la **médiane**
    /// des gradients — pas leur moyenne.
    ///
    /// C'est la médiane qui fait tout le travail : une ligne du damier
    /// traverse l'image de part en part, donc la MOITIÉ AU MOINS des pixels de
    /// sa colonne portent une transition ; le bord d'une dame, lui, n'en
    /// touche qu'une poignée. Une moyenne les met sur le même plan, et les
    /// glyphes tirent la grille de côté (défaut mesuré : les rangées
    /// ressortaient décalées de 2,5 px, les colonnes — moins encombrées —
    /// tombaient juste).
    ///
    /// - parameter alongColumns: `true` pour un profil en x (lignes
    ///   verticales), `false` pour un profil en y.
    static func edgeProfile(_ luminance: [Double], side: Int, alongColumns: Bool) -> [Double] {
        var profile = [Double](repeating: 0, count: side)
        var gradients = [Double](repeating: 0, count: side)

        for index in 1..<(side - 1) {
            for other in 0..<side {
                let before = alongColumns
                    ? luminance[other * side + index - 1]
                    : luminance[(index - 1) * side + other]
                let after = alongColumns
                    ? luminance[other * side + index + 1]
                    : luminance[(index + 1) * side + other]
                gradients[other] = abs(after - before)
            }
            profile[index] = Sample.median(gradients)
        }
        return profile
    }

    // MARK: Recherche du pas et de la phase

    /// Cherche le couple (pas, phase) qui aligne 9 lignes équidistantes sur
    /// les crêtes du profil.
    ///
    /// Recherche exhaustive plutôt que détection de pics : un pic isolé se
    /// fait voler la vedette par le bord d'une dame, alors qu'une grille
    /// complète de 9 lignes ne peut s'aligner par hasard.
    private static func lines(from profile: [Double], scale: Double) -> [Double]? {
        let side = Double(profile.count)
        let idealPeriod = side / 8

        var best: (score: Double, period: Double, phase: Double)?

        for periodStep in -12...12 {
            let period = idealPeriod * (1 + Double(periodStep) / 12 * periodTolerance)
            let maximumPhase = period * phaseTolerance

            for phaseStep in -12...12 {
                let phase = Double(phaseStep) / 12 * maximumPhase
                // La grille doit tenir dans l'image : au-delà, on découperait
                // du vide.
                guard phase >= -1, phase + period * 8 <= side + 1 else { continue }

                var score = 0.0
                for line in 0...8 {
                    score += sample(profile, at: phase + Double(line) * period)
                }
                if best == nil || score > best!.score {
                    best = (score, period, phase)
                }
            }
        }

        guard let best, best.score > 0 else { return nil }
        return (0...8).map { (best.phase + Double($0) * best.period) * scale }
    }

    /// Valeur du profil à une position fractionnaire, interpolée — sinon la
    /// recherche avancerait par sauts d'un pixel et raterait le vrai optimum.
    /// Hors bornes : 0, ce qui n'avantage aucune grille (le bord extérieur du
    /// plateau peut manquer, notamment sur une capture cadrée au plus juste).
    private static func sample(_ profile: [Double], at position: Double) -> Double {
        guard position >= 0, position <= Double(profile.count - 1) else { return 0 }
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, profile.count - 1)
        let fraction = position - Double(lower)
        return profile[lower] * (1 - fraction) + profile[upper] * fraction
    }
}
