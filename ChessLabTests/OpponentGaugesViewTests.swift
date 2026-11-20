import SwiftUI
import Testing
import UIKit
@testable import ChessLab

/// Retour de l'utilisateur sur TestFlight (20/11/2026) : sur un vieil iPhone en affichage « Zoomé » (320 pt), l'écran
/// Nouvelle partie était plus large que l'écran — la grille des jauges exigeait 342 pt (libellé de 82 pt et points de
/// 72 pt, deux fois), et cette largeur gagnait tout l'écran. Les jauges doivent se contenter de ce qu'on leur donne.
@MainActor
struct OpponentGaugesViewTests {
    private func size(proposing width: CGFloat) -> CGSize {
        let view = OpponentGaugesView(traits: OpponentTraits(OpponentProfile.all[0]), tint: .blue)
        return UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 1_000))
    }

    @Test func theGaugesNeverAskForMoreWidthThanTheyAreGiven() {
        // 320 pt = iPhone « Zoomé » ; moins encore : texte très agrandi, fenêtre étroite.
        for width: CGFloat in [240, 270, 296, 320, 342, 380, 402] {
            let wanted = size(proposing: width).width
            #expect(wanted <= width + 0.5, "proposé \(width) pt, demandé \(wanted) pt")
        }
    }

    @Test func withRoomTheyKeepTheLookTheyHadBefore() {
        // Assez de place : 82 + 8 + 72 pt, deux fois, et 18 pt entre les deux colonnes, comme avec l'ancienne grille.
        let wanted = size(proposing: 400).width
        #expect(abs(wanted - 342) <= 1, "demandé \(wanted) pt")
    }

    /// Pour LIRE le rendu (pas une vérification) : `TEST_RUNNER_GAUGES_PNG_DIR=/dossier xcodebuild test …`.
    @Test func renderForTheEyes() throws {
        guard let folder = ProcessInfo.processInfo.environment["GAUGES_PNG_DIR"] else { return }
        for width: CGFloat in [300, 320, 342, 400] {
            let view = OpponentGaugesView(traits: OpponentTraits(OpponentProfile.all[0]), tint: .blue)
                .frame(width: width)
                .padding(8)
                .background(Color(white: 0.15))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            if let data = renderer.uiImage?.pngData() {
                try data.write(to: URL(fileURLWithPath: folder).appending(path: "jauges-\(Int(width)).png"))
            }
        }
    }
}
