import ChessKit
import SwiftUI

/// Lecteur d'ouverture : échiquier + « Précédent / Suivant », l'explication du
/// coup, le fil des coups, et les variantes. Simple et guidé.
struct OpeningReaderView: View {
    @Bindable var viewModel: OpeningReaderViewModel
    let onExit: () -> Void
    var onTrain: () -> Void = {}

    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }

    var body: some View {
        // Le plateau est ANCRÉ, seul le texte défile. Auparavant tout était
        // dans un même `ScrollView` : dès qu'une position offrait plusieurs
        // variantes, la liste passait sous le pli et il fallait faire défiler
        // — ce qui sortait l'échiquier de l'écran, alors qu'on lit justement
        // les coups EN REGARDANT la position (retour testeur, 15/08).
        GeometryReader { geo in
            if geo.size.width > geo.size.height * 1.1 {
                wideLayout(size: geo.size)
            } else {
                tallLayout(size: geo.size)
            }
        }
        .appBackground()
        .navigationTitle(LocalizedStringKey(viewModel.course.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { onTrain() } label: { Label("S'entraîner", systemImage: "graduationcap.fill") }
                    .tint(Theme.accent)
            }
        }
    }

    // MARK: Dispositions

    /// Portrait : plateau ancré en haut, panneau défilant en dessous, barre de
    /// transport en bas. Le plateau ne prend jamais plus de la moitié de la
    /// hauteur utile, sinon il ne resterait rien pour le coup à venir.
    private func tallLayout(size: CGSize) -> some View {
        let side = min(size.width - 32, size.height * 0.5, 520)
        return VStack(spacing: 0) {
            board
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            scrollingPanel
            controlBar
        }
    }

    /// Paysage (iPad, ou iPhone couché) : plateau à gauche, lecture à droite.
    /// Un plateau plafonné à la hauteur laisserait sinon la moitié de l'écran
    /// vide à côté.
    private func wideLayout(size: CGSize) -> some View {
        let side = min(size.height - 24, size.width * 0.5, 560)
        return HStack(spacing: 0) {
            board
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 0) {
                scrollingPanel
                controlBar
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// La partie qui défile : fil des coups, explication, coups jouables.
    private var scrollingPanel: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !viewModel.playedSANs.isEmpty { moveTrail }
                explanationCard
                movesSection
                Spacer(minLength: 8)
            }
            .padding(.vertical, 12)
        }
    }

    private var board: some View {
        ChessBoardView(
            board: viewModel.board,
            orientation: viewModel.orientation,
            theme: boardTheme,
            selectedSquare: nil,
            legalTargetSquares: [],
            lastMove: viewModel.lastMove,
            hintMoves: arrows,
            interactionEnabled: false,
            showCoordinates: true,
            draggableColor: .white,
            onTapSquare: { _ in },
            onDropPiece: { _, _ in }
        )
    }

    /// Fil des coups joués — on peut taper pour revenir en arrière.
    private var moveTrail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(viewModel.playedSANs.enumerated()), id: \.offset) { index, san in
                    let isCurrent = index == viewModel.playedSANs.count - 1
                    Button { viewModel.jump(toPly: index + 1) } label: {
                        Text(trailLabel(index: index, san: san))
                            .font(.caption.weight(.semibold).monospaced())
                            .foregroundStyle(isCurrent ? Theme.background : Theme.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(isCurrent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surface),
                                        in: Capsule())
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func trailLabel(index: Int, san: String) -> String {
        index % 2 == 0 ? "\(index / 2 + 1). \(san)" : san
    }

    @ViewBuilder
    private var explanationCard: some View {
        if let comment = viewModel.currentComment, !comment.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "text.bubble.fill").foregroundStyle(Theme.accent)
                Text(comment).font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .cardStyle()
            .padding(.horizontal, 16)
            .transition(.opacity)
        } else if viewModel.isEnd {
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered").foregroundStyle(Theme.textTertiary)
                Text("Fin de la ligne. Reviens en arrière pour explorer une variante.")
                    .font(.subheadline).foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 0)
            }
            .cardStyle()
            .padding(.horizontal, 16)
        }
    }

    // MARK: Coups jouables (flèches colorées ↔ pastilles)

    /// Un coup jouable et SA couleur — la même sur la flèche du plateau et sur
    /// le fond de sa ligne, pour qu'on relie l'un à l'autre d'un coup d'œil.
    private struct ColoredMove: Identifiable {
        let edge: MoveEdge
        let color: Color
        var id: String { edge.uci }
    }

    /// Palette des variantes « neutres » (hors piège/imprécision) : une famille
    /// de teintes PROCHES (bleu clair → indigo), pour l'uniformité tout en
    /// restant distincte du vert (recommandé) et du rouge/orange (à risque).
    private static let variationPalette: [Color] = [
        Color(red: 0.353, green: 0.651, blue: 1.000),   // #5AA6FF bleu clair
        Color(red: 0.294, green: 0.518, blue: 0.949),   // #4B84F2 bleu
        Color(red: 0.290, green: 0.388, blue: 0.878),   // #4A63E0 bleu-indigo
        Color(red: 0.294, green: 0.310, blue: 0.788),   // #4B4FC9 indigo
    ]

    /// Coups jouables colorés : le coup à venir en vert (recommandé), les pièges
    /// en rouge, les imprécisions en orange, les autres variantes cyclant la palette.
    private var coloredMoves: [ColoredMove] {
        var neutral = 0
        return viewModel.candidates.enumerated().map { index, edge in
            let color: Color
            if index == 0 {
                color = Theme.accent
            } else if edge.role == .trap {
                color = Theme.danger
            } else if edge.role == .inaccuracy {
                color = Theme.warning
            } else {
                color = Self.variationPalette[neutral % Self.variationPalette.count]
                neutral += 1
            }
            return ColoredMove(edge: edge, color: color)
        }
    }

    /// Une flèche par coup jouable, teintée comme sa pastille. Le coup à venir
    /// est plus épais et dessiné au-dessus (rang 1 = ombré, posé en dernier).
    private var arrows: [HintMove] {
        coloredMoves.enumerated().compactMap { index, item in
            let uci = item.edge.uci
            guard uci.count >= 4 else { return nil }
            return HintMove(
                rank: index == 0 ? 1 : 2,
                from: Square(String(uci.prefix(2))),
                to: Square(String(uci.dropFirst(2).prefix(2))),
                strength: index == 0 ? 1.0 : 0.45,
                tint: item.color
            )
        }
    }

    /// « Coup à venir » (le coup recommandé) + « Autres coups » (les variantes),
    /// chaque ligne teintée de la couleur de sa flèche.
    @ViewBuilder
    private var movesSection: some View {
        let moves = coloredMoves
        if !moves.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Coup à venir")
                moveRow(moves[0])
                if moves.count > 1 {
                    sectionHeader("Autres coups à ce stade").padding(.top, 6)
                    ForEach(moves.dropFirst()) { moveRow($0) }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func sectionHeader(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold)).foregroundStyle(Theme.textTertiary)
            .textCase(.uppercase).tracking(0.4)
            .padding(.horizontal, 4)
    }

    private func moveRow(_ item: ColoredMove) -> some View {
        Button { viewModel.play(item.edge) } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(item.color)
                    .frame(width: 14, height: 14)
                Text(item.edge.san).font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(Theme.textPrimary).frame(minWidth: 44, alignment: .leading)
                if item.edge.role == .trap { tag("Piège", Theme.danger) }
                if item.edge.role == .inaccuracy { tag("Imprécision", Theme.warning) }
                Spacer()
                Image(systemName: "arrow.turn.down.right").font(.caption).foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(item.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(item.color.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.pressable)
    }

    private func tag(_ text: LocalizedStringKey, _ color: Color) -> some View {
        Text(text).font(.caption2.weight(.bold)).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    /// Barre du bas : Précédent / Suivant, l'action centrale du lecteur.
    private var controlBar: some View {
        HStack(spacing: 12) {
            Button { viewModel.back() } label: {
                Label("Précédent", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(.pressable)
            .disabled(!viewModel.canGoBack)
            .opacity(viewModel.canGoBack ? 1 : 0.4)
            .accessibilityIdentifier("reader_prev")

            Button { viewModel.next() } label: {
                Label("Suivant", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.bold)).foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.accentGradient, in: Capsule())
                    .glow(Theme.accent, radius: 8)
            }
            .buttonStyle(.pressable)
            .disabled(viewModel.isEnd)
            .opacity(viewModel.isEnd ? 0.4 : 1)
            .accessibilityIdentifier("reader_next")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.background)
    }
}

/// Héberge le lecteur : charge le cours et construit le ViewModel une fois.
struct OpeningReaderHost: View {
    let courseID: String
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    let onExit: () -> Void
    var onTrain: () -> Void = {}
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: OpeningReaderViewModel?

    var body: some View {
        Group {
            if let viewModel {
                OpeningReaderView(viewModel: viewModel, onExit: onExit, onTrain: onTrain)
            } else {
                ContentUnavailableView("Ouverture indisponible", systemImage: "questionmark.folder").appBackground()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = sessionStore.value(for: sessionKey) {
                    OpeningCourseLoader.course(id: courseID).map(OpeningReaderViewModel.init(course:))
                }
            }
        }
    }
}
