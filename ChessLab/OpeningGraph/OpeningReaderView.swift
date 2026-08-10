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
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    board
                        .aspectRatio(1, contentMode: .fit)
                        .padding(.horizontal, 16)
                    if !viewModel.playedSANs.isEmpty { moveTrail }
                    explanationCard
                    if !viewModel.variations.isEmpty { variationsSection }
                    Spacer(minLength: 8)
                }
                .padding(.vertical, 12)
            }
            controlBar
        }
        .appBackground()
        .navigationTitle(LocalizedStringKey(viewModel.course.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { onTrain() } label: { Label("Réviser", systemImage: "checklist") }
                    .tint(Theme.accent)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 3) {
            if let name = viewModel.positionName {
                Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            Text(viewModel.orientation == .white ? "Vous jouez les blancs" : "Vous jouez les noirs")
                .font(.caption2.weight(.medium)).foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 20)
    }

    private var board: some View {
        ChessBoardView(
            board: viewModel.board,
            orientation: viewModel.orientation,
            theme: boardTheme,
            selectedSquare: nil,
            legalTargetSquares: [],
            lastMove: viewModel.lastMove,
            hintMoves: [],
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

    /// « Autres coups » : les variantes jouables à cette position.
    private var variationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Autres coups à ce stade")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase).tracking(0.4)
                .padding(.horizontal, 4)
            ForEach(viewModel.variations, id: \.uci) { edge in
                Button { withAnimation(Theme.spring) { viewModel.play(edge) } } label: {
                    HStack(spacing: 10) {
                        Text(edge.san).font(.subheadline.weight(.semibold).monospaced())
                            .foregroundStyle(Theme.textPrimary).frame(minWidth: 46, alignment: .leading)
                        if edge.role == .trap { tag("Piège", Theme.danger) }
                        if edge.role == .inaccuracy { tag("Imprécision", Theme.warning) }
                        Spacer()
                        Image(systemName: "arrow.turn.down.right").font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, 9).padding(.horizontal, 12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, 16)
    }

    private func tag(_ text: LocalizedStringKey, _ color: Color) -> some View {
        Text(text).font(.caption2.weight(.bold)).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    /// Barre du bas : Précédent / Suivant, l'action centrale du lecteur.
    private var controlBar: some View {
        HStack(spacing: 12) {
            Button { withAnimation(Theme.spring) { viewModel.back() } } label: {
                Label("Précédent", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(.pressable)
            .disabled(!viewModel.canGoBack)
            .opacity(viewModel.canGoBack ? 1 : 0.4)

            Button { withAnimation(Theme.spring) { viewModel.next() } } label: {
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.background)
    }
}

/// Héberge le lecteur : charge le cours et construit le ViewModel une fois.
struct OpeningReaderHost: View {
    let courseID: String
    let onExit: () -> Void
    var onTrain: () -> Void = {}
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
            if viewModel == nil, let course = OpeningCourseLoader.course(id: courseID) {
                viewModel = OpeningReaderViewModel(course: course)
            }
        }
    }
}
