import ChessKit
import SwiftUI

/// Mode APPRENDRE : plateau interactif où l'utilisateur joue lui-même chaque
/// coup de son camp, carte de commentaire, panneau « pourquoi pas autre
/// chose ? », et fin de ligne avec relecture d'un trait.
struct OpeningLearnView: View {
    @Bindable var viewModel: OpeningLearnViewModel
    let onExit: () -> Void
    let onContinueVsStockfish: (String) -> Void

    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                board
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 16)

                if let comment = viewModel.currentComment, !comment.isEmpty {
                    commentCard(comment)
                }

                if viewModel.isLineComplete {
                    resultCard
                } else {
                    VStack(spacing: 12) {
                        attemptsIndicator
                        HStack(spacing: 10) {
                            hintButton
                            alternativesButton
                        }
                        if viewModel.showAlternatives, !viewModel.alternatives.isEmpty {
                            alternativesPanel
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .appBackground()
        .navigationTitle("Apprendre")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay { promotionOverlay }
        .overlay { if viewModel.isLineComplete { CelebrationView() } }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey(viewModel.course.name))
                .font(.caption.weight(.bold)).foregroundStyle(Theme.accent).textCase(.uppercase)
            Text(viewModel.color == .white ? "Trait aux blancs" : "Trait aux noirs")
                .font(.headline).foregroundStyle(Theme.textPrimary)
            Text(viewModel.progressText)
                .font(.caption2.weight(.medium)).foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 20)
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

    private func commentCard(_ comment: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "text.bubble.fill").foregroundStyle(Theme.accent)
            Text(comment).font(.subheadline).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .cardStyle()
        .padding(.horizontal, 16)
        .transition(.opacity)
    }

    private var attemptsIndicator: some View {
        HStack(spacing: 8) {
            Text("Essais").font(.caption2.weight(.semibold)).foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase).tracking(0.4)
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < viewModel.attemptsRemaining ? Theme.accent : Color.white.opacity(0.12))
                    .frame(width: 9, height: 9)
                    .animation(Theme.spring, value: viewModel.attemptsRemaining)
            }
        }
    }

    private var hintButton: some View {
        Button { viewModel.showHint() } label: {
            Label("Indice", systemImage: "lightbulb")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Theme.surfaceElevated, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .disabled(!viewModel.isUserTurn)
    }

    private var alternativesButton: some View {
        Button { withAnimation(Theme.spring) { viewModel.toggleAlternatives() } } label: {
            Label("Pourquoi pas autre chose ?", systemImage: "questionmark.circle")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.violet)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Theme.violet.opacity(0.14), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.violet.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .disabled(viewModel.alternatives.isEmpty)
        .opacity(viewModel.alternatives.isEmpty ? 0.4 : 1)
    }

    private var alternativesPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Autres coups possibles").font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            ForEach(viewModel.alternatives, id: \.uci) { edge in
                HStack(spacing: 10) {
                    Text(edge.san).font(.subheadline.weight(.semibold).monospaced()).foregroundStyle(Theme.textPrimary)
                        .frame(minWidth: 48, alignment: .leading)
                    if edge.role == .trap { badge("Piège", Theme.danger) }
                    Spacer()
                    if let pop = edge.popularityClub {
                        Text("\(Int((pop * 100).rounded()))%").font(.caption2.monospaced()).foregroundStyle(Theme.textTertiary)
                    }
                    if let eval = edge.eval {
                        Text(OpeningExplorerView.formatEval(eval)).font(.caption2.weight(.semibold).monospaced())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            if viewModel.alternatives.allSatisfy({ $0.popularityClub == nil && $0.eval == nil }) {
                Text("Statistiques indisponibles sur ce pilote — elles apparaîtront après régénération.")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
            }
        }
        .cardStyle()
    }

    private func badge(_ text: LocalizedStringKey, _ color: Color) -> some View {
        Text(text).font(.caption2.weight(.bold)).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
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

    private var resultCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.16)).frame(width: 46, height: 46)
                    Image(systemName: "graduationcap.fill").font(.title2).foregroundStyle(Theme.accent)
                }
                Text("Chapitre terminé !").font(.title3.bold()).foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            HStack(spacing: 10) {
                Button { viewModel.replayLine() } label: {
                    Label("Revoir la ligne", systemImage: "play.circle")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)
                Button { viewModel.restart() } label: {
                    Text("Rejouer").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.accentGradient, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
            if let fen = viewModel.resultingFEN {
                Button { onContinueVsStockfish(fen) } label: {
                    Label("Continuer contre l'ordinateur depuis ici", systemImage: "cpu")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.violet)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.violet.opacity(0.14), in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.violet.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.pressable)
            }
            Button(action: onExit) {
                Text("Retour").font(.subheadline.weight(.medium)).foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Héberge le mode Apprendre : construit le ViewModel une seule fois.
struct OpeningLearnHost: View {
    let courseID: String
    let onExit: () -> Void
    let onContinueVsStockfish: (String) -> Void

    @State private var viewModel: OpeningLearnViewModel?

    var body: some View {
        Group {
            if let viewModel {
                OpeningLearnView(viewModel: viewModel, onExit: onExit, onContinueVsStockfish: onContinueVsStockfish)
            } else {
                ContentUnavailableView("Cours indisponible", systemImage: "questionmark.folder").appBackground()
            }
        }
        .onAppear {
            guard viewModel == nil, let course = OpeningCourseLoader.course(id: courseID) else { return }
            viewModel = OpeningLearnViewModel(course: course)
        }
    }
}
