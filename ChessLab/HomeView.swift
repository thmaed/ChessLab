import ChessKit
import SwiftData
import SwiftUI

/// Accueil : cartes de mode + reprise de la dernière activité.
///
/// "Contre l'ordinateur", "Deux joueurs", "Analyser", "Ouvertures" et
/// "Puzzles" sont actifs ; seul "Laboratoire" reste désactivé en
/// attendant son tour. "Contre l'ordinateur"/"Deux joueurs" menaient à un
/// écran de choix intermédiaire (``PlayModeChoiceView``) jusqu'à ce
/// qu'un retour utilisateur le juge superflu — ce sont maintenant deux
/// tuiles directes.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    /// Décide de l'ossature : `.regular` (iPad plein écran, Mac) → barre
    /// latérale + détail (``NavigationSplitView``) ; `.compact` (iPhone, iPad
    /// en multitâche étroit) → pile + grille de modes, inchangée.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Mode sélectionné dans la barre latérale (iPad/Mac). `nil` = tableau de
    /// bord d'accueil (reprise, progression, parties récentes).
    @State private var sidebarSelection: SidebarItem?
    @State private var resumableGame: ResumableGame?
    /// Bilan de progression compact du panneau iPad — recalculé à l'apparition.
    @State private var progressSummary: ProgressionSummary?
    @State private var path = NavigationPath()
    /// Relais de la barre de menus macOS — voir ``MenuCommands``.
    @State private var menuCommands = MenuCommands.shared

    @State private var seedingState = PuzzleSeedingState.shared

    /// Les dernières parties terminées, pour un accès direct à leur analyse
    /// depuis l'accueil. `fetchLimit` borné : un joueur peut accumuler des
    /// centaines de parties, on n'en montre qu'une poignée. `GameRecord` est
    /// une petite table (rien à voir avec les puzzles Lichess), un `@Query`
    /// vivant y est donc sans danger.
    @Query(Self.recentGamesDescriptor) private var recentGames: [GameRecord]

    private static var recentGamesDescriptor: FetchDescriptor<GameRecord> {
        var descriptor = FetchDescriptor<GameRecord>(
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 4
        return descriptor
    }

    private enum Route: Hashable {
        case newGame
        /// « Continuer contre Stockfish » depuis une ligne/un répertoire : on
        /// passe par l'écran de réglages (pré-rempli avec la position) pour
        /// que le joueur CHOISISSE l'Elo au lieu de repartir en silence aux
        /// derniers réglages. Porte le FEN atteint.
        case continueVsStockfish(String)
        case activeGame(PlayGameSettings)
        case resumedGame(PlayGameAutosave)
        case twoPlayerSetup
        case activeTwoPlayerGame(TwoPlayerGameSettings)
        case resumedTwoPlayerGame(TwoPlayerGameAutosave)
        case analysisEntry
        case analysisLibrary
        case activeAnalysis(AnalysisSource)
        case positionEditor(String?)
        case scanner
        case puzzleQueue
        case activePuzzleSession(PuzzleSessionFilter)
        case repertoireList
        case activeOpeningLine(OpeningLibraryEntry, Piece.Color)
        /// Nouveau module en graphe (mode Explorer), gardé par
        /// ``OpeningsGraphFeature`` — voir J6.
        case openingExplorerPicker
        case openingExplorerCourse(String)
        case openingLearnCourse(String)
        /// Réglages Labo, éventuellement pré-remplis avec une position de
        /// départ venue de l'éditeur ou du scanner.
        case labSetup(startFEN: String?)
        case activeLab(LabGameSettings)
        case resumedLab(LabSeriesState)
        case progression
        case settings
        case help
        case licenses
    }

    /// Entrées de la barre latérale iPad/Mac. Chacune enracine la colonne de
    /// détail sur l'écran d'entrée du mode correspondant (voir ``detailRoot``).
    enum SidebarItem: Hashable {
        case vsEngine, twoPlayer, puzzles, openings, analysis, laboratory
        case progression, settings, help
    }

    /// Ouvre une destination demandée par la barre de menus. On repart de
    /// l'ACCUEIL plutôt que d'empiler : un menu déclenché depuis le fond
    /// d'une partie doit mener à l'écran demandé, pas l'enterrer sous trois
    /// niveaux dont on ne ressort qu'à coups de « retour ».
    private func open(_ destination: MenuDestination) {
        let item: SidebarItem
        let route: Route
        switch destination {
        case .newGame: item = .vsEngine; route = .newGame
        case .twoPlayer: item = .twoPlayer; route = .twoPlayerSetup
        case .analysis: item = .analysis; route = .analysisEntry
        case .puzzles: item = .puzzles; route = .puzzleQueue
        case .openings: item = .openings; route = .repertoireList
        case .laboratory: item = .laboratory; route = .labSetup(startFEN: nil)
        case .progression: item = .progression; route = .progression
        case .settings: item = .settings; route = .settings
        case .help: item = .help; route = .help
        }
        // iPad/Mac : sélectionner le mode dans la barre latérale (la colonne
        // de détail s'enracine dessus). iPhone : empiler l'entrée sur la pile.
        if horizontalSizeClass == .regular {
            sidebarSelection = item
            path = NavigationPath()
        } else {
            path = NavigationPath()
            path.append(route)
        }
    }

    /// Marqueur invisible pour les tests UI (Lot 6.A) : combien de moteurs
    /// sont vivants, et combien ont été créés depuis le lancement.
    ///
    /// Sur l'ACCUEIL, parce que c'est là que la réponse doit être zéro : tout
    /// écran moteur a été quitté. Un contrôleur qui survit à son écran, c'est
    /// un Stockfish qui cherche derrière l'interface, invisible et vorace.
    private var engineInstanceMarker: some View {
        // Lit le MIROIR observable, pas le compteur brut : ce dernier mute sous
        // verrou (parfois depuis un `deinit`) sans rien dire à SwiftUI, et la
        // valeur d'accessibilité restait périmée. Le miroir force le re-rendu.
        Color.clear
            .accessibilityIdentifier("engineInstances")
            .accessibilityValue("\(EngineInstanceObserver.shared.alive)/\(EngineInstanceObserver.shared.created)")
    }

    /// Une seule bannière "Reprendre" à la fois : si les deux modes ont
    /// une autosauvegarde en attente (cas rare — abandon d'une partie
    /// dans un mode pendant qu'une autre restait en pause dans l'autre),
    /// on retient la plus récente plutôt que d'empiler deux bannières.
    private enum ResumableGame {
        case vsEngine(PlayGameAutosave)
        case twoPlayer(TwoPlayerGameAutosave)

        var savedAt: Date {
            switch self {
            case let .vsEngine(autosave): autosave.savedAt
            case let .twoPlayer(autosave): autosave.savedAt
            }
        }

        var moveCount: Int {
            switch self {
            case let .vsEngine(autosave): autosave.moveLANs.count
            case let .twoPlayer(autosave): autosave.moveLANs.count
            }
        }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                splitBody
            } else {
                stackBody
            }
        }
        .onChange(of: menuCommands.requested) { _, destination in
            guard let destination else { return }
            menuCommands.requested = nil
            open(destination)
        }
        .onAppear {
            refreshResumableGame()
            // Fusionne la progression puzzles synchronisée (autres appareils)
            // dans les Puzzle locaux AVANT de calculer le bilan — voir
            // ``PuzzleProgressSync``. No-op si rien n'est encore synchronisé.
            PuzzleProgressSync.reconcile(in: modelContext)
            // Fusionne de même la progression d'ouvertures synchronisée : dédup
            // des enregistrements par clé FEN et recalcul de l'état FSRS en
            // rejouant le journal fusionné — voir ``OpeningProgressSync``. No-op
            // tant que rien n'a été révisé.
            OpeningProgressSync.reconcile(in: modelContext)
            loadProgressSummary()
            // Préchargement (ponctuel, au tout premier lancement) de la
            // bibliothèque Lichess : lancé en TÂCHE DE FOND par le seeder —
            // n'occupe jamais le fil principal.
            PuzzleLibrarySeeder.seedIfNeeded(container: modelContext.container)
        }
        // Retour à l'accueil (pile vidée) — y compris par le bouton retour
        // SYSTÈME, qui ne passe PAS par les closures `onExit`. Sans ce
        // rafraîchissement, `resumableGame` gardait un instantané figé : la
        // reprise rouvrait une partie périmée avec un mauvais nombre de coups,
        // alors que l'autosave sur disque était pourtant à jour. On recharge
        // donc la reprise ET le bilan de progression (une partie vient
        // peut-être de se terminer).
        .onChange(of: path) { _, newPath in
            if newPath.isEmpty {
                refreshResumableGame()
                loadProgressSummary()
            }
        }
    }

    // MARK: Ossature iPhone (pile + grille)

    /// iPhone (et iPad en multitâche étroit) : pile classique, grille de modes
    /// en racine — le header maison remplace le grand titre système.
    private var stackBody: some View {
        NavigationStack(path: $path) {
            iPhoneHome
                .appBackground()
                .scrollContentBackground(.hidden)
                .background(engineInstanceMarker)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 10) {
                            toolbarCircleButton(
                                "chart.bar.xaxis", label: "Progression",
                                identifier: "openProgression"
                            ) { path.append(Route.progression) }
                            toolbarCircleButton(
                                "gearshape.fill", label: "Réglages",
                                identifier: "openSettings"
                            ) { path.append(Route.settings) }
                        }
                    }
                }
                .navigationDestination(for: Route.self) { destination(for: $0) }
        }
    }

    // MARK: Ossature iPad / Mac (barre latérale + détail)

    /// iPad plein écran & Mac : barre latérale des modes (+ suivi) et une
    /// colonne de détail qui enracine le mode choisi et empile son flux. La
    /// grille de tuiles laisse place à une navigation persistante, mieux
    /// adaptée au grand écran (Axe A de la roadmap v2).
    private var splitBody: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            NavigationStack(path: $path) {
                detailRoot
                    .appBackground()
                    .scrollContentBackground(.hidden)
                    .navigationDestination(for: Route.self) { destination(for: $0) }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            // Reprise EN HAUT et PERSISTANTE (au-dessus des modes) : sur iPad,
            // le tableau de bord de détail disparaît dès qu'on choisit un mode ;
            // la reprise, elle, doit rester accessible quoi qu'on regarde.
            if let resumableGame {
                Section {
                    Button {
                        // Vide la pile de détail puis montre la partie reprise
                        // (indépendant du mode éventuellement sélectionné).
                        path = NavigationPath()
                        switch resumableGame {
                        case let .vsEngine(autosave): path.append(Route.resumedGame(autosave))
                        case let .twoPlayer(autosave): path.append(Route.resumedTwoPlayerGame(autosave))
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Reprendre la partie en cours")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(resumableGame.moveCount) coup(s) joué(s)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("resumeGame")
                }
            }
            Section("Modes") {
                sidebarLabel(.vsEngine, "Contre l'ordinateur", "cpu", Theme.accent)
                sidebarLabel(.twoPlayer, "Deux joueurs", "person.2.fill", Theme.info)
                sidebarLabel(.puzzles, "Puzzles", "puzzlepiece.fill", Theme.violet)
                sidebarLabel(.openings, "Ouvertures", "books.vertical.fill", Theme.warning)
                sidebarLabel(.analysis, "Analyser", "chart.xyaxis.line", Theme.teal)
                sidebarLabel(.laboratory, "Laboratoire", "flask", Theme.rose)
            }
            Section("Suivi") {
                sidebarLabel(.progression, "Progression", "chart.bar.xaxis", Theme.accent)
                sidebarLabel(.settings, "Réglages", "gearshape.fill", Theme.textSecondary)
                sidebarLabel(.help, "Aide", "questionmark.circle", Theme.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .background(engineInstanceMarker)
        .navigationTitle("ChessLab")
        // Changer de mode repart d'un flux neuf (la pile de détail est vidée) :
        // sélectionner « Puzzles » depuis une analyse ne doit pas laisser les
        // écrans d'analyse empilés dessous.
        .onChange(of: sidebarSelection) { _, _ in path = NavigationPath() }
    }

    private func sidebarLabel(
        _ item: SidebarItem, _ title: LocalizedStringKey, _ icon: String, _ tint: Color
    ) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon).foregroundStyle(tint)
        }
        .tag(item)
    }

    /// Racine de la colonne de détail selon la sélection — réutilise le mapping
    /// ``destination(for:)`` (l'écran d'entrée de chaque mode), ou le tableau de
    /// bord d'accueil quand rien n'est sélectionné.
    @ViewBuilder
    private var detailRoot: some View {
        switch sidebarSelection {
        case .vsEngine: destination(for: .newGame)
        case .twoPlayer: destination(for: .twoPlayerSetup)
        case .puzzles: destination(for: .puzzleQueue)
        case .openings: destination(for: .repertoireList)
        case .analysis: destination(for: .analysisEntry)
        case .laboratory: destination(for: .labSetup(startFEN: nil))
        case .progression: destination(for: .progression)
        case .settings: destination(for: .settings)
        case .help: destination(for: .help)
        case nil: iPadDashboard
        }
    }

    /// Tableau de bord d'accueil (colonne de détail, aucune sélection) :
    /// reprise, progression, parties récentes — borné en largeur pour rester
    /// lisible sur un très grand écran.
    private var iPadDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                homeHeader
                if seedingState.isSeeding { seedingBanner }
                // La reprise vit désormais en HAUT de la barre latérale
                // (persistante) — voir `sidebar` — pour ne pas doublonner ici.
                homeProgressCard
                if !recentGames.isEmpty { recentGamesSection }
            }
            .padding(28)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .appBackground()
        .scrollContentBackground(.hidden)
    }

    /// Mapping route → écran, PARTAGÉ par la pile iPhone et la colonne de
    /// détail iPad/Mac (``NavigationSplitView``) : une seule source de vérité
    /// pour la navigation, quelle que soit l'ossature.
    @ViewBuilder
    private func destination(for route: Route) -> some View {
                switch route {
                case .newGame:
                    NewGameSetupView { settings in
                        // Remplace l'écran de réglages par la partie. En pile
                        // (iPhone) il est empilé ; en racine de détail (iPad) la
                        // pile est vide — d'où la garde, sinon `removeLast`
                        // plante sur une pile vide.
                        if !path.isEmpty { path.removeLast() }
                        path.append(Route.activeGame(settings))
                    }

                case let .continueVsStockfish(fen):
                    // Même écran que « Nouvelle partie », pré-rempli avec la
                    // position atteinte : le joueur règle l'Elo puis lance.
                    NewGameSetupView(initialFEN: fen) { settings in
                        path.append(Route.activeGame(settings))
                    }

                case let .activeGame(settings):
                    ActiveGameHost(settings: settings) {
                        path = NavigationPath()
                        refreshResumableGame()
                    } onAnalyze: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    } onRematch: { newSettings in
                        rematch(with: newSettings)
                    }

                case let .resumedGame(autosave):
                    ResumedGameHost(autosave: autosave) {
                        path = NavigationPath()
                        refreshResumableGame()
                    } onAnalyze: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    } onRematch: { newSettings in
                        rematch(with: newSettings)
                    }

                case .twoPlayerSetup:
                    TwoPlayerSetupView { settings in
                        if !path.isEmpty { path.removeLast() }
                        path.append(Route.activeTwoPlayerGame(settings))
                    }

                case let .activeTwoPlayerGame(settings):
                    TwoPlayerActiveGameHost(settings: settings) {
                        path = NavigationPath()
                        refreshResumableGame()
                    } onAnalyze: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    } onRematch: { newSettings in
                        twoPlayerRematch(with: newSettings)
                    }

                case let .resumedTwoPlayerGame(autosave):
                    TwoPlayerResumedGameHost(autosave: autosave) {
                        path = NavigationPath()
                        refreshResumableGame()
                    } onAnalyze: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    } onRematch: { newSettings in
                        twoPlayerRematch(with: newSettings)
                    }

                case .analysisEntry:
                    AnalysisEntryView { source in
                        path.append(Route.activeAnalysis(source))
                    } onOpenLibrary: {
                        path.append(Route.analysisLibrary)
                    } onOpenPositionEditor: {
                        path.append(Route.positionEditor(nil))
                    } onOpenScanner: {
                        path.append(Route.scanner)
                    }

                case .analysisLibrary:
                    AnalysisLibraryView { source in
                        path.append(Route.activeAnalysis(source))
                    }

                case let .activeAnalysis(source):
                    AnalysisHost(source: source) { fen in
                        path.append(Route.activeGame(playFromPosition(fen)))
                    }

                case let .positionEditor(initialFEN):
                    // Le FEN sortant est déjà passé par `FENValidator` côté
                    // éditeur (actions désactivées tant qu'il est invalide) :
                    // aucune position illégale ne peut atteindre le moteur.
                    PositionEditorView(
                        initialFEN: initialFEN,
                        exit: .standalone(
                            onPlay: { fen in path.append(Route.activeGame(playFromPosition(fen))) },
                            onAnalyze: { fen in path.append(Route.activeAnalysis(.fen(fen))) },
                            onUseAsLabStart: { fen in path.append(Route.labSetup(startFEN: fen)) }
                        )
                    )

                case .scanner:
                    // Tout FEN sortant a été validé par l'écran de
                    // confirmation (actions désactivées tant qu'il est
                    // invalide) : aucune position illégale n'atteint le moteur.
                    ScannerView(
                        exit: .standalone(
                            onPlay: { fen in path.append(Route.activeGame(playFromPosition(fen))) },
                            onAnalyze: { fen in path.append(Route.activeAnalysis(.fen(fen))) },
                            onUseAsLabStart: { fen in path.append(Route.labSetup(startFEN: fen)) }
                        )
                    )

                case .puzzleQueue:
                    PuzzleQueueView { filter in
                        path.append(Route.activePuzzleSession(filter))
                    }

                case let .activePuzzleSession(filter):
                    PuzzleSessionHost(filter: filter) {
                        path.removeLast()
                    } onViewSourceGame: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    }

                case .repertoireList:
                    RepertoireListView { entry, color in
                        path.append(Route.activeOpeningLine(entry, color))
                    } onOpenExplorer: {
                        path.append(Route.openingExplorerPicker)
                    }

                case .openingExplorerPicker:
                    OpeningCoursePickerView { courseID in
                        path.append(Route.openingExplorerCourse(courseID))
                    }

                case let .openingExplorerCourse(courseID):
                    OpeningExplorerHost(courseID: courseID) {
                        path.append(Route.openingLearnCourse(courseID))
                    }

                case let .openingLearnCourse(courseID):
                    OpeningLearnHost(courseID: courseID) {
                        path.removeLast()
                    } onContinueVsStockfish: { fen in
                        path.append(Route.continueVsStockfish(fen))
                    }

                case let .activeOpeningLine(entry, color):
                    OpeningLineTrainingHost(entry: entry, color: color) {
                        path.removeLast()
                    } onContinueVsStockfish: { fen in
                        path.append(Route.continueVsStockfish(fen))
                    }

                case let .labSetup(startFEN):
                    LabSetupView(startFEN: startFEN) { settings in
                        path.append(Route.activeLab(settings))
                    } onResume: { state in
                        path.append(Route.resumedLab(state))
                    }

                case let .activeLab(settings):
                    LabHost(settings: settings, resumeState: nil) {
                        path.removeLast()
                    }

                case let .resumedLab(state):
                    LabHost(settings: nil, resumeState: state) {
                        path.removeLast()
                    }

                case .settings:
                    // Routage dans HomeView, comme partout ailleurs : l'écran
                    // ne fait que remonter l'intention.
                    SettingsView(
                        onOpenHelp: { path.append(Route.help) },
                        onOpenLicenses: { path.append(Route.licenses) }
                    )

                case .progression:
                    ProgressionView { theme in
                        // « Travailler ce thème » : ouvre une série de
                        // puzzles filtrée sur le thème faible désigné.
                        path.append(Route.activePuzzleSession(PuzzleSessionFilter(theme: theme)))
                    }

                case .help:
                    HelpView()

                case .licenses:
                    LicensesView()
                }
    }

    /// Réglages pour "Jouer / Continuer contre Stockfish depuis cette
    /// position" : on repart des derniers réglages mémorisés (force,
    /// cadence, aides) — sinon l'Elo retombait silencieusement au défaut
    /// 1200 — et on attribue à l'utilisateur **le camp au trait dans la
    /// FEN** (celui qu'on veut jouer). Corrige l'ancien comportement qui
    /// donnait toujours les Blancs, y compris pour un répertoire/une ligne
    /// des Noirs.
    /// Revanche : remplace la partie courante en haut de la pile par une
    /// nouvelle (nouvel hôte paresseux → nouveau `PlayViewModel`).
    private func rematch(with settings: PlayGameSettings) {
        if !path.isEmpty { path.removeLast() }
        path.append(Route.activeGame(settings))
    }

    private func twoPlayerRematch(with settings: TwoPlayerGameSettings) {
        if !path.isEmpty { path.removeLast() }
        path.append(Route.activeTwoPlayerGame(settings))
    }

    private func playFromPosition(_ fen: String) -> PlayGameSettings {
        var settings = PlaySettingsStore.load() ?? .default
        settings.startFEN = fen
        if let position = Position(fen: fen) {
            settings.colorChoice = (position.sideToMove == .white ? PlayerColorChoice.white : .black).rawValue
        }
        return settings
    }

    private func refreshResumableGame() {
        let vsEngine = AutosaveStore.loadPlay().map(ResumableGame.vsEngine)
        let twoPlayer = AutosaveStore.loadTwoPlayer().map(ResumableGame.twoPlayer)

        switch (vsEngine, twoPlayer) {
        case (nil, nil):
            resumableGame = nil
        case let (.some(game), nil):
            resumableGame = game
        case let (nil, .some(game)):
            resumableGame = game
        case let (.some(a), .some(b)):
            resumableGame = a.savedAt > b.savedAt ? a : b
        }
    }

    // MARK: Dispositions iPhone / iPad

    /// iPhone : tout défile dans une seule colonne (inchangé).
    private var iPhoneHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                homeHeader
                if seedingState.isSeeding { seedingBanner }
                if let resumableGame { resumeBanner(resumableGame) }
                modesSection(minTile: 160)
                if !recentGames.isEmpty { recentGamesSection }
            }
            .padding(20)
        }
    }

    // MARK: Grille des modes

    /// `minTile` : largeur mini d'une tuile — 160 en pleine largeur (iPhone),
    /// 200 dans la colonne gauche plus étroite de l'iPad.
    private func modesSection(minTile: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Modes")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minTile), spacing: 14)], spacing: 14) {
                ModeCard(title: "Contre l'ordinateur", subtitle: "Force, cadence, aides", systemImage: "cpu", tint: Theme.accent, isEnabled: true) {
                    path.append(Route.newGame)
                }
                ModeCard(title: "Deux joueurs", subtitle: "Sur le même appareil", systemImage: "person.2.fill", tint: Theme.info, isEnabled: true) {
                    path.append(Route.twoPlayerSetup)
                }
                ModeCard(title: "Puzzles", subtitle: "Tactique et bibliothèque Lichess", systemImage: "puzzlepiece.fill", tint: Theme.violet, isEnabled: true) {
                    path.append(Route.puzzleQueue)
                }
                ModeCard(title: "Ouvertures", subtitle: "Répertoires PGN", systemImage: "books.vertical.fill", tint: Theme.warning, isEnabled: true) {
                    path.append(Route.repertoireList)
                }
                ModeCard(title: "Analyser", subtitle: "PGN, FEN, bibliothèque", systemImage: "chart.xyaxis.line", tint: Theme.teal, isEnabled: true) {
                    path.append(Route.analysisEntry)
                }
                ModeCard(title: "Laboratoire", subtitle: "L'ordinateur contre lui-même", systemImage: "flask", tint: Theme.rose, isEnabled: true) {
                    path.append(Route.labSetup(startFEN: nil))
                }
            }
        }
    }

    // MARK: Carte Progression (panneau iPad)

    /// Aperçu compact du tableau de bord, tout le panneau étant un bouton vers
    /// l'écran complet. Réutilise ``ProgressionSummary`` (pur) et le même
    /// chargement filtré que ``ProgressionView`` — jamais toute la table Puzzle.
    private var homeProgressCard: some View {
        Button { path.append(Route.progression) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    IconBadge(systemImage: "chart.bar.xaxis", tint: Theme.accent, size: 30)
                    Text("Progression")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }

                if let summary = progressSummary, summary.hasAnyData {
                    HStack(spacing: 10) {
                        if summary.engineGames > 0 {
                            progressStat("\(summary.engineWins)–\(summary.engineDraws)–\(summary.engineLosses)", "V–N–D")
                        }
                        if let rate = summary.puzzleSuccessRate {
                            progressStat("\(Int((rate * 100).rounded())) %", "Puzzles")
                        }
                    }
                    if let best = summary.bestWinElo {
                        Label("Meilleure victoire ~\(best) Elo", systemImage: "trophy.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    Text("Jouez une partie ou résolvez des puzzles pour voir votre progression.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("homeProgressCard")
    }

    private func progressStat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.surfaceElevated.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Recharge le bilan compact — même discipline que ``ProgressionView`` :
    /// petite table de parties chargée entière, puzzles filtrés sur ceux
    /// réellement tentés (jamais les dizaines de milliers de la bibliothèque).
    private func loadProgressSummary() {
        let games = (try? modelContext.fetch(FetchDescriptor<GameRecord>())) ?? []
        var attempted = FetchDescriptor<Puzzle>(predicate: #Predicate { puzzle in
            (puzzle.successCount ?? 0) > 0 || (puzzle.failureCount ?? 0) > 0
        })
        attempted.propertiesToFetch = [\.successCount, \.failureCount, \.themeRaw, \.rating]
        let puzzles = (try? modelContext.fetch(attempted)) ?? []
        progressSummary = ProgressionSummary.compute(games: games, puzzles: puzzles)
    }

    // MARK: En-tête & résumé

    private var seedingBanner: some View {
        HStack(spacing: 14) {
            ProgressView().tint(Theme.violet)
            VStack(alignment: .leading, spacing: 2) {
                Text("Préparation de la bibliothèque de puzzles…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Une seule fois, en tâche de fond.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
        .overlay(Theme.cardShape.strokeBorder(Theme.violet.opacity(0.30), lineWidth: 1))
    }

    /// Tête d'accueil : pastille-logo (cavalier sur dégradé émeraude) et
    /// wordmark bicolore « Chess » / « Lab », à la place du grand titre
    /// système. `Text(verbatim:)` : le nom de l'app est une MARQUE, il ne
    /// se traduit pas — pas de clé de localisation à générer.
    ///
    /// - important: Le wordmark doit rester lisible par accessibilité comme
    ///   « ChessLab » : le test UI de fumée s'accroche à
    ///   `staticTexts["ChessLab"]` pour prouver que l'accueil est monté.
    private var homeHeader: some View {
        HStack(spacing: 14) {
            // L'illustration porte DÉJÀ son cadre émeraude et son fond : elle
            // remplace donc la tuile entière (dégradé + liseré + glyphe de
            // cavalier), au lieu d'être posée dessus — deux cadres empilés se
            // seraient contrariés. On garde le même gabarit (56 pt, rayon 16)
            // et la lueur, pour ne rien changer à l'équilibre du header.
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .glow(Theme.accent, radius: 9)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                (Text(verbatim: "Chess").foregroundStyle(Theme.textPrimary)
                    + Text(verbatim: "Lab").foregroundStyle(Theme.accentGradient))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .kerning(0.2)
                    .accessibilityLabel(Text(verbatim: "ChessLab"))

                Text("Jouez, analysez, progressez.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Theme.accentGradient)
                .frame(width: 18, height: 3)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }

    /// Bouton rond de barre d'outils (Progression, Réglages) — style commun
    /// pour que les deux icônes de l'accueil restent visuellement sœurs.
    private func toolbarCircleButton(
        _ systemImage: String, label: LocalizedStringKey,
        identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 34, height: 34)
                .background(Theme.surfaceElevated.opacity(0.92), in: Circle())
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    /// Accès direct à l'analyse des dernières parties jouées, depuis l'accueil
    /// (au lieu d'Analyser → Bibliothèque → partie). Un tap ouvre l'analyse de
    /// la partie ; « Voir tout » mène à la bibliothèque complète.
    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionHeader("Parties récentes")
                Spacer()
                Button("Voir tout") { path.append(Route.analysisLibrary) }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }

            VStack(spacing: 10) {
                ForEach(recentGames) { game in
                    Button {
                        guard let pgn = game.pgn, !pgn.isEmpty else { return }
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    } label: {
                        recentGameRow(game)
                    }
                    .buttonStyle(.pressable)
                    .disabled((game.pgn ?? "").isEmpty)
                }
            }
        }
    }

    private func recentGameRow(_ game: GameRecord) -> some View {
        HStack(spacing: 14) {
            IconBadge(systemImage: "chart.xyaxis.line", tint: Theme.teal, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(recentGameTitle(game))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(game.resultRaw ?? "?")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.accent, in: Capsule())
                    if let date = game.playedAt {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
            Text("Analyser")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Analyser la partie"))
    }

    /// Intitulé lisible : « Contre Stockfish » pour une partie moteur, sinon
    /// les deux noms. Les noms « Vous »/« Stockfish » sont stockés en français
    /// dans le modèle ; on les localise à l'affichage.
    private func recentGameTitle(_ game: GameRecord) -> String {
        if game.mode == .vsEngine {
            return LocalizationController.string("Contre l'ordinateur")
        }
        let white = localizedPlayerName(game.whiteName) ?? LocalizationController.string("Blancs")
        let black = localizedPlayerName(game.blackName) ?? LocalizationController.string("Noirs")
        return "\(white) – \(black)"
    }

    /// Traduit les noms « spéciaux » stockés en français ; laisse tel quel un
    /// vrai prénom saisi par l'utilisateur.
    private func localizedPlayerName(_ stored: String?) -> String? {
        guard let stored else { return nil }
        switch stored {
        case "Vous": return LocalizationController.string("Vous")
        case "Blancs": return LocalizationController.string("Blancs")
        case "Noirs": return LocalizationController.string("Noirs")
        // « Stockfish » : nom stocké par les parties antérieures au renommage —
        // affiché « Ordinateur » comme les nouvelles, pour l'uniformité.
        case "Ordinateur", "Stockfish": return LocalizationController.string("Ordinateur")
        default: return stored
        }
    }

    private func resumeBanner(_ resumable: ResumableGame) -> some View {
        Button {
            switch resumable {
            case let .vsEngine(autosave):
                path.append(Route.resumedGame(autosave))
            case let .twoPlayer(autosave):
                path.append(Route.resumedTwoPlayerGame(autosave))
            }
        } label: {
            // CTA principal de l'écran quand il existe : plein dégradé
            // d'accent, texte sombre — le même langage que les chips
            // sélectionnées, au lieu d'une carte grise de plus.
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.background.opacity(0.20))
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.background)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reprendre la partie en cours")
                        .font(.headline)
                        .foregroundStyle(Theme.background)
                    Text("\(resumable.moveCount) coup(s) joué(s)")
                        .font(.caption)
                        .foregroundStyle(Theme.background.opacity(0.72))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.background.opacity(0.85))
            }
            .padding(16)
            .background(Theme.accentGradient, in: Theme.cardShape)
            .overlay(Theme.cardShape.strokeBorder(.white.opacity(0.22), lineWidth: 1))
            .glow(Theme.accent, radius: 11)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("resumeGame")
    }
}

/// Héberge un `PlayViewModel` créé une seule fois (à l'apparition de cette
/// vue) pour une nouvelle partie, quel que soit le nombre de fois où
/// `body` est réévalué ensuite.
///
/// - important: Ne PAS construire `PlayViewModel` via
/// `State(initialValue:)` dans `init` : cette expression est réévaluée à
/// chaque (re)construction de la vue par SwiftUI (pas seulement la
/// première), même si le framework n'en garde qu'une — `PlayViewModel.init`
/// a des effets de bord (démarre un process Stockfish), donc ça en
/// lance un second, orphelin mais actif, qui vient saturer le CPU du
/// simulateur et ralentit voire bloque le premier. On construit donc
/// paresseusement via `.onAppear`, comme `ResumedGameHost` ci-dessous.
private struct ActiveGameHost: View {
    let settings: PlayGameSettings
    let onExit: () -> Void
    let onAnalyze: (String) -> Void
    var onRematch: (PlayGameSettings) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PlayViewModel?

    var body: some View {
        Group {
            if let viewModel {
                PlayView(viewModel: viewModel, onExit: onExit, onAnalyze: onAnalyze, onRematch: onRematch)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = PlayViewModel(settings: settings, modelContext: modelContext)
            }
        }
    }
}

/// Héberge un `PlayViewModel` restauré depuis l'autosauvegarde, créé une
/// seule fois à l'apparition de cette vue.
private struct ResumedGameHost: View {
    let autosave: PlayGameAutosave
    let onExit: () -> Void
    let onAnalyze: (String) -> Void
    var onRematch: (PlayGameSettings) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PlayViewModel?

    var body: some View {
        Group {
            if let viewModel {
                PlayView(viewModel: viewModel, onExit: onExit, onAnalyze: onAnalyze, onRematch: onRematch)
            } else {
                ContentUnavailableView(
                    "Reprise impossible",
                    systemImage: "exclamationmark.triangle",
                    description: Text("La partie sauvegardée n'a pas pu être restaurée.")
                )
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = PlayViewModel(resuming: autosave, modelContext: modelContext)
            }
        }
    }
}

/// Héberge un `TwoPlayerViewModel` créé une seule fois (à l'apparition de
/// cette vue) pour une nouvelle partie — même discipline de construction
/// paresseuse que ``ActiveGameHost``, par cohérence (pas d'effet de bord
/// process moteur ici, donc moins critique).
private struct TwoPlayerActiveGameHost: View {
    let settings: TwoPlayerGameSettings
    let onExit: () -> Void
    let onAnalyze: (String) -> Void
    var onRematch: (TwoPlayerGameSettings) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TwoPlayerViewModel?

    var body: some View {
        Group {
            if let viewModel {
                TwoPlayerGameView(viewModel: viewModel, onExit: onExit, onAnalyze: onAnalyze, onRematch: onRematch)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TwoPlayerViewModel(settings: settings, modelContext: modelContext)
            }
        }
    }
}

/// Héberge un `TwoPlayerViewModel` restauré depuis l'autosauvegarde.
private struct TwoPlayerResumedGameHost: View {
    let autosave: TwoPlayerGameAutosave
    let onExit: () -> Void
    let onAnalyze: (String) -> Void
    var onRematch: (TwoPlayerGameSettings) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TwoPlayerViewModel?

    var body: some View {
        Group {
            if let viewModel {
                TwoPlayerGameView(viewModel: viewModel, onExit: onExit, onAnalyze: onAnalyze, onRematch: onRematch)
            } else {
                ContentUnavailableView(
                    "Reprise impossible",
                    systemImage: "exclamationmark.triangle",
                    description: Text("La partie sauvegardée n'a pas pu être restaurée.")
                )
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TwoPlayerViewModel(resuming: autosave, modelContext: modelContext)
            }
        }
    }
}

/// Héberge un `AnalysisViewModel` créé une seule fois (à l'apparition de
/// cette vue) — même discipline de construction paresseuse que
/// ``ActiveGameHost`` (l'engine d'analyse a le même effet de bord process
/// que celui du mode Jouer).
private struct AnalysisHost: View {
    let source: AnalysisSource
    let onPlayFromHere: (String) -> Void
    @State private var viewModel: AnalysisViewModel?

    var body: some View {
        Group {
            if let viewModel {
                AnalysisView(viewModel: viewModel, onPlayFromHere: onPlayFromHere)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = AnalysisViewModel(source: source)
            }
        }
    }
}

/// Héberge un `PuzzleSolveViewModel` créé une seule fois pour toute une
/// série ouverte (bouton "Commencer" de ``PuzzleQueueView``, une fois
/// niveau/phase/type choisis) — le modèle tire lui-même les puzzles un à
/// un selon le filtre, au fil des "Nouveau puzzle".
private struct PuzzleSessionHost: View {
    let filter: PuzzleSessionFilter
    let onExit: () -> Void
    let onViewSourceGame: (String) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PuzzleSolveViewModel?
    @State private var hasAttemptedLoad = false

    var body: some View {
        Group {
            if let viewModel {
                PuzzleSolveView(viewModel: viewModel, onExit: onExit, onViewSourceGame: onViewSourceGame)
            } else if hasAttemptedLoad {
                // Défensif : le bouton de lancement n'apparaît que si le
                // compte filtré est non nul, mais l'état a pu changer
                // entre les deux (dernier puzzle résolu ailleurs).
                ContentUnavailableView(
                    "Aucun puzzle dû",
                    systemImage: "puzzlepiece",
                    description: Text("Plus aucun puzzle dû ne correspond à ces filtres.")
                )
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil, !hasAttemptedLoad {
                viewModel = PuzzleSolveViewModel(filter: filter, modelContext: modelContext)
                hasAttemptedLoad = true
            }
        }
    }
}


/// Héberge un `OpeningLineTrainingViewModel` créé une seule fois — une
/// ligne de bibliothèque ne persiste rien (pas de répétition espacée,
/// voir ``OpeningLineTrainingViewModel``).
private struct OpeningLineTrainingHost: View {
    let entry: OpeningLibraryEntry
    let color: Piece.Color
    let onExit: () -> Void
    let onContinueVsStockfish: (String) -> Void
    @State private var viewModel: OpeningLineTrainingViewModel?

    var body: some View {
        Group {
            if let viewModel {
                OpeningLineTrainingView(viewModel: viewModel, onExit: onExit, onContinueVsStockfish: onContinueVsStockfish)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OpeningLineTrainingViewModel(entry: entry, color: color)
            }
        }
    }
}

/// Héberge un `LabViewModel` créé une seule fois (nouvelle série ou reprise),
/// même discipline de construction paresseuse que les autres hôtes — le
/// moteur du Laboratoire a le même effet de bord process que les autres modes.
private struct LabHost: View {
    let settings: LabGameSettings?
    let resumeState: LabSeriesState?
    let onExit: () -> Void
    @State private var viewModel: LabViewModel?

    var body: some View {
        Group {
            if let viewModel {
                LabRunView(viewModel: viewModel, onExit: onExit)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                if let resumeState {
                    viewModel = LabViewModel(resuming: resumeState)
                } else if let settings {
                    viewModel = LabViewModel(settings: settings)
                }
            }
        }
    }
}

private struct ModeCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let systemImage: String
    var tint: Color = Theme.accent
    let isEnabled: Bool
    let action: () -> Void

    /// Sur iPad (classe régulière), la tuile grandit avec la grille à 3
    /// colonnes fixes (voir ``HomeView/modeGridColumns``) — sinon la carte
    /// garde sa hauteur iPhone (132 pt) dans une colonne bien plus large,
    /// et l'écart entre icône et texte se creuse au lieu de rester équilibré.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isRegular: Bool { horizontalSizeClass == .regular }
    private var cardHeight: CGFloat { isRegular ? 168 : 132 }
    private var iconSize: CGFloat { isRegular ? 58 : 48 }
    private var ghostIconSize: CGFloat { isRegular ? 118 : 96 }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                IconBadge(systemImage: systemImage, tint: tint, size: iconSize, isEnabled: isEnabled)

                Spacer(minLength: 16)

                // `lineLimit` + `minimumScaleFactor` : la carte a une
                // hauteur FIGÉE — aux tailles d'accessibilité XXL, un titre
                // sans borne déborderait de la tuile.
                Text(title)
                    .font(isRegular ? .title3.weight(.semibold) : .headline)
                    .foregroundStyle(isEnabled ? Theme.textPrimary : Theme.textTertiary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(subtitle ?? "Bientôt")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(isRegular ? 20 : 16)
            .frame(height: cardHeight)
            .background {
                ZStack {
                    Theme.cardGradient
                    // Grande icône décorative "fantôme" débordant dans le
                    // coin, dans la teinte du mode — donne un caractère
                    // illustré à chaque tuile sans image bitmap.
                    Image(systemName: systemImage)
                        .font(.system(size: ghostIconSize, weight: .semibold))
                        .foregroundStyle(tint.opacity(isEnabled ? 0.08 : 0.03))
                        .offset(x: isRegular ? 56 : 46, y: isRegular ? 42 : 34)
                }
            }
            .clipShape(Theme.cardShape)
            // Bordure en dégradé de la teinte : accroche la lumière en haut
            // à gauche et se fond dans le trait neutre en bas — plus de
            // relief qu'un liseré uniforme.
            .overlay(
                Theme.cardShape.strokeBorder(
                    LinearGradient(
                        colors: [tint.opacity(isEnabled ? 0.48 : 0.10), Theme.stroke],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            // Petite flèche de lancement : dit « ceci ouvre un espace »
            // d'un coup d'œil, dans la teinte du mode.
            .overlay(alignment: .topTrailing) {
                if isEnabled {
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(tint.opacity(0.6))
                        .padding(13)
                }
            }
            .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
        .accessibilityLabel(Text(title))
    }
}

#Preview {
    HomeView()
}
