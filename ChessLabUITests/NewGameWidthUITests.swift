import XCTest

/// « Nouvelle partie » doit tenir dans la largeur de l'écran, QUEL QUE SOIT l'iPhone et son affichage (Standard ou
/// « Zoomé »). Né du retour de Nils (21/11/2026) : sur un iPhone en affichage zoomé (320 ou 375 pt), la carte de
/// l'adversaire ne dispose que de 319 pt (375 − 2 × 16 − 2 × 12) et la grille de jauges, à largeurs fixes (342 pt),
/// rognait « Attaque » et « Niveau » de chaque côté.
///
/// Ne réinitialise RIEN (pas de `-resetPlaySettings`) : peut tourner sur un vrai téléphone. La mesure repose sur les
/// `frame` d'accessibilité (``LayoutProbe``) ; la capture n'est jointe que pour l'œil.
@MainActor
final class NewGameWidthUITests: XCTestCase {

    func testNewGameFitsTheScreenWidth() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-AppleLanguages", "(fr)", "-openRoute", "newGame"]
        app.launch()

        let traits = try LayoutProbe.traits(in: app)
        print("NEWGAME|fenêtre \(traits.size.width) × \(traits.size.height) pt, zone sûre \(traits.safeSize.width)")

        let gauges = app.descendants(matching: .any).matching(identifier: "opponentTraits").firstMatch
        XCTAssertTrue(gauges.waitForExistence(timeout: 15), "les jauges de l'adversaire doivent s'afficher")
        let window = app.windows.firstMatch.frame
        print("NEWGAME|jauges \(gauges.frame)")
        XCTAssertGreaterThanOrEqual(gauges.frame.minX, window.minX - 0.5, "les jauges sortent par la gauche")
        XCTAssertLessThanOrEqual(gauges.frame.maxX, window.maxX + 0.5, "les jauges sortent par la droite")

        // La bande des portraits DÉFILE : un portrait à moitié sorti du bord est normal, pas un défaut.
        let overflows = LayoutProbe.horizontalOverflows(in: app).filter { overflow in
            let name = overflow.identifier.isEmpty ? overflow.label : overflow.identifier
            return !name.hasPrefix("opponentTile_") && !name.hasPrefix("avatar_") && name != "stockfishPortrait"
        }
        for overflow in overflows { print("NEWGAME|débordement \(overflow)") }
        XCTAssertTrue(overflows.isEmpty, "éléments hors de l'écran : \(overflows.map(\.description))")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "nouvelle-partie-\(Int(traits.size.width))pt"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
