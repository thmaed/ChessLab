import SwiftUI

/// Thème visuel de l'échiquier. Les couleurs des cases restent volontairement
/// indépendantes du mode sombre du système (comme la plupart des apps
/// d'échecs) ; c'est le reste de l'interface qui s'adapte.
struct BoardTheme: Identifiable, Equatable {
    let id: String
    let label: String
    let lightSquare: Color
    let darkSquare: Color
    let lastMoveLight: Color
    let lastMoveDark: Color
    let checkColor: Color
    let selectedColor: Color
    let legalDotColor: Color
    let coordinateColor: Color

    static let classic = BoardTheme(
        id: "classic",
        label: "Classique",
        lightSquare: Color(red: 0.93, green: 0.90, blue: 0.82),
        darkSquare: Color(red: 0.46, green: 0.59, blue: 0.34),
        lastMoveLight: Color(red: 0.98, green: 0.90, blue: 0.45).opacity(0.85),
        lastMoveDark: Color(red: 0.75, green: 0.68, blue: 0.20).opacity(0.85),
        checkColor: Color.red.opacity(0.75),
        selectedColor: Color.blue.opacity(0.35),
        legalDotColor: Color.black.opacity(0.28),
        coordinateColor: Color.black.opacity(0.45)
    )

    static let walnut = BoardTheme(
        id: "walnut",
        label: "Noyer",
        lightSquare: Color(red: 0.87, green: 0.72, blue: 0.53),
        darkSquare: Color(red: 0.55, green: 0.36, blue: 0.20),
        lastMoveLight: Color(red: 0.96, green: 0.80, blue: 0.35).opacity(0.85),
        lastMoveDark: Color(red: 0.70, green: 0.55, blue: 0.10).opacity(0.85),
        checkColor: Color.red.opacity(0.75),
        selectedColor: Color.blue.opacity(0.35),
        legalDotColor: Color.black.opacity(0.28),
        coordinateColor: Color.black.opacity(0.45)
    )

    static let slate = BoardTheme(
        id: "slate",
        label: "Ardoise",
        lightSquare: Color(red: 0.80, green: 0.82, blue: 0.85),
        darkSquare: Color(red: 0.35, green: 0.40, blue: 0.46),
        lastMoveLight: Color(red: 0.55, green: 0.75, blue: 0.95).opacity(0.85),
        lastMoveDark: Color(red: 0.25, green: 0.50, blue: 0.75).opacity(0.85),
        checkColor: Color.red.opacity(0.75),
        selectedColor: Color.orange.opacity(0.35),
        legalDotColor: Color.black.opacity(0.28),
        coordinateColor: Color.black.opacity(0.45)
    )

    static let all: [BoardTheme] = [.classic, .walnut, .slate]
}
