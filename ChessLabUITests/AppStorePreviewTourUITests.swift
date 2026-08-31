import UIKit
import XCTest

/// Parcours SCÉNARISÉS pour les « app previews » vidéo d'App Store Connect —
/// à lancer À LA DEMANDE pendant qu'un `xcrun simctl io … recordVideo`
/// enregistre l'écran du simulateur (voir `AppStoreSubmission/README.md`).
/// Jamais dans la suite verte.
///
/// Deux parcours (brief utilisateur du 19/08), EN ANGLAIS :
/// 1. iPhone — menu → contre l'ordinateur (2 coups) → menu → Puzzles →
///    un puzzle RÉSOLU (le tirage déterministe sert le puzzle 00008, dont
///    la solution est connue) → menu.
/// 2. iPad — menu → Finales (2 coups dans un cours) → Laboratoire →
///    série lancée, les deux moteurs jouent à l'écran.
///
/// Le rythme est fait de pauses FIXES : une preview se REGARDE. La fenêtre
/// 15-30 s exigée par Apple est découpée au post-traitement
/// (`tools/appstore-preview/make_preview.swift`).
@MainActor
final class AppStorePreviewTourUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// iPhone — jouer, puis résoudre : les deux gestes quotidiens de l'app.
    @MainActor
    func testTourPlayThenPuzzleEnglish() throws {
        let app = launch(language: "en", extraArguments: ["-uiTestDeterministicPuzzles"])
        pause(1.2)

        // Contre l'ordinateur : deux coups joués, réponses du moteur.
        // Rythme SERRÉ : le tout doit tenir dans la fenêtre de 30 s d'Apple.
        if tap(app, label: "Against the computer") {
            pause(1.0)
            if tap(app, label: "Start") {
                if app.otherElements["square_e2"].waitForExistence(timeout: 10) {
                    pause(0.6)
                    playMove(app, from: "e2", to: "e4")
                    waitPlies(app, atLeast: 2)
                    pause(0.6)
                    playMove(app, from: "g1", to: "f3")
                    waitPlies(app, atLeast: 4)
                    pause(0.8)
                }
            }
            goBack(app)   // retour à l'accueil, la partie s'autosauvegarde
            pause(0.9)
        }

        // Puzzles : le 00008 (tirage déterministe), résolu pour de vrai —
        // Re7 !, l'intermezzo Nc1 et la reprise finale Qxc1.
        if tap(app, label: "Puzzles") {
            pause(1.0)
            if tap(app, label: "Start") {
                if app.otherElements["square_e6"].waitForExistence(timeout: 10) {
                    pause(0.8)
                    playMove(app, from: "e6", to: "e7")   // 1.Re7 !
                    pause(1.4)                             // riposte auto …Qb1+
                    playMove(app, from: "b3", to: "c1")   // 2.Nc1 !
                    pause(1.4)                             // …Qxc1+
                    playMove(app, from: "h6", to: "c1")   // 3.Qxc1 — résolu
                    // La pré-chauffe non enregistrée fait de cette assertion
                    // un garde-fou : si le tirage n'est pas le 00008, on le
                    // sait AVANT de tourner la vraie prise.
                    if !app.staticTexts["Solved!"].waitForExistence(timeout: 5) {
                        let dir = "/tmp/cl-preview-debug"
                        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                        try? app.screenshot().pngRepresentation.write(
                            to: URL(fileURLWithPath: "\(dir)/puzzle-fail.png"))
                        XCTFail("le puzzle déterministe doit être résolu par la séquence scriptée")
                    }
                    pause(1.6)                             // confettis
                    _ = tap(app, label: "Back")
                    pause(0.5)
                }
            }
            goBack(app)
            pause(1.2)
        }
    }

    /// iPad — comprendre, puis expérimenter : une finale prouvée, et le
    /// Laboratoire qui fait jouer Stockfish contre lui-même.
    @MainActor
    func testTourEndgameThenLabEnglish() throws {
        let app = launch(language: "en")
        pause(1.8)

        // Finales : l'opposition (première de la liste), deux coups lus.
        if tap(app, label: "Endgames", id: "mode_endgames") {
            pause(2.0)
            let opposition = app.buttons["endgame_eg-opposition"]
            if opposition.waitForExistence(timeout: 6) {
                opposition.tap()
                let next = app.buttons["reader_next"]
                if next.waitForExistence(timeout: 6) {
                    pause(2.4)
                    if next.isEnabled { next.tap() }
                    pause(2.2)
                    if next.isEnabled { next.tap() }
                    pause(2.2)
                }
            }
            goBack(app)   // retour à la liste ; la barre latérale iPad reste visible
            pause(1.0)
        }

        // Laboratoire : lancer une série, laisser les moteurs jouer.
        if tap(app, label: "Laboratory") {
            pause(2.2)
            if tap(app, label: "Start") {
                // Les premiers coups s'enchaînent à 150 ms/coup : on laisse
                // la série vivre à l'écran (plateau, éval, compteur).
                pause(9.0)
            }
        }
        pause(1.0)
    }

    // MARK: Outillage (mêmes conventions que AppStoreScreenshotUITests)

    private func launch(language: String, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-resetPlaySettings",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "fr" ? "fr_FR" : "en_US",
        ] + extraArguments
        app.launch()
        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 10))
        return app
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func playMove(_ app: XCUIApplication, from: String, to: String) {
        app.otherElements["square_\(from)"].tap()
        app.otherElements["square_\(to)"].tap()
    }

    /// Attend que le compteur de demi-coups de l'écran Jouer atteigne `n`
    /// (la riposte du moteur incluse), avec un plafond de patience.
    private func waitPlies(_ app: XCUIApplication, atLeast n: Int, timeout: TimeInterval = 12) {
        let marker = app.otherElements["moveCount"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let value = marker.value as? String, let plies = Int(value), plies >= n { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
    }

    private func goBack(_ app: XCUIApplication) {
        if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    @discardableResult
    private func tap(_ app: XCUIApplication, label: String, id: String? = nil) -> Bool {
        if let id {
            let byId = app.buttons[id]
            if byId.waitForExistence(timeout: 1) { byId.tap(); return true }
        }
        let match = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label)).firstMatch
        if match.waitForExistence(timeout: 6) { match.tap(); return true }
        return false
    }
}
