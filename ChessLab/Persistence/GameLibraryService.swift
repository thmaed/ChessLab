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
        record.whiteName = userColor == .white ? "Vous" : "Ordinateur"
        record.blackName = userColor == .black ? "Vous" : "Ordinateur"
        record.engineColorRaw = engineColor.rawValue
        record.engineEloApprox = Int(strength.sliderValue)
        record.moveCount = GameRecord.plyCount(of: game)
        context.insert(record)
        try? context.save()
    }

    /// Résultat d'un import PGN multi-parties.
    struct ImportOutcome {
        var imported: Int
        var skipped: Int
    }

    /// Importe DANS la bibliothèque toutes les parties lisibles d'un texte PGN
    /// (une base, un export multi-chapitres…). Chaque partie devient un
    /// ``GameRecord`` en mode ``GameRecordMode/imported``, en récupérant ses
    /// en-têtes (joueurs, résultat, date) quand ils existent. Les blocs
    /// illisibles sont comptés dans `skipped` plutôt que de faire échouer tout
    /// l'import. Une seule sauvegarde à la fin.
    @discardableResult
    static func importPGNCollection(text: String, in context: ModelContext) -> ImportOutcome {
        let blocks = PGNSanitizer.splitIntoGames(text)
        var imported = 0
        var skipped = 0

        for block in blocks {
            let candidate = PGNSanitizer.sanitize(block)
            guard !candidate.isEmpty, let game = try? Game(pgn: candidate) else {
                skipped += 1
                continue
            }
            let record = GameRecord()
            record.modeRaw = GameRecordMode.imported.rawValue
            record.pgn = candidate
            let white = game.tags.white.trimmingCharacters(in: .whitespaces)
            let black = game.tags.black.trimmingCharacters(in: .whitespaces)
            record.whiteName = white.isEmpty ? nil : white
            record.blackName = black.isEmpty ? nil : black
            let result = game.tags.result.trimmingCharacters(in: .whitespaces)
            // « * » = partie sans résultat (en cours / inconnu) : on ne le
            // stocke pas comme un vrai résultat.
            record.resultRaw = (result.isEmpty || result == "*") ? nil : result
            record.playedAt = Self.parsePGNDate(game.tags.date) ?? Date()
            record.moveCount = GameRecord.plyCount(of: game)
            context.insert(record)
            imported += 1
        }
        if imported > 0 { try? context.save() }
        return ImportOutcome(imported: imported, skipped: skipped)
    }

    /// Décode une date PGN « YYYY.MM.DD » (les champs inconnus valent « ?? »).
    /// Retourne `nil` si l'année n'est pas exploitable — l'appelant retombe
    /// alors sur la date du jour.
    private static func parsePGNDate(_ raw: String) -> Date? {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 1, let year = Int(parts[0]), year > 1000 else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = parts.count > 1 ? Int(parts[1]) : nil
        components.day = parts.count > 2 ? Int(parts[2]) : nil
        return Calendar.current.date(from: components)
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
