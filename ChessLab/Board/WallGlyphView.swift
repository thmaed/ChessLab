import SwiftUI

/// La case murée de Barricades, dessinée en VECTORIEL.
///
/// Un mur de briques plutôt qu'une case grisée : sur un thème de plateau
/// clair comme sur un thème sombre, une simple teinte se confondrait avec une
/// case ordinaire, alors que l'appareillage des briques se lit d'un coup
/// d'œil et à toutes les tailles — de la case de 47 pt d'un iPhone SE aux
/// ~190 pt d'une fenêtre Mac en plein écran.
///
/// Coordonnées NORMALISÉES (0…1) puis mises à l'échelle, comme
/// ``DuckGlyphView`` : les proportions tiennent quelle que soit la case.
struct WallGlyphView: View {

    private let mortar = Color(red: 0.24, green: 0.22, blue: 0.21)
    private let brick = Color(red: 0.47, green: 0.34, blue: 0.29)
    private let brickLight = Color(red: 0.56, green: 0.41, blue: 0.35)

    /// Quatre assises, décalées d'une demi-brique une rangée sur deux.
    private static let courses = 4

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let inset = 0.04 * s
            let side = s - 2 * inset
            let courseHeight = side / CGFloat(Self.courses)

            let outline = Path(
                roundedRect: CGRect(x: inset, y: inset, width: side, height: side),
                cornerRadius: s * 0.10, style: .continuous
            )
            context.fill(outline, with: .color(mortar))

            // Les briques sont dessinées DANS le contour arrondi : sans ce
            // découpage, les briques des coins dépasseraient du joint.
            context.clip(to: outline)

            let joint = max(1, s * 0.022)
            for course in 0..<Self.courses {
                let y = inset + CGFloat(course) * courseHeight
                // Une assise sur deux commence par une demi-brique — c'est
                // ce décalage qui fait lire « mur » plutôt que « grille ».
                let offset: CGFloat = course.isMultiple(of: 2) ? 0 : -side / 4
                var x = inset + offset
                while x < inset + side {
                    let width = side / 2
                    let rect = CGRect(
                        x: x + joint / 2, y: y + joint / 2,
                        width: width - joint, height: courseHeight - joint
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: s * 0.015, style: .continuous),
                        with: .color(course.isMultiple(of: 2) ? brick : brickLight)
                    )
                    x += width
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
