import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Le bilan par personnage : groupé par identifiant, dans l'ordre de la
/// galerie, avec le plus haut niveau battu ; les parties en mode Niveau Elo
/// n'y figurent pas.
@MainActor
struct ProgressionOpponentTests {

    private func engineGame(result: String, userColor: Piece.Color, elo: Int, opponent: String?) -> GameRecord {
        let record = GameRecord()
        record.modeRaw = GameRecordMode.vsEngine.rawValue
        record.resultRaw = result
        record.engineColorRaw = userColor.opposite.rawValue
        record.whiteName = userColor == .white ? "Vous" : "Ordinateur"
        record.blackName = userColor == .black ? "Vous" : "Ordinateur"
        record.engineEloApprox = elo
        record.opponentProfileID = opponent
        return record
    }

    @Test func gamesAreGroupedByCharacterInGalleryOrder() {
        let games = [
            engineGame(result: "1-0", userColor: .white, elo: 1200, opponent: "pablo"),
            engineGame(result: "0-1", userColor: .white, elo: 1300, opponent: "pablo"),
            engineGame(result: "1-0", userColor: .black, elo: 1500, opponent: "lea"),   // défaite
            engineGame(result: "1/2-1/2", userColor: .white, elo: 1500, opponent: "lea"),
            engineGame(result: "1-0", userColor: .white, elo: 1400, opponent: nil),      // mode Elo
        ]
        let summary = ProgressionSummary.compute(games: games, puzzles: [])
        #expect(summary.engineGames == 5)
        #expect(summary.engineByOpponent.map(\.profileID) == ["lea", "pablo"], "ordre de la galerie")
        let pablo = summary.engineByOpponent.first { $0.profileID == "pablo" }!
        #expect(pablo.wins == 1 && pablo.draws == 0 && pablo.losses == 1)
        #expect(pablo.bestWinLevel == 1200)
        let lea = summary.engineByOpponent.first { $0.profileID == "lea" }!
        #expect(lea.wins == 0 && lea.draws == 1 && lea.losses == 1)
        #expect(lea.bestWinLevel == nil)
    }

    @Test func noCharacterGamesMeansNoSection() {
        let summary = ProgressionSummary.compute(games: [engineGame(result: "1-0", userColor: .white, elo: 1400, opponent: nil)], puzzles: [])
        #expect(summary.engineByOpponent.isEmpty)
    }
}
