import Testing
@testable import ChessLab

/// La courbe d'évaluation, partagée par les quatre écrans d'analyse.
///
/// Ce qui se teste ici est le POINT, pas le dessin : une valeur hors bornes
/// ne fait pas planter Swift Charts, elle écrase silencieusement tout le
/// reste de la courbe — un mat annoncé à ±10 000 centipions aplatirait une
/// partie entière sur la ligne d'équilibre.
@Suite
struct EvalCurveTests {

    @Test("Les centipions deviennent des pions")
    func centipawnsBecomePawns() {
        #expect(EvalCurvePoint(id: 1, ply: 1, centipawnsWhite: 0).pawns == 0)
        #expect(EvalCurvePoint(id: 1, ply: 1, centipawnsWhite: 250).pawns == 2.5)
        #expect(EvalCurvePoint(id: 1, ply: 1, centipawnsWhite: -125).pawns == -1.25)
    }

    @Test("Un mat annoncé est borné à ±10, pas laissé à 10 000")
    func mateScoresAreClamped() {
        #expect(EvalCurvePoint(id: 1, ply: 1, centipawnsWhite: EngineScore.mateCentipawns).pawns == 10)
        #expect(EvalCurvePoint(id: 1, ply: 1, centipawnsWhite: -EngineScore.mateCentipawns).pawns == -10)
        // Et le plafond de Barricades/Duck Chess, plus modeste, l'est aussi.
        #expect(EvalCurvePoint(id: 1, ply: 1, centipawnsWhite: DuckChessEngine.winningCentipawns).pawns == 10)
    }

    @Test("L'identifiant reste celui qu'on lui donne — c'est lui qui pilote le saut")
    func identityIsPreserved() {
        let point = EvalCurvePoint(id: 7, ply: 7, centipawnsWhite: 30, quality: .blunder)
        #expect(point.id == 7)
        #expect(point.ply == 7)
        #expect(point.quality == .blunder)
    }

    /// Les pastilles de la courbe ne montrent que les moments qui MÉRITENT un
    /// coup d'œil : une courbe criblée de points ne dit plus où regarder.
    @Test("Seuls les moments critiques sont épinglés")
    func onlyCriticalMomentsArePinned() {
        let pinned = MoveQuality.allCases.filter(\.marksCriticalPhase)
        #expect(!pinned.isEmpty, "sans pastille, la courbe ne désigne plus rien")
        #expect(pinned.count < MoveQuality.allCases.count, "toutes épinglées, aucune ne ressort")
    }
}
