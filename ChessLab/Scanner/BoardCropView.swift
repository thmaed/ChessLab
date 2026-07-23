import CoreGraphics
import SwiftUI

/// Ajustement manuel des quatre coins du plateau — **livrable obligatoire du
/// Lot 1.B**.
///
/// C'est le filet de sécurité de toutes les sources photo : la détection
/// automatique échouera régulièrement (plateau en bois peu contrasté avec la
/// table, reflets d'écran…), et sans reprise manuelle le scanner serait
/// inutilisable ces fois-là.
///
/// La **grille 8×8 projetée en temps réel** entre les 4 coins est ce qui
/// rend le placement précis : l'utilisateur aligne les lignes sur les
/// rangées du plateau plutôt que de viser un coin au pixel.
struct BoardCropView: View {
    let image: CGImage
    @Binding var quad: BoardQuad
    let wasDetectedAutomatically: Bool
    let onConfirm: () -> Void

    /// Coin en cours de glissement — grossi pour rester visible sous le
    /// doigt.
    @State private var draggedCorner: Corner?

    enum Corner: CaseIterable {
        case topLeft, topRight, bottomRight, bottomLeft
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(hint)
                .font(.footnote)
                .foregroundStyle(quad.isUsable ? Theme.textSecondary : Theme.danger)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

            GeometryReader { geometry in
                let transform = ImageDisplayTransform(
                    imageWidth: Double(image.width), imageHeight: Double(image.height),
                    container: geometry.size
                )

                ZStack(alignment: .topLeading) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    gridOverlay(transform: transform)
                    quadOutline(transform: transform)
                    handles(transform: transform)
                }
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(1)

            Button(action: onConfirm) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                    Text("Valider le cadrage").fontWeight(.semibold)
                }
                .foregroundStyle(quad.isUsable ? Theme.background : Theme.textTertiary)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(confirmBackground)
            }
            .buttonStyle(.pressable)
            .disabled(!quad.isUsable)
            .accessibilityIdentifier("confirmCrop")
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .appBackground()
    }

    private var hint: String {
        if !quad.isUsable {
            return "Les coins se croisent : replacez-les dans l'ordre autour du plateau."
        }
        return wasDetectedAutomatically
            ? "Plateau détecté. Ajustez les coins si besoin : les lignes de la grille doivent suivre les rangées du plateau."
            : "Plateau non détecté automatiquement. Placez les quatre coins : les lignes de la grille doivent suivre les rangées du plateau."
    }

    private var outlineColor: Color {
        quad.isUsable ? Theme.accent : Theme.danger
    }

    @ViewBuilder
    private var confirmBackground: some View {
        if quad.isUsable {
            Theme.controlShape.fill(Theme.accentGradient)
        } else {
            Theme.controlShape.fill(Theme.surfaceElevated)
        }
    }

    // MARK: Surimpressions

    /// La grille projetée. Une homographie envoie les droites sur des
    /// droites : relier les 9 points d'une rangée donne donc exactement la
    /// ligne du plateau, perspective comprise.
    private func gridOverlay(transform: ImageDisplayTransform) -> some View {
        let grid = quad.gridIntersections.map { row in row.map(transform.toView) }

        return Path { path in
            for row in 0...8 {
                path.move(to: grid[row][0])
                for column in 1...8 { path.addLine(to: grid[row][column]) }
            }
            for column in 0...8 {
                path.move(to: grid[0][column])
                for row in 1...8 { path.addLine(to: grid[row][column]) }
            }
        }
        .stroke(Theme.accent.opacity(0.55), lineWidth: 1)
        .allowsHitTesting(false)
    }

    private func quadOutline(transform: ImageDisplayTransform) -> some View {
        Path { path in
            path.addLines(quad.corners.map(transform.toView))
            path.closeSubpath()
        }
        .stroke(outlineColor, lineWidth: 2)
        .allowsHitTesting(false)
    }

    private func handles(transform: ImageDisplayTransform) -> some View {
        ForEach(Corner.allCases, id: \.self) { corner in
            let position = transform.toView(point(for: corner))

            Circle()
                .fill(outlineColor.opacity(0.28))
                .overlay(Circle().strokeBorder(outlineColor, lineWidth: 2))
                .frame(width: draggedCorner == corner ? 46 : 34)
                // Cible tactile confortable, indépendante du disque affiché.
                .contentShape(Circle().inset(by: -12))
                .position(position)
                .gesture(dragGesture(for: corner, transform: transform))
                .accessibilityIdentifier("cropHandle_\(identifier(for: corner))")
                .accessibilityLabel(label(for: corner))
        }
    }

    private func dragGesture(for corner: Corner, transform: ImageDisplayTransform) -> some Gesture {
        DragGesture()
            .onChanged { value in
                draggedCorner = corner
                let imagePoint = transform.toImage(value.location)
                setPoint(clamped(imagePoint), for: corner)
            }
            .onEnded { _ in draggedCorner = nil }
    }

    /// Un coin hors de l'image donnerait un redressement qui va lire des
    /// pixels inexistants.
    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), CGFloat(image.width)),
            y: min(max(point.y, 0), CGFloat(image.height))
        )
    }

    private func point(for corner: Corner) -> CGPoint {
        switch corner {
        case .topLeft: quad.topLeft
        case .topRight: quad.topRight
        case .bottomRight: quad.bottomRight
        case .bottomLeft: quad.bottomLeft
        }
    }

    private func setPoint(_ point: CGPoint, for corner: Corner) {
        switch corner {
        case .topLeft: quad.topLeft = point
        case .topRight: quad.topRight = point
        case .bottomRight: quad.bottomRight = point
        case .bottomLeft: quad.bottomLeft = point
        }
    }

    private func identifier(for corner: Corner) -> String {
        switch corner {
        case .topLeft: "topLeft"
        case .topRight: "topRight"
        case .bottomRight: "bottomRight"
        case .bottomLeft: "bottomLeft"
        }
    }

    private func label(for corner: Corner) -> String {
        switch corner {
        case .topLeft: "Coin haut gauche"
        case .topRight: "Coin haut droit"
        case .bottomRight: "Coin bas droit"
        case .bottomLeft: "Coin bas gauche"
        }
    }
}

/// Conversion entre pixels de l'image et points de la vue, pour une image
/// affichée en `.fit` et centrée.
///
/// Extrait comme type à part (et non calculé au fil de l'eau dans la vue)
/// parce que les deux sens doivent rester exactement inverses : une poignée
/// posée à un endroit doit revenir au même endroit.
struct ImageDisplayTransform {
    let scale: Double
    let offsetX: Double
    let offsetY: Double

    init(imageWidth: Double, imageHeight: Double, container: CGSize) {
        let widthScale = Double(container.width) / max(imageWidth, 1)
        let heightScale = Double(container.height) / max(imageHeight, 1)
        scale = min(widthScale, heightScale)
        offsetX = (Double(container.width) - imageWidth * scale) / 2
        offsetY = (Double(container.height) - imageHeight * scale) / 2
    }

    func toView(_ point: CGPoint) -> CGPoint {
        CGPoint(x: Double(point.x) * scale + offsetX, y: Double(point.y) * scale + offsetY)
    }

    func toImage(_ point: CGPoint) -> CGPoint {
        guard scale > 0 else { return .zero }
        return CGPoint(x: (Double(point.x) - offsetX) / scale, y: (Double(point.y) - offsetY) / scale)
    }
}
