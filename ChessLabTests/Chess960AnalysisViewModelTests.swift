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
        #expect(vm.displayedPly == 7, "s'ouvre sur la FIN de la partie, pas le début")
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

    @Test("L'export reconstruit un PGN rejouable par le même parseur")
    func exportRoundTripsThroughTheParser() throws {
        let pgn = classicalGamePGN(moves: ["e2e4", "e7e5"])
        let vm = try #require(Chess960AnalysisViewModel(pgn: pgn))
        let reexported = vm.exportedPGN
        let reparsed = try #require(Chess960PGNParser.parse(reexported))
        #expect(reparsed.moves.map(\.san) == vm.sanLog)
    }
}
