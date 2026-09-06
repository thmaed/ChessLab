import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Les quatre cas du filet Stockfish derrière Maia — et surtout les cas où il
/// ne doit PAS intervenir : le filet est une promesse écrite dans l'Aide, pas
/// une rustine qui rend le personnage plus fort que son niveau.
@Suite struct SafetyNetTests {

    private let policy = SafetyNetPolicy()

    @Test func aShortMateIsPlayedOnlyFromTheMateLevel() {
        #expect(SafetyNet.overridesForMate(policy: policy, level: 1400, mateInMoves: 1))
        #expect(SafetyNet.overridesForMate(policy: policy, level: 2000, mateInMoves: 2))
        // En dessous du seuil, rater un mat fait partie du personnage.
        #expect(!SafetyNet.overridesForMate(policy: policy, level: 1399, mateInMoves: 1))
        // Un mat en trois n'est pas « court ».
        #expect(!SafetyNet.overridesForMate(policy: policy, level: 2400, mateInMoves: 3))
        // Se faire mater n'est pas un mat disponible.
        #expect(!SafetyNet.overridesForMate(policy: policy, level: 2400, mateInMoves: -1))
        #expect(!SafetyNet.overridesForMate(policy: policy, level: 2400, mateInMoves: nil))
    }

    @Test func aProfileMayDisableTheMateNet() {
        var noMate = policy
        noMate.mateFromLevel = nil
        #expect(!SafetyNet.overridesForMate(policy: noMate, level: 2400, mateInMoves: 1))
    }

    @Test func technicalEndgamesGoToStockfishFromTheEndgameLevel() {
        #expect(SafetyNet.overridesEndgame(policy: policy, level: 1600, pieceCount: 7))
        #expect(SafetyNet.overridesEndgame(policy: policy, level: 2200, pieceCount: 3))
        #expect(!SafetyNet.overridesEndgame(policy: policy, level: 1599, pieceCount: 3))
        #expect(!SafetyNet.overridesEndgame(policy: policy, level: 2200, pieceCount: 8))
    }

    @Test func repetitionIsAvoidedOnlyWhenClearlyWinning() {
        let repetition = Board.State.draw(reason: .repetition)
        let fifty = Board.State.draw(reason: .fiftyMoves)
        #expect(SafetyNet.overridesRepetition(policy: policy, stateAfterMove: repetition, moverCp: 350))
        #expect(SafetyNet.overridesRepetition(policy: policy, stateAfterMove: fifty, moverCp: 200))
        // Position égale ou perdue : répéter est un choix légitime.
        #expect(!SafetyNet.overridesRepetition(policy: policy, stateAfterMove: repetition, moverCp: 40))
        #expect(!SafetyNet.overridesRepetition(policy: policy, stateAfterMove: repetition, moverCp: -300))
        #expect(!SafetyNet.overridesRepetition(policy: policy, stateAfterMove: repetition, moverCp: nil))
        // Un coup ordinaire, ou un pat, ne déclenchent rien.
        #expect(!SafetyNet.overridesRepetition(policy: policy, stateAfterMove: .active, moverCp: 900))
        #expect(!SafetyNet.overridesRepetition(policy: policy, stateAfterMove: .draw(reason: .stalemate), moverCp: 900))
    }

    @Test func theOpponentProfileSurvivesARoundTripAndItsAbsence() throws {
        var settings = PlayGameSettings.default
        settings.opponentProfileID = "camille"
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(PlayGameSettings.self, from: data).opponentProfileID == "camille")
        // Réglages d'une version antérieure : aucune clé → mode Elo.
        let legacy = try #require("{\"eloSliderValue\": 1400}".data(using: .utf8))
        let decoded = try JSONDecoder().decode(PlayGameSettings.self, from: legacy)
        #expect(decoded.opponentProfileID == nil)
        #expect(decoded.opponentProfile == nil)
        #expect(decoded.eloSliderValue == 1400)
    }

    @Test func theGalleryResolvesItsProfiles() {
        #expect(OpponentProfile.named("maia") == .maia)
        #expect(OpponentProfile.named("inconnu") == nil)
        #expect(PlayGameSettings(opponentProfileID: "camille").opponentProfile == .maia)
        #expect(PlayGameSettings().opponentProfile == .maia, "une installation neuve rencontre Maia")
        #expect(PlayGameSettings(opponentProfileID: nil).opponentProfile == nil)
    }
}
