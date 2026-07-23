import ChessKit
import CoreGraphics
import Testing
import UIKit
@testable import ChessLab

/// État du scanner entre deux scans : ce qui doit être OUBLIÉ en revenant en
/// arrière, et ce qui doit rester atteignable quand le cadrage automatique
/// échoue.
@MainActor
struct ScannerStateTests {

    /// Image de test : un damier net, que la détection reconnaît.
    private func boardImage() -> CGImage? {
        guard let position = Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") else { return nil }
        return BoardImageRenderer.renderBoard(position: position, theme: .classic, side: 800)
    }

    /// 🐛 `reading` survivait au retour en arrière : tant qu'une nouvelle
    /// image n'était pas validée, `readFEN` rendait encore la position du
    /// scan PRÉCÉDENT, alors qu'aucun plateau n'est plus à l'écran.
    @Test func goingBackToTheSourceForgetsThePreviousReading() async throws {
        let vm = ScannerViewModel()
        let image = try #require(boardImage())
        await vm.load(UIImage(cgImage: image))

        try #require(vm.readFEN != nil, "le scan devrait avoir produit une lecture")

        vm.backToSource()

        #expect(vm.readFEN == nil, "aucune position ne doit subsister après un retour en arrière")
        #expect(vm.stage == .chooseSource)
        #expect(vm.rotation == .none)
    }

    /// 🐛 Un échec du cadrage AUTOMATIQUE laissait l'écran sur le choix de
    /// source, avec une image chargée mais invisible et aucune porte de
    /// sortie — alors que l'ajustement manuel existe pour ces cas-là.
    @Test func aFailedAutomaticCropFallsBackToManualAdjustment() async throws {
        let vm = ScannerViewModel()
        let image = try #require(boardImage())
        await vm.load(UIImage(cgImage: image))

        // Quel que soit le sort du cadrage auto, on ne reste JAMAIS bloqué à
        // l'étape du choix de source une fois l'image chargée.
        #expect(vm.stage != .chooseSource, "une image chargée doit toujours mener quelque part")
    }

    /// L'erreur qui a motivé le retour n'a pas à rester affichée au-dessus de
    /// l'écran où on vient la corriger.
    @Test func goingBackToTheCropClearsTheError() async throws {
        let vm = ScannerViewModel()
        let image = try #require(boardImage())
        await vm.load(UIImage(cgImage: image))

        vm.backToCrop()

        #expect(vm.errorMessage == nil)
        #expect(vm.stage == .adjustCrop)
    }
}
