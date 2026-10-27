import XCTest

/// Régression : revenir à l'accueil par le bouton retour SYSTÈME (et pas le
/// bouton « Accueil » du panneau, qui seul passait par `onExit`) doit
/// rafraîchir la reprise. Sans ça, « Reprendre la partie en cours » gardait un
/// instantané figé : elle rouvrait une partie périmée avec un mauvais nombre
/// de coups, alors que l'autosave sur disque était pourtant à jour.
@MainActor
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

    /// Depuis l'écran « Nouvelle partie » : la partie en cours se voit (carte « Reprendre »), et
    /// « Commencer » ne l'efface plus sans demander. Retour d'un joueur (27/10/2026) : la flèche le
    /// ramenait ici, « Commencer » lançait une nouvelle partie et la sienne était perdue.
    @MainActor
    func testSetupScreenOffersResumeAndAsksBeforeReplacing() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen"]
        app.launch()

        app.buttons["Contre l'ordinateur"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["setupResumeGame"].exists, "aucune partie en cours : pas de carte")
        app.buttons["Commencer"].tap()

        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 20))
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        let moveCount = app.otherElements["moveCount"]
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline, moveCount.value as? String != "2" {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertEqual(moveCount.value as? String, "2")

        // Retour par la flèche, puis de nouveau l'écran de réglages.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["resumeGame"].waitForExistence(timeout: 5))
        app.buttons["Contre l'ordinateur"].tap()
        XCTAssertTrue(app.buttons["setupResumeGame"].waitForExistence(timeout: 5), "la carte « Reprendre » doit s'afficher")

        // « Commencer » demande avant d'effacer ; « Reprendre » rouvre la partie avec ses 2 coups.
        app.buttons["Commencer"].tap()
        XCTAssertTrue(app.alerts["Une partie est en cours"].waitForExistence(timeout: 5))
        app.alerts.buttons["Reprendre la partie en cours"].tap()
        XCTAssertTrue(app.otherElements["square_e4"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.otherElements["moveCount"].value as? String, "2")
    }
}
