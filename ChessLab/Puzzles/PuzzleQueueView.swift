import SwiftData
import SwiftUI

/// Écran de sélection avant une série de puzzles : trois groupes de
/// chips capsules (niveau, phase, type de puzzle) et un bouton
/// "Commencer" épinglé en bas — le tout tient sur UN SEUL écran, sans
/// défilement. Chaque groupe porte sa propre teinte (vert/bleu/ambre,
/// reprises de ``Theme``) pour se repérer d'un coup d'œil ; la ligne de
/// résumé au-dessus du bouton reformule la sélection courante. Aucune
/// mention de quantité nulle part (ni total, ni "dus") — l'utilisateur
/// choisit ses critères sans être influencé par combien de puzzles s'y
/// trouvent, et l'écran de résolution gère déjà gracieusement le cas
/// "plus rien de dû" si la combinaison est vide (voir
/// `PuzzleSessionHost` dans `HomeView`).
struct PuzzleQueueView: View {
    /// Démarre une série OUVERTE de puzzles selon ces critères — voir
    /// ``PuzzleSolveViewModel``, qui tire les puzzles un à un tant que
    /// l'utilisateur enchaîne.
    let onStartSession: (PuzzleSessionFilter) -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var selectedDifficulty: DifficultyTier?
    @State private var selectedPhase: GamePhase?
    @State private var selectedTheme: PuzzleTheme?

    @State private var hasAnyPuzzle = true
    /// Bilan (Lot 5.B), recalculé à l'apparition — voir ``refresh()``.
    @State private var stats: PuzzleStats?

    private var currentFilter: PuzzleSessionFilter {
        PuzzleSessionFilter(difficulty: selectedDifficulty, phase: selectedPhase, theme: selectedTheme)
    }

    var body: some View {
        Group {
            if !hasAnyPuzzle {
                ContentUnavailableView(
                    "Aucun puzzle",
                    systemImage: "puzzlepiece",
                    description: Text("Analysez une partie avec des erreurs pour créer des puzzles (menu \"...\" du mode Analyser).")
                )
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    filterGroup(title: "Niveau") {
                        FilterChip(label: "Tous", tint: Theme.accent, isSelected: selectedDifficulty == nil) {
                            selectedDifficulty = nil
                        }
                        ForEach(DifficultyTier.allCases, id: \.self) { tier in
                            FilterChip(
                                label: LocalizedStringKey(tier.label),
                                icon: "cellularbars",
                                iconVariableValue: tier.gaugeValue,
                                tint: Theme.accent,
                                isSelected: selectedDifficulty == tier
                            ) {
                                selectedDifficulty = (selectedDifficulty == tier) ? nil : tier
                            }
                        }
                    }

                    filterGroup(title: "Phase") {
                        FilterChip(label: "Toutes", tint: Theme.info, isSelected: selectedPhase == nil) {
                            selectedPhase = nil
                        }
                        ForEach(GamePhase.allCases, id: \.self) { phase in
                            FilterChip(label: LocalizedStringKey(phase.label), icon: phase.icon, tint: Theme.info, isSelected: selectedPhase == phase) {
                                selectedPhase = (selectedPhase == phase) ? nil : phase
                            }
                        }
                    }

                    filterGroup(title: "Type de puzzle") {
                        FilterChip(label: "Tous", tint: Theme.warning, isSelected: selectedTheme == nil) {
                            selectedTheme = nil
                        }
                        ForEach(PuzzleTheme.allCases, id: \.self) { theme in
                            FilterChip(label: LocalizedStringKey(chipLabel(for: theme)), icon: theme.icon, tint: Theme.warning, isSelected: selectedTheme == theme) {
                                selectedTheme = (selectedTheme == theme) ? nil : theme
                            }
                        }
                    }

                    if let stats, stats.successRate != nil {
                        statsCard(stats)
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 10) {
                        Text(selectionSummary)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                        startSessionButton
                    }
                }
                .padding(20)
            }
        }
        .appBackground()
        .navigationTitle("Puzzles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { refresh() }
    }

    /// "Attaque à la découverte" déborderait à côté des autres chips —
    /// raccourci en "Découverte" ici seulement (le libellé complet reste
    /// utilisé sur l'écran de résolution, où il a la place).
    private func chipLabel(for theme: PuzzleTheme) -> String {
        theme == .discoveredAttack ? String(localized: "Découverte") : theme.label
    }

    private var selectionSummary: String {
        // Chaque `.label` est une clé française : on la localise via le bundle
        // détourné (comme partout hors `Text`).
        let parts = [selectedDifficulty?.label, selectedPhase?.label, selectedTheme?.label]
            .compactMap { $0 }
            .map { LocalizationController.string($0) }
        return parts.isEmpty
            ? LocalizationController.string("Tous les puzzles, mélangés")
            : parts.joined(separator: " · ")
    }

    private var startSessionButton: some View {
        Button {
            onStartSession(currentFilter)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Commencer")
            }
            .font(.headline)
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .glow(Theme.accent, radius: 12)
        }
        .buttonStyle(.pressable)
    }

    /// Bilan : réussite globale et thèmes à travailler (Lot 5.B, exigé par le
    /// prompt : « vous ratez souvent des fourchettes »).
    ///
    /// Ne s'affiche qu'une fois quelques puzzles tentés — ni « 0 % » ni thème
    /// désigné sur trois essais.
    @ViewBuilder
    private func statsCard(_ stats: PuzzleStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Réussite", systemImage: "chart.pie.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(stats.successRate.map { "\(Int(($0 * 100).rounded())) %" } ?? "—")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
            Text("\(stats.successes) réussis sur \(stats.attempts) tentatives")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)

            if stats.hasEnoughDataForThemes {
                Divider().overlay(Theme.stroke)
                Text("À travailler")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                ForEach(stats.weakestThemes.prefix(3)) { record in
                    HStack(spacing: 8) {
                        Image(systemName: record.theme.icon)
                            .font(.caption)
                            .foregroundStyle(Theme.warning)
                        Text(LocalizedStringKey(record.theme.label))
                            .font(.caption)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(Int((record.failureRate * 100).rounded())) % d'échecs sur \(record.attempts)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityIdentifier("puzzleStats")
    }

    /// Simple check défensif : la bibliothèque entière est-elle vide
    /// (avant le préchargement, ou un bundle cassé) ? Pas de comptage par
    /// filtre ici — voir le commentaire d'en-tête.
    private func refresh() {
        let totalDescriptor = FetchDescriptor<Puzzle>()
        hasAnyPuzzle = ((try? modelContext.fetchCount(totalDescriptor)) ?? 0) > 0

        // ⚠️ Ne charge QUE les puzzles réellement tentés : la bibliothèque
        // Lichess embarquée en compte des dizaines de milliers, et les
        // matérialiser tous pour calculer un pourcentage rendrait cet écran
        // inutilisable. Le prédicat laisse SQLite faire le tri.
        var attempted = FetchDescriptor<Puzzle>(predicate: #Predicate { puzzle in
            (puzzle.successCount ?? 0) > 0 || (puzzle.failureCount ?? 0) > 0
        })
        attempted.propertiesToFetch = [\.successCount, \.failureCount, \.themeRaw]
        stats = (try? modelContext.fetch(attempted)).map { PuzzleStats.compute(from: $0) }
    }
}

private extension DifficultyTier {
    /// Remplissage de l'icône `cellularbars` (rendu à valeur variable) :
    /// une jauge qui monte avec le niveau, lisible sans compter.
    var gaugeValue: Double {
        switch self {
        case .beginner: 0.25
        case .intermediate: 0.5
        case .advanced: 0.75
        case .expert: 1.0
        }
    }
}
