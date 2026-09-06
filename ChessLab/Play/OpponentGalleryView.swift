import SwiftUI

/// La galerie des personnages : une grille de vignettes, puis la fiche du
/// personnage choisi (grande illustration sur sa couleur, prénom et surnom,
/// étiquettes de style, sa phrase).
struct OpponentGalleryView: View {
    @Binding var selectedID: String
    var onSelect: (OpponentProfile) -> Void = { _ in }

    private var selected: OpponentProfile { OpponentProfile.named(selectedID) ?? .maia }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(OpponentProfile.all) { profile in
                    OpponentTile(profile: profile, isSelected: profile.id == selectedID) {
                        guard profile.id != selectedID else { return }
                        withAnimation(Theme.snappySpring) { selectedID = profile.id }
                        onSelect(profile)
                    }
                }
            }
            OpponentProfileCard(profile: selected)
                .id(selected.id)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }
}

/// Une vignette de la galerie : illustration, prénom, surnom. Sélectionnée,
/// elle prend la couleur du personnage.
struct OpponentTile: View {
    let profile: OpponentProfile
    let isSelected: Bool
    let action: () -> Void

    private var tint: Color { OpponentTintResolver.color(profile.tint) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                OpponentAvatar(profile: profile, size: 54, emphasized: isSelected)
                Text(profile.firstName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(LocalizationController.string(profile.nickname))
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? tint : Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.18) : Theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? tint : Theme.stroke, lineWidth: isSelected ? 2 : 1)
            )
            .glow(tint, radius: 10, isActive: isSelected)
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
    var emphasized: Bool = false

    private var tint: Color { OpponentTintResolver.color(profile.tint) }

    var body: some View {
        // L'illustration porte déjà son disque de couleur : seul un liseré
        // s'ajoute, plus marqué quand le personnage est choisi.
        Image(profile.avatar)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(emphasized ? Color.white.opacity(0.85) : tint.opacity(0.5), lineWidth: emphasized ? 2 : 1))
            .accessibilityHidden(true)
    }
}

/// Les couleurs des disques des illustrations, mesurées sur la planche
/// (06/09/2026) : la teinte de chaque personnage EST celle de son avatar.
enum OpponentTintResolver {
    static func color(_ tint: OpponentTint) -> Color {
        switch tint {
        case .maiaBlue: Color(red: 0.200, green: 0.435, blue: 0.675)
        case .red: Color(red: 0.882, green: 0.141, blue: 0.125)
        case .deepBlue: Color(red: 0.016, green: 0.373, blue: 0.718)
        case .green: Color(red: 0.192, green: 0.518, blue: 0.247)
        case .purple: Color(red: 0.412, green: 0.216, blue: 0.631)
        case .orange: Color(red: 0.976, green: 0.604, blue: 0.086)
        case .cyan: Color(red: 0.004, green: 0.667, blue: 0.753)
        case .slate: Color(red: 0.263, green: 0.322, blue: 0.404)
        case .yellow: Color(red: 0.996, green: 0.765, blue: 0.086)
        }
    }
}

/// La fiche d'un personnage : grande illustration sur un fond de sa couleur,
/// prénom et surnom, étiquettes de style, sa phrase.
struct OpponentProfileCard: View {
    let profile: OpponentProfile

    private var tint: Color { OpponentTintResolver.color(profile.tint) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            OpponentAvatar(profile: profile, size: 84, emphasized: true)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(profile.firstName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("« \(LocalizationController.string(profile.nickname)) »")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(profile.tags, id: \.self) { tag in
                        Text(LocalizedStringKey(tag))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(tint.opacity(0.14)))
                            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
                    }
                }
                Text(LocalizedStringKey(profile.tagline))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background {
            Theme.controlShape.fill(
                LinearGradient(
                    colors: [tint.opacity(0.22), Theme.surfaceElevated],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        }
        .overlay(Theme.controlShape.strokeBorder(tint.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("opponentCard_\(profile.id)")
    }
}

/// Le niveau d'un personnage : le chiffre, le curseur teinté à sa couleur,
/// sa plage crédible marquée sous la piste, et une ligne pour dire de quelle
/// échelle il s'agit.
struct OpponentLevelSlider: View {
    let profile: OpponentProfile
    @Binding var level: Double

    private var tint: Color { OpponentTintResolver.color(profile.tint) }
    private var range: ClosedRange<Double> { profile.levelRange }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Niveau")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(level))")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
            }
            // Le curseur ne va que là où le personnage est crédible : ses
            // deux bornes sont celles de sa plage.
            Slider(value: $level, in: range, step: 50)
                .tint(tint)
            HStack {
                Text("\(profile.recommendedLevels.lowerBound)")
                Spacer()
                Text("\(profile.recommendedLevels.upperBound)")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(tint)
            Text("Échelle humaine (proche de Lichess), différente de l'Elo de Stockfish. Stockfish n'intervient que pour les mats courts, les finales à peu de pièces et les répétitions.")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }
}
