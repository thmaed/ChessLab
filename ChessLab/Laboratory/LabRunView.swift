import Charts
import ChessKit
import SwiftUI
import UIKit

/// Écran d'exécution d'une série Laboratoire : progression, plateau en
/// direct, statistiques cumulées (score, écart Elo ± IC, LOS, longueur
/// moyenne), contrôles pause/arrêt et export PGN/CSV en fin de série.
struct LabRunView: View {
    @Bindable var viewModel: LabViewModel
    let onExit: () -> Void

    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }
    @State private var shareItem: ShareItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Le scénario qui chauffe le plus : des centaines de
                // recherches d'affilée (Lot 2.C).
                ThermalBadge()
                progressCard
                HStack(alignment: .center, spacing: 10) {
                    LabVerticalEvalBar(evalCp: viewModel.currentEvalCp)
                    board
                }
                .frame(maxWidth: 380)
                .frame(maxWidth: .infinity)
                statsGrid
                progressChart
                resultDistribution
                controls
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Laboratoire")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.handleViewDisappear() }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: Progression

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.isFinished ? "Série terminée" : "Partie \(min(viewModel.completed.count + 1, viewModel.settings.gameCount)) / \(viewModel.settings.gameCount)")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if viewModel.isFinished {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.accent)
                        .glow(Theme.accent, radius: 8)
                } else if viewModel.isPaused {
                    Label("En pause", systemImage: "pause.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                } else if viewModel.isRunning {
                    HStack(spacing: 6) {
                        ProgressView().tint(Theme.accent).scaleEffect(0.7)
                        Text("\(viewModel.currentPlyCount) demi-coups")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                            .monospacedDigit()
                    }
                }
            }

            ProgressView(value: viewModel.progressFraction)
                .tint(Theme.accent)
        }
        .cardStyle()
    }

    private var board: some View {
        ChessBoardView(
            board: viewModel.board,
            orientation: .white,
            theme: boardTheme,
            selectedSquare: nil,
            legalTargetSquares: [],
            lastMove: viewModel.lastMove,
            hintMoves: [],
            interactionEnabled: false,
            showCoordinates: true,
            onTapSquare: { _ in },
            onDropPiece: { _, _ in }
        )
    }

    // MARK: Statistiques

    private var statsGrid: some View {
        let stats = viewModel.stats
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statTile(
                value: stats.games > 0 ? "\(Int(stats.scorePercent.rounded()))%" : "—",
                label: "score de A", icon: "percent", tint: Theme.accent
            )
            statTile(
                value: "\(stats.winsA)–\(stats.draws)–\(stats.winsB)",
                label: "V · N · D (A)", icon: "chart.bar.fill", tint: Theme.info
            )
            statTile(value: eloText(stats), label: LocalizedStringKey(eloCaption(stats)), icon: "arrow.up.arrow.down", tint: Theme.violet)
            statTile(
                value: stats.winsA + stats.winsB > 0 ? "\(Int((stats.likelihoodOfSuperiority * 100).rounded()))%" : "—",
                label: "LOS (A > B)", icon: "checkmark.seal", tint: Theme.teal
            )
            statTile(
                value: stats.games > 0 ? "\(Int(stats.averageMoves.rounded()))" : "—",
                label: "coups / partie", icon: "ruler", tint: Theme.warning
            )
            statTile(
                value: "\(stats.games)/\(viewModel.settings.gameCount)",
                label: "parties jouées", icon: "flag.checkered", tint: Theme.rose
            )
        }
    }

    private func statTile(value: String, label: LocalizedStringKey, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: icon, tint: tint, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.cardGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func eloText(_ stats: LabStats) -> String {
        guard let elo = stats.eloDifference else { return "—" }
        return String(format: "%+.0f", elo)
    }

    private func eloCaption(_ stats: LabStats) -> String {
        if let ci = stats.elo95ConfidenceInterval, stats.eloDifference != nil {
            let margin = String(format: "%.0f", (ci.high - ci.low) / 2)
            return String(format: LocalizationController.string("écart Elo ±%@"), margin)
        }
        return LocalizationController.string("écart Elo A−B")
    }

    /// Barre de répartition Victoires / Nulles / Défaites du camp A.
    @ViewBuilder
    private var resultDistribution: some View {
        let stats = viewModel.stats
        if stats.games > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Répartition (A)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        segment(width: geo.size.width, count: stats.winsA, total: stats.games, color: Theme.accent)
                        segment(width: geo.size.width, count: stats.draws, total: stats.games, color: Theme.textTertiary)
                        segment(width: geo.size.width, count: stats.winsB, total: stats.games, color: Theme.danger)
                    }
                }
                .frame(height: 16)
                .clipShape(Capsule())
                HStack(spacing: 14) {
                    legendDot(Theme.accent, "Gagnées \(stats.winsA)")
                    legendDot(Theme.textTertiary, "Nulles \(stats.draws)")
                    legendDot(Theme.danger, "Perdues \(stats.winsB)")
                }
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            }
            .cardStyle()
        }
    }

    @ViewBuilder
    private func segment(width: CGFloat, count: Int, total: Int, color: Color) -> some View {
        if count > 0 {
            Rectangle()
                .fill(color)
                .frame(width: max(2, width * CGFloat(count) / CGFloat(total)))
        }
    }

    private func legendDot(_ color: Color, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }

    // MARK: Courbe de progression

    /// Score cumulé de A (%) avec bande de confiance à 95 % qui se resserre
    /// au fil de la série — un point par partie, coloré selon son résultat.
    /// Masquée sous 2 parties (rien à tracer).
    @ViewBuilder
    private var progressChart: some View {
        let points = viewModel.progressPoints
        if points.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Progression de A")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Chart(points) { point in
                    AreaMark(
                        x: .value("Partie", point.game),
                        yStart: .value("min", point.ciLow),
                        yEnd: .value("max", point.ciHigh)
                    )
                    .foregroundStyle(Theme.accent.opacity(0.13))
                    .interpolationMethod(.monotone)

                    RuleMark(y: .value("Égalité", 50))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(Theme.textTertiary)

                    LineMark(x: .value("Partie", point.game), y: .value("Score A", point.scorePercent))
                        .foregroundStyle(Theme.accentGradient)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)

                    if points.count <= 60 {
                        PointMark(x: .value("Partie", point.game), y: .value("Score A", point.scorePercent))
                            .foregroundStyle(pointColor(point.result))
                            .symbolSize(18)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks(values: [0, 50, 100]) }
                .frame(height: 150)
            }
            .cardStyle()
        }
    }

    private func pointColor(_ result: LabGameResult) -> Color {
        switch result {
        case .winA: Theme.accent
        case .draw: Theme.textTertiary
        case .winB: Theme.danger
        }
    }

    // MARK: Contrôles

    private var controls: some View {
        VStack(spacing: 10) {
            if viewModel.isRunning {
                HStack(spacing: 10) {
                    controlButton(viewModel.isPaused ? "Reprendre" : "Pause", icon: viewModel.isPaused ? "play.fill" : "pause.fill", filled: viewModel.isPaused) {
                        viewModel.togglePause()
                    }
                    controlButton("Arrêter", icon: "stop.fill", tint: Theme.danger) {
                        viewModel.cancel()
                    }
                }
            } else {
                HStack(spacing: 10) {
                    controlButton("PGN", icon: "square.and.arrow.up") { exportPGN() }
                    controlButton("CSV", icon: "tablecells") { exportCSV() }
                }
                controlButton("Nouvelle série", icon: "arrow.clockwise", filled: true) { onExit() }
            }
        }
    }

    private func controlButton(_ title: LocalizedStringKey, icon: String, tint: Color = Theme.textPrimary, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(filled ? Theme.background : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background {
                if filled {
                    Capsule().fill(Theme.accentGradient)
                } else {
                    Capsule().fill(Theme.surface)
                }
            }
            .overlay(Capsule().strokeBorder(filled ? Color.clear : Theme.stroke, lineWidth: 1))
            .glow(Theme.accent, radius: 9, isActive: filled)
        }
        .buttonStyle(.pressable)
    }

    // MARK: Export

    private func exportPGN() {
        writeAndShare(content: LabExport.pgn(viewModel.completed, settings: viewModel.settings), filename: "chesslab-serie.pgn")
    }

    private func exportCSV() {
        writeAndShare(content: LabExport.csv(viewModel.completed), filename: "chesslab-serie.csv")
    }

    private func writeAndShare(content: String, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            shareItem = ShareItem(url: url)
        } catch {
            // Échec d'écriture temporaire : rien à partager, on ignore.
        }
    }
}

private struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.path }
}

/// Barre d'évaluation VERTICALE affichée à gauche du plateau du
/// Laboratoire (blanc en bas, noir en haut, comme sur Lichess/chess.com),
/// avec le score en pions au-dessus. `evalCp` est du point de vue des
/// Blancs (le plateau du Labo est toujours orienté blancs en bas).
private struct LabVerticalEvalBar: View {
    let evalCp: Int?

    private var whiteFraction: Double {
        guard let evalCp else { return 0.5 }
        return min(1, max(0, EvalConversion.winPercentage(cp: evalCp) / 100))
    }

    private var scoreLabel: String {
        guard let evalCp else { return "—" }
        return String(format: "%+.1f", Double(evalCp) / 100)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(scoreLabel)
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    Rectangle().fill(
                        LinearGradient(colors: [Color(white: 0.16), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)
                    )
                    Rectangle().fill(
                        LinearGradient(colors: [Color.white, Color(white: 0.86)], startPoint: .bottom, endPoint: .top)
                    )
                    .frame(height: geo.size.height * whiteFraction)

                    // Repère central (égalité).
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                .animation(.easeInOut(duration: 0.3), value: whiteFraction)
            }
            .frame(width: 14)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.gray.opacity(0.55), lineWidth: 1.5))
        }
        .frame(width: 36)
    }
}

/// Feuille de partage système (export PGN/CSV).
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
