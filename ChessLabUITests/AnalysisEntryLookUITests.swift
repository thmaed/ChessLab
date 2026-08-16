import XCTest

/// Capture l'écran d'entrée de l'Analyse, replié puis déplié, pour juger le
/// nouveau style de « Autres sources » à l'œil — le code ne dit pas si un
/// en-tête se lit comme un en-tête.
final class AnalysisEntryLookUITests: XCTestCase {

    @MainActor
    func testCaptureAnalysisEntry() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        for candidate in [app.buttons["Analyser"], app.cells["Analyser"], app.staticTexts["Analyser"]] {
            if candidate.waitForExistence(timeout: 6) { candidate.tap(); break }
        }
        XCTAssertTrue(app.buttons["analysisOtherSources"].waitForExistence(timeout: 10))

        let folded = XCTAttachment(screenshot: app.screenshot())
        folded.name = "analyse-replie"
        folded.lifetime = .keepAlways
        add(folded)

        app.buttons["analysisOtherSources"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        let unfolded = XCTAttachment(screenshot: app.screenshot())
        unfolded.name = "analyse-deplie"
        unfolded.lifetime = .keepAlways
        add(unfolded)
    }
}
