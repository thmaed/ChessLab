import ChessKit
import SwiftUI

/// Écran de partie du Duck Chess.
///
/// Même anatomie que les autres écrans de variante — bandeaux joueurs,
/// plateau borné par la hauteur, barre de contrôle unique, ruban de coups —
/// avec en plus le bandeau de PHASE, qui est ici l'information la plus utile
/// de l'écran : sans lui, on ne sait pas si l'app attend un déplacement ou la
/// pose du canard.
struct DuckChessPlayView: View {
    @Bindable var viewModel: DuckChessViewModel
    let onExit: () -> Void
    var onAnalyze: (DuckChessAnalysisSeed) -> Void = { _ in }

    @State private var appSettings = AppSettings.shared
    @State private var showResignConfirmation = false
    @State private var showDrawConfirmation = false
    @State private var copiedMessage: String?

    private let variant = DuckChessVariant.shared

    private var blunderBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingBlunderWarning != nil },
            set: { if !$0 { viewModel.dismissBlunderWarning() } }
        )
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                playerRow(for: viewModel.userColor.opposite)
                phaseBanner
                boardBlock
                playerRow(for: viewModel.userColor)
                gameOverPanel
                controlBar
                movesStrip
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // Colonne bornée par la HAUTEUR de la fenêtre : le plateau est
            // carré, donc déjà borné par elle. Sans cette borne, les bandeaux
            // et la barre de contrôle s'étireraient seuls sur toute la largeur
            // d'une fenêtre Mac. Même mesure que les autres variantes.
            .frame(maxWidth: geo.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(moveCountMarker)
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
            if viewModel.isVersusEngine {
                Button("Abandonner", role: .destructive) { viewModel.userResigns() }
            } else {
                Button("\(LocalizationController.string("Blancs"))", role: .destructive) {
                    viewModel.resign(.white)
                }
                Button("\(LocalizationController.string("Noirs"))", role: .destructive) {
                    viewModel.resign(.black)
                }
            }
            Button("Annuler", role: .cancel) {}
        }
        .alert("Nulle refusée", isPresented: $viewModel.drawOfferDeclinedByEngine) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Le moteur préfère continuer la partie.")
        }
        .confirmationDialog(
            viewModel.isVersusEngine
                ? Text("Proposer nulle au moteur ?")
                : Text("Les deux joueurs sont d'accord pour la nulle ?"),
            isPresented: $showDrawConfirmation,
            titleVisibility: .visible
        ) {
            if viewModel.isVersusEngine {
                Button("Proposer nulle") { viewModel.offerDrawToEngine() }
            } else {
                // À deux sur le même appareil, personne n'a besoin d'être
                // convaincu : la nulle est actée d'un tap.
                Button("Confirmer la nulle") { viewModel.agreeToDraw() }
            }
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
                PromotionPickerView(color: viewModel.sideToMove) { kind in
                    _ = pending
                    viewModel.completePromotion(to: kind)
                }
            }
        }
        .overlay(alignment: .top) {
            if viewModel.isEngineUnavailable {
                EngineUnavailableBanner(
                    message: "L'ordinateur n'a pas démarré : il ne jouera pas.",
                    isRetrying: false, onRetry: {}
                )
            }
        }
    }

    // MARK: Blocs

    /// Ce que l'app attend, en toutes lettres. Le seul écran de l'app où le
    /// tour se joue en deux gestes : sans cette phrase, un joueur qui vient
    /// de déplacer une pièce croit que c'est à l'autre.
    private var phaseBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.phase == .placeDuck ? "bird.fill" : "hand.tap.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(variant.tint)
                .accessibilityHidden(true)
            Text(viewModel.instruction)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            variant.tint.opacity(viewModel.phase == .placeDuck ? 0.20 : 0.08),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        // Marqueur en fond : posés sur la pile, identifiant et valeur ne
        // remontent pas à l'accessibilité — même piège que la bande de
        // réserve du Crazyhouse. Voir ``moveCountMarker``.
        .background(
            Color.clear
                .accessibilityIdentifier("duck_phase")
                // `Text(verbatim:)` : ces deux valeurs sont des JETONS lus
                // par les tests d'interface, pas des mots à traduire. Sans
                // lui, Xcode les extrayait dans le catalogue et une version
                // anglaise pouvait les changer sous les tests.
                .accessibilityValue(Text(verbatim: viewModel.phase == .placeDuck ? "duck" : "move"))
        )
    }

    /// Le côté du plateau, c'est ce qui RESTE une fois les rangées fixes
    /// posées. Mesuré, jamais deviné : une grande taille de texte fait des
    /// rangées plus hautes, donc un plateau plus petit, sans facteur dédié.
    private var boardBlock: some View {
        GeometryReader { slot in
            let evalReserve: CGFloat = showsEvalBar ? EvalBarView.defaultHeight + 8 : 0
            let side = max(0, min(slot.size.width, slot.size.height - evalReserve))
            VStack(spacing: 8) {
                if showsEvalBar {
                    EvalBarView(evalCp: viewModel.currentEvalCp, evalMate: nil)
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
                    draggableColor: viewModel.isVersusEngine ? viewModel.userColor : nil,
                    onTapSquare: { viewModel.selectSquare($0) },
                    onDropPiece: { viewModel.attemptUserMove(from: $0, to: $1) },
                    duckSquare: viewModel.displayedDuck,
                    // Ni échec, ni mat en Duck Chess : un anneau rouge autour
                    // du roi mentirait sur la règle.
                    showsCheckIndicator: false
                )
                .frame(width: side, height: side)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// La barre d'éval demande le moteur : sans adversaire artificiel (partie
    /// à deux), il n'y en a pas.
    private var showsEvalBar: Bool {
        viewModel.settings.showEvalBar && viewModel.isVersusEngine
    }

    private func playerRow(for color: Piece.Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: color == viewModel.engineColor ? "cpu" : "person.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color == viewModel.engineColor ? variant.tint : Theme.info)
                .accessibilityHidden(true)
            Text(rowLabel(for: color))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            if viewModel.isEngineThinking, color == viewModel.engineColor {
                ProgressView().controlSize(.mini).tint(Theme.textSecondary)
            }
            if viewModel.sideToMove == color, viewModel.outcome == nil, !viewModel.isReviewing {
                Text(LocalizationController.string("au trait"))
                    .font(.caption)
                    .foregroundStyle(variant.tint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
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
                    Text(outcome.summary(
                        whiteName: playerName(for: .white), blackName: playerName(for: .black)
                    ))
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    panelButton("Accueil", icon: "house.fill") { onExit() }
                    panelButton("Analyser", icon: "chart.xyaxis.line", filled: true) {
                        let seed = viewModel.analysisSeed
                        Task {
                            // Un seul processus moteur à la fois : celui de la
                            // partie s'efface avant que l'analyse ne démarre le
                            // sien. Voir ``DuckChessViewModel/stopEngineBeforeAnalysis()``.
                            await viewModel.stopEngineBeforeAnalysis()
                            onAnalyze(seed)
                        }
                    }
                }
            }
            .cardStyle()
            .overlay(Theme.cardShape.strokeBorder(Theme.strokeStrong, lineWidth: 1))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier("duck_gameOver")
        }
    }

    private func panelButton(_ title: LocalizedStringKey, icon: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
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
            hintsEnabled: viewModel.hintsAvailable,
            isFinished: viewModel.outcome != nil,
            isEngineThinking: viewModel.isEngineThinking,
            onPrevious: { viewModel.reviewPrevious() },
            onNext: { viewModel.reviewNext() },
            onResumeHere: { viewModel.resumeFromReview() },
            onUndoResume: { viewModel.cancelResumeFromReview() },
            onToggleHint: { viewModel.toggleHint() },
            onShowMoveList: {},
            onOfferDraw: { showDrawConfirmation = true },
            onResign: { showResignConfirmation = true }
        )
    }

    private func rowLabel(for color: Piece.Color) -> String {
        playerName(for: color)
    }

    private func playerName(for color: Piece.Color) -> String {
        guard viewModel.isVersusEngine else {
            return color == .white
                ? LocalizationController.string("Blancs")
                : LocalizationController.string("Noirs")
        }
        return color == viewModel.engineColor
            ? LocalizationController.string("Ordinateur")
            : LocalizationController.string("Vous")
    }

    private var movesStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.numberedMoves, id: \.number) { entry in
                        HStack(spacing: 4) {
                            Text("\(entry.number).").foregroundStyle(Theme.textSecondary)
                            Text(entry.white).foregroundStyle(Theme.textPrimary)
                            if let black = entry.black {
                                Text(black).foregroundStyle(Theme.textPrimary)
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
            .accessibilityIdentifier("duck_moveCount")
            .accessibilityValue("\(viewModel.totalPlies)")
    }
}
