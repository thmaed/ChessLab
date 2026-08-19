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
        // Le Laboratoire manquait au parcours — alors que l'en-tête de ce
        // fichier le documente depuis toujours. C'est pourtant le SEUL écran
        // qui emprunte `computeBestMove`, donc `ensureMoveReader`, donc le
        // lecteur permanent qui retenait le contrôleur à vie : la fuite tenait
        // debout précisément parce que le test qui devait l'attraper ne
        // passait pas par là.
        try visitLaboratory(app)
        // L'entraînement libre des finales (19/08) est le petit dernier des
        // écrans à moteur : même exigence que les autres — son arbitre ne
        // doit pas survivre au retour à l'accueil.
        try visitFreeEndgameTraining(app)

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
    private func visitFreeEndgameTraining(_ app: XCUIApplication) throws {
        app.buttons["mode_endgames"].tap()
        let opposition = app.buttons["endgame_eg-opposition"]
        XCTAssertTrue(opposition.waitForExistence(timeout: 10))
        opposition.tap()
        let trainMenu = app.buttons["reader_trainMenu"]
        XCTAssertTrue(trainMenu.waitForExistence(timeout: 5))
        trainMenu.tap()
        let free = app.buttons["Entraînement libre"]
        XCTAssertTrue(free.waitForExistence(timeout: 5))
        free.tap()
        // Le plateau du mode libre monte et l'arbitre (un moteur plein pot)
        // démarre sa première évaluation : on le laisse réellement chercher.
        XCTAssertTrue(app.otherElements["square_a1"].waitForExistence(timeout: 15))
        RunLoop.current.run(until: Date().addingTimeInterval(4))
        // Retour : écran libre → lecteur → liste → accueil.
        app.navigationBars.buttons.firstMatch.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        app.navigationBars.buttons.firstMatch.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["Contre l'ordinateur"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func visitPlay(_ app: XCUIApplication) throws {
        app.buttons["Contre l'ordinateur"].tap()
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
        XCTAssertTrue(app.buttons["Contre l'ordinateur"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func visitAnalysis(_ app: XCUIApplication) throws {
        app.buttons["Analyser"].tap()
        // « Analyser PGN / FEN » vit sous « Autres sources » : le menu met en avant
        // les chemins courts (scanner, bibliothèque) et replie ce qui demande
        // de fournir un texte.
        XCTAssertTrue(app.buttons["Autres sources"].waitForExistence(timeout: 5))
        app.buttons["Autres sources"].tap()
        XCTAssertTrue(app.buttons["Analyser PGN / FEN"].waitForExistence(timeout: 5))
        app.buttons["Analyser PGN / FEN"].tap()

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
        XCTAssertTrue(app.buttons["Analyser PGN / FEN"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["Contre l'ordinateur"].waitForExistence(timeout: 10))
    }

    /// Laboratoire : une série d'UNE partie à réflexion courte suffit — ce
    /// qu'on traque n'est pas la durée mais le fait qu'un `computeBestMove` ait
    /// eu lieu, donc qu'un lecteur de coups ait été installé.
    @MainActor
    private func visitLaboratory(_ app: XCUIApplication) throws {
        guard tapEntry(app, "Laboratoire") else {
            XCTFail("le Laboratoire doit être atteignable depuis l'accueil")
            return
        }
        let start = app.buttons["Lancer"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "l'écran de réglages du Labo doit s'ouvrir")
        start.tap()

        // Laisser la série démarrer et jouer quelques coups : un moteur qui n'a
        // jamais cherché ne fuit pas de la même façon.
        RunLoop.current.run(until: Date().addingTimeInterval(8))

        // Deux écrans à remonter : la série est empilée SUR les réglages du
        // Labo (comme l'analyse l'est sur son écran d'entrée).
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(
            app.buttons["Lancer"].waitForExistence(timeout: 15),
            "retour aux réglages du Laboratoire"
        )
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(
            app.buttons["Contre l'ordinateur"].waitForExistence(timeout: 15),
            "retour à l'accueil après le Laboratoire"
        )
    }

    @MainActor
    private func tapEntry(_ app: XCUIApplication, _ label: String) -> Bool {
        for candidate in [app.buttons[label], app.cells[label], app.staticTexts[label]] {
            guard candidate.waitForExistence(timeout: 5) else { continue }
            for _ in 0..<4 {
                if candidate.isHittable { candidate.tap(); return true }
                app.swipeUp()
                RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            }
        }
        return false
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
