import SwiftUI
import Testing
@testable import ChessLab

/// Quand les commandes d'un écran d'échiquier passent à DROITE du plateau.
///
/// Motif : sur l'iPhone Duo ouvert (13/10/2026), les écrans en colonne
/// laissaient 280 à 330 pt au plateau, dans une place de ~867 × 585 pt.
@MainActor
struct BoardPanelLayoutTests {

    /// Le Duo ouvert, barre latérale repliée : panneau à droite.
    @Test func theOpenDuoPutsThePanelOnTheSide() {
        #expect(BoardPanelLayout.usesSidePanel(in: CGSize(width: 867, height: 585)))
    }

    /// Ce qui ne doit PAS changer : l'iPhone et l'écran extérieur du Duo
    /// (debout), l'iPad debout, et l'iPad en paysage barre latérale ouverte,
    /// dont la colonne de détail est presque carrée.
    @Test(arguments: [
        CGSize(width: 402, height: 780),   // iPhone
        CGSize(width: 466, height: 600),   // Duo fermé
        CGSize(width: 834, height: 1100),  // iPad debout
        CGSize(width: 874, height: 760),   // iPad 11" paysage, barre ouverte
        CGSize(width: 813, height: 690),   // iPad mini paysage, barre ouverte
    ])
    func everyOtherShapeKeepsItsColumn(size: CGSize) {
        #expect(!BoardPanelLayout.usesSidePanel(in: size))
    }

    @Test func nothingIsDecidedWithoutAMeasure() {
        #expect(!BoardPanelLayout.usesSidePanel(in: .zero))
    }

    /// Le panneau reste entre ses bornes, et le plateau gagne au change :
    /// sur le Duo ouvert, la colonne du plateau dépasse les 330 pt d'avant.
    @Test func thePanelStaysWithinItsBoundsAndTheBoardGains() {
        #expect(BoardPanelLayout.panelWidth(in: CGSize(width: 600, height: 400)) == BoardPanelLayout.panelMinimumWidth)
        #expect(BoardPanelLayout.panelWidth(in: CGSize(width: 2000, height: 1000)) == BoardPanelLayout.panelMaximumWidth)
        #expect(BoardPanelLayout.boardColumnWidth(in: CGSize(width: 867, height: 585)) > 500)
    }
}
