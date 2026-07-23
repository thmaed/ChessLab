import XCTest

/// Refonte de l'analyse (19/07) : le bandeau coach qui catégorise le coup
/// affiché, et la feuille « Bilan de la partie » avec le décompte par
/// joueur — vérifiés sur le parcours réel (partie jouée puis analysée),
/// pas sur un écran vide.
final class AnalysisReviewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCoachBarAndGameSummaryAppearInAnalysis() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        // Jouer un coup puis abandonner : la plus courte partie analysable.
        app.buttons["Contre Stockfish"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 15))
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(2))

        XCTAssertTrue(app.buttons["Abandonner"].waitForExistence(timeout: 5))
        app.buttons["Abandonner"].tap()
        XCTAssertTrue(app.staticTexts["Abandonner la partie ?"].waitForExistence(timeout: 5))
        let confirm = app.sheets.buttons["Abandonner"].exists
            ? app.sheets.buttons["Abandonner"]
            : app.buttons.matching(identifier: "Abandonner").element(boundBy: 1)
        confirm.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(2))

        while app.navigationBars.buttons.firstMatch.exists, !app.buttons["Contre Stockfish"].exists {
            app.navigationBars.buttons.firstMatch.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }

        let gameRow = app.buttons["Analyser la partie"].firstMatch
        var tries = 0
        while !gameRow.exists, tries < 8 {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            tries += 1
        }
        XCTAssertTrue(gameRow.exists, "la partie jouée doit apparaître dans les parties récentes")
        gameRow.tap()
        XCTAssertTrue(app.otherElements["square_e4"].waitForExistence(timeout: 10))

        // Avancer d'un coup (lecture automatique : un tap suffit pour la
        // lancer, elle s'arrête seule en fin de ligne). Le bandeau coach
        // doit alors nommer la catégorie du coup affiché — il n'apparaît
        // qu'une fois le coup classifié par Stockfish, d'où le délai large.
        XCTAssertTrue(app.buttons["autoplay"].waitForExistence(timeout: 10))
        app.buttons["autoplay"].tap()
        let coachBar = app.descendants(matching: .any).matching(identifier: "coachBar").firstMatch
        XCTAssertTrue(
            coachBar.waitForExistence(timeout: 45),
            "après navigation, le coup affiché doit être catégorisé dans le bandeau coach"
        )

        // Ouvrir le bilan depuis le menu d'options.
        app.buttons["Plus d'options"].tap()
        let summaryEntry = app.buttons["Bilan de la partie"]
        XCTAssertTrue(summaryEntry.waitForExistence(timeout: 5))
        summaryEntry.tap()

        // La feuille montre les dix catégories, y compris à zéro : la
        // ligne « Gaffe » présente prouve que le tableau complet est là.
        // Délai large : la présentation peut attendre que le fil principal
        // souffle entre deux ticks d'analyse en continu.
        if !app.navigationBars["Bilan de la partie"].waitForExistence(timeout: 15) {
            print("HIERARCHIE_DEBUG_DEBUT")
            print(app.debugDescription)
            print("HIERARCHIE_DEBUG_FIN")
        }
        XCTAssertTrue(app.navigationBars["Bilan de la partie"].exists)
        XCTAssertTrue(app.staticTexts["Gaffe"].firstMatch.exists, "le tableau des catégories doit être complet")
        XCTAssertTrue(app.staticTexts["Brillant"].firstMatch.exists)
    }
}
