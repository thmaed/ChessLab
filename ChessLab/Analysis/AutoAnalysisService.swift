import ChessKit
import CStockfishKit
import Foundation
import Observation
import SwiftData

/// A1 (2.0) — l'analyse AUTOMATIQUE des parties, sans écran.
///
/// Une file de parties, traitées UNE à la fois par un ``AnalysisViewModel``
/// que personne ne regarde : il classe la ligne principale, écrit le cache par
/// coup sur le disque (``AnalysisEvalStore``), puis le service recopie le bilan
/// chiffré dans la partie enregistrée. Ce que l'écran d'analyse fait déjà,
/// moins l'écran — et c'est exprès : la même passe, donc les mêmes verdicts.
///
/// Garde-fous (S1, `PLAN-2.0.md` §4 ter) :
/// - rien sans l'accord de l'utilisateur (``AutoAnalysisChoice``) ;
/// - rien en mode économie d'énergie, ni pendant que l'appareil est bridé ;
/// - interrompue si l'app quitte l'avant-plan (reprise au retour) ;
/// - arrêtable à tout moment ; ce qui est déjà classé reste sur le disque.
///
/// Pendant Android : `AutoAnalysisService.kt`.
@Observable
@MainActor
final class AutoAnalysisService {
    static let shared = AutoAnalysisService()

    struct Job: Equatable, Identifiable {
        let id: String   // empreinte de la partie (AnalysisEvalStore.key)
        let pgn: String
        /// Le camp de l'utilisateur : ses erreurs, pas celles de l'ordinateur.
        let userColor: Piece.Color?
    }

    /// A2 : au plus ce nombre de puzzles tirés d'une partie, les mats manqués
    /// d'abord, puis les fautes les plus coûteuses.
    static let maxPuzzlesPerGame = 3

    private static let pendingKey = "autoAnalysis.newPuzzles"

    /// Puzzles créés depuis la dernière visite des puzzles : la pastille de
    /// l'accueil. Local à l'appareil.
    private(set) var newPuzzleCount = UserDefaults.standard.integer(forKey: pendingKey)

    private static let exitsKey = "autoAnalysis.repertoireExits"

    /// A3 : sorties de répertoire repérées depuis la dernière visite des
    /// ouvertures — la pastille de l'accueil. Local à l'appareil.
    private(set) var repertoireExitCount = UserDefaults.standard.integer(forKey: exitsKey)

    func acknowledgeRepertoireExits() {
        repertoireExitCount = 0
        UserDefaults.standard.removeObject(forKey: Self.exitsKey)
    }

    /// A3 — la position où l'utilisateur a quitté son répertoire rejoint les
    /// révisions FSRS : ce qu'on a raté en partie est revu. L'adversaire qui
    /// quitte la théorie le premier n'est PAS une sortie (voir
    /// ``RepertoireExitDetector``).
    func recordRepertoireExit(from viewModel: AnalysisViewModel, color: Piece.Color, context: ModelContext) {
        let followed = RepertoireExitDetector.followedCourses(in: context)
        guard let exit = RepertoireExitDetector.firstExit(
            in: viewModel.game, userColor: color, courses: followed.courses, studied: followed.studied)
        else { return }
        OpeningProgressStore.recordReview(fenKey: exit.fenKey, rating: .again, in: context)
        repertoireExitCount += 1
        UserDefaults.standard.set(repertoireExitCount, forKey: Self.exitsKey)
    }

    func acknowledgeNewPuzzles() {
        newPuzzleCount = 0
        UserDefaults.standard.removeObject(forKey: Self.pendingKey)
    }

    /// Parties en attente, la première étant celle en cours.
    private(set) var queue: [Job] = []
    /// Avancement de la partie en cours (demi-coups classés / total).
    private(set) var progress: (done: Int, total: Int)?
    private(set) var isActive = true

    private var context: ModelContext?
    private var runner: Task<Void, Never>?
    /// Écrans qui tiennent le moteur (partie, analyse, laboratoire…). Le process
    /// moteur est UNIQUE : tant qu'il y en a un, l'analyse automatique attend.
    private var userLeases = 0
    private var resumeTask: Task<Void, Never>?
    /// Échecs par partie : au troisième, on y renonce.
    private var failures: [String: Int] = [:]

    /// Un écran réserve le moteur : l'analyse automatique s'arrête ET le libère
    /// avant que l'appelant ne démarre le sien. C'est ce qui évite le conflit
    /// de la fin de partie, quand l'utilisateur ouvre l'analyse pendant que
    /// l'arrière-plan travaille encore.
    func acquireUserEngine() async {
        userLeases += 1
        resumeTask?.cancel()
        guard let running = runner else { return }
        running.cancel()
        await running.value
    }

    /// Le moteur est rendu. La reprise attend un peu : passer d'un écran à
    /// l'autre (jeu → analyse) rend et reprend le moteur à quelques instants.
    func releaseUserEngine() {
        userLeases = max(0, userLeases - 1)
        guard userLeases == 0 else { return }
        resumeTask?.cancel()
        resumeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.startIfPossible()
        }
    }

    var isRunning: Bool { runner != nil }

    /// Ajoute une partie à la file (sans doublon) et démarre si possible.
    func enqueue(pgn: String, key: String, userColor: Piece.Color? = nil, context: ModelContext) {
        guard AppSettings.shared.autoAnalysisChoice == .on else { return }
        guard !queue.contains(where: { $0.id == key }) else { return }
        self.context = context
        queue.append(Job(id: key, pgn: pgn, userColor: userColor))
        startIfPossible()
    }

    /// Vide la file et interrompt la partie en cours.
    func stop() {
        queue.removeAll()
        runner?.cancel()
    }

    /// L'app passe à l'avant-plan ou le quitte.
    func setActive(_ active: Bool) {
        isActive = active
        if active { startIfPossible() } else { runner?.cancel() }
    }

    /// Le réglage vient d'être changé.
    func settingChanged() {
        if AppSettings.shared.autoAnalysisChoice == .on { startIfPossible() } else { stop() }
    }

    private var mayRun: Bool {
        AppSettings.shared.autoAnalysisChoice == .on
            && isActive
            && userLeases == 0
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && !ThermalMonitor.shared.isThrottling
    }

    private func startIfPossible() {
        guard runner == nil, !queue.isEmpty, mayRun, let context else { return }
        runner = Task { [weak self] in
            await self?.drain(context: context)
        }
    }

    private func drain(context: ModelContext) async {
        defer {
            runner = nil
            progress = nil
        }
        while let job = queue.first, mayRun, !Task.isCancelled {
            let finished = await analyze(job, context: context)
            // Interrompue : la partie reste en tête de file, on la reprendra.
            guard finished else { return }
            queue.removeAll { $0.id == job.id }
        }
    }

    /// A2 — les erreurs et les mats manqués de l'utilisateur deviennent des
    /// puzzles « Mes parties », sans qu'il ait à y penser.
    private func createPuzzles(from viewModel: AnalysisViewModel, color: Piece.Color, context: ModelContext) async {
        let cap = Self.maxPuzzlesPerGame
        let mates = await viewModel.findMissedMates(in: context, color: color)
        var created = viewModel.saveMissedMates(Array(mates.prefix(cap)), in: context)
        if created < cap, mayRun {
            created += await viewModel.generatePuzzles(in: context, color: color, limit: cap - created)
        }
        guard created > 0 else { return }
        newPuzzleCount += created
        UserDefaults.standard.set(newPuzzleCount, forKey: Self.pendingKey)
    }

    /// Vrai si la partie est terminée (ou irrécupérable) — faux si interrompue.
    private func analyze(_ job: Job, context: ModelContext) async -> Bool {
        let viewModel = AnalysisViewModel(source: .pgn(job.pgn), isBackground: true)
        let total = max(1, viewModel.moveListRows.count)
        progress = (0, total)
        // Au plus 10 minutes en tout, et 2 minutes sans le moindre progrès : au
        // delà, la partie est tenue pour bloquée (moteur muet, par exemple).
        let deadline = Date().addingTimeInterval(600)
        var lastDone = -1
        var lastChange = Date()
        var finished = false
        var failed = false

        // Annulée (un écran réclame le moteur) : on arrête le view model TOUT DE
        // SUITE, y compris au milieu des puzzles — sinon il continuerait de
        // chercher plusieurs secondes derrière le nouvel arrivant.
        await withTaskCancellationHandler {
            while Date() < deadline {
                if Task.isCancelled || !mayRun { break }
                let done = viewModel.moveEvaluations.count
                progress = (min(total, done), total)
                if done != lastDone { lastDone = done; lastChange = Date() }
                if viewModel.isEngineUnavailable || Date().timeIntervalSince(lastChange) > 120 {
                    failed = true
                    break
                }
                if viewModel.analysisMetrics != nil {
                    _ = viewModel.persistMetrics(in: context)
                    if let color = job.userColor {
                        await createPuzzles(from: viewModel, color: color, context: context)
                        // Après les puzzles et seulement si rien n'a été interrompu :
                        // une partie reprise ne doit pas compter deux fois la sortie.
                        if !Task.isCancelled {
                            recordRepertoireExit(from: viewModel, color: color, context: context)
                        }
                    }
                    finished = !Task.isCancelled
                    break
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        } onCancel: {
            Task { @MainActor in viewModel.handleViewDisappear() }
        }
        if Date() >= deadline { failed = true }
        viewModel.handleViewDisappear()
        // Rend le process moteur AVANT de rendre la main : le suivant (un écran
        // de l'utilisateur, ou la partie suivante) l'attend.
        for _ in 0..<120 {
            if !StockfishEngine.isProcessBusy { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        if failed {
            let count = (failures[job.id] ?? 0) + 1
            failures[job.id] = count
            // Trois échecs : on y renonce, au lieu de réessayer sans fin.
            return count >= 3
        }
        return finished
    }
}
