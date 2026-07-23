import SwiftUI

/// Palette sombre de l'app (identité visuelle propre à ChessLab,
/// indépendante du mode clair/sombre système — voir `ChessLabApp`).
///
/// L'identité repose sur un fond sombre profond, un vert émeraude signature
/// (décliné en dégradé émeraude → sarcelle) et une petite famille de teintes
/// par section pour se repérer d'un coup d'œil.
enum Theme {
    // MARK: Surfaces

    static let background = Color(red: 0.055, green: 0.063, blue: 0.078)
    /// Ton le plus sombre, utilisé au bas du dégradé d'ambiance.
    static let backgroundDeep = Color(red: 0.035, green: 0.041, blue: 0.055)
    static let surface = Color(red: 0.106, green: 0.118, blue: 0.137)
    static let surfaceElevated = Color(red: 0.145, green: 0.161, blue: 0.184)
    static let stroke = Color.white.opacity(0.08)
    /// Bordure un peu plus marquée pour les éléments qui doivent ressortir
    /// (cartes survolées, éléments actifs) sans passer à la teinte d'accent.
    static let strokeStrong = Color.white.opacity(0.16)

    // MARK: Accent & teintes de section

    static let accent = Color(red: 0.36, green: 0.80, blue: 0.56)
    /// Second point du dégradé d'accent (sarcelle), pour donner de la
    /// profondeur aux CTA et surbrillances plutôt qu'un aplat.
    static let accentSecondary = Color(red: 0.24, green: 0.72, blue: 0.72)

    static let danger = Color(red: 0.92, green: 0.38, blue: 0.38)
    static let warning = Color(red: 0.95, green: 0.75, blue: 0.30)
    static let info = Color(red: 0.36, green: 0.58, blue: 0.95)
    /// Teintes d'appoint pour l'identité par section (cartes de mode…).
    static let violet = Color(red: 0.62, green: 0.51, blue: 0.96)
    static let rose = Color(red: 0.96, green: 0.46, blue: 0.62)
    static let teal = accentSecondary

    // MARK: Texte

    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.38)

    // MARK: Formes

    static let cardShape = RoundedRectangle(cornerRadius: 18, style: .continuous)
    static let controlShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    // MARK: Dégradés

    /// Dégradé d'accent signature (émeraude → sarcelle), en diagonale.
    static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Dégradé de carte : très légère lumière en haut à gauche pour donner
    /// du volume sans casser le ton uni de la surface.
    static let cardGradient = LinearGradient(
        colors: [surfaceElevated.opacity(0.9), surface],
        startPoint: .top, endPoint: .bottom
    )

    /// Dégradé d'une teinte quelconque vers sa version assombrie — utilisé
    /// pour les pastilles d'icône colorées.
    static func tintGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.72)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: Mouvement

    /// Ressort standard pour les apparitions et changements d'état.
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.72)
    /// Ressort plus vif pour le retour tactile (pressions, sélections).
    static let snappySpring = Animation.spring(response: 0.26, dampingFraction: 0.7)
    /// Transition douce pour les fondus / redimensionnements.
    static let gentle = Animation.easeInOut(duration: 0.25)
}

// MARK: - Fond d'ambiance

/// Fond signature de l'app : base sombre du thème plus deux halos très
/// diffus (émeraude en haut, bleu en bas) qui donnent de la profondeur et
/// une atmosphère sans jamais gêner la lecture du contenu. À utiliser en
/// remplacement d'un simple `.background(Theme.background)` sur les écrans.
struct AppBackground: View {
    var body: some View {
        GeometryReader { geo in
            // Rayons en FRACTION de la diagonale de l'écran, pas en points
            // fixes : les valeurs d'origine (460/380/520) étaient calibrées
            // pour un iPhone et restaient collées aux coins sur un iPad, où
            // le centre de l'écran restait plat. La diagonale d'un iPhone
            // valant environ 930 pt, les fractions ci-dessous reproduisent
            // le rendu iPhone actuel au pixel près tout en s'agrandissant
            // proportionnellement sur un plus grand écran.
            let diagonal = hypot(geo.size.width, geo.size.height)

            ZStack {
                // Base en dégradé vertical plutôt qu'un aplat : la profondeur
                // vient du fond lui-même, les cartes n'ont plus à la simuler.
                LinearGradient(
                    colors: [Theme.background, Theme.backgroundDeep],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    colors: [Theme.accent.opacity(0.12), .clear],
                    center: UnitPoint(x: 0.12, y: -0.02), startRadius: 4, endRadius: diagonal * 0.495
                )
                RadialGradient(
                    colors: [Theme.violet.opacity(0.05), .clear],
                    center: UnitPoint(x: -0.08, y: 0.55), startRadius: 4, endRadius: diagonal * 0.41
                )
                RadialGradient(
                    colors: [Theme.info.opacity(0.07), .clear],
                    center: UnitPoint(x: 1.05, y: 1.02), startRadius: 4, endRadius: diagonal * 0.56
                )
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Applique le fond d'ambiance signature derrière le contenu.
    func appBackground() -> some View {
        background(AppBackground())
    }
}

// MARK: - Styles de bouton

/// Retour tactile visuel réutilisable : la cible se contracte et s'atténue
/// légèrement à la pression, avec un petit ressort. Remplace `.plain` sur
/// les boutons de type carte/tuile pour les rendre vivants au toucher.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Theme.snappySpring, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// `.buttonStyle(.pressable)` — retour tactile par contraction.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle { PressableButtonStyle(scale: scale) }
}

// MARK: - Lueur

/// Halo coloré doux autour d'un élément (état sélectionné/actif), en deux
/// passes d'ombre pour un rendu plus dense qu'une seule ombre.
struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat = 12
    var isActive: Bool = true

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.45) : .clear, radius: radius)
            .shadow(color: isActive ? color.opacity(0.25) : .clear, radius: radius * 2)
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 12, isActive: Bool = true) -> some View {
        modifier(GlowModifier(color: color, radius: radius, isActive: isActive))
    }
}

// MARK: - Style de carte

/// Style de carte réutilisable pour les panneaux (réglages, listes de
/// coups, etc.), en remplacement du look "Form" par défaut d'UIKit.
/// Dégradé subtil + fine bordure + ombre portée douce pour donner du
/// relief sur le fond sombre.
struct CardBackground: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.cardGradient, in: Theme.cardShape)
            .overlay(Theme.cardShape.strokeBorder(Theme.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

// MARK: - Pastille d'icône

/// Tuile d'icône colorée — motif récurrent des cartes de mode, entrées de
/// liste et bannières. Centralisé ici pour un rendu homogène.
///
/// Pleine teinte (dégradé) avec icône SOMBRE, et non plus teinte pâle avec
/// icône colorée : c'est le langage visuel des chips sélectionnées
/// (``FilterChip``), étendu à toute l'app — plus vivant, et le contraste
/// icône/fond est garanti sur toutes les teintes de section, y compris le
/// jaune `warning` où une icône blanche serait illisible.
struct IconBadge: View {
    let systemImage: String
    var tint: Color = Theme.accent
    var size: CGFloat = 48
    var isEnabled: Bool = true

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
    }

    var body: some View {
        ZStack {
            if isEnabled {
                shape.fill(Theme.tintGradient(tint))
                // Liseré lumineux dégradé en haut : donne le volume d'une
                // surface bombée sans image.
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.38), .white.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            } else {
                shape.fill(Color.white.opacity(0.06))
            }
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(isEnabled ? Theme.background : Theme.textTertiary)
        }
        .frame(width: size, height: size)
        .shadow(
            color: isEnabled ? tint.opacity(0.28) : .clear,
            radius: size * 0.16, x: 0, y: size * 0.07
        )
    }
}

// MARK: - Filtres & chips

/// Groupe de filtre étiqueté : titre en petites capitales suivi de ses
/// chips en retour à la ligne automatique — même gabarit pour tout écran
/// de sélection par facettes (``PuzzleQueueView``, ``OpeningLibraryView``).
func filterGroup(title: LocalizedStringKey, @ViewBuilder chips: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .textCase(.uppercase)
            .tracking(0.4)
        FlowLayout(spacing: 8, lineSpacing: 8) {
            chips()
        }
    }
}

/// Chip capsule à bascule, teintée par groupe : icône dans la teinte du
/// groupe au repos, fond dégradé de cette teinte une fois sélectionnée
/// (même mécanique que ``ChipButton``, plus la couleur par section) —
/// partagée par tout écran de sélection par facettes.
struct FilterChip: View {
    let label: LocalizedStringKey
    var icon: String?
    var iconVariableValue: Double = 1
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon, variableValue: iconVariableValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.background : tint)
                }
                Text(label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(isSelected ? Theme.background : Theme.textPrimary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule().fill(Theme.tintGradient(tint))
                } else {
                    Capsule().fill(Theme.surfaceElevated)
                }
            }
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Theme.stroke, lineWidth: 1))
            .glow(tint, radius: 8, isActive: isSelected)
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Enchaîne ses enfants horizontalement en revenant à la ligne quand la
/// largeur disponible est dépassée — utilisé pour des groupes de chips
/// compacts (cadences, préréglages…) plutôt qu'une liste verticale.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Célébration

/// Petite pluie de confettis jouée une fois, par-dessus les écrans de
/// réussite (partie gagnée, puzzle résolu). Purement décorative et sans
/// interaction — `allowsHitTesting(false)` pour laisser passer les taps.
struct CelebrationView: View {
    var colors: [Color] = [Theme.accent, Theme.info, Theme.warning, Theme.violet, Theme.rose]
    var pieceCount: Int = 36

    /// « Réduire les animations » (Lot 4.B) : une pluie de confettis est
    /// exactement ce que ce réglage système existe pour supprimer — 36 objets
    /// qui traversent l'écran en tournant, sans le moindre sens fonctionnel.
    /// On ne dessine alors rien du tout : atténuer ne suffirait pas, c'est le
    /// mouvement lui-même qui gêne.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animate = false

    private struct Confetto: Identifiable {
        let id = UUID()
        let xStart: CGFloat
        let color: Color
        let size: CGFloat
        let delay: Double
        let rotation: Double
        let drift: CGFloat
    }

    private let confetti: [Confetto]

    init(colors: [Color] = [Theme.accent, Theme.info, Theme.warning, Theme.violet, Theme.rose], pieceCount: Int = 36) {
        self.colors = colors
        self.pieceCount = pieceCount
        confetti = (0..<pieceCount).map { i in
            Confetto(
                xStart: CGFloat.random(in: 0.05...0.95),
                color: colors[i % colors.count],
                size: CGFloat.random(in: 6...11),
                delay: Double.random(in: 0...0.35),
                rotation: Double.random(in: -220...220),
                drift: CGFloat.random(in: -40...40)
            )
        }
    }

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            confettiLayer
        }
    }

    private var confettiLayer: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(confetti) { piece in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.5)
                        .position(
                            x: geo.size.width * piece.xStart + (animate ? piece.drift : 0),
                            y: animate ? geo.size.height + 40 : -40
                        )
                        .rotationEffect(.degrees(animate ? piece.rotation : 0))
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeIn(duration: 1.6).delay(piece.delay),
                            value: animate
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}
