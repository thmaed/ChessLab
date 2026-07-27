import XCTest

/// Régression : revenir à l'accueil par le bouton retour SYSTÈME (et pas le
/// bouton « Accueil » du panneau, qui seul passait par `onExit`) doit
/// rafraîchir la reprise. Sans ça, « Reprendre la partie en cours » gardait un
/// instantané figé : elle rouvrait une partie périmée avec un mauvais nombre
/// de coups, alors que l'autosave sur disque était pourtant à jour.
final class ResumeGameUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testResumeReflectsLastGameAfterSystemBack() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        app.buttons["Contre l'ordinateur"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()

        let e2 = app.otherElements["square_e2"]
        XCTAssertTrue(e2.waitForExistence(timeout: 20))
        e2.tap()
        app.otherElements["square_e4"].tap()

        // Attendre la réponse du moteur : 2 demi-coups joués (le nôtre + le sien).
        let moveCount = app.otherElements["moveCount"]
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline, moveCount.value as? String != "2" {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertEqual(moveCount.value as? String, "2", "le moteur doit avoir répondu")

        // Retour par le bouton RETOUR SYSTÈME — le cas du bug, PAS « Accueil ».
        app.navigationBars.buttons.firstMatch.tap()

        // La reprise doit apparaître ET rouvrir la BONNE partie (ses 2 coups).
        let resume = app.buttons["resumeGame"]
        XCTAssertTrue(
            resume.waitForExistence(timeout: 5),
            "la reprise doit apparaître après un retour système"
        )
        resume.tap()

        XCTAssertTrue(app.otherElements["square_e4"].waitForExistence(timeout: 20))
        XCTAssertEqual(
            app.otherElements["moveCount"].value as? String, "2",
            "la reprise doit rouvrir la dernière partie avec ses 2 coups"
        )
    }
}
