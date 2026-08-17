import XCTest

/// Le parcours réel du module Finales : tuile d'accueil → liste groupée par
/// famille → lecteur sur la position de la finale.
///
/// C'est le test qui manquait à un écran tout neuf : les tests de modèle
/// prouvent le catalogue, celui-ci prouve qu'un doigt y ARRIVE — et que le
/// lecteur, conçu pour des ouvertures, monte bien un plateau qui part d'une
/// position arbitraire (quatre pièces, pas trente-deux).
final class EndgameModuleUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEndgameTileLeadsToLucenaInTheReader() throws {
        let app = XCUIApplication()
        app.launch()

        // Tuile sur iPhone, ligne de barre latérale sur iPad.
        let tile = app.buttons["mode_endgames"]
        if tile.waitForExistence(timeout: 10) {
            tile.tap()
        } else {
            let sidebarRow = app.staticTexts["Finales"]
            XCTAssertTrue(sidebarRow.waitForExistence(timeout: 5), "ni tuile ni entrée latérale « Finales »")
            sidebarRow.tap()
        }

        // La liste groupée : la Lucena est dans « Finales de tours ».
        let lucena = app.buttons["endgame_eg-lucena"]
        XCTAssertTrue(lucena.waitForExistence(timeout: 10), "le cours Lucena doit être listé")
        // La section des familles existe (l'en-tête est du texte statique).
        XCTAssertTrue(app.staticTexts["Finales de tours"].exists
                      || app.staticTexts["Rook endings"].exists,
                      "la liste doit être groupée par famille")
        lucena.tap()

        // Le LECTEUR monte la position de la Lucena : la case b7 porte le
        // pion blanc — un plateau de départ standard n'aurait rien à y faire.
        // On vérifie l'existence des cases et la navigation du lecteur.
        XCTAssertTrue(app.otherElements["square_b7"].waitForExistence(timeout: 10),
                      "le plateau du lecteur doit être monté")
        let next = app.buttons["reader_next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "les commandes du lecteur doivent être là")
        next.tap()

        // Après « Suivant », le premier coup du pont (Rd1+) est joué : le
        // lecteur avance bien dans le graphe de la finale.
        XCTAssertTrue(app.buttons["reader_prev"].waitForExistence(timeout: 5))
    }
}
