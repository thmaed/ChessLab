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
        try CaptureToolGate.requireEnabled()

        try captureOpenings(appleLanguageCode: "fr", folder: "fr")
        try captureFinalesAndVariants(appleLanguageCode: "fr", folder: "fr")
        try capturePlay(appleLanguageCode: "fr", folder: "fr")
    }

    @MainActor
    func testCaptureAppStoreScreenshotsEnglish() throws {
        try CaptureToolGate.requireEnabled()

        try captureOpenings(appleLanguageCode: "en", folder: "en")
        try captureFinalesAndVariants(appleLanguageCode: "en", folder: "en")
        try capturePlay(appleLanguageCode: "en", folder: "en")
    }

    /// Lance l'app avec les arguments de langue standard — chaque phase de
    /// capture appelle ceci pour repartir d'un lancement FRAIS plutôt que de
    /// chaîner toutes les captures sur UNE SEULE session d'app. Certains
    /// simulateurs (constaté sur iPhone 14 Plus) laissent le retour arrière
    /// se dégrader après une navigation profonde (lecteur d'Ouvertures) —
    /// repartir de zéro entre chaque phase élimine tout état accumulé, au
    /// prix d'un aller-retour d'accueil affiché deux fois de plus.
    @MainActor
    private func launchApp(appleLanguageCode: String) -> XCUIApplication {
        let fr = appleLanguageCode == "fr"
        let app = XCUIApplication()
        app.launchArguments += [
            "-resetPlaySettings",
            "-AppleLanguages", "(\(appleLanguageCode))",
            "-AppleLocale", fr ? "fr_FR" : "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        return app
    }

    // MARK: 01, 02 & 03 — Accueil, Ouvertures

    @MainActor
    private func captureOpenings(appleLanguageCode: String, folder: String) throws {
        let fr = appleLanguageCode == "fr"
        let app = launchApp(appleLanguageCode: appleLanguageCode)

        // 01 — Accueil.
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
    }

    // MARK: 05 & 06 — Finales ; 07, 08 & 09 — Variantes

    @MainActor
    private func captureFinalesAndVariants(appleLanguageCode: String, folder: String) throws {
        let fr = appleLanguageCode == "fr"
        let app = launchApp(appleLanguageCode: appleLanguageCode)

        // 05 & 06 — Finales : la liste groupée par familles (l'argument n° 1
        // de la 1.5 : 77 cours prouvés), puis le lecteur sur la Lucena —
        // rangée 1 en bas, pied « vérifié par table de finales » visible.
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

        // 07, 08 & 09 — Variantes : le hub à tuiles, puis Roi de la colline en
        // pleine partie (une variante Fairy-Stockfish, pas Chess960 — pas
        // d'étape de réglage de position à négocier), puis la position de
        // départ de Horde (asymétrique — 36 pions blancs, aucune autre pièce
        // — déjà assez parlante sans jouer le moindre coup).
        var backToVariants = 0
        while !app.buttons["mode_variants"].exists && !app.staticTexts[fr ? "Variantes" : "Variants"].firstMatch.isHittable, backToVariants < 15 {
            goBack(app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            backToVariants += 1
        }
        if tapLabeled(app, fr ? "Variantes" : "Variants", id: "mode_variants") {
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            save(app.screenshot(), folder: folder, name: "07-variantes")

            let kingOfTheHill = app.buttons["variant_kingofthehill"]
            if kingOfTheHill.waitForExistence(timeout: 6) {
                kingOfTheHill.tap()
                let start = app.buttons["fairyVariant_start"]
                if start.waitForExistence(timeout: 6) {
                    start.tap()
                    if app.otherElements["square_e2"].waitForExistence(timeout: 10) {
                        app.otherElements["square_e2"].tap()
                        app.otherElements["square_e4"].tap()
                        let moveMarker = app.otherElements["fairyVariant_moveCount"]
                        let deadline = Date().addingTimeInterval(15)
                        while Date() < deadline, moveMarker.value as? String != "2" {
                            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                        }
                        RunLoop.current.run(until: Date().addingTimeInterval(1))
                        save(app.screenshot(), folder: folder, name: "08-variante-partie")
                    } else {
                        save(app.screenshot(), folder: folder, name: "debug-08-no-board")
                        XCTFail("plateau Roi de la colline jamais apparu : capture 08 impossible")
                    }
                } else {
                    save(app.screenshot(), folder: folder, name: "debug-08-no-start")
                    XCTFail("bouton Commencer jamais apparu (Roi de la colline) : capture 08 impossible")
                }
            } else {
                save(app.screenshot(), folder: folder, name: "debug-07-no-king-of-hill-tile")
                XCTFail("tuile Roi de la colline jamais apparue : capture 08 impossible")
            }

            // Retour au hub avant la seconde variante — deux niveaux à
            // remonter (partie → réglages → hub), chacun via le bouton
            // système de la barre de navigation.
            var backToHub = 0
            while !app.buttons["variant_horde"].waitForExistence(timeout: 1), backToHub < 15 {
                goBack(app)
                RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                backToHub += 1
            }
            let horde = app.buttons["variant_horde"]
            if horde.waitForExistence(timeout: 6) {
                horde.tap()
                let start = app.buttons["fairyVariant_start"]
                if start.waitForExistence(timeout: 6) {
                    start.tap()
                    if app.otherElements["square_b5"].waitForExistence(timeout: 10) {
                        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
                        save(app.screenshot(), folder: folder, name: "09-variante-horde")
                    } else {
                        save(app.screenshot(), folder: folder, name: "debug-09-no-board")
                        XCTFail("plateau Horde jamais apparu : capture 09 impossible")
                    }
                } else {
                    save(app.screenshot(), folder: folder, name: "debug-09-no-start")
                    XCTFail("bouton Commencer jamais apparu (Horde) : capture 09 impossible")
                }
            } else {
                save(app.screenshot(), folder: folder, name: "debug-09-no-horde-tile")
                XCTFail("tuile Horde jamais apparue : capture 09 impossible")
            }

            captureDuckChess(app, folder: folder)
        }
    }

    // MARK: 10 — Duck Chess, la variante la plus reconnaissable de la 1.7
    //
    // Dixième et DERNIÈRE capture : App Store Connect n'en accepte pas plus.
    // Le canard jaune posé sur une case dit d'un coup d'œil ce qu'aucune
    // ligne de description ne dira aussi vite — et il faut avoir joué un tour
    // complet pour le voir, puisqu'il n'est pas là au départ.
    @MainActor
    private func captureDuckChess(_ app: XCUIApplication, folder: String) {
        // Retour au hub, puis descente jusqu'à la tuile : avec douze
        // variantes, le canard n'est plus dans le premier écran.
        var backToHub = 0
        while !app.buttons["variant_kingofthehill"].waitForExistence(timeout: 1), backToHub < 15 {
            goBack(app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            backToHub += 1
        }
        let duck = app.buttons["variant_duck"]
        var scrolls = 0
        while !(duck.exists && duck.isHittable), scrolls < 10 {
            app.swipeUp(velocity: .slow)
            RunLoop.current.run(until: Date().addingTimeInterval(0.45))
            scrolls += 1
        }
        guard duck.exists, duck.isHittable else {
            save(app.screenshot(), folder: folder, name: "debug-10-no-duck-tile")
            XCTFail("tuile Duck Chess jamais atteinte : capture 10 impossible")
            return
        }
        duck.tap()

        let start = app.buttons["fairyVariant_start"]
        guard start.waitForExistence(timeout: 6) else {
            save(app.screenshot(), folder: folder, name: "debug-10-no-start")
            XCTFail("bouton Commencer jamais apparu (Duck Chess) : capture 10 impossible")
            return
        }
        start.tap()

        guard app.otherElements["square_e2"].waitForExistence(timeout: 12) else {
            save(app.screenshot(), folder: folder, name: "debug-10-no-board")
            XCTFail("plateau Duck Chess jamais apparu : capture 10 impossible")
            return
        }
        // Un tour COMPLET : le coup, puis la pose du canard — sans elle, il
        // n'y a rien à montrer. On attend ensuite la réponse de l'ordinateur,
        // qui pose le sien ailleurs.
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        app.otherElements["square_e5"].tap()

        let moveMarker = app.otherElements["duck_moveCount"]
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline, Int(moveMarker.value as? String ?? "0") ?? 0 < 2 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        save(app.screenshot(), folder: folder, name: "10-variante-canard")
    }

    // MARK: 04 — Partie en cours (mode classique)

    @MainActor
    private func capturePlay(appleLanguageCode: String, folder: String) throws {
        let fr = appleLanguageCode == "fr"
        let app = launchApp(appleLanguageCode: appleLanguageCode)
        let playLabel = fr ? "Contre l'ordinateur" : "Against the computer"

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

    /// Navigue « en arrière » — geste de bord sur iPhone plutôt que le
    /// bouton système de la barre de navigation : sur certains simulateurs
    /// (constaté sur iPhone 14 Plus, 1284×2778), ce bouton se fait parfois
    /// calculer un point de frappe invalide (« {-1, -1} après défilement »)
    /// et le tap n'a AUCUN effet, bloquant toute navigation retour pendant
    /// des minutes sans jamais faire échouer le test (garde tolérante).
    /// Le geste de bord ne dépend d'aucun calcul de cadre de bouton. Garde
    /// le bouton système sur iPad, où la barre latérale rend le geste de
    /// bord ambigu (peut révéler/masquer la barre au lieu de reculer) et où
    /// ce défaut n'a jamais été observé.
    private func goBack(_ app: XCUIApplication) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            goBack(app)
        } else {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    private func save(_ screenshot: XCUIScreenshot, folder: String, name: String) {
        let idiom = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        let dir = "/tmp/cl-appstore-screenshots/\(idiom)/\(folder)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
}
