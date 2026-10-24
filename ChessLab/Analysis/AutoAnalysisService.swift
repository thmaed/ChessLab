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
    }

    /// Parties en attente, la première étant celle en cours.
    private(set) var queue: [Job] = []
    /// Avancement de la partie en cours (demi-coups classés / total).
    private(set) var progress: (done: Int, total: Int)?
    private(set) var isActive = true

    private var context: ModelContext?
    private var runner: Task<Void, Never>?

    var isRunning: Bool { runner != nil }

    /// Ajoute une partie à la file (sans doublon) et démarre si possible.
    func enqueue(pgn: String, key: String, context: ModelContext) {
        guard AppSettings.shared.autoAnalysisChoice == .on else { return }
        guard !queue.contains(where: { $0.id == key }) else { return }
        self.context = context
        queue.append(Job(id: key, pgn: pgn))
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

    /// Vrai si la partie est terminée (ou irrécupérable) — faux si interrompue.
    private func analyze(_ job: Job, context: ModelContext) async -> Bool {
        let viewModel = AnalysisViewModel(source: .pgn(job.pgn))
        let total = max(1, viewModel.moveListRows.count)
        progress = (0, total)
        // Au plus 10 minutes : une partie de 130 demi-coups en prend 4 sur le
        // plus lent des téléphones mesurés.
        let deadline = Date().addingTimeInterval(600)
        var finished = false
        while Date() < deadline {
            if Task.isCancelled || !mayRun { break }
            if viewModel.isEngineUnavailable { finished = true; break }
            progress = (min(total, viewModel.moveEvaluations.count), total)
            if viewModel.analysisMetrics != nil {
                _ = viewModel.persistMetrics(in: context)
                finished = true
                break
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        if !finished, Date() >= deadline { finished = true }   // trop longue : on renonce
        viewModel.handleViewDisappear()
        // Laisse la file du moteur l'arrêter avant d'en lancer un autre.
        try? await Task.sleep(for: .milliseconds(800))
        return finished
    }
}
