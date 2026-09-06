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

/// Fenêtre temporelle du bilan « Contre l'ordinateur » — chaque
/// ``GameRecord`` porte un ``GameRecord/playedAt`` réel, donc un filtre par
/// date y est honnête. Les puzzles, eux, ne stockent que des compteurs
/// CUMULÉS (voir la note sur ``ProgressionSummary``) : pas de date par
/// tentative, donc pas de filtre là — mieux vaut ne rien proposer qu'une
/// fausse fenêtre temporelle.
enum ProgressionTimeRange: String, CaseIterable, Identifiable {
    case last7Days, last30Days, allTime

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .last7Days: "7 jours"
        case .last30Days: "30 jours"
        case .allTime: "Tout"
        }
    }

    /// `nil` = pas de borne (tout l'historique).
    var cutoff: Date? {
        switch self {
        case .last7Days: Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .last30Days: Calendar.current.date(byAdding: .day, value: -30, to: Date())
        case .allTime: nil
        }
    }
}

struct ProgressionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var allGames: [GameRecord] = []
    @State private var puzzles: [Puzzle] = []
    @State private var timeRange: ProgressionTimeRange = .allTime

    /// Passe une session de puzzles filtrée sur le thème le plus faible —
    /// branché par l'hôte de navigation. No-op par défaut (aperçus/tests).
    var onTrainTheme: (PuzzleTheme) -> Void = { _ in }

    private var summary: ProgressionSummary {
        let cutoff = timeRange.cutoff
        let games = cutoff.map { bound in allGames.filter { ($0.playedAt ?? .distantPast) >= bound } } ?? allGames
        return ProgressionSummary.compute(games: games, puzzles: puzzles)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if summary.hasAnyData || !allGames.isEmpty {
                    if !allGames.isEmpty {
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
            .frame(maxWidth: Theme.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
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
            cardHeader("Contre l'ordinateur", systemImage: "cpu", tint: Theme.accent)

            HStack(spacing: 8) {
                ForEach(ProgressionTimeRange.allCases) { range in
                    FilterChip(
                        label: range.label, tint: Theme.accent,
                        isSelected: timeRange == range
                    ) {
                        timeRange = range
                    }
                }
            }
            .accessibilityIdentifier("progressionTimeRange")

            if summary.engineGames == 0 {
                Text("Aucune partie sur cette période.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

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

            if !summary.engineByOpponent.isEmpty {
                Divider().overlay(Theme.stroke)
                Text("Par personnage")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                ForEach(summary.engineByOpponent) { record in
                    opponentRow(record)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityIdentifier("progressionEngine")
    }

    @ViewBuilder
    private func opponentRow(_ record: ProgressionSummary.OpponentRecord) -> some View {
        if let profile = OpponentProfile.named(record.profileID) {
            HStack(spacing: 10) {
                OpponentAvatar(profile: profile, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.firstName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                    if let best = record.bestWinLevel {
                        Text("Battu jusqu'à \(best)")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer()
                HStack(spacing: 6) {
                    pill("\(record.wins)", tint: Theme.accent)
                    pill("\(record.draws)", tint: Theme.textSecondary)
                    pill("\(record.losses)", tint: Theme.danger)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(profile.firstName) : \(record.wins) victoires, \(record.draws) nulles, \(record.losses) défaites"))
        }
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
                    // Même bride que le chiffre de précision du bilan de
                    // partie : il suit Dynamic Type, plafonné à 1,5×.
                    .scaledSystemFont(
                        size: 40, relativeTo: .largeTitle,
                        weight: .bold, maximumScale: 1.5
                    )
                    .monospacedDigit()
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
            Text("Jouez une partie contre l'ordinateur ou résolvez quelques puzzles : votre progression apparaîtra ici.")
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
        // Fusionne d'abord la progression puzzles synchronisée (autres
        // appareils) dans les Puzzle locaux, pour que le bilan la reflète.
        PuzzleProgressSync.reconcileIfStale(in: modelContext)
        // Parties : petite table, chargement complet sans risque. `playedAt`
        // reste chargée (pas dans `propertiesToFetch` réduit, contrairement
        // aux puzzles ci-dessous) : c'est elle qui alimente le sélecteur de
        // période ci-dessus.
        allGames = (try? modelContext.fetch(FetchDescriptor<GameRecord>())) ?? []

        // Puzzles : UNIQUEMENT ceux tentés (voir l'avertissement d'en-tête).
        var attempted = FetchDescriptor<Puzzle>(predicate: #Predicate { puzzle in
            (puzzle.successCount ?? 0) > 0 || (puzzle.failureCount ?? 0) > 0
        })
        attempted.propertiesToFetch = [\.successCount, \.failureCount, \.themeRaw, \.rating]
        puzzles = (try? modelContext.fetch(attempted)) ?? []
    }
}
