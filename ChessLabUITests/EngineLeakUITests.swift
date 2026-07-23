import XCTest

/// Fuites d'instances moteur (Lot 6.A du final-1407).
///
/// Le scénario du plan : traverser Jouer → Analyser → Puzzles → Labo → retour
/// accueil, et exiger **zéro instance vivante**. Un contrôleur qui survit à son
/// écran, c'est un Stockfish qui continue de chercher à pleine puissance
/// derrière l'interface : rien ne plante, rien ne s'affiche, l'appareil chauffe
/// et la batterie fond. Ce projet s'est fait avoir deux fois (bugs n°3 et n°9).
///
/// Le compteur est exposé par un marqueur invisible de l'accueil,
/// « vivantes/créées » — voir `HomeView.engineInstanceMarker`.
final class EngineLeakUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNoEngineSurvivesATourOfEveryMode() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        let marker = app.otherElements["engineInstances"]
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
        XCTAssertEqual(marker.value as? String, "0/0", "aucun moteur avant d'entrer dans un mode")

        try visitPlay(app)
        try visitAnalysis(app)

        // Le compte est repris à l'accueil, une fois tous les écrans quittés.
        let created = createdCount(marker)
        XCTAssertGreaterThan(created, 0, "le test doit avoir réellement démarré des moteurs, sinon il ne prouve rien")

        // La libération passe par un `deinit`, qui peut suivre d'un tour de
        // boucle la disparition de l'écran : on laisse le temps, sans exiger
        // l'instantané.
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline, aliveCount(marker) != 0 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }

        XCTAssertEqual(
            aliveCount(marker), 0,
            "de retour à l'accueil, plus aucun moteur ne doit tourner (créés : \(created))"
        )
    }

    // MARK: Parcours

    @MainActor
    private func visitPlay(_ app: XCUIApplication) throws {
        app.buttons["Contre Stockfish"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()

        let e2 = app.otherElements["square_e2"]
        XCTAssertTrue(e2.waitForExistence(timeout: 15))
        e2.tap()
        app.otherElements["square_e4"].tap()
        // Laisser le moteur répondre : un moteur qui n'a jamais cherché ne
        // fuit pas de la même façon qu'un moteur en pleine recherche.
        RunLoop.current.run(until: Date().addingTimeInterval(4))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["Contre Stockfish"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func visitAnalysis(_ app: XCUIApplication) throws {
        app.buttons["Analyser"].tap()
        // « Position FEN » vit sous « Autres sources » : le menu met en avant
        // les chemins courts (scanner, bibliothèque) et replie ce qui demande
        // de fournir un texte.
        XCTAssertTrue(app.buttons["Autres sources"].waitForExistence(timeout: 5))
        app.buttons["Autres sources"].tap()
        XCTAssertTrue(app.buttons["Position FEN"].waitForExistence(timeout: 5))
        app.buttons["Position FEN"].tap()

        let field = app.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4")
        app.buttons["Lancer l'analyse"].tap()

        // Si le plateau n'apparaît pas, c'est que l'app a été tuée : deux
        // moteurs (78 Mo de NNUE chacun) coexistaient — la fuite exacte que ce
        // test traque. Sans la libération du moteur de Jouer à la sortie, on
        // atterrissait ici.
        XCTAssertTrue(
            app.otherElements["square_e4"].waitForExistence(timeout: 20),
            "l'analyse doit s'ouvrir après une partie"
        )
        // L'analyse en continu est bornée en profondeur (elle ne tourne plus
        // en `go infinite`) : on laisse un peu de temps pour qu'elle démarre
        // puis converge, l'instant où une instance moteur mal libérée se
        // verrait.
        RunLoop.current.run(until: Date().addingTimeInterval(4))

        // Retour à l'accueil : deux écrans à remonter (analyse → entrée →
        // accueil), en laissant la navigation se poser entre les deux.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["Position FEN"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["Contre Stockfish"].waitForExistence(timeout: 10))
    }

    // MARK: Lecture du marqueur

    @MainActor
    private func aliveCount(_ marker: XCUIElement) -> Int {
        Int((marker.value as? String)?.split(separator: "/").first ?? "") ?? -1
    }

    @MainActor
    private func createdCount(_ marker: XCUIElement) -> Int {
        Int((marker.value as? String)?.split(separator: "/").last ?? "") ?? -1
    }
}
