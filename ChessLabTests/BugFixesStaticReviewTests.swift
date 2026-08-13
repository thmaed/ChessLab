import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Non-régression des bugs de la revue statique (`PROMPT-bugs.md`), pour les
/// points testables sans moteur ni simulateur.
///
/// Chaque test échoue avant sa correction.
struct BugFixesStaticReviewTests {

    // MARK: Lot 3 — le PGN exporté doit rester rechargeable

    /// Le cœur du bug : une session ouverte sur une FEN produisait un PGN sans
    /// `[SetUp]` ni `[FEN]`. Rechargé, il rejouait ses coups depuis la position
    /// STANDARD — donc une autre partie.
    @Test func exportedPGNCarriesTheStartingPositionOfAFENGame() throws {
        // Position d'étude quelconque, très loin de la position standard.
        let fen = "8/P6k/8/8/8/8/7K/8 w - - 0 1"
        let start = try #require(Position(fen: fen))
        var game = Game(startingWith: start)
        var board = Board(position: start)
        let played = board.move(pieceAt: Square("h2"), to: Square("h3"))
        let move = try #require(played)
        _ = game.make(move: move, from: game.startingIndex)

        let exported = PGNExport.pgn(for: game)

        #expect(exported.contains("[SetUp \"1\"]"))
        #expect(exported.contains("[FEN \"\(fen)\"]"))

        // Et surtout : rechargé, il retrouve SA position de départ.
        let reloaded = try Game(pgn: exported)
        let reloadedStart = try #require(reloaded.positions[reloaded.startingIndex])
        #expect(reloadedStart.fen == fen)
    }

    /// Une partie qui part de la position standard n'a rien à déclarer : on ne
    /// pollue pas son PGN.
    @Test func exportedPGNOfAStandardGameHasNoSetUpTags() throws {
        var game = Game(startingWith: .standard)
        var board = Board(position: .standard)
        let played = board.move(pieceAt: Square("e2"), to: Square("e4"))
        let move = try #require(played)
        _ = game.make(move: move, from: game.startingIndex)

        let exported = PGNExport.pgn(for: game)

        #expect(!exported.contains("[SetUp"))
        #expect(!exported.contains("[FEN"))
    }

    /// Le piège de voisinage signalé par la revue : dès qu'un tag existe, le
    /// préfixage naïf créait une **troisième section** et `PGNParser` levait
    /// `.tooManyLineBreaks`. Les tags doivent s'insérer DANS la section de tags.
    @Test func exportedPGNStaysParsableWhenTheGameAlreadyHasTags() throws {
        let fen = "8/P6k/8/8/8/8/7K/8 w - - 0 1"
        let start = try #require(Position(fen: fen))
        var game = Game(startingWith: start)
        game.tags.white = "Alice"
        game.tags.black = "Stockfish"
        game.tags.result = "1-0"
        var board = Board(position: start)
        let played = board.move(pieceAt: Square("h2"), to: Square("h3"))
        let move = try #require(played)
        _ = game.make(move: move, from: game.startingIndex)

        let exported = PGNExport.pgn(for: game)

        // Une seule ligne vide : tags d'un côté, movetext de l'autre.
        let blankLines = exported.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        #expect(blankLines.count == 1, "un PGN n'a qu'une séparation tags/movetext")

        #expect(exported.contains("[White \"Alice\"]"))
        #expect(exported.contains("[SetUp \"1\"]"))

        let reloaded = try Game(pgn: exported)
        let reloadedStart = try #require(reloaded.positions[reloaded.startingIndex])
        #expect(reloadedStart.fen == fen, "les tags ne doivent pas empêcher le rechargement")
    }

    // MARK: Lot 6.1 — une progression sans échéance ne doit pas disparaître

    @Test func aProgressRecordWithoutADueDateIsTreatedAsNew() {
        let card = TrainCard(
            courseID: "italienne", fenKey: "position-sans-echeance",
            expectedUCI: "e2e4", expectedSAN: "e4", comment: nil
        )
        // Un enregistrement existe, mais sans `dueDate` : avant correction, la
        // position n'était ni « due » ni « neuve » — elle sortait de la file
        // pour toujours, sans que rien ne le signale.
        let progress = [
            "position-sans-echeance": OpeningProgressSnapshot(
                dueDate: nil, lapses: 0, stability: 0, reps: 0
            )
        ]

        let queue = OpeningTrainingQueue.dailyQueue(cards: [card], progress: progress)

        #expect(queue.count == 1, "la position doit rester révisable")
        #expect(queue.first?.fenKey == "position-sans-echeance")
    }

    @Test func aProgressRecordWithAFutureDueDateStaysOutOfTodaysQueue() {
        let card = TrainCard(
            courseID: "italienne", fenKey: "revue-demain",
            expectedUCI: "e2e4", expectedSAN: "e4", comment: nil
        )
        let progress = [
            "revue-demain": OpeningProgressSnapshot(
                dueDate: Date().addingTimeInterval(86_400), lapses: 0,
                stability: 3, reps: 2
            )
        ]

        let queue = OpeningTrainingQueue.dailyQueue(cards: [card], progress: progress)

        #expect(queue.isEmpty, "une position déjà planifiée ne revient pas aujourd'hui")
    }
}
