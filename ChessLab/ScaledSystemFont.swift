import SwiftUI

/// Une police système à taille donnée qui suit quand même Dynamic Type.
///
/// ## Pourquoi ce détour
///
/// `Font.system(size:)` ne scale **pas** : c'est une taille en points, figée.
/// Les styles sémantiques (`.body`, `.headline`…) scalent, mais n'offrent pas
/// de taille arbitraire. Or quelques endroits de l'app ont besoin des deux —
/// un nombre affiché en grand, un libellé de bouton calé sur un gabarit.
///
/// La seule voie officielle est `@ScaledMetric`, qui ne s'utilise que dans une
/// vue. D'où ce modificateur : il porte le `@ScaledMetric`, et le point d'appel
/// reste une ligne.
///
/// ## Ce qu'il ne faut PAS convertir avec
///
/// Deux familles de tailles fixes de l'app sont **volontairement** figées, et
/// les passer ici serait une régression :
///
/// - **les SF Symbols dans un cadre de contrôle** (`.frame(width: 44,
///   height: 44)` et compagnie). Un glyphe est dimensionné pour SON contrôle ;
///   le faire grossir dans un cadre qui, lui, ne bouge pas ne l'agrandit pas,
///   ça le rogne. C'est le cas de la très grande majorité des
///   `.font(.system(size:))` du projet ;
/// - **les tailles dérivées de la géométrie du plateau** (`squareSize * 0,2`
///   pour les coordonnées, `side * 0,5` dans l'éditeur, `size * 0,42` pour les
///   pastilles). Ce n'est pas de la typographie, c'est du dessin : elles
///   doivent suivre le plateau, jamais le réglage de texte.
///
/// Ce qui reste — le vrai texte que l'utilisateur lit — est ce que ce
/// modificateur sert.
struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let baseSize: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design
    private let maximumScale: CGFloat?

    init(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: Font.Weight,
        design: Font.Design,
        maximumScale: CGFloat?
    ) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.baseSize = size
        self.weight = weight
        self.design = design
        self.maximumScale = maximumScale
    }

    func body(content: Content) -> some View {
        content.font(.system(size: resolvedSize, weight: weight, design: design))
    }

    /// Le plafond sert aux nombres affichés en très grand : à AX5, un 40 pt
    /// deviendrait un 100 pt qui chasserait tout le reste de la carte. Les
    /// borner à une fois et demie garde la réponse à Dynamic Type — le chiffre
    /// grossit bel et bien — sans faire exploser la mise en page.
    private var resolvedSize: CGFloat {
        guard let maximumScale else { return scaledSize }
        return min(scaledSize, baseSize * maximumScale)
    }
}

extension View {
    /// Police système à `size` points, qui suit Dynamic Type relativement à
    /// `textStyle`. Voir ``ScaledSystemFont`` pour ce qu'il ne faut PAS
    /// convertir.
    ///
    /// - parameter maximumScale: plafond d'agrandissement, en multiple de
    ///   `size`. `nil` = pas de plafond.
    func scaledSystemFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        maximumScale: CGFloat? = nil
    ) -> some View {
        modifier(ScaledSystemFont(
            size: size, relativeTo: textStyle,
            weight: weight, design: design, maximumScale: maximumScale
        ))
    }
}
