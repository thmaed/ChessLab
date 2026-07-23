import Foundation

/// Simule des échecs de démarrage du moteur, via l'argument de lancement
/// `-simulateEngineFailure <n>` (n = nombre de démarrages à faire échouer).
///
/// Raison d'être : une vraie panne de Stockfish (réseau NNUE absent, mémoire
/// insuffisante) ne se provoque pas depuis un test — il faudrait casser le
/// bundle. Sans cette porte dérobée, la bannière « Moteur indisponible » et
/// toute la reprise du Lot 2.A ne seraient vérifiables qu'à la main, donc
/// jamais. Même parti pris que ``ScanTestImage`` pour le scanner.
///
/// `<n>` plutôt qu'un simple drapeau : c'est ce qui rend la REPRISE testable
/// — le premier démarrage échoue, « Réessayer » réussit, la partie continue.
/// Un drapeau permanent n'aurait prouvé que l'affichage de la bannière.
///
/// Acteur, et non variable globale : plusieurs ``EngineController`` (donc
/// plusieurs acteurs) le consultent, chacun sur son propre contexte.
actor EngineStartFailureSimulator {
    static let shared = EngineStartFailureSimulator()

    private var remainingFailures: Int

    init(remainingFailures: Int? = nil) {
        self.remainingFailures = remainingFailures ?? Self.requestedFailureCount()
    }

    /// Consomme un échec s'il en reste. Renvoie `false` en usage normal —
    /// l'argument de lancement absent, le compteur vaut zéro.
    func consumeFailure() -> Bool {
        guard remainingFailures > 0 else { return false }
        remainingFailures -= 1
        return true
    }

    private static func requestedFailureCount() -> Int {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "-simulateEngineFailure"),
              index + 1 < arguments.count,
              let count = Int(arguments[index + 1])
        else { return 0 }
        return count
    }
}
