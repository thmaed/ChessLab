import XCTest

/// Tournée de captures pour la revue visuelle des PETITS iPhone (SE, mini).
///
/// Pas un test de non-régression : rien n'y est affirmé. C'est un outil de
/// revue, à lancer à la demande — il dépose des PNG dans
/// `/tmp/cl-small-phone/` pour qu'on juge densité, marges et hiérarchie sur
/// l'écran le plus serré du parc (375 × 667 pt), là où une mise en page
/// pensée sur un grand iPhone devient vite chargée.
///
/// Il vit à part des tests verts habituels, comme ``AppStoreScreenshotUITests``.
final class SmallPhoneTourUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testCaptureSmallPhoneTour() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()
        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 15))
        settle()
        save(app, "01-accueil")

        // L'accueil défilé : ce qui vit sous le pli sur un écran de 667 pt.
        app.swipeUp()
        settle()
        save(app, "02-accueil-defile")
        app.swipeDown()
        settle()

        capture(app, entry: "Contre l'ordinateur", name: "03-reglages-partie")
        capture(app, entry: "Puzzles", name: "04-puzzles-filtres")
        capture(app, entry: "Ouvertures", name: "05-ouvertures-liste")
        capture(app, entry: "Finales", name: "06-finales-liste")
        capture(app, entry: "Variantes", name: "07-variantes-hub")
        capture(app, entry: "Réglages", name: "08-reglages")
        capture(app, entry: "Aide", name: "09-aide")

        // Les réglages d'une variante : même écran partagé par les six
        // variantes Fairy-Stockfish, avec en plus le pavé de règles.
        if tapEntry(app, label: "Variantes") {
            settle(1.0)
            if tapLabeled(app, "Horde") || app.buttons["variant_horde"].exists {
                if app.buttons["variant_horde"].exists, app.buttons["variant_horde"].isHittable {
                    app.buttons["variant_horde"].tap()
                }
                settle(1.2)
                save(app, "12-variante-reglages")
                app.swipeUp()
                settle(0.8)
                save(app, "13-variante-reglages-defile")
            }
            goBack(app)
            settle(0.6)
            goBack(app)
            settle(0.8)
        }

        // Une partie réelle : la densité de l'écran de jeu est le vrai juge.
        if tapEntry(app, label: "Contre l'ordinateur") {
            settle(1.0)
            if tapLabeled(app, "Commencer") {
                _ = app.otherElements["square_e2"].waitForExistence(timeout: 15)
                settle(1.2)
                save(app, "10-partie")
                app.otherElements["square_e2"].tap()
                app.otherElements["square_e4"].tap()
                settle(1.5)
                save(app, "11-partie-apres-coup")
            }
        }
    }

    // MARK: Outillage

    @MainActor
    private func settle(_ seconds: TimeInterval = 0.7) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    /// Va sur un écran depuis l'accueil, capture, revient.
    @MainActor
    private func capture(_ app: XCUIApplication, entry: String, name: String) {
        guard tapEntry(app, label: entry) else {
            print("SMALL-TOUR|\(name)|INATTEIGNABLE")
            return
        }
        settle(1.1)
        save(app, name)
        goBack(app)
        settle(0.8)
    }

    @MainActor
    private func tapEntry(_ app: XCUIApplication, label: String) -> Bool {
        for candidate in [app.buttons[label], app.cells[label], app.staticTexts[label]] {
            guard candidate.waitForExistence(timeout: 4) else { continue }
            for _ in 0..<4 {
                if candidate.isHittable {
                    candidate.tap()
                    return true
                }
                app.swipeUp()
                settle(0.4)
            }
        }
        return false
    }

    @MainActor
    @discardableResult
    private func tapLabeled(_ app: XCUIApplication, _ label: String) -> Bool {
        let button = app.buttons[label]
        guard button.waitForExistence(timeout: 6) else { return false }
        for _ in 0..<4 {
            if button.isHittable {
                button.tap()
                return true
            }
            app.swipeUp()
            settle(0.4)
        }
        return false
    }

    @MainActor
    private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists, back.isHittable { back.tap() }
    }

    @MainActor
    private func save(_ app: XCUIApplication, _ name: String) {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "inconnu"
        let dir = "/tmp/cl-small-phone/\(device.replacingOccurrences(of: " ", with: "-"))"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        print("SMALL-TOUR|\(name)|ok")
    }
}
