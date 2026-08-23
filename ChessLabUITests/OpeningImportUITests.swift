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

        // GRILLE sur iPhone, BARRE LATÉRALE sur iPad : le module a deux
        // points d'entrée, et ce test n'en connaissait qu'un — il échouait
        // donc sur iPad depuis toujours, faute d'y trouver une tuile.
        let tile = app.buttons["mode_openings"]
        if tile.waitForExistence(timeout: 10) {
            tile.tap()
        } else {
            let sidebar = app.staticTexts["sidebar_openings"]
            XCTAssertTrue(sidebar.waitForExistence(timeout: 10),
                          "aucun point d'entrée vers les Ouvertures")
            sidebar.tap()
        }

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

        // Il s'ouvre dans le lecteur ordinaire — index des lignes d'abord,
        // qui est l'écran d'entrée du module.
        row.tap()
        let closeIndex = app.buttons["openingIndex_close"]
        XCTAssertTrue(closeIndex.waitForExistence(timeout: 10),
                      "un cours importé doit ouvrir le même index que les cours livrés")
        closeIndex.tap()
        XCTAssertTrue(app.buttons["reader_next"].waitForExistence(timeout: 10),
                      "un cours importé doit s'ouvrir dans le même lecteur que les cours livrés")
        app.navigationBars.buttons.firstMatch.tap()

        // Ménage : on supprime ce qu'on a créé, et on vérifie que ça part.
        //
        // Par le MENU d'actions, plus par balayage : depuis le 23/08 la liste
        // n'est plus une `List` — le menu « … » est visible en permanence,
        // ce que le code de l'ancien écran jugeait déjà préférable (« une
        // fonctionnalité qui demande de deviner qu'il faut balayer une ligne
        // n'existe pas vraiment »).
        XCTAssertTrue(element(containing: repertoireName, in: app).waitForExistence(timeout: 10))

        // On vide TOUS les répertoires personnels, pas seulement le nôtre : le
        // menu porte l'identifiant du cours, pas son nom, et une exécution
        // précédente interrompue peut en avoir laissé. Sans ce ménage, on
        // supprimerait un résidu en croyant supprimer le sien — et l'assertion
        // finale mentirait dans les deux sens.
        let userMenus = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'openingActions_user-'")
        )
        XCTAssertGreaterThan(userMenus.count, 0, "le menu d'actions du répertoire est introuvable")
        var guardCount = 0
        while userMenus.count > 0 && guardCount < 10 {
            guardCount += 1
            userMenus.firstMatch.tap()
            let delete = app.buttons["Supprimer"].firstMatch
            guard delete.waitForExistence(timeout: 5) else { break }
            delete.tap()
            // Confirmation — le dialogue reprend le même libellé.
            let confirm = app.buttons["Supprimer"].firstMatch
            if confirm.waitForExistence(timeout: 5) { confirm.tap() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        }
        capture(app, "apres-suppression")
        XCTAssertFalse(
            element(containing: repertoireName, in: app).waitForExistence(timeout: 3),
            "le répertoire supprimé reste affiché"
        )
    }
}
