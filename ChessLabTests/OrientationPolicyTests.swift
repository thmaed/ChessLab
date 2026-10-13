import Testing
import UIKit
@testable import ChessLab

/// Les orientations selon la taille de l'écran, pas selon l'appareil.
///
/// Motif : l'iPhone Duo est un iPhone, et le verrou portrait de l'iPhone
/// laissait ChessLab couché quand on tournait l'appareil OUVERT (13/10/2026).
struct OrientationPolicyTests {

    /// Tous les iPhone, et l'écran extérieur du Duo : portrait seulement.
    @Test(arguments: [
        CGSize(width: 375, height: 667),   // iPhone SE
        CGSize(width: 440, height: 956),   // le plus large des iPhone
        CGSize(width: 466, height: 678),   // Duo fermé
    ])
    func phonesStayPortrait(screen: CGSize) {
        #expect(OrientationPolicy.supportedOrientations(screenSize: screen) == .portrait)
    }

    /// L'écran intérieur du Duo et tous les iPad : toutes les orientations —
    /// quel que soit le sens dans lequel l'écran est mesuré.
    @Test(arguments: [
        CGSize(width: 951, height: 669),   // Duo ouvert
        CGSize(width: 669, height: 951),
        CGSize(width: 744, height: 1133),  // iPad mini
        CGSize(width: 1032, height: 1376), // iPad Pro 13"
    ])
    func largeScreensRotateFreely(screen: CGSize) {
        #expect(OrientationPolicy.supportedOrientations(screenSize: screen) == .all)
    }

    @Test func noScreenMeansPortrait() {
        #expect(OrientationPolicy.supportedOrientations(screenSize: nil) == .portrait)
    }
}
