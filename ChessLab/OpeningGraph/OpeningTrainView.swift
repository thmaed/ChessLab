import ChessKit
import SwiftUI
import SwiftData

/// Mode ENTRAÎNER : plateau où l'utilisateur retrouve le coup de sa position,
/// note sa performance (FSRS), et enchaîne la file du jour. Correction immédiate
/// sur erreur.
struct OpeningTrainView: View {
    @Bindable var viewModel: OpeningTrainViewModel
    let onExit: () -> Void

    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }

    var body: some View {
        VStack(spacing: 14) {
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

    private var header: some View {
        VStack(spacing: 6) {
            Text(modeTitle)
                .font(.caption.weight(.bold)).foregroundStyle(Theme.accent).textCase(.uppercase)
            if viewModel.phase != .empty && viewModel.phase != .complete {
                HStack(spacing: 8) {
                    Text(viewModel.orientation == .white ? "Trait aux blancs" : "Trait aux noirs")
                        .font(.headline).foregroundStyle(Theme.textPrimary)
                }
                ProgressView(value: Double(viewModel.reviewedCount), total: Double(max(viewModel.total, 1)))
                    .tint(Theme.accent)
                    .frame(maxWidth: 220)
                Text("\(viewModel.reviewedCount) / \(viewModel.total)")
                    .font(.caption2.weight(.medium).monospaced()).foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 20)
    }

    private var modeTitle: LocalizedStringKey {
        switch viewModel.mode {
        case .daily: "Révision du jour"
        case .hardest: "Positions difficiles"
        case .fullLine: "Ligne complète, sans filet"
        }
    }

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
            draggableColor: viewModel.board.position.sideToMove,
            onTapSquare: { viewModel.selectSquare($0) },
            onDropPiece: { viewModel.attemptMove(from: $0, to: $1) }
        )
    }

    @ViewBuilder
    private var bottomArea: some View {
        VStack(spacing: 12) {
            if let comment = viewModel.currentComment, !comment.isEmpty, viewModel.phase != .awaiting {
                commentCard(comment)
            }
            switch viewModel.phase {
            case .awaiting:
                VStack(spacing: 10) {
                    Text("Retrouvez le coup").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    if viewModel.allowsHints {
                        Button { viewModel.showHint() } label: {
                            Label("Indice", systemImage: "lightbulb")
                                .font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Theme.surfaceElevated, in: Capsule())
                                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.pressable)
                    }
                }
            case .wrong:
                if let card = viewModel.currentCard {
                    Text("Le coup était \(card.expectedSAN)")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.danger)
                }
                continueButton(title: "Continuer")
            case .correct:
                continueButton(title: "Continuer")
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
    }

    /// Une seule action : la note FSRS est déduite automatiquement de la
    /// performance (voir `OpeningTrainViewModel.autoRating`), plus de choix
    /// manuel Encore/Difficile/Bien/Facile.
    private func continueButton(title: LocalizedStringKey) -> some View {
        Button { viewModel.advance() } label: {
            Text(title)
                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Theme.accentGradient, in: Capsule())
                .glow(Theme.accent, radius: 8)
        }
        .buttonStyle(.pressable)
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Rien à réviser").font(.title3.bold()).foregroundStyle(Theme.textPrimary)
            Text("Aucune position due pour l'instant. Explore ou apprends une ouverture pour remplir ta file.")
                .font(.subheadline).foregroundStyle(Theme.textTertiary).multilineTextAlignment(.center)
            backButton
        }
        .padding(24)
    }

    private var completeState: some View {
        VStack(spacing: 12) {
            Image(systemName: "party.popper").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Séance terminée !").font(.title3.bold()).foregroundStyle(Theme.textPrimary)
            Text("\(viewModel.reviewedCount) position(s) révisée(s).")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
            backButton
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
    let onExit: () -> Void
    @Environment(\.modelContext) private var modelContext
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
                viewModel = OpeningTrainViewModel(mode: mode, context: modelContext)
            }
        }
    }
}
