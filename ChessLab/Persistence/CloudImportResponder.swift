import Foundation
import SwiftData

/// Ce qui arrive d'iCloud est appliqué À L'ARRIVÉE, pas au prochain passage sur un écran.
///
/// Jusqu'ici, une réception CloudKit (progression d'un autre appareil, programme Woodpecker, collection
/// importée) entrait dans la base, mais les fusions qui la rendent visible (``PuzzleProgressSync``,
/// ``OpeningProgressSync``, ``PuzzleCollectionSync``) ne tournaient qu'à l'apparition des écrans, au plus
/// une fois toutes les 5 minutes — et l'écran déjà affiché gardait ses anciens chiffres. Ici : chaque
/// réception réussie (annoncée par ``CloudSyncMonitor``) déclenche, après un court regroupement, les trois
/// fusions puis ``didApply``, que les écrans ouverts écoutent pour se relire.
///
/// Regroupement : CloudKit livre souvent par rafales (plusieurs lots de suite) ; on attend 1,5 s de calme
/// avant de fusionner, une fois.
@MainActor
enum CloudImportResponder {
    /// Postée après une fusion de données reçues : les écrans affichés se relisent.
    static let didApply = Notification.Name("chesslab.cloudDataDidApply")

    private static var context: ModelContext?
    private static var observer: NSObjectProtocol?
    private static var pending: Task<Void, Never>?

    static func start(context: ModelContext) {
        guard observer == nil else { return }
        self.context = context
        observer = NotificationCenter.default.addObserver(
            forName: CloudSyncMonitor.didReceive, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { schedule() }
        }
    }

    /// Fusionne bientôt (les appels rapprochés se regroupent en un seul).
    static func schedule(after delay: Duration = .milliseconds(1500)) {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await applyNow()
        }
    }

    /// Fusionne tout de suite (aussi utilisé par « Synchroniser maintenant »).
    static func applyNow() async {
        guard let context else { return }
        PuzzleProgressSync.reconcile(in: context)
        OpeningProgressSync.reconcile(in: context)
        await PuzzleCollectionSync.sync(in: context)
        UserOpeningStore.shared.reload()
        NotificationCenter.default.post(name: didApply, object: nil)
    }
}
