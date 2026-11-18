import XCTest

/// Visualisation de bout en bout (18/11/2026) : la tuile de l'accueil, les deux marches, une série de dix
/// questions répondues au hasard, le bilan et ses erreurs à revoir ; puis le chrono par question qui tranche seul.
/// Pendant Android : `VisualizationTest` (instrumenté).
///
/// - important: PAS de `-resetPlaySettings` : le test doit pouvoir tourner sur un iPhone réel.
@MainActor
final class VisualizationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pause(_ s: Double) { RunLoop.current.run(until: Date().addingTimeInterval(s)) }

    /// Les réglages en pastilles (18/11/2026) : 0 = la première (« 10 questions », « Sans »).
    private func tapPill(_ id: String, _ app: XCUIApplication) {
        let pill = app.buttons[id]
        XCTAssertTrue(pill.waitForExistence(timeout: 5), id)
        NewGameSetupSteps.reveal(pill, in: app)
        pill.tap()
        XCTAssertTrue(pill.isSelected, id)
    }

    /// Répond à la question affichée : le premier choix, ou le centre du plateau pour « Touchez… ».
    private func answerCurrent(_ app: XCUIApplication) {
        // Le fondu entre deux questions laisse un instant les boutons, DÉSACTIVÉS, de la précédente : on attend
        // qu'il finisse, et on ne vise qu'un bouton actif.
        pause(0.5)
        let choice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'visualizationChoice_' AND enabled == true")).firstMatch
        if choice.waitForExistence(timeout: 2), choice.isHittable {
            choice.tap()
        } else {
            let board = app.descendants(matching: .any)["visualizationBoard"].firstMatch
            XCTAssertTrue(board.exists, "ni choix ni plateau")
            board.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.45)).tap()
        }
    }

    func testASeriesFromTheHomeTileToTheSummary() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-AppleLanguages", "(fr)"]
        app.launch()

        // La grille de l'accueil est paresseuse : la tuile n'existe qu'en approchant.
        XCTAssertTrue(app.buttons["mode_play"].waitForExistence(timeout: 20))
        let tile = app.buttons["mode_visualization"]
        var tries = 0
        while !(tile.exists && tile.isHittable), tries < 8 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(tile.exists, "la tuile Visualisation doit être à l'accueil")
        tile.tap()

        let start = app.buttons["visualizationStart"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        // Les deux marches, une série de dix, sans chrono.
        let lines = app.buttons["visualizationStep_lines"]
        XCTAssertTrue(lines.exists)
        if !lines.isSelected { lines.tap() }
        XCTAssertTrue(lines.isSelected)
        tapPill("visualizationLength_0", app)
        tapPill("visualizationTimer_0", app)
        snapshot(app, "1-reglages")
        start.tap()

        let prompt = app.staticTexts["visualizationPrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["visualizationProgress"].label, "1 / 10")
        snapshot(app, "2-question")
        let progress = app.staticTexts["visualizationProgress"]
        let score = app.staticTexts["visualizationSummaryScore"]
        for index in 0..<10 {
            answerCurrent(app)
            // Un juste ne reste affiché qu'un instant (0,45 s) : on attend la question suivante, ou le bilan.
            let next = "\(index + 2) / 10"
            let deadline = Date().addingTimeInterval(10)
            while Date() < deadline, !score.exists, !(progress.exists && progress.label == next) { pause(0.2) }
            if !(score.exists || progress.label == next) { snapshot(app, "echec-\(index + 1)") }
            XCTAssertTrue(score.exists || progress.label == next, "la série avance après la réponse \(index + 1)")
        }

        XCTAssertTrue(score.waitForExistence(timeout: 5), "le bilan après dix réponses")
        XCTAssertTrue(score.label.hasSuffix("/ 10"), "dix questions posées : \(score.label)")
        snapshot(app, "3-bilan")

        // Retour aux réglages : les ratés éventuels sont annoncés.
        let correct = Int(score.label.split(separator: " ").first ?? "") ?? 10
        app.buttons["visualizationSettings"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        if correct < 10 {
            XCTAssertTrue(app.descendants(matching: .any)["visualizationReview"].firstMatch.exists,
                          "les ratés doivent être annoncés")
        }

        // Chrono par question : sans réponse, le temps tranche.
        tapPill("visualizationTimer_1", app)
        start.tap()
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        let timedOut = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Temps écoulé'")).firstMatch
        XCTAssertTrue(timedOut.waitForExistence(timeout: 16), "au bout de 5 s, le temps est écoulé")
        snapshot(app, "4-temps-ecoule")
        app.buttons["visualizationStop"].tap()
        XCTAssertTrue(score.waitForExistence(timeout: 5))
        XCTAssertTrue(score.label.hasPrefix("0 /"), "la question manquée compte : \(score.label)")

        // Le retour, d'une série en cours, mène aux réglages du module, pas à l'accueil.
        app.buttons["visualizationSettings"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        app.buttons["visualizationBack"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5), "le retour d'une série mène aux réglages de Visualisation")
        XCTAssertFalse(app.buttons["mode_play"].exists, "pas à l'accueil")
        tapPill("visualizationTimer_0", app)
    }

    /// Lot 2 : les marches 3 et 4 seules ; chaque question met en scène son trajet ou sa position, en figurines.
    func testPiecesAndPositionSteps() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-AppleLanguages", "(fr)"]
        app.launch()
        XCTAssertTrue(app.buttons["mode_play"].waitForExistence(timeout: 20))
        let tile = app.buttons["mode_visualization"]
        var tries = 0
        while !(tile.exists && tile.isHittable), tries < 8 { app.swipeUp(); tries += 1 }
        tile.tap()
        let start = app.buttons["visualizationStart"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))

        // Cocher 3 et 4 d'abord (jamais aucune marche), puis décocher 1 et 2.
        for step in ["pieces", "position"] {
            let row = app.buttons["visualizationStep_\(step)"]
            NewGameSetupSteps.reveal(row, in: app)
            if !row.isSelected { row.tap() }
            XCTAssertTrue(row.isSelected, step)
        }
        for step in ["squares", "lines"] {
            let row = app.buttons["visualizationStep_\(step)"]
            NewGameSetupSteps.reveal(row, in: app)
            if row.isSelected { row.tap() }
            XCTAssertFalse(row.isSelected, step)
        }
        tapPill("visualizationLength_0", app)
        tapPill("visualizationTimer_0", app)
        snapshot(app, "5-reglages-lot2")
        start.tap()

        let scene = app.descendants(matching: .any)["visualizationScene"].firstMatch
        let progress = app.staticTexts["visualizationProgress"]
        let score = app.staticTexts["visualizationSummaryScore"]
        for index in 0..<10 {
            XCTAssertTrue(scene.waitForExistence(timeout: 5), "la question \(index + 1) met en scène sa position")
            if index < 3 { snapshot(app, "6-question-\(index + 1)") }
            answerCurrent(app)
            let next = "\(index + 2) / 10"
            let deadline = Date().addingTimeInterval(10)
            while Date() < deadline, !score.exists, !(progress.exists && progress.label == next) { pause(0.2) }
        }
        XCTAssertTrue(score.waitForExistence(timeout: 5))
        snapshot(app, "7-bilan-lot2")

        // Réglages rendus : la marche 1 seule.
        app.buttons["visualizationSettings"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        let squares = app.buttons["visualizationStep_squares"]
        NewGameSetupSteps.reveal(squares, in: app)
        squares.tap()
        for step in ["pieces", "position"] {
            let row = app.buttons["visualizationStep_\(step)"]
            NewGameSetupSteps.reveal(row, in: app)
            if row.isSelected { row.tap() }
        }
    }
}
