import ChessKit
import Foundation
import Observation
import SwiftData

/// Les SUITES d'une analyse terminée (A2, A3) — quand l'utilisateur a ouvert l'analyse d'une
/// de ses parties contre l'ordinateur et que la classification vient de s'achever : les erreurs
/// et mats manqués deviennent des puzzles « Mes parties », et la position où il a quitté son
/// répertoire rejoint les révisions.
///
/// L'analyse AUTOMATIQUE en arrière-plan (A1) a été retirée le 27/10/2026 : elle se bloquait,
/// coûtait de la batterie et demandait une question hors contexte. Ces suites, elles, restent —
/// elles se jouent maintenant sous les yeux de l'utilisateur, à la fin de SON analyse.
///
/// Pendant Android : `AnalysisFollowUpService.kt`.
@Observable
@MainActor
final class AnalysisFollowUpService {
    static let shared = AnalysisFollowUpService()

    /// Au plus ce nombre de puzzles tirés d'une partie, les mats manqués d'abord, puis les fautes
    /// les plus coûteuses.
    static let maxPuzzlesPerGame = 3

    private static let pendingKey = "autoAnalysis.newPuzzles"
    private static let exitsKey = "autoAnalysis.repertoireExits"
    private static let doneKey = "analysisFollowUp.done"
    private static let retained = 300

    /// Puzzles créés depuis la dernière visite des puzzles : la pastille de l'accueil. Local à
    /// l'appareil.
    private(set) var newPuzzleCount = UserDefaults.standard.integer(forKey: pendingKey)

    /// Sorties de répertoire repérées depuis la dernière visite des ouvertures — la pastille de
    /// l'accueil. Local à l'appareil.
    private(set) var repertoireExitCount = UserDefaults.standard.integer(forKey: exitsKey)

    func acknowledgeNewPuzzles() {
        newPuzzleCount = 0
        UserDefaults.standard.removeObject(forKey: Self.pendingKey)
    }

    func acknowledgeRepertoireExits() {
        repertoireExitCount = 0
        UserDefaults.standard.removeObject(forKey: Self.exitsKey)
    }

    // MARK: Une fois par partie

    /// Les parties dont les suites ont déjà été jouées : rouvrir l'analyse d'une partie ne doit ni
    /// recréer ses puzzles ni compter deux fois sa sortie de répertoire.
    static func hasProcessed(_ key: String, defaults: UserDefaults = .standard) -> Bool {
        (defaults.stringArray(forKey: doneKey) ?? []).contains(key)
    }

    static func markProcessed(_ key: String, defaults: UserDefaults = .standard) {
        var keys = defaults.stringArray(forKey: doneKey) ?? []
        guard !keys.contains(key) else { return }
        keys.append(key)
        defaults.set(Array(keys.suffix(retained)), forKey: doneKey)
    }

    /// Les suites d'une analyse qui vient de se terminer. La sortie de répertoire (A3) s'enregistre d'elle-même,
    /// une fois par partie. Les puzzles (A2) ne se créent PAS d'office : on rend ce que l'app peut créer, et
    /// l'écran le propose (``PuzzleOfferSheet``) — `nil` s'il n'y a rien à proposer ou si la partie a déjà été
    /// décidée. Sans effet pour une partie qui n'est pas une partie enregistrée contre l'ordinateur.
    func followUp(after viewModel: AnalysisViewModel, context: ModelContext) async -> PuzzleOffer? {
        guard viewModel.analysisMetrics != nil,
              let key = viewModel.analysisPersistenceKey,
              let color = viewModel.userColorInRecordedGame(in: context)
        else { return nil }
        if !Self.hasProcessed("exit:\(key)") {
            Self.markProcessed("exit:\(key)")
            recordRepertoireExit(from: viewModel, color: color, context: context)
        }
        guard !Self.hasProcessed("puz:\(key)") else { return nil }
        let candidates = await viewModel.proposePuzzles(in: context, color: color, limit: Self.maxPuzzlesPerGame)
        guard !candidates.isEmpty else {
            Self.markProcessed("puz:\(key)")
            return nil
        }
        return PuzzleOffer(key: key, candidates: candidates)
    }

    /// La décision est prise (accepté ou refusé) : la partie ne sera plus proposée.
    func puzzlesDecided(key: String, created: Int) {
        Self.markProcessed("puz:\(key)")
        guard created > 0 else { return }
        newPuzzleCount += created
        UserDefaults.standard.set(newPuzzleCount, forKey: Self.pendingKey)
    }

    /// A3 — la position où l'utilisateur a quitté son répertoire rejoint les révisions FSRS : ce
    /// qu'on a raté en partie est revu. L'adversaire qui quitte la théorie le premier n'est PAS
    /// une sortie (voir ``RepertoireExitDetector``).
    func recordRepertoireExit(from viewModel: AnalysisViewModel, color: Piece.Color, context: ModelContext) {
        let followed = RepertoireExitDetector.followedCourses(in: context)
        guard let exit = RepertoireExitDetector.firstExit(
            in: viewModel.game, userColor: color, courses: followed.courses, studied: followed.studied)
        else { return }
        OpeningProgressStore.recordReview(fenKey: exit.fenKey, rating: .again, in: context)
        repertoireExitCount += 1
        UserDefaults.standard.set(repertoireExitCount, forKey: Self.exitsKey)
    }
}
