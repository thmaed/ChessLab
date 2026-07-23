import SwiftData
import SwiftUI

/// Tableau de bord « Progression » (1.3) : une vue d'ensemble transversale
/// de ce que l'utilisateur a accompli, agrégée depuis ce qui est **déjà**
/// en base (voir ``ProgressionSummary``). Aucune nouvelle donnée collectée.
///
/// - important: Ne charge JAMAIS toute la table `Puzzle` — la bibliothèque
///   Lichess embarquée en compte des dizaines de milliers. Comme
///   ``PuzzleQueueView``, un `FetchDescriptor` filtré laisse SQLite ne
///   remonter que les puzzles réellement TENTÉS. Les `GameRecord`, eux,
///   forment une petite table : un chargement complet est sans danger.
struct ProgressionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var summary: ProgressionSummary?

    /// Passe une session de puzzles filtrée sur le thème le plus faible —
    /// branché par l'hôte de navigation. No-op par défaut (aperçus/tests).
    var onTrainTheme: (PuzzleTheme) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let summary, summary.hasAnyData {
                    if summary.engineGames > 0 {
                        engineCard(summary)
                    }
                    if summary.puzzleAttempts > 0 {
                        puzzleCard(summary)
                    }
                } else {
                    emptyState
                }
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Progression")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear(perform: load)
    }

    // MARK: Contre Stockfish

    @ViewBuilder
    private func engineCard(_ summary: ProgressionSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader("Contre Stockfish", systemImage: "cpu", tint: Theme.accent)

            HStack(spacing: 10) {
                statTile("\(summary.engineWins)", "Victoires", tint: Theme.accent)
                statTile("\(summary.engineDraws)", "Nulles", tint: Theme.textSecondary)
                statTile("\(summary.engineLosses)", "Défaites", tint: Theme.danger)
            }

            if let best = summary.bestWinElo {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                    Text("Meilleure victoire : ~\(best) Elo")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }

            if !summary.engineByBand.isEmpty {
                Divider().overlay(Theme.stroke)
                Text("Par niveau d'adversaire")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                ForEach(summary.engineByBand) { record in
                    bandRow(record)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityIdentifier("progressionEngine")
    }

    private func bandRow(_ record: ProgressionSummary.BandRecord) -> some View {
        HStack(spacing: 10) {
            Text(LocalizedStringKey(record.band.label))
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            // V · N · D compact, la couleur dit le sens sans légende.
            HStack(spacing: 6) {
                pill("\(record.wins)", tint: Theme.accent)
                pill("\(record.draws)", tint: Theme.textSecondary)
                pill("\(record.losses)", tint: Theme.danger)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(record.band.label) : \(record.wins) victoires, \(record.draws) nulles, \(record.losses) défaites"))
    }

    // MARK: Puzzles

    @ViewBuilder
    private func puzzleCard(_ summary: ProgressionSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader("Puzzles", systemImage: "puzzlepiece.fill", tint: Theme.violet)

            HStack(alignment: .firstTextBaseline) {
                Text(summary.puzzleSuccessRate.map { "\(Int(($0 * 100).rounded())) %" } ?? "—")
                    .font(.system(size: 40, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.violet)
                VStack(alignment: .leading, spacing: 2) {
                    Text("de réussite")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(summary.puzzleSuccesses) sur \(summary.puzzleAttempts) tentatives")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)

            if let tier = summary.reachedTier {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                    Text("Niveau atteint : ")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    + Text(LocalizedStringKey(tier.label))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }

            if !summary.puzzlesByTier.isEmpty {
                Divider().overlay(Theme.stroke)
                Text("Réussite par difficulté")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                ForEach(summary.puzzlesByTier) { record in
                    tierRow(record)
                }
            }

            if !summary.weakestThemes.isEmpty {
                Divider().overlay(Theme.stroke)
                HStack {
                    Text("À travailler")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                ForEach(summary.weakestThemes.prefix(3)) { record in
                    Button {
                        onTrainTheme(record.theme)
                    } label: {
                        weakThemeRow(record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityIdentifier("progressionPuzzles")
    }

    private func tierRow(_ record: ProgressionSummary.TierRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(LocalizedStringKey(record.tier.label))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(Int((record.successRate * 100).rounded())) %")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            // Barre de réussite : lecture d'un coup d'œil, pas besoin d'un
            // graphe pour un simple ratio.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceElevated)
                    Capsule()
                        .fill(Theme.tintGradient(Theme.violet))
                        .frame(width: max(4, geo.size.width * record.successRate))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(record.tier.label) : \(Int((record.successRate * 100).rounded())) % de réussite sur \(record.attempts)"))
    }

    private func weakThemeRow(_ record: PuzzleStats.ThemeRecord) -> some View {
        HStack(spacing: 8) {
            Image(systemName: record.theme.icon)
                .font(.caption)
                .foregroundStyle(Theme.warning)
            Text(LocalizedStringKey(record.theme.label))
                .font(.caption)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(Int((record.failureRate * 100).rounded())) % d'échecs")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textTertiary)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.accent)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Lancer une série sur ce thème"))
    }

    // MARK: État vide

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 46))
                .foregroundStyle(Theme.textTertiary)
            Text("Rien à afficher pour l'instant")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Jouez une partie contre Stockfish ou résolvez quelques puzzles : votre progression apparaîtra ici.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }

    // MARK: Briques

    private func cardHeader(_ title: LocalizedStringKey, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: systemImage, tint: tint, size: 34)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func statTile(_ value: String, _ label: LocalizedStringKey, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surfaceElevated.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func pill(_ value: String, tint: Color) -> some View {
        Text(value)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(tint)
            .frame(minWidth: 26)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
    }

    // MARK: Chargement

    private func load() {
        // Parties : petite table, chargement complet sans risque.
        let games = (try? modelContext.fetch(FetchDescriptor<GameRecord>())) ?? []

        // Puzzles : UNIQUEMENT ceux tentés (voir l'avertissement d'en-tête).
        var attempted = FetchDescriptor<Puzzle>(predicate: #Predicate { puzzle in
            (puzzle.successCount ?? 0) > 0 || (puzzle.failureCount ?? 0) > 0
        })
        attempted.propertiesToFetch = [\.successCount, \.failureCount, \.themeRaw, \.rating]
        let puzzles = (try? modelContext.fetch(attempted)) ?? []

        summary = ProgressionSummary.compute(games: games, puzzles: puzzles)
    }
}
