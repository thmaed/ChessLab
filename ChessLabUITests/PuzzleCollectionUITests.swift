import XCTest

/// Les collections de puzzles importées, de bout en bout : coller un PGN →
/// la collection apparaît → on la travaille en série → en programme Woodpecker
/// → on la supprime.
///
/// Le choix de FICHIERS passe par le sélecteur du système, que XCUITest ne pilote
/// pas : le test passe par la zone de collage, préremplie par l'argument de
/// lancement `-uiTestPuzzleImportText` (DEBUG).
@MainActor
final class PuzzleCollectionUITests: XCTestCase {
    /// Nom unique : le simulateur garde ses données entre deux exécutions.
    private lazy var collectionName = "Mats \(Int(Date().timeIntervalSince1970))"

    /// Deux mats en deux du couloir, le premier avec un FEN différent du second.
    /// Chacun commence par sa PRÉPARATION, le coup adverse a6, joué d'avance.
    private let pgn = [
        "[FEN \"r5k1/p4ppp/8/8/8/4R3/5PPP/4R1K1 b - - 0 22\"]", "22...a6 23. Re8+ Rxe8 24. Rxe8#", "",
        "[FEN \"r5k1/p4ppp/8/8/8/4R3/5PPP/4R1K1 b - - 0 23\"]", "23...a6 24. Re8+ Rxe8 25. Rxe8#", "",
        "[FEN \"pas une position\"]", "1. e4",
    ].joined(separator: "|")

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func scrollTo(_ target: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !target.isHittable, tries < 10 {
            app.swipeUp()
            tries += 1
        }
    }

    func testImportPracticeWoodpeckerAndDeleteACollection() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-discoveryTourSeen", "-openRoute", "puzzles", "-uiTestPuzzleImportText", pgn,
        ]
        app.launch()

        let importRow = element(app, "puzzleImportRow")
        XCTAssertTrue(importRow.waitForExistence(timeout: 15))
        scrollTo(importRow, in: app)
        importRow.tap()

        let name = app.textFields["puzzleImportName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(collectionName)
        app.buttons["puzzleImportPasted"].tap()

        // Le bilan : deux puzzles ajoutés, une partie écartée.
        let report = element(app, "puzzleImportReport")
        XCTAssertTrue(report.waitForExistence(timeout: 15), "le bilan de l'import doit s'afficher")
        XCTAssertTrue(report.label.contains("2"), "deux puzzles ajoutés : \(report.label)")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "import-bilan"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["puzzleImportClose"].tap()

        // La collection est là, avec son compte.
        let row = element(app, "collection-\(collectionName)")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        scrollTo(row, in: app)

        // En série : l'écran de résolution s'ouvre.
        row.tap()
        XCTAssertTrue(element(app, "puzzleHint").waitForExistence(timeout: 15), "un puzzle de la collection doit s'afficher")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // En programme Woodpecker : TOUTE la collection (2 puzzles).
        let archive = element(app, "woodpeckerArchive")
        if archive.waitForExistence(timeout: 3) {
            scrollTo(archive, in: app)
            archive.tap()
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'programme'")).firstMatch.tap()
        }
        let menu = element(app, "collectionMenu-\(collectionName)")
        scrollTo(menu, in: app)
        menu.tap()
        app.buttons["Programme Woodpecker"].tap()
        XCTAssertTrue(element(app, "woodpeckerClock").waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1/2'")).firstMatch.waitForExistence(timeout: 5),
            "le programme couvre toute la collection"
        )
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // On arrête le programme, puis on supprime la collection.
        let stop = element(app, "woodpeckerArchive")
        XCTAssertTrue(stop.waitForExistence(timeout: 10))
        scrollTo(stop, in: app)
        stop.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'programme'")).firstMatch.tap()

        let menuAgain = element(app, "collectionMenu-\(collectionName)")
        scrollTo(menuAgain, in: app)
        menuAgain.tap()
        app.buttons["Supprimer"].tap()
        app.buttons["Supprimer"].tap()
        XCTAssertFalse(element(app, "collection-\(collectionName)").waitForExistence(timeout: 3))
    }
}
