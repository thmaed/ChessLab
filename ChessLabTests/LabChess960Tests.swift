import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Le Laboratoire en Chess960 : le tirage des positions (pur), puis UNE vraie
/// série de deux parties contre le vrai moteur — la seule preuve que les
/// règles 960, le dialecte UCI du roque et l'export tiennent ensemble.
struct LabChess960SettingsTests {

    private func settings(
        alternate: Bool = true, number: Int? = nil, seed: UInt64 = 42
    ) -> LabGameSettings {
        var settings = LabGameSettings()
        settings.chess960Enabled = true
        settings.chess960Number = number
        settings.chess960Seed = seed
        settings.alternateColors = alternate
        return settings
    }

    @Test func aPairOfGamesSharesItsPositionWhenColoursAlternate() {
        let settings = settings()
        #expect(settings.chess960Number(forGame: 0) == settings.chess960Number(forGame: 1))
        #expect(settings.chess960Number(forGame: 2) == settings.chess960Number(forGame: 3))
    }

    @Test func everyGameHasItsOwnPositionWithoutAlternation() {
        let settings = settings(alternate: false)
        let numbers = (0..<20).map(settings.chess960Number(forGame:))
        #expect(Set(numbers).count > 10)
    }

    @Test func aFixedNumberAppliesToEveryGameAndIsClamped() {
        #expect((0..<6).allSatisfy { settings(number: 518).chess960Number(forGame: $0) == 518 })
        #expect(settings(number: 5000).chess960Number(forGame: 0) == 959)
        #expect(settings(number: -3).chess960Number(forGame: 0) == 0)
    }

    @Test func theSameSeedGivesTheSameSeries() {
        let first = (0..<30).map(settings(seed: 7).chess960Number(forGame:))
        let again = (0..<30).map(settings(seed: 7).chess960Number(forGame:))
        let other = (0..<30).map(settings(seed: 8).chess960Number(forGame:))
        #expect(first == again)
        #expect(first != other)
        #expect(first.allSatisfy { (0...959).contains($0) })
    }

    /// Les valeurs de référence que l'Android reprend à l'identique (le test
    /// JVM porte les mêmes) : si la suite change d'un côté, elle change de l'autre.
    @Test func theDrawMatchesTheValuesAndroidChecks() {
        let numbers = (0..<6).map { LabGameSettings.scharnagl(seed: 42, pair: $0) }
        #expect(numbers == LabChess960SettingsTests.referenceDraw)
    }

    /// Calculées à part, en Python, avant d'être écrites ici.
    static let referenceDraw = [482, 853, 451, 18, 84, 370]

    @Test func aSavedSeriesWithoutTheNewKeysReadsAsAClassicalOne() throws {
        // Une série sauvegardée avant le Chess960 : les mêmes clés, moins les trois nouvelles.
        var saved = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(LabGameSettings())) as? [String: Any]
        )
        for key in ["chess960Enabled", "chess960Number", "chess960Seed"] { saved.removeValue(forKey: key) }
        let decoded = try JSONDecoder().decode(LabGameSettings.self, from: JSONSerialization.data(withJSONObject: saved))
        #expect(!decoded.isChess960)
        #expect(decoded.startingPosition == .standard)
    }

    @Test func aChess960SeriesStartsFromItsFirstPosition() throws {
        let settings = settings(number: 518)
        #expect(settings.startingPosition == (try #require(Chess960Game(number: 518))).board.position)
        #expect(!settings.usesMaia)
    }

    @Test func theHeaderKeepsTheVariantTag() {
        let game = LabCompletedGame(
            index: 0, aWasWhite: true, pgnResult: "1/2-1/2", reasonLabel: "Nulle", plyCount: 2,
            pgn: "[Variant \"Chess960\"]\n[SetUp \"1\"]\n[FEN \"bbqnnrkr/pppppppp/8/8/8/8/PPPPPPPP/BBQNNRKR w KQkq - 0 1\"]\n\n1. e4 e5 1/2-1/2",
            chess960Number: 5
        )
        let pgn = LabExport.pgn([game], settings: LabGameSettings())
        #expect(pgn.contains("[Variant \"Chess960\"]"))
        #expect(pgn.contains("[FEN \"bbqnnrkr"))
    }
}

/// Une vraie série, contre le vrai Stockfish. Réservée à `ENGINE_INTEGRATION=1`
/// (`TEST_RUNNER_ENGINE_INTEGRATION=1 xcodebuild test …`) comme les autres tests
/// d'intégration moteur : lancée dans la suite complète, elle tournait en même
/// temps que les suites des variantes, et le processus de test plantait (05/11/2026).
@Suite(.serialized)
@MainActor
struct LabChess960SeriesTests {

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENGINE_INTEGRATION"] == "1"))
    func aTwoGameSeriesPlaysLegalChess960AndExportsReadablePGN() async throws {
        var settings = LabGameSettings()
        settings.chess960Enabled = true
        settings.chess960Seed = 11
        settings.gameCount = 2
        settings.movetimeMs = 30
        settings.sideAEloSlider = 1500
        settings.sideBEloSlider = 1500
        settings.liveVisualization = false
        settings.keepAwakeSetting = false

        let viewModel = LabViewModel(settings: settings)
        viewModel.start()
        let deadline = Date().addingTimeInterval(240)
        while !viewModel.isFinished, Date() < deadline {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        viewModel.cancel()

        #expect(viewModel.isFinished, "la série doit se terminer")
        #expect(viewModel.completed.count == 2)
        let numbers = viewModel.completed.compactMap(\.chess960Number)
        #expect(numbers.count == 2 && numbers[0] == numbers[1], "les deux parties d'une paire partent de la même position")
        #expect(viewModel.completed[0].aWasWhite != viewModel.completed[1].aWasWhite)

        for game in viewModel.completed {
            #expect(game.pgn.contains("[Variant \"Chess960\"]"))
            // Chaque coup se rejoue contre la couche de règles : un coup illégal ou mal noté tronquerait la lecture.
            let parsed = try #require(Chess960PGNParser.parse(game.pgn))
            #expect(parsed.moves.count == game.plyCount, "tous les coups de la partie se relisent")
        }
        // Et l'export de la série garde la variante, pour que le logiciel d'arrivée lise le FEN en Shredder.
        #expect(LabExport.pgn(viewModel.completed, settings: settings).contains("[Variant \"Chess960\"]"))
    }
}
