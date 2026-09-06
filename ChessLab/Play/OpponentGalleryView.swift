import SwiftUI

/// La galerie des personnages : une grille de vignettes, puis la carte du
/// personnage choisi (illustration, prénom et surnom, sa phrase, sa plage).
struct OpponentGalleryView: View {
    @Binding var selectedID: String
    var onSelect: (OpponentProfile) -> Void = { _ in }

    private var selected: OpponentProfile { OpponentProfile.named(selectedID) ?? .camille }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                ForEach(OpponentProfile.all) { profile in
                    OpponentTile(profile: profile, isSelected: profile.id == selectedID) {
                        guard profile.id != selectedID else { return }
                        selectedID = profile.id
                        onSelect(profile)
                    }
                }
            }
            OpponentProfileCard(profile: selected)
        }
    }
}

/// Une vignette de la galerie : illustration, prénom, surnom.
struct OpponentTile: View {
    let profile: OpponentProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                OpponentAvatar(profile: profile, size: 56)
                Text(profile.firstName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Theme.background : Theme.textPrimary)
                    .lineLimit(1)
                Text("« \(LocalizationController.string(profile.nickname)) »")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Theme.background.opacity(0.75) : Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accentGradient)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceElevated)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isSelected ? Color.clear : Theme.stroke, lineWidth: 1))
            .glow(Theme.accent, radius: 8, isActive: isSelected)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text("\(profile.firstName) « \(LocalizationController.string(profile.nickname)) »"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("opponentTile_\(profile.id)")
    }
}

/// L'illustration d'un personnage, sur un disque de sa couleur.
struct OpponentAvatar: View {
    let profile: OpponentProfile
    var size: CGFloat = 44

    var body: some View {
        Image(profile.avatar)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .background(Circle().fill(OpponentTintResolver.color(profile.tint).opacity(0.18)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(OpponentTintResolver.color(profile.tint).opacity(0.6), lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

enum OpponentTintResolver {
    static func color(_ tint: OpponentTint) -> Color {
        switch tint {
        case .accent: Theme.accent
        case .teal: Theme.teal
        case .gold: Theme.gold
        case .violet: Theme.violet
        case .rose: Theme.rose
        case .info: Theme.info
        case .danger: Theme.danger
        case .neutral: Theme.textSecondary
        }
    }
}

/// La carte d'un personnage : illustration, prénom et surnom, sa phrase, sa
/// plage conseillée, et ce que fait Stockfish derrière lui.
struct OpponentProfileCard: View {
    let profile: OpponentProfile

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            OpponentAvatar(profile: profile, size: 64)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(profile.firstName)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("« \(LocalizationController.string(profile.nickname)) »")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(LocalizedStringKey(profile.tagline))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Crédible de \(profile.recommendedLevels.lowerBound) à \(profile.recommendedLevels.upperBound).")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                // Mesuré au Laboratoire (05/09/2026) : Stockfish bridé à
                // « 1100 » écrase Maia consigne 2200. Les deux échelles ne
                // sont pas comparables, et on le dit plutôt que de mentir.
                Text("Le niveau suit l'échelle humaine de Maia (proche de Lichess), pas celle de Stockfish : un personnage à 1500 joue comme un joueur de 1500, ce qui est bien moins fort que Stockfish bridé à 1500.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Joue avec Maia-3, un réseau entraîné sur des millions de parties humaines. Stockfish n'intervient que pour les mats courts, les finales à peu de pièces et les répétitions.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Theme.surfaceElevated, in: Theme.controlShape)
        .overlay(Theme.controlShape.strokeBorder(Theme.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("opponentCard_\(profile.id)")
    }
}
