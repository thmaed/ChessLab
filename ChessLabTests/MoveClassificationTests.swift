import ChessKit
import Testing
@testable import ChessLab

struct MoveClassificationTests {

    // MARK: EvalConversion

    @Test func winPercentageIsFiftyAtEqualEval() {
        #expect(abs(EvalConversion.winPercentage(cp: 0) - 50) < 0.01)
    }

    @Test func winPercentageIncreasesWithAdvantage() {
        let equal = EvalConversion.winPercentage(cp: 0)
        let ahead = EvalConversion.winPercentage(cp: 300)
        let behind = EvalConversion.winPercentage(cp: -300)
        #expect(ahead > equal)
        #expect(behind < equal)
        // Symétrique autour de 50.
        #expect(abs((ahead - 50) - (50 - behind)) < 0.01)
    }

    @Test func winPercentageForMateIsExtreme() {
        #expect(EvalConversion.winPercentage(mate: 3) == 100)
        #expect(EvalConversion.winPercentage(mate: -2) == 0)
    }

    // MARK: MoveClassifier — l'échelle des fautes (seuils de perte)

    @Test func sevenPointsOfLossIsAnInaccuracy() {
        // Bande imprécision : 5 à 10 points de perte.
        #expect(MoveClassifier.classify(.init(winPercentBefore: 60, winPercentAfter: 53)) == .inaccuracy)
    }

    @Test func fifteenPointsOfLossIsAMistake() {
        // Bande erreur : 10 à 20 points.
        #expect(MoveClassifier.classify(.init(winPercentBefore: 60, winPercentAfter: 45)) == .mistake)
    }

    @Test func thirtyPointsOfLossIsABlunder() {
        // Gaffe : 20 points et plus.
        #expect(MoveClassifier.classify(.init(winPercentBefore: 60, winPercentAfter: 30)) == .blunder)
    }

    // MARK: MoveClassifier — l'échelle des bons coups

    @Test func aTinyLossIsExcellent() {
        #expect(MoveClassifier.classify(.init(winPercentBefore: 60, winPercentAfter: 59)) == .excellent)
    }

    @Test func aModestLossIsMerelyGood() {
        // 3 points de perte : sous le seuil d'imprécision (5), mais plus
        // « excellent » (< 2) — la catégorie intermédiaire existe pour ça.
        #expect(MoveClassifier.classify(.init(winPercentBefore: 60, winPercentAfter: 57)) == .good)
    }

    @Test func gainingWinPercentIsExcellentEvenWhenNotTheEngineChoice() {
        // Le joueur a GAGNÉ en probabilité : jamais une faute, même si le
        // moteur préférait un autre coup.
        #expect(MoveClassifier.classify(.init(winPercentBefore: 40, winPercentAfter: 70)) == .excellent)
    }

    @Test func theEngineFirstChoiceIsBest() {
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 60, winPercentAfter: 60, isBestMove: true, gapToSecondBest: 3
        )) == .best)
    }

    @Test func theOnlyGoodMoveIsGreat() {
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 60, winPercentAfter: 60, isBestMove: true, gapToSecondBest: 20
        )) == .great)
    }

    @Test func noGreatMoveInAnAlreadyWonPosition() {
        // À 90 %+, toutes les alternatives gagnent aussi : l'écart au 2e
        // choix ne mesure plus un mérite.
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 92, winPercentAfter: 92, isBestMove: true, gapToSecondBest: 25
        )) == .best)
    }

    @Test func noGreatMoveWithoutAKnownSecondChoice() {
        // Pas de 2e choix (mat, réseau de mat) : impossible de prouver que
        // le coup était « le seul », on s'en tient à « le meilleur ».
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 60, winPercentAfter: 60, isBestMove: true, gapToSecondBest: nil
        )) == .best)
    }

    // MARK: MoveClassifier — brillant

    @Test func aWinningOnlyMoveSacrificeIsBrilliant() {
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 55, winPercentAfter: 55,
            isBestMove: true, gapToSecondBest: 20, isSacrifice: true
        )) == .brilliant)
    }

    @Test func brilliantRequiresEachOfItsConditions() {
        // Pas le meilleur coup → la branche « brillant » n'est pas atteinte.
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 55, winPercentAfter: 55,
            isBestMove: false, gapToSecondBest: 20, isSacrifice: true
        )) != .brilliant)
        // Pas de sacrifice → grand coup, pas brillant.
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 55, winPercentAfter: 55,
            isBestMove: true, gapToSecondBest: 20, isSacrifice: false
        )) == .great)
        // Position perdante après le coup → sacrifice spéculatif, pas salué.
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 48, winPercentAfter: 45,
            isBestMove: true, gapToSecondBest: 20, isSacrifice: true
        )) != .brilliant)
        // Une bonne alternative existait → pas « le seul bon coup ».
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 55, winPercentAfter: 55,
            isBestMove: true, gapToSecondBest: 5, isSacrifice: true
        )) == .best)
        // Sacrifice IMMÉDIATEMENT repris sur sa case → simple simplification,
        // pas un brillant : reste un Grand coup.
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 55, winPercentAfter: 55,
            isBestMove: true, gapToSecondBest: 20, isSacrifice: true,
            sacrificeImmediatelyRecaptured: true
        )) == .great)
    }

    // MARK: MoveClassifier — occasion manquée

    @Test func squanderingAWinWithoutLosingItIsAMiss() {
        // Position gagnée (90 %), grosse perte (35 points)… mais toujours
        // au-dessus de 50 : la victoire est manquée, pas la partie. Et la
        // perte vient d'avoir raté une TACTIQUE (mat ou gain matériel).
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 90, winPercentAfter: 55, bestMoveWasTactical: true
        )) == .miss)
    }

    @Test func squanderingAWinWithoutATacticIsNotAMiss() {
        // Même relâchement d'une position gagnée, mais le meilleur coup n'était
        // PAS une tactique nette (dérive positionnelle) : c'est jugé sur
        // l'échelle ordinaire (35 points → gaffe), pas un « Miss ».
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 90, winPercentAfter: 55, bestMoveWasTactical: false
        )) == .blunder)
    }

    @Test func anAlreadyWonPositionWithACollapsingSecondChoiceIsGreat() {
        // Exception au « pas de Grand coup si déjà gagné » : le 2e choix
        // s'effondre de > 30 %, un seul coup gardait vraiment le gain.
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 92, winPercentAfter: 92, isBestMove: true, gapToSecondBest: 35
        )) == .great)
    }

    @Test func throwingAwayAWonPositionEntirelyIsABlunder() {
        // Même position gagnée, mais on passe SOUS l'égalité : gaffe.
        #expect(MoveClassifier.classify(.init(winPercentBefore: 90, winPercentAfter: 40)) == .blunder)
    }

    @Test func aBigLossFromANonWinningPositionIsNotAMiss() {
        // À 80 % on n'était pas encore « clairement gagnant » (< 85 %) : la
        // perte s'apprécie sur l'échelle ordinaire — 25 points, donc une
        // gaffe, PAS une occasion manquée (celle-ci exige une position déjà
        // gagnée). C'est ce qui la distingue du cas 90 % ci-dessus.
        #expect(MoveClassifier.classify(.init(winPercentBefore: 80, winPercentAfter: 55)) == .blunder)
    }

    // MARK: MoveClassifier — théorie et coup forcé

    @Test func aBookMoveIsBookWhateverTheEval() {
        // La théorie prime tout : même un coup que le moteur n'aime pas
        // reste un coup de théorie tant que la ligne est connue.
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 55, winPercentAfter: 48, isBook: true
        )) == .book)
    }

    @Test func aForcedMoveIsBestNeverBrilliant() {
        // Coup unique : trivialement le meilleur — et jamais « brillant »,
        // on ne sacrifie pas ce qu'on est forcé de donner.
        #expect(MoveClassifier.classify(.init(
            winPercentBefore: 50, winPercentAfter: 50,
            isBestMove: true, gapToSecondBest: nil, isSacrifice: true, isForced: true
        )) == .best)
    }

    // MARK: MoveClassifier — sacrifice

    @Test func involvesSacrificeDetectsUndefendedQueenCapture() {
        var board = Board(position: .standard)
        // 1. e4 e5 2. Qh5 Nc6 3. Qxf7+ — la dame ne prend qu'un pion mais
        // reste attaquable par le roi : perte nette si elle est reprise.
        #expect(board.move(pieceAt: Square("e2"), to: Square("e4")) != nil)
        #expect(board.move(pieceAt: Square("e7"), to: Square("e5")) != nil)
        #expect(board.move(pieceAt: Square("d1"), to: Square("h5")) != nil)
        #expect(board.move(pieceAt: Square("b8"), to: Square("c6")) != nil)
        guard let queenTakesF7 = board.move(pieceAt: Square("h5"), to: Square("f7")) else {
            Issue.record("Qxf7+ devrait être un coup légal")
            return
        }
        #expect(MoveClassifier.involvesSacrifice(move: queenTakesF7, boardAfterMove: board))
    }

    @Test func involvesSacrificeFalseForOrdinarySafeMove() {
        var board = Board(position: .standard)
        guard let pawnMove = board.move(pieceAt: Square("e2"), to: Square("e4")) else {
            Issue.record("e4 devrait être un coup légal")
            return
        }
        #expect(!MoveClassifier.involvesSacrifice(move: pawnMove, boardAfterMove: board))
    }

    // MARK: MoveQuality — contrat d'affichage et d'export

    @Test func everyQualityHasDistinctIdentity() {
        // Dix catégories, dix couleurs, dix libellés : aucune ne doit se
        // confondre avec une autre à l'écran.
        #expect(MoveQuality.allCases.count == 10)
        #expect(Set(MoveQuality.allCases.map(\.label)).count == 10)
    }

    @Test func onlyFaultsTriggerTheBetterMoveArrow() {
        #expect(MoveQuality.allCases.filter(\.isFault) == [.inaccuracy, .mistake, .miss, .blunder])
    }

    @Test func pgnExportOnlyUsesRealChessNotation() {
        // Les catégories sans signe NAG partent sans annotation — un PGN
        // constellé de symboles inventés ne serait lu nulle part.
        #expect(MoveQuality.brilliant.pgnAssessment == .brilliant)
        #expect(MoveQuality.great.pgnAssessment == .good)
        #expect(MoveQuality.miss.pgnAssessment == .mistake)
        #expect(MoveQuality.best.pgnAssessment == nil)
        #expect(MoveQuality.book.pgnAssessment == nil)
    }

    // MARK: AccuracyScore

    @Test func accuracyIsPerfectWithNoLoss() {
        #expect(AccuracyScore.accuracy(averageWinPercentLoss: 0) == 100)
    }

    @Test func accuracyDecreasesWithLoss() {
        let small = AccuracyScore.accuracy(averageWinPercentLoss: 2)
        let large = AccuracyScore.accuracy(averageWinPercentLoss: 20)
        #expect(small < 100)
        #expect(large < small)
        #expect(large >= 0)
    }
}
