import XCTest

/// Duck Chess de bout en bout : la tuile, l'écran de réglages COMMUN aux
/// variantes, un tour complet en deux temps (déplacer, puis poser le canard),
/// et la réponse de l'ordinateur.
@MainActor
final class DuckChessUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testPlayOneFullTurnAgainstTheComputer() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["mode_variants"].waitForExistence(timeout: 15))
        app.buttons["mode_variants"].tap()

        let tile = app.buttons["variant_duck"]
        XCTAssertTrue(tile.waitForExistence(timeout: 8), "la tuile Duck Chess doit exister")
        for _ in 0..<6 where !tile.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        // Capture du hub : c'est là que se juge la tuile (dessin de canard,
        // teinte, accroche courte). Déposée à côté de celle de la partie.
        try? FileManager.default.createDirectory(atPath: "/tmp/cl-duck", withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/cl-duck/hub.png"))

        tile.tap()

        // Le Duck Chess partage l'écran de réglages des autres variantes
        // depuis qu'il se joue contre l'ordinateur — d'où `fairyVariant_start`
        // et non un bouton à lui.
        let start = app.buttons["fairyVariant_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8), "l'écran de réglages doit proposer de commencer")
        start.tap()

        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 10))
        let phase = app.otherElements["duck_phase"]
        XCTAssertTrue(phase.waitForExistence(timeout: 5))
        XCTAssertEqual(phase.value as? String, "move", "on commence par déplacer une pièce")

        // Premier temps : le coup.
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertEqual(phase.value as? String, "duck", "le coup joué, le canard reste à poser")

        // Second temps : le canard. Le tour est clos, l'ordinateur enchaîne.
        app.otherElements["square_e5"].tap()

        let count = app.otherElements["duck_moveCount"]
        let deadline = Date().addingTimeInterval(40)
        while Date() < deadline, Int(count.value as? String ?? "0") ?? 0 < 2 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertEqual(Int(count.value as? String ?? ""), 2, "l'ordinateur doit avoir répondu")

        // Son tour à lui aussi va jusqu'au canard : la main revient au joueur.
        let phaseDeadline = Date().addingTimeInterval(20)
        while Date() < phaseDeadline, phase.value as? String != "move" {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertEqual(phase.value as? String, "move", "le canard de l'ordinateur est posé")

        try? FileManager.default.createDirectory(atPath: "/tmp/cl-duck", withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/cl-duck/partie.png"))
    }

    /// L'autre moitié de la promesse : une partie finie s'analyse, canard
    /// compris. C'est aussi le passage de relais le plus délicat de l'écran —
    /// le moteur de la partie doit s'effacer avant que celui de l'analyse ne
    /// démarre (un seul processus à la fois).
    @MainActor
    func testAnalyseAfterResigning() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["mode_variants"].waitForExistence(timeout: 15))
        app.buttons["mode_variants"].tap()

        let tile = app.buttons["variant_duck"]
        XCTAssertTrue(tile.waitForExistence(timeout: 8))
        for _ in 0..<6 where !tile.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        tile.tap()

        let start = app.buttons["fairyVariant_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()

        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 10))
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        app.otherElements["square_e5"].tap()

        let count = app.otherElements["duck_moveCount"]
        let replied = Date().addingTimeInterval(40)
        while Date() < replied, Int(count.value as? String ?? "0") ?? 0 < 2 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }

        XCTAssertTrue(app.buttons["Abandonner"].waitForExistence(timeout: 5))
        app.buttons["Abandonner"].tap()
        XCTAssertTrue(app.staticTexts["Abandonner la partie ?"].waitForExistence(timeout: 5))
        // Même contorsion que les autres suites : la feuille de confirmation
        // porte un bouton du MÊME nom que celui de la barre de contrôle.
        let confirm = app.sheets.buttons["Abandonner"].exists
            ? app.sheets.buttons["Abandonner"]
            : app.buttons.matching(identifier: "Abandonner").element(boundBy: 1)
        confirm.tap()

        let analyse = app.buttons["Analyser"].firstMatch
        XCTAssertTrue(analyse.waitForExistence(timeout: 10), "le panneau de fin doit proposer l'analyse")
        analyse.tap()

        let plies = app.otherElements["duckAnalysis_totalPlies"]
        XCTAssertTrue(plies.waitForExistence(timeout: 20), "l'écran d'analyse doit s'ouvrir")
        XCTAssertEqual(Int(plies.value as? String ?? ""), 2, "les deux demi-coups doivent être là")

        // Laisser la passe de classification avancer avant la capture.
        RunLoop.current.run(until: Date().addingTimeInterval(6))
        try? FileManager.default.createDirectory(atPath: "/tmp/cl-duck", withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/cl-duck/analyse.png"))
    }
}
