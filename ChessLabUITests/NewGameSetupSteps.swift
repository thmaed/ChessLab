import XCTest

/// Les gestes de l'écran « Nouvelle partie » refondu (17-18/11/2026) : l'adversaire se choisit dans une bande de
/// portraits qui défile de côté, et chaque ligne de la carte « Partie » (cadence, aveugle, départ) s'ouvre en menu.
@MainActor
enum NewGameSetupSteps {

    /// Fait défiler l'écran jusqu'à ce que `element` soit touchable.
    static func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !(element.exists && element.isHittable), tries < 6 {
            app.swipeUp()
            tries += 1
        }
    }

    /// Ouvre le menu `menuID` et y touche `item`.
    static func pick(_ item: String, inMenu menuID: String, app: XCUIApplication,
                     file: StaticString = #filePath, line: UInt = #line) {
        let menu = app.buttons[menuID]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "le menu « \(menuID) » doit exister", file: file, line: line)
        reveal(menu, in: app)
        menu.tap()
        // Le menu ouvert, l'entrée est la seule à porter ce libellé en dehors de la ligne elle-même : on prend
        // celle qui n'est PAS la ligne.
        let entries = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", item, menuID))
        let entry = entries.firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "« \(item) » doit être dans le menu « \(menuID) »",
                      file: file, line: line)
        entry.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
    }

    /// La valeur affichée par la ligne d'un menu (« 3+2 », « Tout caché »…).
    static func value(ofMenu menuID: String, app: XCUIApplication) -> String {
        app.buttons[menuID].label
    }

    /// Départ : « Saisir une FEN », puis la position tapée dans le champ.
    static func enterFEN(_ fen: String, app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        pick("Saisir une FEN", inMenu: "startMenu", app: app, file: file, line: line)
        let field = app.textFields["customFENField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "le champ FEN doit apparaître", file: file, line: line)
        reveal(field, in: app)
        field.tap()
        field.typeText(fen)
    }

    /// Choisit un adversaire dans la bande de portraits (`stockfish`, `maia`, `theo`…). La bande défile de côté,
    /// un portrait à la fois : un balayage entier en sautait.
    static func chooseOpponent(_ id: String, app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let tile = app.buttons["opponentTile_\(id)"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "le portrait « \(id) » doit exister", file: file, line: line)
        let screen = app.windows.firstMatch.frame
        func fullyVisible(_ element: XCUIElement) -> Bool {
            element.exists && element.frame.minX >= screen.minX + 8 && element.frame.maxX <= screen.maxX - 8
        }
        let all = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'opponentTile_'"))
        var tries = 0
        while !fullyVisible(tile), tries < 14 {
            let visible = all.allElementsBoundByIndex.filter(fullyVisible)
            // Vers la droite si le portrait voulu est après les portraits visibles, sinon vers la gauche.
            let goRight = tile.frame.minX > (visible.last?.frame.maxX ?? screen.midX)
            if let anchor = goRight ? visible.last : visible.first {
                let start = anchor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: goRight ? -120 : 120, dy: 0)),
                            withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            tries += 1
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }
}
