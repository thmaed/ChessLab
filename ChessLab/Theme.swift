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
    /// Or des Finales — plus cuivré que `warning` (les deux voisinent sur
    /// l'accueil : Ouvertures ambre, Finales or rosé).
    static let gold = Color(red: 0.91, green: 0.62, blue: 0.34)

    // MARK: Texte

    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.38)

    // MARK: Formes

    static let cardShape = RoundedRectangle(cornerRadius: 18, style: .continuous)
    static let controlShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    // MARK: Mesure de lecture

    /// Largeur maximale d'une colonne de texte suivi (Aide, Réglages,
    /// Progression, tableau de bord de l'accueil).
    ///
    /// Sans elle, une fenêtre Mac en plein écran étire les paragraphes sur
    /// toute sa largeur — plus de 300 caractères par ligne sur un 27 pouces,
    /// où l'œil perd la ligne suivante à chaque retour. 720 pt tient la
    /// mesure autour de 70-90 caractères, la plage lisible que recommandent
    /// les HIG. À utiliser en paire : `.frame(maxWidth: Theme.readableWidth)`
    /// puis `.frame(maxWidth: .infinity, alignment: .center)` pour recentrer
    /// la colonne dans la fenêtre.
    static let readableWidth: CGFloat = 720

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
                GrainOverlay()
            }
        }
        .ignoresSafeArea()
    }
}

/// Voile de grain, à 3,5 % — presque invisible, et c'est le but.
///
/// Un grand dégradé sombre affiche des BANDES sur un écran large : les pas de
/// quantification du noir deviennent visibles dès que le dégradé s'étale sur
/// plus d'un millier de points, ce qu'une fenêtre Mac ou un iPad en paysage
/// font sans effort. Un bruit très faible casse ces paliers — c'est le remède
/// classique, et il ne coûte qu'une tuile de 128×128 générée une seule fois.
///
/// `.overlay` plutôt qu'une opacité simple : le grain module la luminosité
/// existante au lieu de déposer un gris uniforme, donc il disparaît là où le
/// fond est déjà clair (les halos) et travaille là où il est plat.
private struct GrainOverlay: View {
    /// Tuile générée UNE fois pour toute la vie de l'app.
    private static let tile: Image = {
        let side = 128
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        var generator = SystemRandomNumberGenerator()
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let value = UInt8.random(in: 96...160, using: &generator)
            pixels[index] = value
            pixels[index + 1] = value
            pixels[index + 2] = value
            pixels[index + 3] = 255
        }
        let context = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let cgImage = context?.makeImage() else { return Image(systemName: "circle") }
        return Image(decorative: cgImage, scale: 1)
    }()

    var body: some View {
        Self.tile
            .resizable(resizingMode: .tile)
            .blendMode(.overlay)
            .opacity(0.035)
            .allowsHitTesting(false)
    }
}

/// Damier fantôme — la présence graphique discrète des grands écrans.
///
/// Même idiome que l'icône décorative de ``ModeCard``, qui déborde du coin de
/// chaque tuile : un motif tiré du sujet, très pâle, coupé par le bord. Ici
/// c'est le damier de l'icône de l'app, redessiné en VECTORIEL plutôt que
/// repris en photo — l'icône est claire, contrastée et photoréaliste, trois
/// défauts derrière une interface sombre et plate.
///
/// Réservé aux écrans qui ont du vide à meubler (le tableau de bord iPad et
/// Mac) : sur un écran de jeu, déjà chargé, ce serait du bruit.
struct BoardGhost: View {
    /// Côté du damier, en fraction de la plus petite dimension offerte.
    var scale: CGFloat = 1.15

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * scale
            let square = side / 8

            Canvas { context, _ in
                for rank in 0..<8 {
                    for file in 0..<8 where (rank + file).isMultiple(of: 2) {
                        context.fill(
                            Path(CGRect(
                                x: CGFloat(file) * square, y: CGFloat(rank) * square,
                                width: square, height: square
                            )),
                            with: .color(.white)
                        )
                    }
                }
            }
            .frame(width: side, height: side)
            .rotationEffect(.degrees(-14))
            // Débordant du coin bas-droit : le motif est coupé par le bord,
            // ce qui le lit comme une texture et non comme une image posée.
            .offset(x: geo.size.width - side * 0.62, y: geo.size.height - side * 0.55)
            .opacity(0.022)
            .blur(radius: 0.5)
        }
        .allowsHitTesting(false)
        .clipped()
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
/// Un dessin À NOUS, là où aucun symbole SF ne dit la chose.
///
/// Le Duck Chess est le seul cas à ce jour : `bird.fill` montre un passereau
/// de profil, alors que la variante EST un canard de bain jaune — c'est son
/// nom, c'est ce qu'on voit sur le plateau, et c'est ce qui la distingue des
/// neuf autres tuiles du hub. Un `enum` plutôt qu'une vue quelconque : la
/// liste des dessins maison reste courte et lisible d'un coup d'œil.
enum ModeGlyph {
    case duck

    @ViewBuilder
    func view(outlined: Bool) -> some View {
        switch self {
        case .duck: DuckGlyphView(outlined: outlined)
        }
    }
}

struct IconBadge: View {
    let systemImage: String
    /// Quand il est là, il REMPLACE `systemImage`.
    var customGlyph: ModeGlyph? = nil
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
            if let customGlyph {
                // Le halo sombre du dessin le détache du dégradé de la
                // pastille, qui est dans la teinte du mode — un canard jaune
                // sur un fond ambre s'y fondrait sans lui.
                customGlyph.view(outlined: true)
                    .frame(width: size * 0.66, height: size * 0.66)
                    .opacity(isEnabled ? 1 : 0.45)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(isEnabled ? Theme.background : Theme.textTertiary)
            }
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
/// de sélection par facettes (``PuzzleQueueView``).
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

/// Puce-pion : même capsule que ``FilterChip``, mais un glyphe d'échecs à
/// 26 pt (« au moins 2× » le texte des autres puces — demande du 19/08). Le
/// remplissage vertical est réduit pour que la capsule reste à hauteur des
/// voisines. `\u{FE0E}` sur le pion noir force le rendu TEXTE : sans lui,
/// U+265F bascule en émoji sur iOS.
///
/// Partagée depuis le 23/08 entre l'écran Ouvertures et l'écran Labs : les
/// deux proposent les mêmes filtres, ils doivent proposer la même puce.
struct PieceFilterChip: View {
    let glyph: String
    let isSelected: Bool
    let accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 26))
                .foregroundStyle(isSelected ? Theme.background : Theme.textPrimary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 1)
                .background {
                    if isSelected {
                        Capsule().fill(Theme.tintGradient(Theme.textPrimary))
                    } else {
                        Capsule().fill(Theme.surfaceElevated)
                    }
                }
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Theme.stroke, lineWidth: 1))
                .glow(Theme.textPrimary, radius: 8, isActive: isSelected)
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
                    // Une puce ne PASSE JAMAIS à la ligne : sur écran étroit,
                    // « Blancs » devenait « Blan/cs » (retour utilisateur du
                    // 19/08). C'est à l'écran hôte d'offrir un défilement
                    // horizontal si la rangée déborde.
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
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
///
/// ## Deux défauts corrigés (Lot 3.4)
///
/// La version d'origine interrogeait ses enfants avec
/// `sizeThatFits(.unspecified)`, c'est-à-dire leur **largeur idéale sur une
/// seule ligne** : le texte d'une puce ne pouvait donc jamais revenir à la
/// ligne ni être tronqué. Et sa condition de retour à la ligne exigeait
/// `x > bounds.minX` : une puce **plus large que le conteneur** était posée
/// en début de ligne et débordait franchement, sans qu'aucun mécanisme ne la
/// rattrape. Les deux se combinaient sur les étiquettes SAISIES PAR
/// L'UTILISATEUR (`AnalysisLibraryView`), qui débordaient dès ~40 caractères
/// **à taille de texte normale**, et sur n'importe quelle puce en taille
/// d'accessibilité.
///
/// Désormais : la largeur proposée aux enfants est **bornée à la ligne**, et
/// toute largeur mesurée est écrêtée à cette même borne. Un élément trop
/// large occupe sa ligne entière et se débrouille avec — il se replie ou se
/// tronque, mais ne sort plus de l'écran.
///
/// La hauteur retournée est celle des lignes réellement occupées, et la
/// largeur celle de la plus longue — le conteneur ne réserve plus toute la
/// largeur disponible pour deux puces (cosmétique sur iPhone, visible sur
/// iPad).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    /// Une ligne calculée : les tailles retenues et leur position en x.
    private struct Line {
        var items: [(index: Int, size: CGSize, x: CGFloat)] = []
        var height: CGFloat = 0
        var width: CGFloat = 0
    }

    /// Répartition commune à la mesure et au placement — sans quoi les deux
    /// interrogeraient les enfants séparément, avec le risque de diverger.
    private func lines(subviews: Subviews, maxWidth: CGFloat) -> [Line] {
        // Proposer la largeur de ligne (et non `.unspecified`) : c'est ce qui
        // autorise un `Text` à se replier ou à se tronquer.
        let proposal = ProposedViewSize(
            width: maxWidth.isFinite ? maxWidth : nil, height: nil
        )
        var result: [Line] = []
        var current = Line()
        var x: CGFloat = 0

        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(proposal)
            // Écrêtage : un enfant qui réclame plus que la ligne (image à
            // largeur fixe, texte insécable) est ramené à la ligne.
            size.width = min(size.width, maxWidth)

            // Tolérance d'un demi-point : sans elle, un enfant mesuré à la
            // largeur exacte de la ligne provoquerait un retour à la ligne
            // parasite sur un arrondi de rendu.
            if !current.items.isEmpty, x + size.width > maxWidth + 0.5 {
                current.width = x - spacing
                result.append(current)
                current = Line()
                x = 0
            }
            current.items.append((index, size, x))
            x += size.width + spacing
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty {
            current.width = x - spacing
            result.append(current)
        }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let lines = lines(subviews: subviews, maxWidth: maxWidth)
        guard !lines.isEmpty else { return .zero }
        let height = lines.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(lines.count - 1)
        return CGSize(width: lines.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(subviews: subviews, maxWidth: bounds.width) {
            for item in line.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
            }
            y += line.height + lineSpacing
        }
    }
}

/// Ancien jumeau de ``FlowLayout``, dupliqué à l'identique dans
/// `GameTagsEditorSheet` — et porteur des deux mêmes défauts. Conservé comme
/// simple alias pour ne pas réécrire ses sites d'appel : une seule
/// implémentation, donc une seule correction à maintenir.
typealias WrapLayout = FlowLayout

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
