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

    /// Dans la feuille « Série sur mesure » (28/10/2026) : vos puzzles n'ont pas de
    /// cote, choisir « Mes parties » retire le niveau, le désélectionner le rend.
    func testOwnGamesHideTheLevelFilter() throws {
        let app = launchOnPuzzleQueue()
        let custom = element(app, "serie-sur-mesure")
        XCTAssertTrue(custom.waitForExistence(timeout: 15))
        custom.tap()

        let level = element(app, "niveau-beginner")
        XCTAssertTrue(level.waitForExistence(timeout: 5), "le niveau doit s'afficher par défaut")
        let own = element(app, "provenance-ownGames")
        var tries = 0
        while !own.isHittable, tries < 6 { app.swipeUp(); tries += 1 }
        own.tap()
        XCTAssertTrue(level.waitForNonExistence(timeout: 3), "vos puzzles n'ont pas de cote : le niveau doit disparaître")

        own.tap()
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
        XCTAssertFalse(missed.isEnabled, "aucun puzzle raté : la tuile « Ratés » doit être grisée")
    }

    /// « Ratés » mène soit à un puzzle (il y en a), soit au message dédié —
    /// jamais à un écran vide ni à « Aucun puzzle dû ».
    func testMissedSessionOpensAPuzzleOrSaysNoneIsMissed() throws {
        let app = launchOnPuzzleQueue()
        let missed = element(app, "historique-rates")
        XCTAssertTrue(missed.waitForExistence(timeout: 15))
        // Les séries démarrent au toucher (28/10/2026). Aucun puzzle raté : la tuile est
        // GRISÉE ; on lance alors « À mon niveau », qui doit, elle, ouvrir un puzzle.
        if missed.isEnabled { missed.tap() } else { element(app, "serie-mon-niveau").tap() }

        let puzzle = element(app, "puzzleHint")
        let empty = element(app, "puzzleSessionEmpty")
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline, !puzzle.exists, !empty.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(puzzle.exists || empty.exists, "la série « Ratés » doit ouvrir un puzzle ou le dire")
    }
}
