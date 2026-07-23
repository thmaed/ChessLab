import ChessKit
import SwiftUI

/// Écran de résolution d'un puzzle : plateau + bandeau "Trouvez mieux
/// que...", compteur d'essais, et overlay de résultat (réussite ou
/// solution révélée après 3 essais) avec lien vers la partie d'origine.
struct PuzzleSolveView: View {
    @Bindable var viewModel: PuzzleSolveViewModel
    let onExit: () -> Void
    let onViewSourceGame: (String) -> Void

    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }

    var body: some View {
        VStack(spacing: 14) {
            header

            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                board
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 16)

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
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .appBackground()
        .navigationTitle("Puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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

    private var attemptsIndicator: some View {
        HStack(spacing: 8) {
            Text("Essais")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .tracking(0.4)
            ForEach(0..<3, id: \.self) { i in
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
