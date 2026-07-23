import CoreGraphics
import Foundation

/// Les quatre coins d'un plateau dans une image, et la projection qui en
/// découle.
///
/// **Espace de coordonnées** : pixels de l'image, **origine en haut à
/// gauche** (comme `CGImage` et SwiftUI). C'est la convention de tout le
/// scanner ; les conversions vers Vision (normalisé, origine en bas à
/// gauche) et CoreImage (origine en bas à gauche) sont faites À LA FRONTIÈRE
/// de ces frameworks, jamais ici. Ce type reste ainsi pur et testable sans
/// image ni simulateur.
struct BoardQuad: Equatable, Hashable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    /// Quadrilatère couvrant toute une image de taille donnée.
    static func covering(width: Double, height: Double, inset: Double = 0) -> BoardQuad {
        BoardQuad(
            topLeft: CGPoint(x: inset, y: inset),
            topRight: CGPoint(x: width - inset, y: inset),
            bottomRight: CGPoint(x: width - inset, y: height - inset),
            bottomLeft: CGPoint(x: inset, y: height - inset)
        )
    }

    /// Quadrilatère (aligné sur les axes) couvrant un rectangle — la sortie de
    /// la détection automatique par damier.
    static func covering(rect: CGRect) -> BoardQuad {
        BoardQuad(
            topLeft: CGPoint(x: rect.minX, y: rect.minY),
            topRight: CGPoint(x: rect.maxX, y: rect.minY),
            bottomRight: CGPoint(x: rect.maxX, y: rect.maxY),
            bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        )
    }

    // MARK: Projection

    /// Coefficients de l'homographie carré unité → quadrilatère.
    ///
    /// Méthode de Heckbert (« Fundamentals of Texture Mapping and Image
    /// Warping », §2.2) : le carré unité a ses sommets en (0,0), (1,0),
    /// (1,1), (0,1), qui correspondent dans l'ordre à `topLeft`,
    /// `topRight`, `bottomRight`, `bottomLeft`.
    private struct Homography {
        let a, b, c, d, e, f, g, h: Double

        init(_ quad: BoardQuad) {
            let x0 = Double(quad.topLeft.x), y0 = Double(quad.topLeft.y)
            let x1 = Double(quad.topRight.x), y1 = Double(quad.topRight.y)
            let x2 = Double(quad.bottomRight.x), y2 = Double(quad.bottomRight.y)
            let x3 = Double(quad.bottomLeft.x), y3 = Double(quad.bottomLeft.y)

            let dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3
            let dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3

            let denominator = dx1 * dy2 - dy1 * dx2

            // dx3 == dy3 == 0 : les côtés opposés sont parallèles, la
            // transformation est affine (cas d'une capture d'écran non
            // déformée) — les termes projectifs s'annulent.
            if abs(dx3) < 1e-9 && abs(dy3) < 1e-9 {
                a = x1 - x0; b = x2 - x1; c = x0
                d = y1 - y0; e = y2 - y1; f = y0
                g = 0; h = 0
            } else if abs(denominator) < 1e-12 {
                // Quadrilatère dégénéré (coins alignés ou confondus) :
                // repli affine, faute de mieux. L'appelant valide en amont.
                a = x1 - x0; b = x2 - x1; c = x0
                d = y1 - y0; e = y2 - y1; f = y0
                g = 0; h = 0
            } else {
                g = (dx3 * dy2 - dy3 * dx2) / denominator
                h = (dx1 * dy3 - dy1 * dx3) / denominator
                a = x1 - x0 + g * x1
                b = x3 - x0 + h * x3
                c = x0
                d = y1 - y0 + g * y1
                e = y3 - y0 + h * y3
                f = y0
            }
        }

        func map(u: Double, v: Double) -> CGPoint {
            let w = g * u + h * v + 1
            guard abs(w) > 1e-12 else { return CGPoint(x: c, y: f) }
            return CGPoint(x: (a * u + b * v + c) / w, y: (d * u + e * v + f) / w)
        }
    }

    /// Point de l'image correspondant aux coordonnées `(u, v)` du plateau,
    /// avec `(0,0)` au coin `topLeft` et `(1,1)` au coin `bottomRight`.
    func point(u: Double, v: Double) -> CGPoint {
        Homography(self).map(u: u, v: v)
    }

    /// Les 81 intersections de la grille 8×8 (9×9 points), lignes du haut
    /// vers le bas. C'est ce que l'ajustement manuel superpose à l'image :
    /// aligner ces lignes sur les rangées du plateau rend le placement des
    /// coins précis sans loupe.
    var gridIntersections: [[CGPoint]] {
        let homography = Homography(self)
        return (0...8).map { row in
            (0...8).map { column in
                homography.map(u: Double(column) / 8, v: Double(row) / 8)
            }
        }
    }

    /// Quadrilatère d'une case, `column`/`row` comptés depuis le coin
    /// `topLeft` (0...7).
    func squareQuad(column: Int, row: Int) -> BoardQuad {
        let homography = Homography(self)
        let u0 = Double(column) / 8, u1 = Double(column + 1) / 8
        let v0 = Double(row) / 8, v1 = Double(row + 1) / 8

        return BoardQuad(
            topLeft: homography.map(u: u0, v: v0),
            topRight: homography.map(u: u1, v: v0),
            bottomRight: homography.map(u: u1, v: v1),
            bottomLeft: homography.map(u: u0, v: v1)
        )
    }

    // MARK: Validation & tri

    /// Aire (formule du lacet). Sert à écarter les détections dégénérées.
    var area: Double {
        let points = corners.map { (Double($0.x), Double($0.y)) }
        var sum = 0.0
        for i in 0..<4 {
            let (x1, y1) = points[i]
            let (x2, y2) = points[(i + 1) % 4]
            sum += x1 * y2 - x2 * y1
        }
        return abs(sum) / 2
    }

    /// Vrai si les quatre coins forment un quadrilatère **convexe et non
    /// croisé**.
    ///
    /// Indispensable : en croisant deux poignées (glisser le coin haut
    /// gauche par-dessus le coin bas droit), on obtient un « nœud papillon »
    /// dont l'aire reste grande — le contrôle d'aire seul le laissait passer,
    /// et le redressement rendait alors une image coupée en diagonale, sans
    /// le moindre message. Vu à la capture, corrigé ici.
    ///
    /// Test : les produits vectoriels des arêtes consécutives doivent tous
    /// avoir le même signe (rotation toujours dans le même sens).
    var isConvex: Bool {
        let points = corners
        var sawPositive = false
        var sawNegative = false

        for i in 0..<4 {
            let a = points[i]
            let b = points[(i + 1) % 4]
            let c = points[(i + 2) % 4]

            let cross = (Double(b.x) - Double(a.x)) * (Double(c.y) - Double(b.y))
                - (Double(b.y) - Double(a.y)) * (Double(c.x) - Double(b.x))

            if cross > 1e-9 { sawPositive = true }
            if cross < -1e-9 { sawNegative = true }
            // Les deux : au moins un coin rentrant → croisé ou concave.
            if sawPositive && sawNegative { return false }
        }

        // Ni l'un ni l'autre = les 4 points sont alignés.
        return sawPositive || sawNegative
    }

    /// Cadrage exploitable : convexe et d'une aire non dégénérée.
    var isUsable: Bool {
        isConvex && area > 100
    }

    /// Range 4 points quelconques en topLeft / topRight / bottomRight /
    /// bottomLeft. Indispensable : Vision ne garantit pas l'ordre de ses
    /// coins, et l'ajustement manuel laisse l'utilisateur croiser les
    /// poignées.
    ///
    /// Tri par angle autour du barycentre (robuste à la perspective, là où
    /// un tri par x/y se trompe dès que le plateau est incliné), puis on
    /// démarre au coin le plus « en haut à gauche ».
    static func ordering(_ points: [CGPoint]) -> BoardQuad? {
        guard points.count == 4 else { return nil }

        let centerX = points.map { Double($0.x) }.reduce(0, +) / 4
        let centerY = points.map { Double($0.y) }.reduce(0, +) / 4

        // Angles croissants = sens horaire (l'axe y descend vers le bas).
        let sorted = points.sorted {
            atan2(Double($0.y) - centerY, Double($0.x) - centerX)
                < atan2(Double($1.y) - centerY, Double($1.x) - centerX)
        }

        guard let startIndex = sorted.indices.min(by: {
            let a = sorted[$0], b = sorted[$1]
            return (Double(a.x) + Double(a.y)) < (Double(b.x) + Double(b.y))
        }) else { return nil }

        let rotated = (0..<4).map { sorted[(startIndex + $0) % 4] }
        return BoardQuad(
            topLeft: rotated[0], topRight: rotated[1],
            bottomRight: rotated[2], bottomLeft: rotated[3]
        )
    }

    /// Mise à l'échelle (image redimensionnée avant traitement, aperçu à
    /// l'écran plus petit que l'image d'origine…).
    func scaled(by factor: Double) -> BoardQuad {
        BoardQuad(
            topLeft: CGPoint(x: Double(topLeft.x) * factor, y: Double(topLeft.y) * factor),
            topRight: CGPoint(x: Double(topRight.x) * factor, y: Double(topRight.y) * factor),
            bottomRight: CGPoint(x: Double(bottomRight.x) * factor, y: Double(bottomRight.y) * factor),
            bottomLeft: CGPoint(x: Double(bottomLeft.x) * factor, y: Double(bottomLeft.y) * factor)
        )
    }
}
