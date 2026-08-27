import ChessKit
import SwiftUI

/// Écran de résolution d'un puzzle : plateau + bandeau "Trouvez mieux
/// que...", compteur d'essais, et overlay de résultat (réussite ou
/// solution révélée après 3 essais) avec lien vers la partie d'origine.
struct PuzzleSolveView: View {
    @Bindable var viewModel: PuzzleSolveViewModel
    let onExit: () -> Void
    let onViewSourceGame: (String) -> Void
    var onOpenLab: (String) -> Void = { _ in }
    var onPlayVsEngine: (String) -> Void = { _ in }
    var onOpenTwoPlayer: (String) -> Void = { _ in }

    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }
    /// iPad plein écran & Mac en paysage : deux colonnes (plateau | infos).
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                GeometryReader { geo in
                    if geo.size.width > geo.size.height {
                        wideLayout
                    } else {
                        singleColumn
                    }
                }
            } else {
                singleColumn
            }
        }
        .appBackground()
        .navigationTitle("Puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                QuickSwitchMenu(
                    onPlayVsEngine: { onPlayVsEngine(viewModel.currentFEN) },
                    onOpenTwoPlayer: { onOpenTwoPlayer(viewModel.currentFEN) },
                    onOpenLab: { onOpenLab(viewModel.currentFEN) }
                )
            }
        }
        .overlay { promotionOverlay }
        .overlay {
            // Confettis par-dessus tout l'écran à la résolution (une seule
            // fois par puzzle : l'overlay disparaît puis réapparaît au
            // suivant, rejouant l'animation).
            if viewModel.isFinished, viewModel.isSolved {
                CelebrationView()
            }
        }
    }

    // MARK: Dispositions

    /// iPhone, et iPad en portrait : une colonne, plateau carré au centre.
    private var singleColumn: some View {
        VStack(spacing: 14) {
            header
            boardSquare
                .padding(.horizontal, 16)
            puzzleControls
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    /// iPad plein écran & Mac en paysage : plateau à gauche (toute la hauteur),
    /// consigne + essais + indice/résultat dans une colonne de droite — sinon
    /// le plateau carré laissait toute la moitié droite de l'écran vide.
    private var wideLayout: some View {
        HStack(alignment: .center, spacing: 0) {
            boardSquare
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 6)
                .padding(.leading, 6)
                // Le plateau descendait jusqu'au dernier pixel de la fenêtre :
                // aucune marge sous les lettres de colonnes, il touchait le
                // bord. 16 pt lui rendent son assise.
                .padding(.bottom, 16)

            // Colonne élastique plutôt que figée à 360 pt : à cette largeur
            // fixe elle affamait le plateau dans les fenêtres moyennes et
            // restait à moitié vide dans les grandes.
            ScrollView {
                VStack(spacing: 18) {
                    header
                    puzzleControls
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .frame(minWidth: 300, maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Plateau carré, borné au plus petit côté de la place offerte.
    private var boardSquare: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            board
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Sous le plateau (portrait) ou dans la colonne de droite (paysage) :
    /// résultat une fois fini, sinon compteur d'essais et bouton d'indice.
    @ViewBuilder
    private var puzzleControls: some View {
        if viewModel.isFinished {
            resultCard
        } else {
            VStack(spacing: 12) {
                attemptsIndicator
                if viewModel.hintMoves.isEmpty {
                    hintButton
                }
            }
        }
    }

    /// Deux lignes au lieu de quatre.
    ///
    /// Il y avait ici quatre lignes empilées — capsules de contexte, consigne,
    /// « Trait aux blancs », avancement — toutes de tailles et de gris
    /// différents : aucune ne ressortait, et le regard devait les lire l'une
    /// après l'autre pour trouver LA seule qui dit quoi faire. Le camp au
    /// trait, en particulier, n'est pas une phrase à part : c'est un attribut
    /// de la consigne, et une pastille le dit plus vite qu'un mot.
    ///
    /// Reste donc : la consigne, seule en gros ; puis tout le contexte sur
    /// une ligne discrète.
    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.orientation == .white ? Color.white : Color.black)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                Text(instruction)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(sideToMoveLabel))
            .accessibilityValue(Text(instruction))

            HStack(spacing: 7) {
                Text(LocalizedStringKey(viewModel.puzzle.theme.label))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .textCase(.uppercase)

                // Niveau et phase en PASTILLES colorées (plus grandes que
                // l'ancien texte gris minuscule, à la demande) : la difficulté
                // se lit à sa couleur (vert → rouge), la phase à son icône.
                if let tier = viewModel.puzzle.difficultyTier {
                    contextPill(LocalizedStringKey(tier.label), tint: tint(for: tier))
                }
                contextPill(
                    LocalizedStringKey(viewModel.puzzle.phase.label),
                    icon: viewModel.puzzle.phase.icon,
                    tint: tint(for: viewModel.puzzle.phase)
                )
                if let progress = viewModel.sessionProgressText {
                    Text(progress)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 20)
    }

    /// Pastille capsule teintée pour le niveau / la phase.
    private func contextPill(_ label: LocalizedStringKey, icon: String? = nil, tint: Color) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.caption2.weight(.bold))
            }
            Text(label).font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.15), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.30), lineWidth: 1))
    }

    /// Difficulté : progression verte → rouge, pour la lire d'un coup d'œil.
    private func tint(for tier: DifficultyTier) -> Color {
        switch tier {
        case .beginner: Theme.accent
        case .intermediate: Theme.info
        case .advanced: Theme.warning
        case .expert: Theme.rose
        }
    }

    /// Phase : une teinte par moment de la partie.
    private func tint(for phase: GamePhase) -> Color {
        switch phase {
        case .opening: Theme.teal
        case .middlegame: Theme.violet
        case .endgame: Theme.warning
        }
    }

    private var instruction: LocalizedStringKey {
        if let playedMoveSAN = viewModel.puzzle.playedMoveSAN {
            "Trouvez mieux que \(SANFormatter.display(playedMoveSAN))"
        } else {
            "Trouvez le meilleur coup"
        }
    }

    private var sideToMoveLabel: LocalizedStringKey {
        viewModel.orientation == .white ? "Trait aux blancs" : "Trait aux noirs"
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
            interactionEnabled: !viewModel.isFinished && !viewModel.isAutoPlaying,
            showCoordinates: true,
            draggableColor: viewModel.board.position.sideToMove,
            rejectedMove: viewModel.rejectedMove,
            onRejectedAnimationEnd: { viewModel.finishRejectedAttempt() },
            onTapSquare: { viewModel.selectSquare($0) },
            onDropPiece: { viewModel.attemptMove(from: $0, to: $1) }
        )
    }

    /// Autant de pastilles que d'essais accordés — une seule dans le régime par
    /// défaut, où l'intitulé le dit franchement plutôt que d'afficher un
    /// compteur à un cran.
    private var attemptsIndicator: some View {
        HStack(spacing: 8) {
            Text(viewModel.allowedAttempts == 1 ? "Un seul essai" : "Essais")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .tracking(0.4)
            ForEach(0..<viewModel.allowedAttempts, id: \.self) { i in
                Circle()
                    .fill(i < viewModel.attemptsRemaining ? Theme.accent : Color.white.opacity(0.12))
                    .frame(width: 9, height: 9)
                    .glow(Theme.accent, radius: 5, isActive: i < viewModel.attemptsRemaining)
                    .animation(Theme.spring, value: viewModel.attemptsRemaining)
            }
        }
    }

    /// Flèche le coup à jouer sans le jouer ni terminer le puzzle — se
    /// masque une fois affiché (voir `viewModel.hintMoves`, remis à zéro
    /// au coup suivant).
    private var hintButton: some View {
        Button {
            viewModel.showHint()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                Text("Indice")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Theme.surfaceElevated, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.pressable)
    }

    @ViewBuilder
    private var promotionOverlay: some View {
        if let pending = viewModel.pendingPromotion {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                // Taper en dehors du sélecteur annule la promotion, comme en
                // mode Jouer : sans cela, un pion glissé par erreur sur la
                // dernière rangée coûtait un essai.
                .onTapGesture { viewModel.cancelPromotion() }
                .overlay {
                    PromotionPickerView(color: pending.move.piece.color) { kind in
                        viewModel.completePromotion(to: kind)
                    }
                }
        }
    }

    /// Affiché SOUS l'échiquier une fois le puzzle terminé (jamais en
    /// overlay par-dessus) : la position reste visible, notamment la
    /// flèche de solution quand elle a été révélée après le 3e échec.
    /// "Nouveau puzzle" tire un puzzle suivant et réinitialise l'état
    /// directement dans ce même écran, sans repasser par la file.
    @ViewBuilder
    private var resultCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((viewModel.isSolved ? Theme.accent : Theme.textSecondary).opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: viewModel.isSolved ? "checkmark.circle.fill" : "flag.checkered")
                        .font(.title2)
                        .foregroundStyle(viewModel.isSolved ? Theme.accent : Theme.textSecondary)
                }
                .glow(Theme.accent, radius: 10, isActive: viewModel.isSolved)
                Text(viewModel.isSolved ? "Résolu !" : "Solution révélée")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            HStack(spacing: 10) {
                Button(action: onExit) {
                    Text("Retour")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)

                if viewModel.hasNextPuzzle {
                    Button { viewModel.loadNextPuzzle() } label: {
                        Text("Nouveau puzzle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.accentGradient, in: Capsule())
                            .glow(Theme.accent, radius: 9)
                    }
                    .buttonStyle(.pressable)
                }
            }

            if let sourcePGN = viewModel.puzzle.sourceGamePGN {
                Button("Voir dans la partie d'origine") {
                    onViewSourceGame(sourcePGN)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
