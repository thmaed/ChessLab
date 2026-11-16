import XCTest

/// Essais de la synchronisation iCloud sur DEUX VRAIS iPhone — le simulateur n'a pas de compte iCloud, il ne
/// peut éprouver que ce qui ne dépend pas d'un échange réel.
///
/// Jamais dans la suite ordinaire : chaque étape est lancée À LA MAIN, sur l'appareil voulu, avec
/// `TEST_RUNNER_CHESSLAB_DEVICE_SYNC=1` (et `TEST_RUNNER_CHESSLAB_SYNC_TAG=<nom>` pour reconnaître les parties
/// de l'essai) — voir `tools/device-sync-test.sh`. L'appareil A joue les Blancs, B les Noirs.
///
/// Ce sont des téléphones RÉELS : aucune étape ne remet l'app à zéro (`-resetPlaySettings` effacerait
/// réglages et parties). Les parties de l'essai se jouent en mode Deux joueurs, aux noms de l'essai.
@MainActor
final class DeviceSyncUITests: XCTestCase {

    private var environment: [String: String] { ProcessInfo.processInfo.environment }
    private var tag: String { environment["CHESSLAB_SYNC_TAG"] ?? "Essai" }

    override func setUpWithError() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Essai sur appareil réel seulement.")
        #else
        try XCTSkipUnless(environment["CHESSLAB_DEVICE_SYNC"] == "1", "Lancé à la main par tools/device-sync-test.sh.")
        continueAfterFailure = false
        #endif
    }

    // MARK: Outils

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-AppleLanguages", "(fr)"]
        app.launch()
        XCTAssertTrue(app.buttons["openSettings"].waitForExistence(timeout: 20), "l'accueil doit s'afficher")
        return app
    }

    /// Une ligne du compte rendu : dans la sortie de xcodebuild (préfixe SYNC|) et en pièce jointe.
    private func note(_ text: String) {
        print("SYNC|\(text)")
        let attachment = XCTAttachment(string: text)
        attachment.name = "note"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, tries: Int = 12) {
        var count = 0
        while !element.isHittable, count < tries { app.swipeUp(velocity: .slow); count += 1 }
    }

    private func goHome(_ app: XCUIApplication) {
        var tries = 0
        while !app.buttons["openSettings"].isHittable, tries < 6 {
            app.navigationBars.buttons.firstMatch.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            tries += 1
        }
    }

    /// Attend une condition en laissant tourner l'app ; rend le temps écoulé, ou `nil` à l'échéance.
    private func wait(upTo seconds: TimeInterval, _ condition: () -> Bool) -> TimeInterval? {
        let start = Date()
        while Date().timeIntervalSince(start) < seconds {
            if condition() { return Date().timeIntervalSince(start) }
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        return condition() ? Date().timeIntervalSince(start) : nil
    }

    private func resumeLabel(_ app: XCUIApplication) -> String {
        app.buttons["resumeGame"].exists ? app.buttons["resumeGame"].label : ""
    }

    private func play(_ from: String, _ to: String, in app: XCUIApplication) {
        XCTAssertTrue(app.otherElements["square_\(from)"].waitForExistence(timeout: 20))
        app.otherElements["square_\(from)"].tap()
        app.otherElements["square_\(to)"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(2))
    }

    private func replaceText(of field: XCUIElement, with text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 4))
        field.typeText(text)
    }

    // MARK: 1. Réglages : l'interrupteur, l'état, « Vos appareils »

    func test01_settings() throws {
        let app = launch()
        app.buttons["openSettings"].tap()
        let toggle = app.switches["syncToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        scrollTo(toggle, in: app)
        if (toggle.value as? String) == "0" {
            note("synchro éteinte : je l'allume")
            let start = Date()
            toggle.switches.firstMatch.tap()
            XCTAssertTrue(app.staticTexts["Cet appareil"].waitForExistence(timeout: 30),
                          "après l'échange de base, les Réglages doivent revenir avec « Vos appareils »")
            note(String(format: "relancement intérieur : %.1f s", Date().timeIntervalSince(start)))
        } else {
            note("synchro déjà allumée")
        }
        let list = app.otherElements["syncDevicesList"]
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        scrollTo(list, in: app)
        for state in ["Dernière étape : relancer ChessLab", "Connectez-vous à iCloud", "Désactivée",
                      "Synchronisation en cours…", "Vérification du compte iCloud…"] where app.staticTexts[state].exists {
            note("état : \(state)")
        }
        if let upToDate = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'À jour'")).allElementsBoundByIndex.first {
            note("état : \(upToDate.label)")
        }
        let devices = list.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
        note("Vos appareils : " + devices.joined(separator: " | "))
        XCTAssertFalse(app.staticTexts["Dernière étape : relancer ChessLab"].exists, "plus de relancement demandé")
        XCTAssertFalse(app.staticTexts["Connectez-vous à iCloud"].exists, "l'appareil doit avoir un compte iCloud")
        snapshot(app, "reglages")
    }

    // MARK: 2. Une partie à deux, commencée sur A

    func test02_A_startGameAndPlayE4() throws {
        let app = launch()
        let tile = app.buttons["mode_twoPlayer"]
        scrollTo(tile, in: app, tries: 8)
        tile.tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 10))
        replaceText(of: app.textFields.element(boundBy: 0), with: tag)
        replaceText(of: app.textFields.element(boundBy: 1), with: "Synchro")
        app.textFields.element(boundBy: 1).typeText("\n")
        app.buttons["Commencer"].tap()
        if app.alerts.firstMatch.waitForExistence(timeout: 3) {
            note("une partie à deux était en cours sur A : remplacée par celle de l'essai")
            app.alerts.buttons["Remplacer par une nouvelle partie"].tap()
        }
        play("e2", "e4", in: app)
        goHome(app)
        XCTAssertTrue(app.buttons["resumeGame"].waitForExistence(timeout: 10))
        note("A : 1.e4 joué à \(Date().formatted(date: .omitted, time: .standard)) — \(resumeLabel(app))")
        snapshot(app, "A-accueil-apres-e4")
    }

    // MARK: 3. B la voit arriver, et répond

    func test03_B_seesGameAndPlaysE5() throws {
        let app = launch()
        let elapsed = wait(upTo: 180) {
            let label = resumeLabel(app)
            return label.contains("1 coup") && label.contains("Dernier coup joué sur votre")
        }
        note("B : partie reçue — \(elapsed.map { String(format: "%.0f s après l'ouverture", $0) } ?? "PAS REÇUE en 180 s") — \(resumeLabel(app))")
        snapshot(app, "B-accueil-partie-recue")
        XCTAssertNotNil(elapsed, "la partie commencée sur A doit apparaître sur B")
        app.buttons["resumeGame"].tap()
        play("e7", "e5", in: app)
        goHome(app)
        note("B : 1…e5 joué à \(Date().formatted(date: .omitted, time: .standard))")
    }

    // MARK: 4. A voit la réponse

    func test04_A_seesReply() throws {
        let app = launch()
        let elapsed = wait(upTo: 180) {
            let label = resumeLabel(app)
            return label.contains("2 coup") && label.contains("Dernier coup joué sur votre")
        }
        note("A : réponse reçue — \(elapsed.map { String(format: "%.0f s après l'ouverture", $0) } ?? "PAS REÇUE en 180 s") — \(resumeLabel(app))")
        snapshot(app, "A-accueil-reponse-recue")
        XCTAssertNotNil(elapsed, "la réponse jouée sur B doit apparaître sur A")
    }

    // MARK: 5. Échiquier ouvert sur A pendant que B joue (lancés EN MÊME TEMPS)

    /// Le coup que joue B pendant que l'échiquier de A est ouvert (`CHESSLAB_SYNC_MOVE`, « g1f3 » par défaut)
    /// et la case à vérifier après « Rattraper » (`CHESSLAB_SYNC_EXPECT`, « f3 »), occupée par un cavalier.
    private var remoteMove: String { environment["CHESSLAB_SYNC_MOVE"] ?? "g1f3" }
    private var expectedSquare: String { environment["CHESSLAB_SYNC_EXPECT"] ?? "f3" }

    func test05_A_openBoardAndWaitForBanner() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["resumeGame"].waitForExistence(timeout: 30))
        app.buttons["resumeGame"].tap()
        XCTAssertTrue(app.otherElements["square_e4"].waitForExistence(timeout: 20))
        note("A : échiquier ouvert à \(Date().formatted(date: .omitted, time: .standard)), j'attends le bandeau")
        let banner = app.otherElements["remoteAdvanceBanner"]
        let elapsed = wait(upTo: 240) { banner.exists }
        note("A : bandeau — \(elapsed.map { String(format: "apparu à %@ (%.0f s d'attente)", Date().formatted(date: .omitted, time: .standard), $0) } ?? "ABSENT en 240 s")")
        XCTAssertNotNil(elapsed, "le coup joué sur B doit faire apparaître le bandeau sur A")
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        snapshot(app, "A-bandeau")
        app.buttons["remoteAdvanceCatchUp"].tap()
        let square = app.otherElements["square_\(expectedSquare)"]
        let caughtUp = wait(upTo: 15) { square.exists && square.label.localizedCaseInsensitiveContains("cavalier") }
        note("A : après « Rattraper », \(expectedSquare) = \(square.exists ? square.label : "?")")
        snapshot(app, "A-apres-rattraper")
        XCTAssertNotNil(caughtUp, "le cavalier joué sur B doit être en \(expectedSquare)")
        XCTAssertFalse(banner.exists, "le bandeau doit disparaître")
    }

    func test06_B_playRemoteMove() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["resumeGame"].waitForExistence(timeout: 60))
        // Laisser à A le temps d'ouvrir son échiquier.
        RunLoop.current.run(until: Date().addingTimeInterval(20))
        app.buttons["resumeGame"].tap()
        let from = String(remoteMove.prefix(2)), to = String(remoteMove.suffix(2))
        play(from, to, in: app)
        note("B : \(remoteMove) joué à \(Date().formatted(date: .omitted, time: .standard))")
        RunLoop.current.run(until: Date().addingTimeInterval(5))
        goHome(app)
    }

    // MARK: 6. La partie se termine sur A : la partie TERMINÉE voyage par CloudKit (le chemin du retour de Ron)

    func test07_A_resign() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["resumeGame"].waitForExistence(timeout: 30))
        app.buttons["resumeGame"].tap()
        XCTAssertTrue(app.buttons["Abandonner"].waitForExistence(timeout: 20))
        app.buttons["Abandonner"].tap()
        let blackResigns = app.buttons["Synchro (Noirs)"]
        XCTAssertTrue(blackResigns.waitForExistence(timeout: 10))
        blackResigns.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        goHome(app)
        note("A : partie terminée (abandon des Noirs) à \(Date().formatted(date: .omitted, time: .standard))")
        snapshot(app, "A-accueil-partie-terminee")
    }

    func test08_B_seesFinishedGame() throws {
        let app = launch()
        let gone = wait(upTo: 120) { !app.buttons["resumeGame"].exists || !resumeLabel(app).contains("coup") }
        note("B : reprise retirée — \(gone.map { String(format: "%.0f s", $0) } ?? "toujours là après 120 s")")
        // La bibliothèque, filtrée sur le nom de l'essai.
        let start = Date()
        var found = false
        while !found, Date().timeIntervalSince(start) < 300 {
            goHome(app)
            let analyse = app.buttons["Analyser"].firstMatch
            scrollTo(analyse, in: app, tries: 6)
            analyse.tap()
            let library = app.buttons.matching(NSPredicate(format: "label CONTAINS 'ibliothèque'")).firstMatch
            if library.waitForExistence(timeout: 10) { library.tap() }
            let search = app.searchFields.firstMatch
            if search.waitForExistence(timeout: 10) {
                search.tap()
                search.typeText(tag)
            }
            found = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", tag)).firstMatch
                .waitForExistence(timeout: 20)
            if !found { RunLoop.current.run(until: Date().addingTimeInterval(10)) }
        }
        note("B : partie terminée dans la bibliothèque — \(found ? String(format: "trouvée après %.0f s", Date().timeIntervalSince(start)) : "ABSENTE après 300 s")")
        snapshot(app, "B-bibliotheque")
        XCTAssertTrue(found, "la partie terminée sur A doit arriver dans la bibliothèque de B (CloudKit)")
    }
}
