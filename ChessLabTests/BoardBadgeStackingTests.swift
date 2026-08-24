import ChessKit
import SwiftUI
import UIKit
import XCTest
@testable import ChessLab

/// La pastille de qualité (gaffe, coup brillant…) est posée sur la case
/// d'ARRIVÉE du coup joué — exactement là où une flèche du moteur commence ou
/// se termine. Elles se disputent donc les mêmes pixels, et l'ordre du `ZStack`
/// faisait passer les flèches DEVANT : la pastille devenait illisible
/// précisément quand elle compte le plus, sur une gaffe ou un coup brillant.
///
/// Un ordre d'empilement ne se lit dans aucune propriété : il se CONSTATE au
/// rendu. Ces tests dessinent donc l'échiquier et regardent les pixels.
@MainActor
final class BoardBadgeStackingTests: XCTestCase {

    /// Plateau de 400 pt : 50 pt par case, des coordonnées entières partout.
    private static let side: CGFloat = 400
    private static let squareSize: CGFloat = side / 8

    /// Centre de la pastille posée sur e4 : ``ChessBoardView`` la décale de
    /// 0,30 case vers le coin haut-droit de sa case.
    private static let badgeCenter = CGPoint(x: 4 * squareSize + squareSize / 2 + squareSize * 0.30,
                                             y: 4 * squareSize + squareSize / 2 - squareSize * 0.30)

    /// Flèche h8 → e4 : elle arrive sur e4 par le haut-droit, donc son fût et
    /// sa pointe passent SUR la pastille. C'est le conflit à trancher.
    private static let crossingArrow = HintMove(rank: 1, from: Square("h8"), to: Square("e4"), strength: 1)

    private func board(arrow: Bool, badge: Bool) -> some View {
        ChessBoardView(
            board: Board(position: .standard),
            orientation: .white,
            theme: .classic,
            selectedSquare: nil,
            legalTargetSquares: [],
            lastMove: nil,
            hintMoves: arrow ? [Self.crossingArrow] : [],
            qualityBadge: badge ? (Square("e4"), MoveQuality.blunder) : nil,
            interactionEnabled: false,
            showCoordinates: false,
            onTapSquare: { _ in },
            onDropPiece: { _, _ in }
        )
        .frame(width: Self.side, height: Self.side)
    }

    /// Couleur effectivement dessinée en `point`, à l'échelle 1 : 1.
    private func pixel(_ view: some View, at point: CGPoint) throws -> [UInt8] {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage, "le rendu n'a produit aucune image")

        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // On translate l'image pour amener le point voulu sur l'unique pixel.
        context.draw(image, in: CGRect(x: -point.x, y: -(CGFloat(image.height) - point.y),
                                       width: CGFloat(image.width), height: CGFloat(image.height)))
        return pixel
    }

    /// Contrôle de VALIDITÉ du test lui-même : sans lui, les deux suivants
    /// passeraient tout aussi bien si la flèche ne touchait pas la pastille —
    /// on prouverait alors qu'il n'y a pas de conflit, pas qu'il est tranché.
    func testTheArrowGenuinelyCoversTheBadgeSpot() throws {
        let bare = try pixel(board(arrow: false, badge: false), at: Self.badgeCenter)
        let withArrow = try pixel(board(arrow: true, badge: false), at: Self.badgeCenter)
        XCTAssertNotEqual(
            bare, withArrow,
            "La flèche ne passe pas sur l'emplacement de la pastille : le test ne prouve rien."
        )
    }

    /// Le cœur du sujet : ajouter une flèche ne doit RIEN changer aux pixels
    /// de la pastille.
    func testTheArrowDoesNotPaintOverTheBadge() throws {
        let badgeAlone = try pixel(board(arrow: false, badge: true), at: Self.badgeCenter)
        let badgeAndArrow = try pixel(board(arrow: true, badge: true), at: Self.badgeCenter)
        XCTAssertEqual(
            badgeAlone, badgeAndArrow,
            "La flèche repeint la pastille : elle est dessinée au-dessus (\(badgeAlone) → \(badgeAndArrow))."
        )
    }

    /// Et ce qu'on voit là est bien la pastille, pas le fond du plateau : la
    /// teinte de la gaffe est franchement rouge.
    func testWhatShowsThereIsTheBadge() throws {
        let p = try pixel(board(arrow: true, badge: true), at: Self.badgeCenter)
        XCTAssertGreaterThan(Int(p[0]), Int(p[1]) + 40, "la pastille « gaffe » est rouge (obtenu \(p))")
        XCTAssertGreaterThan(Int(p[0]), Int(p[2]) + 40, "la pastille « gaffe » est rouge (obtenu \(p))")
    }
}
