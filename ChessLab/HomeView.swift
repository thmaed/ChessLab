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
    /// View models des écrans de session, détenus ICI — donc au-dessus du
    /// `if/else` d'ossature, qui détruirait sinon tout le sous-arbre et la
    /// partie en cours avec lui. Voir ``SessionStore``.
    @State private var sessionStore = SessionStore()
    /// Relais de la barre de menus macOS — voir ``MenuCommands``.
    @State private var menuCommands = MenuCommands.shared

    @State private var seedingState = PuzzleSeedingState.shared
    /// Santé de la persistance — la bannière « rien ne s'enregistre » en vit.
    @State private var persistenceHealth = PersistenceHealth.shared

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
        /// Même écran, pré-rempli avec une position venue d'un autre mode
        /// (lecteur d'ouverture/finale, partie contre le moteur) — miroir de
        /// ``continueVsStockfish(_:)``.
        case continueTwoPlayer(String)
        case activeTwoPlayerGame(TwoPlayerGameSettings)
        case resumedTwoPlayerGame(TwoPlayerGameAutosave)
        case analysisEntry
        case analysisLibrary
        case activeAnalysis(AnalysisSource)
        case positionEditor(String?)
        case scanner
        case puzzleQueue
        case activePuzzleSession(PuzzleSessionFilter)
        /// Liste des ouvertures — l'écran d'entrée du module.
        case openingList
        /// Module Finales : mêmes routes lecteur/entraîneur que les
        /// ouvertures, seule la LISTE est propre au module.
        case endgameList
        /// Entraînement LIBRE d'une finale (arbitré au verdict) — porte
        /// l'identifiant du cours.
        case endgameFreeTrain(String)
        /// Lecteur de FINALE, pas-à-pas. Les Ouvertures ont le leur
        /// (``openingLabsReader``) depuis le 23/08.
        case endgameReader(String)
        /// Éditeur d'arbre — répertoires PERSONNELS seulement (`user-…`).
        case openingEditor(String)
        /// Lecteur d'une ouverture : index des lignes en arbre, coups des
        /// maîtres, meilleurs coups du moteur.
        case openingLabsReader(String)
        case openingTrainDaily
        case openingTrainLine(String)
        /// Réglages Labo, éventuellement pré-remplis avec une position de
        /// départ venue de l'éditeur ou du scanner.
        case labSetup(startFEN: String?)
        /// Hub des variantes d'échecs, puis le Chess960 : réglages et partie.
        case variantsHub
        case chess960Setup
        case activeChess960Game(Chess960Settings)
        /// Débranchement « Deux joueurs » depuis une partie Chess960 —
        /// la position affichée devient le départ d'une partie neuve, sans
        /// écran de réglages intermédiaire (même esprit que
        /// `continueTwoPlayer`, mais la variante n'a pas encore de réglages
        /// à choisir : noms et cadence restent ceux par défaut).
        case activeChess960TwoPlayerGame(Chess960TwoPlayerSettings)
        /// Analyse de fin de partie Chess960 — porte le PGN complet
        /// (tags Variant/SetUp/FEN compris), pas juste la FEN finale.
        case activeChess960Analysis(String)
        case activeLab(LabGameSettings)
        case resumedLab(LabSeriesState)
        case progression
        case settings
        case help
        case licenses
        case openingsSources
    }

    /// Entrées de la barre latérale iPad/Mac. Chacune enracine la colonne de
    /// détail sur l'écran d'entrée du mode correspondant (voir ``detailRoot``).
    enum SidebarItem: Hashable {
        case vsEngine, twoPlayer, puzzles, openings, endgames, analysis, laboratory, variants
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
        case .openings: item = .openings; route = .openingList
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
        // Injecté AUTOUR du `Group`, donc au-dessus de la branche : le coffre
        // appartient à `HomeView`, que la bascule d'ossature n'atteint pas.
        .environment(\.sessionStore, sessionStore)
        .onChange(of: menuCommands.requested) { _, destination in
            guard let destination else { return }
            menuCommands.requested = nil
            open(destination)
        }
        .onAppear {
            // Le conteneur est-il retombé en mémoire au lancement ? Le
            // drapeau est posé AVANT le MainActor (voir SessionDegradation),
            // la bannière le lit ici.
            if SessionDegradation.isInMemory { persistenceHealth.isDegradedSession = true }
            refreshResumableGame()
            // Fusionne la progression puzzles synchronisée (autres appareils)
            // dans les Puzzle locaux AVANT de calculer le bilan — voir
            // ``PuzzleProgressSync``. No-op si rien n'est encore synchronisé.
            PuzzleProgressSync.reconcileIfStale(in: modelContext)
            // Fusionne de même la progression d'ouvertures synchronisée : dédup
            // des enregistrements par clé FEN et recalcul de l'état FSRS en
            // rejouant le journal fusionné — voir ``OpeningProgressSync``. No-op
            // tant que rien n'a été révisé.
            OpeningProgressSync.reconcileIfStale(in: modelContext)
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
                // Retour à l'accueil : plus aucun écran de session n'est
                // monté, donc plus aucun view model à garder. Sans ce vidage,
                // un `PlayViewModel` survivrait à son écran — et avec lui un
                // Stockfish qui cherche derrière l'interface (c'est ce que
                // surveille `EngineLeakUITests`).
                sessionStore.clear()
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
                            // Coloré, à côté de Progression : l'aide explique
                            // des choses qu'on ne devine pas (import et partage
                            // de répertoires, portée de la synchro iCloud) et
                            // elle était enterrée dans les Réglages, où
                            // personne ne va chercher un mode d'emploi.
                            toolbarCircleButton(
                                "questionmark.circle.fill", label: "Aide",
                                // Identifiant DISTINCT de celui des Réglages
                                // (`openHelp`) : deux boutons de même nom dans
                                // l'arbre d'accessibilité rendraient les tests
                                // ambigus, et l'ambiguïté se paierait un jour.
                                identifier: "openHelpFromHome", tint: Theme.accent
                            ) { path.append(Route.help) }
                            toolbarCircleButton(
                                "chart.bar.xaxis", label: "Progression",
                                identifier: "openProgression", tint: Theme.info
                            ) { path.append(Route.progression) }
                            toolbarCircleButton(
                                "gearshape.fill", label: "Réglages",
                                identifier: "openSettings", tint: Theme.gold
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
                sidebarLabel(
                    .openings, "Ouvertures", "books.vertical.fill", Theme.warning,
                    accessibilityID: "sidebar_openings"
                )
                sidebarLabel(.endgames, "Finales", "crown.fill", Theme.gold)
                sidebarLabel(.analysis, "Analyser", "chart.xyaxis.line", Theme.teal)
                sidebarLabel(.laboratory, "Laboratoire", "flask", Theme.rose)
                sidebarLabel(.variants, "Variantes", "die.face.5.fill", Theme.violet, accessibilityID: "sidebar_variants")
            }
            Section("Suivi") {
                // Mêmes teintes qu'en barre d'outils iPhone : le même bouton
                // portait deux couleurs selon l'appareil — Progression était
                // verte ici et grise là, l'aide l'inverse.
                sidebarLabel(.progression, "Progression", "chart.bar.xaxis", Theme.info)
                sidebarLabel(.settings, "Réglages", "gearshape.fill", Theme.gold)
                sidebarLabel(.help, "Aide", "questionmark.circle", Theme.accent)
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
        _ item: SidebarItem, _ title: LocalizedStringKey, _ icon: String, _ tint: Color,
        accessibilityID: String? = nil
    ) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon).foregroundStyle(tint)
        }
        .tag(item)
        // Identifiant facultatif : les tests d'interface iPad n'ont pas de
        // tuile à viser (la grille laisse place à la barre latérale) et un
        // repérage par LIBELLÉ casserait au premier changement de langue.
        .accessibilityIdentifier(accessibilityID ?? "")
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
        case .openings: destination(for: .openingList)
        case .endgames: destination(for: .endgameList)
        case .analysis: destination(for: .analysisEntry)
        case .laboratory: destination(for: .labSetup(startFEN: nil))
        case .variants: destination(for: .variantsHub)
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
                if persistenceHealth.showsBanner { persistenceBanner }
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
                        startNewGame(settings, replacingCurrent: true)
                    }

                case let .continueVsStockfish(fen):
                    // Même écran que « Nouvelle partie », pré-rempli avec la
                    // position atteinte : le joueur règle l'Elo puis lance.
                    NewGameSetupView(initialFEN: fen) { settings in
                        startNewGame(settings)
                    }

                case let .activeGame(settings):
                    ActiveGameHost(settings: settings, sessionKey: sessionKey(for: route)) {
                        path = NavigationPath()
                        refreshResumableGame()
                    } onAnalyze: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    } onRematch: { newSettings in
                        rematch(with: newSettings)
                    } onAnalyzePosition: { fen in
                        // EMPILÉ au-dessus de la partie, qui reste vivante en
                        // dessous : le retour la retrouve telle quelle.
                        path.append(Route.activeAnalysis(.fen(fen)))
                    } onOpenLab: { fen in
                        path.append(Route.labSetup(startFEN: fen))
                    } onOpenTwoPlayer: { fen in
                        path.append(Route.continueTwoPlayer(fen))
                    }

                case let .resumedGame(autosave):
                    ResumedGameHost(autosave: autosave, sessionKey: sessionKey(for: route)) {
                        path = NavigationPath()
                        refreshResumableGame()
                    } onAnalyze: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    } onRematch: { newSettings in
                        rematch(with: newSettings)
                    } onAnalyzePosition: { fen in
                        path.append(Route.activeAnalysis(.fen(fen)))
                    } onOpenLab: { fen in
                        path.append(Route.labSetup(startFEN: fen))
                    } onOpenTwoPlayer: { fen in
                        path.append(Route.continueTwoPlayer(fen))
                    }

                case .twoPlayerSetup:
                    TwoPlayerSetupView { settings in
                        startNewTwoPlayerGame(settings, replacingCurrent: true)
                    }

                case let .continueTwoPlayer(fen):
                    // Même écran, pré-rempli avec la position atteinte — miroir
                    // de `.continueVsStockfish`.
                    TwoPlayerSetupView(initialFEN: fen) { settings in
                        startNewTwoPlayerGame(settings)
                    }

                case let .activeTwoPlayerGame(settings):
                    TwoPlayerActiveGameHost(settings: settings, sessionKey: sessionKey(for: route)) {
                        path = NavigationPath()
                        refreshResumableGame()
                    } onAnalyze: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    } onRematch: { newSettings in
                        twoPlayerRematch(with: newSettings)
                    } onAnalyzePosition: { fen in
                        path.append(Route.activeAnalysis(.fen(fen)))
                    } onOpenLab: { fen in
                        path.append(Route.labSetup(startFEN: fen))
                    } onPlayVsEngine: { fen in
                        path.append(Route.continueVsStockfish(fen))
                    }

                case let .resumedTwoPlayerGame(autosave):
                    TwoPlayerResumedGameHost(autosave: autosave, sessionKey: sessionKey(for: route)) {
                        path = NavigationPath()
                        refreshResumableGame()
                    } onAnalyze: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    } onRematch: { newSettings in
                        twoPlayerRematch(with: newSettings)
                    } onAnalyzePosition: { fen in
                        path.append(Route.activeAnalysis(.fen(fen)))
                    } onOpenLab: { fen in
                        path.append(Route.labSetup(startFEN: fen))
                    } onPlayVsEngine: { fen in
                        path.append(Route.continueVsStockfish(fen))
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
                    AnalysisHost(source: source, sessionKey: sessionKey(for: route)) { fen in
                        startNewGame(playFromPosition(fen))
                    } onOpenLab: { fen in
                        path.append(Route.labSetup(startFEN: fen))
                    }

                case let .positionEditor(initialFEN):
                    // Le FEN sortant est déjà passé par `FENValidator` côté
                    // éditeur (actions désactivées tant qu'il est invalide) :
                    // aucune position illégale ne peut atteindre le moteur.
                    PositionEditorView(
                        initialFEN: initialFEN,
                        exit: .standalone(
                            onPlay: { fen in startNewGame(playFromPosition(fen)) },
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
                            onPlay: { fen in startNewGame(playFromPosition(fen)) },
                            onAnalyze: { fen in path.append(Route.activeAnalysis(.fen(fen))) },
                            onUseAsLabStart: { fen in path.append(Route.labSetup(startFEN: fen)) }
                        )
                    )

                case .variantsHub:
                    VariantsHubView {
                        path.append(Route.chess960Setup)
                    }

                case .chess960Setup:
                    Chess960SetupView { settings in
                        startNewChess960Game(settings)
                    }

                case let .activeChess960Game(settings):
                    Chess960ActiveGameHost(settings: settings, sessionKey: sessionKey(for: route)) {
                        path = NavigationPath()
                    } onOpenTwoPlayer: { fen in
                        startNewChess960TwoPlayerGame(fromFEN: fen)
                    } onAnalyze: { pgn in
                        path.append(Route.activeChess960Analysis(pgn))
                    }

                case let .activeChess960TwoPlayerGame(settings):
                    Chess960TwoPlayerActiveGameHost(settings: settings, sessionKey: sessionKey(for: route)) {
                        path = NavigationPath()
                    } onAnalyze: { pgn in
                        path.append(Route.activeChess960Analysis(pgn))
                    }

                case let .activeChess960Analysis(pgn):
                    Chess960AnalysisActiveGameHost(pgn: pgn, sessionKey: sessionKey(for: route))

                case .puzzleQueue:
                    PuzzleQueueView { filter in
                        path.append(Route.activePuzzleSession(filter))
                    } onOpenLab: {
                        path.append(Route.labSetup(startFEN: nil))
                    } onPlayVsEngine: {
                        path.append(Route.newGame)
                    } onOpenTwoPlayer: {
                        path.append(Route.twoPlayerSetup)
                    }

                case let .activePuzzleSession(filter):
                    PuzzleSessionHost(filter: filter, sessionKey: sessionKey(for: route)) {
                        path.removeLast()
                    } onViewSourceGame: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    } onOpenLab: { fen in
                        path.append(Route.labSetup(startFEN: fen))
                    } onPlayVsEngine: { fen in
                        path.append(Route.continueVsStockfish(fen))
                    } onOpenTwoPlayer: { fen in
                        path.append(Route.continueTwoPlayer(fen))
                    }

                case .endgameList:
                    EndgameListView { courseID in
                        path.append(Route.endgameReader(courseID))
                    } onReview: {
                        path.append(Route.openingTrainDaily)
                    } onOpenLab: {
                        path.append(Route.labSetup(startFEN: nil))
                    } onPlayVsEngine: {
                        path.append(Route.newGame)
                    } onOpenTwoPlayer: {
                        path.append(Route.twoPlayerSetup)
                    }

                case let .endgameFreeTrain(courseID):
                    EndgameFreeTrainHost(courseID: courseID, sessionKey: sessionKey(for: route)) {
                        path.removeLast()
                    }

                case .openingList:
                    OpeningListView { courseID in
                        path.append(Route.openingLabsReader(courseID))
                    } onEdit: { courseID in
                        path.append(Route.openingEditor(courseID))
                    } onOpenLab: {
                        path.append(Route.labSetup(startFEN: nil))
                    } onPlayVsEngine: {
                        path.append(Route.newGame)
                    } onOpenTwoPlayer: {
                        path.append(Route.twoPlayerSetup)
                    }

                case let .openingLabsReader(courseID):
                    OpeningReaderHost(courseID: courseID, sessionKey: sessionKey(for: route)) {
                        path.removeLast()
                    } onTrain: {
                        path.append(Route.openingTrainLine(courseID))
                    } onContinueVsStockfish: { fen in
                        path.append(Route.continueVsStockfish(fen))
                    } onOpenLab: { fen in
                        path.append(Route.labSetup(startFEN: fen))
                    } onOpenTwoPlayer: { fen in
                        path.append(Route.continueTwoPlayer(fen))
                    }

                case let .openingEditor(courseID):
                    OpeningEditorHost(courseID: courseID) {
                        path.removeLast()
                    }

                case let .endgameReader(courseID):
                    EndgameReaderHost(courseID: courseID, sessionKey: sessionKey(for: route)) {
                        path.removeLast()
                    } onTrain: {
                        path.append(Route.openingTrainLine(courseID))
                    } onContinueVsStockfish: { fen in
                        path.append(Route.continueVsStockfish(fen))
                    } onOpenLab: { fen in
                        path.append(Route.labSetup(startFEN: fen))
                    } onOpenTwoPlayer: { fen in
                        path.append(Route.continueTwoPlayer(fen))
                    } onFreeTrain: {
                        path.append(Route.endgameFreeTrain(courseID))
                    }

                case .openingTrainDaily:
                    OpeningTrainHost(mode: .daily, sessionKey: sessionKey(for: route)) { path.removeLast() }

                case let .openingTrainLine(courseID):
                    OpeningTrainHost(
                        mode: .fullLine(courseID: courseID), sessionKey: sessionKey(for: route)
                    ) { path.removeLast() }

                case let .labSetup(startFEN):
                    LabSetupView(startFEN: startFEN) { settings in
                        path.append(Route.activeLab(settings))
                    } onResume: { state in
                        path.append(Route.resumedLab(state))
                    }

                case let .activeLab(settings):
                    LabHost(settings: settings, resumeState: nil, sessionKey: sessionKey(for: route)) {
                        path.removeLast()
                    } onAnalyze: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    }

                case let .resumedLab(state):
                    LabHost(settings: nil, resumeState: state, sessionKey: sessionKey(for: route)) {
                        path.removeLast()
                    } onAnalyze: { pgn in
                        path.append(Route.activeAnalysis(.pgn(pgn)))
                    }

                case .settings:
                    // Routage dans HomeView, comme partout ailleurs : l'écran
                    // ne fait que remonter l'intention.
                    SettingsView(
                        onOpenHelp: { path.append(Route.help) },
                        onOpenLicenses: { path.append(Route.licenses) },
                        onOpenSources: { path.append(Route.openingsSources) }
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

                case .openingsSources:
                    SourcesView()
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
    /// Clé de session d'une route — voir ``SessionStore``.
    ///
    /// La route EST l'identité de l'écran : même route, même partie. Deux
    /// analyses de PGN différents ont des routes différentes, donc des
    /// sessions distinctes. Une seule fonction pour les douze hôtes, plutôt
    /// qu'une dérivation par type de charge utile.
    private func sessionKey(for route: Route) -> String {
        String(describing: route)
    }

    /// Démarrer une NOUVELLE partie contre l'ordinateur.
    ///
    /// C'est ICI, à l'intention explicite de l'utilisateur, que
    /// l'autosauvegarde précédente est effacée — et non dans
    /// `PlayViewModel.init`, où toute reconstruction de vue la détruisait
    /// (voir ``SessionStore``). Tous les points de départ passent par cette
    /// porte : nouvelle partie, position d'éditeur, scan, analyse, revanche.
    private func startNewGame(_ settings: PlayGameSettings, replacingCurrent: Bool = false) {
        AutosaveStore.clearPlay()
        sessionStore.remove(sessionKey(for: .activeGame(settings)))
        if replacingCurrent, !path.isEmpty { path.removeLast() }
        path.append(Route.activeGame(settings))
    }

    /// Idem pour le Chess960 — pas d'autosauvegarde à purger ici (lot 2/3),
    /// seulement la session éventuellement stagnante.
    private func startNewChess960Game(_ settings: Chess960Settings) {
        sessionStore.remove(sessionKey(for: .activeChess960Game(settings)))
        path.append(Route.activeChess960Game(settings))
    }

    /// Débranchement « Deux joueurs » depuis une partie Chess960 en cours :
    /// pas d'écran de réglages, la position affichée EST le départ — les
    /// deux noms restent les défauts (« Blancs »/« Noirs »), modifiables
    /// nulle part pour l'instant (aucun écran de réglages Chess960 à deux
    /// n'existe encore, ce mode n'étant atteignable que par débranchement).
    private func startNewChess960TwoPlayerGame(fromFEN fen: String) {
        let settings = Chess960TwoPlayerSettings(startFEN: fen)
        sessionStore.remove(sessionKey(for: .activeChess960TwoPlayerGame(settings)))
        path.append(Route.activeChess960TwoPlayerGame(settings))
    }

    /// Idem pour le mode deux joueurs.
    private func startNewTwoPlayerGame(
        _ settings: TwoPlayerGameSettings, replacingCurrent: Bool = false
    ) {
        AutosaveStore.clearTwoPlayer()
        sessionStore.remove(sessionKey(for: .activeTwoPlayerGame(settings)))
        if replacingCurrent, !path.isEmpty { path.removeLast() }
        path.append(Route.activeTwoPlayerGame(settings))
    }

    private func rematch(with settings: PlayGameSettings) {
        startNewGame(settings, replacingCurrent: true)
    }

    private func twoPlayerRematch(with settings: TwoPlayerGameSettings) {
        startNewTwoPlayerGame(settings, replacingCurrent: true)
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
                if persistenceHealth.showsBanner { persistenceBanner }
                if seedingState.isSeeding { seedingBanner }
                if let resumableGame { resumeBanner(resumableGame) }
                modesSection(minTile: ModeGridMetrics.minTileIPhone)
                if !recentGames.isEmpty { recentGamesSection }
            }
            .padding(20)
        }
    }

    // MARK: Grille des modes

    /// `minTile` : largeur mini d'une tuile, qui décide du nombre de colonnes
    /// — voir ``ModeGridMetrics/minTileIPhone`` pour le choix de la valeur et
    /// ce qu'elle garantit sur un écran de 320 pt.
    private func modesSection(minTile: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Modes")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: minTile), spacing: ModeGridMetrics.spacing)],
                spacing: ModeGridMetrics.spacing
            ) {
                ModeCard(title: "Contre l'ordinateur", shortTitle: "Ordinateur", subtitle: "Force, cadence, aides", systemImage: "cpu", tint: Theme.accent, isEnabled: true) {
                    path.append(Route.newGame)
                }
                ModeCard(title: "Deux joueurs", shortTitle: "2 joueurs", subtitle: "Sur le même appareil", systemImage: "person.2.fill", tint: Theme.info, isEnabled: true) {
                    path.append(Route.twoPlayerSetup)
                }
                ModeCard(title: "Puzzles", subtitle: "Tactique et bibliothèque Lichess", shortSubtitle: "Tactique et Lichess", systemImage: "puzzlepiece.fill", tint: Theme.violet, isEnabled: true) {
                    path.append(Route.puzzleQueue)
                }
                ModeCard(title: "Ouvertures", subtitle: "Apprends et révise tes ouvertures", shortSubtitle: "Apprends et révise", systemImage: "books.vertical.fill", tint: Theme.warning, isEnabled: true, accessibilityID: "mode_openings") {
                    path.append(Route.openingList)
                }
                ModeCard(title: "Finales", subtitle: "Lucena, Philidor, opposition — prouvées", shortSubtitle: "Techniques prouvées", systemImage: "crown.fill", tint: Theme.gold, isEnabled: true, accessibilityID: "mode_endgames") {
                    path.append(Route.endgameList)
                }
                ModeCard(title: "Analyser", subtitle: "PGN, FEN, bibliothèque", shortSubtitle: "PGN, FEN", systemImage: "chart.xyaxis.line", tint: Theme.teal, isEnabled: true) {
                    path.append(Route.analysisEntry)
                }
                ModeCard(title: "Laboratoire", subtitle: "L'ordinateur contre lui-même", shortSubtitle: "Face à lui-même", systemImage: "flask", tint: Theme.rose, isEnabled: true) {
                    path.append(Route.labSetup(startFEN: nil))
                }
                ModeCard(title: "Variantes", subtitle: "Chess960 et autres façons de jouer", shortSubtitle: "Chess960 et plus", systemImage: "die.face.5.fill", tint: Theme.violet, isEnabled: true, accessibilityID: "mode_variants") {
                    path.append(Route.variantsHub)
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

    /// « Vos données ne s'enregistrent plus » — discrète mais franche.
    /// Deux causes distinctes, deux textes : la base qui ne s'ouvre plus
    /// (session en mémoire) et les enregistrements qui échouent en série
    /// (disque plein, conflit) — voir ``PersistenceHealth``.
    private var persistenceBanner: some View {
        HStack(spacing: 14) {
            IconBadge(systemImage: "exclamationmark.triangle.fill", tint: Theme.warning, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(persistenceHealth.isDegradedSession
                     ? "Session sans enregistrement"
                     : "Vos données ne s'enregistrent plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(persistenceHealth.isDegradedSession
                     ? "La base n'a pas pu s'ouvrir — vos données existantes sont intactes. Redémarrez l'app pour réessayer."
                     : "Vérifiez l'espace disque. Vos dernières actions risquent d'être perdues.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
        .overlay(Theme.cardShape.strokeBorder(Theme.warning.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("persistenceBanner")
    }

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
                    // Le nom était figé à 32 pt juste au-dessus d'un
                    // `.subheadline` qui, lui, grossissait : à AX5 le
                    // sous-titre rattrapait le titre. Plafonné à 1,4× — un
                    // en-tête d'accueil doit rester un en-tête.
                    .scaledSystemFont(
                        size: 32, relativeTo: .largeTitle,
                        weight: .bold, design: .rounded, maximumScale: 1.4
                    )
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

    /// Bouton rond de barre d'outils (Aide, Progression, Réglages) — style
    /// commun pour que les icônes de l'accueil restent visuellement sœurs.
    ///
    /// `tint` non nul = teinte sur le glyphe, le fond et le liseré.
    ///
    /// Les trois boutons sont désormais colorés (24/08) : une couleur par
    /// fonction — vert pour l'aide, bleu pour la progression (comme ses
    /// courbes), doré pour les réglages. On perd la hiérarchie que le gris
    /// donnait à l'aide ; c'est un choix assumé, l'accueil gagne en gaieté ce
    /// qu'il perd en mise en avant, et les trois restent distincts entre eux.
    private func toolbarCircleButton(
        _ systemImage: String, label: LocalizedStringKey,
        identifier: String, tint: Color? = nil, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint ?? Theme.textSecondary)
                .frame(width: 34, height: 34)
                .background(
                    tint.map { AnyShapeStyle($0.opacity(0.16)) }
                        ?? AnyShapeStyle(Theme.surfaceElevated.opacity(0.92)),
                    in: Circle()
                )
                .overlay(Circle().strokeBorder(tint?.opacity(0.5) ?? Theme.stroke, lineWidth: 1))
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
                    // La MÊME pastille que la bibliothèque (ivoire/ardoise) :
                    // l'accueil affichait « 1/2-1/2 » sur fond émeraude, un
                    // second langage pour la même information.
                    GameResultPill(raw: game.resultRaw)
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
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    let onExit: () -> Void
    let onAnalyze: (String) -> Void
    var onRematch: (PlayGameSettings) -> Void = { _ in }
    /// Passerelles « Continuer ailleurs » du menu d'export — voir ``PlayView``.
    var onAnalyzePosition: (String) -> Void = { _ in }
    var onOpenLab: (String) -> Void = { _ in }
    var onOpenTwoPlayer: (String) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: PlayViewModel?

    var body: some View {
        Group {
            if let viewModel {
                PlayView(
                    viewModel: viewModel, onExit: onExit, onAnalyze: onAnalyze,
                    onRematch: onRematch, onAnalyzePosition: onAnalyzePosition, onOpenLab: onOpenLab,
                    onOpenTwoPlayer: onOpenTwoPlayer
                )
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = sessionStore.value(for: sessionKey) {
                    PlayViewModel(settings: settings, modelContext: modelContext)
                }
            }
        }
    }
}

/// Héberge un `PlayViewModel` restauré depuis l'autosauvegarde, créé une
/// seule fois à l'apparition de cette vue.
private struct ResumedGameHost: View {
    let autosave: PlayGameAutosave
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    let onExit: () -> Void
    let onAnalyze: (String) -> Void
    var onRematch: (PlayGameSettings) -> Void = { _ in }
    /// Passerelles « Continuer ailleurs » du menu d'export — voir ``PlayView``.
    var onAnalyzePosition: (String) -> Void = { _ in }
    var onOpenLab: (String) -> Void = { _ in }
    var onOpenTwoPlayer: (String) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: PlayViewModel?

    var body: some View {
        Group {
            if let viewModel {
                PlayView(
                    viewModel: viewModel, onExit: onExit, onAnalyze: onAnalyze,
                    onRematch: onRematch, onAnalyzePosition: onAnalyzePosition, onOpenLab: onOpenLab,
                    onOpenTwoPlayer: onOpenTwoPlayer
                )
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
                viewModel = sessionStore.value(for: sessionKey) {
                    PlayViewModel(resuming: autosave, modelContext: modelContext)
                }
            }
        }
    }
}

/// Héberge un `TwoPlayerViewModel` créé une seule fois (à l'apparition de
/// cette vue) pour une nouvelle partie — même discipline de construction
/// paresseuse que ``ActiveGameHost``, par cohérence (pas d'effet de bord
/// process moteur ici, donc moins critique).
/// Voir ``ActiveGameHost`` : même remède, même raison — sans lui, chaque
/// re-rendu de `HomeView` (donc chaque coup joué, puisqu'il mute l'état
/// observé par la hiérarchie) reconstruisait un ``Chess960PlayViewModel``
/// neuf et effaçait la partie en cours. C'est le défaut signalé le 25/08 :
/// « je n'arrive pas à déplacer les pièces » — chaque coup se voyait
/// aussitôt annulé par une réinitialisation silencieuse.
private struct Chess960ActiveGameHost: View {
    let settings: Chess960Settings
    let sessionKey: String
    let onExit: () -> Void
    var onOpenTwoPlayer: (String) -> Void = { _ in }
    var onAnalyze: (String) -> Void = { _ in }
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: Chess960PlayViewModel?

    var body: some View {
        Group {
            if let viewModel {
                Chess960PlayView(viewModel: viewModel, onExit: onExit, onOpenTwoPlayer: onOpenTwoPlayer, onAnalyze: onAnalyze)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = sessionStore.value(for: sessionKey) {
                    Chess960PlayViewModel(settings: settings)
                }
            }
        }
    }
}

private struct Chess960TwoPlayerActiveGameHost: View {
    let settings: Chess960TwoPlayerSettings
    let sessionKey: String
    let onExit: () -> Void
    var onAnalyze: (String) -> Void = { _ in }
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: Chess960TwoPlayerViewModel?

    var body: some View {
        Group {
            if let viewModel {
                Chess960TwoPlayerView(viewModel: viewModel, onExit: onExit, onAnalyze: onAnalyze)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = sessionStore.value(for: sessionKey) {
                    Chess960TwoPlayerViewModel(settings: settings)
                }
            }
        }
    }
}

/// Héberge un `Chess960AnalysisViewModel` — même discipline paresseuse que
/// ``AnalysisHost``. Construction ÉCHOUABLE (`init?(pgn:)`) : un PGN qui ne
/// vient pas de ``Chess960PlayViewModel/exportedPGN`` ou de son homologue
/// Deux joueurs ne devrait jamais échouer, mais l'écran reste vide plutôt que
/// de planter si un jour une autre source lui passe un PGN invalide.
private struct Chess960AnalysisActiveGameHost: View {
    let pgn: String
    let sessionKey: String
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: Chess960AnalysisViewModel?

    var body: some View {
        Group {
            if let viewModel {
                Chess960AnalysisView(viewModel: viewModel)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = sessionStore.value(for: sessionKey) {
                    Chess960AnalysisViewModel(pgn: pgn)
                }
            }
        }
    }
}

private struct TwoPlayerActiveGameHost: View {
    let settings: TwoPlayerGameSettings
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    let onExit: () -> Void
    let onAnalyze: (String) -> Void
    var onRematch: (TwoPlayerGameSettings) -> Void = { _ in }
    /// Passerelles « Continuer ailleurs » du menu d'export — voir ``TwoPlayerGameView``.
    var onAnalyzePosition: (String) -> Void = { _ in }
    var onOpenLab: (String) -> Void = { _ in }
    var onPlayVsEngine: (String) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: TwoPlayerViewModel?

    var body: some View {
        Group {
            if let viewModel {
                TwoPlayerGameView(
                    viewModel: viewModel, onExit: onExit, onAnalyze: onAnalyze,
                    onRematch: onRematch, onAnalyzePosition: onAnalyzePosition, onOpenLab: onOpenLab,
                    onPlayVsEngine: onPlayVsEngine
                )
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = sessionStore.value(for: sessionKey) {
                    TwoPlayerViewModel(settings: settings, modelContext: modelContext)
                }
            }
        }
    }
}

/// Héberge un `TwoPlayerViewModel` restauré depuis l'autosauvegarde.
private struct TwoPlayerResumedGameHost: View {
    let autosave: TwoPlayerGameAutosave
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    let onExit: () -> Void
    let onAnalyze: (String) -> Void
    var onRematch: (TwoPlayerGameSettings) -> Void = { _ in }
    /// Passerelles « Continuer ailleurs » du menu d'export — voir ``TwoPlayerGameView``.
    var onAnalyzePosition: (String) -> Void = { _ in }
    var onOpenLab: (String) -> Void = { _ in }
    var onPlayVsEngine: (String) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: TwoPlayerViewModel?

    var body: some View {
        Group {
            if let viewModel {
                TwoPlayerGameView(
                    viewModel: viewModel, onExit: onExit, onAnalyze: onAnalyze,
                    onRematch: onRematch, onAnalyzePosition: onAnalyzePosition, onOpenLab: onOpenLab,
                    onPlayVsEngine: onPlayVsEngine
                )
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
                viewModel = sessionStore.value(for: sessionKey) {
                    TwoPlayerViewModel(resuming: autosave, modelContext: modelContext)
                }
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
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    let onPlayFromHere: (String) -> Void
    var onOpenLab: (String) -> Void = { _ in }
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: AnalysisViewModel?

    var body: some View {
        Group {
            if let viewModel {
                AnalysisView(viewModel: viewModel, onPlayFromHere: onPlayFromHere, onOpenLab: onOpenLab)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = sessionStore.value(for: sessionKey) { AnalysisViewModel(source: source) }
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
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    let onExit: () -> Void
    let onViewSourceGame: (String) -> Void
    var onOpenLab: (String) -> Void = { _ in }
    var onPlayVsEngine: (String) -> Void = { _ in }
    var onOpenTwoPlayer: (String) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: PuzzleSolveViewModel?
    @State private var hasAttemptedLoad = false

    var body: some View {
        Group {
            if let viewModel {
                PuzzleSolveView(
                    viewModel: viewModel, onExit: onExit, onViewSourceGame: onViewSourceGame,
                    onOpenLab: onOpenLab, onPlayVsEngine: onPlayVsEngine, onOpenTwoPlayer: onOpenTwoPlayer
                )
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
                viewModel = sessionStore.value(for: sessionKey) {
                    PuzzleSolveViewModel(filter: filter, modelContext: modelContext)
                }
                hasAttemptedLoad = true
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
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    let onExit: () -> Void
    var onAnalyze: (String) -> Void = { _ in }
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: LabViewModel?

    var body: some View {
        Group {
            if let viewModel {
                LabRunView(viewModel: viewModel, onExit: onExit, onAnalyze: onAnalyze)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = sessionStore.value(for: sessionKey) {
                    if let resumeState { return LabViewModel(resuming: resumeState) }
                    if let settings { return LabViewModel(settings: settings) }
                    return nil
                }
            }
        }
    }
}

/// Géométrie de la grille des modes : une largeur mini de tuile décide du
/// nombre de colonnes, donc de toute la physionomie de l'accueil.
///
/// Elle vit ici, hors de la vue, parce qu'un test doit pouvoir la vérifier aux
/// largeurs que les simulateurs ne savent pas produire — même parti pris que
/// ``BoardGeometry`` et ``PlayControlBar``.
enum ModeGridMetrics {
    /// Marge du contenu de l'accueil.
    static let contentPadding: CGFloat = 20
    /// Gouttière entre deux tuiles.
    static let spacing: CGFloat = 14
    /// L'écran le plus étroit à supporter : **iPhone 11 Pro en Zoom
    /// d'affichage**, soit 320 × 693 pt pour un panneau de 1125 × 2436
    /// (relevé sur l'appareil : `xcrun devicectl device info displays`).
    static let narrowestScreen: CGFloat = 320

    /// Largeur mini d'une tuile iPhone.
    ///
    /// **160 auparavant** : deux colonnes tenaient à 375 pt — 2 × 160 + 14 =
    /// 334 pour 335 utiles, un point de marge — mais pas à 320, où l'accueil
    /// tombait à UNE colonne et empilait les sept modes. À 132, deux colonnes
    /// tiennent dès 316 pt d'écran.
    ///
    /// Rien ne change au-dessus : la grille adaptative n'ouvrirait une
    /// troisième colonne qu'à partir de 3 × 132 + 2 × 14 = 424 pt utiles,
    /// hors d'atteinte d'un iPhone en portrait (l'iPhone est verrouillé en
    /// portrait depuis le Lot 2).
    static let minTileIPhone: CGFloat = 132

    /// Place utile pour les tuiles sur un écran de largeur `screen`.
    static func usableWidth(screen: CGFloat) -> CGFloat {
        screen - 2 * contentPadding
    }

    /// Vrai si `count` colonnes de `tile` points tiennent sur cet écran.
    static func fits(columns count: Int, tile: CGFloat, screen: CGFloat) -> Bool {
        CGFloat(count) * tile + CGFloat(count - 1) * spacing <= usableWidth(screen: screen)
    }
}

/// Interne et non privée : les tests de mise en page en rendent une à la
/// largeur d'un écran zoomé (320 pt), largeur qu'aucun simulateur iOS 26 ne
/// sait produire — voir ``ModeGridMetrics`` et `HomeGridLayoutTests`.
struct ModeCard: View {
    let title: LocalizedStringKey
    /// Variante COURTE du titre, pour les tuiles iPhone (2 colonnes,
    /// ~160 pt) — `nil` quand le titre tient déjà (un seul mot). Sur iPad,
    /// où la grille laisse largement la place, le titre complet reste
    /// affiché : voir ``isRegular``.
    var shortTitle: LocalizedStringKey?
    let subtitle: LocalizedStringKey?
    /// Variante COURTE du sous-titre — même raison que ``shortTitle``, mais
    /// pour la légende : plusieurs débordaient encore en points de
    /// suspension malgré `minimumScaleFactor`.
    var shortSubtitle: LocalizedStringKey?
    let systemImage: String
    var tint: Color = Theme.accent
    let isEnabled: Bool
    var accessibilityID: String? = nil
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
    private var displayedTitle: LocalizedStringKey { isRegular ? title : (shortTitle ?? title) }
    private var displayedSubtitle: LocalizedStringKey { isRegular ? (subtitle ?? "Bientôt") : (shortSubtitle ?? subtitle ?? "Bientôt") }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                IconBadge(systemImage: systemImage, tint: tint, size: iconSize, isEnabled: isEnabled)

                Spacer(minLength: 16)

                // `lineLimit` + `minimumScaleFactor` : la carte a une
                // hauteur FIGÉE — aux tailles d'accessibilité XXL, un titre
                // sans borne déborderait de la tuile.
                Text(displayedTitle)
                    .font(isRegular ? .title3.weight(.semibold) : .headline)
                    .foregroundStyle(isEnabled ? Theme.textPrimary : Theme.textTertiary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(displayedSubtitle)
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
                        // Purement décorative — et invisible au-delà de la
                        // carte, que `clipShape` écrête. L'accessibilité, elle,
                        // ne sait pas qu'elle est écrêtée : sans ce masquage,
                        // la `frame` annoncée de la tuile allait jusqu'à
                        // 17,5 pt HORS de l'écran sur iPhone SE, VoiceOver
                        // voyait un glyphe qui ne dit rien, et le détecteur de
                        // débordement du Lot 0 signalait l'accueil à tort.
                        .accessibilityHidden(true)
                }
                // Le FOND ENTIER est décoratif, et surtout : il est écrêté
                // ici même. `clipShape` plus bas masque le débordement à
                // l'œil, mais la géométrie annoncée à l'accessibilité, elle,
                // continuait d'inclure l'icône fantôme — la tuile se
                // déclarait 198 pt de large pour 160,5 réels, soit 17,5 pt
                // hors écran sur iPhone SE.
                .clipped()
                .accessibilityHidden(true)
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
        .accessibilityIdentifier(accessibilityID ?? "")
    }
}

#Preview {
    HomeView()
}
