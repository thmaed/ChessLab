import ChessKit
import SwiftUI

/// Revue d'une partie Chess960 terminée — plateau, barre d'évaluation
/// (toujours visible, contrairement au jeu en cours), flèches des meilleurs
/// coups, liste des coups, navigation coup par coup.
struct Chess960AnalysisView: View {
    let viewModel: Chess960AnalysisViewModel

    @State private var appSettings = AppSettings.shared
    @State private var copiedMessage: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                boardBlock(size: geo.size)
                navigationBar
                movesList
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(totalPliesMarker)
        }
        .appBackground()
        .navigationTitle("Analyse — Chess960")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { exportMenu }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.handleViewDisappear() }
        .alert(
            "Copié",
            isPresented: Binding(get: { copiedMessage != nil }, set: { if !$0 { copiedMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(copiedMessage ?? "")
        }
    }

    private func boardBlock(size: CGSize) -> some View {
        let side = min(size.width - 24, size.height * (dynamicTypeSize.isAccessibilitySize ? 0.42 : 0.56))
        return VStack(spacing: 8) {
            EvalBarView(evalCp: viewModel.currentEvalCp, evalMate: viewModel.currentEvalMate)
                .frame(width: side)
            ChessBoardView(
                board: viewModel.displayedGame.board,
                orientation: .white,
                theme: appSettings.boardTheme,
                selectedSquare: nil,
                legalTargetSquares: [],
                lastMove: viewModel.displayedLastMove,
                hintMoves: viewModel.hintMoves,
                interactionEnabled: false,
                showCoordinates: true,
                onTapSquare: { _ in },
                onDropPiece: { _, _ in }
            )
            .frame(width: side, height: side)
        }
        .frame(maxWidth: .infinity)
    }

    private var navigationBar: some View {
        HStack(spacing: 16) {
            navButton("chevron.left.2", label: "Début") { viewModel.review(toPly: 0) }
                .disabled(viewModel.displayedPly == 0)
            navButton("chevron.left", label: "Coup précédent") { viewModel.reviewPrevious() }
                .disabled(viewModel.displayedPly == 0)
            Spacer(minLength: 0)
            if viewModel.isAnalyzing {
                ProgressView().controlSize(.small).tint(Theme.textSecondary)
            }
            Text("\(viewModel.displayedPly) / \(viewModel.totalPlies)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            navButton("chevron.right", label: "Coup suivant") { viewModel.reviewNext() }
                .disabled(viewModel.displayedPly == viewModel.totalPlies)
            navButton("chevron.right.2", label: "Fin") { viewModel.review(toPly: viewModel.totalPlies) }
                .disabled(viewModel.displayedPly == viewModel.totalPlies)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func navButton(_ systemImage: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }

    private var movesList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.fixed(28)), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(viewModel.numberedMoves, id: \.number) { entry in
                    Text("\(entry.number).")
                        .foregroundStyle(Theme.textSecondary)
                    moveButton(entry.white, ply: entry.number * 2 - 1)
                    if let black = entry.black {
                        moveButton(black, ply: entry.number * 2)
                    } else {
                        Color.clear
                    }
                }
            }
            .font(.subheadline.monospacedDigit())
            .padding(10)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func moveButton(_ san: String, ply: Int) -> some View {
        Button {
            viewModel.review(toPly: ply)
        } label: {
            Text(san)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(
                    viewModel.displayedPly == ply ? Theme.accent.opacity(0.22) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .foregroundStyle(Theme.textPrimary)
        }
        .buttonStyle(.plain)
    }

    /// Preuve du round-trip pour les tests d'interface : le nombre de coups
    /// que l'écran a effectivement rejoués depuis le PGN reçu.
    private var totalPliesMarker: some View {
        Color.clear
            .accessibilityIdentifier("chess960_analysis_totalPlies")
            .accessibilityValue("\(viewModel.totalPlies)")
    }

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
            Divider()
            ShareLink(item: viewModel.exportedPGN) {
                Label("Partager la partie", systemImage: "square.and.arrow.up.on.square")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityLabel("Exporter")
    }
}
