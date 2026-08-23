import XCTest

/// Le parcours complet du module « Ouvertures — Labs », de la tuile d'accueil
/// au saut depuis l'index des lignes.
///
/// L'aperçu est ÉTEINT par défaut : le test l'allume par un argument de
/// lancement (domaine `NSArgumentDomain` de `UserDefaults`), exactement comme
/// `-settings.appLanguage` ailleurs dans cette suite. Le premier contrôle du
/// test est donc aussi celui de l'interrupteur lui-même.
final class OpeningsModuleUITests: XCTestCase {

    private func launchWithLabs(contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        // Les tailles d'accessibilité se forcent AU LANCEMENT : il n'existe
        // pas d'API pour en changer en cours de route (cf.
        // `DynamicTypeOverflowUITests`).
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        return app
    }

    /// Ouvre le module, quelle que soit l'ossature d'accueil : GRILLE de
    /// tuiles sur iPhone, BARRE LATÉRALE sur iPad et Mac. C'est le même module
    /// derrière, mais pas le même point d'entrée — un test qui ne connaîtrait
    /// que la tuile ne dirait rien de l'iPad, précisément là où la disposition
    /// du lecteur change (plateau à gauche, panneau à droite).
    @discardableResult
    private func openLabs(_ app: XCUIApplication) -> Bool {
        let tile = app.buttons["mode_openings"]
        if tile.waitForExistence(timeout: 10) {
            tile.tap()
            return true
        }
        let row = sidebarRow(app)
        guard row.waitForExistence(timeout: 10) else { return false }
        row.tap()
        return true
    }

    /// L'entrée de barre latérale, telle que XCUITest la VOIT : un
    /// `StaticText` dans une cellule, et non un bouton — une `List(selection:)`
    /// SwiftUI n'expose pas ses rangées comme des boutons, et l'identifiant
    /// posé sur le `Label` atterrit sur son texte.
    private func sidebarRow(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["sidebar_openings"]
    }

    /// Existe-t-il un point d'entrée vers Labs, dans l'une ou l'autre ossature ?
    private func labsEntryExists(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        app.buttons["mode_openings"].waitForExistence(timeout: timeout)
            || sidebarRow(app).exists
    }

    /// Le module a un point d'entrée, dans l'une comme dans l'autre ossature.
    ///
    /// Il était opt-in derrière un interrupteur de réglages tant que l'ancien
    /// module tenait la place ; depuis le 23/08 il EST le module Ouvertures,
    /// et sa tuile est celle de l'accueil.
    func testTheModuleHasAHomeEntryPoint() {
        let app = launchWithLabs()
        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 15))
        XCTAssertTrue(labsEntryExists(app, timeout: 15),
                      "aucun point d'entrée vers les Ouvertures")
    }

    /// Le parcours du prompt : choisir une ouverture, arriver sur l'index des
    /// lignes, taper un coup au milieu d'une variante, atterrir dessus.
    func testJumpingFromTheLineIndexLandsOnThePosition() {
        let app = launchWithLabs()

        XCTAssertTrue(openLabs(app), "aucun point d'entrée vers Labs")
        capture(app, "01-labs-list")

        // La liste est triée par nom et paresseuse : on défile jusqu'à
        // l'entrée voulue avant d'exiger son existence (même précaution que
        // `OpeningReaderScreenshotUITests`).
        let entry = app.buttons["opening_scandinavian"]
        var scrolls = 0
        while !(entry.exists && entry.isHittable) && scrolls < 15 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()

        // L'index s'ouvre TOUT SEUL à l'arrivée — « au moment du choix du type
        // d'ouverture, je souhaite avoir un écran (index ouvertures) ».
        let close = app.buttons["openingIndex_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10),
                      "l'index doit s'ouvrir de lui-même en entrant dans l'ouverture")
        capture(app, "02-labs-index")

        // Chaque coup de chaque ligne est un bouton : on en prend un PROFOND
        // (pas le premier), c'est le saut que le prompt demande.
        let deepMove = firstMoveChip(in: app, minimumPly: 5)
        XCTAssertNotNil(deepMove, "aucun coup profond trouvé dans l'index")
        deepMove?.tap()

        // On a atterri sur le lecteur, à une position déjà avancée.
        XCTAssertTrue(app.buttons["reader_prev"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["reader_prev"].isEnabled,
                      "« Précédent » actif : on n'est pas retombé sur la position de départ")
        capture(app, "03-labs-reader")

        // L'index se ROUVRE par l'icône de la barre d'outils.
        let reopen = app.buttons["opening_openIndex"]
        XCTAssertTrue(reopen.waitForExistence(timeout: 5))
        reopen.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 10), "l'index doit pouvoir se rouvrir")
        capture(app, "04-labs-index-reopened")
    }

    /// Le lecteur montre bien les trois sections de données du prompt.
    func testTheReaderShowsMastersAndEngine() {
        let app = launchWithLabs()
        XCTAssertTrue(openLabs(app), "aucun point d'entrée vers Labs")

        let entry = app.buttons["opening_scandinavian"]
        var scrolls = 0
        while !(entry.exists && entry.isHittable) && scrolls < 15 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()

        let close = app.buttons["openingIndex_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()

        // Position de départ : c'est celle qui a le plus de parties de maîtres.
        let masters = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'opening_master_'")
        )
        let engine = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'opening_engine_'")
        )
        let repertoire = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'opening_repertoire_'")
        )

        XCTAssertTrue(app.buttons["reader_next"].waitForExistence(timeout: 10))
        XCTAssertGreaterThan(repertoire.count, 0, "les coups du répertoire manquent")
        XCTAssertGreaterThan(masters.count, 0, "les coups de maîtres manquent")
        XCTAssertLessThanOrEqual(engine.count, 3, "le prompt dit « maximum 3 » coups de Stockfish")
        capture(app, "05-labs-sections")
    }

    /// La disposition demandée pour iPad et Mac : « à droite si on est en mode
    /// paysage ou dessous si en mode portrait ».
    ///
    /// On la mesure par la GÉOMÉTRIE, pas par la famille d'appareil : la barre
    /// d'évaluation est collée sous le plateau, les lignes du répertoire sont
    /// en tête du panneau. En portrait le panneau est SOUS le plateau, en
    /// paysage il est À DROITE.
    ///
    /// IGNORÉ sur iPhone : la cible y est verrouillée en portrait
    /// (`INFOPLIST_KEY_UISupportedInterfaceOrientations`), la rotation n'a donc
    /// aucun effet et l'échec ne dirait rien de la mise en page. On le CONSTATE
    /// après avoir tourné, plutôt que de deviner la famille d'appareil.
    func testTheReadingPanelSitsBesideTheBoardInLandscape() throws {
        let app = launchWithLabs()
        defer { XCUIDevice.shared.orientation = .portrait }

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(openLabs(app), "aucun point d'entrée vers Labs")
        openScandinavianReader(app)

        let evalBar = app.otherElements["opening_evalBar"]
        XCTAssertTrue(evalBar.waitForExistence(timeout: 10))
        let panelRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'opening_repertoire_'")
        ).firstMatch
        XCTAssertTrue(panelRow.waitForExistence(timeout: 10))

        // Portrait : le panneau commence SOUS la barre d'évaluation.
        XCTAssertGreaterThan(panelRow.frame.minY, evalBar.frame.maxY,
                             "en portrait, le panneau doit être sous le plateau")
        capture(app, "06-labs-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        RunLoop.current.run(until: Date().addingTimeInterval(2))

        try XCTSkipUnless(
            app.frame.width > app.frame.height,
            "appareil verrouillé en portrait : la disposition paysage ne s'y produit jamais"
        )

        // Paysage : le panneau commence À DROITE du plateau. Sur un écran
        // large ET court, c'est la seule disposition qui laisse le plateau
        // entier visible.
        XCTAssertTrue(evalBar.waitForExistence(timeout: 10))
        XCTAssertTrue(panelRow.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(panelRow.frame.minX, evalBar.frame.maxX - 1,
                             "en paysage, le panneau doit être à droite du plateau")
        capture(app, "07-labs-landscape")
    }

    /// Le module tient-il à la plus grande taille de texte ?
    ///
    /// L'index est l'écran le plus dense de l'app : des centaines de pastilles
    /// dans un arbre indenté. C'est là que Dynamic Type casse en premier, et
    /// c'est là qu'on doit le vérifier plutôt que de l'espérer. On ne mesure
    /// pas l'esthétique — on exige que la NAVIGATION survive : les coups
    /// restent tappables, et taper mène toujours à la position.
    func testTheModuleSurvivesTheLargestTextSize() throws {
        let app = launchWithLabs(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")

        XCTAssertTrue(openLabs(app), "aucun point d'entrée vers Labs en AX5")

        // À la plus grande taille, faire défiler cinquante-huit cartes devient
        // long : la RECHERCHE est le chemin praticable. Elle n'est pas exposée
        // de la même façon selon l'ossature (barre de navigation sur iPad), on
        // se rabat donc sur le défilement — ce qu'un lecteur ferait aussi.
        let entry = app.buttons["opening_scandinavian"]
        let field = app.searchFields.firstMatch
        if field.waitForExistence(timeout: 5) {
            field.tap()
            field.typeText("scandinav")
        } else {
            var scrolls = 0
            while !(entry.exists && entry.isHittable) && scrolls < 40 {
                app.swipeUp()
                scrolls += 1
            }
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 10),
                      "l'ouverture reste inatteignable en AX5")
        entry.tap()

        XCTAssertTrue(app.buttons["openingIndex_close"].waitForExistence(timeout: 10),
                      "l'index ne s'ouvre pas en AX5")
        capture(app, "08-labs-index-AX5")

        // Les pastilles restent des boutons, et restent atteignables — au
        // besoin après un défilement, comme le ferait un lecteur.
        var chip = firstMoveChip(in: app, minimumPly: 1)
        var scrolled = 0
        while chip == nil && scrolled < 4 {
            app.swipeUp()
            scrolled += 1
            chip = firstMoveChip(in: app, minimumPly: 1)
        }
        XCTAssertNotNil(chip, "plus aucune pastille tappable en AX5, même après défilement")
        XCTAssertLessThanOrEqual(scrolled, 1,
                                 "il faut \(scrolled) balayages pour atteindre l'arbre en AX5 : l'en-tête l'enterre")
        chip?.tap()
        XCTAssertTrue(app.buttons["reader_next"].waitForExistence(timeout: 10),
                      "le saut depuis l'index ne fonctionne plus en AX5")
        capture(app, "09-labs-reader-AX5")
    }

    /// Les pastilles de coups doivent rester CONFORTABLES au doigt.
    ///
    /// La cible de 44 pt des HIG n'est pas tenable telle quelle dans un arbre
    /// de variantes — à 44 pt par pastille, la scandinave ferait quatre mille
    /// points de haut. On mesure donc ce qu'on tient réellement, et on le
    /// verrouille : sous 24 pt, la pastille redevient un piège à doigts.
    func testMoveChipsStayComfortablyTappable() throws {
        let app = launchWithLabs()
        XCTAssertTrue(openLabs(app))
        let entry = app.buttons["opening_scandinavian"]
        var scrolls = 0
        while !(entry.exists && entry.isHittable) && scrolls < 15 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.buttons["openingIndex_close"].waitForExistence(timeout: 10))

        let chips = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'openingIndex_move_'")
        )
        var measured = 0
        for index in 0..<min(chips.count, 25) {
            let chip = chips.element(boundBy: index)
            guard chip.exists, chip.isHittable else { continue }
            XCTAssertGreaterThanOrEqual(
                chip.frame.height, 24,
                "pastille de \(chip.frame.height) pt de haut : trop petite au doigt"
            )
            measured += 1
        }
        XCTAssertGreaterThan(measured, 5, "trop peu de pastilles mesurées")
    }

    // MARK: Outils

    /// Ouvre la scandinave dans le lecteur, index refermé.
    private func openScandinavianReader(_ app: XCUIApplication) {
        let entry = app.buttons["opening_scandinavian"]
        var scrolls = 0
        while !(entry.exists && entry.isHittable) && scrolls < 15 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        let close = app.buttons["openingIndex_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
    }

    /// Le premier coup de l'index dont le demi-coup atteint `minimumPly` —
    /// l'identifiant porte ce numéro (`openingIndex_move_<ply>_<uci>`).
    private func firstMoveChip(in app: XCUIApplication, minimumPly: Int) -> XCUIElement? {
        let chips = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'openingIndex_move_'")
        )
        // BORNÉ : l'arbre compte plusieurs centaines de pastilles, et les
        // interroger toutes prenait des minutes aux tailles d'accessibilité.
        // Les premières visibles suffisent — c'est ce qu'un lecteur touche.
        for index in 0..<min(chips.count, 40) {
            let chip = chips.element(boundBy: index)
            guard chip.exists, chip.isHittable else { continue }
            let parts = chip.identifier.split(separator: "_")
            guard parts.count >= 4, let ply = Int(parts[2]), ply >= minimumPly else { continue }
            return chip
        }
        return nil
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
