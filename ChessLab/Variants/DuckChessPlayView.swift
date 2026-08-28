import ChessKit
import SwiftUI

/// Écran de partie du Duck Chess, à deux joueurs sur le même appareil.
///
/// Même anatomie que les autres écrans de variante — bandeaux joueurs,
/// plateau borné par la hauteur, barre de coups — avec en plus le bandeau de
/// PHASE, qui est ici l'information la plus utile de l'écran : sans lui, on
/// ne sait pas si l'app attend un déplacement ou la pose du canard.
struct DuckChessPlayView: View {
    @State private var viewModel = DuckChessViewModel()
    let onExit: () -> Void

    @State private var appSettings = AppSettings.shared
    private let variant = DuckChessVariant.shared

    var body: some View {
        VStack(spacing: 10) {
            playerRow(for: .black)
            phaseBanner
            boardBlock
            playerRow(for: .white)
            gameOverPanel
            movesStrip
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appBackground()
        .navigationTitle(Text(variant.displayName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay {
            if let pending = viewModel.pendingPromotion {
                PromotionPickerView(color: viewModel.sideToMove) { kind in
                    _ = pending
                    viewModel.completePromotion(to: kind)
                }
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
                .accessibilityValue(viewModel.phase == .placeDuck ? "duck" : "move")
        )
    }

    private var boardBlock: some View {
        GeometryReader { slot in
            let side = max(0, min(slot.size.width, slot.size.height))
            ChessBoardView(
                board: viewModel.board,
                orientation: .white,
                theme: appSettings.boardTheme,
                selectedSquare: viewModel.selectedSquare,
                legalTargetSquares: viewModel.legalTargetSquares,
                lastMove: viewModel.lastMove,
                hintMoves: [],
                interactionEnabled: viewModel.outcome == nil,
                showCoordinates: true,
                draggableColor: nil,
                onTapSquare: { viewModel.selectSquare($0) },
                onDropPiece: { viewModel.attemptUserMove(from: $0, to: $1) },
                duckSquare: viewModel.duckSquare
            )
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func playerRow(for color: Piece.Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color == .white ? Theme.info : Theme.violet)
                .accessibilityHidden(true)
            Text(color == .white
                 ? LocalizationController.string("Blancs")
                 : LocalizationController.string("Noirs"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            if viewModel.sideToMove == color, viewModel.outcome == nil {
                Text(LocalizationController.string("au trait"))
                    .font(.caption)
                    .foregroundStyle(variant.tint)
            }
            Spacer()
            Button {
                viewModel.resign(color)
            } label: {
                Image(systemName: "flag.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.danger)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.outcome != nil)
            .accessibilityLabel(Text("Abandonner"))
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
                    Text(outcome.summary(whiteName: LocalizationController.string("Blancs"),
                                         blackName: LocalizationController.string("Noirs")))
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 0)
                }
                Button {
                    onExit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "house.fill").font(.system(size: 15, weight: .semibold))
                        Text("Accueil").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.tintGradient(variant.tint))
                    )
                }
                .buttonStyle(.pressable)
            }
            .cardStyle()
            .overlay(Theme.cardShape.strokeBorder(Theme.strokeStrong, lineWidth: 1))
            .accessibilityIdentifier("duck_gameOver")
        }
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
        .background(
            Color.clear
                .accessibilityIdentifier("duck_moveCount")
                .accessibilityValue("\(viewModel.totalPlies)")
        )
    }
}
