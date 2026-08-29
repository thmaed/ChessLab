import XCTest

/// Outil de REGARD, pas de non-régression : joue une vraie partie de variante
/// sur plusieurs coups, l'abandonne, ouvre l'analyse et dépose une capture
/// dans `/tmp/cl-courbe/`. Sert à juger la courbe d'évaluation avec de la
/// matière — deux demi-coups ne disent rien de son allure.
final class VariantAnalysisCurveCaptureUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testCaptureVariantAnalysisCurve() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["mode_variants"].waitForExistence(timeout: 15))
        app.buttons["mode_variants"].tap()

        let tile = app.buttons["variant_kingofthehill"]
        XCTAssertTrue(tile.waitForExistence(timeout: 8))
        tile.tap()
        let start = app.buttons["fairyVariant_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 20))

        // Six demi-coups utilisateur, chacun suivi de la réponse machine :
        // une douzaine de points sur la courbe, de quoi la juger.
        let count = app.otherElements["fairyVariant_moveCount"]
        let script = [("e2", "e4"), ("g1", "f3"), ("f1", "c4"), ("d2", "d4"), ("b1", "c3"), ("c1", "g5")]
        for (from, to) in script {
            let target = Int(count.value as? String ?? "0") ?? 0
            app.otherElements["square_\(from)"].tap()
            app.otherElements["square_\(to)"].tap()
            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline, Int(count.value as? String ?? "0") ?? 0 < target + 2 {
                RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            }
        }
        XCTAssertGreaterThanOrEqual(Int(count.value as? String ?? "0") ?? 0, 6,
                                    "il faut une vraie partie à analyser")

        XCTAssertTrue(app.buttons["Abandonner"].waitForExistence(timeout: 5))
        app.buttons["Abandonner"].tap()
        XCTAssertTrue(app.staticTexts["Abandonner la partie ?"].waitForExistence(timeout: 5))
        let confirm = app.sheets.buttons["Abandonner"].exists
            ? app.sheets.buttons["Abandonner"]
            : app.buttons.matching(identifier: "Abandonner").element(boundBy: 1)
        confirm.tap()

        let analyse = app.buttons["Analyser"].firstMatch
        XCTAssertTrue(analyse.waitForExistence(timeout: 10))
        analyse.tap()
        XCTAssertTrue(app.otherElements["variantAnalysis_totalPlies"].waitForExistence(timeout: 20))

        // Laisser la passe de classification remplir la courbe.
        RunLoop.current.run(until: Date().addingTimeInterval(25))
        try? FileManager.default.createDirectory(atPath: "/tmp/cl-courbe", withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: "/tmp/cl-courbe/variante.png"))
    }
}
