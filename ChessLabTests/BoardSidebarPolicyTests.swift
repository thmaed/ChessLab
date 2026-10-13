import SwiftUI
import Testing
@testable import ChessLab

/// Quand la barre latérale cède sa place à l'échiquier.
///
/// Motif : sur l'iPhone Duo ouvert (13/10/2026, simulateur Xcode 27.1), la
/// barre latérale laissait au plateau 349 pt en partie et 184 pt en analyse —
/// moins que l'écran extérieur, replié, du même téléphone.
@MainActor
struct BoardSidebarPolicyTests {

    /// L'iPhone Duo ouvert, mesuré dans sa zone sûre : la barre se replie.
    @Test func theOpenDuoCollapsesTheSidebarOnABoard() {
        #expect(BoardSidebarPolicy.collapsesSidebar(showsBoard: true, size: CGSize(width: 867, height: 635)))
    }

    /// Une liste garde sa barre latérale, même étroite.
    @Test func aListKeepsItsSidebar() {
        #expect(!BoardSidebarPolicy.collapsesSidebar(showsBoard: false, size: CGSize(width: 867, height: 635)))
    }

    /// Tous les iPad en plein écran, en paysage : rien ne change — le plus
    /// étroit, l'iPad mini, fait 1 133 pt.
    @Test(arguments: [CGSize(width: 1133, height: 744), CGSize(width: 1194, height: 834), CGSize(width: 1376, height: 1032)])
    func aLandscapeIPadKeepsItsSidebar(size: CGSize) {
        #expect(!BoardSidebarPolicy.collapsesSidebar(showsBoard: true, size: size))
    }

    /// L'iPad en portrait a déjà sa disposition en hauteur, vérifiée sur
    /// appareil : la règle ne la touche pas, bien que plus étroite que le seuil.
    @Test(arguments: [CGSize(width: 744, height: 1133), CGSize(width: 834, height: 1194), CGSize(width: 1024, height: 1366)])
    func aPortraitIPadKeepsItsSidebar(size: CGSize) {
        #expect(!BoardSidebarPolicy.collapsesSidebar(showsBoard: true, size: size))
    }

    /// Avant toute mesure, on ne décide rien.
    @Test func nothingCollapsesBeforeAMeasure() {
        #expect(!BoardSidebarPolicy.collapsesSidebar(showsBoard: true, size: nil))
        #expect(!BoardSidebarPolicy.collapsesSidebar(showsBoard: true, size: .zero))
    }

    /// Le seuil, écrit noir sur blanc : sous le plus étroit des iPad en
    /// paysage, au-dessus de la bascule vers la disposition iPhone.
    @Test func theThresholdSitsBetweenTheTwoRules() {
        #expect(BoardSidebarPolicy.minimumWidth == 1024)
        #expect(BoardSidebarPolicy.minimumWidth > NarrowWindowLayout.regularMinimumWidth)
        #expect(BoardSidebarPolicy.minimumWidth < 1133)
    }

    /// Seul l'écran VISIBLE compte : une partie recouverte par son analyse
    /// disparaît, l'analyse apparaît, et la barre reste repliée.
    @Test func presenceFollowsTheVisibleScreens() {
        let presence = BoardScreenPresence()
        let game = UUID(), analysis = UUID()
        presence.appeared(game)
        #expect(presence.showsBoard)
        presence.appeared(analysis)
        presence.disappeared(game)
        #expect(presence.showsBoard)
        presence.disappeared(analysis)
        #expect(!presence.showsBoard)
    }
}
