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

    /// L'autre standard universel, tonalité froide (proche du bleu Lichess).
    static let blue = BoardTheme(
        id: "blue",
        label: "Bleu",
        lightSquare: Color(red: 0.86, green: 0.89, blue: 0.92),
        darkSquare: Color(red: 0.42, green: 0.55, blue: 0.69),
        lastMoveLight: Color(red: 0.62, green: 0.82, blue: 0.96).opacity(0.85),
        lastMoveDark: Color(red: 0.28, green: 0.52, blue: 0.78).opacity(0.85),
        checkColor: Color.red.opacity(0.75),
        selectedColor: Color.orange.opacity(0.38),
        legalDotColor: Color.black.opacity(0.28),
        coordinateColor: Color.black.opacity(0.45)
    )

    /// Accessibilité : contraste de luminance renforcé entre les cases (utile
    /// à tous, en particulier en basse vision) et surbrillances qui ne
    /// reposent PAS sur la distinction rouge/vert (sûres pour le daltonisme) —
    /// dernier coup en ambre, sélection en bleu vif.
    static let contrast = BoardTheme(
        id: "contrast",
        label: "Contraste élevé",
        lightSquare: Color(red: 0.96, green: 0.96, blue: 0.93),
        darkSquare: Color(red: 0.20, green: 0.24, blue: 0.31),
        lastMoveLight: Color(red: 0.99, green: 0.85, blue: 0.32).opacity(0.90),
        lastMoveDark: Color(red: 0.85, green: 0.66, blue: 0.12).opacity(0.90),
        checkColor: Color(red: 0.95, green: 0.24, blue: 0.30).opacity(0.85),
        selectedColor: Color(red: 0.20, green: 0.55, blue: 0.98).opacity(0.45),
        legalDotColor: Color(red: 0.45, green: 0.45, blue: 0.45).opacity(0.65),
        coordinateColor: Color.black.opacity(0.55)
    )

    /// Volontairement COURT et curé : chaque thème a un rôle (vert familier,
    /// bleu froid, bois chaleureux, contraste accessible) plutôt qu'« une
    /// couleur de plus ». Chaque jeu de pièces doit rester lisible sur chacun.
    static let all: [BoardTheme] = [.classic, .blue, .walnut, .contrast]
}
