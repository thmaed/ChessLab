import SwiftData
import SwiftUI
import XCTest

@testable import ChessLab

/// Le trou de couverture que le testeur a trouvé le 22/08 : **rien n'avait
/// jamais été mesuré sous 375 pt**.
///
/// Le Lot 3 du 13/08 le disait déjà — « Display Zoom (320 pt) : toujours pas
/// reproductible par argument de lancement, donc jamais mesuré » — et
/// `LayoutOverflowUITests.testNoOverflowOnPlayScreen`, qui couvre pourtant le
/// bon écran, ne tourne qu'à la largeur du simulateur du jour. Aucun
/// simulateur iOS 26 ne descend à 320 pt : l'iPhone SE 1re génération, seul
/// appareil de cette largeur, est refusé par le runtime (vérifié le 22/08).
///
/// D'où ce test **hors interface** : on héberge la vraie ``PlayControlBar`` —
/// pas une copie — et on lui propose les largeurs qu'aucun simulateur ne sait
/// produire. Même parti pris que `BoardGeometryTests` : le calcul est dans un
/// type, les chiffres exacts sont ici.
@MainActor
final class PlayControlBarLayoutTests: XCTestCase {

    /// iPhone 11 Pro en **Zoom d'affichage** — la configuration du testeur —
    /// et, accessoirement, la largeur d'un Slide Over sur iPad.
    private static let zoomedWidth: CGFloat = 320
    /// La plus étroite jamais mesurée avant ce jour (iPhone SE, 13 mini…).
    private static let standardWidth: CGFloat = 375
    /// Marge horizontale du conteneur de ``PlayView`` : 12 pt de chaque côté.
    private static let containerPadding: CGFloat = 24

    private static func usableWidth(screen: CGFloat) -> CGFloat {
        screen - containerPadding
    }

    /// Largeur que la barre RÉCLAME pour la place qu'on lui propose.
    private func measuredWidth(_ bar: PlayControlBar, proposing width: CGFloat) -> CGFloat {
        UIHostingController(rootView: bar)
            .sizeThatFits(in: CGSize(width: width, height: 200))
            .width
    }

    /// Partie en cours, rangée complète : c'est l'état de la capture reçue.
    private func liveBar() -> PlayControlBar {
        PlayControlBar(
            hasMoves: true, displayedPly: 4, totalPlies: 4,
            isReviewing: false, canResumeFromReview: false,
            undoableResumeCount: nil,
            showMoveList: true,
            hintsWanted: false, hintsEnabled: true,
            isFinished: false, isEngineThinking: false,
            onPrevious: {}, onNext: {}, onResumeHere: {}, onUndoResume: {}, onToggleHint: {},
            onShowMoveList: {}, onOfferDraw: {}, onResign: {}
        )
    }

    /// En consultation, « Coups joués » cède la place à la pastille
    /// « Reprendre ici » — le seul élément de la rangée dont la largeur
    /// dépend d'un texte traduit.
    private func reviewingBar() -> PlayControlBar {
        PlayControlBar(
            hasMoves: true, displayedPly: 2, totalPlies: 4,
            isReviewing: true, canResumeFromReview: true,
            undoableResumeCount: nil,
            showMoveList: true,
            hintsWanted: false, hintsEnabled: true,
            isFinished: false, isEngineThinking: false,
            onPrevious: {}, onNext: {}, onResumeHere: {}, onUndoResume: {}, onToggleHint: {},
            onShowMoveList: {}, onOfferDraw: {}, onResign: {}
        )
    }

    /// Juste APRÈS la reprise : la consultation est finie, mais la pastille
    /// « Annuler » occupe encore l'emplacement. Elle remplace « Coups joués »
    /// exactement comme le faisait « Reprendre ici » — sans quoi la rangée
    /// gagnerait une pastille et redéborderait sur un écran zoomé.
    private func undoOfferedBar() -> PlayControlBar {
        PlayControlBar(
            hasMoves: true, displayedPly: 2, totalPlies: 2,
            isReviewing: false, canResumeFromReview: false,
            undoableResumeCount: 6,
            showMoveList: true,
            hintsWanted: false, hintsEnabled: true,
            isFinished: false, isEngineThinking: false,
            onPrevious: {}, onNext: {}, onResumeHere: {}, onUndoResume: {}, onToggleHint: {},
            onShowMoveList: {}, onOfferDraw: {}, onResign: {}
        )
    }

    // MARK: Ce qui a cassé chez le testeur

    func testLiveBarFitsOnAZoomedIPhone() {
        let usable = Self.usableWidth(screen: Self.zoomedWidth)
        let width = measuredWidth(liveBar(), proposing: usable)
        XCTAssertLessThanOrEqual(
            width, usable,
            "La rangée réclame \(width) pt pour \(usable) disponibles : la pile de PlayView "
                + "devient plus large que l'écran et TOUT son contenu déborde, plateau compris."
        )
    }

    func testReviewingBarFitsOnAZoomedIPhone() {
        let usable = Self.usableWidth(screen: Self.zoomedWidth)
        let width = measuredWidth(reviewingBar(), proposing: usable)
        XCTAssertLessThanOrEqual(width, usable, "La pastille « Reprendre ici » repousse la rangée hors écran.")
    }

    /// L'annulation de reprise a ajouté une pastille à la rangée. Elle ne doit
    /// coûter aucune largeur : elle remplace « Coups joués », comme « Reprendre
    /// ici » juste avant elle.
    func testUndoOfferedBarFitsOnAZoomedIPhone() {
        let usable = Self.usableWidth(screen: Self.zoomedWidth)
        let width = measuredWidth(undoOfferedBar(), proposing: usable)
        XCTAssertLessThanOrEqual(width, usable, "La pastille « Annuler » repousse la rangée hors écran.")
    }

    // MARK: Non-régression sur les largeurs déjà couvertes

    func testBarFitsAtStandardWidth() {
        let usable = Self.usableWidth(screen: Self.standardWidth)
        XCTAssertLessThanOrEqual(measuredWidth(liveBar(), proposing: usable), usable)
        XCTAssertLessThanOrEqual(measuredWidth(reviewingBar(), proposing: usable), usable)
        XCTAssertLessThanOrEqual(measuredWidth(undoOfferedBar(), proposing: usable), usable)
    }

    // MARK: L'écran entier, pas seulement la barre

    /// Le garde-fou de demain : la barre n'est coupable que parce qu'elle
    /// était le seul enfant RIGIDE de la pile. Ce test mesure la pile complète
    /// — lignes joueurs, plateau, barre — pour que le prochain enfant trop
    /// large soit attrapé ici, et pas sur le téléphone d'un testeur.
    func testWholePlayScreenFitsOnAZoomedIPhone() throws {
        let container = try ModelContainer(
            for: GameRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = PlayViewModel(settings: PlayGameSettings(), modelContext: ModelContext(container))
        let screen = Self.zoomedWidth
        let host = UIHostingController(
            rootView: PlayView(viewModel: viewModel, onExit: {}, onAnalyze: { _ in })
        )
        let fitted = host.sizeThatFits(in: CGSize(width: screen, height: 693))
        XCTAssertLessThanOrEqual(
            fitted.width, screen,
            "L'écran Jouer réclame \(fitted.width) pt de large pour un écran de \(screen)."
        )
    }

    /// Même mesure sur *Deux joueurs*, l'autre écran de partie : sa barre
    /// porte des capsules à texte, qui se compriment — mais rien ne le
    /// prouvait, et la portée du défaut se constate, elle ne se suppose pas.
    func testWholeTwoPlayerScreenFitsOnAZoomedIPhone() throws {
        let container = try ModelContainer(
            for: GameRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = TwoPlayerViewModel(
            settings: TwoPlayerGameSettings(), modelContext: ModelContext(container)
        )
        let screen = Self.zoomedWidth
        let host = UIHostingController(
            rootView: TwoPlayerGameView(viewModel: viewModel, onExit: {}, onAnalyze: { _ in })
        )
        let fitted = host.sizeThatFits(in: CGSize(width: screen, height: 693))
        XCTAssertLessThanOrEqual(
            fitted.width, screen,
            "L'écran Deux joueurs réclame \(fitted.width) pt de large pour un écran de \(screen)."
        )
    }

    // MARK: Le chiffre lui-même

    /// Épingle la largeur **incompressible** de la rangée : les six boutons,
    /// et rien d'autre. C'est ce nombre qui décide de la largeur d'écran
    /// minimale supportée — le documenter en dur ici fait échouer le test le
    /// jour où un septième bouton arrive, plutôt que chez un utilisateur.
    func testIncompressibleWidthIsTheButtonsAlone() {
        let buttons = 6 * PlayControlBar.buttonSide
        XCTAssertEqual(measuredWidth(liveBar(), proposing: 0), buttons, accuracy: 0.5)
        XCTAssertLessThanOrEqual(
            buttons, Self.usableWidth(screen: Self.zoomedWidth),
            "Six boutons de \(PlayControlBar.buttonSide) pt ne tiennent plus dans un écran de 320 pt : "
                + "il faut en retirer un, pas rétrécir la cible tactile."
        )
    }
}
