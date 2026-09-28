import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Ce qu'un PGN exporté contient VRAIMENT.
///
/// Motif : un testeur a partagé deux parties par courriel le 27/09/2026 et
/// n'a reçu que des suites de coups — « no pgn tags, no result ». C'était
/// exact : `ChessKit.Game.pgn` ne sérialise que les balises renseignées, et
/// l'app n'en renseignait aucune. Un fichier sans les sept balises du standard
/// n'est pas un PGN : plusieurs logiciels le refusent, et aucun ne sait qui a
/// joué ni qui a gagné.
@MainActor
struct PGNExportHeaderTests {

    /// Une partie d'un coup, depuis la position standard.
    private func gameAfterE4() throws -> Game {
        var game = Game(startingWith: .standard)
        var board = Board(position: .standard)
        let played = board.move(pieceAt: Square("e2"), to: Square("e4"))
        let move = try #require(played)
        _ = game.make(move: move, from: game.startingIndex)
        return game
    }

    /// Les sept balises obligatoires, présentes et renseignées.
    @Test func exportCarriesTheSevenTagRoster() throws {
        let pgn = PGNExport.pgn(
            for: try gameAfterE4(),
            metadata: .vsEngine(
                userColor: .white, engineName: "Ordinateur", result: "1-0",
                date: try #require(date(2026, 9, 27))
            )
        )

        #expect(pgn.contains("[Site \"ChessLab\"]"))
        #expect(pgn.contains("[Date \"2026.09.27\"]"))
        #expect(pgn.contains("[Round \"-\"]"))
        #expect(pgn.contains("[Black \"Ordinateur\"]"))
        #expect(pgn.contains("[Result \"1-0\"]"))
        // L'événement et le nom du joueur suivent la langue de l'app.
        #expect(pgn.contains("[Event \"\(LocalizationController.string("Contre l'ordinateur"))\"]"))
        #expect(pgn.contains("[White \"\(PlayerName.you)\"]"))
    }

    /// Le résultat clôt aussi le movetext — c'est là que les lecteurs le
    /// cherchent, et c'est ce que le testeur ne trouvait pas.
    @Test func theResultClosesTheMovetext() throws {
        let pgn = PGNExport.pgn(
            for: try gameAfterE4(),
            metadata: .twoPlayer(whiteName: "Alice", blackName: "Bob", result: "0-1")
        )
        #expect(pgn.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("0-1"))
    }

    /// Partie inachevée : « * », la valeur que le standard réserve à ça —
    /// jamais rien.
    @Test func anUnfinishedGameIsMarkedWithAStar() throws {
        let pgn = PGNExport.pgn(
            for: try gameAfterE4(),
            metadata: .twoPlayer(whiteName: "Alice", blackName: "Bob", result: nil)
        )
        #expect(pgn.contains("[Result \"*\"]"))
        #expect(pgn.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("*"))
    }

    /// Un PGN importé garde SES en-têtes : on ne réécrit pas l'histoire d'une
    /// partie de championnat avec « ChessLab » et la date du jour.
    @Test func existingTagsAreNeverOverwritten() throws {
        var game = try gameAfterE4()
        game.tags.event = "Championnat du monde"
        game.tags.white = "Fischer, Robert J."
        game.tags.date = "1972.07.11"

        let pgn = PGNExport.pgn(
            for: game,
            metadata: .twoPlayer(whiteName: "Alice", blackName: "Bob", result: "1-0")
        )

        #expect(pgn.contains("[Event \"Championnat du monde\"]"))
        #expect(pgn.contains("[White \"Fischer, Robert J.\"]"))
        #expect(pgn.contains("[Date \"1972.07.11\"]"))
        // Ce qui manquait, en revanche, est bien comblé.
        #expect(pgn.contains("[Black \"Bob\"]"))
    }

    /// Un guillemet dans un nom fermerait la balise et rendrait le fichier
    /// illisible pour tout le monde, nous compris.
    @Test func aQuoteInANameCannotBreakTheFile() throws {
        let pgn = PGNExport.pgn(
            for: try gameAfterE4(),
            metadata: .twoPlayer(
                whiteName: "Ron \"Rocket\" Lasser", blackName: "[Bob]", result: "1-0"
            )
        )

        #expect(pgn.contains("[White \"Ron Rocket Lasser\"]"))
        #expect(pgn.contains("[Black \"Bob\"]"))
        let reloaded = try #require(PGNLoader.game(from: pgn))
        #expect(reloaded.tags.white == "Ron Rocket Lasser")
    }

    /// Les en-têtes ne doivent pas empêcher le rechargement : c'est le même
    /// texte qui part au partage et qui revient par l'import.
    @Test func theExportedGameReloadsWithItsMovesAndItsHeaders() throws {
        let pgn = PGNExport.pgn(
            for: try gameAfterE4(),
            metadata: .vsEngine(userColor: .black, engineName: "Maia", result: "0-1")
        )
        let reloaded = try #require(PGNLoader.game(from: pgn))

        #expect(reloaded.tags.white == "Maia")
        #expect(reloaded.tags.black == PlayerName.you)
        #expect(reloaded.tags.result == "0-1")
        #expect(reloaded.moves.pgnRepresentation.isEmpty == false)
    }

    /// Une date inconnue s'écrit « ????.??.?? » — pas la date du jour, qui
    /// serait un mensonge, ni rien, qui serait un trou.
    @Test func anUnknownDateFollowsTheStandard() throws {
        let pgn = PGNExport.pgn(
            for: try gameAfterE4(),
            metadata: PGNExport.Metadata(
                event: "Analyse", date: nil, white: "?", black: "?", result: nil
            )
        )
        #expect(pgn.contains("[Date \"????.??.??\"]"))
    }

    /// La date PGN ne dépend NI de la locale NI du calendrier de l'appareil :
    /// « AAAA.MM.JJ », grégorien, chiffres arabes.
    @Test func theDateFormatIsInvariant() throws {
        #expect(PGNExport.pgnDate(try #require(date(2026, 1, 5))) == "2026.01.05")
    }

    /// Le fichier COMPLET, tel qu'il part par courriel : une section de
    /// balises, une ligne vide, le movetext clos par le résultat. C'est la
    /// forme que le standard appelle « export format », et c'est elle que les
    /// autres logiciels savent lire.
    @Test func theWholeFileHasTheShapeTheStandardExpects() throws {
        let pgn = PGNExport.pgn(
            for: try gameAfterE4(),
            metadata: .vsEngine(
                userColor: .white, engineName: "Ordinateur", result: "1-0",
                date: try #require(date(2026, 9, 27))
            )
        )
        let expected = """
        [Event "\(LocalizationController.string("Contre l'ordinateur"))"]
        [Site "ChessLab"]
        [Date "2026.09.27"]
        [Round "-"]
        [White "\(PlayerName.you)"]
        [Black "Ordinateur"]
        [Result "1-0"]

        1. e4 1-0
        """
        #expect(pgn == expected)
    }

    /// Le contrat d'origine tient toujours : sans en-têtes demandées, une
    /// partie standard sort nue.
    @Test func withoutMetadataAStandardGameStaysBare() throws {
        let pgn = PGNExport.pgn(for: try gameAfterE4())
        #expect(!pgn.contains("["))
    }

    /// Une partie rangée AVANT que l'app n'émette ses balises : rouverte
    /// depuis la bibliothèque, elle doit retrouver ses joueurs, sa date et son
    /// résultat — qui ne vivaient que dans les colonnes de l'enregistrement.
    @Test func anOldRecordIsCompletedFromWhatTheLibraryKnows() throws {
        let record = GameRecord()
        record.modeRaw = GameRecordMode.vsEngine.rawValue
        record.pgn = "1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0"
        record.whiteName = "Vous"
        record.blackName = "Ordinateur"
        record.resultRaw = "1-0"
        record.playedAt = try #require(date(2026, 9, 27))

        let pgn = try #require(GameLibraryService.analysablePGN(of: record))

        #expect(pgn.contains("[White \"\(PlayerName.you)\"]"))
        #expect(pgn.contains("[Black \"\(PlayerName.computer)\"]"))
        #expect(pgn.contains("[Date \"2026.09.27\"]"))
        #expect(pgn.contains("[Result \"1-0\"]"))
    }

    /// Une partie IMPORTÉE garde son texte d'origine : la repasser par le
    /// lecteur lui coûterait ses commentaires et ses variantes.
    @Test func animportedGameIsHandedOverUntouched() throws {
        let original = """
        [Event "Championnat"]
        [White "Fischer, Robert J."]

        1. e4 {la meilleure par test} e5 (1... c5 2. Nf3) 2. Nf3 1-0
        """
        let record = GameRecord()
        record.modeRaw = GameRecordMode.imported.rawValue
        record.pgn = original

        #expect(GameLibraryService.analysablePGN(of: record) == original)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components)
    }
}
