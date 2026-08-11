import UIKit
import XCTest

/// Capture des visuels App Store Connect (accueil, Ouvertures = liste + lecteur
/// à flèches colorées, partie en cours), sur simulateur, en français ET en
/// anglais. Pas un test de régression : lancé à la demande pour la préparation
/// de soumission, jamais dans la suite verte habituelle.
///
/// `-AppleLanguages` force la langue « système » indépendamment de la locale du
/// Mac hôte. La navigation est TOLÉRANTE (soft `if`) : si un écran manque sur un
/// idiome, la capture continue sans faire échouer le test.
///
/// Écrit sur le disque hôte sous `/tmp/cl-appstore-screenshots/<idiom>/<langue>/`.
final class AppStoreScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreenshotsFrench() throws {
        try capture(appleLanguageCode: "fr", folder: "fr")
    }

    @MainActor
    func testCaptureAppStoreScreenshotsEnglish() throws {
        try capture(appleLanguageCode: "en", folder: "en")
    }

    @MainActor
    private func capture(appleLanguageCode: String, folder: String) throws {
        let fr = appleLanguageCode == "fr"
        let app = XCUIApplication()
        app.launchArguments += [
            "-resetPlaySettings",
            "-AppleLanguages", "(\(appleLanguageCode))",
            "-AppleLocale", fr ? "fr_FR" : "en_US",
        ]
        app.launch()

        // 01 — Accueil.
        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        save(app.screenshot(), folder: folder, name: "01-accueil")

        // 02 & 03 — Ouvertures : la liste, puis le lecteur avec ses flèches
        // colorées (la grande nouveauté 1.2).
        if tapLabeled(app, fr ? "Ouvertures" : "Openings", id: "mode_openings") {
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            save(app.screenshot(), folder: folder, name: "02-ouvertures")
            // La List SwiftUI est paresseuse : on défile jusqu'à l'italienne.
            let italian = app.buttons["opening_italian-game"]
            var scrolls = 0
            while !italian.isHittable, scrolls < 14 {
                app.swipeUp()
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                scrolls += 1
            }
            if italian.isHittable {
                italian.tap()
                let next = app.buttons["reader_next"]
                if next.waitForExistence(timeout: 6) {
                    // Jusqu'à une position à variantes (après 3.Fc4) : flèche verte
                    // (coup recommandé) + flèches bleues (autres coups).
                    for _ in 0..<5 where next.isEnabled { next.tap() }
                    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                    save(app.screenshot(), folder: folder, name: "03-lecteur")
                }
            }
        }

        // Revenir à un état où le mode de jeu est accessible (accueil sur iPhone,
        // barre latérale persistante sur iPad).
        let playLabel = fr ? "Contre l'ordinateur" : "Against the computer"
        func playHittable() -> Bool {
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", playLabel)).firstMatch.isHittable
        }
        var hops = 0
        while !playHittable(), hops < 5 {
            if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            hops += 1
        }

        // 04 — Partie en cours.
        if tapLabeled(app, playLabel) {
            if tapLabeled(app, fr ? "Commencer" : "Start") {
                if app.otherElements["square_e2"].waitForExistence(timeout: 10) {
                    app.otherElements["square_e2"].tap()
                    app.otherElements["square_e4"].tap()
                    let moveMarker = app.otherElements["moveCount"]
                    let deadline = Date().addingTimeInterval(15)
                    while Date() < deadline, moveMarker.value as? String != "2" {
                        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                    }
                    RunLoop.current.run(until: Date().addingTimeInterval(1))
                    save(app.screenshot(), folder: folder, name: "04-partie")
                }
            }
        }
    }

    /// Tape un élément par identifiant (tuile iPhone) ou, à défaut, par LABEL,
    /// quel que soit son type (bouton, cellule de liste, texte) — nécessaire car
    /// les rangées de la barre latérale iPad ne sont pas exposées comme boutons.
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

    private func save(_ screenshot: XCUIScreenshot, folder: String, name: String) {
        let idiom = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        let dir = "/tmp/cl-appstore-screenshots/\(idiom)/\(folder)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
}
