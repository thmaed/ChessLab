import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// La pendule doit décompter **dès l'ouverture** de la partie (Lot 2 de
/// `PROMPT-bugs.md`).
///
/// Le défaut : `GameClock` était bien créée à l'`init` d'une partie neuve, mais
/// `startTurn` n'était appelé qu'au premier `commit` — et à la reprise d'une
/// autosauvegarde. Le camp au trait jouait donc son premier coup hors du temps,
/// l'affichage restait figé sur le temps initial, et contre Stockfish aux
/// Blancs la réflexion du moteur n'était pas décomptée non plus. Le
/// commentaire de la reprise qualifiait déjà ce comportement de bug
/// « répétable à volonté » : la nouvelle partie avait le même, non corrigé.
///
/// Ces tests échouent avant correction et passent après.
///
/// Aucun ne démarre Stockfish : on n'appelle jamais `handleViewAppear()` sur un
/// view model dont le moteur aurait été libéré, et `TwoPlayerViewModel` n'a pas
/// de moteur du tout.
@MainActor
struct GameClockStartTests {

    private static func inMemoryContext() throws -> ModelContext {
        let schema = Schema([GameRecord.self, Puzzle.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    /// 3+0 : trois minutes, sans incrément.
    private static func blitzSettings() -> TwoPlayerGameSettings {
        var settings = TwoPlayerGameSettings.default
        settings.timeControlID = "custom"
        settings.customMinutes = 3
        settings.customIncrementSeconds = 0
        return settings
    }

    // MARK: Deux joueurs (aucun moteur en jeu)

    @Test func twoPlayerClockIsIdleBeforeTheViewAppears() throws {
        let settings = Self.blitzSettings()
        let viewModel = TwoPlayerViewModel(settings: settings, modelContext: try Self.inMemoryContext())

        // À la construction, rien ne tourne : la vue n'est pas encore là, et
        // décompter du temps qu'on ne voit pas serait le voler au joueur.
        #expect(viewModel.clock?.isRunning == false)
    }

    @Test func twoPlayerClockRunsForWhiteAsSoonAsTheViewAppears() throws {
        let settings = Self.blitzSettings()
        let viewModel = TwoPlayerViewModel(settings: settings, modelContext: try Self.inMemoryContext())

        viewModel.handleViewAppear()

        #expect(viewModel.clock?.isRunning == true)
        #expect(viewModel.moveLog.isEmpty, "le décompte commence AVANT le premier coup")
    }

    /// Le cœur du bug : le temps des Blancs doit **décroître avant** le premier
    /// coup. C'est l'assertion demandée par le Lot 0.3.
    @Test func whiteTimeDecreasesBeforeTheFirstMove() async throws {
        let settings = Self.blitzSettings()
        let viewModel = TwoPlayerViewModel(settings: settings, modelContext: try Self.inMemoryContext())
        viewModel.handleViewAppear()

        let initial = try #require(viewModel.clock?.whiteRemaining)

        // ATTENTE ACTIVE plutôt qu'un `sleep` unique suivi d'une lecture : la
        // pendule décompte depuis sa propre tâche, sur le même acteur que ce
        // test. Quand d'autres suites saturent le `MainActor` (les bancs
        // d'essai moteur tournent en parallèle), le réveil du test peut
        // précéder le premier tick — on mesurait alors l'ordre
        // d'ordonnancement, pas le comportement de la pendule.
        var later = initial
        let deadline = Date().addingTimeInterval(10)
        while later >= initial, Date() < deadline {
            try await Task.sleep(nanoseconds: 200_000_000)
            later = try #require(viewModel.clock?.whiteRemaining)
        }

        #expect(later < initial, "le temps des Blancs doit décroître sans qu'aucun coup soit joué")
        #expect(viewModel.moveLog.isEmpty)
        // Et c'est bien le camp au trait qui paie : les Noirs sont intacts.
        #expect(viewModel.clock?.blackRemaining == TimeInterval(3 * 60))
    }

    @Test func twoPlayerAppearingTwiceDoesNotRestartTheClock() async throws {
        let settings = Self.blitzSettings()
        let viewModel = TwoPlayerViewModel(settings: settings, modelContext: try Self.inMemoryContext())

        viewModel.handleViewAppear()
        try await Task.sleep(nanoseconds: 800_000_000)
        let afterFirstAppear = try #require(viewModel.clock?.whiteRemaining)

        // Revenir sur l'écran ne doit pas rendre du temps déjà consommé.
        viewModel.handleViewAppear()
        let afterSecondAppear = try #require(viewModel.clock?.whiteRemaining)

        #expect(afterSecondAppear <= afterFirstAppear)
    }

    // MARK: Sans cadence

    @Test func noClockMeansNothingToStart() throws {
        // Cadence « aucune » : `hasClock` est faux, aucune pendule n'est créée.
        let settings = TwoPlayerGameSettings.default
        let viewModel = TwoPlayerViewModel(settings: settings, modelContext: try Self.inMemoryContext())

        viewModel.handleViewAppear()

        #expect(viewModel.clock == nil, "sans cadence, aucune pendule n'est créée")
    }
}
