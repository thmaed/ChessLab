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
}
