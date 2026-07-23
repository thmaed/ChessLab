import XCTest

/// Reprise après panne moteur (Lot 2.A du final-1407).
///
/// Le prompt exige de « redémarrer l'instance et reprendre depuis le FEN
/// courant ». La panne est provoquée par `-simulateEngineFailure <n>` : une
/// vraie panne de Stockfish ne se déclenche pas depuis un test, et sans cette
/// porte dérobée la bannière et sa reprise ne seraient jamais vérifiées.
///
/// `<n> = 1` fait échouer le PREMIER démarrage seulement : c'est ce qui rend
/// la reprise observable — la bannière apparaît, « Réessayer » réussit, la
/// partie repart. Un échec permanent n'aurait prouvé que l'affichage.
final class EngineRecoveryUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEngineFailureIsShownThenRecoveredByRetry() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-simulateEngineFailure", "1"]
        app.launch()

        XCTAssertTrue(app.buttons["Contre Stockfish"].waitForExistence(timeout: 5))
        app.buttons["Contre Stockfish"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()

        // La panne est dite, pas tue.
        XCTAssertTrue(
            app.staticTexts["Moteur indisponible"].waitForExistence(timeout: 15),
            "un échec de démarrage doit se voir"
        )

        // Jouer reste possible : c'est la réponse du moteur qui manque.
        let e2 = app.otherElements["square_e2"]
        XCTAssertTrue(e2.waitForExistence(timeout: 5))
        e2.tap()
        app.otherElements["square_e4"].tap()
        XCTAssertEqual(app.otherElements["square_e4"].label, "Case e4, pion blanc")

        // Le moteur ne répond pas : le compteur de coups reste à 1.
        let moveCount = app.otherElements["moveCount"]
        RunLoop.current.run(until: Date().addingTimeInterval(5))
        XCTAssertEqual(moveCount.value as? String, "1", "sans moteur, aucune réponse ne peut arriver")

        // Reprise : le second démarrage réussit, et le moteur reprend depuis
        // le FEN courant — donc il répond au coup DÉJÀ joué.
        app.buttons["retryEngine"].tap()

        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline, moveCount.value as? String != "2" {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertEqual(moveCount.value as? String, "2", "après reprise, le moteur doit jouer sa réponse")
        XCTAssertFalse(app.staticTexts["Moteur indisponible"].exists, "la bannière doit disparaître")
    }
}
