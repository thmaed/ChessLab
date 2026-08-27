import ChessKit
import SwiftUI

/// Revue d'une partie de variante terminée — même structure que
/// ``Chess960AnalysisView`` (plateau, barre d'éval toujours visible,
/// flèches, liste des coups, navigation), pour les six variantes du hub
/// hors Chess960.
struct VariantAnalysisView: View {
    let viewModel: VariantAnalysisViewModel

    @State private var appSettings = AppSettings.shared
    @State private var copiedMessage: String?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                boardBlock(size: geo.size)
                navigationBar
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        navigationBarHeight = height
                    }
                movesList
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(totalPliesMarker)
        }
        .appBackground()
        .navigationTitle(Text(LocalizationController.string("Analyse") + " — " + viewModel.variantDisplayName))
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

    /// Hauteur réelle de la barre de navigation, qui grandit avec la taille
    /// du texte. Mesurée plutôt que devinée — voir ``boardBlock(size:)``.
    @State private var navigationBarHeight: CGFloat = 44

    /// Ce qu'on laisse à la liste des coups quoi qu'il arrive. Elle défile,
    /// mais poussée hors de l'écran elle ne défilerait plus : elle aurait
    /// disparu.
    private static let minimumMovesListHeight: CGFloat = 120

    /// Le côté du plateau vient d'un budget de hauteur MESURÉ, et non d'une
    /// fraction devinée de la fenêtre.
    ///
    /// C'était `hauteur × 0,56`, avec un `0,42` de rattrapage aux tailles
    /// d'accessibilité — deux nombres qui ne disaient pas d'où ils venaient et
    /// ne connaissaient ni la hauteur réelle de la barre de navigation, ni ce
    /// qu'il fallait laisser à la liste des coups. On soustrait maintenant ce
    /// qu'on doit à ces deux-là, et le facteur d'accessibilité devient inutile :
    /// un texte plus grand fait une barre plus haute, donc un plateau plus
    /// petit, tout seul. Même raisonnement que sur les écrans de JEU des
    /// variantes, adapté au fait que la liste des coups, ici, est défilante.
    private func boardBlock(size: CGSize) -> some View {
        let reserved = navigationBarHeight
            + Self.minimumMovesListHeight
            + EvalBarView.defaultHeight
            + 28   // les deux espacements de la pile (10 + 10) + celui du bloc (8)
        let side = max(0, min(size.width - 24, size.height - reserved))
        return VStack(spacing: 8) {
            EvalBarView(evalCp: viewModel.currentEvalCp, evalMate: viewModel.currentEvalMate)
                .frame(width: side)
            ChessBoardView(
                board: viewModel.displayedBoard,
                orientation: .white,
                theme: appSettings.boardTheme,
                selectedSquare: nil,
                legalTargetSquares: [],
                lastMove: viewModel.displayedLastMove,
                hintMoves: viewModel.hintMoves,
                qualityBadge: viewModel.qualityBadge,
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
            if viewModel.isClassifying, let progress = viewModel.classificationProgress {
                classificationIndicator(progress)
            } else if viewModel.isAnalyzing {
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

    private func classificationIndicator(_ progress: (done: Int, total: Int)) -> some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small).tint(Theme.textTertiary)
            Text("\(progress.done)/\(progress.total)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .fixedSize()
        }
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

    private func rowNumber(forPly ply: Int) -> Int {
        max(1, (ply + 1) / 2)
    }

    private var movesList: some View {
        ScrollViewReader { proxy in
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
            .onChange(of: viewModel.displayedPly) { _, newPly in
                withAnimation(Theme.gentle) {
                    proxy.scrollTo(rowNumber(forPly: newPly), anchor: .center)
                }
            }
            .onAppear { proxy.scrollTo(rowNumber(forPly: viewModel.displayedPly), anchor: .center) }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func moveButton(_ san: String, ply: Int) -> some View {
        let quality = viewModel.moveQuality[ply].flatMap { $0.showsInMoveList ? $0 : nil }
        return Button {
            viewModel.review(toPly: ply)
        } label: {
            HStack(spacing: 3) {
                Text(san)
                if let quality {
                    qualityGlyph(quality)
                }
            }
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

    @ViewBuilder
    private func qualityGlyph(_ quality: MoveQuality) -> some View {
        // `.accessibilityLabel` explicite : sans lui, VoiceOver lit soit le
        // texte brut du glyphe ("!!"), soit le nom du symbole SF ("star
        // fill") — ni l'un ni l'autre ne dit « coup brillant »/« le
        // meilleur ». Même patron que ``MoveQualityBadgeView`` (la pastille
        // posée sur le plateau), qui l'a déjà.
        Group {
            switch quality.icon {
            case let .text(text):
                Text(text)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(quality.tint)
            case let .symbol(name):
                Image(systemName: name)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(quality.tint)
            }
        }
        .accessibilityLabel(Text(quality.label))
    }

    private var totalPliesMarker: some View {
        Color.clear
            .accessibilityIdentifier("variantAnalysis_totalPlies")
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
