import SwiftUI

/// A1 (2.0) — l'interface de l'analyse automatique : l'indicateur d'avancement
/// quand une partie est en cours. Posé à la racine de l'accueil.
///
/// La PROPOSITION n'est plus une alerte au démarrage (25/10/2026 : hors contexte,
/// jargon, aucun bénéfice dit). Elle vit sur l'écran de fin de partie —
/// ``AutoAnalysisOfferCard`` — au moment où l'utilisateur a une partie à analyser.
struct AutoAnalysisHost: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var service = AutoAnalysisService.shared

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if service.isRunning || !service.queue.isEmpty { banner }
            }
            .onChange(of: scenePhase) { _, phase in
                service.setActive(phase == .active)
            }
    }

    private var banner: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyse de votre partie en cours")
                    .font(.subheadline.weight(.semibold))
                if let progress = service.progress {
                    Text("\(progress.done) / \(progress.total) coups")
                        .font(.caption).foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            Button("Arrêter") { service.stop() }
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("auto_analysis_stop")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .accessibilityIdentifier("auto_analysis_banner")
    }
}

extension View {
    func autoAnalysisHost() -> some View { modifier(AutoAnalysisHost()) }
}
