import XCTest

/// Débranchement demandé le 25/08 : « à la fin de la partie chess960 [...]
/// l'analyse de la partie démarre comme sur le jeu normal ». Vérifie le
/// chemin complet — abandon (la partie la plus courte à terminer), tap sur
/// « Analyser » du bilan de fin de partie, arrivée sur l'écran d'analyse
/// Chess960 avec la partie effectivement rejouée (au moins le coup joué
/// avant l'abandon).
final class Chess960AnalysisUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAnalyzeButtonAfterResignOpensTheReplayedGame() throws {
        let app = XCUIApplication()
        app.launch()

        _ = app.buttons["mode_variants"].waitForExistence(timeout: 5)
        app.buttons["mode_variants"].tap()
        _ = app.buttons["variant_chess960"].waitForExistence(timeout: 5)
        app.buttons["variant_chess960"].tap()
        _ = app.buttons["chess960_start"].waitForExistence(timeout: 5)
        app.buttons["chess960_start"].tap()

        // e2-e4 : légal depuis n'importe laquelle des 960 positions de départ.
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 10))
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()

        let moveCount = app.otherElements["chess960_moveCount"]
        let movedDeadline = Date().addingTimeInterval(5)
        while Date() < movedDeadline, Int(moveCount.value as? String ?? "") ?? 0 < 1 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertGreaterThanOrEqual(Int(moveCount.value as? String ?? "") ?? 0, 1, "le coup joué doit tenir avant l'abandon")

        XCTAssertTrue(app.buttons["Abandonner"].waitForExistence(timeout: 5))
        app.buttons["Abandonner"].tap()
        XCTAssertTrue(app.staticTexts["Abandonner la partie ?"].waitForExistence(timeout: 5))
        let confirm = app.sheets.buttons["Abandonner"].exists
            ? app.sheets.buttons["Abandonner"]
            : app.buttons.matching(identifier: "Abandonner").element(boundBy: 1)
        confirm.tap()

        XCTAssertTrue(app.buttons["Analyser"].waitForExistence(timeout: 5), "le bilan de fin de partie doit proposer Analyser")
        app.buttons["Analyser"].tap()

        let totalPlies = app.otherElements["chess960_analysis_totalPlies"]
        XCTAssertTrue(totalPlies.waitForExistence(timeout: 10), "l'écran d'analyse Chess960 doit s'ouvrir")
        let repliesDeadline = Date().addingTimeInterval(5)
        while Date() < repliesDeadline, Int(totalPlies.value as? String ?? "") ?? 0 < 1 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertGreaterThanOrEqual(Int(totalPlies.value as? String ?? "") ?? 0, 1,
                                     "la partie rejouée doit compter au moins le coup joué avant l'abandon")

        // La courbe d'évaluation, partagée par les quatre écrans d'analyse
        // depuis le 29/08 : on vérifie qu'elle est bien là, et on garde une
        // capture pour l'œil.
        XCTAssertTrue(app.otherElements["evalCurve"].waitForExistence(timeout: 15),
                      "la courbe d'évaluation doit être affichée")
        try? FileManager.default.createDirectory(atPath: "/tmp/cl-courbe", withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: "/tmp/cl-courbe/chess960.png"))

    }
}
