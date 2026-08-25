import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// La mécanique du Chess960 à deux humains — même patron que
/// ``Chess960PlayViewModelTests``, SANS moteur : ce view model n'en a aucun,
/// donc aucune de ces vérifications ne dépend d'un process externe — tout
/// est pur et rapide, contrairement au pendant « contre l'ordinateur ».
@MainActor
struct Chess960TwoPlayerViewModelTests {

    private static let classicalFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w HAha - 0 1"

    private func classicalGame() -> Chess960TwoPlayerViewModel {
        Chess960TwoPlayerViewModel(settings: Chess960TwoPlayerSettings(startFEN: Self.classicalFEN))
    }

    private func play(_ moves: [(from: String, to: String)], on vm: Chess960TwoPlayerViewModel) {
        for move in moves {
            let before = vm.totalPlies
            vm.attemptUserMove(from: Square(move.from), to: Square(move.to))
            #expect(vm.totalPlies == before + 1, "\(move.from)-\(move.to) refusé")
        }
    }

    // MARK: Les deux camps jouent, sans restriction de couleur

    @Test("Les deux camps peuvent jouer tour à tour, sans moteur ni restriction")
    func bothSidesCanPlayInTurn() {
        let vm = classicalGame()
        play([("e2", "e4"), ("e7", "e5"), ("g1", "f3")], on: vm)
        #expect(vm.sanLog == ["e4", "e5", "Nf3"])
    }

    /// Toucher une pièce du camp qui n'est PAS au trait ne doit rien faire —
    /// ni la sélectionner, ni permettre de la déplacer.
    @Test("Toucher une pièce hors tour ne la sélectionne pas")
    func touchingTheWrongSideSelectsNothing() {
        let vm = classicalGame()
        vm.selectSquare(Square("e7"))   // noir, mais les BLANCS sont au trait
        #expect(vm.legalTargetSquares.isEmpty)
        #expect(vm.selectedSquare == nil)
    }

    // MARK: Rotation face-à-face

    @Test("L'orientation suit le trait en mode face-à-face")
    func orientationFollowsTheMoverInFaceToFaceMode() {
        var settings = Chess960TwoPlayerSettings(startFEN: Self.classicalFEN)
        settings.rotationMode = .faceToFace
        let vm = Chess960TwoPlayerViewModel(settings: settings)
        #expect(vm.orientation == .white)
        vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
        #expect(vm.orientation == .black)
    }

    @Test("L'orientation reste fixe hors mode face-à-face")
    func orientationStaysFixedOutsideFaceToFaceMode() {
        var settings = Chess960TwoPlayerSettings(startFEN: Self.classicalFEN)
        settings.rotationMode = .fixed
        let vm = Chess960TwoPlayerViewModel(settings: settings)
        vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
        #expect(vm.orientation == .white)
    }

    // MARK: Fin de partie — abandon et nulle, PAR camp

    @Test("Un camp précis abandonne — l'autre gagne")
    func aSpecificSideResigns() {
        let vm = classicalGame()
        vm.resign(.white)
        #expect(vm.outcome == GameOutcome(winner: .black, reason: .resignation))
    }

    @Test("La nulle par accord n'a pas de vainqueur")
    func drawByAgreementHasNoWinner() {
        let vm = classicalGame()
        vm.agreeToDraw()
        #expect(vm.outcome == GameOutcome(winner: nil, reason: .drawByAgreement))
    }

    // MARK: Reprendre ici — même pattern du 24/08, sans moteur à garder

    @Test("Reprendre ici agit, s'annule, et respecte le garde de fin de partie")
    func resumeHereFollowsThe24AugustPattern() {
        let vm = classicalGame()
        play([("e2", "e4"), ("e7", "e5"), ("g1", "f3"), ("b8", "c6"), ("f1", "c4")], on: vm)

        vm.review(toPly: 2)
        #expect(vm.canResumeFromReview)
        vm.resumeFromReview()
        #expect(vm.totalPlies == 2)
        #expect(vm.resumeUndo?.discardedCount == 3)

        vm.cancelResumeFromReview()
        #expect(vm.totalPlies == 5)
        #expect(vm.sanLog.last == "Bc4")
        #expect(vm.resumeUndo == nil)

        // Le garde : une partie finie (abandon) ne se ressuscite pas.
        vm.review(toPly: 2)
        vm.resumeFromReview()
        vm.resign(.white)
        #expect(vm.outcome != nil)
        vm.cancelResumeFromReview()
        #expect(vm.outcome != nil, "l'abandon doit survivre à l'annulation")
        #expect(vm.totalPlies == 2)
    }

    // MARK: Surbrillance et roque

    @Test("Le geste de roque expose les cases des tours, quel que soit le camp")
    func castlingTargetsWorkForBothColors() {
        let vm = classicalGame()
        play([("e2", "e4"), ("e7", "e5"), ("g1", "f3"), ("b8", "c6"), ("f1", "c4"), ("f8", "c5")], on: vm)
        vm.selectSquare(Square("e1"))
        #expect(vm.legalTargetSquares.contains(Square("h1")))
    }

    // MARK: Export

    @Test("Le PGN porte les deux noms de joueurs et les tags de la variante")
    func pgnCarriesBothPlayerNamesAndVariantTags() {
        var settings = Chess960TwoPlayerSettings(startFEN: Self.classicalFEN)
        settings.whiteName = "Alice"
        settings.blackName = "Bob"
        let vm = Chess960TwoPlayerViewModel(settings: settings)
        vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
        let pgn = vm.exportedPGN
        #expect(pgn.contains("[White \"Alice\"]"))
        #expect(pgn.contains("[Black \"Bob\"]"))
        #expect(pgn.contains("[Variant \"Chess960\"]"))
    }
}
