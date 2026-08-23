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
            while !italian.isHittable, scrolls < 20 {
                app.swipeUp(velocity: .slow)
                RunLoop.current.run(until: Date().addingTimeInterval(0.45))
                scrolls += 1
            }
            if italian.isHittable {
                italian.tap()
                // L'index des lignes s'ouvre de lui-même : on le montre — il
                // vaut d'être vu — puis on le referme pour le lecteur.
                let closeIndex = app.buttons["openingIndex_close"]
                if closeIndex.waitForExistence(timeout: 6) {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                    save(app.screenshot(), folder: folder, name: "03-index-lignes")
                    closeIndex.tap()
                }
                let next = app.buttons["reader_next"]
                if !next.waitForExistence(timeout: 6) {
                    // Le tap a pu rater (rangée au ras du bord, feuille par-
                    // dessus…) : un cran de recentrage, puis UNE retentative.
                    save(app.screenshot(), folder: folder, name: "03-debug-after-tap")
                    app.swipeUp(velocity: .slow)
                    RunLoop.current.run(until: Date().addingTimeInterval(0.6))
                    if italian.isHittable { italian.tap() }
                    _ = next.waitForExistence(timeout: 6)
                }
                if next.exists {
                    // Jusqu'à une position à variantes (après 3.Fc4) : flèche verte
                    // (coup recommandé) + flèches bleues (autres coups).
                    for _ in 0..<5 where next.isEnabled { next.tap() }
                    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                    save(app.screenshot(), folder: folder, name: "03-lecteur")
                } else {
                    save(app.screenshot(), folder: folder, name: "03-debug-no-reader")
                }
            } else {
                print("DIAG 03 : italian.exists=\(italian.exists) après défilements")
                save(app.screenshot(), folder: folder, name: "03-debug-not-hittable")
            }
        }

        // 05 & 06 — Finales : la liste groupée par familles (l'argument n° 1
        // de la 1.5 : 77 cours prouvés), puis le lecteur sur la Lucena —
        // rangée 1 en bas, pied « vérifié par table de finales » visible.
        var back = 0
        while !app.buttons["mode_endgames"].exists && !app.staticTexts[fr ? "Finales" : "Endgames"].firstMatch.isHittable, back < 4 {
            if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            back += 1
        }
        if tapLabeled(app, fr ? "Finales" : "Endgames", id: "mode_endgames") {
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            save(app.screenshot(), folder: folder, name: "05-finales")
            // Plutôt que 20 swipes dans une List paresseuse (rangée « hittable »
            // en bord de zone dont le tap est avalé — cause des captures à 5/6
            // du 19-20/08) : filtrer par famille avec la puce « Tours », la
            // Lucena remonte en haut de liste. Petit défilement de secours.
            let rooksChip = app.buttons["endgameFamilyChip_rooks"]
            if rooksChip.waitForExistence(timeout: 4) { rooksChip.tap() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            let lucena = app.buttons["endgame_eg-lucena"]
            var scrolls = 0
            while !lucena.isHittable, scrolls < 6 {
                app.swipeUp(velocity: .slow)
                RunLoop.current.run(until: Date().addingTimeInterval(0.45))
                scrolls += 1
            }
            if lucena.isHittable {
                lucena.tap()
                let next = app.buttons["reader_next"]
                // Premier passage après redémarrage du simulateur : la poussée
                // de navigation peut dépasser 6 s (déjà vu sur 03-lecteur).
                // Re-taper une fois, délai rallongé — et si la capture reste
                // impossible, ÉCHOUER : un « TEST SUCCEEDED » à 5 fichiers
                // sur 6 est un mensonge (arrivé le 19/08, locale EN).
                if !next.waitForExistence(timeout: 10), lucena.isHittable {
                    lucena.tap()
                    _ = next.waitForExistence(timeout: 10)
                }
                if next.exists {
                    for _ in 0..<4 where next.isEnabled { next.tap() }
                    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                    save(app.screenshot(), folder: folder, name: "06-finale-lecteur")
                } else {
                    save(app.screenshot(), folder: folder, name: "debug-06-lecteur-jamais-ouvert")
                    XCTFail("lecteur Lucena jamais ouvert : capture 06-finale-lecteur impossible")
                }
            } else {
                save(app.screenshot(), folder: folder, name: "debug-06-lucena-pas-hittable")
                XCTFail("endgame_eg-lucena pas hittable après défilement : capture 06 impossible")
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
