import SwiftData
import SwiftUI

/// L'écran Puzzles : LANCER en un geste, régler à part, Woodpecker à sa place.
///
/// Refonte du 28/10/2026. L'écran précédent était fait de cinq groupes de
/// puces à régler AVANT de jouer, d'un bouton « Commencer » épinglé en bas, et
/// d'une carte Woodpecker coincée entre les deux, qui « reprenait les critères
/// choisis au-dessus » — en partie repliés, donc invisibles. Deux usages de
/// poids très différents (la série de tous les jours, le programme de
/// plusieurs semaines) y pesaient pareil.
///
/// Désormais, de haut en bas :
/// - **où j'en suis** : cote, réussite, thème à travailler (un toucher le lance) ;
/// - **quatre séries prêtes**, qui démarrent au toucher : à mon niveau, ratés,
///   à revoir, mes parties — chacune avec son compte, grisée à zéro ;
/// - **série sur mesure** : tous les filtres dans une feuille, avec le nombre
///   de puzzles avant de lancer ;
/// - **programme Woodpecker** : une ligne ; sa création (critères compris) vit
///   dans sa propre feuille, et un programme en cours s'y reprend.
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

    @State private var puzzleRating = PuzzleRatingStore.load()
    @State private var stats: PuzzleStats?
    @State private var hasAnyPuzzle = true
    /// Les comptes des séries prêtes ; une série à zéro est grisée.
    @State private var missedCount = 0
    @State private var reviewCount = 0
    @State private var ownCount = 0

    /// Le programme Woodpecker en cours (le plus récent non abandonné).
    @State private var woodpecker: WoodpeckerProgram?
    @State private var confirmsWoodpeckerArchive = false
    @State private var woodpeckerMessage: String?

    @State private var sheet: CriteriaSheetMode?
    /// Ce que la feuille a décidé, exécuté APRÈS sa fermeture : pousser un écran
    /// pendant qu'une feuille se ferme le fait disparaître sans bruit.
    @State private var afterSheet: (() -> Void)?

    var body: some View {
        Group {
            if !hasAnyPuzzle {
                ContentUnavailableView(
                    "Aucun puzzle",
                    systemImage: "puzzlepiece",
                    description: Text("Analysez une partie avec des erreurs pour créer des puzzles (menu \"...\" du mode Analyser).")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if let stats, stats.successRate != nil { statusCard(stats) }
                        readySeries
                        customSeriesRow
                        programmeSection
                    }
                    .padding(20)
                    .frame(maxWidth: Theme.readableWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
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
        .sheet(item: $sheet, onDismiss: {
            afterSheet?()
            afterSheet = nil
        }) { mode in
            PuzzleCriteriaSheet(mode: mode, puzzleRating: puzzleRating) { filter, size in
                switch mode {
                case .session:
                    afterSheet = { onStartSession(filter) }
                case .woodpecker:
                    if let id = createWoodpecker(filter: filter, size: size) {
                        afterSheet = { onOpenWoodpecker(id) }
                    }
                }
                sheet = nil
            }
        }
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

    // MARK: Où j'en suis

    /// Cote, réussite, et le thème le plus raté — qu'un toucher met au travail.
    private func statusCard(_ stats: PuzzleStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                if puzzleRating.count > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Votre cote")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Text((puzzleRating.isSettled ? "" : "≈ ") + "\(puzzleRating.displayed)")
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("puzzleRating")
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Réussite")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(stats.successRate.map { "\(Int(($0 * 100).rounded())) %" } ?? "—")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }
            if stats.hasEnoughDataForThemes, let weakest = stats.weakestThemes.first {
                Divider().overlay(Theme.stroke)
                Button { onStartSession(PuzzleSessionFilter(theme: weakest.theme)) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: weakest.theme.icon)
                            .foregroundStyle(Theme.warning)
                        Text("À travailler :")
                            .foregroundStyle(Theme.textSecondary)
                        Text(LocalizedStringKey(weakest.theme.label))
                            .foregroundStyle(Theme.textPrimary)
                            .fontWeight(.semibold)
                        Spacer(minLength: 0)
                        Text("\(Int((weakest.failureRate * 100).rounded())) % d'échecs")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textTertiary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .font(.subheadline)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("travailler-theme")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityIdentifier("puzzleStats")
    }

    // MARK: Séries prêtes

    /// Quatre séries qui démarrent AU TOUCHER — pas de puce à cocher puis de
    /// bouton à chercher.
    private var readySeries: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Commencer")
            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                SeriesTile(
                    title: "À mon niveau",
                    subtitle: "\(puzzleRating.window.lowerBound)–\(puzzleRating.window.upperBound)",
                    systemImage: "scope", tint: Theme.accent, count: nil
                ) {
                    onStartSession(PuzzleSessionFilter(ratingWindow: puzzleRating.window))
                }
                .accessibilityIdentifier("serie-mon-niveau")
                SeriesTile(
                    title: "Ratés", subtitle: "à refaire",
                    systemImage: "xmark.circle.fill", tint: Theme.rose, count: missedCount
                ) {
                    onStartSession(PuzzleSessionFilter(missedOnly: true))
                }
                .accessibilityIdentifier("historique-rates")
                SeriesTile(
                    title: "À revoir", subtitle: "trouvés à moitié",
                    systemImage: "arrow.counterclockwise.circle.fill", tint: Theme.warning, count: reviewCount
                ) {
                    onStartSession(PuzzleSessionFilter(reviewOnly: true))
                }
                .accessibilityIdentifier("historique-a-revoir")
                SeriesTile(
                    title: "Mes parties", subtitle: "vos erreurs",
                    systemImage: "person.fill", tint: Theme.violet, count: ownCount
                ) {
                    onStartSession(PuzzleSessionFilter(source: .ownGames))
                }
                .accessibilityIdentifier("serie-mes-parties")
            }
        }
    }

    private var customSeriesRow: some View {
        Button { sheet = .session } label: {
            linkRow(
                systemImage: "slider.horizontal.3", tint: Theme.info,
                title: "Série sur mesure", subtitle: "Niveau, phase, type, provenance"
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("serie-sur-mesure")
    }

    // MARK: Programme

    @ViewBuilder
    private var programmeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Programme")
            if let program = woodpecker, let plan = program.plan {
                runningProgramme(program, plan: plan)
            } else {
                Button { sheet = .woodpecker } label: {
                    linkRow(
                        systemImage: "arrow.triangle.2.circlepath", tint: Theme.teal,
                        title: "Méthode Woodpecker",
                        subtitle: "Un lot fixe de puzzles, repris en cycles de plus en plus rapides"
                    )
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("woodpeckerCard")
            }
        }
    }

    /// Un programme en cours : où il en est, et la reprise d'un toucher.
    private func runningProgramme(_ program: WoodpeckerProgram, plan: WoodpeckerPlan) -> some View {
        let cycle = plan.currentCycle
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconBadge(systemImage: "arrow.triangle.2.circlepath", tint: Theme.teal, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Méthode Woodpecker")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(cycle.isComplete
                         ? LocalizationController.string("Cycle %lld terminé", cycle.number)
                         : LocalizationController.string("Cycle %lld · %lld/%lld", cycle.number, cycle.attempts.count, cycle.order.count))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                    Text(program.criteria)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        // `.contain` : sans lui, l'identifiant de la carte ÉCRASE ceux de ses
        // boutons, que les tests ne retrouvent plus.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("woodpeckerProgramme")
    }

    /// Compose le lot avec les critères de la feuille. Renvoie l'identifiant du
    /// programme créé, `nil` si aucun puzzle ne correspond.
    private func createWoodpecker(filter: PuzzleSessionFilter, size: Int) -> UUID? {
        var items = PuzzleSessionDrawer.sample(matching: filter, count: size, in: modelContext)
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
            ), count: size)
        }
        #endif
        guard let plan = WoodpeckerPlan.start(items: items) else {
            woodpeckerMessage = LocalizationController.string("Aucun puzzle ne correspond à ces critères.")
            return nil
        }
        let program = WoodpeckerProgram()
        program.criteria = LocalizationController.string("%lld puzzles", plan.items.count)
            + " · " + PuzzleCriteriaSheet.summary(of: filter)
        program.plan = plan
        modelContext.insert(program)
        PersistenceLog.save(modelContext)
        woodpecker = program
        return program.id
    }

    private func archiveWoodpecker() {
        woodpecker?.isArchived = true
        PersistenceLog.save(modelContext)
        woodpecker = nil
    }

    // MARK: Briques

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .textCase(.uppercase)
            .tracking(0.4)
    }

    private func linkRow(systemImage: String, tint: Color, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: systemImage, tint: tint, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func refresh() {
        // Fusionne la progression synchronisée (dueDate, compteurs) avant de
        // lire les comptes et les stats — sinon un puzzle déjà résolu ailleurs
        // pourrait être re-servi ici. Voir ``PuzzleProgressSync``.
        puzzleRating = PuzzleRatingStore.load()
        PuzzleProgressSync.reconcileIfStale(in: modelContext)
        hasAnyPuzzle = ((try? modelContext.fetchCount(FetchDescriptor<Puzzle>())) ?? 0) > 0
        missedCount = PuzzleSessionDrawer.count(matching: PuzzleSessionFilter(missedOnly: true), in: modelContext)
        reviewCount = PuzzleSessionDrawer.count(matching: PuzzleSessionFilter(reviewOnly: true), in: modelContext)
        ownCount = PuzzleSessionDrawer.count(matching: PuzzleSessionFilter(source: .ownGames), in: modelContext)

        // ⚠️ Ne charge QUE les puzzles réellement tentés : la bibliothèque
        // embarquée en compte plus de cent mille, et les matérialiser tous pour
        // un pourcentage rendrait cet écran inutilisable. SQLite fait le tri.
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

/// Une série prête : elle démarre au toucher. Son compte s'affiche ; à zéro,
/// elle est grisée (il n'y a rien à y faire).
private struct SeriesTile: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let tint: Color
    /// `nil` : pas de compte (« À mon niveau » puise dans toute la bibliothèque).
    let count: Int?
    let action: () -> Void

    private var isEmpty: Bool { count == 0 }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(tint)
                    Spacer(minLength: 0)
                    if let count {
                        Text("\(count)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(count > 0 ? tint : Theme.textTertiary)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(tint.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .disabled(isEmpty)
        .opacity(isEmpty ? 0.4 : 1)
    }
}

/// Ce que la feuille de critères prépare : une série, ou un programme Woodpecker.
enum CriteriaSheetMode: String, Identifiable {
    case session, woodpecker
    var id: String { rawValue }
}

/// Tous les filtres, dans une feuille : niveau, phase, type, provenance. Rien de
/// coché = tout — pas de puce « Tous » à chaque groupe. Le nombre de puzzles
/// correspondants s'affiche avant de lancer ; en mode Woodpecker, on choisit
/// aussi la taille du lot.
struct PuzzleCriteriaSheet: View {
    let mode: CriteriaSheetMode
    let puzzleRating: PuzzleRating
    /// Critères retenus, et taille du lot (mode Woodpecker).
    let onConfirm: (PuzzleSessionFilter, Int) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var difficulty: DifficultyTier?
    @State private var atMyLevel = false
    @State private var phase: GamePhase?
    @State private var theme: PuzzleTheme?
    @State private var source: PuzzleSource?
    @State private var size = WoodpeckerPlan.defaultSize
    @State private var matching = 0

    private var filter: PuzzleSessionFilter {
        PuzzleSessionFilter(
            difficulty: difficulty, phase: phase, theme: theme, source: source,
            ratingWindow: atMyLevel ? puzzleRating.window : nil
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if mode == .woodpecker {
                            Text("Un lot fixe de puzzles, résolu en entier puis repris dans un nouvel ordre, cycle après cycle, pour en trouver plus et plus vite. Choisissez ses puzzles, puis sa taille.")
                                .font(.callout)
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // Vos puzzles n'ont pas de cote : un niveau les exclurait tous.
                        if source != .ownGames {
                            filterGroup(title: "Niveau", systemImage: "cellularbars", tint: Theme.accent) {
                                FilterChip(label: "À mon niveau", icon: "scope", tint: Theme.accent, isSelected: atMyLevel) {
                                    atMyLevel.toggle()
                                    if atMyLevel { difficulty = nil }
                                }
                                .accessibilityIdentifier("niveau-mien")
                                ForEach(DifficultyTier.allCases, id: \.self) { tier in
                                    FilterChip(
                                        label: LocalizedStringKey(tier.label), icon: "cellularbars",
                                        iconVariableValue: tier.gaugeValue, tint: Theme.accent,
                                        isSelected: difficulty == tier
                                    ) {
                                        difficulty = difficulty == tier ? nil : tier
                                        atMyLevel = false
                                    }
                                    .accessibilityIdentifier("niveau-\(tier.rawValue)")
                                }
                            }
                        }
                        filterGroup(title: "Phase", systemImage: "flag.checkered", tint: Theme.info) {
                            ForEach(GamePhase.allCases, id: \.self) { value in
                                FilterChip(label: LocalizedStringKey(value.label), icon: value.icon, tint: Theme.info, isSelected: phase == value) {
                                    phase = phase == value ? nil : value
                                }
                            }
                        }
                        filterGroup(title: "Type de puzzle", systemImage: "puzzlepiece.fill", tint: Theme.warning) {
                            ForEach(PuzzleTheme.allCases, id: \.self) { value in
                                FilterChip(label: LocalizedStringKey(Self.chipLabel(for: value)), icon: value.icon, tint: Theme.warning, isSelected: theme == value) {
                                    theme = theme == value ? nil : value
                                }
                            }
                        }
                        filterGroup(title: "Provenance", systemImage: "square.stack.3d.up.fill", tint: Theme.violet) {
                            ForEach(PuzzleSource.allCases, id: \.self) { value in
                                FilterChip(label: LocalizedStringKey(value.label), icon: value.icon, tint: Theme.violet, isSelected: source == value) {
                                    source = source == value ? nil : value
                                    if source == .ownGames { difficulty = nil; atMyLevel = false }
                                }
                                .accessibilityIdentifier("provenance-\(value.rawValue)")
                            }
                        }
                        if mode == .woodpecker {
                            filterGroup(title: "Taille du lot", systemImage: "number", tint: Theme.teal) {
                                Picker("Taille du lot", selection: $size) {
                                    ForEach(WoodpeckerPlan.sizes, id: \.self) { Text("\($0)").tag($0) }
                                }
                                .pickerStyle(.segmented)
                                .accessibilityIdentifier("woodpeckerSize")
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                footer
            }
            .appBackground()
            .navigationTitle(mode == .session ? "Série sur mesure" : "Méthode Woodpecker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Réinitialiser") {
                        difficulty = nil; atMyLevel = false; phase = nil; theme = nil; source = nil
                    }
                    .disabled(difficulty == nil && !atMyLevel && phase == nil && theme == nil && source == nil)
                }
            }
            .onAppear { recount() }
            .onChange(of: filter) { recount() }
        }
        .presentationDetents([.large])
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text(Self.summary(of: filter))
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
            Button { onConfirm(filter, size) } label: {
                HStack(spacing: 8) {
                    Image(systemName: mode == .session ? "play.fill" : "arrow.triangle.2.circlepath")
                    if mode == .session {
                        Text("Commencer · \(matching) puzzles")
                    } else {
                        Text("Créer le programme")
                    }
                }
                .font(.headline)
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(matching == 0)
            .opacity(matching == 0 ? 0.4 : 1)
            .accessibilityIdentifier(mode == .session ? "startPuzzleSession" : "woodpeckerCreate")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(Theme.background)
        .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }

    /// Une série compte les puzzles DUS ; un programme puise dans tous ceux qui
    /// correspondent, dus ou non (voir ``PuzzleSessionDrawer/sample``).
    private func recount() {
        matching = mode == .session
            ? PuzzleSessionDrawer.count(matching: filter, in: modelContext)
            : PuzzleSessionDrawer.countIgnoringSchedule(matching: filter, in: modelContext)
    }

    /// La sélection en une ligne — aussi le libellé d'un programme Woodpecker.
    static func summary(of filter: PuzzleSessionFilter) -> String {
        let myLevel = filter.ratingWindow.map {
            LocalizationController.string("À mon niveau") + " (\($0.lowerBound)–\($0.upperBound))"
        }
        let parts = [
            filter.source?.label, filter.missedOnly ? "Ratés" : nil, filter.reviewOnly ? "À revoir" : nil,
            filter.difficulty?.label, filter.phase?.label, filter.theme?.label,
        ]
            .compactMap { $0 }
            .map { LocalizationController.string($0) }
            + [myLevel].compactMap { $0 }
        return parts.isEmpty
            ? LocalizationController.string("Tous les puzzles, mélangés")
            : parts.joined(separator: " · ")
    }

    /// "Attaque à la découverte" déborderait à côté des autres chips —
    /// raccourci en "Découverte" ici seulement (le libellé complet reste
    /// utilisé sur l'écran de résolution, où il a la place).
    private static func chipLabel(for theme: PuzzleTheme) -> String {
        theme == .discoveredAttack ? LocalizationController.string("Découverte") : theme.label
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
