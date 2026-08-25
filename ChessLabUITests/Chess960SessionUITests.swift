import XCTest

/// Reproduit le défaut signalé le 25/08 : « je n'arrive pas à déplacer des
/// pièces » en Chess960.
///
/// La cause n'était pas dans les règles (prouvées par perft) ni dans le view
/// model (6 tests verts sur sa mécanique) : `HomeView` construisait un
/// `Chess960PlayViewModel` INLINE dans `destination(for:)`, au lieu de le
/// confier au `SessionStore` comme le font `.activeGame` et
/// `.activeTwoPlayerGame`. Chaque coup joué mute l'état observé par
/// `HomeView`, qui réévalue son `body` — et `destination(for:)` avec lui —
/// reconstruisant un view model NEUF à chaque fois : le coup qu'on venait de
/// jouer disparaissait aussitôt sous une partie remise à zéro. Aucun test
/// unitaire ne pouvait le voir : ils appellent le view model directement,
/// en court-circuitant précisément le chemin où vivait le défaut.
final class Chess960SessionUITests: XCTestCase {

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
    private func openChess960(_ app: XCUIApplication) {
        _ = app.buttons["mode_variants"].waitForExistence(timeout: 5)
        app.buttons["mode_variants"].tap()
        _ = app.buttons["variant_chess960"].waitForExistence(timeout: 5)
        app.buttons["variant_chess960"].tap()
        _ = app.buttons["chess960_start"].waitForExistence(timeout: 5)
        app.buttons["chess960_start"].tap()
    }

    /// e2-e4 : légal depuis N'IMPORTE laquelle des 960 positions de départ —
    /// seule la rangée de base varie, les pions sont toujours en rang 2.
    @MainActor
    private func pushWhiteKingPawn(_ app: XCUIApplication) {
        _ = app.otherElements["square_e2"].waitForExistence(timeout: 10)
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
    }

    /// LE test qui aurait attrapé le défaut : jouer un coup doit faire
    /// avancer le compteur, jamais le remettre à zéro.
    ///
    /// On vise « au moins 1 », pas « exactement 1» : selon la vitesse du
    /// moteur, sa réponse peut déjà être arrivée au moment où l'on regarde
    /// (mesuré : le compteur peut valoir « 2 » dès la première lecture,
    /// coup utilisateur ET réponse moteur déjà tous les deux commis). C'est
    /// le signe que tout fonctionne, pas d'un défaut — seul un retour à
    /// « 0 » aurait trahi la remise à zéro du 25/08.
    @MainActor
    func testMovesAccumulateInsteadOfResetting() throws {
        let app = launchApp()
        openChess960(app)

        let moveCount = app.otherElements["chess960_moveCount"]
        _ = moveCount.waitForExistence(timeout: 5)
        XCTAssertEqual(moveCount.value as? String, "0")

        pushWhiteKingPawn(app)

        let deadline = Date().addingTimeInterval(5)
        var sawAtLeastOne = false
        while Date() < deadline {
            let count = Int(moveCount.value as? String ?? "") ?? 0
            if count >= 1 { sawAtLeastOne = true }
            XCTAssertFalse(count == 0 && sawAtLeastOne, "le compteur est retombé à 0 après avoir progressé : le coup a été effacé")
            if sawAtLeastOne { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(sawAtLeastOne, "le coup joué n'a jamais été enregistré")

        // Laisser tourner encore un peu : si une reconstruction tardive du
        // view model devait survenir (le défaut du 25/08, mais retardé),
        // c'est ici qu'elle ramènerait le compteur à 0.
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let final = Int(moveCount.value as? String ?? "") ?? 0
        XCTAssertGreaterThanOrEqual(final, 1, "la partie a été réinitialisée après coup")
    }
}
