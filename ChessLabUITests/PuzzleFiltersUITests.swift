import XCTest

/// Les groupes « Provenance » et « Historique » de l'écran de choix des
/// puzzles (23/10/2026). Pendant de `AppTest.ownGamesHideTheLevelFilter` côté
/// Android.
///
/// - important: PAS de `-resetPlaySettings` : ce test tourne aussi sur un
///   iPhone réel (iOS 18), où il effacerait le nom du joueur et la langue. Les
///   éléments sont trouvés par identifiant, quelle que soit la langue.
@MainActor
final class PuzzleFiltersUITests: XCTestCase {

    private func launchOnPuzzleQueue() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-openRoute", "puzzles"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func testOwnGamesHideTheLevelFilter() throws {
        let app = launchOnPuzzleQueue()
        let level = element(app, "niveau-tous")
        XCTAssertTrue(level.waitForExistence(timeout: 15), "le niveau doit s'afficher par défaut")

        element(app, "provenance-ownGames").tap()
        XCTAssertTrue(level.waitForNonExistence(timeout: 3), "vos puzzles n'ont pas de cote : le niveau doit disparaître")

        element(app, "provenance-ownGames").tap()
        XCTAssertTrue(level.waitForExistence(timeout: 3), "désélectionner « Mes parties » rend le niveau")
    }

    /// Sans puzzle raté, la puce « Ratés » est grisée ; avec, elle répond.
    func testMissedChipIsGreyedOutWhenNothingWasMissed() throws {
        let app = launchOnPuzzleQueue()
        let missed = element(app, "historique-rates")
        XCTAssertTrue(missed.waitForExistence(timeout: 15))
        let counted = Date().addingTimeInterval(5)
        while Date() < counted { RunLoop.current.run(until: Date().addingTimeInterval(0.25)) }
        // Le simulateur de test n'a, au départ, aucun puzzle raté : la puce doit être inactive.
        XCTAssertFalse(missed.isEnabled, "aucun puzzle raté : « Ratés » doit être grisée")
    }

    /// « Ratés » mène soit à un puzzle (il y en a), soit au message dédié —
    /// jamais à un écran vide ni à « Aucun puzzle dû ».
    func testMissedSessionOpensAPuzzleOrSaysNoneIsMissed() throws {
        let app = launchOnPuzzleQueue()
        let missed = element(app, "historique-rates")
        XCTAssertTrue(missed.waitForExistence(timeout: 15))
        // Aucun puzzle raté : la puce est GRISÉE, on ne peut pas la choisir. Sinon, on la choisit.
        if missed.isEnabled { missed.tap() }
        element(app, "startPuzzleSession").tap()

        let puzzle = element(app, "puzzleHint")
        let empty = element(app, "puzzleSessionEmpty")
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline, !puzzle.exists, !empty.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(puzzle.exists || empty.exists, "la série « Ratés » doit ouvrir un puzzle ou le dire")
    }
}
