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
        /// Blocs ILLISIBLES — un PGN qu'on n'a pas su décoder.
        var skipped: Int
        /// Parties déjà présentes, écartées sans être réimportées.
        var duplicates: Int = 0
    }

    /// Signature d'une partie, pour reconnaître un doublon.
    ///
    /// Fondée sur les COUPS et les deux joueurs, jamais sur le texte brut : le
    /// même PGN exporté par deux sites diffère par ses balises, ses
    /// commentaires et ses espaces, et une comparaison textuelle ne
    /// reconnaîtrait rien.
    ///
    /// Les joueurs entrent dans la signature à dessein. Les coups seuls
    /// suffiraient à reconnaître un ré-import, mais deux parties DIFFÉRENTES
    /// peuvent partager leur suite de coups (une nulle courte, une miniature
    /// connue) : les écarter à tort ferait perdre des parties à
    /// l'utilisateur, ce qui est bien pire que laisser passer un doublon.
    static func signature(ofPGN pgn: String) -> String? {
        guard let game = try? Game(pgn: PGNSanitizer.sanitize(pgn)) else { return nil }
        let moves = movetext(of: pgn)
        guard !moves.isEmpty else { return nil }
        let white = game.tags.white.trimmingCharacters(in: .whitespaces).lowercased()
        let black = game.tags.black.trimmingCharacters(in: .whitespaces).lowercased()
        return "\(white)|\(black)|\(moves)"
    }

    /// Suite de coups NORMALISÉE : balises, commentaires, variantes, numéros
    /// de coup et résultat retirés, espaces réduits. C'est ce qui reste
    /// identique d'un export à l'autre.
    static func movetext(of pgn: String) -> String {
        var text = pgn
        // Balises d'en-tête, une par ligne.
        text = text.replacingOccurrences(
            of: "\\[[^\\]]*\\]", with: " ", options: .regularExpression
        )
        // Commentaires { … } et variantes ( … ).
        text = text.replacingOccurrences(of: "\\{[^}]*\\}", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
        // Numéros de coup (« 12. », « 12... ») et annotations ($1, !, ?).
        text = text.replacingOccurrences(of: "\\d+\\.(\\.\\.)?", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\$\\d+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "[!?]+", with: "", options: .regularExpression)
        // Résultat final.
        for token in ["1-0", "0-1", "1/2-1/2", "*"] {
            text = text.replacingOccurrences(of: token, with: " ")
        }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
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
        var duplicates = 0

        // Signatures DÉJÀ en bibliothèque, calculées une seule fois. Le même
        // ensemble reçoit ensuite celles du lot en cours : réimporter un
        // fichier qui contient deux fois la même partie n'en range qu'une.
        let existing = (try? context.fetch(FetchDescriptor<GameRecord>())) ?? []
        var seen = Set(existing.compactMap { $0.pgn.flatMap(Self.signature(ofPGN:)) })

        for block in blocks {
            let candidate = PGNSanitizer.sanitize(block)
            guard !candidate.isEmpty, let game = try? Game(pgn: candidate) else {
                skipped += 1
                continue
            }
            if let signature = Self.signature(ofPGN: candidate) {
                guard seen.insert(signature).inserted else {
                    duplicates += 1
                    continue
                }
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
        return ImportOutcome(imported: imported, skipped: skipped, duplicates: duplicates)
    }

    /// Retire une partie de la bibliothèque. La suppression est définitive :
    /// c'est l'appelant qui demande confirmation.
    static func delete(_ record: GameRecord, in context: ModelContext) {
        delete([record], in: context)
    }

    /// Retire PLUSIEURS parties d'un coup, avec une seule sauvegarde.
    ///
    /// Une sauvegarde par partie sur une sélection de cinquante ferait
    /// cinquante écritures disque et autant de notifications à l'interface,
    /// qui se redessinerait à chaque suppression.
    @discardableResult
    static func delete(_ records: [GameRecord], in context: ModelContext) -> Int {
        guard !records.isEmpty else { return 0 }
        for record in records { context.delete(record) }
        try? context.save()
        return records.count
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
