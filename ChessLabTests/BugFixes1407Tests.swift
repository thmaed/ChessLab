import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Tests de NON-RÉGRESSION des bugs de la revue du 14/07/2026
/// (`bug-1407.md`). Un test par bug testable unitairement — les bugs
/// purement moteur/concurrence (n°3, 5, 9, 10, 11, 12, 13) demandent une
/// injection au-dessus d'``EngineController``, prévue en phase Qualité.
///
/// Aucun de ces tests ne démarre Stockfish : les view models retenus sont
/// soit sans moteur, soit dans un état où le moteur n'est jamais créé.
@MainActor
struct BugFixes1407Tests {

    private static func inMemoryContext() throws -> ModelContext {
        let schema = Schema([GameRecord.self, Puzzle.self])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: Bug n°1 — le drag & drop permet de jouer les pièces de l'adversaire

    /// Le cœur du bug : ChessKit accepte le coup (ni `canMove` ni
    /// `legalMoves` ne consultent le trait), c'est donc bien à l'app de
    /// refuser. Ce test échouerait sans le garde de couleur.
    @Test func chessKitItselfAllowsMovingThePieceOfTheSideNotToMove() {
        var board = Board(position: .standard)
        #expect(board.position.sideToMove == .white)
        #expect(board.canMove(pieceAt: Square("e7"), to: Square("e5")))
        #expect(board.move(pieceAt: Square("e7"), to: Square("e5")) != nil)
    }

    @Test func twoPlayerRefusesDraggingAPieceOfTheSideNotToMove() throws {
        let viewModel = TwoPlayerViewModel(settings: .default, modelContext: try Self.inMemoryContext())

        // Trait aux blancs : glisser un pion NOIR ne doit rien jouer.
        viewModel.attemptUserMove(from: Square("e7"), to: Square("e5"))

        #expect(viewModel.moveLog.isEmpty)
        #expect(viewModel.board.position.sideToMove == .white)
        #expect(viewModel.board.position.fen == Position.standard.fen)
    }

    @Test func twoPlayerStillAcceptsAMoveOfTheSideToMove() throws {
        let viewModel = TwoPlayerViewModel(settings: .default, modelContext: try Self.inMemoryContext())

        viewModel.attemptUserMove(from: Square("e2"), to: Square("e4"))

        #expect(viewModel.moveLog.count == 1)
        #expect(viewModel.board.position.sideToMove == .black)
    }

    /// Sans le garde, le coup adverse était accepté ET le trait basculait :
    /// deux coups de la même couleur d'affilée devenaient possibles.
    @Test func twoPlayerKeepsColorsAlternatingAfterAWrongColourDrag() throws {
        let viewModel = TwoPlayerViewModel(settings: .default, modelContext: try Self.inMemoryContext())

        viewModel.attemptUserMove(from: Square("e2"), to: Square("e4"))
        viewModel.attemptUserMove(from: Square("d2"), to: Square("d4")) // 2e coup BLANC : refusé

        #expect(viewModel.moveLog.count == 1)
        #expect(viewModel.board.position.sideToMove == .black)
    }

    // MARK: Bug n°19 — même garde dans les modes d'entraînement

    @Test func openingLineTrainingIgnoresADragOfTheOpponentPiece() throws {
        let entry = OpeningLibraryEntry(
            family: "Test", category: "C",
            pgn: "1. e4 1... e5 2. Nf3", hasBlack: true
        )
        let viewModel = try #require(OpeningLineTrainingViewModel(entry: entry, color: .white))

        // Pièce noire alors que c'est aux blancs : ne doit PAS coûter un essai.
        viewModel.attemptMove(from: Square("e7"), to: Square("e5"))

        #expect(viewModel.attemptsRemaining == 3)
        #expect(viewModel.currentStep == 0)
    }

    // MARK: Bug n°4 — partie reprise : la pendule doit repartir

    @Test func resumedTwoPlayerGameRestartsTheClockForTheSideToMove() throws {
        var settings = TwoPlayerGameSettings.default
        settings.timeControlID = TimeControl.blitz5_0.id
        let autosave = TwoPlayerGameAutosave(
            settings: settings, moveLANs: ["e2e4"],
            whiteRemaining: 200, blackRemaining: 180, savedAt: Date()
        )

        let viewModel = try #require(
            TwoPlayerViewModel(resuming: autosave, modelContext: try Self.inMemoryContext())
        )

        let clock = try #require(viewModel.clock)
        #expect(clock.isRunning)
        #expect(viewModel.board.position.sideToMove == .black)
        // Aucun incrément crédité à la reprise (le coup n'est pas encore joué).
        #expect(clock.remaining(for: .white) == 200)
        #expect(clock.remaining(for: .black) == 180)
    }

    // MARK: Bug n°6 — un LAN inapplicable rend la sauvegarde irrécupérable

    @Test func resumingFailsOnAnUnapplicableMoveRatherThanSkippingIt() throws {
        // 2e coup illégal : sauté par l'ancien code, tous les coups suivants
        // s'appliquaient alors à une position fausse.
        let autosave = TwoPlayerGameAutosave(
            settings: .default, moveLANs: ["e2e4", "a1a8", "e7e5"],
            whiteRemaining: nil, blackRemaining: nil, savedAt: Date()
        )

        #expect(TwoPlayerViewModel(resuming: autosave, modelContext: try Self.inMemoryContext()) == nil)
    }

    @Test func resumingFailsOnATruncatedMove() throws {
        let autosave = TwoPlayerGameAutosave(
            settings: .default, moveLANs: ["e2e4", "e7"],
            whiteRemaining: nil, blackRemaining: nil, savedAt: Date()
        )

        #expect(TwoPlayerViewModel(resuming: autosave, modelContext: try Self.inMemoryContext()) == nil)
    }

    @Test func resumingSucceedsOnAValidMoveList() throws {
        let autosave = TwoPlayerGameAutosave(
            settings: .default, moveLANs: ["e2e4", "e7e5", "g1f3"],
            whiteRemaining: nil, blackRemaining: nil, savedAt: Date()
        )

        let viewModel = try #require(
            TwoPlayerViewModel(resuming: autosave, modelContext: try Self.inMemoryContext())
        )
        #expect(viewModel.moveLog.count == 3)
        #expect(viewModel.sanMoveList == ["e4", "e5", "Nf3"])
    }

    // MARK: Bug n°7 — position de départ déjà terminée

    /// La limite de ChessKit qui rend le bug possible : à l'init d'un
    /// `Board`, un mat du camp AU TRAIT n'est pas vu.
    @Test func chessKitDoesNotSeeCheckmateOfTheSideToMoveOnAFreshBoard() throws {
        // Mat du berger : les noirs sont mats et au trait.
        let fen = "r1bqkbnr/pppp1Qpp/2n5/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4"
        let position = try #require(Position(fen: fen))
        if case .active = Board(position: position).state {
            // Comportement attendu de ChessKit — c'est ce que l'app doit compenser.
        } else {
            Issue.record("ChessKit détecte désormais ce mat : la sonde miroir peut être simplifiée.")
        }
    }

    @Test func startingPositionOutcomeDetectsCheckmateOfTheSideToMove() throws {
        let fen = "r1bqkbnr/pppp1Qpp/2n5/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4"
        let position = try #require(Position(fen: fen))

        let outcome = try #require(GameOutcome.ofStartingPosition(position))
        #expect(outcome.winner == .white)
        #expect(outcome.reason == .checkmate)
    }

    @Test func startingPositionOutcomeDetectsStalemateOfTheSideToMove() throws {
        // Pat classique : les noirs au trait n'ont aucun coup légal.
        let position = try #require(Position(fen: "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"))

        let outcome = try #require(GameOutcome.ofStartingPosition(position))
        #expect(outcome.winner == nil)
        #expect(outcome.reason == .draw(.stalemate))
    }

    @Test func startingPositionOutcomeIsNilOnALivePosition() {
        #expect(GameOutcome.ofStartingPosition(.standard) == nil)
    }

    /// Un échec SANS mat ne doit surtout pas être pris pour une fin de partie.
    @Test func startingPositionOutcomeIsNilWhenSideToMoveIsMerelyInCheck() throws {
        let position = try #require(Position(fen: "rnbqkbnr/ppp2ppp/8/1B1pp3/4P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 3"))
        #expect(GameOutcome.ofStartingPosition(position) == nil)
    }

    /// Le mode Jouer ne doit plus démarrer une partie « morte » : l'écran
    /// affiche un résultat au lieu d'attendre un coup du moteur qui ne
    /// viendra jamais (`bestmove (none)`).
    @Test func playViewModelStartsAlreadyFinishedOnATerminalFEN() throws {
        var settings = PlayGameSettings.default
        settings.startFEN = "r1bqkbnr/pppp1Qpp/2n5/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4"

        let viewModel = PlayViewModel(settings: settings, modelContext: try Self.inMemoryContext())

        let outcome = try #require(viewModel.outcome)
        #expect(outcome.reason == .checkmate)
        #expect(outcome.winner == .white)
    }

    /// Le validateur refuse désormais un FEN déjà terminé (« ne JAMAIS
    /// envoyer un FEN illégal au moteur »).
    @Test func fenValidatorRejectsAPositionWithNoLegalMoveForTheSideToMove() {
        let errors = FENValidator.errors(in: "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
        #expect(errors.contains { $0.contains("aucun coup légal") })
    }

    @Test func fenValidatorStillAcceptsALivePosition() {
        #expect(FENValidator.isLegal(Position.standard.fen))
        #expect(FENValidator.isLegal("r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR b KQkq - 3 3"))
    }

    // MARK: Bug n°8 — PGN transmis à l'analyse depuis une partie à FEN personnalisé

    @Test func exportedPGNOfACustomStartCarriesSetUpAndFENTags() throws {
        let fen = "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1"
        let position = try #require(Position(fen: fen))
        var game = Game(startingWith: position)
        var board = Board(position: position)
        // `#require` ne peut pas envelopper un appel `mutating` (`board.move`).
        let move = board.move(pieceAt: Square("e2"), to: Square("e4"))
        let played = try #require(move)
        _ = game.make(move: played, from: game.startingIndex)

        let pgn = PGNExport.pgn(for: game)
        #expect(pgn.contains("[SetUp \"1\"]"))
        #expect(pgn.contains("[FEN \"\(fen)\"]"))

        // Le point du bug : rechargé, ce PGN redonne bien la MÊME partie —
        // `game.pgn` brut serait rejoué depuis la position standard.
        let reloaded = try Game(pgn: pgn)
        #expect(reloaded.positions[reloaded.startingIndex]?.fen == fen)
    }

    // MARK: Bug n°14 — alerte gaffe répétée dans un mat forcé déjà subi

    @Test func blunderAlertStaysSilentWhenTheMateWasAlreadyUnavoidable() {
        // Avant : on se faisait déjà mater (mate < 0, POV du joueur).
        // Après : l'adversaire a le mat (mate > 0 de son POV) — inévitable.
        let severity = PlayViewModel.blunderSeverity(
            before: (cp: -10_000, mate: -3), after: (cp: 10_000, mate: 2)
        )
        #expect(severity == nil)
    }

    @Test func blunderAlertStillFiresWhenTheMoveActuallyConcedesTheMate() {
        let severity = PlayViewModel.blunderSeverity(
            before: (cp: 20, mate: nil), after: (cp: 10_000, mate: 3)
        )
        #expect(severity == .allowsMate)
    }

    @Test func blunderAlertStillReportsAMissedMate() {
        let severity = PlayViewModel.blunderSeverity(
            before: (cp: 10_000, mate: 2), after: (cp: 30, mate: nil)
        )
        #expect(severity == .missedMate)
    }

    @Test func blunderAlertReportsACentipawnDropOnlyBeyondTheThreshold() {
        #expect(PlayViewModel.blunderSeverity(before: (cp: 50, mate: nil), after: (cp: 200, mate: nil)) == .centipawns(250))
        #expect(PlayViewModel.blunderSeverity(before: (cp: 50, mate: nil), after: (cp: 100, mate: nil)) == nil)
    }

    // MARK: Bug n°15 — flèches de solution : identifiants uniques

    @Test func hintMovesOfTheSameRankKeepDistinctIdentifiers() {
        let a = HintMove(rank: 1, from: Square("e2"), to: Square("e4"), strength: 1)
        let b = HintMove(rank: 1, from: Square("d2"), to: Square("d4"), strength: 1)
        #expect(a.id != b.id)
    }

    // MARK: Bug n°18 — PGN commençant par une ligne vide

    @Test func sanitizerKeepsTheTagsMovetextSeparatorDespiteALeadingBlankLine() {
        let pgn = "\n\n[Event \"Test\"]\n[Site \"?\"]\n\n1. e4 e5 2. Nf3 *"

        let cleaned = PGNSanitizer.collapseExtraBlankLines(pgn)

        // Le séparateur entre tags et coups doit survivre…
        #expect(cleaned.contains("[Site \"?\"]\n\n1. e4"))
        // …et le PGN doit redevenir lisible par ChessKit.
        #expect((try? Game(pgn: PGNSanitizer.sanitize(pgn))) != nil)
    }

    @Test func sanitizerStillCollapsesExtraBlankLinesInsideThePGN() {
        let pgn = "[Event \"Test\"]\n\n\n\n1. e4 e5 *"
        let cleaned = PGNSanitizer.collapseExtraBlankLines(pgn)
        #expect(!cleaned.contains("\n\n\n"))
        #expect((try? Game(pgn: PGNSanitizer.sanitize(pgn))) != nil)
    }
}
