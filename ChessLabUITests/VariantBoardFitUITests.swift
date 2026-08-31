import XCTest

/// Non-régression du budget de hauteur des écrans de jeu des variantes.
///
/// ## Ce que ces tests attrapent
///
/// Les cinq écrans de jeu des variantes fixaient le côté du plateau à
/// `hauteur × 0,62` sans compter les rangées empilées autour — bandeaux
/// joueurs, barre de contrôle, bande des coups — et sans `ScrollView` pour
/// rattraper. Dès que ces rangées dépassaient les 38 % restants, la pile
/// débordait par le bas : la barre de contrôle et la bande des coups
/// passaient sous le pli, où, faute de défilement, elles disparaissaient
/// pour de bon. Abandonner une partie devenait impossible.
///
/// Le défaut a été trouvé à l'œil sur une fenêtre Mac à sa taille minimale,
/// pas par la suite de tests : ``LayoutProbe`` ne savait alors mesurer que
/// les débordements de LARGEUR. Ces tests ferment ce trou.
///
/// ## Ce que ces tests prouvent, et ce qu'ils ne prouvent pas
///
/// **Honnêteté sur leur portée** : ils n'ont PAS été vus échouer sur le code
/// fautif, faute de pouvoir reproduire la géométrie qui le faisait craquer.
/// Trois tentatives, toutes documentées ici pour éviter de les refaire :
///
/// - iPhone en portrait : la hauteur n'y est jamais la contrainte — le
///   plateau est borné par la LARGEUR (404 pt pour 926 pt de haut sur un
///   14 Plus), donc `hauteur × 0,62` ne mordait pas. Et l'iPhone est
///   verrouillé en portrait (Lot 2), donc pas de paysage de secours.
/// - iPad 11" en paysage AX5 : mesuré plateau 451 pt, bas à 658 pt pour une
///   fenêtre de 834 pt — l'ancien calcul y tenait encore, de justesse.
/// - iPad mini en paysage AX5 : le module Variantes n'y est plus atteignable
///   par XCUITest à cette taille de texte, le test s'arrête avant de mesurer.
///
/// Ce qui manquait à la fenêtre Mac (820 × 680 pt, soit ~32 % de la hauteur
/// mangés par les rangées fixes) n'existe sur aucun simulateur disponible.
///
/// Ils gardent donc l'INVARIANT — plateau et barre de contrôle tiennent tous
/// deux dans la fenêtre d'un écran sans défilement — plutôt que le cas
/// précis. C'est déjà ce qui manquait : le défaut a été trouvé à l'œil, et
/// aucun test ne l'aurait signalé, ``LayoutProbe`` ne sachant alors mesurer
/// que les débordements de LARGEUR.
@MainActor
final class VariantBoardFitUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        // `tearDown()` reste non-isolé (signature héritée d'XCTestCase),
        // mais XCTest l'exécute sur le fil principal : l'affirmation est
        // sûre, et remettre l'orientation ne mérite pas une version async.
        MainActor.assumeIsolated {
            XCUIDevice.shared.orientation = .portrait
        }
        super.tearDown()
    }

    /// Le bouton d'abandon est le dernier élément de la barre de contrôle,
    /// donc le premier à sombrer quand la pile déborde : c'est la sentinelle.
    private static let sentinelLabel = "Abandonner"

    /// Ouvre le module Variantes depuis l'accueil, quel que soit le squelette.
    ///
    /// iPhone : une tuile portant `mode_variants`. iPad et Mac : une rangée de
    /// la barre latérale, qui n'a pas cet identifiant — d'où le repli sur le
    /// libellé, le même que celui des tests de captures d'écran.
    @MainActor
    private func openVariants(_ app: XCUIApplication) -> Bool {
        let tile = app.buttons["mode_variants"]
        if tile.waitForExistence(timeout: 8), tile.isHittable {
            tile.tap()
            return true
        }
        for candidate in [app.buttons["Variantes"], app.cells["Variantes"], app.staticTexts["Variantes"]] {
            guard candidate.waitForExistence(timeout: 4) else { continue }
            for _ in 0..<4 {
                if candidate.isHittable {
                    candidate.tap()
                    return true
                }
                app.swipeUp()
                RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            }
        }
        return false
    }

    @MainActor
    private func launchInVariant(
        _ app: XCUIApplication, tile: String, contentSize: String?, landscape: Bool
    ) throws {
        if landscape {
            try XCTSkipUnless(
                UIDevice.current.userInterfaceIdiom == .pad,
                "Le paysage n'existe que sur iPad — l'iPhone est verrouillé en portrait (Lot 2)"
            )
        }
        // La navigation se fait TOUJOURS en portrait, puis on pivote une fois
        // la partie lancée : en paysage AX5, la barre latérale ne se laisse pas
        // atteindre de façon fiable, et surtout pivoter APRÈS reproduit ce que
        // fait un utilisateur Mac — il redimensionne une fenêtre déjà ouverte.
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments += ["-resetPlaySettings"]
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()

        XCTAssertTrue(openVariants(app), "le module Variantes doit être atteignable")

        XCTAssertTrue(app.buttons[tile].waitForExistence(timeout: 10), "la tuile \(tile) doit exister")
        app.buttons[tile].tap()

        let start = app.buttons["fairyVariant_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        // En AX5, le bouton peut être passé sous le pli de l'écran de réglages
        // (qui, LUI, défile — c'est légitime).
        for _ in 0..<4 where !start.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        start.tap()

        XCTAssertTrue(app.otherElements["square_a8"].waitForExistence(timeout: 15), "le plateau doit apparaître")
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        if landscape {
            XCUIDevice.shared.orientation = .landscapeLeft
            // La rotation n'est pas instantanée : on attend que la fenêtre soit
            // réellement plus large que haute avant de mesurer quoi que ce soit.
            let deadline = Date().addingTimeInterval(10)
            while Date() < deadline, app.frame.width <= app.frame.height {
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
            XCTAssertGreaterThan(app.frame.width, app.frame.height, "la fenêtre doit être passée en paysage")
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        }
    }

    /// Le cœur du garde-fou : plateau ET barre de contrôle tiennent tous deux
    /// dans la fenêtre, sur un écran qui n'offre aucun défilement.
    @MainActor
    private func assertPlayScreenFits(_ app: XCUIApplication, context: String) throws {
        guard let board = LayoutProbe.boardRect(in: app) else {
            return XCTFail("plateau introuvable — \(context)")
        }
        let window = app.frame

        XCTAssertLessThanOrEqual(
            board.maxY, window.maxY + 0.5,
            "le plateau déborde de \(board.maxY - window.maxY) pt sous la fenêtre — \(context)"
        )

        let resign = app.buttons[Self.sentinelLabel]
        LayoutProbe.assertNoVerticalClipping(
            of: resign, named: "le bouton « \(Self.sentinelLabel) »", in: app, context: context
        )

        // Le relevé part dans le journal : c'est lui qui a permis de constater
        // que le plateau reste pleine largeur là où il y a la place.
        print(String(
            format: "VARIANT-FIT|%@|plateau=%.1f|bas plateau=%.1f|bas fenêtre=%.1f",
            context, min(board.width, board.height), board.maxY, window.maxY
        ))
    }

    /// Portrait, taille par défaut — le cas nominal, où le plateau est borné
    /// par la largeur. Ne prouve rien sur le budget de hauteur : il est là
    /// pour attraper une régression qui casserait le cas facile.
    @MainActor
    func testHordeFitsInPortrait() throws {
        let app = XCUIApplication()
        try launchInVariant(app, tile: "variant_horde", contentSize: nil, landscape: false)
        try assertPlayScreenFits(app, context: "Horde, portrait, taille par défaut")
    }

    /// **Le vrai garde-fou** : paysage + AX5, les deux conditions réunies.
    /// Sans le budget de hauteur, la barre de contrôle passe sous le pli.
    @MainActor
    func testHordeFitsInLandscapeAtAccessibilityXXXL() throws {
        let app = XCUIApplication()
        try launchInVariant(
            app, tile: "variant_horde",
            contentSize: "UICTContentSizeCategoryAccessibilityXXXL", landscape: true
        )
        try assertPlayScreenFits(app, context: "Horde, paysage, AX5")
    }

    /// Roi de la colline dans les mêmes conditions : même pile, autre
    /// variante — de quoi prouver que le budget vaut pour la famille et pas
    /// pour un écran en particulier.
    @MainActor
    func testKingOfTheHillFitsInLandscapeAtAccessibilityXXXL() throws {
        let app = XCUIApplication()
        try launchInVariant(
            app, tile: "variant_kingofthehill",
            contentSize: "UICTContentSizeCategoryAccessibilityXXXL", landscape: true
        )
        try assertPlayScreenFits(app, context: "Roi de la colline, paysage, AX5")
    }
}
