import SwiftUI

/// Sonde de mise en page (Lot 0.1) : expose les traits réels de la fenêtre —
/// classes de taille, taille de la fenêtre, encoches — au lieu de les
/// supposer.
///
/// Deux consommateurs, un seul relevé :
/// - un **marqueur d'accessibilité** (`layoutTraits`), lu par les tests UI.
///   C'est LA source de vérité : en paysage, les captures d'écran du
///   simulateur sortent tournées dans un cadre resté portrait (piège
///   documenté dans `PROGRESS.md`), alors que les valeurs d'accessibilité,
///   elles, sont fiables ;
/// - une **surimpression visible**, uniquement pour l'œil humain quand on
///   inspecte le simulateur à la main.
///
/// Activée par l'argument de lancement `-showTraits` — même parti pris que
/// ``ScanTestImage``, ``EngineStartFailureSimulator`` et ``ThermalMonitor`` :
/// sans ça, ces valeurs ne se constateraient qu'en instrumentant le code
/// applicatif à la main, autrement dit jamais.
///
/// Le marqueur d'accessibilité, lui, est présent sans argument (il ne coûte
/// qu'une `Color.clear` et ne capte aucun geste) : c'est ce qui permet aux
/// tests de mise en page de connaître les traits de la fenêtre sans devoir
/// relancer l'app avec un argument supplémentaire. **Tout ce fichier est
/// compilé sous `#if DEBUG`** : rien de tout cela n'existe dans le binaire
/// livré, où ``View/layoutTraitsProbe()`` ne fait rien.
#if DEBUG
struct LayoutTraitsProbe: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// `-showTraits` : ajoute la surimpression lisible à l'œil.
    static var showsBadge: Bool { CommandLine.arguments.contains("-showTraits") }

    func body(content: Content) -> some View {
        content
            // Le marqueur va en ARRIÈRE-PLAN, comme ``HomeView/engineInstanceMarker`` :
            // en superposition, son élément d'accessibilité pleine fenêtre
            // devenait le premier touché au point de frappe et XCUITest
            // déclarait « Not hittable » tous les boutons de l'écran
            // (`ResumeGameUITests` est tombé ainsi). `allowsHitTesting(false)`
            // n'y change rien : c'est la hiérarchie d'accessibilité, pas le
            // hit-testing SwiftUI, que consulte le pilote de test.
            .background { probeLayer }
            // La surimpression lisible, elle, reste au-dessus — mais seulement
            // avec `-showTraits`, un mode d'inspection manuelle où l'on ne
            // pilote pas l'app par les tests.
            .overlay { if Self.showsBadge { badgeLayer } }
    }

    /// Marqueur invisible lu par les tests.
    ///
    /// `GeometryReader` SANS `ignoresSafeArea` : mesuré, c'est cette forme qui
    /// donne les DEUX informations utiles — `geo.size` est la zone sûre et
    /// `geo.safeAreaInsets` les encoches réelles. Avec `.ignoresSafeArea()`, la
    /// vue possède tout l'écran et les encoches sont alors rapportées à zéro
    /// (constaté sur iPhone SE : 375×667 avec des insets nuls, alors que la
    /// barre d'état en occupe 20). La taille de fenêtre se reconstitue par
    /// addition.
    private var probeLayer: some View {
        GeometryReader { geo in
            Color.clear
                .accessibilityIdentifier("layoutTraits")
                .accessibilityValue(
                    Self.summary(
                        horizontal: horizontalSizeClass,
                        vertical: verticalSizeClass,
                        safeSize: geo.size,
                        insets: geo.safeAreaInsets,
                        dynamicTypeSize: dynamicTypeSize
                    )
                )
        }
        .allowsHitTesting(false)
    }

    private var badgeLayer: some View {
        GeometryReader { geo in
            Text(
                Self.summary(
                    horizontal: horizontalSizeClass,
                    vertical: verticalSizeClass,
                    safeSize: geo.size,
                    insets: geo.safeAreaInsets,
                    dynamicTypeSize: dynamicTypeSize
                )
                .replacingOccurrences(of: ";", with: "\n")
            )
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .padding(6)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
            .padding(4)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Relevé sérialisé en `clé=valeur` séparés par `;` — format volontairement
    /// plat pour être lisible d'un coup d'œil ET analysable par les tests UI
    /// sans dépendance partagée entre la cible app et la cible de test.
    ///
    /// `w`/`ht` = la FENÊTRE (zone sûre + encoches), `sw`/`sh` = la zone sûre
    /// effectivement disponible au contenu.
    static func summary(
        horizontal: UserInterfaceSizeClass?,
        vertical: UserInterfaceSizeClass?,
        safeSize: CGSize,
        insets: EdgeInsets,
        dynamicTypeSize: DynamicTypeSize
    ) -> String {
        func name(_ sizeClass: UserInterfaceSizeClass?) -> String {
            switch sizeClass {
            case .compact: "compact"
            case .regular: "regular"
            default: "nil"
            }
        }
        func number(_ value: CGFloat) -> String { String(format: "%.1f", value) }

        let window = CGSize(
            width: safeSize.width + insets.leading + insets.trailing,
            height: safeSize.height + insets.top + insets.bottom
        )
        return [
            "h=\(name(horizontal))",
            "v=\(name(vertical))",
            "w=\(number(window.width))",
            "ht=\(number(window.height))",
            "sw=\(number(safeSize.width))",
            "sh=\(number(safeSize.height))",
            "top=\(number(insets.top))",
            "leading=\(number(insets.leading))",
            "bottom=\(number(insets.bottom))",
            "trailing=\(number(insets.trailing))",
            "dts=\(dynamicTypeSize)",
        ].joined(separator: ";")
    }
}

extension View {
    /// Pose la sonde de traits de mise en page — voir ``LayoutTraitsProbe``.
    func layoutTraitsProbe() -> some View {
        modifier(LayoutTraitsProbe())
    }
}
#else
extension View {
    /// Sans effet hors Debug : la sonde n'est pas compilée dans le binaire
    /// livré.
    func layoutTraitsProbe() -> some View { self }
}
#endif
