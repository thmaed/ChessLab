import Foundation
import Testing
import ChessKit
@testable import ChessLab

/// S1 (2.0) — MESURE de l'analyse complète d'une partie : durée, nombre de
/// positions, état thermique avant/après. Opt-in (`ENGINE_INTEGRATION=1`),
/// à lancer sur un APPAREIL : c'est lui qui décide si l'analyse automatique
/// (volet A1) peut se faire en arrière-plan sans ruiner la batterie.
/// Les chiffres sortent sur la sortie standard (`S1|…`).
@MainActor
struct HeadlessAnalysisMeasureTests {

    private static let games: [String] = [
        // partie 5 (52 coups)
        #"1. e4 d5 2. exd5 Qxd5 3. Nc3 Qa5 4. Nf3 Nf6 5. h3 Bf5 6. d3 e6 7. Bd2 Nbd7 8. a3 c5 9. Be2 Qb6 10. Na4 Qc6 11. c4 Bd6 12. O-O O-O 13. Nh2 Bxd3 14. Bxd3 Bxh2+ 15. Kxh2 Qd6+ 16. Bf4 Qxf4+ 17. g3 Qd4 18. Qc2 Ne5 19. Rad1 Nxd3 20. Rxd3 Qe5 21. Nc3 Rfd8 22. Rfd1 Rxd3 23. Qxd3 h6 24. b4 cxb4 25. axb4 Rc8 26. Rd2 a6 27. Re2 Qc7 28. Ne4 Qxc4 29. Nxf6+ gxf6 30. Qe3 Kh7 31. Rb2 f5 32. Rb3 Qf1 33. g4 Rc2 34. Kg3 Qg1+ 35. Kf3 Qh1+ 36. Kg3 Qg1+ 37. Kf3 fxg4+ 38. hxg4 Qh1+ 39. Kg3 Qg1+ 40. Kf3 Qd1+ 41. Kg3 Rc4 42. f3 Qd6+ 43. f4 Rxb4 44. Rd3 Qb6 45. Qe1 Qb5 46. Qe3 a5 47. Rc3 a4 48. Qd2 Rb2 49. Qd4 Qe2 50. f5 Qe1+ 51. Kf4 e5+ 52. Qxe5 Rf2+ *"#,
        // partie 2 (28 coups)
        #"1. e4 e5 2. Nf3 Nc6 3. d4 exd4 4. Nxd4 Bc5 5. Be3 Nxd4 6. Bxd4 Bxd4 7. Qxd4 Nf6 8. e5 Qe7 9. Be2 c5 10. exf6 Qxe2+ 11. Kxe2 cxd4 12. fxg7 Rg8 13. Rd1 d5 14. Rxd4 Be6 15. Nd2 Rc8 16. c3 Rxg7 17. g3 Rg5 18. Nf1 Ke7 19. Ne3 b5 20. a4 a6 21. axb5 axb5 22. Ra5 Rb8 23. Rb4 Bd7 24. Ra6 Rbg8 25. Rd4 Re5 26. Rxd5 Rgg5 27. Rd4 b4 28. Ra7 1-0"#,
        // partie 1 (66 coups)
        #"1. e4 e6 2. c4 d5 3. cxd5 exd5 4. exd5 Nf6 5. Bb5+ Nbd7 6. Nc3 Bd6 7. Nge2 O-O 8. O-O a6 9. Bc4 Ne5 10. d3 Nfg4 11. f4 Bc5+ 12. d4 Nxc4 13. Qd3 Bd6 14. Qxc4 f5 15. h3 Nf6 16. Bd2 b5 17. Qb3 Bb7 18. a3 Qe8 19. Rae1 Qf7 20. Nc1 Rae8 21. Nd3 Ne4 22. Nxe4 fxe4 23. Ne5 Qxd5 24. Qe3 c5 25. Bc3 b4 26. axb4 cxb4 27. Bd2 a5 28. b3 Bc7 29. Bc1 Bb6 30. Bb2 Rc8 31. Nc4 Rxc4 32. bxc4 Qxc4 33. Rc1 Qd5 34. Kh1 a4 35. Ba1 Rd8 36. Rfd1 Rd7 37. Rb1 Qd6 38. Qd2 b3 39. Bc3 Bc7 40. Ra1 Qc6 41. d5 Qc5 42. Qd4 Qd6 43. Qxe4 Re7 44. Be5 Qf6 45. Qxa4 Rxe5 46. fxe5 Qxe5 47. Kg1 Bb6+ 48. Kf1 b2 49. Rab1 Qf5+ 50. Ke2 Qe5+ 51. Kd3 Qf5+ 52. Kc3 Qe5+ 53. Kb3 Bxd5+ 54. Rxd5 Qxd5+ 55. Qc4 Qxc4+ 56. Kxc4 Bc7 57. Rxb2 Be5 58. Rb7 h6 59. Kd5 Bf6 60. Ke6 Kh7 61. Kf7 h5 62. Rb6 Be5 63. Rb5 Bf4 64. Rxh5+ Bh6 65. g4 g6 66. Rh4 1-0"#,
    ]

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENGINE_INTEGRATION"] == "1"))
    func measureFullClassification() async throws {
        for (i, moves) in Self.games.enumerated() {
            let pgn = "[Event \"S1\"]\n[Result \"*\"]\n\n\(moves) *"
            let before = ProcessInfo.processInfo.thermalState.rawValue
            let start = Date()
            let viewModel = AnalysisViewModel(source: .pgn(pgn))
            let total = max(1, viewModel.moveListRows.count)
            let deadline = Date().addingTimeInterval(600)
            var done = 0
            while Date() < deadline, !viewModel.isEngineUnavailable {
                done = viewModel.moveEvaluations.count
                if done > 0, !viewModel.isClassifying, viewModel.classificationProgress == nil, done >= total / 2 { break }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            let seconds = Date().timeIntervalSince(start)
            let plies = viewModel.moveEvaluations.count
            print(String(format: "S1|partie %d|%d demi-coups classés|%.1f s|%.2f s/demi-coup|thermique %d→%d",
                         i, plies, seconds, seconds / Double(max(1, plies)),
                         before, ProcessInfo.processInfo.thermalState.rawValue))
            viewModel.handleViewDisappear()
            try await Task.sleep(nanoseconds: 800_000_000)
        }
    }
}
