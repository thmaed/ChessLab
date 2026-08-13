import SwiftUI

#if DEBUG
/// Bascule d'ossature à la demande, pour les tests (Lot 1).
///
/// La bascule `compact ↔ regular` est ce qui détruit le sous-arbre de
/// ``HomeView`` et, avant le coffre de session, la partie en cours. Il fallait
/// pouvoir la déclencher **de façon déterministe** dans un test — or aucun des
/// déclencheurs réels ne s'automatise :
///
/// - la **rotation** d'un iPhone Plus / Pro Max marche (mesuré au Lot 0), mais
///   le Lot 2 verrouille justement l'iPhone en portrait : le test mourrait
///   avec le correctif suivant ;
/// - **Split View**, **Slide Over** et **Stage Manager** ne se pilotent pas
///   depuis XCUITest.
///
/// On force donc la valeur d'environnement que lit `HomeView`, au-dessus
/// d'elle. Le mécanisme testé est exactement celui de la panne — le `if/else`
/// sur `horizontalSizeClass` produit un `_ConditionalContent`, qui détruit sa
/// branche sortante — mais **ce n'est pas une vraie rotation** : rien ici ne
/// reproduit un changement de taille de fenêtre, seulement la classe. C'est la
/// limite de ce harnais, et elle est assumée : c'est la classe de taille, pas
/// la taille, qui décide de l'ossature.
///
/// Activé par `-skeletonToggle`, comme ``ScanTestImage`` et ``ThermalMonitor``.
@MainActor
@Observable
final class SkeletonOverride {
    static let shared = SkeletonOverride()

    /// Classe forcée, ou `nil` pour laisser celle du système.
    var forced: UserInterfaceSizeClass?

    static var isEnabled: Bool { CommandLine.arguments.contains("-skeletonToggle") }
}

/// Enveloppe la racine : lit la classe réelle, applique l'éventuelle
/// surcharge, et expose un bouton de bascule aux tests.
struct SkeletonOverrideHost<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var actual
    @State private var override = SkeletonOverride.shared
    @ViewBuilder let content: Content

    var body: some View {
        content
            .environment(\.horizontalSizeClass, override.forced ?? actual)
            .overlay(alignment: .bottomTrailing) {
                if SkeletonOverride.isEnabled { toggle }
            }
    }

    /// Bouton MINUSCULE et dans le coin : posé plein écran il rendrait les
    /// vrais contrôles injoignables pour XCUITest (leçon du Lot 0, où la sonde
    /// de traits en superposition avait fait tomber `ResumeGameUITests`).
    private var toggle: some View {
        Button {
            let current = override.forced ?? actual
            override.forced = (current == .regular) ? .compact : .regular
        } label: {
            Image(systemName: "rectangle.split.2x1")
                .font(.caption2)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.black.opacity(0.6), in: Circle())
        }
        .accessibilityIdentifier("toggleSkeleton")
        .accessibilityLabel("Basculer l'ossature")
    }
}
#endif

extension View {
    /// Applique la bascule d'ossature de test — sans effet hors Debug.
    func skeletonOverride() -> some View {
        #if DEBUG
        SkeletonOverrideHost { self }
        #else
        self
        #endif
    }
}
