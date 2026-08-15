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
/// L'erreur du cadrage serré venait donc d'ailleurs.
///
/// ## Le cadrage serré, tranché le 15/08/2026
///
/// Elle venait du **garde** de `BoardGridFinder.lines(from:scale:)`, qui
/// exigeait que les 9 lignes tiennent dans l'image : sur un plateau de 800 px
/// rogné de 6, la vraie grille a un pas de 100 et une phase de −6, et les deux
/// conditions du garde étaient contradictoires. La bonne réponse n'était pas
/// mal notée, elle était **hors concours** — la recherche se rabattait sur un
/// pas ≤ 98,75, soit une dizaine de pixels d'erreur cumulée.
///
/// Le garde est devenu un quorum de lignes visibles. Résultat, en rangées :
/// **14,52 px → 6,00**.
///
/// Et ces 6 px restants ne sont plus une erreur de grille : ce sont exactement
/// les deux lignes extrêmes, qui tombent hors de l'image et que `grid(in:)`
/// ramène au bord. L'écart des **7 lignes intérieures** — celles qui découpent
/// réellement les vignettes — tombe à zéro. C'est ce que mesure
/// `interiorDeviation`, et c'est lui qui porte l'assertion serrée.
///
/// Ces tests **impriment** l'écart (`GRID-BIAS|…`) en plus de l'asserter :
/// la mesure documente mieux que le verdict.
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

    /// Même écart, mais sur les **7 lignes intérieures** seulement.
    ///
    /// Quand le plateau déborde de l'image, ses deux lignes extrêmes n'y sont
    /// tout simplement pas, et `BoardGridFinder.grid(in:)` les ramène au bord.
    /// Les compter dans l'écart mesure alors le bornage, pas le recalage — or
    /// ce sont les lignes intérieures qui découpent les vignettes.
    private func interiorDeviation(_ found: [Double], expectedStart: Double, step: Double) -> Double {
        (1...7).map { abs(found[$0] - (expectedStart + Double($0) * step)) }.max() ?? .infinity
    }

    /// Cas 1 — cadrage au pixel près. Les lignes extrêmes tombent exactement
    /// sur `0` et `side`, donc là où le profil est aveugle.
    @Test func perfectCropDeviation() throws {
        let image = try board()
        let grid = BoardGridFinder.grid(in: image)

        let columns = maximumDeviation(grid.columns, expectedStart: 0, step: 100)
        let rows = maximumDeviation(grid.rows, expectedStart: 0, step: 100)
        print(String(
            format: "GRID-BIAS|cadrage-parfait|colonnes=%.2f|lignes=%.2f|intérieur=%.2f/%.2f",
            columns, rows,
            interiorDeviation(grid.columns, expectedStart: 0, step: 100),
            interiorDeviation(grid.rows, expectedStart: 0, step: 100)
        ))

        // Sous les 2,5 px que l'en-tête de ``BoardGridFinder`` donne pour seuil
        // de décrochage de la reconnaissance.
        #expect(columns < 2.5)
        #expect(rows < 2.5)
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
        print(String(
            format: "GRID-BIAS|cadrage-large|colonnes=%.2f|lignes=%.2f|intérieur=%.2f/%.2f",
            columns, rows,
            interiorDeviation(grid.columns, expectedStart: inset, step: 100),
            interiorDeviation(grid.rows, expectedStart: inset, step: 100)
        ))

        #expect(columns < 2.5)
        #expect(rows < 2.5)
    }

    /// Cas 3 — cadrage TROP SERRÉ : on rogne 6 px de chaque côté, si bien que
    /// les lignes extrêmes du plateau sortent de l'image. C'est le cas que la
    /// revue soupçonnait d'être mal servi par un profil aveugle aux bords, et
    /// qui venait en réalité du garde de `lines(from:scale:)` (voir l'en-tête).
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
        let innerColumns = interiorDeviation(grid.columns, expectedStart: -crop, step: 100)
        let innerRows = interiorDeviation(grid.rows, expectedStart: -crop, step: 100)
        print(String(
            format: "GRID-BIAS|cadrage-serre|colonnes=%.2f|lignes=%.2f|intérieur=%.2f/%.2f",
            columns, rows, innerColumns, innerRows
        ))

        // Les 7 lignes INTÉRIEURES sont celles qui découpent les vignettes :
        // c'est sur elles que porte l'exigence, et elle est serrée. L'en-tête
        // de `BoardGridFinder` juge 2,5 px suffisants à faire chuter la
        // reconnaissance — le seuil est donc calé en dessous.
        #expect(innerColumns < 2)
        #expect(innerRows < 2)

        // Les deux lignes extrêmes, elles, sont hors de l'image et ramenées au
        // bord : leur écart ne peut pas descendre sous la valeur du rognage.
        // On vérifie seulement qu'il ne la DÉPASSE pas, ce qui signalerait un
        // recalage parti en vrille.
        #expect(columns <= crop + 1)
        #expect(rows <= crop + 1)
    }
}
