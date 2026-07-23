import ChessKit
import Foundation
import SwiftData

/// Point d'écriture unique vers la bibliothèque de parties (SwiftData) :
/// appelé une fois par partie terminée, quel que soit le mode.
@MainActor
enum GameLibraryService {
    static func recordVsEngineGame(
        game: Game,
        outcome: GameOutcome,
        userColor: Piece.Color,
        engineColor: Piece.Color,
        strength: EngineStrength,
        in context: ModelContext
    ) {
        let record = GameRecord()
        record.modeRaw = GameRecordMode.vsEngine.rawValue
        record.pgn = PGNExport.pgn(for: game)
        record.resultRaw = outcome.pgnResult
        record.outcomeReasonRaw = outcome.reason.storageLabel
        record.whiteName = userColor == .white ? "Vous" : "Stockfish"
        record.blackName = userColor == .black ? "Vous" : "Stockfish"
        record.engineColorRaw = engineColor.rawValue
        record.engineEloApprox = Int(strength.sliderValue)
        record.moveCount = GameRecord.plyCount(of: game)
        context.insert(record)
        try? context.save()
    }

    static func recordTwoHumanGame(
        game: Game,
        outcome: GameOutcome,
        whiteName: String,
        blackName: String,
        in context: ModelContext
    ) {
        let record = GameRecord()
        record.modeRaw = GameRecordMode.twoHuman.rawValue
        record.pgn = PGNExport.pgn(for: game)
        record.resultRaw = outcome.pgnResult
        record.outcomeReasonRaw = outcome.reason.storageLabel
        record.whiteName = whiteName
        record.blackName = blackName
        record.moveCount = GameRecord.plyCount(of: game)
        context.insert(record)
        try? context.save()
    }
}
