import XCTest

/// Le menu d'actions d'un répertoire personnel est-il VISIBLE, et mène-t-il
/// bien à l'éditeur d'arbre ?
///
/// L'utilisateur ne trouvait pas l'éditeur. Ce test répond sur pièces plutôt
/// que par une description du chemin.
final class OpeningEditorAccessUITests: XCTestCase {

    @MainActor
    func testActionsMenuLeadsToEditor() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-seedUserOpening"]
        app.launch()

        for candidate in [app.buttons["Ouvertures"], app.cells["Ouvertures"], app.staticTexts["Ouvertures"]] {
            if candidate.waitForExistence(timeout: 6) { candidate.tap(); break }
        }
        XCTAssertTrue(app.staticTexts["Répertoire de test"].waitForExistence(timeout: 10),
                      "le répertoire personnel de test doit apparaître")

        let listShot = XCTAttachment(screenshot: app.screenshot())
        listShot.name = "liste-ouvertures"
        listShot.lifetime = .keepAlways
        add(listShot)

        // Le menu « … » doit exister SANS balayage.
        let menus = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'openingActions_'"))
        XCTAssertGreaterThan(menus.count, 0, "le menu d'actions doit être visible sans balayer")
        menus.element(boundBy: 0).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))

        let menuShot = XCTAttachment(screenshot: app.screenshot())
        menuShot.name = "menu-actions"
        menuShot.lifetime = .keepAlways
        add(menuShot)

        let edit = app.buttons["Modifier le répertoire"]
        XCTAssertTrue(edit.waitForExistence(timeout: 4), "« Modifier le répertoire » doit être proposé")
        edit.tap()

        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 15),
                      "l'éditeur doit afficher un échiquier")
        let editorShot = XCTAttachment(screenshot: app.screenshot())
        editorShot.name = "editeur-arbre"
        editorShot.lifetime = .keepAlways
        add(editorShot)
    }
}
