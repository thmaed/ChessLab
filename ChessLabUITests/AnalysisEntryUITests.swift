import XCTest

/// C6 : l'écran Analyser met la dernière partie en tête, avec ses deux gestes.
@MainActor
final class AnalysisEntryUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testTheLastGameCardOffersAnalysisAndMissedMates() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen", "-seedLibrarySample"]
        app.launch()

        let entry = app.buttons["Analyser"]
        if entry.waitForExistence(timeout: 10) { entry.tap() } else { app.cells["Analyser"].tap() }

        XCTAssertTrue(app.otherElements["lastGameCard"].waitForExistence(timeout: 10), "la carte de la dernière partie")
        XCTAssertTrue(app.buttons["lastGameAnalyze"].exists)
        XCTAssertTrue(app.buttons["lastGameMissedMates"].exists)
        XCTAssertTrue(app.buttons["Scanner une position"].exists, "le scanner reste accessible")
        XCTAssertTrue(app.buttons["Bibliothèque"].exists || app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Bibliothèque")).firstMatch.exists)

        if let path = ProcessInfo.processInfo.environment["SCREENSHOT_PATH"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
        }
        app.buttons["lastGameMissedMates"].tap()
        XCTAssertTrue(app.otherElements["square_e4"].waitForExistence(timeout: 25), "le plateau d'analyse s'ouvre")
    }
}
