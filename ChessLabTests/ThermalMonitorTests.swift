import Foundation
import Testing
@testable import ChessLab

/// Réduction thermique (Lot 2.C du final-1407).
///
/// Testable parce que l'état est INJECTABLE : sans ça, il faudrait faire
/// réellement chauffer un appareil pour vérifier quoi que ce soit — autrement
/// dit ne jamais le vérifier.
@MainActor
struct ThermalMonitorTests {

    @Test("Seuls `serious` et `critical` font lever le pied", arguments: [
        (ProcessInfo.ThermalState.nominal, false),
        (ProcessInfo.ThermalState.fair, false),
        (ProcessInfo.ThermalState.serious, true),
        (ProcessInfo.ThermalState.critical, true)
    ])
    func throttlingStartsAtSerious(state: ProcessInfo.ThermalState, expected: Bool) {
        let monitor = ThermalMonitor(forcedState: state)

        #expect(monitor.isThrottling == expected)
    }

    /// `fair` est l'état NORMAL d'un appareil qui calcule : brider là-dessus
    /// reviendrait à brider en permanence.
    @Test func aWarmButHealthyDeviceKeepsItsFullBudget() {
        let monitor = ThermalMonitor(forcedState: .fair)

        #expect(monitor.movetimeFactor == 1)
        #expect(monitor.threads(preferred: 4) == 4)
    }

    @Test func throttlingHalvesTheThinkingBudgetAndDropsToOneThread() {
        let monitor = ThermalMonitor(forcedState: .serious)

        #expect(monitor.movetimeFactor == 0.5)
        #expect(monitor.threads(preferred: 4) == 1)
        #expect(monitor.threads(preferred: 1) == 1)
    }

    /// La réduction doit être RÉELLE, pas seulement affichée : c'est
    /// l'exigence du lot (« + réduction effective »).
    @Test func theHalvedBudgetIsWhatActuallyReachesTheEngine() {
        let normal = ThermalMonitor(forcedState: .nominal)
        let hot = ThermalMonitor(forcedState: .critical)
        let labMovetime = 150

        #expect(Int(Double(labMovetime) * normal.movetimeFactor) == 150)
        #expect(Int(Double(labMovetime) * hot.movetimeFactor) == 75)
    }

    /// Un état imposé ne doit pas se faire écraser par l'état réel de la
    /// machine de test — sinon les tests ci-dessus seraient à la merci de la
    /// température du Mac.
    @Test func aForcedStateIgnoresTheRealDevice() {
        let monitor = ThermalMonitor(forcedState: .critical)

        #expect(monitor.state == .critical)
        #expect(monitor.isThrottling)
    }
}
