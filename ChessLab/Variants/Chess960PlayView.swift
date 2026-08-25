import ChessKit
import SwiftUI

/// Écran de partie Chess960 — la structure de ``PlayView`` (plateau au
/// centre, rangées joueurs, barre de contrôle unique, menu d'export et
/// abandon), avec le numéro de Scharnagl toujours visible : c'est l'identité
/// de la partie, et il se partage (« essaie la 356 »).
struct Chess960PlayView: View {
    @Bindable var viewModel: Chess960PlayViewModel
    let onExit: () -> Void
    /// Débranchement vers une partie à deux humains, sur la position
    /// AFFICHÉE — même contrat que ``PlayView``. `nil` = pas encore câblé
    /// (lots suivants pour Laboratoire et Analyser).
    var onOpenTwoPlayer: (String) -> Void = { _ in }
    /// Fin de partie → écran d'analyse, comme en mode « Jouer ». Porte le
    /// PGN complet (tags Variant/SetUp/FEN compris), pas seulement la FEN
    /// affichée : l'analyse doit rejouer TOUTE la partie, pas juste sa fin.
    var onAnalyze: (String) -> Void = { _ in }

    @State private var appSettings = AppSettings.shared
    @State private var showResignConfirmation = false
    @State private var copiedMessage: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                boardBlock(size: geo.size)
                playerRow(for: viewModel.userColor)
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
        .navigationTitle("Chess960 · n° \(viewModel.settings.positionNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                exportMenu
                QuickSwitchMenu(onOpenTwoPlayer: { onOpenTwoPlayer(viewModel.displayedFEN) })
            }
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
        // AU-DESSUS de tout (`.overlay`, pas un frère de niveau supérieur) :
        // un `if` de dernier niveau après une longue chaîne de modificateurs
        // compile (le corps d'une vue est un ViewBuilder implicite) mais ne
        // se superpose PAS au reste — sans conteneur explicite, SwiftUI n'a
        // aucune règle d'empilement à appliquer. Défaut sans conséquence
        // visible tant que le moteur démarre (cas normal), mais faux malgré
        // tout : corrigé au passage du 25/08.
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

    /// Bilan de fin de partie — même patron que ``PlayView/gameOverPanel``
    /// (résultat, Accueil, Analyser), sans Revanche : relancer une partie
    /// Chess960 repasse par le réglage de la position, pas par un simple
    /// redémarrage.
    @ViewBuilder
    private var gameOverPanel: some View {
        if let outcome = viewModel.outcome {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.title2)
                        .foregroundStyle(Theme.textSecondary)
                    Text(outcome.summary(userColor: viewModel.userColor))
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

    /// Marqueur invisible exposant le nombre de coups joués, pour les tests
    /// d'interface — même convention que ``PlayView/moveCountMarker``. C'est
    /// lui qui prouve qu'un coup S'EST BIEN JOUÉ : le défaut du 25/08
    /// (chaque rendu recréait le view model) remettait la partie à zéro sans
    /// que rien à l'écran ne le crie — ni erreur, ni écran figé, juste un
    /// coup qui semblait avaler.
    private var moveCountMarker: some View {
        Color.clear
            .accessibilityIdentifier("chess960_moveCount")
            .accessibilityValue("\(viewModel.totalPlies)")
    }

    /// Le FEN affiché — pour les tests d'interface qui vérifient qu'un
    /// débranchement (« Changer de mode ») emporte bien LA POSITION EXACTE,
    /// sans présumer du nombre de demi-coups déjà joués (le moteur peut avoir
    /// déjà répondu). Comparer deux FEN est déterministe ; rejouer un coup
    /// supplémentaire pour le vérifier ne l'est pas.
    private var fenMarker: some View {
        Color.clear
            .accessibilityIdentifier("chess960_fen")
            .accessibilityValue(viewModel.displayedFEN)
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
