import SwiftUI
import UIKit

/// Quelles orientations l'app accepte — selon la TAILLE de l'écran qui
/// l'affiche, et non selon la famille d'appareil.
///
/// **L'existant.** L'iPhone est verrouillé en portrait depuis le Lot 2 (voir
/// `OrientationLockUITests`) : ses dispositions n'ont jamais été dessinées
/// pour une fenêtre de 400 pt de haut, et le verrou fait disparaître toute
/// cette classe de bugs. L'iPad, lui, tourne librement.
///
/// **Le problème.** L'iPhone Duo est un iPhone : le verrou s'appliquait aussi
/// à son écran intérieur (951 × 669 pt). Tourner l'appareil ouvert laissait
/// ChessLab couché, illisible — alors qu'Apple demande pour le Duo le
/// support de « toutes les poses » (13/10/2026, simulateur Xcode 27.1).
///
/// **La règle.** Un écran dont le PETIT côté atteint ``freeRotationMinimumSide``
/// a la place de toutes les orientations : l'app y tourne librement. Les
/// mises en page choisissent ensuite d'après la place offerte (voir
/// ``NarrowWindowLayout``, ``BoardSidebarPolicy``, ``BoardWithPanel``), jamais
/// d'après l'orientation, comme Apple le demande. En dessous — tous les
/// iPhone, et l'écran extérieur du Duo (466 pt) —, le portrait reste de mise.
enum OrientationPolicy {

    /// 600 pt : au-dessus du plus large des iPhone (440 pt) et de l'écran
    /// extérieur du Duo (466 pt), en dessous de l'écran intérieur du Duo
    /// (669 pt) et du plus étroit des iPad (744 pt).
    static let freeRotationMinimumSide: CGFloat = 600

    /// `nil` (aucune fenêtre encore) : le portrait, sûr partout.
    static func supportedOrientations(screenSize: CGSize?) -> UIInterfaceOrientationMask {
        guard let screenSize, min(screenSize.width, screenSize.height) >= freeRotationMinimumSide else {
            return .portrait
        }
        return .all
    }
}

#if !targetEnvironment(macCatalyst)
/// Le délégué d'app d'iOS : n'existe que pour poser ``OrientationPolicy``. Le
/// Mac a le sien, ``MacMenuDelegate``.
final class OrientationDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        // L'écran de CETTE fenêtre — jamais `UIScreen.main`, qu'Apple
        // proscrit pour le Duo : ses deux écrans n'ont pas la même taille.
        OrientationPolicy.supportedOrientations(screenSize: window?.windowScene?.screen.bounds.size)
    }
}

/// Fait reposer la question des orientations quand la fenêtre change de
/// taille — c'est-à-dire, sur l'iPhone Duo, quand l'app passe d'un écran à
/// l'autre.
///
/// Sans cela, le système gardait la réponse donnée sur l'écran INTÉRIEUR
/// (toutes les orientations) une fois le Duo refermé : tourné sur le côté,
/// l'écran extérieur passait ChessLab en paysage, où ses dispositions iPhone
/// n'ont jamais été dessinées (constaté le 13/10/2026 dans le journal du
/// simulateur : « Scene will change interface orientation: landscapeLeft »,
/// Duo fermé).
private struct SupportedOrientationsRefresher: ViewModifier {
    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { _ in
            for case let windowScene as UIWindowScene in UIApplication.shared.connectedScenes {
                for window in windowScene.windows {
                    window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            }
        }
    }
}
#endif

extension View {
    /// Voir ``SupportedOrientationsRefresher``. Sans effet sur Mac.
    @ViewBuilder
    func refreshesSupportedOrientations() -> some View {
        #if targetEnvironment(macCatalyst)
        self
        #else
        modifier(SupportedOrientationsRefresher())
        #endif
    }
}
