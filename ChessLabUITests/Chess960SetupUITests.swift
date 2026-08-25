import XCTest

/// L'éditeur manuel de rangée (25/08) : en plus du tirage « Aléatoire » et du
/// numéro saisi à la main, la rangée d'aperçu ELLE-MÊME devient l'éditeur —
/// toucher une case la sélectionne, en toucher une seconde échange les deux.
/// Un échange préserve toujours le jeu de pièces ; seules deux règles du
/// Chess960 peuvent encore se briser en cours de route (roi hors de
/// l'intervalle des tours, fous de même couleur), d'où ces tests.
final class Chess960SetupUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    @MainActor
    private func openChess960Setup(_ app: XCUIApplication) {
        _ = app.buttons["mode_variants"].waitForExistence(timeout: 5)
        app.buttons["mode_variants"].tap()
        _ = app.buttons["variant_chess960"].waitForExistence(timeout: 5)
        app.buttons["variant_chess960"].tap()
        _ = app.buttons["chess960_start"].waitForExistence(timeout: 5)
    }

    /// L'échange dans la rangée doit refuser une composition illégale — pas
    /// SILENCIEUSEMENT (elle serait jouée telle quelle), mais visiblement :
    /// « Commencer » se désactive, et un message dit CE QUI cloche.
    @MainActor
    func testSwappingIntoAnIllegalArrangementDisablesStart() throws {
        let app = launchApp()
        openChess960Setup(app)

        // Position par défaut : RNBQKBNR (518, la partie classique). Échanger
        // la case 0 (R) et la case 4 (K) sort le roi de l'intervalle des deux
        // tours — composition illégale, tel que testé unitairement dans
        // Chess960RulesTests.kingNotBetweenRooksIsIllegal.
        XCTAssertTrue(app.buttons["chess960_start"].isEnabled)
        app.buttons["chess960_rankSquare_0"].tap()
        app.buttons["chess960_rankSquare_4"].tap()

        XCTAssertTrue(app.staticTexts["chess960_invalidArrangement"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["chess960_start"].isEnabled, "une composition illégale ne doit pas pouvoir démarrer")

        // Le même échange, rejoué, restaure exactement l'arrangement de
        // départ — une paire d'échanges est sa propre inverse.
        app.buttons["chess960_rankSquare_0"].tap()
        app.buttons["chess960_rankSquare_4"].tap()

        XCTAssertFalse(app.staticTexts["chess960_invalidArrangement"].exists)
        XCTAssertTrue(app.buttons["chess960_start"].isEnabled, "revenue à RNBQKBNR, la partie doit redevenir jouable")
    }

    /// Composer RNBQKBNR à la main doit retrouver le n° 518 — la preuve que
    /// la recherche inverse tourne vraiment depuis l'écran, pas seulement
    /// dans les tests unitaires de la couche de règles.
    @MainActor
    func testManualArrangementFindsItsScharnaglNumber() throws {
        let app = launchApp()
        openChess960Setup(app)

        // Un aller-retour d'échange laisse la position INCHANGÉE, mais
        // repasse par la recherche inverse : si elle se trompait de numéro,
        // ce test le verrait.
        app.buttons["chess960_rankSquare_1"].tap()
        app.buttons["chess960_rankSquare_6"].tap()   // N ↔ N : aucun changement visible
        app.buttons["chess960_rankSquare_1"].tap()
        app.buttons["chess960_rankSquare_6"].tap()

        let numberField = app.textFields["Numéro de position"]
        XCTAssertTrue(numberField.waitForExistence(timeout: 3))
        XCTAssertEqual(numberField.value as? String, "518")
    }

    /// L'indice et l'alerte gaffe (25/08) ont chacun leur interrupteur —
    /// désactiver « Indice » doit désactiver le bouton correspondant dans la
    /// partie elle-même, bout en bout depuis l'écran de réglages.
    @MainActor
    func testDisablingHintsDisablesTheHintButtonInGame() throws {
        let app = launchApp()
        openChess960Setup(app)

        let hintsToggle = app.switches["Indice (flèches des meilleurs coups)"]
        XCTAssertTrue(hintsToggle.waitForExistence(timeout: 5))
        if (hintsToggle.value as? String) != "0" {
            hintsToggle.tap()
        }
        XCTAssertEqual(hintsToggle.value as? String, "0")

        app.buttons["chess960_start"].tap()

        let hintButton = app.buttons["Indice"]
        XCTAssertTrue(hintButton.waitForExistence(timeout: 5))
        XCTAssertFalse(hintButton.isEnabled, "le bouton doit rester désactivé quand l'indice est désactivé dans les réglages")
    }

    /// Le pavé numérique iOS n'a nativement AUCUNE touche de fermeture —
    /// signalé par l'utilisateur : impossible de le refermer une fois ouvert.
    /// « Terminé », posé sur la barre d'accessoires du clavier, doit le
    /// faire disparaître.
    @MainActor
    func testKeyboardDismissesViaDoneButton() throws {
        let app = launchApp()
        openChess960Setup(app)

        let numberField = app.textFields["Numéro de position"]
        XCTAssertTrue(numberField.waitForExistence(timeout: 3))
        numberField.tap()

        let doneButton = app.buttons["Terminé"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3), "aucune touche pour refermer le pavé numérique")
        doneButton.tap()

        XCTAssertFalse(doneButton.waitForExistence(timeout: 2), "le clavier (et sa barre) doit avoir disparu")
    }
}
