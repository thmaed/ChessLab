import UIKit
import XCTest

/// Scénarios pour les vidéos App Store Connect (accueil → mode classique →
/// puzzle ; accueil → Variantes → Horde → Chess960), en anglais uniquement.
/// Ne prend AUCUNE capture elle-même — l'enregistrement vidéo se fait à
/// côté via `xcrun simctl io <udid> recordVideo`, ce test ne fait que
/// piloter l'app pendant que ça tourne. Pas un test de régression : lancé
/// à la demande, jamais dans la suite verte habituelle. Même discipline de
/// navigation tolérante/bornée que ``AppStoreScreenshotUITests``.
final class AppStoreVideoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testVideoClassicAndPuzzleEnglish() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-resetPlaySettings",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        // Contre l'ordinateur, réglages par défaut, deux coups joués.
        guard tapLabeled(app, "Against the computer") else {
            XCTFail("tuile « Against the computer » introuvable")
            return
        }
        guard tapLabeled(app, "Start") else {
            XCTFail("bouton « Start » introuvable (mode classique)")
            return
        }
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 10))
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        waitForMoveCount(app, marker: "moveCount", atLeast: 2)

        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        app.otherElements["square_g1"].tap()
        app.otherElements["square_f3"].tap()
        waitForMoveCount(app, marker: "moveCount", atLeast: 4)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        // Retour à l'accueil (barre latérale iPad persistante, pile de
        // navigation iPhone), puis Puzzles.
        goBackToHome(app)
        guard tapLabeled(app, "Puzzles") else {
            XCTFail("tuile « Puzzles » introuvable")
            return
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        if tapLabeled(app, "Start", timeout: 4) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }

    @MainActor
    func testVideoVariantsHordeAndChess960English() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-resetPlaySettings",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        guard tapLabeled(app, "Variants", id: "mode_variants") else {
            XCTFail("tuile « Variants » introuvable")
            return
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        // Horde : trois poussées de pion sûres depuis la position de départ
        // (e4-e5, d4-d5, h4-h5 — toutes vers des cases vides, voir le FEN
        // dans ``FairyVariant/horde``).
        let horde = app.buttons["variant_horde"]
        guard horde.waitForExistence(timeout: 6) else {
            XCTFail("tuile Horde introuvable")
            return
        }
        horde.tap()
        // Coupée AVANT de démarrer : l'éval Horde est volatile sur de
        // simples poussées de pion (aucune n'est réellement une gaffe), et
        // l'alerte — bien réelle — coûterait un arrêt de 2 s en pleine
        // vidéo, potentiellement une reprise du coup qui viendrait de se
        // jouer. Constaté en répétition avant l'enregistrement.
        _ = tapLabeled(app, "Warn on risky moves", timeout: 2)
        guard tapLabeled(app, "Start", id: "fairyVariant_start") else {
            XCTFail("bouton Start introuvable (Horde)")
            return
        }
        XCTAssertTrue(app.otherElements["square_e4"].waitForExistence(timeout: 10))
        for (from, to) in [("e4", "e5"), ("d4", "d5"), ("h4", "h5")] {
            app.otherElements["square_\(from)"].tap()
            app.otherElements["square_\(to)"].tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        // Retour au hub des variantes (deux niveaux : partie → hub), puis
        // Chess960 — la position par défaut suffit à activer Start.
        var backToHub = 0
        while !app.buttons["variant_chess960"].waitForExistence(timeout: 1), backToHub < 6 {
            goBack(app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            backToHub += 1
        }
        let chess960 = app.buttons["variant_chess960"]
        guard chess960.waitForExistence(timeout: 6) else {
            XCTFail("tuile Chess960 introuvable au retour")
            return
        }
        chess960.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        guard tapLabeled(app, "Start", id: "chess960_start") else {
            XCTFail("bouton Start introuvable (Chess960)")
            return
        }
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 10))
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }

    // MARK: Aides

    private func waitForMoveCount(_ app: XCUIApplication, marker: String, atLeast: Int, timeout: TimeInterval = 15) {
        let element = app.otherElements[marker]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, (Int(element.value as? String ?? "0") ?? 0) < atLeast {
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
    }

    private func goBackToHome(_ app: XCUIApplication) {
        var hops = 0
        while !app.buttons["mode_variants"].waitForExistence(timeout: 1), hops < 6 {
            goBack(app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            hops += 1
        }
    }

    /// Voir le commentaire jumeau sur
    /// ``AppStoreScreenshotUITests/goBack(_:)`` — même geste de bord côté
    /// iPhone, pour la même raison.
    private func goBack(_ app: XCUIApplication) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        } else {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    @discardableResult
    private func tapLabeled(_ app: XCUIApplication, _ label: String, id: String? = nil, timeout: TimeInterval = 6) -> Bool {
        if let id {
            let byId = app.buttons[id]
            if byId.waitForExistence(timeout: 1) { byId.tap(); return true }
        }
        let match = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        if match.waitForExistence(timeout: timeout) { match.tap(); return true }
        return false
    }
}
