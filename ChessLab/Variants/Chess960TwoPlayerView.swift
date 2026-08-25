import ChessKit
import SwiftUI

/// Écran de partie Chess960 à deux humains — la structure de
/// ``Chess960PlayView`` (rangées joueurs, plateau, barre de contrôle unique,
/// ruban de coups), avec la rotation face-à-face de ``TwoPlayerGameView``.
struct Chess960TwoPlayerView: View {
    @Bindable var viewModel: Chess960TwoPlayerViewModel
    let onExit: () -> Void
    /// Fin de partie → écran d'analyse, comme en mode « Jouer ».
    var onAnalyze: (String) -> Void = { _ in }

    @State private var appSettings = AppSettings.shared
    @State private var showResignConfirmation = false
    @State private var showDrawConfirmation = false
    @State private var copiedMessage: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var topColor: Piece.Color { viewModel.orientation.opposite }
    private var bottomColor: Piece.Color { viewModel.orientation }
    private var isTabletopMode: Bool { viewModel.settings.rotationMode == .tabletop }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                playerRow(for: topColor, atTop: true)
                boardBlock(size: geo.size)
                playerRow(for: bottomColor, atTop: false)
                gameOverPanel
                controlBar
                movesStrip
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(moveCountMarker)
            .background(fenMarker)
        }
        .appBackground()
        .navigationTitle("Deux joueurs — Chess960")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { exportMenu }
        }
        .onAppear { viewModel.handleViewAppear() }
        .onDisappear { viewModel.handleViewDisappear() }
        .confirmationDialog(
            "Qui abandonne ?",
            isPresented: $showResignConfirmation,
            titleVisibility: .visible
        ) {
            Button("\(viewModel.settings.whiteName) (\(LocalizationController.string("Blancs")))", role: .destructive) {
                viewModel.resign(.white)
            }
            Button("\(viewModel.settings.blackName) (\(LocalizationController.string("Noirs")))", role: .destructive) {
                viewModel.resign(.black)
            }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog(
            "Les deux joueurs sont d'accord pour la nulle ?",
            isPresented: $showDrawConfirmation,
            titleVisibility: .visible
        ) {
            Button("Confirmer la nulle") { viewModel.agreeToDraw() }
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
                PromotionPickerView(color: viewModel.displayedBoard.position.sideToMove) { kind in
                    _ = pending
                    viewModel.completePromotion(to: kind)
                }
            }
        }
    }

    // MARK: Blocs

    private func boardBlock(size: CGSize) -> some View {
        let side = min(size.width - 24, size.height * (dynamicTypeSize.isAccessibilitySize ? 0.5 : 0.62))
        return ChessBoardView(
            board: viewModel.displayedBoard,
            orientation: viewModel.orientation,
            theme: appSettings.boardTheme,
            selectedSquare: viewModel.selectedSquare,
            legalTargetSquares: viewModel.legalTargetSquares,
            lastMove: viewModel.displayedLastMove,
            hintMoves: [],
            interactionEnabled: viewModel.outcome == nil && !viewModel.isReviewing,
            showCoordinates: true,
            // Tous côté haut, aucune restriction — les DEUX camps sont
            // « l'utilisateur », comme dans TwoPlayerGameView.
            allPiecesRotated: isTabletopMode && !viewModel.isReviewing
                && viewModel.displayedBoard.position.sideToMove == topColor,
            draggableColor: nil,
            onTapSquare: { viewModel.selectSquare($0) },
            onDropPiece: { viewModel.attemptUserMove(from: $0, to: $1) }
        )
        .frame(width: side, height: side)
        .frame(maxWidth: .infinity)
    }

    private func playerRow(for color: Piece.Color, atTop: Bool) -> some View {
        let name = color == .white ? viewModel.settings.whiteName : viewModel.settings.blackName
        return HStack(spacing: 10) {
            Image(systemName: "person.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color == .white ? Theme.info : Theme.violet)
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                // En mode table, le HUD du joueur du haut se lit à l'endroit
                // depuis SA place, face à l'appareil — même logique que
                // TwoPlayerGameView.
                .rotationEffect(.degrees(isTabletopMode && atTop ? 180 : 0))
            Spacer()
            if let clock = viewModel.clock {
                ClockLabel(clock: clock, color: color)
                    .rotationEffect(.degrees(isTabletopMode && atTop ? 180 : 0))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var gameOverPanel: some View {
        if let outcome = viewModel.outcome {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.title2)
                        .foregroundStyle(Theme.textSecondary)
                    Text(outcome.summary(whiteName: viewModel.settings.whiteName, blackName: viewModel.settings.blackName))
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    panelButton("Accueil", icon: "house.fill") { onExit() }
                    panelButton("Analyser", icon: "chart.xyaxis.line", filled: true) {
                        onAnalyze(viewModel.exportedPGN)
                    }
                }
            }
            .cardStyle()
            .overlay(Theme.cardShape.strokeBorder(Theme.strokeStrong, lineWidth: 1))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func panelButton(_ title: LocalizedStringKey, icon: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(filled ? Theme.background : Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if filled {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accentGradient)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(filled ? Color.clear : Theme.stroke, lineWidth: 1))
            .glow(Theme.accent, radius: 8, isActive: filled)
        }
        .buttonStyle(.pressable)
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
            isEngineThinking: false,
            onPrevious: { viewModel.reviewPrevious() },
            onNext: { viewModel.reviewNext() },
            onResumeHere: { viewModel.resumeFromReview() },
            onUndoResume: { viewModel.cancelResumeFromReview() },
            onToggleHint: {},
            onShowMoveList: {},
            onOfferDraw: { showDrawConfirmation = true },
            onResign: { showResignConfirmation = true }
        )
    }

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

    // MARK: Export

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

    private var moveCountMarker: some View {
        Color.clear
            .accessibilityIdentifier("chess960_twoPlayer_moveCount")
            .accessibilityValue("\(viewModel.totalPlies)")
    }

    private var fenMarker: some View {
        Color.clear
            .accessibilityIdentifier("chess960_fen")
            .accessibilityValue(viewModel.displayedFEN)
    }
}

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
