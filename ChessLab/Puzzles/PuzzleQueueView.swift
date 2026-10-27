import SwiftData
import SwiftUI

/// Écran de sélection avant une série de puzzles : cinq groupes de chips
/// capsules (provenance, historique, niveau, phase, type de puzzle) qui
/// défilent, et un bouton "Commencer" épinglé en bas. Chaque groupe porte
/// sa propre teinte (violet/rose/vert/bleu/ambre, reprises de ``Theme``)
/// pour se repérer d'un coup d'œil ; la ligne de
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
    var onOpenLab: () -> Void = {}
    var onPlayVsEngine: () -> Void = {}
    var onOpenTwoPlayer: () -> Void = {}
    /// Ouvre un programme Woodpecker (créé ici, ou repris).
    var onOpenWoodpecker: (UUID) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext

    @State private var selectedDifficulty: DifficultyTier?
    @State private var selectedPhase: GamePhase?
    @State private var selectedTheme: PuzzleTheme?
    @State private var selectedSource: PuzzleSource?
    /// « À mon niveau » : la cote personnelle fixe la fenêtre de puzzles.
    @State private var atMyLevel = false
    @State private var puzzleRating = PuzzleRatingStore.load()
    @State private var missedOnly = false
    /// Puzzles ratés à la dernière tentative : à zéro, la puce « Ratés » est grisée (rien à y retrouver).
    @State private var missedCount = 0

    @State private var hasAnyPuzzle = true
    /// Bilan (Lot 5.B), recalculé à l'apparition — voir ``refresh()``.
    @State private var stats: PuzzleStats?
    /// Le programme Woodpecker en cours (le plus récent non abandonné).
    @State private var woodpecker: WoodpeckerProgram?
    @State private var woodpeckerSize = WoodpeckerPlan.defaultSize
    @State private var confirmsWoodpeckerArchive = false
    @State private var woodpeckerMessage: String?

    private var currentFilter: PuzzleSessionFilter {
        PuzzleSessionFilter(
            difficulty: selectedDifficulty, phase: selectedPhase, theme: selectedTheme,
            source: selectedSource, missedOnly: missedOnly,
            ratingWindow: atMyLevel ? puzzleRating.window : nil
        )
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
                // Filtres DÉFILANTS + pied épinglé (« Commencer » toujours
                // accessible). Sur grand écran, le `ScrollView` occupe toute la
                // hauteur et pousse le pied en bas comme avant ; sur petit écran
                // (SE…), les filtres défilent au lieu d'être tassés/rognés.
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            filterGroup(title: "Provenance", systemImage: "square.stack.3d.up.fill", tint: Theme.violet) {
                                FilterChip(label: "Toutes", tint: Theme.violet, isSelected: selectedSource == nil) {
                                    selectedSource = nil
                                }
                                .accessibilityIdentifier("provenance-toutes")
                                ForEach(PuzzleSource.allCases, id: \.self) { source in
                                    FilterChip(label: LocalizedStringKey(source.label), icon: source.icon, tint: Theme.violet, isSelected: selectedSource == source) {
                                        selectedSource = (selectedSource == source) ? nil : source
                                        // Vos puzzles n'ont pas de cote : un niveau
                                        // choisi les exclurait TOUS (voir le
                                        // prédicat du tirage).
                                        if selectedSource == .ownGames { selectedDifficulty = nil }
                                    }
                                    .accessibilityIdentifier("provenance-\(source.rawValue)")
                                }
                            }

                            filterGroup(title: "Historique", systemImage: "clock.arrow.circlepath", tint: Theme.rose) {
                                FilterChip(label: "Tous", tint: Theme.rose, isSelected: !missedOnly) {
                                    missedOnly = false
                                }
                                .accessibilityIdentifier("historique-tous")
                                FilterChip(label: "Ratés", icon: "xmark.circle.fill", tint: Theme.rose, isSelected: missedOnly) {
                                    missedOnly.toggle()
                                }
                                .disabled(missedCount == 0)
                                .opacity(missedCount == 0 ? 0.35 : 1)
                                .accessibilityIdentifier("historique-rates")
                            }

                            // Masqué pour « Mes parties » : sans cote, aucun
                            // niveau ne retiendrait un seul puzzle.
                            if selectedSource != .ownGames {
                                filterGroup(title: "Niveau", systemImage: "cellularbars", tint: Theme.accent) {
                                    FilterChip(label: "Tous", tint: Theme.accent, isSelected: selectedDifficulty == nil && !atMyLevel) {
                                        selectedDifficulty = nil
                                        atMyLevel = false
                                    }
                                    .accessibilityIdentifier("niveau-tous")
                                    // Ma cote, plutôt qu'un palier : les puzzles
                                    // se resserrent autour de ce que je réussis.
                                    FilterChip(label: "À mon niveau", icon: "scope", tint: Theme.accent, isSelected: atMyLevel) {
                                        atMyLevel.toggle()
                                        if atMyLevel { selectedDifficulty = nil }
                                    }
                                    .accessibilityIdentifier("niveau-mien")
                                    ForEach(DifficultyTier.allCases, id: \.self) { tier in
                                        FilterChip(
                                            label: LocalizedStringKey(tier.label),
                                            icon: "cellularbars",
                                            iconVariableValue: tier.gaugeValue,
                                            tint: Theme.accent,
                                            isSelected: selectedDifficulty == tier
                                        ) {
                                            selectedDifficulty = (selectedDifficulty == tier) ? nil : tier
                                            atMyLevel = false
                                        }
                                    }
                                }
                            }

                            filterGroup(title: "Phase", systemImage: "flag.checkered", tint: Theme.info) {
                                FilterChip(label: "Toutes", tint: Theme.info, isSelected: selectedPhase == nil) {
                                    selectedPhase = nil
                                }
                                ForEach(GamePhase.allCases, id: \.self) { phase in
                                    FilterChip(label: LocalizedStringKey(phase.label), icon: phase.icon, tint: Theme.info, isSelected: selectedPhase == phase) {
                                        selectedPhase = (selectedPhase == phase) ? nil : phase
                                    }
                                }
                            }

                            filterGroup(title: "Type de puzzle", systemImage: "puzzlepiece.fill", tint: Theme.warning) {
                                FilterChip(label: "Tous", tint: Theme.warning, isSelected: selectedTheme == nil) {
                                    selectedTheme = nil
                                }
                                ForEach(PuzzleTheme.allCases, id: \.self) { theme in
                                    FilterChip(label: LocalizedStringKey(chipLabel(for: theme)), icon: theme.icon, tint: Theme.warning, isSelected: selectedTheme == theme) {
                                        selectedTheme = (selectedTheme == theme) ? nil : theme
                                    }
                                }
                            }

                            woodpeckerCard

                            if let stats, stats.successRate != nil {
                                statsCard(stats)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: 10) {
                        Text(selectionSummary)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                        startSessionButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    .background(Theme.background)
                    // Fin liseré haut : sépare le pied du contenu qui défile
                    // dessous, sans ombre lourde.
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Theme.stroke)
                            .frame(height: 1)
                    }
                }
            }
        }
        .appBackground()
        .navigationTitle("Puzzles")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                QuickSwitchMenu(
                    onPlayVsEngine: onPlayVsEngine, onOpenTwoPlayer: onOpenTwoPlayer, onOpenLab: onOpenLab
                )
            }
        }
        .onAppear { refresh() }
        .confirmationDialog(
            "Arrêter ce programme ?",
            isPresented: $confirmsWoodpeckerArchive,
            titleVisibility: .visible
        ) {
            Button("Arrêter le programme", role: .destructive) { archiveWoodpecker() }
        } message: {
            Text("Ses cycles restent enregistrés, mais il ne sera plus proposé.")
        }
        .alert(
            "Woodpecker",
            isPresented: Binding(get: { woodpeckerMessage != nil }, set: { if !$0 { woodpeckerMessage = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(woodpeckerMessage ?? "")
        }
    }

    // MARK: Woodpecker

    /// La méthode Woodpecker : un lot FIXE, repris en cycles de plus en plus
    /// rapides (voir ``WoodpeckerPlan``). Un seul programme en cours à la
    /// fois — la carte propose de le reprendre, sinon d'en créer un avec les
    /// critères choisis au-dessus.
    @ViewBuilder
    private var woodpeckerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Méthode Woodpecker", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            if let program = woodpecker, let plan = program.plan {
                let cycle = plan.currentCycle
                Text(program.criteria)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(cycle.isComplete
                     ? LocalizationController.string("Cycle %lld terminé", cycle.number)
                     : LocalizationController.string("Cycle %lld · %lld/%lld", cycle.number, cycle.attempts.count, cycle.order.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                if let finished = plan.cycles.last(where: \.isComplete) {
                    Text(LocalizationController.string(
                        "Cycle %lld : %lld trouvés sur %lld en %@",
                        finished.number, finished.solvedCount, finished.order.count,
                        WoodpeckerPlan.formatDuration(finished.activeSeconds)
                    ))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
                }
                HStack(spacing: 10) {
                    Button { onOpenWoodpecker(program.id) } label: {
                        Text(cycle.isComplete
                             ? LocalizationController.string("Commencer le cycle %lld", cycle.number + 1)
                             : LocalizationController.string("Reprendre"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.accentGradient, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("woodpeckerResume")
                    // « Arrêter » et non « Abandonner », qui se traduit
                    // « Resign » : abandonner une PARTIE, pas un programme.
                    Button("Arrêter", role: .destructive) { confirmsWoodpeckerArchive = true }
                        .font(.subheadline)
                        .accessibilityIdentifier("woodpeckerArchive")
                }
            } else {
                Text("Un lot fixe de puzzles, résolu en entier puis repris dans un nouvel ordre, cycle après cycle, pour en trouver plus et plus vite. Il reprend les critères choisis au-dessus.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("Taille du lot", selection: $woodpeckerSize) {
                    ForEach(WoodpeckerPlan.sizes, id: \.self) { size in
                        Text("\(size)").tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("woodpeckerSize")
                Button { createWoodpecker() } label: {
                    Text("Créer le programme")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.strokeStrong, lineWidth: 1))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("woodpeckerCreate")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        // `.contain` : sans lui, l'identifiant de la carte ÉCRASE ceux de ses
        // boutons, que les tests ne retrouvent plus.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("woodpeckerCard")
    }

    /// Compose le lot avec les critères de l'écran, puis l'ouvre aussitôt.
    private func createWoodpecker() {
        var items = PuzzleSessionDrawer.sample(matching: currentFilter, count: woodpeckerSize, in: modelContext)
            .map(WoodpeckerPlan.Item.init)
        #if DEBUG
        // Outil de test : un lot CONNU — le mat en deux du couloir, riposte
        // comprise (Te8+ Txe8 Txe8#) —, pour qu'un test d'interface joue un
        // cycle entier sans lire l'échiquier. Debug seulement.
        if CommandLine.arguments.contains("-uiTestWoodpeckerDemo") {
            items = Array(repeating: WoodpeckerPlan.Item(
                fen: "r5k1/5ppp/8/8/8/4R3/5PPP/4R1K1 w - - 0 23",
                solutionLANs: ["e3e8", "a8e8", "e1e8"], themeRaw: PuzzleTheme.checkmate.rawValue,
                phaseRaw: GamePhase.endgame.rawValue
            ), count: woodpeckerSize)
        }
        #endif
        guard let plan = WoodpeckerPlan.start(items: items) else {
            woodpeckerMessage = LocalizationController.string("Aucun puzzle ne correspond à ces critères.")
            return
        }
        let program = WoodpeckerProgram()
        program.criteria = LocalizationController.string("%lld puzzles", plan.items.count) + " · " + selectionSummary
        program.plan = plan
        modelContext.insert(program)
        PersistenceLog.save(modelContext)
        woodpecker = program
        onOpenWoodpecker(program.id)
    }

    private func archiveWoodpecker() {
        woodpecker?.isArchived = true
        PersistenceLog.save(modelContext)
        woodpecker = nil
    }

    /// "Attaque à la découverte" déborderait à côté des autres chips —
    /// raccourci en "Découverte" ici seulement (le libellé complet reste
    /// utilisé sur l'écran de résolution, où il a la place).
    private func chipLabel(for theme: PuzzleTheme) -> String {
        theme == .discoveredAttack ? LocalizationController.string("Découverte") : theme.label
    }

    private var selectionSummary: String {
        // Chaque `.label` est une clé française : on la localise via le bundle
        // détourné (comme partout hors `Text`).
        let myLevel: String? = atMyLevel
            ? LocalizationController.string("À mon niveau") + " (\(puzzleRating.window.lowerBound)–\(puzzleRating.window.upperBound))"
            : nil
        let parts = [
            selectedSource?.label, missedOnly ? "Ratés" : nil,
            selectedDifficulty?.label, myLevel, selectedPhase?.label, selectedTheme?.label,
        ]
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
        .accessibilityIdentifier("startPuzzleSession")
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
            if puzzleRating.count > 0 {
                HStack {
                    Label("Cote de puzzle", systemImage: "scope")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text((puzzleRating.isSettled ? "" : "≈ ") + "\(puzzleRating.displayed)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("puzzleRating")
            }

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
        // Fusionne la progression synchronisée (dueDate, compteurs) avant de
        // lire la file et les stats — sinon un puzzle déjà résolu ailleurs
        // pourrait être re-servi ici. Voir ``PuzzleProgressSync``.
        puzzleRating = PuzzleRatingStore.load()
        PuzzleProgressSync.reconcileIfStale(in: modelContext)
        let totalDescriptor = FetchDescriptor<Puzzle>()
        hasAnyPuzzle = ((try? modelContext.fetchCount(totalDescriptor)) ?? 0) > 0
        missedCount = PuzzleSessionDrawer.count(matching: PuzzleSessionFilter(source: nil, missedOnly: true), in: modelContext)
        if missedCount == 0 { missedOnly = false }

        // ⚠️ Ne charge QUE les puzzles réellement tentés : la bibliothèque
        // Lichess embarquée en compte des dizaines de milliers, et les
        // matérialiser tous pour calculer un pourcentage rendrait cet écran
        // inutilisable. Le prédicat laisse SQLite faire le tri.
        var attempted = FetchDescriptor<Puzzle>(predicate: #Predicate { puzzle in
            (puzzle.successCount ?? 0) > 0 || (puzzle.failureCount ?? 0) > 0
        })
        attempted.propertiesToFetch = [\.successCount, \.failureCount, \.themeRaw]
        stats = (try? modelContext.fetch(attempted)).map { PuzzleStats.compute(from: $0) }

        var programs = FetchDescriptor<WoodpeckerProgram>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        programs.fetchLimit = 1
        woodpecker = (try? modelContext.fetch(programs))?.first
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
