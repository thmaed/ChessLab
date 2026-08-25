import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// `.serialized` dès l'origine — leçon du 25/08 (voir
/// ``Chess960PlayViewModelTests``) : Swift Testing lance une suite en
/// parallèle par défaut, et deux Stockfish concurrents se corrompent
/// mutuellement (`stdout` est un canal UCI global au processus).
@Suite(.serialized)
@MainActor
struct Chess960AnalysisViewModelTests {

    private func classicalGamePGN(moves: [String]) -> String {
        var settings = Chess960Settings()
        settings.positionNumber = 518
        let vm = Chess960PlayViewModel(settings: settings)
        for uci in moves { vm.forceMove(uci: uci) }
        return vm.exportedPGN
    }

    @Test("Se construit depuis un PGN exporté, position et journal identiques")
    func buildsFromAnExportedPGN() throws {
        let pgn = classicalGamePGN(moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "e1h1"])
        let vm = try #require(Chess960AnalysisViewModel(pgn: pgn))
        #expect(vm.sanLog == ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "O-O"])
        #expect(vm.totalPlies == 7)
        #expect(vm.displayedPly == 0, "s'ouvre sur le DÉBUT de la partie (25/08) — la classification part de là")
    }

    @Test("Un PGN sans position Chess960 ne construit rien")
    func nonChess960PGNFailsToConstruct() {
        #expect(Chess960AnalysisViewModel(pgn: "1. e4 e5 *") == nil)
    }

    @Test("La navigation rejoue la position, roque compris")
    func navigationReplaysThePosition() throws {
        let pgn = classicalGamePGN(moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "e1h1"])
        let vm = try #require(Chess960AnalysisViewModel(pgn: pgn))

        vm.review(toPly: 0)
        #expect(vm.displayedFEN == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w HAha - 0 1")

        vm.review(toPly: 7)
        #expect(vm.displayedGame.board.position.piece(at: Square("g1"))?.kind == .king,
                "après O-O, le roi doit être en g1")

        let last = try #require(vm.displayedLastMove)
        #expect(last.start == Square("e1") && last.end == Square("g1"),
                "surbrillance sur la case RÉELLE du roi, pas le dialecte roi-prend-tour")
    }

    @Test("L'analyse produit une évaluation et au moins une flèche")
    func analysisProducesAnEvalAndAtLeastOneArrow() async throws {
        let pgn = classicalGamePGN(moves: ["e2e4", "e7e5", "g1f3"])
        let vm = try #require(Chess960AnalysisViewModel(pgn: pgn))
        vm.start()

        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline, vm.currentEvalCp == nil && vm.currentEvalMate == nil {
            try await Task.sleep(for: .milliseconds(300))
        }
        #expect(vm.currentEvalCp != nil || vm.currentEvalMate != nil, "aucune évaluation produite")
        #expect(!vm.hintMoves.isEmpty, "aucune flèche produite")

        vm.handleViewDisappear()
    }

    // MARK: Classification (pastilles) — moteur RÉEL, 25/08 second lot

    /// Toute la ligne principale doit recevoir une pastille — même une
    /// partie qui se termine par un roque, où le coup ne se convertit pas en
    /// `Move` ChessKit (voir ``Chess960AnalysisViewModel/chessKitMove(for:board:)``).
    @Test("La classification couvre toute la ligne, roque compris")
    func classificationCoversTheWholeMainLine() async throws {
        let pgn = classicalGamePGN(moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "e1h1"])
        let vm = try #require(Chess960AnalysisViewModel(pgn: pgn))
        vm.start()

        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline, vm.moveQuality.count < vm.totalPlies {
            try await Task.sleep(for: .milliseconds(300))
        }
        #expect(vm.moveQuality.count == vm.totalPlies, "chaque coup doit recevoir une qualité, y compris O-O")
        #expect(vm.moveQuality[vm.totalPlies] != nil, "le roque final doit être classé")

        vm.review(toPly: vm.totalPlies)
        let badge = try #require(vm.qualityBadge)
        #expect(badge.square == Square("g1"), "la pastille du roque se pose sur la case RÉELLE du roi")

        vm.handleViewDisappear()
    }

    /// 1.e4 g6 2.Dh5?? — la dame se pose sur une case attaquée par le pion
    /// g6 (gxh5 la gagne), même hang de dame que ``Chess960PlayViewModelTests``.
    @Test("Une dame hors-jeu se classe en faute")
    func aHangingQueenIsClassifiedAsAFault() async throws {
        let pgn = classicalGamePGN(moves: ["e2e4", "g7g6", "d1h5"])
        let vm = try #require(Chess960AnalysisViewModel(pgn: pgn))
        vm.start()

        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline, vm.moveQuality[3] == nil {
            try await Task.sleep(for: .milliseconds(300))
        }
        let quality = try #require(vm.moveQuality[3])
        #expect(quality.isFault, "Dh5?? doit être signalé comme une faute (\(quality))")

        vm.handleViewDisappear()
    }

    /// Une classification déjà calculée se recharge du cache — sans repasser
    /// par le moteur — au lieu de tout recalculer à chaque ouverture.
    @Test("La classification se met en cache entre deux ouvertures")
    func classificationIsCachedAcrossOpenings() async throws {
        let pgn = classicalGamePGN(moves: ["e2e4", "e7e5"])
        let startFEN = try #require(Chess960PGNParser.parse(pgn)).startFEN
        let key = try #require(AnalysisEvalStore.key(startFEN: startFEN, lans: ["e2e4", "e7e5"]))
        defer { try? FileManager.default.removeItem(at: AnalysisEvalStore.fileURL(for: key)) }

        let first = try #require(Chess960AnalysisViewModel(pgn: pgn))
        first.start()
        let firstDeadline = Date().addingTimeInterval(60)
        while Date() < firstDeadline, first.moveQuality.count < first.totalPlies {
            try await Task.sleep(for: .milliseconds(300))
        }
        #expect(first.moveQuality.count == first.totalPlies)
        first.handleViewDisappear()

        let second = try #require(Chess960AnalysisViewModel(pgn: pgn))
        second.start()
        // Le cache se lit en un seul passage de la file sérielle : quelques
        // centaines de ms suffisent très largement, contre plusieurs
        // secondes pour une VRAIE analyse à deux coups.
        let cacheDeadline = Date().addingTimeInterval(5)
        while Date() < cacheDeadline, second.moveQuality.count < second.totalPlies {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(second.moveQuality.count == second.totalPlies, "le cache doit fournir la classification quasi instantanément")
        #expect(second.moveQuality == first.moveQuality)

        second.handleViewDisappear()
    }

    /// Une fois la ligne classée, se déplacer dans les coups déjà couverts
    /// ne doit PLUS repasser par le moteur — ``review(toPly:)`` doit montrer
    /// l'éval en cache DE FAÇON SYNCHRONE (pas de salve async à attendre).
    @Test("Naviguer dans une partie classée ne relance aucune analyse")
    func navigatingAClassifiedGameNeverReanalyzes() async throws {
        let pgn = classicalGamePGN(moves: ["e2e4", "e7e5", "g1f3", "b8c6"])
        let vm = try #require(Chess960AnalysisViewModel(pgn: pgn))
        vm.start()

        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline, vm.moveQuality.count < vm.totalPlies {
            try await Task.sleep(for: .milliseconds(300))
        }
        #expect(vm.moveQuality.count == vm.totalPlies)

        for ply in 0...vm.totalPlies {
            vm.review(toPly: ply)
            // Synchrone : si ceci retombait sur ``refreshAnalysis()``, l'éval
            // serait remise à `nil` en attendant une salve async, jamais
            // disponible tout de suite après l'appel.
            #expect(vm.currentEvalCp != nil || vm.currentEvalMate != nil,
                     "coup \(ply) : l'éval doit venir du cache, pas d'une nouvelle salve")
        }

        vm.handleViewDisappear()
    }

    @Test("L'export reconstruit un PGN rejouable par le même parseur")
    func exportRoundTripsThroughTheParser() throws {
        let pgn = classicalGamePGN(moves: ["e2e4", "e7e5"])
        let vm = try #require(Chess960AnalysisViewModel(pgn: pgn))
        let reexported = vm.exportedPGN
        let reparsed = try #require(Chess960PGNParser.parse(reexported))
        #expect(reparsed.moves.map(\.san) == vm.sanLog)
    }
}
