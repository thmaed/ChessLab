import Foundation
import Observation

/// Surveille l'état thermique de l'appareil pour lever le pied sur le moteur
/// (Lot 2.C).
///
/// Stockfish est, de loin, ce que l'app fait de plus coûteux : une série de
/// laboratoire ou une analyse en continu peut faire chauffer l'appareil au
/// point qu'iOS finisse par brider le CPU — l'app devient alors lente ET
/// chaude. Mieux vaut réduire nous-mêmes, pendant qu'on décide encore de ce
/// qu'on sacrifie.
@Observable
@MainActor
final class ThermalMonitor {
    static let shared = ThermalMonitor()

    private(set) var state: ProcessInfo.ThermalState

    /// Vrai quand il faut lever le pied. `serious` = le système bride déjà ;
    /// `critical` = il va couper. `fair` ne déclenche rien : c'est l'état
    /// normal d'un appareil qui calcule.
    var isThrottling: Bool {
        state == .serious || state == .critical
    }

    /// Facteur appliqué aux budgets de réflexion — le prompt : « réduire les
    /// budgets ». Moitié moins de temps par coup pendant la surchauffe.
    var movetimeFactor: Double {
        isThrottling ? 0.5 : 1
    }

    /// Équivalent pour les budgets exprimés en NŒUDS (classification des
    /// coups). Séparé de ``movetimeFactor`` à dessein : appliquer une
    /// réduction de TEMPS à une recherche bornée en nœuds serait
    /// contradictoire — les deux limites se combattraient, et la première
    /// atteinte gagnerait au hasard de la charge, ruinant justement la
    /// reproductibilité qu'on cherche en passant aux nœuds.
    ///
    /// La surchauffe rabote donc le TRAVAIL demandé, pas le temps accordé :
    /// le verdict reste comparable d'une exécution à l'autre, seulement
    /// rendu sur une recherche moins profonde.
    var nodeFactor: Double {
        isThrottling ? 0.5 : 1
    }

    /// Threads du prochain démarrage de moteur : un seul en surchauffe.
    ///
    /// « Prochain » démarrage seulement : changer `Threads` sur un Stockfish
    /// en pleine recherche n'a pas de comportement défini côté UCI.
    func threads(preferred: Int) -> Int {
        isThrottling ? 1 : preferred
    }

    /// Profondeur de l'analyse en continu, rabotée en surchauffe : la position
    /// affichée est réévaluée en boucle à chaque navigation, autant y mettre
    /// moins de travail quand l'appareil chauffe. Plafond à 16 plis en
    /// surchauffe — la profondeur suffisante pour des flèches justes sans
    /// tourner les cœurs à fond.
    func liveDepth(preferred: Int) -> Int {
        isThrottling ? min(preferred, 16) : preferred
    }

    /// Jeton d'observation, dans une boîte `Sendable` pour que le `deinit`
    /// (contexte non isolé) puisse le retirer sans toucher à l'état isolé au
    /// `MainActor`.
    private final class ObserverBox: @unchecked Sendable {
        var token: NSObjectProtocol?
    }
    private let observerBox = ObserverBox()

    /// - parameter forcedState: état imposé (tests, ou argument de lancement).
    ///   Quand il est fourni, aucune notification n'est observée : l'état ne
    ///   bougera pas sous les pieds du test.
    init(forcedState: ProcessInfo.ThermalState? = nil) {
        let forced = forcedState ?? Self.launchArgumentState()

        if let forced {
            state = forced
            return
        }

        state = ProcessInfo.processInfo.thermalState
        observerBox.token = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // `thermalState` se relit à la notification : elle ne transporte
            // pas la valeur.
            let updated = ProcessInfo.processInfo.thermalState
            Task { @MainActor [weak self] in self?.state = updated }
        }
    }

    deinit {
        if let token = observerBox.token { NotificationCenter.default.removeObserver(token) }
    }

    /// `-simulateThermalState <nominal|fair|serious|critical>` : sans ça, la
    /// bannière et la réduction ne se vérifieraient qu'en faisant réellement
    /// chauffer un appareil — autrement dit jamais. Même parti pris que
    /// ``ScanTestImage`` et ``EngineStartFailureSimulator``.
    private static func launchArgumentState() -> ProcessInfo.ThermalState? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "-simulateThermalState"),
              index + 1 < arguments.count
        else { return nil }

        switch arguments[index + 1] {
        case "nominal": return .nominal
        case "fair": return .fair
        case "serious": return .serious
        case "critical": return .critical
        default: return nil
        }
    }
}
