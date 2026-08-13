import XCTest

/// Lot 1 — la partie en cours doit SURVIVRE à la bascule de classe de taille.
///
/// Avant correction, cette bascule (rotation d'un iPhone Plus/Pro Max, Split
/// View sur iPad) détruisait le sous-arbre de `HomeView`, donc le view model
/// de la partie ; `path` survivant, la route était ré-instanciée et un
/// `PlayViewModel` neuf naissait — dont l'`init` **effaçait
/// l'autosauvegarde**. Échiquier remis à la position initiale, et « Reprendre
/// la partie en cours » définitivement perdu.
///
/// La bascule est provoquée par le bouton `toggleSkeleton` (`-skeletonToggle`,
/// Debug seulement) : les déclencheurs réels ne s'automatisent pas — voir
/// ``SkeletonOverride`` pour la limite de ce procédé.
final class SkeletonSwitchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-skeletonToggle"]
        app.launch()
        return app
    }

    /// Le cœur du Lot 1 : jouer, basculer, et retrouver sa partie.
    @MainActor
    func testGameSurvivesSizeClassSwitch() throws {
        let app = launchApp()
        try openVsEngineGame(in: app)

        // Un coup joué, et la réponse du moteur : la partie a un passé qu'on
        // pourra reconnaître après la bascule.
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()

        let moveCount = app.otherElements["moveCount"]
        XCTAssertTrue(moveCount.waitForExistence(timeout: 10))
        XCTAssertTrue(
            waitForValue(moveCount, "2", timeout: 25),
            "le moteur doit avoir répondu avant la bascule (valeur lue : \(moveCount.value ?? "nil"))"
        )

        let toggle = app.buttons["toggleSkeleton"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "le bouton de bascule doit être présent")
        toggle.tap()

        // 1) L'échiquier est toujours celui de la partie : deux demi-coups.
        XCTAssertTrue(
            waitForValue(moveCount, "2", timeout: 10),
            "la partie doit survivre à la bascule (valeur lue : \(moveCount.value ?? "nil"))"
        )

        // 2) Et re-basculer ne la perd pas non plus.
        toggle.tap()
        XCTAssertTrue(
            waitForValue(moveCount, "2", timeout: 10),
            "la partie doit survivre au retour à l'ossature d'origine"
        )
    }

    /// L'autre moitié du Lot 1 : l'autosauvegarde ne doit pas avoir été
    /// effacée en route. On le vérifie par l'interface, là où l'utilisateur le
    /// constate — la bannière « Reprendre la partie en cours ».
    @MainActor
    func testAutosaveSurvivesSizeClassSwitch() throws {
        let app = launchApp()
        try openVsEngineGame(in: app)

        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        let moveCount = app.otherElements["moveCount"]
        XCTAssertTrue(moveCount.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForValue(moveCount, "2", timeout: 25))

        // Aller-retour complet : c'est le passage par l'autre ossature qui
        // détruisait la sauvegarde. On revient ensuite à l'ossature d'origine
        // pour vérifier là où l'utilisateur regarde — la bannière de reprise
        // de l'accueil iPhone. (En ossature « regular », la reprise vit dans
        // la barre latérale, dont l'affichage dépend de la largeur de fenêtre :
        // ce serait tester le chrome du système, pas la sauvegarde.)
        app.buttons["toggleSkeleton"].tap()
        XCTAssertTrue(waitForValue(moveCount, "2", timeout: 10))
        app.buttons["toggleSkeleton"].tap()
        XCTAssertTrue(waitForValue(moveCount, "2", timeout: 10))

        // Retour à l'accueil par le bouton système, comme le ferait un joueur.
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let resume = app.descendants(matching: .any).matching(identifier: "resumeGame").firstMatch
        XCTAssertTrue(
            resume.waitForExistence(timeout: 10),
            "« Reprendre la partie en cours » doit toujours être proposé après la bascule"
        )
    }

    /// Point connexe du Lot 1 : `sidebarSelection` et `path` sont deux
    /// représentations de la même navigation, et la bascule ne les réconcilie
    /// pas. Ce test ne juge pas — il **constate** ce que devient l'écran, pour
    /// documenter le symptôme réel au lieu de le déduire du code.
    @MainActor
    func testReportSidebarAndPathCoherence() throws {
        let app = launchApp()

        // Depuis la grille iPhone : la file de puzzles est empilée sur `path`,
        // sans que `sidebarSelection` soit touché.
        let puzzles = app.buttons["Puzzles"]
        XCTAssertTrue(puzzles.waitForExistence(timeout: 15))
        puzzles.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        print("COHERENCE|avant|titre=\(navigationTitle(app))")

        app.buttons["toggleSkeleton"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        print("COHERENCE|après-bascule|titre=\(navigationTitle(app))")

        // Ce que donne « retour » : c'est là que l'audit attend un écran
        // jamais demandé.
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists, back.isHittable {
            back.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
            print("COHERENCE|après-retour|titre=\(navigationTitle(app))")
        } else {
            print("COHERENCE|après-retour|aucun bouton retour")
        }
    }

    @MainActor
    private func navigationTitle(_ app: XCUIApplication) -> String {
        let bars = app.navigationBars.allElementsBoundByAccessibilityElement
        let titles = bars.map(\.identifier).filter { !$0.isEmpty }
        return titles.isEmpty ? "(aucun)" : titles.joined(separator: "/")
    }

    // MARK: Outils

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ expected: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.value as? String == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return element.value as? String == expected
    }

    @MainActor
    private func openVsEngineGame(in app: XCUIApplication) throws {
        let button = app.buttons["Contre l'ordinateur"]
        if button.waitForExistence(timeout: 15) {
            button.tap()
        } else if app.staticTexts["Contre l'ordinateur"].waitForExistence(timeout: 5) {
            app.staticTexts["Contre l'ordinateur"].tap()
        } else {
            XCTFail("Point d'entrée « Contre l'ordinateur » introuvable")
            return
        }
        let start = app.buttons["Commencer"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 25))
    }
}
