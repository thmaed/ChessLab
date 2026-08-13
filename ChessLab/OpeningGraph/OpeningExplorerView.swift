import ChessKit
import SwiftUI

/// Mode EXPLORER : navigation libre dans le graphe d'un cours. Plateau (affichage
/// seul) + liste des coups triés par popularité, avec double base (Maîtres/Club),
/// score, évaluation et transpositions. Le moins risqué des trois modes — il
/// valide le modèle et la donnée sans logique d'entraînement.
struct OpeningExplorerView: View {
    @Bindable var viewModel: OpeningExplorerViewModel
    var onLearn: () -> Void = {}
    var onTrain: () -> Void = {}

    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                board
                baseToggle
                if !viewModel.transpositions.isEmpty { transpositionsCard }
                if let plan = viewModel.plan, !plan.isEmpty { planCard(plan) }
                movesSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .appBackground()
        .navigationTitle("Explorateur")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Button(action: onLearn) { Image(systemName: "graduationcap") }
                    Button(action: onTrain) { Image(systemName: "figure.strengthtraining.traditional") }
                    Button { viewModel.back() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!viewModel.canGoBack)
                    Button { viewModel.reset() } label: { Image(systemName: "house") }
                        .disabled(!viewModel.canGoBack)
                }
                .tint(Theme.accent)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey(viewModel.course.name))
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
                .textCase(.uppercase)
            if let eco = viewModel.ecoName {
                Text(eco)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            Text(viewModel.orientation == .white ? "Vue des blancs" : "Vue des noirs")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.textTertiary)
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
            hintMoves: [],
            interactionEnabled: false,
            showCoordinates: true,
            draggableColor: .white,
            onTapSquare: { _ in },
            onDropPiece: { _, _ in }
        )
        .aspectRatio(1, contentMode: .fit)
    }

    private var baseToggle: some View {
        HStack(spacing: 8) {
            ForEach(ExplorerBase.allCases, id: \.self) { base in
                FilterChip(
                    label: LocalizedStringKey(base.label),
                    icon: base == .masters ? "crown.fill" : "person.3.fill",
                    tint: base == .masters ? Theme.violet : Theme.info,
                    isSelected: viewModel.base == base
                ) {
                    viewModel.base = base
                }
            }
            Spacer()
        }
    }

    private var transpositionsCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.triangle.merge").foregroundStyle(Theme.info)
            VStack(alignment: .leading, spacing: 2) {
                Text("Transpositions").font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Text(viewModel.transpositions.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .cardStyle()
    }

    private func planCard(_ plan: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "map").foregroundStyle(Theme.accent)
            Text(plan).font(.subheadline).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .cardStyle()
    }

    @ViewBuilder
    private var movesSection: some View {
        if viewModel.moves.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "flag.checkered").font(.title2).foregroundStyle(Theme.textTertiary)
                Text("Fin de la ligne connue").font(.subheadline).foregroundStyle(Theme.textSecondary)
                Text("Approfondis cette ouverture en régénérant les données.")
                    .font(.caption).foregroundStyle(Theme.textTertiary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .cardStyle()
        } else {
            VStack(spacing: 8) {
                ForEach(viewModel.moves, id: \.uci) { edge in
                    Button { viewModel.play(edge) } label: { moveRow(edge) }
                        .buttonStyle(.pressable)
                }
            }
        }
    }

    private func moveRow(_ edge: MoveEdge) -> some View {
        HStack(spacing: 12) {
            Text(edge.san)
                .font(.body.weight(.semibold).monospaced())
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 54, alignment: .leading)

            roleBadge(edge)

            VStack(alignment: .leading, spacing: 5) {
                popularityBar(viewModel.popularity(edge))
                if edge.scoreWhite != nil { scoreBar(edge) }
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                if let eval = edge.eval {
                    Text(Self.formatEval(eval))
                        .font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(Theme.textSecondary)
                }
                if let games = viewModel.games(edge) {
                    Text(Self.formatGames(games))
                        .font(.caption2).foregroundStyle(Theme.textTertiary)
                }
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    @ViewBuilder
    private func roleBadge(_ edge: MoveEdge) -> some View {
        switch edge.role {
        case .trap:
            badge("Piège", Theme.danger)
        case .refutation:
            badge("Réfutation", Theme.warning)
        case .inaccuracy:
            badge("Imprécision", Theme.warning)
        case .mainLine:
            if edge.isCritical { badge("Clé", Theme.accent) } else { EmptyView() }
        case .sideline:
            EmptyView()
        }
    }

    private func badge(_ text: LocalizedStringKey, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func popularityBar(_ pop: Double) -> some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(Theme.accent.opacity(0.8))
                        .frame(width: max(2, geo.size.width * pop))
                }
            }
            .frame(height: 5)
            Text("\(Int((pop * 100).rounded()))%")
                .font(.caption2.weight(.medium).monospaced())
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 34, alignment: .trailing)
        }
    }

    private func scoreBar(_ edge: MoveEdge) -> some View {
        let w = edge.scoreWhite ?? 0
        let d = edge.scoreDraw ?? 0
        let b = edge.scoreBlack ?? 0
        return HStack(spacing: 0) {
            Rectangle().fill(Color.white.opacity(0.85)).frame(width: 56 * w)
            Rectangle().fill(Color.gray.opacity(0.55)).frame(width: 56 * d)
            Rectangle().fill(Color.black.opacity(0.75)).frame(width: 56 * b)
        }
        .frame(width: 56, height: 4)
        .clipShape(Capsule())
    }

    static func formatEval(_ cp: Double) -> String {
        if abs(cp) >= 100_000 { return cp > 0 ? "#" : "-#" }
        let pawns = cp / 100
        return String(format: "%+.1f", pawns)
    }

    static func formatGames(_ games: Int) -> String {
        if games >= 1_000_000 { return String(format: "%.1fM", Double(games) / 1_000_000) }
        if games >= 1_000 { return String(format: "%.1fk", Double(games) / 1_000) }
        return "\(games)"
    }
}

/// Héberge l'Explorer : charge le cours par identifiant, construit le ViewModel
/// une seule fois avec l'index de transpositions embarqué.
struct OpeningExplorerHost: View {
    let courseID: String
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    var onLearn: () -> Void = {}
    var onTrain: () -> Void = {}
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: OpeningExplorerViewModel?

    var body: some View {
        Group {
            if let viewModel {
                OpeningExplorerView(viewModel: viewModel, onLearn: onLearn, onTrain: onTrain)
            } else {
                ContentUnavailableView("Cours indisponible", systemImage: "questionmark.folder")
                    .appBackground()
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            viewModel = sessionStore.value(for: sessionKey) {
                guard let course = OpeningCourseLoader.course(id: courseID) else { return nil }
                return OpeningExplorerViewModel(course: course) { fen in
                    OpeningTranspositionIndex.bundled.courses(for: fen, excluding: courseID)
                }
            }
        }
    }
}
