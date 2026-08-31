import XCTest

/// Ce que l'accueil iPad offre RÉELLEMENT au lancement (Lot 0, diagnostic
/// 4.1) — inventaire, pas jugement : on imprime les éléments interactifs
/// visibles en portrait puis en paysage, et on compte les points d'entrée
/// vers les six modes.
///
/// Motivation : le relevé du plateau sur iPad Pro 11" a échoué faute de
/// trouver « Contre l'ordinateur » à l'écran. Plutôt que de contourner par
/// une navigation plus futée, on mesure ce que voit l'utilisateur.
@MainActor
final class IPadEntryPointsUITests: XCTestCase {

    private static let modes = [
        "Contre l'ordinateur", "Deux joueurs", "Puzzles",
        "Ouvertures", "Analyser", "Laboratoire",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testReportHomeEntryPoints() throws {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "?"

        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()
        _ = app.staticTexts["ChessLab"].waitForExistence(timeout: 15)
        report(app, device: device, orientation: "portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        report(app, device: device, orientation: "paysage")

        XCUIDevice.shared.orientation = .portrait
    }

    /// Géométrie des SIX tuiles de la grille d'accueil.
    ///
    /// Deux d'entre elles se déclarent plus larges que leur colonne, et
    /// toujours des mêmes 17,5 et 6,5 pt — insensibles à tout ce qu'on fait
    /// au fond décoratif. Ce relevé sert à trancher : est-ce la grille qui
    /// déborde vraiment, ou une `frame` d'accessibilité qui ment ?
    @MainActor
    func testReportModeTileFrames() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()
        _ = app.staticTexts["ChessLab"].waitForExistence(timeout: 15)

        let window = app.frame
        for mode in Self.modes {
            let button = app.buttons[mode]
            guard button.exists else { continue }
            print(
                String(
                    format: "TILE|%@|x=[%.1f…%.1f] largeur=%.1f|y=[%.1f…%.1f]|fenêtre=%.0f",
                    mode, button.frame.minX, button.frame.maxX, button.frame.width,
                    button.frame.minY, button.frame.maxY, window.width
                )
            )
        }
        // Et les textes qu'elles contiennent : si c'est le TITRE qui déborde,
        // il le dira lui-même.
        for label in ["Deux joueurs", "Ouvertures", "Sur le même appareil"] {
            let text = app.staticTexts[label]
            guard text.exists else { continue }
            print(
                String(
                    format: "TILE-TEXT|%@|x=[%.1f…%.1f] largeur=%.1f",
                    label, text.frame.minX, text.frame.maxX, text.frame.width
                )
            )
        }
    }

    @MainActor
    private func report(_ app: XCUIApplication, device: String, orientation: String) {
        let window = app.frame
        var reachable: [String] = []
        for mode in Self.modes {
            // « Exister » dans la hiérarchie ne suffit pas : un élément hors
            // cadre existe aussi. On exige une frame non vide, RÉELLEMENT
            // dans la fenêtre — c'est la question posée par le diagnostic 4.1
            // (« l'utilisateur voit-il un point d'entrée ? »).
            let candidates = [app.buttons[mode], app.cells[mode], app.staticTexts[mode]]
            guard let visible = candidates.first(where: { element in
                guard element.exists else { return false }
                let frame = element.frame
                return frame.width > 0 && frame.height > 0 && window.intersects(frame)
            }) else { continue }
            reachable.append(mode)
            print(
                String(
                    format: "ENTRY-FRAME|%@|%@|%@|x=[%.1f…%.1f] y=[%.1f…%.1f] fenêtre=%.0fx%.0f",
                    device, orientation, mode,
                    visible.frame.minX, visible.frame.maxX,
                    visible.frame.minY, visible.frame.maxY,
                    window.width, window.height
                )
            )
        }
        print("ENTRY|\(device)|\(orientation)|modes visibles=\(reachable.count)/6|\(reachable.joined(separator: ","))")

        // Ce qui EST à l'écran, pour comprendre ce qui remplace la grille.
        let labels = app.buttons.allElementsBoundByAccessibilityElement
            .filter { $0.frame.width > 0 }
            .map { $0.identifier.isEmpty ? $0.label : $0.identifier }
            .filter { !$0.isEmpty }
        print("ENTRY-BUTTONS|\(device)|\(orientation)|\(labels.prefix(20).joined(separator: " · "))")
    }
}
