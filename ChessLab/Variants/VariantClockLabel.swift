import ChessKit
import SwiftUI

/// Pendule d'un camp sur un écran de variante.
///
/// Une seule déclaration pour toutes les variantes : elle existait en CINQ
/// copies `private` rigoureusement identiques (Fairy, Légalité, Coup Volé,
/// Chess960, Chess960 à deux). Le Duck Chess en avait besoin d'une sixième —
/// l'occasion de n'en garder qu'une.
struct ClockLabel: View {
    let clock: GameClock
    let color: Piece.Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            Text(Self.format(clock.displayRemaining(for: color)))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(clock.displayRemaining(for: color) < 30 ? Theme.danger : Theme.textPrimary)
        }
    }

    private static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
