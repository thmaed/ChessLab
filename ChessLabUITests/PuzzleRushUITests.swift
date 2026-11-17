import XCTest

/// « Contre la montre » de bout en bout (17/11/2026) : la carte, la règle, le décompte, le chrono, la pause
/// voilée, le bilan.
///
/// - important: PAS de `-resetPlaySettings` : le test doit pouvoir tourner sur un iPhone réel. La série est
///   raccourcie par `-puzzleRushSeconds` (Debug).
@MainActor
final class PuzzleRushUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launchOnRush(seconds: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-openRoute", "puzzles", "-AppleLanguages", "(fr)",
                                "-puzzleRushSeconds", "\(seconds)"]
        app.launch()
        let card = element(app, "serie-contre-la-montre")
        XCTAssertTrue(card.waitForExistence(timeout: 20), "la carte « Contre la montre » doit être dans Puzzles")
        snapshot(app, "puzzles-carte")
        var tries = 0
        while !card.isHittable, tries < 6 { app.swipeUp(); tries += 1 }
        card.tap()
        XCTAssertTrue(element(app, "rushRule").waitForExistence(timeout: 10), "la règle s'affiche avant de commencer")
        snapshot(app, "regle")
        return app
    }

    func testARunGoesFromTheRuleToTheSummary() throws {
        let app = launchOnRush(seconds: 6)
        element(app, "rushStart").tap()
        XCTAssertTrue(element(app, "rushCountdown").waitForExistence(timeout: 3), "décompte 3-2-1")
        XCTAssertTrue(element(app, "rushBoard").waitForExistence(timeout: 6), "puis le plateau")
        XCTAssertTrue(element(app, "rushClock").exists)
        XCTAssertTrue(element(app, "rushErrors").exists)
        snapshot(app, "pendant")

        let final = element(app, "rushFinalScore")
        XCTAssertTrue(final.waitForExistence(timeout: 20), "le temps écoulé mène au bilan")
        XCTAssertTrue(app.buttons["rushAgain"].exists)
        snapshot(app, "bilan")

        app.buttons["rushDone"].tap()
        XCTAssertTrue(element(app, "serie-contre-la-montre").waitForExistence(timeout: 10), "retour aux puzzles")
    }

    func testLeavingTheAppPausesAndHidesTheBoard() throws {
        let app = launchOnRush(seconds: 120)
        element(app, "rushStart").tap()
        XCTAssertTrue(element(app, "rushBoard").waitForExistence(timeout: 8))

        XCUIDevice.shared.press(.home)
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        app.activate()
        let resume = app.buttons["rushResume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "au retour : « En pause », plateau masqué")
        XCTAssertFalse(element(app, "rushBoard").exists, "le plateau ne se voit pas pendant la pause")
        snapshot(app, "pause")
        let before = element(app, "rushClock").value as? String
        RunLoop.current.run(until: Date().addingTimeInterval(2.5))
        XCTAssertEqual(element(app, "rushClock").value as? String, before, "en pause, le chrono ne bouge pas")

        resume.tap()
        XCTAssertTrue(element(app, "rushBoard").waitForExistence(timeout: 5))
    }
}
