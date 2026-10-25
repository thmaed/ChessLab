import SwiftUI

/// Un sélecteur « un parmi n » à segments égaux, avec son intitulé — pour les
/// filtres d'une liste. Chaque segment prend la teinte de son choix quand il est
/// actif. Aux tailles d'accessibilité, les segments s'empilent plutôt que de
/// se tronquer.
struct SegmentedFilter<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let label: LocalizedStringKey
        var systemImage: String?
        /// Une pastille pleine (blanche ou noire) à la place d'une icône : sur fond
        /// sombre, les pions ♙/♟ se lisaient à l'envers (le contour ressemble à du noir).
        var disc: Color?
        let tint: Color
        var identifier: String?
        var id: String { identifier ?? "\(value)" }
    }

    let title: LocalizedStringKey
    let options: [Option]
    @Binding var selection: Value
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .tracking(0.4)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 4))
                : AnyLayout(HStackLayout(spacing: 4))
            layout {
                ForEach(options) { option in
                    segment(option)
                }
            }
            .padding(4)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        }
    }

    private func segment(_ option: Option) -> some View {
        let selected = selection == option.value
        return Button {
            withAnimation(Theme.snappySpring) { selection = option.value }
        } label: {
            HStack(spacing: 5) {
                if let disc = option.disc {
                    Circle()
                        .fill(disc)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                } else if let image = option.systemImage {
                    Image(systemName: image).font(.caption2.weight(.semibold))
                }
                Text(option.label)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Theme.background : Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background {
                if selected { Capsule().fill(Theme.tintGradient(option.tint)) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier(option.identifier ?? "")
    }
}
