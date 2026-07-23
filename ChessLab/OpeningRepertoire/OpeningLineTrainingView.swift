import ChessKit
import SwiftUI

/// Écran de lecture d'une ouverture de bibliothèque : plateau + bandeau
/// de progression, un bouton "Indice" facultatif, et une carte de fin de
/// ligne (jamais un échec bloquant — voir ``OpeningLineTrainingViewModel``).
struct OpeningLineTrainingView: View {
    @Bindable var viewModel: OpeningLineTrainingViewModel
    let onExit: () -> Void
    let onContinueVsStockfish: (String) -> Void

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

            if viewModel.isLineComplete {
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
        .navigationTitle("Ouvertures")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay { promotionOverlay }
        .overlay {
            if viewModel.isLineComplete {
                CelebrationView()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey(viewModel.familyName))
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
                .textCase(.uppercase)
            Text(viewModel.color == .white ? "Trait aux blancs" : "Trait aux noirs")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(viewModel.progressText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.textTertiary)
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

    /// Flèche le coup à jouer sans le jouer ni terminer la ligne — se
    /// masque une fois affiché (voir `viewModel.hintMoves`).
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

    private var resultCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.16)).frame(width: 46, height: 46)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                }
                .glow(Theme.accent, radius: 10)
                Text("Ligne terminée !")
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

                Button { viewModel.restart() } label: {
                    Text("Rejouer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accentGradient, in: Capsule())
                        .glow(Theme.accent, radius: 9)
                }
                .buttonStyle(.pressable)
            }

            if let resultingFEN = viewModel.resultingFEN {
                // Action secondaire distincte (on quitte le drill pour une
                // vraie partie) : capsule teintée violet + icône moteur, à ne
                // pas confondre avec le vert « Rejouer » du haut.
                Button { onContinueVsStockfish(resultingFEN) } label: {
                    Label("Continuer contre Stockfish depuis ici", systemImage: "cpu")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.violet)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.violet.opacity(0.14), in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.violet.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.pressable)
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
