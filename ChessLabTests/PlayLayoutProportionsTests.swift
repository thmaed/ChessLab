import SwiftUI
import Testing
@testable import ChessLab

/// Le partage de la place entre l'échiquier et le panneau, sur iPad.
///
/// Motif : sur un iPad Pro 11" en fenêtre réduite (29/09/2026), l'échiquier
/// tombait à 358 pt dans une colonne de 544, et à 454 pt face à un panneau de
/// 376. « L'échiquier ne prend pas de place, et la zone avec l'évaluation, les
/// boutons et les coups joués est trop proéminente. » Les deux règles ci-dessous
/// sont ce qui répond à ça — et ce qui garantit que les iPad en plein écran ne
/// bougent pas.
@MainActor
struct PlayLayoutProportionsTests {

    // MARK: La colonne de droite, en paysage

    /// Le principe : le plateau prend son carré, le panneau prend CE QUI RESTE.
    @Test func thePanelTakesWhatIsLeftBesideTheSquareBoard() {
        // iPad 13" en paysage, barre latérale repliée : large, le panneau
        // atteint son plafond et l'échiquier garde tout le reste.
        #expect(PlayView.panelWidth(in: CGSize(width: 1376, height: 950)) == 420)
        // La fenêtre réduite du testeur : le panneau descend à son plancher
        // au lieu d'emporter 43 % de la largeur.
        #expect(PlayView.panelWidth(in: CGSize(width: 866, height: 730)) == 340)
    }

    /// Le plancher n'est pas un chiffre rond : c'est la largeur utile de la
    /// barre de commandes. En dessous, transport, indice, nulle et abandon ne
    /// tiennent plus sur leur ligne.
    @Test func thePanelNeverGetsNarrowerThanItsControls() {
        #expect(PlayView.panelWidth(in: CGSize(width: 900, height: 880)) == 340)
        #expect(PlayView.panelWidth(in: CGSize(width: 760, height: 750)) == 340)
    }

    /// Et jamais plus large que la fenêtre : la colonne plateau ne doit pas se
    /// voir proposer une largeur négative.
    @Test func thePanelNeverExceedsTheWindow() {
        let tiny = CGSize(width: 300, height: 200)
        #expect(PlayView.panelWidth(in: tiny) == 300)
        #expect(tiny.width - PlayView.panelWidth(in: tiny) >= 0)
    }

    // MARK: La liste des coups, en colonne unique

    /// Sur un iPad en plein écran, la colonne est bien plus haute que large :
    /// la liste garde sa place sous l'échiquier, et rien ne change.
    @Test(arguments: [
        CGSize(width: 734, height: 1274),   // 13" portrait, barre latérale ouverte
        CGSize(width: 544, height: 1130),   // 11" portrait, barre latérale ouverte
        CGSize(width: 454, height: 1030),   // mini portrait, barre latérale ouverte
    ])
    func aFullHeightColumnKeepsItsMovesList(size: CGSize) {
        #expect(PlayView.movesListFitsBelowBoard(in: size))
    }

    /// Dans une colonne presque carrée, la liste ne se paierait qu'en cases
    /// d'échiquier : elle passe dans la feuille, comme sur iPhone.
    @Test(arguments: [
        CGSize(width: 544, height: 730),    // fenêtre partagée, barre latérale ouverte
        CGSize(width: 1032, height: 1266),  // 13" portrait, barre latérale repliée
    ])
    func ashortColumnSendsTheListToTheSheet(size: CGSize) {
        #expect(!PlayView.movesListFitsBelowBoard(in: size))
    }

    /// Ce que la règle vaut en pratique : de combien l'échiquier grandit.
    /// Le calcul est celui de la colonne — le plateau est carré, donc borné
    /// par la largeur ou par la hauteur qui lui reste.
    @Test func droppingTheListGivesTheBoardWhatItWasMissing() {
        let column = CGSize(width: 544, height: 730)
        // Pendules, barre d'évaluation, commandes et espacements.
        let furniture: CGFloat = 250
        let withList = min(column.width, column.height - furniture - 150)
        let withoutList = min(column.width, column.height - furniture)
        #expect(withList == 330)
        #expect(withoutList == 480)
        #expect(!PlayView.movesListFitsBelowBoard(in: column))
    }
}
