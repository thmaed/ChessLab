import CoreGraphics
import Testing
@testable import ChessLab

/// Le recadrage du scanner attribue le doigt au coin le plus PROCHE, dans un
/// rayon de saisie — c'est désormais le seul chemin par lequel une poignée
/// bouge (voir ``BoardCropView/nearestCorner(to:among:)``).
@MainActor
struct CropHandleGrabTests {

    private let corners: [(BoardCropView.Corner, CGPoint)] = [
        (.topLeft, CGPoint(x: 10, y: 10)),
        (.topRight, CGPoint(x: 300, y: 10)),
        (.bottomRight, CGPoint(x: 300, y: 300)),
        (.bottomLeft, CGPoint(x: 10, y: 300)),
    ]

    /// Le cas du défaut iOS 18 : un toucher dans le coin haut-gauche de
    /// l'image, là où les poignées étaient mises en page, saisit bien le coin
    /// haut-gauche.
    @Test func aTouchNearTheOriginGrabsTheTopLeftCorner() {
        #expect(BoardCropView.nearestCorner(to: CGPoint(x: 0, y: 0), among: corners) == .topLeft)
    }

    @Test func theClosestCornerWins() {
        #expect(BoardCropView.nearestCorner(to: CGPoint(x: 280, y: 290), among: corners) == .bottomRight)
    }

    /// Loin de tout coin, rien n'est saisi : un geste au milieu de l'image ne
    /// doit déplacer aucune poignée.
    @Test func aTouchFarFromEveryCornerGrabsNothing() {
        #expect(BoardCropView.nearestCorner(to: CGPoint(x: 150, y: 150), among: corners) == nil)
    }

    @Test func theRadiusIsInclusive() {
        let edge = CGPoint(x: 10 + BoardCropView.grabRadius, y: 10)
        #expect(BoardCropView.nearestCorner(to: edge, among: corners) == .topLeft)
    }
}
