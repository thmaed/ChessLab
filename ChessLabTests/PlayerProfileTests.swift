import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// A4 — le profil de faiblesses, de la perte par coup au profil affiché.
@Suite
@MainActor
struct PlayerProfileTests {

    private func game(
        daysAgo: Int, accuracy: Double?, opening: PhaseLoss? = nil, middle: PhaseLoss? = nil,
        end: PhaseLoss? = nil, themes: [String: Int] = [:], name: String? = nil
    ) -> AnalyzedGame {
        var phases: [GamePhase: PhaseLoss] = [:]
        if let opening { phases[.opening] = opening }
        if let middle { phases[.middlegame] = middle }
        if let end { phases[.endgame] = end }
        return AnalyzedGame(
            date: Date(timeIntervalSinceNow: -Double(daysAgo) * 86_400), accuracy: accuracy,
            phases: phases, themes: themes, openingName: name)
    }

    @Test("Les chaînes stockées se relisent à l'identique")
    func codecRoundTrip() {
        let phases: [GamePhase: PhaseLoss] = [
            .opening: PhaseLoss(total: 12.5, count: 6), .endgame: PhaseLoss(total: 4, count: 2)]
        let text = GameProfileCodec.encode(phases: phases)
        #expect(text == "o:12.50:6,m:0.00:0,e:4.00:2")
        let decoded = GameProfileCodec.decodePhases(text)
        #expect(decoded[.opening] == PhaseLoss(total: 12.5, count: 6))
        #expect(decoded[.endgame] == PhaseLoss(total: 4, count: 2))

        let themes = ["pin": 1, "fork": 2, "other": 0]
        #expect(GameProfileCodec.encode(themes: themes) == "fork:2,pin:1")
        #expect(GameProfileCodec.decodeThemes("fork:2,pin:1") == ["fork": 2, "pin": 1])
        #expect(GameProfileCodec.decodePhases(nil).isEmpty)
        #expect(GameProfileCodec.decodeThemes("n'importe quoi").isEmpty)
    }

    @Test("Les métriques d'une partie portent la perte par phase et les fautes par motif")
    func metricsCarryTheProfile() {
        let moves: [GameAnalysisMetrics.Move] = [
            .init(mover: .white, loss: 10, isBook: false, phase: .opening),
            .init(mover: .white, loss: 0, isBook: true, phase: .opening),
            .init(mover: .white, loss: 30, isBook: false, phase: .middlegame, faultTheme: "fork"),
            .init(mover: .white, loss: 20, isBook: false, phase: .middlegame, faultTheme: "other"),
            .init(mover: .black, loss: 5, isBook: false, phase: .endgame),
        ]
        let metrics = GameAnalysisMetrics.compute(
            moves: moves, accuracyByColor: [:], openingName: "Italian Game")
        #expect(metrics.white.phases[.opening] == PhaseLoss(total: 10, count: 1))
        #expect(metrics.white.phases[.middlegame] == PhaseLoss(total: 50, count: 2))
        #expect(metrics.white.themes == ["fork": 1, "other": 1])
        #expect(metrics.black.phases[.endgame] == PhaseLoss(total: 5, count: 1))
        #expect(metrics.openingName == "Italian Game")
    }

    @Test("Le profil et son enregistrement dans la partie")
    func recordRoundTrip() throws {
        let record = GameRecord()
        let metrics = GameAnalysisMetrics.compute(
            moves: [.init(mover: .white, loss: 8, isBook: false, phase: .middlegame, faultTheme: "pin")],
            accuracyByColor: [.white: 80], openingName: "Sicilian Defense")
        #expect(record.apply(metrics, key: "k"))
        #expect(!record.apply(metrics, key: "k"))
        let back = try #require(record.analysisMetrics)
        #expect(back.white.phases[.middlegame] == PhaseLoss(total: 8, count: 1))
        #expect(back.white.themes == ["pin": 1])
        #expect(back.openingName == "Sicilian Defense")
    }

    @Test("Trop peu de parties : le profil n'est pas montré")
    func notMeaningfulWithFewGames() {
        let profile = PlayerProfile.compute(from: [game(daysAgo: 1, accuracy: 70), game(daysAgo: 2, accuracy: 72)])
        #expect(!profile.isMeaningful)
    }

    @Test("La phase la plus coûteuse est le point faible, à condition d'avoir assez de coups")
    func weakestPhase() throws {
        let games = (0..<4).map { index in
            game(daysAgo: index, accuracy: 75,
                 opening: PhaseLoss(total: 6, count: 3),
                 middle: PhaseLoss(total: 60, count: 6),
                 end: PhaseLoss(total: 10, count: 2))
        }
        let profile = PlayerProfile.compute(from: games)
        #expect(profile.isMeaningful)
        let weakest = try #require(profile.weakestPhase)
        #expect(weakest.phase == .middlegame)
        #expect(abs(weakest.averageLoss - 10) < 1e-9)
        // La finale n'a que 8 coups sur quatre parties : 2 × 4 = 8, juste assez.
        #expect(profile.phases.map(\.phase) == [.opening, .middlegame, .endgame])

        // Sous le seuil de coups, une phase n'est pas jugée.
        let thin = PlayerProfile.compute(from: (0..<3).map { game(daysAgo: $0, accuracy: 70, middle: PhaseLoss(total: 9, count: 1)) })
        #expect(thin.phases.isEmpty)
        #expect(thin.weakestPhase == nil)
    }

    @Test("La précision récente se compare aux dix précédentes")
    func accuracyTrend() throws {
        // 25 parties : les 10 plus récentes à 80, les 10 d'avant à 70, les 5 plus anciennes à 60.
        var games: [AnalyzedGame] = []
        for index in 0..<25 {
            let accuracy: Double = index < 10 ? 80 : (index < 20 ? 70 : 60)
            games.append(game(daysAgo: index, accuracy: accuracy))
        }
        let trend = try #require(PlayerProfile.compute(from: games).accuracy)
        #expect(trend.recent.count == 10)
        #expect(trend.recentAverage == 80)
        #expect(trend.previousAverage == 70)
        #expect(trend.delta == 10)

        // Moins de trois parties avant : pas de comparaison.
        let young = try #require(PlayerProfile.compute(from: (0..<12).map { game(daysAgo: $0, accuracy: 75) }).accuracy)
        #expect(young.previousAverage == nil)
    }

    @Test("Les tactiques manquées sont classées, les trois premières seulement")
    func themes() {
        let games = [
            game(daysAgo: 1, accuracy: 70, themes: ["fork": 2, "pin": 1]),
            game(daysAgo: 2, accuracy: 70, themes: ["fork": 1, "other": 5, "mate": 1, "hanging": 1]),
            game(daysAgo: 3, accuracy: 70),
        ]
        let profile = PlayerProfile.compute(from: games)
        #expect(profile.themes.map(\.theme) == ["other", "fork", "hanging"])
        #expect(profile.themes.map(\.count) == [5, 3, 1])
    }

    @Test("Une ouverture coûteuse demande deux parties et assez de coups hors théorie")
    func costlyOpenings() {
        let games = [
            game(daysAgo: 1, accuracy: 70, opening: PhaseLoss(total: 30, count: 3), name: "Sicilian Defense"),
            game(daysAgo: 2, accuracy: 70, opening: PhaseLoss(total: 24, count: 3), name: "Sicilian Defense"),
            game(daysAgo: 3, accuracy: 70, opening: PhaseLoss(total: 5, count: 3), name: "Italian Game"),
            game(daysAgo: 4, accuracy: 70, opening: PhaseLoss(total: 90, count: 3), name: "Scandinavian Defense"),
        ]
        let profile = PlayerProfile.compute(from: games)
        // Scandinave et Italienne n'ont qu'une partie : seule la sicilienne compte.
        #expect(profile.openings.map(\.name) == ["Sicilian Defense"])
        #expect(abs((profile.openings.first?.averageLoss ?? 0) - 9) < 1e-9)
        #expect(profile.openings.first?.games == 2)
    }

    @Test("Seules les parties contre l'ordinateur, vues du côté du joueur, entrent dans le profil")
    func onlyMyGamesAgainstTheEngine() {
        func record(engineColor: Piece.Color?, mode: GameRecordMode, whiteLoss: Double, blackLoss: Double) -> GameRecord {
            let record = GameRecord()
            record.modeRaw = mode.rawValue
            record.engineColorRaw = engineColor?.rawValue
            record.playedAt = Date()
            let metrics = GameAnalysisMetrics.compute(
                moves: [
                    .init(mover: .white, loss: whiteLoss, isBook: false, phase: .middlegame),
                    .init(mover: .black, loss: blackLoss, isBook: false, phase: .middlegame),
                ],
                accuracyByColor: [.white: 60, .black: 90])
            record.apply(metrics, key: UUID().uuidString)
            return record
        }
        let profile = PlayerProfile.compute(games: [
            record(engineColor: .black, mode: .vsEngine, whiteLoss: 10, blackLoss: 1),   // je suis Blanc
            record(engineColor: .white, mode: .vsEngine, whiteLoss: 1, blackLoss: 20),   // je suis Noir
            record(engineColor: nil, mode: .twoHuman, whiteLoss: 99, blackLoss: 99),    // à deux : exclue
        ])
        #expect(profile.games == 2)
        let middle = profile.phases.first { $0.phase == .middlegame }
        // Mes pertes : 10 (Blanc) et 20 (Noir) → 15 par coup sur 2 coups, pas 99.
        #expect(middle == nil)   // 2 coups < seuil de 8 : non jugée
        #expect(profile.accuracy?.recentAverage == 75)   // (60 + 90) / 2
    }
}
