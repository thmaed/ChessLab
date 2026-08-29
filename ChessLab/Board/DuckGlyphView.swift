import SwiftUI

/// Le canard jaune du Duck Chess, dessiné en VECTORIEL.
///
/// Pas l'emoji 🦆 (un colvert brun-vert, méconnaissable en petit et étranger
/// au style plat de l'app), pas une image du web non plus — ses droits sont
/// incertains et un bitmap se salit en grandissant. Un canard de bain tracé à
/// la main : net à toutes les tailles, du plateau d'iPhone SE (case de 47 pt)
/// à une fenêtre Mac en plein écran (case de ~190 pt).
///
/// Tout est en coordonnées NORMALISÉES (0…1) puis mis à l'échelle : les
/// proportions tiennent quelle que soit la case.
struct DuckGlyphView: View {
    /// Silhouette claire derrière le canard, pour le détacher d'une case
    /// jaune clair — sans elle, il s'y fondrait presque.
    var outlined: Bool = true

    private let body_ = Color(red: 1.0, green: 0.82, blue: 0.16)
    private let bodyShade = Color(red: 0.96, green: 0.70, blue: 0.09)
    private let beak = Color(red: 0.97, green: 0.55, blue: 0.11)
    private let eye = Color(red: 0.13, green: 0.11, blue: 0.09)

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
                CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
            }

            // Contour : les mêmes formes, légèrement gonflées, en sombre.
            if outlined {
                var halo = Path()
                halo.addEllipse(in: r(0.06, 0.44, 0.78, 0.50))
                halo.addEllipse(in: r(0.46, 0.10, 0.44, 0.44))
                context.fill(halo, with: .color(.black.opacity(0.28)))
            }

            // Queue — un triangle relevé à l'arrière, c'est lui qui fait lire
            // « canard » plutôt que « poussin ».
            var tail = Path()
            tail.move(to: p(0.20, 0.62))
            tail.addLine(to: p(0.02, 0.44))
            tail.addLine(to: p(0.17, 0.76))
            tail.closeSubpath()
            context.fill(tail, with: .color(bodyShade))

            // Corps.
            context.fill(Path(ellipseIn: r(0.09, 0.47, 0.72, 0.44)), with: .color(body_))
            // Ombre basse, pour un peu de volume.
            context.fill(
                Path(ellipseIn: r(0.16, 0.72, 0.56, 0.19)),
                with: .color(bodyShade.opacity(0.55))
            )

            // Tête.
            context.fill(Path(ellipseIn: r(0.49, 0.13, 0.38, 0.38)), with: .color(body_))

            // Bec, vers la droite.
            var bill = Path()
            bill.move(to: p(0.84, 0.28))
            bill.addLine(to: p(1.00, 0.33))
            bill.addLine(to: p(0.84, 0.40))
            bill.closeSubpath()
            context.fill(bill, with: .color(beak))

            // Œil.
            context.fill(Path(ellipseIn: r(0.68, 0.24, 0.075, 0.075)), with: .color(eye))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
