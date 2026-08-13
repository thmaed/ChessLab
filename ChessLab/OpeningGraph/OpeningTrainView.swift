import ChessKit
import SwiftUI
import SwiftData

/// Mode ENTRAÎNER — « ligne guidée » : plateau continu, l'utilisateur joue son
/// camp, l'adversaire répond tout seul. Historique des coups, commentaire au fil
/// des coups, et sur une variante on demande s'il faut la jouer ou rester sur la
/// principale. Voir ``OpeningTrainViewModel``.
struct OpeningTrainView: View {
    @Bindable var viewModel: OpeningTrainViewModel
    let onExit: () -> Void

    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }

    var body: some View {
        VStack(spacing: 12) {
            header
            switch viewModel.phase {
            case .empty:
                emptyState
            case .complete:
                completeState
            default:
                board
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 16)
                if !viewModel.playedSANs.isEmpty { moveTrail }
                bottomArea
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .appBackground()
        .navigationTitle("Entraîner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay { promotionOverlay }
    }

    // MARK: En-tête

    private var header: some View {
        VStack(spacing: 4) {
            Text(modeTitle)
                .font(.caption.weight(.bold)).foregroundStyle(Theme.accent).textCase(.uppercase).tracking(0.4)
            if viewModel.phase != .empty && viewModel.phase != .complete {
                Text(LocalizedStringKey(viewModel.courseName))
                    .font(.headline).foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                statusLine
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch viewModel.phase {
        case .awaiting:
            Label("À vous de jouer", systemImage: "hand.point.up.left.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
        case .opponentMoving:
            Text("L'adversaire joue…")
                .font(.caption.weight(.medium)).foregroundStyle(Theme.textTertiary)
        default:
            EmptyView()
        }
    }

    private var modeTitle: LocalizedStringKey {
        switch viewModel.mode {
        case .daily: "Révision du jour"
        case .hardest: "Positions difficiles"
        case .fullLine: "Entraîner la ligne"
        }
    }

    // MARK: Plateau + historique

    private var board: some View {
        ChessBoardView(
            board: viewModel.board,
            orientation: viewModel.orientation,
            theme: boardTheme,
            selectedSquare: viewModel.selectedSquare,
            legalTargetSquares: viewModel.legalTargetSquares,
            lastMove: viewModel.lastMove,
            hintMoves: viewModel.hintMoves,
            interactionEnabled: viewModel.isUserTurn,
            showCoordinates: true,
            draggableColor: viewModel.orientation,
            onTapSquare: { viewModel.selectSquare($0) },
            onDropPiece: { viewModel.attemptMove(from: $0, to: $1) }
        )
    }

    /// Fil des coups joués (affichage seul), le dernier mis en évidence.
    private var moveTrail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.playedSANs.enumerated()), id: \.offset) { index, san in
                        let isCurrent = index == viewModel.playedSANs.count - 1
                        Text(trailLabel(index: index, san: san))
                            .font(.caption.weight(.semibold).monospaced())
                            .foregroundStyle(isCurrent ? Theme.background : Theme.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(isCurrent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surface),
                                        in: Capsule())
                            .id(index)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: viewModel.playedSANs.count) { _, count in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(count - 1, anchor: .trailing) }
            }
        }
    }

    private func trailLabel(index: Int, san: String) -> String {
        index % 2 == 0 ? "\(index / 2 + 1). \(san)" : san
    }

    // MARK: Bas de l'écran (selon la phase)

    @ViewBuilder
    private var bottomArea: some View {
        VStack(spacing: 12) {
            if let comment = viewModel.currentComment, !comment.isEmpty {
                commentCard(comment)
            }
            switch viewModel.phase {
            case .awaiting:
                Button { viewModel.showHint() } label: {
                    Label("Indice", systemImage: "lightbulb")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Theme.surfaceElevated, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)
            case .variation:
                variationPrompt
            case .wrong:
                wrongControls
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
    }

    private var variationPrompt: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.triangle.branch").foregroundStyle(Theme.info)
                Text(variationMessage)
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .cardStyle()
            HStack(spacing: 10) {
                Button { viewModel.keepMainLine() } label: {
                    Text("Rester sur la principale")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)
                Button { viewModel.playVariation() } label: {
                    Text("Jouer la variante")
                        .font(.subheadline.weight(.bold)).foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.accentGradient, in: Capsule())
                        .glow(Theme.accent, radius: 6)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private var variationMessage: String {
        let played = viewModel.variationPlayedSAN ?? "?"
        let main = viewModel.variationMainSAN ?? "?"
        let fr = AppSettings.shared.appLanguage.resolvedCode == "fr"
        return fr
            ? "« \(played) » est une variante du répertoire — la ligne principale est \(main). Que veux-tu faire ?"
            : "“\(played)” is a repertoire sideline — the main line is \(main). What would you like to do?"
    }

    @ViewBuilder
    private var wrongControls: some View {
        if let correct = viewModel.wrongCorrectSAN {
            Text(wrongMessage(correct))
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.danger)
                .multilineTextAlignment(.center)
        }
        Button { viewModel.continueAfterWrong() } label: {
            Text("Continuer")
                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Theme.accentGradient, in: Capsule())
                .glow(Theme.accent, radius: 8)
        }
        .buttonStyle(.pressable)
    }

    private func wrongMessage(_ correct: String) -> String {
        AppSettings.shared.appLanguage.resolvedCode == "fr"
            ? "Le bon coup était \(correct)."
            : "The right move was \(correct)."
    }

    private func commentCard(_ comment: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "text.bubble.fill").foregroundStyle(Theme.accent)
            Text(comment).font(.subheadline).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    // MARK: États de fin

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Rien à réviser").font(.title3.bold()).foregroundStyle(Theme.textPrimary)
            Text("Aucune position due pour l'instant. Ouvre une ouverture et entraîne-la pour remplir ta file.")
                .font(.subheadline).foregroundStyle(Theme.textTertiary).multilineTextAlignment(.center)
            backButton
        }
        .padding(24)
    }

    private var completeState: some View {
        VStack(spacing: 12) {
            Image(systemName: "party.popper").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Séance terminée !").font(.title3.bold()).foregroundStyle(Theme.textPrimary)
            Text("\(viewModel.reviewedCount) coup(s) joué(s).")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 12) {
                Button { viewModel.restart() } label: {
                    Label("Recommencer", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)
                Button(action: onExit) {
                    Text("Retour").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.background)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Theme.accentGradient, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .overlay { CelebrationView() }
    }

    private var backButton: some View {
        Button(action: onExit) {
            Text("Retour").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.background)
                .padding(.horizontal, 28).padding(.vertical, 12)
                .background(Theme.accentGradient, in: Capsule())
        }
        .buttonStyle(.pressable)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var promotionOverlay: some View {
        if let pending = viewModel.pendingPromotion {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { viewModel.cancelPromotion() }
                .overlay {
                    PromotionPickerView(color: pending.move.piece.color) { kind in
                        viewModel.completePromotion(to: kind)
                    }
                }
        }
    }
}

/// Héberge l'entraînement : construit le ViewModel avec le `ModelContext` (pour
/// lire/écrire la progression synchronisée).
struct OpeningTrainHost: View {
    let mode: OpeningTrainViewModel.Mode
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    let onExit: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: OpeningTrainViewModel?

    var body: some View {
        Group {
            if let viewModel {
                OpeningTrainView(viewModel: viewModel, onExit: onExit)
            } else {
                ProgressView().appBackground()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = sessionStore.value(for: sessionKey) {
                    OpeningTrainViewModel(mode: mode, context: modelContext)
                }
            }
        }
    }
}
