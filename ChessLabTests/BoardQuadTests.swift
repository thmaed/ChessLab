import CoreGraphics
import Foundation
import Testing
@testable import ChessLab

/// Tests de la géométrie du scanner (étape 7 / Lot 1.B).
///
/// Tout le pipeline repose sur cette projection : une erreur ici décale la
/// découpe des 64 cases et fait lire n'importe quoi au classifieur. D'où des
/// vérifications numériques exactes plutôt que des « à peu près ».
struct BoardQuadTests {

    private func expectClose(_ a: CGPoint, _ b: CGPoint, tolerance: Double = 1e-6, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(abs(Double(a.x) - Double(b.x)) < tolerance, "x: \(a.x) ≠ \(b.x)", sourceLocation: sourceLocation)
        #expect(abs(Double(a.y) - Double(b.y)) < tolerance, "y: \(a.y) ≠ \(b.y)", sourceLocation: sourceLocation)
    }

    private var unitSquare: BoardQuad {
        BoardQuad.covering(width: 800, height: 800)
    }

    /// Un trapèze : côté du haut plus court que celui du bas, comme un
    /// plateau photographié un peu de biais.
    private var trapezoid: BoardQuad {
        BoardQuad(
            topLeft: CGPoint(x: 200, y: 100),
            topRight: CGPoint(x: 600, y: 100),
            bottomRight: CGPoint(x: 800, y: 700),
            bottomLeft: CGPoint(x: 0, y: 700)
        )
    }

    // MARK: Projection

    @Test func cornersMapToTheUnitSquareCorners() {
        let quad = trapezoid

        expectClose(quad.point(u: 0, v: 0), quad.topLeft)
        expectClose(quad.point(u: 1, v: 0), quad.topRight)
        expectClose(quad.point(u: 1, v: 1), quad.bottomRight)
        expectClose(quad.point(u: 0, v: 1), quad.bottomLeft)
    }

    /// Sur un rectangle, la projection doit être une simple interpolation
    /// linéaire — le cas des captures d'écran, le plus fréquent.
    @Test func anAxisAlignedRectangleProjectsLinearly() {
        let quad = BoardQuad.covering(width: 800, height: 400)

        expectClose(quad.point(u: 0.5, v: 0.5), CGPoint(x: 400, y: 200))
        expectClose(quad.point(u: 0.25, v: 0), CGPoint(x: 200, y: 0))
        expectClose(quad.point(u: 1, v: 0.75), CGPoint(x: 800, y: 300))
    }

    /// Propriété projective forte : le centre du carré unité tombe TOUJOURS
    /// sur l'intersection des diagonales du quadrilatère, quelle que soit la
    /// perspective. Une homographie fausse rate ce point.
    @Test func theCenterLandsOnTheIntersectionOfTheDiagonals() {
        let quad = trapezoid
        let center = quad.point(u: 0.5, v: 0.5)

        // Intersection de (topLeft → bottomRight) et (topRight → bottomLeft).
        let expected = intersection(
            CGPoint(x: 200, y: 100), CGPoint(x: 800, y: 700),
            CGPoint(x: 600, y: 100), CGPoint(x: 0, y: 700)
        )

        expectClose(center, try! #require(expected), tolerance: 1e-6)
    }

    private func intersection(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> CGPoint? {
        let x1 = Double(p1.x), y1 = Double(p1.y), x2 = Double(p2.x), y2 = Double(p2.y)
        let x3 = Double(p3.x), y3 = Double(p3.y), x4 = Double(p4.x), y4 = Double(p4.y)
        let d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        guard abs(d) > 1e-12 else { return nil }
        let a = x1 * y2 - y1 * x2
        let b = x3 * y4 - y3 * x4
        return CGPoint(x: (a * (x3 - x4) - (x1 - x2) * b) / d, y: (a * (y3 - y4) - (y1 - y2) * b) / d)
    }

    /// Sous perspective, les rangées ne sont PAS équidistantes : celles du
    /// fond se resserrent. Si elles l'étaient, la projection serait affine
    /// et la découpe se décalerait sur les photos.
    @Test func perspectiveCompressesTheFarRows() {
        let quad = trapezoid

        let firstRowHeight = Double(quad.point(u: 0.5, v: 1.0 / 8).y) - Double(quad.point(u: 0.5, v: 0).y)
        let lastRowHeight = Double(quad.point(u: 0.5, v: 1).y) - Double(quad.point(u: 0.5, v: 7.0 / 8).y)

        #expect(firstRowHeight < lastRowHeight)
    }

    // MARK: Grille

    @Test func theGridHas81Intersections() {
        let grid = trapezoid.gridIntersections

        #expect(grid.count == 9)
        #expect(grid.allSatisfy { $0.count == 9 })
        #expect(grid.flatMap { $0 }.count == 81)
    }

    @Test func theGridCornersAreTheQuadCorners() {
        let quad = trapezoid
        let grid = quad.gridIntersections

        expectClose(grid[0][0], quad.topLeft)
        expectClose(grid[0][8], quad.topRight)
        expectClose(grid[8][8], quad.bottomRight)
        expectClose(grid[8][0], quad.bottomLeft)
    }

    @Test func aRectangleGridIsEvenlySpaced() {
        let grid = BoardQuad.covering(width: 800, height: 800).gridIntersections

        for row in 0...8 {
            for column in 0...8 {
                expectClose(grid[row][column], CGPoint(x: Double(column) * 100, y: Double(row) * 100))
            }
        }
    }

    // MARK: Cases

    @Test func squareQuadsTileTheBoardWithoutGaps() {
        let quad = trapezoid

        // Le coin bas-droit d'une case est le coin haut-gauche de sa voisine
        // en diagonale : aucune bande de pixels perdue entre deux cases.
        for row in 0..<7 {
            for column in 0..<7 {
                expectClose(
                    quad.squareQuad(column: column, row: row).bottomRight,
                    quad.squareQuad(column: column + 1, row: row + 1).topLeft
                )
            }
        }
    }

    @Test func theFirstSquareOfARectangleBoardIsItsTopLeftEighth() {
        let quad = BoardQuad.covering(width: 800, height: 800)
        let a8 = quad.squareQuad(column: 0, row: 0)

        expectClose(a8.topLeft, CGPoint(x: 0, y: 0))
        expectClose(a8.bottomRight, CGPoint(x: 100, y: 100))
    }

    // MARK: Tri des coins

    @Test func fourPointsInAnyOrderAreSortedClockwiseFromTopLeft() throws {
        let expected = BoardQuad(
            topLeft: CGPoint(x: 10, y: 20),
            topRight: CGPoint(x: 200, y: 15),
            bottomRight: CGPoint(x: 210, y: 220),
            bottomLeft: CGPoint(x: 5, y: 200)
        )

        // Les mêmes coins, mélangés — ce que rend Vision (ordre non garanti).
        let shuffled = [expected.bottomRight, expected.topLeft, expected.bottomLeft, expected.topRight]
        let ordered = try #require(BoardQuad.ordering(shuffled))

        #expect(ordered == expected)
    }

    @Test func orderingRejectsAnythingButFourPoints() {
        #expect(BoardQuad.ordering([]) == nil)
        #expect(BoardQuad.ordering([CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2), CGPoint(x: 3, y: 3)]) == nil)
    }

    // MARK: Convexité

    @Test func aPlainRectangleIsConvex() {
        #expect(unitSquare.isConvex)
        #expect(unitSquare.isUsable)
    }

    @Test func aPerspectiveTrapezoidIsConvex() {
        #expect(trapezoid.isConvex)
        #expect(trapezoid.isUsable)
    }

    /// « Nœud papillon » : deux côtés se croisent.
    @Test func aBowtieIsRejected() {
        let bowtie = BoardQuad(
            topLeft: CGPoint(x: 0, y: 0),
            topRight: CGPoint(x: 800, y: 0),
            bottomRight: CGPoint(x: 100, y: 800),
            bottomLeft: CGPoint(x: 700, y: 600)
        )

        #expect(!bowtie.isConvex)
        #expect(!bowtie.isUsable)
    }

    /// Le cas EXACT vu à la capture : le coin haut gauche glissé sur le coin
    /// bas droit. **Son aire vaut 24 000 px²** — le seul contrôle d'aire
    /// (`> 100`) le laissait donc passer sans broncher, et le redressement
    /// rendait une image coupée en diagonale. Seule la convexité l'attrape.
    @Test func draggingACornerOntoTheOppositeOneIsRejected() {
        let collapsed = BoardQuad(
            topLeft: CGPoint(x: 780, y: 760),
            topRight: CGPoint(x: 800, y: 0),
            bottomRight: CGPoint(x: 800, y: 800),
            bottomLeft: CGPoint(x: 0, y: 800)
        )

        #expect(collapsed.area > 100, "l'aire seule ne suffisait pas à le rejeter")
        #expect(!collapsed.isConvex)
        #expect(!collapsed.isUsable)
    }

    /// Quadrilatère concave (« fer de flèche ») : un coin rentrant.
    @Test func aConcaveQuadIsRejected() {
        let dart = BoardQuad(
            topLeft: CGPoint(x: 0, y: 0),
            topRight: CGPoint(x: 400, y: 300),
            bottomRight: CGPoint(x: 800, y: 0),
            bottomLeft: CGPoint(x: 400, y: 800)
        )

        #expect(!dart.isConvex)
        #expect(!dart.isUsable)
    }

    @Test func fourCollinearPointsAreRejected() {
        let flat = BoardQuad(
            topLeft: CGPoint(x: 0, y: 0),
            topRight: CGPoint(x: 100, y: 100),
            bottomRight: CGPoint(x: 200, y: 200),
            bottomLeft: CGPoint(x: 300, y: 300)
        )

        #expect(!flat.isConvex)
        #expect(!flat.isUsable)
    }

    @Test func aQuadCollapsedToAPointIsRejected() {
        let dot = BoardQuad(
            topLeft: .zero, topRight: .zero, bottomRight: .zero, bottomLeft: .zero
        )

        #expect(!dot.isUsable)
    }

    // MARK: Aire & échelle

    @Test func theAreaOfARectangleIsWidthTimesHeight() {
        #expect(abs(BoardQuad.covering(width: 800, height: 400).area - 320_000) < 1e-6)
    }

    @Test func scalingMovesEveryCorner() {
        let scaled = BoardQuad.covering(width: 800, height: 800).scaled(by: 0.5)

        expectClose(scaled.bottomRight, CGPoint(x: 400, y: 400))
        #expect(abs(scaled.area - 160_000) < 1e-6)
    }
}
