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
        engineName: String = "Ordinateur",
        opponentProfileID: String? = nil,
        in context: ModelContext
    ) {
        let record = GameRecord()
        record.modeRaw = GameRecordMode.vsEngine.rawValue
        // Le PGN rangé porte les mêmes en-têtes que celui qu'on partage :
        // c'est lui que rouvre l'analyse, et c'est lui qu'on réexporte depuis
        // la bibliothèque.
        record.pgn = PGNExport.pgn(
            for: game,
            metadata: .vsEngine(
                userColor: userColor,
                // Le nom AFFICHÉ dans les balises — « Ordinateur » est une
                // sentinelle française, qu'on ne sert pas telle quelle à un
                // lecteur anglophone.
                engineName: PlayerName.display(engineName, fallback: PlayerName.computer),
                result: outcome.pgnResult
            )
        )
        record.resultRaw = outcome.pgnResult
        record.outcomeReasonRaw = outcome.reason.storageLabel
        record.whiteName = userColor == .white ? "Vous" : engineName
        record.blackName = userColor == .black ? "Vous" : engineName
        record.engineColorRaw = engineColor.rawValue
        record.engineEloApprox = Int(strength.sliderValue)
        record.opponentProfileID = opponentProfileID
        record.moveCount = GameRecord.plyCount(of: game)
        // Empreinte canonique : c'est par elle que l'analyse retrouvera
        // cette partie pour y déposer son bilan chiffré.
        record.analysisKey = AnalysisEvalStore.key(for: game)
        context.insert(record)
        PersistenceLog.save(context)
    }

    /// Le PGN d'une partie rangée, COMPLÉTÉ par ce que l'enregistrement sait.
    ///
    /// Les parties jouées avant le 28/09/2026 ont été rangées sans aucune
    /// balise : leurs joueurs, leur date et leur résultat ne vivaient que dans
    /// les colonnes du modèle. Rouvertes puis repartagées, elles ressortaient
    /// donc nues — le défaut que le testeur signalait, pour tout ce qu'il
    /// avait déjà joué.
    ///
    /// Prudence volontaire : on ne recompose que les PGN SANS section de
    /// balises, et jamais une partie importée. Repasser un PGN externe par le
    /// lecteur puis le resérialiser lui coûterait ses commentaires et ses
    /// variantes — on lui préfère son texte d'origine, intact.
    static func analysablePGN(of record: GameRecord) -> String? {
        guard let pgn = record.pgn, !pgn.isEmpty else { return nil }
        guard record.mode != .imported, !pgn.contains("[") else { return pgn }
        guard let game = PGNLoader.game(from: pgn) else { return pgn }
        let event = record.mode == .vsEngine
            ? LocalizationController.string("Contre l'ordinateur")
            : LocalizationController.string("Deux joueurs")
        return PGNExport.pgn(
            for: game,
            metadata: PGNExport.Metadata(
                event: event,
                date: record.playedAt,
                white: PlayerName.display(record.whiteName, fallback: PlayerName.white),
                black: PlayerName.display(record.blackName, fallback: PlayerName.black),
                result: record.resultRaw
            )
        )
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
    nonisolated static func signature(ofPGN pgn: String) -> String? {
        guard let game = PGNLoader.game(from: pgn) else { return nil }
        let moves = movetext(of: pgn)
        guard !moves.isEmpty else { return nil }
        return "\(normalizedName(game.tags.white))|\(normalizedName(game.tags.black))|\(moves)"
    }

    /// Nom de joueur réduit à ce qui compte pour reconnaître une partie.
    ///
    /// « ? » vaut ABSENT : c'est ce que le standard écrit pour un joueur
    /// inconnu, et c'est ce que notre propre export pose depuis qu'il émet les
    /// sept balises (27/09/2026). Sans cette équivalence, une partie rangée
    /// avant ce changement — donc sans balises — puis réimportée après aurait
    /// deux signatures différentes, et reviendrait en double.
    private nonisolated static func normalizedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed == "?" ? "" : trimmed
    }

    /// Suite de coups NORMALISÉE : balises, commentaires, variantes, numéros
    /// de coup et résultat retirés, espaces réduits. C'est ce qui reste
    /// identique d'un export à l'autre.
    nonisolated static func movetext(of pgn: String) -> String {
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
    /// Import en TÂCHE DE FOND (bug18aout §7, arbitré le 18/08) : le parsing
    /// et la déduplication d'une grosse base (des milliers de parties)
    /// gelaient le fil principal plusieurs secondes. Ici : contexte propre
    /// sur le même conteneur, travail détaché, progression relayée pour
    /// l'indicateur — l'interface reste vivante pendant tout l'import.
    nonisolated static func importPGNCollection(
        text: String, container: ModelContainer,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> ImportOutcome {
        await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            return importPGNCollection(text: text, in: context, onProgress: onProgress)
        }.value
    }

    nonisolated static func importPGNCollection(
        text: String, in context: ModelContext,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) -> ImportOutcome {
        let blocks = PGNSanitizer.splitIntoGames(text)
        var imported = 0
        var skipped = 0
        var duplicates = 0

        // Signatures DÉJÀ en bibliothèque, calculées une seule fois. Le même
        // ensemble reçoit ensuite celles du lot en cours : réimporter un
        // fichier qui contient deux fois la même partie n'en range qu'une.
        let existing = (try? context.fetch(FetchDescriptor<GameRecord>())) ?? []
        var seen = Set(existing.compactMap { $0.pgn.flatMap(Self.signature(ofPGN:)) })

        for (blockIndex, block) in blocks.enumerated() {
            onProgress?(blockIndex + 1, blocks.count)
            let candidate = PGNSanitizer.sanitize(block)
            // PGNLoader et non `Game(pgn:)` : ChessKit refuse des parties
            // légales (prise en passant, roque avec échec) et elles seraient
            // comptées « illisibles » puis perdues sans bruit.
            guard !candidate.isEmpty, let game = PGNLoader.game(from: candidate) else {
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
            // Empreinte canonique : c'est par elle que l'analyse retrouvera
            // cette partie pour y déposer son bilan chiffré.
            record.analysisKey = AnalysisEvalStore.key(for: game)
            context.insert(record)
            imported += 1
        }
        // Variante de fond : l'import peut tourner hors du MainActor.
        if imported > 0 { PersistenceLog.saveInBackground(context) }
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
        PersistenceLog.save(context)
        return records.count
    }

    /// Décode une date PGN « YYYY.MM.DD » (les champs inconnus valent « ?? »).
    /// Retourne `nil` si l'année n'est pas exploitable — l'appelant retombe
    /// alors sur la date du jour.
    private nonisolated static func parsePGNDate(_ raw: String) -> Date? {
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
        record.pgn = PGNExport.pgn(
            for: game,
            metadata: .twoPlayer(
                whiteName: whiteName, blackName: blackName, result: outcome.pgnResult
            )
        )
        record.resultRaw = outcome.pgnResult
        record.outcomeReasonRaw = outcome.reason.storageLabel
        record.whiteName = whiteName
        record.blackName = blackName
        record.moveCount = GameRecord.plyCount(of: game)
        // Empreinte canonique : c'est par elle que l'analyse retrouvera
        // cette partie pour y déposer son bilan chiffré.
        record.analysisKey = AnalysisEvalStore.key(for: game)
        context.insert(record)
        PersistenceLog.save(context)
    }
}
