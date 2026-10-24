import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// B1 — le Coach : ce que jouent les humains de votre niveau.
@Suite
@MainActor
struct HumanMoveCoachTests {

    private func candidate(_ uci: String, _ probability: Double) -> MaiaCandidate {
        MaiaCandidate(move: MaiaMove(uci: uci, index: 0), probability: probability)
    }

    @Test("Les seuils : faute fréquente = typique, rarissime = accident, entre les deux = sans étiquette")
    func classification() {
        #expect(HumanMoveCoach.classify(probability: 0.20, isFault: true) == .typicalMistake)
        #expect(HumanMoveCoach.classify(probability: 0.08, isFault: true) == .typicalMistake)
        #expect(HumanMoveCoach.classify(probability: 0.05, isFault: true) == nil)
        #expect(HumanMoveCoach.classify(probability: 0.029, isFault: true) == .accident)
        #expect(HumanMoveCoach.classify(probability: 0.0, isFault: true) == .accident)
        // Un bon coup n'est jamais une « erreur » : rare ou rien.
        #expect(HumanMoveCoach.classify(probability: 0.01, isFault: false) == .rareFind)
        #expect(HumanMoveCoach.classify(probability: 0.40, isFault: false) == nil)
    }

    @Test("Le coup joué est cherché dans la distribution, le plus courant est nommé en SAN")
    func insightFromDistribution() throws {
        let board = Board(position: .standard)
        let distribution = [candidate("e2e4", 0.50), candidate("d2d4", 0.30), candidate("a2a3", 0.01)]
        let insight = try #require(HumanMoveCoach.insight(
            distribution: distribution, playedLAN: "d2d4", parent: board, level: 1400))
        #expect(insight.playedProbability == 0.30)
        #expect(insight.topProbability == 0.50)
        #expect(insight.topMoveSAN == "e4")
        #expect(!insight.playedIsTop)
        #expect(insight.level == 1400)

        let top = try #require(HumanMoveCoach.insight(
            distribution: distribution, playedLAN: "e2e4", parent: board, level: 1400))
        #expect(top.playedIsTop)
    }

    @Test("Un coup absent de la distribution compte pour une probabilité nulle")
    func absentMove() throws {
        let insight = try #require(HumanMoveCoach.insight(
            distribution: [candidate("e2e4", 0.9)], playedLAN: "h2h3", parent: Board(position: .standard), level: 1200))
        #expect(insight.playedProbability == 0)
        #expect(insight.kind(isFault: true) == .accident)
    }

    @Test("Les phrases : pourcentage, niveau, étiquette, coup le plus courant")
    func sentences() throws {
        let board = Board(position: .standard)
        let typical = try #require(HumanMoveCoach.insight(
            distribution: [candidate("e2e4", 0.50), candidate("d2d4", 0.30)],
            playedLAN: "d2d4", parent: board, level: 1400))
        let line = try #require(HumanMoveCoach.sentence(for: typical, isFault: true))
        #expect(line.contains("30 %"))
        #expect(line.contains("1400"))
        #expect(line.contains("erreur typique"))
        #expect(line.contains("e4"))

        // Le coup joué est le plus courant : pas de « le plus courant » redondant.
        let same = try #require(HumanMoveCoach.insight(
            distribution: [candidate("e2e4", 0.50)], playedLAN: "e2e4", parent: board, level: 1400))
        #expect(!(HumanMoveCoach.sentence(for: same, isFault: true) ?? "").contains("Le plus courant"))

        // Un bon coup courant ne dit rien ; une trouvaille rare se célèbre.
        #expect(HumanMoveCoach.sentence(for: same, isFault: false) == nil)
        let rare = try #require(HumanMoveCoach.insight(
            distribution: [candidate("e2e4", 0.90), candidate("a2a3", 0.002)],
            playedLAN: "a2a3", parent: board, level: 1400))
        let rareLine = try #require(HumanMoveCoach.sentence(for: rare, isFault: false))
        #expect(rareLine.contains("moins de 1 %"))
        #expect(rareLine.contains("coup rare"))
    }

    @Test("Avec le vrai modèle, 1.e4 est un coup très courant à 1500")
    func realModel() async throws {
        let maia = try #require(MaiaOpponent(), "le modèle Maia doit être embarqué")
        let board = Board(position: .standard)
        let distribution = try await maia.distribution(
            history: [board.position], board: board, selfElo: 1500, oppoElo: 1500)
        #expect(distribution.count == 20)
        #expect(abs(distribution.map(\.probability).reduce(0, +) - 1) < 1e-6)
        let insight = try #require(HumanMoveCoach.insight(
            distribution: distribution, playedLAN: "e2e4", parent: board, level: 1500))
        #expect(insight.playedProbability > 0.2)
        let odd = try #require(HumanMoveCoach.insight(
            distribution: distribution, playedLAN: "h2h4", parent: board, level: 1500))
        #expect(odd.playedProbability < insight.playedProbability)
    }

    @Test("Le niveau par défaut reste dans l'échelle du Coach")
    func defaultLevelIsClamped() {
        #expect(HumanMoveCoach.levelRange.contains(HumanMoveCoach.defaultLevel()))
    }
}
