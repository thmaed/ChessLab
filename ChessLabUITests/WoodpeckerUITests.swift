import XCTest

/// La méthode Woodpecker de bout en bout : créer un programme depuis l'écran
/// de choix, le jouer, le retrouver, l'arrêter.
///
/// - important: PAS de `-resetPlaySettings`, comme ``PuzzleFiltersUITests`` :
///   ce test doit pouvoir tourner sur un iPhone réel.
@MainActor
final class WoodpeckerUITests: XCTestCase {

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Fait défiler l'écran de choix jusqu'à l'élément (la carte est sous les
    /// filtres).
    private func scrollTo(_ target: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !target.isHittable, tries < 8 {
            app.swipeUp()
            tries += 1
        }
    }

    func testCreatePlayResumeAndStopAProgramme() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-openRoute", "puzzles"]
        app.launch()

        // La ligne de création, ou un programme laissé par un essai précédent.
        let card = element(app, "woodpeckerCard")
        let leftoverProgramme = element(app, "woodpeckerProgramme")
        let opened = Date().addingTimeInterval(15)
        while Date() < opened, !card.exists, !leftoverProgramme.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        // Un programme laissé par un essai précédent : on l'arrête d'abord.
        let leftover = element(app, "woodpeckerArchive")
        if leftover.exists {
            scrollTo(leftover, in: app)
            leftover.tap()
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'programme'")).firstMatch.tap()
        }

        // La ligne Woodpecker ouvre sa feuille : critères, taille du lot, création (28/10/2026).
        element(app, "woodpeckerCard").tap()
        let create = element(app, "woodpeckerCreate")
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        let size25 = app.segmentedControls.buttons["25"]
        scrollTo(size25, in: app)
        size25.tap()
        create.tap()

        // L'écran de résolution, en mode programme : chrono et rang dans le lot.
        XCTAssertTrue(element(app, "woodpeckerClock").waitForExistence(timeout: 15), "le chrono du cycle doit s'afficher")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1/25'")).firstMatch.waitForExistence(timeout: 5),
            "le rang dans le lot doit s'afficher"
        )
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "woodpecker-resolution"
        shot.lifetime = .keepAlways
        add(shot)

        // Retour : la carte propose de REPRENDRE ce programme.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let resume = element(app, "woodpeckerResume")
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "le programme en cours doit être proposé")

        // Et on l'arrête : la ligne de création revient.
        let archive = element(app, "woodpeckerArchive")
        scrollTo(archive, in: app)
        archive.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'programme'")).firstMatch.tap()
        XCTAssertTrue(element(app, "woodpeckerCard").waitForExistence(timeout: 5))
    }

    /// Un cycle ENTIER (lot connu de dix mats en deux, riposte comprise) :
    /// chaque puzzle se résout à travers l'échiquier, le bilan s'affiche au
    /// dixième, puis le cycle 2 repart sur le même lot.
    func testAFullCycleLeadsToTheSummaryThenTheNextCycle() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-openRoute", "puzzles", "-uiTestWoodpeckerDemo"]
        app.launch()

        let opened = Date().addingTimeInterval(15)
        while Date() < opened, !element(app, "woodpeckerCard").exists, !element(app, "woodpeckerProgramme").exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        let leftover = element(app, "woodpeckerArchive")
        if leftover.exists {
            scrollTo(leftover, in: app)
            leftover.tap()
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'programme'")).firstMatch.tap()
        }
        element(app, "woodpeckerCard").tap()
        let create = element(app, "woodpeckerCreate")
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        let size10 = app.segmentedControls.buttons["10"]
        scrollTo(size10, in: app)
        size10.tap()
        create.tap()
        XCTAssertTrue(element(app, "woodpeckerClock").waitForExistence(timeout: 15))

        func square(_ name: String) -> XCUIElement { app.otherElements["square_\(name)"] }
        func play(_ from: String, _ to: String) {
            XCTAssertTrue(square(from).waitForExistence(timeout: 10))
            square(from).tap()
            square(to).tap()
        }

        for rank in 1...10 {
            play("e3", "e8")
            // La riposte Txe8 : la tour noire arrive en e8.
            let e8 = square("e8")
            let deadline = Date().addingTimeInterval(10)
            while Date() < deadline, !e8.label.lowercased().contains("noir"), !e8.label.lowercased().contains("black") {
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
            // Sur un vrai téléphone, un tap qui arrive pendant l'animation de
            // la riposte est ignoré (iPhone XS, 24/10) — un humain ne joue pas
            // aussi vite. On vérifie que le coup est PRIS, et on le rejoue sinon.
            let e1 = square("e1")
            for _ in 0..<4 {
                play("e1", "e8")
                let settled = Date().addingTimeInterval(2)
                while Date() < settled, !e1.label.lowercased().contains("vide"), !e1.label.lowercased().contains("empty") {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                }
                if e1.label.lowercased().contains("vide") || e1.label.lowercased().contains("empty") { break }
            }
            if rank < 10 {
                let next = element(app, "puzzleNext")
                XCTAssertTrue(next.waitForExistence(timeout: 10), "puzzle \(rank) : « Puzzle suivant » attendu")
                next.tap()
            }
        }

        let summary = element(app, "woodpeckerCycleSummary")
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "le bilan du cycle doit s'afficher")
        XCTAssertTrue(summary.label.contains("10"), "dix trouvés sur dix (lu : \(summary.label))")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "woodpecker-bilan"
        shot.lifetime = .keepAlways
        add(shot)

        element(app, "woodpeckerNextCycle").tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Cycle 2'")).firstMatch.waitForExistence(timeout: 10),
            "le cycle 2 doit démarrer"
        )

        // Ménage : le programme de démonstration ne reste pas en cours.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let archive = element(app, "woodpeckerArchive")
        XCTAssertTrue(archive.waitForExistence(timeout: 10))
        scrollTo(archive, in: app)
        archive.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'programme'")).firstMatch.tap()
    }
}

