import XCTest

/// Les tuiles de l'accueil rangées sous « Plus » (Deux joueurs, Finales, Visualisation, Variantes, Laboratoire)
/// vivent dans une grille PARESSEUSE : depuis le passage à trois colonnes (18/11/2026), elles n'existent qu'une fois
/// l'accueil défilé jusqu'à elles. Un `waitForExistence` suivi d'un `tap` ne suffit plus — sept tests en sont
/// tombés. Sur iPad et Mac, les modes sont aussi des lignes de la barre latérale, sans cet identifiant : on se replie
/// alors sur leur libellé (`sidebarLabel`).
@MainActor
enum HomeTiles {

    /// Ouvre la tuile `id` en faisant défiler l'accueil ; rend `false` si ni tuile ni ligne latérale n'est trouvée.
    @discardableResult
    static func open(_ id: String, sidebarLabel: String? = nil, in app: XCUIApplication) -> Bool {
        let tile = app.buttons[id]
        // L'accueil d'abord : sa première tuile, ou celle qu'on cherche si elle est déjà là.
        _ = app.buttons["mode_play"].waitForExistence(timeout: 20) || tile.waitForExistence(timeout: 2)
        let sidebar: [XCUIElement] = sidebarLabel.map {
            [app.buttons[$0], app.cells[$0], app.staticTexts[$0]]
        } ?? []
        for _ in 0..<8 {
            if tile.exists, tile.isHittable {
                tile.tap()
                return true
            }
            if let row = sidebar.first(where: { $0.exists && $0.isHittable }) {
                row.tap()
                return true
            }
            app.swipeUp(velocity: .slow)
        }
        return false
    }
}
