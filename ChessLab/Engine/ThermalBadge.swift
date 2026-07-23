import SwiftUI

/// Bandeau discret « appareil chaud, moteur bridé » (Lot 2.C), affiché sur les
/// écrans qui font tourner Stockfish.
///
/// Discret parce qu'il n'y a rien à faire : ce n'est pas une erreur, c'est
/// l'app qui lève le pied d'elle-même. Mais il faut le DIRE — sans lui, le
/// moteur deviendrait mystérieusement plus faible, et l'utilisateur mettrait
/// ça sur le compte d'un bug.
///
/// Même style que le badge « Analyse en continu » : capsule, teinte
/// d'avertissement, pas de bouton.
struct ThermalBadge: View {
    @State private var thermal = ThermalMonitor.shared

    var body: some View {
        if thermal.isThrottling {
            HStack(spacing: 6) {
                Image(systemName: "thermometer.high")
                Text("Appareil chaud — moteur bridé")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.warning)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Theme.warning.opacity(0.12), in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("thermalBadge")
            .transition(.opacity)
        }
    }
}
