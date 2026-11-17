import XCTest

/// Une fenêtre LARGE et BASSE — l'écran intérieur de l'iPhone Duo en paysage (≈ 951 × 669 pt) — rangeait les
/// quatre grandes tuiles sur toute la hauteur, « Plus » sous le pli et la droite vide (retour du 16/11/2026).
///
/// Le simulateur du Duo ne se tourne qu'à la main (Device Hub) : on éprouve la même géométrie sur un iPad mini en
/// paysage, barre latérale repliée (≈ 1133 × 744 pt). Tout doit tenir sans défiler, chaque étage sur une rangée.
@MainActor
final class WideLowDashboardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWideLowWindow_everyModeFitsOnOneScreen_oneRowPerTier() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad (fenêtre régulière) seulement") }
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen", "-AppleLanguages", "(fr)"]
        app.launch()

        let play = app.buttons["mode_play"]
        XCTAssertTrue(play.waitForExistence(timeout: 20))
        // La barre latérale repliée : la fenêtre de détail prend toute la largeur, comme sur le Duo.
        let sidebarToggle = app.buttons.matching(NSPredicate(
            format: "identifier == 'ToggleSidebar' OR label CONTAINS[c] 'barre latérale' OR label CONTAINS[c] 'sidebar'"
        )).firstMatch
        if sidebarToggle.waitForExistence(timeout: 5), app.cells.count > 0 || app.staticTexts["Modes"].exists {
            sidebarToggle.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        }
        snapshot(app, "ipad-mini-paysage-sans-barre")
        // Une fenêtre HAUTE (iPad 11 ou 13 pouces) garde ses deux rangées : la règle ne vise que les basses.
        try XCTSkipUnless(app.windows.firstMatch.frame.height < 760,
                          "fenêtre de \(Int(app.windows.firstMatch.frame.height)) pt de haut : pas « basse »")

        let main = [play, app.buttons["Puzzles"].firstMatch, app.buttons["mode_openings"], app.buttons["Analyser"].firstMatch]
        let more = [app.buttons["mode_twoPlayer"], app.buttons["mode_endgames"], app.buttons["mode_variants"],
                    app.buttons["Laboratoire"].firstMatch]
        for tile in main + more {
            XCTAssertTrue(tile.waitForExistence(timeout: 5), "\(tile) doit exister")
            XCTAssertTrue(tile.isHittable, "\(tile.label) doit être visible SANS défiler")
        }
        let mainRows = Set(main.map { Int($0.frame.minY.rounded()) })
        let moreRows = Set(more.map { Int($0.frame.minY.rounded()) })
        XCTAssertEqual(mainRows.count, 1, "les quatre modes principaux sur UNE rangée : \(main.map(\.frame))")
        XCTAssertEqual(moreRows.count, 1, "« Plus » sur une rangée : \(more.map(\.frame))")
        // La carte « À l'aveugle » (17/11/2026), pleine largeur sous « Plus » : elle aussi SANS défiler.
        let blindfold = app.buttons["mode_blindfold"]
        XCTAssertTrue(blindfold.waitForExistence(timeout: 5))
        XCTAssertTrue(blindfold.isHittable, "« À l'aveugle » doit être visible SANS défiler")
        // Capture en paysage : celle de XCUITest sort pivotée et rognée. Avec CHESSLAB_HOLD (variable
        // TEST_RUNNER_CHESSLAB_HOLD), l'écran reste affiché le temps d'un `simctl io screenshot`.
        if ProcessInfo.processInfo.environment["CHESSLAB_HOLD"] != nil {
            RunLoop.current.run(until: Date().addingTimeInterval(25))
        }
    }
}
