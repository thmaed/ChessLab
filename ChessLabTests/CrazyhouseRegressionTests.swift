import ChessKit
import Testing
@testable import ChessLab

/// Les cinq défauts trouvés à la revue du 29/08/2026, chacun avec le test
/// qui l'aurait attrapé.
@Suite(.serialized)
@MainActor
struct CrazyhouseRegressionTests {

    private func game(_ color: PlayerColorChoice = .white) -> EngineLegalityPlayViewModel {
        var settings = FairyVariantSettings()
        settings.colorChoice = color.rawValue
        settings.showEvalBar = false
        return EngineLegalityPlayViewModel(variant: .crazyhouse, settings: settings)
    }

    // MARK: #1 — la FEN du moteur corrompait le plateau

    @Test("Une réserve NON vide ne corrompt plus la dernière rangée")
    func pocketDoesNotCorruptTheBoard() {
        let raw = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR[Pp] w KQkq - 0 1"
        // Sans assainissement, ChessKit empilait « P » et « p » sur h1 : la
        // tour blanche y devenait un pion NOIR, et le plateau comptait 34
        // pièces. Mesuré avant correction.
        let corrupted = Position(fen: raw)!
        #expect(corrupted.pieces.count == 34, "témoin : la FEN brute EST mal lue")
        #expect(corrupted.piece(at: Square("h1"))?.color == .black, "témoin")

        let clean = Position(fen: CrazyhouseFEN.forChessKit(raw))!
        #expect(clean.pieces.count == 32)
        #expect(clean.piece(at: Square("h1"))?.kind == .rook)
        #expect(clean.piece(at: Square("h1"))?.color == .white)
    }

    @Test("La marque de promotion du moteur ne décale plus la rangée")
    func promotionMarkerIsStripped() {
        let raw = "rnbQ~kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR[Pp] b KQkq - 0 5"
        let clean = Position(fen: CrazyhouseFEN.forChessKit(raw))!
        #expect(clean.piece(at: Square("e8"))?.kind == .king, "le roi noir reste en e8")
        #expect(clean.piece(at: Square("h8"))?.kind == .rook)
        #expect(clean.piece(at: Square("d8"))?.kind == .queen, "la dame promue est bien là")
    }

    @Test("Le plateau reste juste quand les DEUX camps ont une réserve")
    func boardStaysCorrectWithBothPockets() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game()
            vm.start()
            try await Task.sleep(for: .seconds(1))
            try #require(!vm.isEngineUnavailable)

            // 1.e4 d5 2.exd5 Dxd5 : chacun tient un pion.
            for uci in ["e2e4", "d7d5", "e4d5", "d8d5"] { await vm.forceMove(uci: uci) }
            #expect(!vm.userPocket.isEmpty && !vm.enginePocket.isEmpty, "les deux réserves sont garnies")

            let board = vm.displayedBoard.position
            #expect(board.pieces.count == 30, "32 pièces moins les deux prises")
            #expect(board.piece(at: Square("h1"))?.kind == .rook, "la tour h1 n'a pas été masquée")
            #expect(board.piece(at: Square("h1"))?.color == .white)
            #expect(board.piece(at: Square("h8"))?.kind == .rook)
            vm.handleViewDisappear()
        }
    }

    // MARK: #2 — les poses désynchronisaient le journal des coups

    @Test("Une pose occupe sa place dans le journal, comme tout coup")
    func dropKeepsMoveLogAligned() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game()
            vm.start()
            try await Task.sleep(for: .seconds(1))
            try #require(!vm.isEngineUnavailable)

            for uci in ["e2e4", "d7d5", "e4d5", "d8d5"] { await vm.forceMove(uci: uci) }
            vm.selectPocketPiece(.pawn)
            let target = try #require(vm.legalTargetSquares.first)
            await vm.forceMove(uci: "P@" + target.notation)

            // Sans entrée pour la pose, `moveLog` prenait du retard sur
            // `uciLog` — et la consultation plantait plus tard sur un indice
            // hors bornes.
            #expect(vm.moveLog.count == vm.uciLog.count,
                    "journal des Move (\(vm.moveLog.count)) et des coups (\(vm.uciLog.count)) alignés")
            #expect(vm.displayedLastMove?.end == target, "la case de pose est bien surlignée")
            vm.handleViewDisappear()
        }
    }

    // MARK: #3 — revenir sur une partie la remettait à zéro

    @Test("Revenir sur une partie en cours ne l'efface pas")
    func resumingDoesNotResetTheGame() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game()
            vm.start()
            try await Task.sleep(for: .seconds(1))
            try #require(!vm.isEngineUnavailable)

            for uci in ["e2e4", "d7d5", "e4d5", "d8d5"] { await vm.forceMove(uci: uci) }
            let pliesBefore = vm.totalPlies
            let fenBefore = vm.displayedBoard.position.fen
            #expect(pliesBefore == 4)

            // On quitte l'écran et on y revient : `start()` est rappelé sur
            // le MÊME view model, que SessionStore conserve.
            vm.handleViewDisappear()
            try await Task.sleep(for: .seconds(1))
            vm.start()
            try await Task.sleep(for: .seconds(2))

            #expect(vm.totalPlies == pliesBefore, "les coups joués doivent tenir")
            #expect(vm.displayedBoard.position.fen == fenBefore, "le plateau ne doit pas revenir au départ")
            #expect(vm.fenLog.count == pliesBefore + 1, "un FEN par ply, plus le départ")

            // La consultation d'un coup passé plantait sur un fenLog remis à
            // un seul élément.
            vm.review(toPly: 2)
            #expect(vm.isReviewing)
            vm.handleViewDisappear()
        }
    }

    // MARK: #4 — la réserve ne suivait pas une reprise

    @Test("Reprendre à un coup passé remet la réserve à jour")
    func takebackRefreshesThePocket() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game()
            vm.start()
            try await Task.sleep(for: .seconds(1))
            try #require(!vm.isEngineUnavailable)

            for uci in ["e2e4", "d7d5", "e4d5"] { await vm.forceMove(uci: uci) }
            #expect(!vm.userPocket.isEmpty, "après exd5, les Blancs tiennent un pion")

            // On revient AVANT la prise : la réserve doit se vider.
            vm.review(toPly: 2)
            vm.resumeFromReview()
            try await Task.sleep(for: .seconds(2))
            #expect(vm.userPocket.isEmpty,
                    "la prise a été annulée : plus rien en main, or la bande restait garnie")
            vm.handleViewDisappear()
        }
    }
}
