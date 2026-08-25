import ChessKit
import SwiftUI

/// Écran de partie Chess960 — la structure de ``PlayView`` (plateau au
/// centre, rangées joueurs, barre de contrôle unique, menu d'export et
/// abandon), avec le numéro de Scharnagl toujours visible : c'est l'identité
/// de la partie, et il se partage (« essaie la 356 »).
struct Chess960PlayView: View {
    @Bindable var viewModel: Chess960PlayViewModel
    let onExit: () -> Void

    @State private var appSettings = AppSettings.shared
    @State private var showResignConfirmation = false
    @State private var copiedMessage: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                playerRow(for: viewModel.engineColor)
                boardBlock(size: geo.size)
                playerRow(for: viewModel.userColor)
                if let outcome = viewModel.outcome {
                    outcomeBanner(outcome)
                }
                controlBar
                movesStrip
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .appBackground()
        .navigationTitle("Chess960 · n° \(viewModel.settings.positionNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { exportMenu }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.handleViewDisappear() }
        .confirmationDialog(
            "Abandonner la partie ?",
            isPresented: $showResignConfirmation,
            titleVisibility: .visible
        ) {
            Button("Abandonner", role: .destructive) { viewModel.userResigns() }
            Button("Annuler", role: .cancel) {}
        }
        .alert(
            "Copié",
            isPresented: Binding(get: { copiedMessage != nil }, set: { if !$0 { copiedMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(copiedMessage ?? "")
        }
        .overlay {
            if let pending = viewModel.pendingPromotion {
                PromotionPickerView(color: viewModel.userColor) { kind in
                    _ = pending
                    viewModel.completePromotion(to: kind)
                }
            }
        }
        if viewModel.isEngineUnavailable {
            EngineUnavailableBanner(
                message: "L'ordinateur n'a pas démarré : il ne jouera pas.",
                isRetrying: false,
                onRetry: {}
            )
        }
    }

    // MARK: Blocs

    private func boardBlock(size: CGSize) -> some View {
        let side = min(size.width - 24, size.height * (dynamicTypeSize.isAccessibilitySize ? 0.5 : 0.62))
        return VStack(spacing: 8) {
            if viewModel.settings.showEvalBar {
                EvalBarView(evalCp: viewModel.currentEvalCp, evalMate: viewModel.currentEvalMate)
                    .frame(width: side)
            }
            ChessBoardView(
                board: viewModel.displayedBoard,
                orientation: viewModel.userColor,
                theme: appSettings.boardTheme,
                selectedSquare: viewModel.selectedSquare,
                legalTargetSquares: viewModel.legalTargetSquares,
                lastMove: nil,
                hintMoves: [],
                interactionEnabled: viewModel.outcome == nil && !viewModel.isReviewing,
                showCoordinates: true,
                draggableColor: viewModel.userColor,
                onTapSquare: { viewModel.selectSquare($0) },
                onDropPiece: { viewModel.attemptUserMove(from: $0, to: $1) }
            )
            .frame(width: side, height: side)
        }
        .frame(maxWidth: .infinity)
    }

    private func playerRow(for color: Piece.Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: color == viewModel.engineColor ? "cpu" : "person.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color == viewModel.engineColor ? Theme.accent : Theme.info)
            Text(color == viewModel.engineColor
                 ? LocalizationController.string("Ordinateur")
                 : LocalizationController.string("Vous"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            if color == viewModel.engineColor, viewModel.isEngineThinking {
                ProgressView().controlSize(.mini).tint(Theme.textSecondary)
            }
            Spacer()
            if let clock = viewModel.clock {
                ClockLabel(clock: clock, color: color)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func outcomeBanner(_ outcome: GameOutcome) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.checkered")
            Text(outcome.summary(userColor: viewModel.userColor))
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var controlBar: some View {
        PlayControlBar(
            hasMoves: viewModel.totalPlies > 0,
            displayedPly: viewModel.displayedPly,
            totalPlies: viewModel.totalPlies,
            isReviewing: viewModel.isReviewing,
            canResumeFromReview: viewModel.canResumeFromReview,
            undoableResumeCount: viewModel.resumeUndo?.discardedCount,
            showMoveList: false,
            hintsWanted: false,
            hintsEnabled: false,
            isFinished: viewModel.outcome != nil,
            isEngineThinking: viewModel.isEngineThinking,
            onPrevious: { viewModel.reviewPrevious() },
            onNext: { viewModel.reviewNext() },
            onResumeHere: { viewModel.resumeFromReview() },
            onUndoResume: { viewModel.cancelResumeFromReview() },
            onToggleHint: {},
            onShowMoveList: {},
            onOfferDraw: {},
            onResign: { showResignConfirmation = true }
        )
    }

    /// Ruban des coups joués, défilant, dernier coup en tête de lecture.
    private var movesStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.numberedMoves, id: \.number) { entry in
                        HStack(spacing: 4) {
                            Text("\(entry.number).")
                                .foregroundStyle(Theme.textSecondary)
                            Text(entry.white)
                                .foregroundStyle(Theme.textPrimary)
                            if let black = entry.black {
                                Text(black)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                        .font(.footnote.weight(.medium).monospacedDigit())
                        .id(entry.number)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 26)
            .onChange(of: viewModel.totalPlies) { _, _ in
                if let last = viewModel.numberedMoves.last?.number {
                    withAnimation(Theme.gentle) { proxy.scrollTo(last, anchor: .trailing) }
                }
            }
        }
    }

    // MARK: Export — uniquement de l'export, comme partout depuis le 24/08

    private var exportMenu: some View {
        Menu {
            Button {
                UIPasteboard.general.string = viewModel.displayedFEN
                copiedMessage = LocalizationController.string("Position (FEN) copiée dans le presse-papiers.")
            } label: {
                Label("Copier la position (FEN)", systemImage: "square.grid.3x3")
            }
            Button {
                UIPasteboard.general.string = viewModel.exportedPGN
                copiedMessage = LocalizationController.string("Partie (PGN) copiée dans le presse-papiers.")
            } label: {
                Label("Copier la partie (PGN)", systemImage: "doc.on.doc")
            }
            .disabled(viewModel.totalPlies == 0)
            Divider()
            ShareLink(item: viewModel.exportedPGN) {
                Label("Partager la partie", systemImage: "square.and.arrow.up.on.square")
            }
            .disabled(viewModel.totalPlies == 0)
        } label: {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityLabel("Exporter")
    }
}

/// Pendule d'un camp — lecture seule, rafraîchie par l'horloge observable.
private struct ClockLabel: View {
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
