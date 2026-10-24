import SwiftUI

/// A1 (2.0) — l'interface de l'analyse automatique : la PROPOSITION (une fois,
/// à l'accueil, une fois la visite guidée passée) et l'indicateur d'avancement
/// quand une partie est en cours. Posé à la racine de l'accueil.
struct AutoAnalysisHost: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.discoveryTour) private var tour
    @State private var settings = AppSettings.shared
    @State private var service = AutoAnalysisService.shared
    @State private var showProposal = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if service.isRunning || !service.queue.isEmpty { banner }
            }
            .task {
                // Attend la fin de la visite guidée : une seule question à la fois.
                try? await Task.sleep(for: .seconds(3))
                guard settings.autoAnalysisChoice == .undecided,
                      !DiscoveryTourMemory.shouldOffer, tour?.isActive != true else { return }
                showProposal = true
            }
            .onChange(of: scenePhase) { _, phase in
                service.setActive(phase == .active)
            }
            .alert("Analyser vos parties automatiquement ?", isPresented: $showProposal) {
                Button("Activer") {
                    settings.autoAnalysisChoice = .on
                    service.settingChanged()
                }
                Button("Plus tard", role: .cancel) {}
                Button("Non merci") { settings.autoAnalysisChoice = .off }
            } message: {
                Text("Après chaque partie contre l'ordinateur, ChessLab peut l'analyser en tâche de fond, sur l'appareil : environ 1 à 3 minutes par partie, avec un peu de batterie. Interrompu en économie d'énergie ou si l'appareil chauffe. Modifiable dans les Réglages.")
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
