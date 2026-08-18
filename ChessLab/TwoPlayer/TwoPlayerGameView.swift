import ChessKit
import SwiftUI

/// Écran de jeu "deux humains sur le même appareil" : plateau plein
/// écran, interface minimale, éval et notation MASQUÉES pendant la
/// partie (révélées seulement sur l'écran de résultat).
struct TwoPlayerGameView: View {
    @Bindable var viewModel: TwoPlayerViewModel
    let onExit: () -> Void
    let onAnalyze: (String) -> Void
    var onRematch: (TwoPlayerGameSettings) -> Void = { _ in }
    /// Passerelles vers les autres modes, sur la position AFFICHÉE — même
    /// contrat que ``PlayView``.
    var onAnalyzePosition: (String) -> Void = { _ in }
    var onOpenLab: (String) -> Void = { _ in }
    /// Bascule vers « Contre l'ordinateur », réglages pré-remplis avec la
    /// position affichée — même logique que le Laboratoire ci-dessus.
    var onPlayVsEngine: (String) -> Void = { _ in }

    @Environment(\.scenePhase) private var scenePhase
    /// Sur iPad/Mac (classe régulière), le plateau est BORNÉ pour tenir dans
    /// la hauteur : un carré pleine largeur y déborderait sous les HUD.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }
    @State private var showResignConfirmation = false
    @State private var showDrawConfirmation = false
    @State private var showResumeConfirmation = false
    @State private var copiedMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            topZone

            boardArea

            VStack(spacing: 14) {
                hud(for: bottomColor)
                transportBar
                if viewModel.outcome == nil {
                    controlsBar
                } else {
                    gameOverPanel
                }
            }
            .animation(Theme.spring, value: viewModel.outcome != nil)
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer(minLength: 0)
        }
        .padding(.top, 6)
        .padding(.bottom, 12)
        .appBackground()
        // Le décompte démarre à l'APPARITION, pas à l'init : voir
        // ``TwoPlayerViewModel/handleViewAppear()``. Le couple avec
        // `onDisappear` met la pendule en pause quand un écran empilé par le
        // menu d'export recouvre la partie.
        .onAppear { viewModel.handleViewAppear() }
        .onDisappear { viewModel.handleViewDisappear() }
        .navigationTitle("Deux joueurs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { exportMenu }
        }
        .alert(
            "Copié",
            isPresented: Binding(
                get: { copiedMessage != nil },
                set: { if !$0 { copiedMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { copiedMessage = nil }
        } message: {
            Text(copiedMessage ?? "")
        }
        .overlay { promotionOverlay }
        .overlay { gameOverOverlay }
        .confirmationDialog(
            "Qui abandonne ?",
            isPresented: $showResignConfirmation,
            titleVisibility: .visible
        ) {
            Button("\(viewModel.settings.whiteName) (\(LocalizationController.string("Blancs")))", role: .destructive) { viewModel.resign(.white) }
            Button("\(viewModel.settings.blackName) (\(LocalizationController.string("Noirs")))", role: .destructive) { viewModel.resign(.black) }
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
        .confirmationDialog(
            "Reprendre depuis le coup \(viewModel.displayedPly) ?",
            isPresented: $showResumeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reprendre ici", role: .destructive) { viewModel.resumeFromReview() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les \(viewModel.totalPlies - viewModel.displayedPly) coup(s) suivants seront effacés.")
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                viewModel.handleAppBackgrounded()
            case .active:
                viewModel.handleAppForegrounded()
            @unknown default:
                break
            }
        }
    }

    // MARK: Export & passerelles

    /// Même menu que ``PlayView`` : copier/partager la position (FEN) ou la
    /// partie (PGN), et continuer ailleurs — analyse ou Laboratoire — sans
    /// passer par le presse-papiers. La partie reste dans la pile : le
    /// retour la retrouve telle quelle.
    ///
    /// L'évaluation reste masquée À L'ÉCRAN pendant la partie ; ouvrir
    /// l'analyse est un choix explicite des joueurs, au même titre que
    /// copier la FEN vers une autre app l'a toujours permis.
    private var exportMenu: some View {
        Menu {
            Section("Continuer ailleurs") {
                Button {
                    onAnalyzePosition(viewModel.displayedFEN)
                } label: {
                    Label("Analyser cette position", systemImage: "chart.xyaxis.line")
                }
                Button {
                    onOpenLab(viewModel.displayedFEN)
                } label: {
                    Label("Continuer au Laboratoire", systemImage: "flask")
                }
                Button {
                    onPlayVsEngine(viewModel.displayedFEN)
                } label: {
                    Label("Contre l'ordinateur", systemImage: "cpu")
                }
            }
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
            .disabled(!viewModel.hasGameToExport)
            Divider()
            ShareLink(item: viewModel.displayedFEN) {
                Label("Partager la position", systemImage: "square.and.arrow.up")
            }
            if viewModel.hasGameToExport {
                ShareLink(item: viewModel.exportedPGN) {
                    Label("Partager la partie", systemImage: "square.and.arrow.up.on.square")
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityLabel("Exporter")
        .accessibilityIdentifier("exportGame")
    }

    // MARK: Orientation / HUD

    private var topColor: Piece.Color { viewModel.orientation.opposite }
    private var bottomColor: Piece.Color { viewModel.orientation }

    private var isTabletopMode: Bool { viewModel.settings.rotationMode == .tabletop }

    /// En mode Table, HUD ET contrôles du joueur du haut sont dupliqués et
    /// tournés à 180° (rotation de pixels, pas un simple ré-agencement) :
    /// c'est ce qui fait apparaître noms, pendule et icônes des boutons à
    /// l'endroit pour le joueur assis en face, sans jamais avoir à
    /// retourner l'appareil. Dans les autres modes, la zone du haut ne
    /// montre que le HUD, comme avant.
    private var topZone: some View {
        Group {
            if isTabletopMode {
                VStack(spacing: 14) {
                    hud(for: topColor)
                    controlsBar
                }
                .rotationEffect(.degrees(180))
            } else {
                hud(for: topColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, viewModel.clock != nil ? 8 : 4)
    }

    private func hud(for color: Piece.Color) -> some View {
        let isActive = viewModel.board.position.sideToMove == color && viewModel.outcome == nil
        let captured = viewModel.capturedMaterial
        return HStack(spacing: 10) {
            Circle()
                .fill(color == .white ? Color.white : Color.black)
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                .frame(width: 11, height: 11)
            Text(color == .white ? viewModel.settings.whiteName : viewModel.settings.blackName)
                .font(.headline)
                .foregroundStyle(isActive ? Theme.textPrimary : Theme.textTertiary)
            // En mode Table, ce HUD vit dans `topZone` déjà tourné à 180° :
            // le bandeau des prises hérite donc de la rotation et se lit à
            // l'endroit pour le joueur d'en face, comme le nom et la pendule.
            CapturedTrayView(
                kinds: captured.captures(by: color),
                glyphColor: color.opposite,
                advantage: captured.advantage(for: color)
            )
            Spacer()
            if let clock = viewModel.clock {
                Text(formattedClock(clock.displayRemaining(for: color)))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(isActive ? Theme.textPrimary : Theme.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isActive ? Theme.surfaceElevated : Color.clear, in: Capsule())
        .overlay(Capsule().strokeBorder(isActive ? Theme.accent.opacity(0.40) : Color.clear, lineWidth: 1))
        .glow(Theme.accent, radius: 6, isActive: isActive)
        .animation(Theme.spring, value: isActive)
    }

    private func formattedClock(_ remaining: TimeInterval) -> String {
        let clamped = max(0, remaining)
        if clamped < 10 {
            return String(format: "%.1f", clamped)
        }
        let totalSeconds = Int(clamped.rounded())
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    // MARK: Plateau

    /// iPhone : plateau pleine largeur (le carré tient toujours en hauteur en
    /// portrait). iPad/Mac : borné à l'espace offert (`aspectRatio` + priorité
    /// de mise en page), il prend la hauteur laissée par les HUD et se centre,
    /// au lieu de déborder l'écran en paysage.
    @ViewBuilder
    private var boardArea: some View {
        if horizontalSizeClass == .regular {
            board
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        } else {
            board
        }
    }

    private var board: some View {
        ChessBoardView(
            board: viewModel.displayedBoard,
            orientation: viewModel.orientation,
            theme: boardTheme,
            selectedSquare: viewModel.selectedSquare,
            legalTargetSquares: viewModel.legalTargetSquares,
            lastMove: viewModel.displayedLastMove,
            hintMoves: [],
            interactionEnabled: viewModel.outcome == nil && !viewModel.isReviewing,
            showCoordinates: true,
            allPiecesRotated: isTabletopMode && !viewModel.isReviewing && viewModel.board.position.sideToMove == topColor,
            draggableColor: viewModel.board.position.sideToMove,
            onTapSquare: { viewModel.selectSquare($0) },
            onDropPiece: { viewModel.attemptUserMove(from: $0, to: $1) }
        )
    }

    /// Barre de transport (lecture seule) — orientée vers le joueur du bas,
    /// outil d'arbitrage commun. « Reprendre ici » ramène la partie au coup
    /// consulté (hors pendule).
    @ViewBuilder
    private var transportBar: some View {
        if viewModel.totalPlies > 0 {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    navIconButton("backward.end.fill", disabled: viewModel.displayedPly == 0) { viewModel.reviewToStart() }
                    navIconButton("chevron.left", disabled: viewModel.displayedPly == 0) { viewModel.reviewPrevious() }
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.displayedPly) },
                            set: { viewModel.review(toPly: Int($0.rounded())) }
                        ),
                        in: 0...Double(viewModel.totalPlies),
                        step: 1
                    )
                    .tint(viewModel.isReviewing ? Theme.warning : Theme.accent)
                    navIconButton("chevron.right", disabled: viewModel.displayedPly >= viewModel.totalPlies) { viewModel.reviewNext() }
                    navIconButton("forward.end.fill", disabled: !viewModel.isReviewing) { viewModel.reviewToLive() }
                }

                if viewModel.isReviewing {
                    HStack(spacing: 8) {
                        Label("Consultation — coup \(viewModel.displayedPly)/\(viewModel.totalPlies)", systemImage: "eye")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.warning)
                        Spacer()
                        if viewModel.canResumeFromReview {
                            Button { showResumeConfirmation = true } label: {
                                Text("Reprendre ici")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.background)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.accent, in: Capsule())
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(Theme.gentle, value: viewModel.isReviewing)
        }
    }

    private func navIconButton(_ systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(disabled ? Theme.textTertiary : Theme.textPrimary)
                // 44 pt : le minimum des Human Interface Guidelines (Lot 4.B).
                .frame(width: 44, height: 44)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .disabled(disabled)
    }

    private var controlsBar: some View {
        HStack(spacing: 12) {
            controlButton("flag.fill", label: "Abandonner", tint: Theme.danger, disabled: viewModel.outcome != nil) {
                showResignConfirmation = true
            }

            Spacer()

            controlButton("hand.raised.fill", label: "Nulle", disabled: viewModel.outcome != nil) {
                showDrawConfirmation = true
            }
        }
    }

    private func controlButton(
        _ systemImage: String,
        label: LocalizedStringKey,
        tint: Color = Theme.textPrimary,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(label)
            }
            // Un libellé de bouton se LIT : il doit suivre Dynamic Type. La
            // capsule qui l'entoure n'a pas de hauteur figée (des marges, pas
            // un `frame`), donc elle grandit avec lui — pas de plafond ici.
            .scaledSystemFont(size: 15, relativeTo: .subheadline, weight: .medium)
            .foregroundStyle(disabled ? Theme.textTertiary : tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .disabled(disabled)
    }

    // MARK: Overlays

    @ViewBuilder
    private var promotionOverlay: some View {
        if let pending = viewModel.pendingPromotion {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { viewModel.cancelPromotion() }
                .overlay {
                    PromotionPickerView(color: pending.move.piece.color) { kind in
                        viewModel.completePromotion(to: kind)
                    }
                    // En mode Table, si c'est le joueur d'en face qui promeut,
                    // le sélecteur est retourné pour être lisible pour lui.
                    .rotationEffect(.degrees(isTabletopMode && pending.move.piece.color == topColor ? 180 : 0))
                }
        }
    }

    /// À la fin de partie, seuls les confettis passent en superposition : le
    /// bilan (avec la notation enfin révélée) et les actions s'affichent SOUS
    /// le plateau, qui reste visible et rejouable.
    @ViewBuilder
    private var gameOverOverlay: some View {
        if let outcome = viewModel.outcome, outcome.winner != nil {
            CelebrationView()
        }
    }

    @ViewBuilder
    private var gameOverPanel: some View {
        if let outcome = viewModel.outcome {
            let isDraw = outcome.winner == nil
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: isDraw ? "hand.raised.fill" : "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(isDraw ? Theme.textSecondary : Theme.warning)
                        .glow(Theme.warning, radius: 8, isActive: !isDraw)
                    Text(outcome.summary(whiteName: viewModel.settings.whiteName, blackName: viewModel.settings.blackName))
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 0)
                }

                if !viewModel.sanMoveList.isEmpty {
                    Text(SANFormatter.display(viewModel.sanMoveList).joined(separator: " "))
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    panelButton("Accueil", icon: "house.fill") { onExit() }
                    // Toujours une position standard ici, mais on passe par
                    // `PGNExport` comme partout ailleurs — voir ``PlayView``.
                    panelButton("Analyser", icon: "chart.xyaxis.line") { onAnalyze(PGNExport.pgn(for: viewModel.game)) }
                    panelButton("Revanche", icon: "arrow.triangle.2.circlepath", filled: true) { onRematch(rematchSettings()) }
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

    /// Revanche : mêmes réglages, les deux joueurs échangent les couleurs.
    private func rematchSettings() -> TwoPlayerGameSettings {
        var settings = viewModel.settings
        swap(&settings.whiteName, &settings.blackName)
        return settings
    }
}
