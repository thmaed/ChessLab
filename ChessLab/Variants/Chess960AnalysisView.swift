import ChessKit
import SwiftUI

/// Revue d'une partie Chess960 terminée — plateau, barre d'évaluation
/// (toujours visible, contrairement au jeu en cours), flèches des meilleurs
/// coups, liste des coups, navigation coup par coup.
struct Chess960AnalysisView: View {
    let viewModel: Chess960AnalysisViewModel

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
                // La courbe d'évaluation, comme en mode « Contre
                // l'ordinateur » : elle dit d'un coup d'œil OÙ la partie a
                // basculé, et un appui y saute directement. Dans une carte,
                // comme la liste des coups juste dessous — posée à nu sur le
                // fond, elle avait l'air d'un reste de mise en page. Le
                // rembourrage horizontal dégage aussi le repère de position
                // quand on est au tout premier ou au tout dernier coup, sinon
                // collé au bord et coupé en deux.
                if !viewModel.evalCurvePoints.isEmpty {
                    EvalCurveView(
                        points: viewModel.evalCurvePoints,
                        currentPly: viewModel.displayedPly
                    ) { ply in
                        viewModel.review(toPly: ply)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                accuracyCard
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
        .overlay(alignment: .top) {
            if viewModel.isEngineUnavailable {
                EngineUnavailableBanner(
                    message: "L'analyse n'a pas pu démarrer : le moteur est indisponible.",
                    isRetrying: false,
                    onRetry: {}
                )
            }
        }
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

    /// Ce que la courbe d'évaluation prend à la hauteur — sa hauteur propre
    /// plus l'espacement de la pile. Réservé, jamais deviné : sans cette
    /// ligne, la courbe poussait la liste des coups hors de l'écran sur les
    /// appareils courts.
    private static let evalCurveHeight: CGFloat = 64 + 12 + 10

    /// Ce que la carte de précision prend à la hauteur, espacement compris.
    private static let accuracyCardHeight: CGFloat = 44 + 10

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
            + Self.evalCurveHeight
            + Self.accuracyCardHeight
            + VariantMoveStripView.reservedHeight
            + EvalBarView.defaultHeight
            + 28   // les deux espacements de la pile (10 + 10) + celui du bloc (8)
        let side = max(0, min(size.width - 24, size.height - reserved))
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

    /// Avancement de la classification de fond — même rendu compact que
    /// ``AnalysisView/classificationIndicator(_:)``.
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

    /// Numéro de la rangée (« N. blancs noirs ») qui contient `ply` — même
    /// calcul que ``Chess960AnalysisViewModel/numberedMoves``.
    /// Les coups EN LIGNE — même bande à capsules que le mode Contre
    /// l'ordinateur, chaque coup remarquable bordé de la couleur de sa
    /// catégorie d'évaluation. Voir ``VariantMoveStripView``.
    private var movesList: some View {
        VariantMoveStripView(
            numberedMoves: viewModel.numberedMoves,
            currentPly: viewModel.displayedPly,
            quality: viewModel.moveQuality
        ) { ply in
            viewModel.review(toPly: ply)
        }
    }

    /// Preuve du round-trip pour les tests d'interface : le nombre de coups
    /// que l'écran a effectivement rejoués depuis le PGN reçu.
    private var totalPliesMarker: some View {
        Color.clear
            .accessibilityIdentifier("chess960_analysis_totalPlies")
            .accessibilityValue("\(viewModel.totalPlies)")
    }


    /// Précision par joueur — le même bilan d'un coup d'œil qu'en mode
    /// « Contre l'ordinateur ». Elle se complète au fil de la classification,
    /// et n'apparaît donc qu'une fois le premier coup jugé.
    @ViewBuilder
    private var accuracyCard: some View {
        if !viewModel.accuracyByColor.isEmpty {
            HStack(spacing: 14) {
                ForEach([Piece.Color.white, .black], id: \.self) { color in
                    if let accuracy = viewModel.accuracyByColor[color] {
                        HStack(spacing: 9) {
                            Circle()
                                .fill(color == .white ? Color.white : Color.black)
                                .overlay(Circle().strokeBorder(Theme.strokeStrong, lineWidth: 1))
                                .frame(width: 11, height: 11)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(Int(accuracy.rounded()))%")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(Theme.textPrimary)
                                Text("précision")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier("variantAnalysis_accuracy")
        }
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
