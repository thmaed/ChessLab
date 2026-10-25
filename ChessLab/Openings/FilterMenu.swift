import SwiftUI

/// Un filtre « un parmi n » replié en une capsule : elle affiche le choix
/// courant, et un menu propose les autres. Deux capsules côte à côte tiennent
/// sur UNE ligne — là où deux sélecteurs libellés mangeaient la moitié de
/// l'écran. Teintée dès qu'un choix autre que le premier est actif.
struct FilterMenu<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let label: LocalizedStringKey
        var systemImage: String?
        /// Une pastille pleine (blanche ou noire) : les pions ♙/♟ se lisaient à
        /// l'envers sur fond sombre.
        var disc: Color?
        let tint: Color
        var identifier: String
        var id: String { identifier }
    }

    let options: [Option]
    @Binding var selection: Value
    let accessibilityLabel: LocalizedStringKey

    private var current: Option { options.first { $0.value == selection } ?? options[0] }
    private var isActive: Bool { selection != options[0].value }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option.value
                } label: {
                    if let image = option.systemImage {
                        Label(option.label, systemImage: selection == option.value ? "checkmark" : image)
                    } else {
                        Label(option.label, systemImage: selection == option.value ? "checkmark" : "circle")
                    }
                }
                .accessibilityIdentifier(option.identifier)
            }
        } label: {
            HStack(spacing: 6) {
                if let disc = current.disc {
                    Circle().fill(disc).frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                } else if let image = current.systemImage {
                    Image(systemName: image).font(.caption.weight(.semibold))
                }
                Text(current.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(isActive ? Theme.background : Theme.textPrimary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background {
                if isActive {
                    Capsule().fill(Theme.tintGradient(current.tint))
                } else {
                    Capsule().fill(current.tint.opacity(0.10))
                }
            }
            .overlay(Capsule().strokeBorder(isActive ? Color.clear : current.tint.opacity(0.28), lineWidth: 1))
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(Text(current.label))
        .accessibilityIdentifier("filter_menu_\(options[0].identifier)")
    }
}
