import ChessKit
import SwiftUI

/// Écran de partie pour Course des rois/Antéchecs/Atomique — même structure
/// que ``FairyVariantPlayView`` (plateau au centre, rangées joueurs, barre
/// de contrôle, menu d'export, abandon), adaptée à
/// ``EngineLegalityPlayViewModel`` : pas de dupliquée générique possible
/// avec le lot A, la vue-modèle sous-jacente diffère trop (voir son
/// commentaire de tête).
struct EngineLegalityPlayView: View {
    @Bindable var viewModel: EngineLegalityPlayViewModel
    let onExit: () -> Void
    var onAnalyze: (VariantAnalysisSeed) -> Void = { _ in }

    @State private var appSettings = AppSettings.shared
    @State private var showResignConfirmation = false
    @State private var copiedMessage: String?

    private var variant: EngineLegalityVariant { viewModel.variant }

    private var blunderBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingBlunderWarning != nil },
            set: { if !$0 { viewModel.dismissBlunderWarning() } }
        )
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                playerRow(for: viewModel.engineColor)
                boardBlock
                playerRow(for: viewModel.userColor)
                gameOverPanel
                controlBar
                movesStrip
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // Colonne bornée par la HAUTEUR de la fenêtre. Le plateau est
            // carré, donc déjà borné par la hauteur : sans cette borne, les
            // bandeaux joueurs, la barre de contrôle et la bande des coups
            // s'étiraient seuls sur toute la largeur d'une fenêtre Mac large
            // — le transport à un bout, l'abandon à l'autre, séparés par un
            // mètre de vide. Ils restent maintenant à la largeur du plateau.
            // Sans effet en portrait (hauteur > largeur) : ni l'iPhone ni
            // l'iPad debout ne changent.
            .frame(maxWidth: geo.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(moveCountMarker)
            .background(outcomeMarker)
        }
        .appBackground()
        .navigationTitle(Text(variant.displayName))
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
            "Coup risqué",
            isPresented: blunderBinding,
            presenting: viewModel.pendingBlunderWarning
        ) { _ in
            Button("Ignorer", role: .cancel) { viewModel.dismissBlunderWarning() }
            Button("Reprendre le coup", role: .destructive) { viewModel.takebackAfterBlunderWarning() }
        } message: { pending in
            Text(pending.message)
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
        .overlay {
            if viewModel.isEngineUnavailable {
                EngineUnavailableBanner(
                    message: "L'ordinateur n'a pas démarré : il ne jouera pas.",
                    isRetrying: false,
                    onRetry: {}
                )
            }
        }
    }

    // MARK: Blocs

    /// Le côté du plateau, c'est ce qui RESTE une fois les rangées fixes
    /// posées — bandeaux joueurs, barre de contrôle, bande des coups,
    /// et le panneau de fin de partie quand il apparaît. Ce lecteur de géométrie mesure l'espace
    /// réellement laissé par la pile, au lieu de parier une fraction de la
    /// fenêtre (`hauteur × 0,62`) : ce pari ignorait les rangées et tronquait
    /// le plateau dès que la fenêtre devenait courte — sur Mac, dès sa taille
    /// minimale. Il rend aussi les grandes tailles de texte gratuites : les
    /// rangées grandissent, le plateau se réduit d'autant, sans facteur dédié.
    private var boardBlock: some View {
        GeometryReader { slot in
            let evalReserve: CGFloat = viewModel.settings.showEvalBar ? EvalBarView.defaultHeight + 8 : 0
            let side = max(0, min(slot.size.width, slot.size.height - evalReserve))
            VStack(spacing: 8) {
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
                    lastMove: viewModel.displayedLastMove,
                    hintMoves: viewModel.isReviewing ? [] : viewModel.hintMoves,
                    interactionEnabled: viewModel.outcome == nil && !viewModel.isReviewing,
                    showCoordinates: true,
                    draggableColor: viewModel.userColor,
                    onTapSquare: { viewModel.selectSquare($0) },
                    onDropPiece: { viewModel.attemptUserMove(from: $0, to: $1) }
                )
                .frame(width: side, height: side)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func playerRow(for color: Piece.Color) -> some View {
        HStack(spacing: 10) {
            // Décoratif : le texte juste après porte déjà l'information
            // (« Ordinateur »/« Vous ») — sans ce masquage, VoiceOver
            // annonçait le nom brut du symbole SF ("cpu") avant le libellé.
            Image(systemName: color == viewModel.engineColor ? "cpu" : "person.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color == viewModel.engineColor ? variant.tint : Theme.info)
                .accessibilityHidden(true)
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

    @ViewBuilder
    private var gameOverPanel: some View {
        if let outcome = viewModel.outcome {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.title2)
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityHidden(true)
                    Text(outcome.summary(userColor: viewModel.userColor))
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    panelButton("Accueil", icon: "house.fill") { onExit() }
                    panelButton("Analyser", icon: "chart.xyaxis.line", filled: true) {
                        let seed = VariantAnalysisSeed(
                            variantID: variant.id, variantDisplayName: variant.displayName, startFEN: variant.startFEN,
                            uciLog: viewModel.uciLog, sanLog: viewModel.sanLog, moveLog: viewModel.moveLog,
                            fenLog: viewModel.fenLog, outcome: outcome
                        )
                        Task {
                            // Voir ``EngineLegalityPlayViewModel/stopEngineBeforeAnalysis()``.
                            await viewModel.stopEngineBeforeAnalysis()
                            onAnalyze(seed)
                        }
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
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(filled ? Theme.background : Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if filled {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.tintGradient(variant.tint))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(filled ? Color.clear : Theme.stroke, lineWidth: 1))
            .glow(variant.tint, radius: 8, isActive: filled)
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
            hintsWanted: viewModel.hintsWanted,
            hintsEnabled: viewModel.settings.hintsEnabled,
            isFinished: viewModel.outcome != nil,
            isEngineThinking: viewModel.isEngineThinking,
            onPrevious: { viewModel.reviewPrevious() },
            onNext: { viewModel.reviewNext() },
            onResumeHere: { viewModel.resumeFromReview() },
            onUndoResume: { viewModel.cancelResumeFromReview() },
            onToggleHint: { viewModel.toggleHint() },
            onShowMoveList: {},
            onOfferDraw: {},
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
            .accessibilityIdentifier("fairyVariant_moveCount")
            .accessibilityValue("\(viewModel.totalPlies)")
    }

    private var outcomeMarker: some View {
        Color.clear
            .accessibilityIdentifier("fairyVariant_outcome")
            .accessibilityValue(viewModel.outcome.map { $0.reason.storageLabel } ?? "")
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
