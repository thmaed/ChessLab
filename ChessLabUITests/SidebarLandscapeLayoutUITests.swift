import XCTest

/// Ce que devient la colonne de détail quand la barre latérale est là, sur un
/// iPad en paysage.
///
/// Motif : un testeur sur iPad Pro 13" (iPadOS 26.6) rapporte que « parfois,
/// pas toujours », en paysage et barre latérale ouverte, le reste de l'écran
/// part hors cadre à droite (27/09/2026). Le symptôme décrit une colonne de
/// détail restée à la largeur de la FENÊTRE, simplement décalée de la largeur
/// de la barre — donc dont le bord droit tombe hors de l'écran.
///
/// On mesure par les `frame` d'accessibilité, comme tout le Lot 0.2 : en
/// paysage, une capture d'écran de simulateur sort tournée dans un cadre resté
/// portrait et ne prouve rien.
@MainActor
final class SidebarLandscapeLayoutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    /// Chaque entrée de la barre latérale, en paysage : rien ne doit sortir du
    /// cadre. On les parcourt toutes parce que le testeur dit « parfois » —
    /// c'est donc d'un écran en particulier qu'il s'agit, pas de l'ossature.
    func testNoDetailScreenOverflowsWithTheSidebarInLandscape() throws {
        let app = launchInLandscape()
        let traits = try LayoutProbe.traits(in: app, waitingForLandscape: true)
        try XCTSkipUnless(
            traits.horizontalSizeClass == "regular",
            "Ossature barre latérale + détail : iPad plein écran seulement"
        )
        print(traits.logLine(device: device, orientation: "paysage"))

        for entry in Self.sidebarEntries {
            guard let row = sidebarRow(entry, in: app) else {
                XCTFail("Entrée « \(entry) » absente de la barre latérale")
                continue
            }
            row.tap()
            // Laisse la colonne de détail se poser avant de la mesurer.
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))
            report(app, screen: entry)
            LayoutProbe.assertNoHorizontalOverflow(
                in: app, context: "détail « \(entry) », paysage, barre latérale ouverte",
                ignoring: Self.systemArtifacts
            )
        }
    }

    /// Le même écran, mais après une ROTATION : c'est le moment où une colonne
    /// de détail peut garder la largeur qu'elle avait en portrait.
    func testDetailIsRelaidOutAfterRotatingWithTheSidebarOpen() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen"]
        app.launch()

        let portrait = try LayoutProbe.traits(in: app, waitingForLandscape: false)
        try XCTSkipUnless(
            portrait.horizontalSizeClass == "regular",
            "Ossature barre latérale + détail : iPad plein écran seulement"
        )

        let entry = try XCTUnwrap(
            sidebarRow("Analyser", in: app), "la barre latérale doit être là"
        )
        entry.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        for turn in 1...2 {
            XCUIDevice.shared.orientation = .landscapeLeft
            _ = try LayoutProbe.traits(in: app, waitingForLandscape: true)
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))
            report(app, screen: "Analyser après rotation \(turn)")
            LayoutProbe.assertNoHorizontalOverflow(
                in: app, context: "détail « Analyser » après rotation \(turn)",
                ignoring: Self.systemArtifacts
            )

            XCUIDevice.shared.orientation = .portrait
            _ = try LayoutProbe.traits(in: app, waitingForLandscape: false)
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        }
    }

    /// La BIBLIOTHÈQUE, en paysage et barre latérale ouverte : c'est l'écran
    /// que le testeur avait sous les yeux, avec sa barre d'outils chargée
    /// (import, sélection, champ de recherche) — le meilleur candidat à un
    /// débordement par la droite.
    func testTheLibraryFitsBesideTheSidebarInLandscape() throws {
        let app = launchInLandscape(extraArguments: ["-seedLibrarySample"])
        let traits = try LayoutProbe.traits(in: app, waitingForLandscape: true)
        try XCTSkipUnless(
            traits.horizontalSizeClass == "regular",
            "Ossature barre latérale + détail : iPad plein écran seulement"
        )

        try XCTUnwrap(sidebarRow("Analyser", in: app)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        let library = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Bibliothèque")
        ).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: 10), "l'entrée « Bibliothèque » doit exister")
        library.tap()

        // On mesure la BIBLIOTHÈQUE, pas l'écran d'entrée : sans cette
        // vérification, un tap sans effet ferait passer le test sur le mauvais
        // écran — c'est arrivé.
        let importButton = app.buttons["importGames"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 10), "la bibliothèque doit s'ouvrir")
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        reportContent(app, screen: "Bibliothèque")
        LayoutProbe.assertNoHorizontalOverflow(
            in: app, context: "Bibliothèque, paysage, barre latérale ouverte",
            ignoring: Self.systemArtifacts
        )
    }

    /// La barre latérale MASQUÉE puis REMONTRÉE, en paysage : c'est le geste
    /// que décrit le testeur (« quand j'ai le menu de gauche »), et le moment
    /// où une colonne de détail peut garder la largeur de l'autre état.
    func testDetailSurvivesHidingAndShowingTheSidebar() throws {
        let app = launchInLandscape()
        let traits = try LayoutProbe.traits(in: app, waitingForLandscape: true)
        try XCTSkipUnless(
            traits.horizontalSizeClass == "regular",
            "Ossature barre latérale + détail : iPad plein écran seulement"
        )

        try XCTUnwrap(sidebarRow("Réglages", in: app)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        // Le bouton système de bascule n'a pas d'identifiant : il se nomme par
        // son libellé, qui change selon l'état de la barre.
        reportContent(app, screen: "Réglages, barre ouverte")
        for turn in 1...3 {
            let toggle = try XCTUnwrap(
                [app.buttons["Masquer la barre latérale"], app.buttons["Afficher la barre latérale"]]
                    .first { $0.exists && $0.isHittable },
                "bouton de bascule introuvable au tour \(turn)"
            )
            toggle.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
            reportContent(app, screen: "Réglages, bascule \(turn)")
            LayoutProbe.assertNoHorizontalOverflow(
                in: app, context: "Réglages après \(turn) bascule(s) de barre latérale",
                ignoring: Self.systemArtifacts
            )
        }
    }

    // MARK: Outils

    /// Vues POSÉES PAR LE SYSTÈME, pas par l'app : le voile d'assombrissement
    /// qu'UIKit glisse sous une barre latérale flottante déborde de 120 pt de
    /// chaque côté, par construction. Le mesurer n'apprendrait rien sur notre
    /// mise en page.
    private static let systemArtifacts: Set<String> = ["AdditionalDimmingOverlay"]

    private static let sidebarEntries = [
        "Contre l'ordinateur", "Deux joueurs", "Puzzles", "Ouvertures",
        "Finales", "Analyser", "Variantes", "Progression", "Réglages",
    ]

    /// La ligne de la BARRE LATÉRALE portant ce libellé.
    ///
    /// Le même mot figure souvent aussi dans la colonne de détail (le tableau
    /// de bord d'accueil montre les mêmes modes) : on prend la plus à GAUCHE,
    /// qui est nécessairement celle de la barre.
    private func sidebarRow(_ label: String, in app: XCUIApplication) -> XCUIElement? {
        let matches = app.staticTexts.matching(identifier: label)
        guard matches.firstMatch.waitForExistence(timeout: 15) else { return nil }
        return matches.allElementsBoundByIndex
            .filter { $0.exists && $0.frame.width > 0 }
            .min { $0.frame.minX < $1.frame.minX }
    }

    private var device: String {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "?"
    }

    private func launchInLandscape(extraArguments: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen"] + extraArguments
        app.launch()
        return app
    }

    /// Relevé du CONTENU : où commencent et où finissent les commandes de la
    /// colonne de détail. Sur iPadOS 26 la barre latérale flotte AU-DESSUS du
    /// détail ; si le système n'inserait pas l'encoche correspondante, le
    /// contenu de gauche disparaîtrait sous le verre.
    private func reportContent(_ app: XCUIApplication, screen: String) {
        let window = app.frame
        let sidebarBar = app.navigationBars["ChessLab"]
        let sidebar = sidebarBar.exists ? sidebarBar.frame : .zero
        print(
            String(
                format: "SIDEBAR|%@|%@|visible=%@|x=[%.1f…%.1f]|fenêtre=[%.1f…%.1f]",
                device, screen, sidebarBar.exists ? "oui" : "non",
                sidebar.minX, sidebar.maxX, window.minX, window.maxX
            )
        )
        for element in app.buttons.allElementsBoundByIndex.prefix(12) where element.exists {
            let frame = element.frame
            guard frame.width > 0 else { continue }
            print(
                String(
                    format: "CONTENU|%@|%@|%@|x=[%.1f…%.1f]",
                    device, screen, element.identifier.isEmpty ? element.label : element.identifier,
                    frame.minX, frame.maxX
                )
            )
        }
    }

    /// Relevé imprimé même quand le test passe : c'est lui qui documente où
    /// commence et où finit réellement la colonne de détail.
    private func report(_ app: XCUIApplication, screen: String) {
        let window = app.frame
        let navigationBars = app.navigationBars.allElementsBoundByIndex
        for bar in navigationBars where bar.exists {
            print(
                String(
                    format: "SPLIT|%@|%@|barre=%@|x=[%.1f…%.1f]|fenêtre=[%.1f…%.1f]",
                    device, screen, bar.identifier.isEmpty ? "?" : bar.identifier,
                    bar.frame.minX, bar.frame.maxX, window.minX, window.maxX
                )
            )
        }
    }
}
