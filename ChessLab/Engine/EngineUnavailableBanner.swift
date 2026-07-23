import SwiftUI

/// Bannière « Moteur indisponible — Réessayer », partagée par Jouer et
/// Analyser (Lot 2.A).
///
/// Le prompt exige de pouvoir « redémarrer l'instance et reprendre depuis le
/// FEN courant » : sans ce bouton, la seule issue était de quitter l'écran et
/// de tout relancer — en perdant la partie en cours sur l'écran Jouer.
///
/// Vue partagée plutôt que deux copies : la première version était déjà
/// dupliquée à l'identique dans les deux écrans, et seul le texte changeait.
struct EngineUnavailableBanner: View {
    let message: String
    let isRetrying: Bool
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.danger)

            VStack(alignment: .leading, spacing: 2) {
                Text("Moteur indisponible")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: onRetry) {
                Group {
                    if isRetrying {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Theme.textPrimary)
                    } else {
                        Text("Réessayer")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 84, minHeight: 44)
                .background(Theme.surfaceElevated, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(.pressable)
            .disabled(isRetrying)
            .accessibilityLabel("Réessayer")
            .accessibilityIdentifier("retryEngine")
        }
        .cardStyle()
        .overlay(Theme.cardShape.strokeBorder(Theme.danger.opacity(0.45), lineWidth: 1))
    }
}
