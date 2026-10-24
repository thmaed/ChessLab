import ChessKit
import Testing
@testable import ChessLab

/// La consultation contre l'ordinateur avance et recule par coup COMPLET,
/// toujours vers une position où c'est au joueur de jouer.
struct ReviewStepperTests {

    @Test func whiteStepsByFullMoves() {
        // Joueur aux Blancs, partie normale : ses positions sont les paires.
        let stepper = ReviewStepper(totalPlies: 6, userMovesOnEvenPlies: true)
        #expect(stepper.previous(from: 6) == 4)
        #expect(stepper.previous(from: 4) == 2)
        #expect(stepper.previous(from: 2) == 0)
        #expect(stepper.previous(from: 0) == nil)
        #expect(stepper.next(from: 0) == 2)
        #expect(stepper.next(from: 4) == 6)
        #expect(stepper.next(from: 6) == nil)
    }

    @Test func blackStepsToOddPliesAndNeverToTheStart() {
        // Joueur aux Noirs : ses positions sont les impaires. La position de
        // départ (au moteur) n'est jamais atteinte par les flèches.
        let stepper = ReviewStepper(totalPlies: 6, userMovesOnEvenPlies: false)
        #expect(stepper.previous(from: 6) == 5)
        #expect(stepper.previous(from: 5) == 3)
        #expect(stepper.previous(from: 1) == nil)
        #expect(stepper.next(from: 1) == 3)
        #expect(stepper.next(from: 5) == 6, "plus de position du joueur : retour au direct")
    }

    /// Le moteur réfléchit : la position vive est la sienne. Reculer mène à
    /// la dernière position du joueur, un demi-coup plus tôt.
    @Test func fromALiveEnginePositionTheFirstStepBackIsHalfAMove() {
        let stepper = ReviewStepper(totalPlies: 5, userMovesOnEvenPlies: true)
        #expect(stepper.previous(from: 5) == 4)
        #expect(stepper.next(from: 4) == 5)
    }

    /// Une position consultée depuis la liste des coups peut être celle du
    /// moteur : les flèches ramènent aussitôt sur celles du joueur.
    @Test func fromAnEnginePositionTheArrowsRealign() {
        let stepper = ReviewStepper(totalPlies: 8, userMovesOnEvenPlies: true)
        #expect(stepper.previous(from: 3) == 2)
        #expect(stepper.next(from: 3) == 4)
    }

    // MARK: Variantes (24/10)

    /// Par la FEN : le joueur aux Noirs n'a le trait qu'aux positions « b ».
    @Test func theFenLogTellsWhoIsToMove() {
        let fens = [
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
            "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2",
            "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2",
            "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3",
        ]
        let stepper = ReviewStepper(totalPlies: 4, fenLog: fens, userColor: .black)
        #expect(stepper.previous(from: 4) == 3)
        #expect(stepper.previous(from: 3) == 1)
        #expect(stepper.previous(from: 1) == nil)
        #expect(stepper.next(from: 1) == 3)
        #expect(stepper.next(from: 3) == 4)
    }

    /// Coup Volé : les Blancs (joueur) dépensent un jeton et jouent DEUX coups
    /// d'affilée (demi-coups 2 et 3). La position du milieu du tour double est
    /// encore au joueur — la parité, elle, l'aurait donnée au moteur.
    @Test func aDoubleTurnKeepsBothPositionsForThePlayer() {
        let movers: [Piece.Color] = [.white, .black, .white, .white, .black, .white]
        let stepper = ReviewStepper(moverColors: movers, userColor: .white)
        #expect(stepper.previous(from: 6) == 5)
        #expect(stepper.previous(from: 5) == 3)
        #expect(stepper.previous(from: 3) == 2)
        #expect(stepper.previous(from: 2) == 0)
        #expect(stepper.next(from: 0) == 2)
        #expect(stepper.next(from: 2) == 3)
        #expect(stepper.next(from: 3) == 5)
        #expect(stepper.next(from: 5) == 6)
    }

    @Test func readsTheSideToMoveOfAVariantFen() {
        #expect(ReviewStepper.sideToMove(fen: "8/8/8/8/8/8/8/K6k b - - 0 1") == .black)
        #expect(ReviewStepper.sideToMove(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR[] w KQkq - 0 1") == .white)
        #expect(ReviewStepper.sideToMove(fen: "pas une fen") == nil)
    }
}

