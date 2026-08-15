import XCTest

/// Le flux complet d'un répertoire personnel, tel que l'utilisateur le vit :
/// Ouvertures → « + » → coller un PGN → il apparaît dans la liste → l'ouvrir →
/// le supprimer.
///
/// Les tests unitaires couvrent la conversion et le stockage ; celui-ci couvre
/// ce qu'aucun d'eux ne voit : que la feuille est atteignable, que la liste se
/// rafraîchit toute seule après l'import (le magasin est observé), et qu'un
/// cours importé s'ouvre dans le MÊME lecteur que les cours livrés.
final class OpeningImportUITests: XCTestCase {

    /// Nom unique : le simulateur garde ses Documents entre deux exécutions.
    /// Sans accent : `typeText` les rend de façon peu fiable au clavier logiciel.
    private lazy var repertoireName = "Repertoire test \(Int(Date().timeIntervalSince1970))"

    /// Élément dont le LIBELLÉ contient le nom, quel que soit son type : la
    /// ligne de liste fusionne ses enfants (`accessibilityElement(.combine)`),
    /// donc ni `staticTexts[nom]` ni une recherche par identifiant ne la voient.
    private func element(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testImportOpenAndDeleteARepertoire() {
        let app = XCUIApplication()
        app.launch()

        let openings = app.buttons["mode_openings"]
        XCTAssertTrue(openings.waitForExistence(timeout: 10))
        openings.tap()

        // Import
        let add = app.buttons["opening_add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()

        let nameField = app.textFields["opening_import_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(repertoireName)

        let editor = app.textViews["opening_import_pgn"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        // Une variante entre parenthèses : c'est tout l'intérêt d'importer un
        // répertoire plutôt qu'une partie.
        editor.typeText("1. e4 e5 (1... c5 2. Nf3) 2. Nf3 Nc6 *")

        app.buttons["opening_import_confirm"].tap()
        capture(app, "apres-import")

        // La liste se rafraîchit sans intervention.
        let row = element(containing: repertoireName, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "le répertoire importé n'apparaît pas dans la liste")

        // Il s'ouvre dans le lecteur ordinaire.
        row.tap()
        XCTAssertTrue(app.buttons["reader_next"].waitForExistence(timeout: 10),
                      "un cours importé doit s'ouvrir dans le même lecteur que les cours livrés")
        app.navigationBars.buttons.firstMatch.tap()

        // Ménage : on supprime ce qu'on a créé, et on vérifie que ça part.
        let listRow = element(containing: repertoireName, in: app)
        XCTAssertTrue(listRow.waitForExistence(timeout: 10))
        listRow.swipeLeft()

        let delete = app.buttons["Supprimer"].firstMatch
        if delete.waitForExistence(timeout: 5) {
            delete.tap()
            // Confirmation
            let confirm = app.buttons["Supprimer"].firstMatch
            if confirm.waitForExistence(timeout: 5) { confirm.tap() }
        }
        capture(app, "apres-suppression")
        XCTAssertFalse(
            element(containing: repertoireName, in: app).waitForExistence(timeout: 3),
            "le répertoire supprimé reste affiché"
        )
    }
}
