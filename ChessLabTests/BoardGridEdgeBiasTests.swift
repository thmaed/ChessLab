import ChessKit
import CoreGraphics
import Testing
import UIKit
@testable import ChessLab

/// Mesure du biais de bord du recalage de grille (Lot 5.2 de `PROMPT-bugs.md`).
///
/// Le constat de la revue : `BoardGridFinder.edgeProfile` calcule un gradient
/// par différence CENTRÉE, sur `1..<(side-1)` — `profile[0]` et
/// `profile[side-1]` restent donc à **zéro**. Le score d'une grille somme
/// pourtant 9 lignes : les deux extrêmes ne contribuent structurellement rien,
/// et le couple (pas, phase) se choisit sur 7 lignes intérieures. Sur un module
/// dont l'en-tête décrit un décalage de 2,5 px comme suffisant à faire chuter
/// la reconnaissance, cela méritait d'être mesuré plutôt que supposé.
///
/// ## Verdict de la mesure : diagnostic exact, correctif inutile
///
/// La dérivée décentrée aux bords a été implémentée puis **retirée** : elle ne
/// change rien, au centième de pixel près.
///
/// | Cadrage | Écart max avant | après |
/// |---|---|---|
/// | parfait | 0,00 / 0,00 | 0,00 / 0,00 |
/// | large (14 px de marge) | 1,71 / 1,71 | 1,71 / 1,71 |
/// | serré (6 px rognés) | 6,00 / **14,52** | 6,00 / **14,52** |
///
/// L'erreur du cadrage serré vient donc d'ailleurs : les lignes extrêmes y
/// tombent **hors de l'image**, où `sample` rend zéro par construction — quoi
/// que contienne le profil. C'est la mesure qui gagne : le code d'origine
/// reste, et ces tests figent sa précision pour qu'une régression se voie.
///
/// Ils **impriment** l'écart (`GRID-BIAS|…`) en plus de l'asserter : le jour
/// où quelqu'un s'attaquera vraiment au cadrage serré, il aura sa référence.
@MainActor
struct BoardGridEdgeBiasTests {

    private func board(
        fen: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        side: CGFloat = 800
    ) throws -> CGImage {
        let position = try #require(Position(fen: fen))
        return try #require(BoardImageRenderer.renderBoard(position: position, theme: .classic, side: side))
    }

    /// Écart maximal, en pixels, entre les 9 lignes trouvées et les 9 lignes
    /// attendues.
    private func maximumDeviation(_ found: [Double], expectedStart: Double, step: Double) -> Double {
        (0...8).map { abs(found[$0] - (expectedStart + Double($0) * step)) }.max() ?? .infinity
    }

    /// Cas 1 — cadrage au pixel près. Les lignes extrêmes tombent exactement
    /// sur `0` et `side`, donc là où le profil est aveugle.
    @Test func perfectCropDeviation() throws {
        let image = try board()
        let grid = BoardGridFinder.grid(in: image)

        let columns = maximumDeviation(grid.columns, expectedStart: 0, step: 100)
        let rows = maximumDeviation(grid.rows, expectedStart: 0, step: 100)
        print(String(format: "GRID-BIAS|cadrage-parfait|colonnes=%.2f|lignes=%.2f", columns, rows))

        #expect(columns < 4)
        #expect(rows < 4)
    }

    /// Cas 2 — le cas réel : plateau de 800 px inséré à 14 px dans une toile de
    /// 828. Les lignes extrêmes tombent à l'INTÉRIEUR de l'image, là où le
    /// profil voit — c'est le cas de référence pour juger si le bord aveugle
    /// change quelque chose.
    @Test func insetCropDeviation() throws {
        let inset = 14.0
        let canvas = 828.0
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let board = try board()

        let padded = try #require(
            UIGraphicsImageRenderer(size: CGSize(width: canvas, height: canvas), format: format).image { context in
                UIColor(white: 0.12, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
                UIImage(cgImage: board).draw(in: CGRect(x: inset, y: inset, width: 800, height: 800))
            }.cgImage
        )

        let grid = BoardGridFinder.grid(in: padded)
        let columns = maximumDeviation(grid.columns, expectedStart: inset, step: 100)
        let rows = maximumDeviation(grid.rows, expectedStart: inset, step: 100)
        print(String(format: "GRID-BIAS|cadrage-large|colonnes=%.2f|lignes=%.2f", columns, rows))

        #expect(columns < 5)
        #expect(rows < 5)
    }

    /// Cas 3 — cadrage TROP SERRÉ : on rogne 6 px de chaque côté, si bien que
    /// les lignes extrêmes du plateau sortent de l'image. C'est le cas que la
    /// revue soupçonne d'être mal servi par un profil aveugle aux bords.
    @Test func tightCropDeviation() throws {
        let crop = 6.0
        let board = try board()
        let cropped = try #require(
            board.cropping(to: CGRect(x: crop, y: crop, width: 800 - 2 * crop, height: 800 - 2 * crop))
        )

        let grid = BoardGridFinder.grid(in: cropped)
        // Le plateau commence désormais 6 px AVANT l'image : la première ligne
        // vraie est à -6, la dernière à 794.
        let columns = maximumDeviation(grid.columns, expectedStart: -crop, step: 100)
        let rows = maximumDeviation(grid.rows, expectedStart: -crop, step: 100)
        print(String(format: "GRID-BIAS|cadrage-serre|colonnes=%.2f|lignes=%.2f", columns, rows))

        // Pas d'assertion serrée ici : ce cas sert de MESURE comparative.
        // L'exigence est seulement que le recalage ne parte pas en vrille.
        #expect(columns < 60)
        #expect(rows < 60)
    }
}
