import XCTest

final class ChessLabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Lance l'app avec des réglages de partie vierges, pour que chaque
    /// test soit indépendant des réglages mémorisés par les précédents.
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()
        return app
    }

    @MainActor
    func testAppLaunches() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 5))
    }

    /// Reproduit le bug signalé : jouer un coup pendant que l'indice
    /// analyse en continu ne doit pas bloquer la réponse du moteur.
    @MainActor
    func testMoveWhileHintAnalyzingDoesNotDeadlock() throws {
        let app = launchApp()
        _ = app.buttons["Contre Stockfish"].waitForExistence(timeout: 5)
        app.buttons["Contre Stockfish"].tap()
        _ = app.buttons["Commencer"].waitForExistence(timeout: 5)
        app.buttons["Commencer"].tap()

        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()

        let moveCountMarker = app.otherElements["moveCount"]
        let firstReplyDeadline = Date().addingTimeInterval(15)
        while Date() < firstReplyDeadline, moveCountMarker.value as? String != "2" {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertEqual(moveCountMarker.value as? String, "2", "Le moteur devrait avoir répondu une première fois")

        XCTAssertTrue(app.buttons["Indice"].waitForExistence(timeout: 3))
        app.buttons["Indice"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))

        app.otherElements["square_g1"].tap()
        app.otherElements["square_f3"].tap()

        let secondReplyDeadline = Date().addingTimeInterval(15)
        while Date() < secondReplyDeadline, moveCountMarker.value as? String != "4" {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertEqual(moveCountMarker.value as? String, "4", "Le moteur devrait répondre même si l'indice tournait au moment du coup")
    }

    /// Vérifie le parcours central de l'étape 1 : accueil → nouvelle partie
    /// → un coup joué au tap-tap → le moteur répond.
    /// Les réglages choisis (cadence, force, aides…) doivent être
    /// préremplis à la partie suivante, y compris après relance de l'app.
    @MainActor
    func testSettingsArePersistedBetweenGames() throws {
        var app = launchApp()
        _ = app.buttons["Contre Stockfish"].waitForExistence(timeout: 5)
        app.buttons["Contre Stockfish"].tap()
        _ = app.buttons["Commencer"].waitForExistence(timeout: 5)
        // La cadence se choisit en deux temps depuis le 18/07/2026 : la
        // famille, puis la cadence dans cette famille.
        app.buttons["Blitz"].tap()
        XCTAssertTrue(app.buttons["3+2"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["3+2"].isSelected, "Réglages vierges : 3+2 ne doit pas être présélectionné")
        app.buttons["3+2"].tap()
        app.buttons["Commencer"].tap()
        _ = app.otherElements["square_e2"].waitForExistence(timeout: 10)

        // Relance SANS l'argument de réinitialisation.
        app = XCUIApplication()
        app.launch()
        _ = app.buttons["Contre Stockfish"].waitForExistence(timeout: 5)
        app.buttons["Contre Stockfish"].tap()
        _ = app.buttons["Commencer"].waitForExistence(timeout: 5)
        XCTAssertTrue(app.buttons["3+2"].isSelected, "La cadence 3+2 choisie précédemment doit être mémorisée")
    }

    @MainActor
    func testPlayAGameMove() throws {
        let app = launchApp()

        let vsEngineCard = app.buttons["Contre Stockfish"]
        XCTAssertTrue(vsEngineCard.waitForExistence(timeout: 5))
        vsEngineCard.tap()

        let startButton = app.buttons["Commencer"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let e2 = app.otherElements["square_e2"]
        XCTAssertTrue(e2.waitForExistence(timeout: 10))
        e2.tap()

        let e4 = app.otherElements["square_e4"]
        XCTAssertTrue(e4.waitForExistence(timeout: 5))
        e4.tap()

        // Le pion blanc doit apparaître en e4 (coup validé et joué).
        var e4HasPawn = false
        let pawnDeadline = Date().addingTimeInterval(8)
        while Date() < pawnDeadline {
            if e4.label.lowercased().contains("pion blanc") {
                e4HasPawn = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(e4HasPawn, "Le pion blanc devrait être en e4 après le coup (label: \(e4.label))")

        // Le moteur (noirs) doit répondre dans la foulée. Marqueur
        // indépendant du layout iPhone/iPad (bouton "Coups joués" en
        // compact, panneau permanent en régulier).
        let moveCountMarker = app.otherElements["moveCount"]
        XCTAssertTrue(moveCountMarker.waitForExistence(timeout: 15))

        let deadline = Date().addingTimeInterval(30)
        var sawTwoMoves = false
        while Date() < deadline {
            if moveCountMarker.value as? String == "2" {
                sawTwoMoves = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertTrue(sawTwoMoves, "Le moteur devrait avoir joué un coup en réponse (value: \(moveCountMarker.value ?? "nil"))")
    }

    @MainActor
    func testLayoutScreenshots() throws {
        let app = launchApp()
        _ = app.buttons["Contre Stockfish"].waitForExistence(timeout: 5)
        app.buttons["Contre Stockfish"].tap()
        _ = app.buttons["Commencer"].waitForExistence(timeout: 5)

        // Cadence "3+0" (blitz) + barre d'évaluation, pour vérifier
        // pendules et barre d'éval à l'écran. Famille d'abord.
        app.buttons["Blitz"].tap()
        _ = app.buttons["3+0"].waitForExistence(timeout: 5)
        app.buttons["3+0"].tap()
        app.switches.matching(NSPredicate(format: "label CONTAINS 'valuation'")).firstMatch.tap()
        attach(app, "setup")
        app.buttons["Commencer"].tap()

        let e2 = app.otherElements["square_e2"]
        XCTAssertTrue(e2.waitForExistence(timeout: 10))
        e2.tap()
        app.otherElements["square_e4"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        attach(app, "midgame-clocks-evalbar")

        // Attendre que le moteur ait répondu (redevient le trait de
        // l'utilisateur) avant de tester l'indice.
        let moveCountMarker = app.otherElements["moveCount"]
        let engineDeadline = Date().addingTimeInterval(15)
        while Date() < engineDeadline, moveCountMarker.value as? String != "2" {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }

        // Indice en continu : laisser tourner un peu puis capturer.
        if app.buttons["Indice"].waitForExistence(timeout: 3) {
            app.buttons["Indice"].tap()
            RunLoop.current.run(until: Date().addingTimeInterval(2.5))
            attach(app, "hint-continuous")
        }

        // Confirmation d'abandon.
        if app.buttons["Abandonner"].waitForExistence(timeout: 3) {
            app.buttons["Abandonner"].tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            attach(app, "resign-confirmation")
        }
    }

    /// `@MainActor` : `XCUIScreen.main` et `screenshot()` y sont isolés, et
    /// les appeler depuis un contexte non isolé n'était toléré que par
    /// indulgence du compilateur.
    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
