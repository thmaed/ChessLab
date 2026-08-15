import XCTest

/// Inventaire des débordements de largeur (Lot 3), à la taille de texte par
/// défaut **et** en AX5.
///
/// Diagnostic, pas verdict : chaque écran est visité et ce qui dépasse est
/// imprimé (`OVERFLOW|…`). Le Lot 0 a montré qu'il ne fallait pas se fier aux
/// estimations — plusieurs « débordements » calculés au papier n'existent pas
/// à l'exécution, et l'accueil en cachait un que personne n'avait prévu.
///
/// Les tailles d'accessibilité se forcent au lancement, il n'existe pas d'API
/// pour en changer en cours de route.
final class DynamicTypeOverflowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    private func launchApp(contentSize: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        return app
    }

    @MainActor
    func testReportOverflowsAtDefaultSize() throws {
        try sweep(contentSize: nil, tag: "L")
    }

    /// AX3 en plus d'AX5 : la matrice du prompt l'exige sur iPhone SE, et
    /// c'est la taille où beaucoup de gabarits craquent en premier — AX5 est
    /// si grand que certaines vues basculent sur d'autres dispositions.
    @MainActor
    func testReportOverflowsAtAX3() throws {
        try sweep(contentSize: "UICTContentSizeCategoryAccessibilityL", tag: "AX3")
    }

    @MainActor
    func testReportOverflowsAtAX5() throws {
        try sweep(contentSize: "UICTContentSizeCategoryAccessibilityXXXL", tag: "AX5")
    }

    /// Parcourt les écrans d'entrée atteignables sans partie en cours — ceux
    /// où vivent les rangées sur-remplies et les groupes de puces du
    /// diagnostic 3.4/3.5.
    @MainActor
    private func sweep(contentSize: String?, tag: String) throws {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "?"
        let app = launchApp(contentSize: contentSize)
        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 15))
        report(app, screen: "accueil", tag: tag, device: device)

        // Chaque écran est visité depuis l'accueil, puis quitté par le bouton
        // retour — plus robuste qu'un enchaînement, un écran manquant
        // n'emportant pas les suivants.
        for (label, screen) in [
            ("Contre l'ordinateur", "nouvelle-partie"),
            ("Deux joueurs", "deux-joueurs"),
            ("Puzzles", "puzzles"),
            ("Analyser", "analyser"),
            ("Laboratoire", "laboratoire"),
            // Ajouté le 15/08 : c'est le seul écran qui affiche un nombre en
            // TRÈS grand (le taux de réussite, 40 pt). Depuis qu'il suit
            // Dynamic Type, il doit être balayé comme les autres.
            ("Progression", "progression"),
        ] {
            guard tapEntry(app, label: label) else {
                print("OVERFLOW|\(device)|\(tag)|\(screen)|ÉCRAN INATTEIGNABLE")
                continue
            }
            RunLoop.current.run(until: Date().addingTimeInterval(1.2))
            report(app, screen: screen, tag: tag, device: device)
            goBack(app)
        }
    }

    /// En AX5, les tuiles de mode passent sous le pli : `isHittable` est alors
    /// faux tant qu'on n'a pas défilé. Sans ce défilement, le balayage
    /// concluait « écran inatteignable » — un défaut du test, pas de l'app.
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
                RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            }
        }
        return false
    }

    @MainActor
    private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists, back.isHittable { back.tap() }
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }

    @MainActor
    private func report(_ app: XCUIApplication, screen: String, tag: String, device: String) {
        let overflows = LayoutProbe.horizontalOverflows(in: app)
        if overflows.isEmpty {
            print("OVERFLOW|\(device)|\(tag)|\(screen)|aucun")
            return
        }
        for overflow in overflows.prefix(8) {
            print("OVERFLOW|\(device)|\(tag)|\(screen)|\(overflow)")
        }
    }
}
