import Observation
import SwiftUI

/// Sur un écran d'échiquier, la barre latérale se replie quand la fenêtre est
/// trop étroite pour la garder ET donner sa place au plateau.
///
/// **Le problème.** L'iPhone Duo ouvert (écran intérieur, 951 × 669 pt en
/// paysage) est `regular` dans les deux sens : il reçoit, à raison, la
/// disposition iPad — barre latérale + détail. Mais la barre prend ~320 pt,
/// la barre d'état ~84 pt sur le bord droit, et la colonne de détail qui
/// reste est presque CARRÉE. Mesuré le 13/10/2026 sur le simulateur (Xcode
/// 27.1) : plateau de **349 pt** en partie, de **184 pt** en analyse — moins
/// que sur l'écran extérieur, replié, du même téléphone.
///
/// **La règle**, fondée sur la place et non sur l'appareil (Apple le demande
/// pour le Duo : ni `UIScreen`, ni idiome, ni orientation) : dans une fenêtre
/// plus large que haute et plus étroite que ``minimumWidth``, un écran qui
/// montre un échiquier replie la barre latérale (`.detailOnly`). Le bouton de la barre d'outils la rouvre à la demande, et
/// le choix de l'utilisateur est respecté tant qu'il reste sur ces écrans. En
/// revenant vers une liste, la barre revient d'elle-même.
///
/// **Le seuil, et pourquoi celui-là.** 1 024 pt : sous le plus étroit des iPad
/// en paysage (l'iPad mini, 1 133 pt), dont les mises en page ont été
/// dessinées et vérifiées sur appareil et ne bougent pas. Au-dessus du seuil
/// de ``NarrowWindowLayout`` (744 pt), sous lequel l'app passe de toute façon
/// à la disposition iPhone. Entre les deux : l'iPhone Duo ouvert, et les
/// fenêtres redimensionnées de l'iPad — exactement là où la colonne de détail
/// est trop étroite pour un plateau et son panneau côte à côte.
///
/// **Pourquoi « plus large que haute ».** Une fenêtre en hauteur (l'iPad en
/// portrait, 744 à 1 032 pt) a déjà sa disposition : plateau pleine largeur de
/// la colonne, panneau dessous (`PlayView.iPadTallLayout`), vérifiée sur
/// appareil. C'est quand la place est en LARGEUR que la barre latérale coûte
/// au plateau : la colonne qui reste est presque carrée, et le plateau doit y
/// partager les deux dimensions avec son panneau.
enum BoardSidebarPolicy {

    /// Sous cette largeur de fenêtre, un écran d'échiquier replie la barre.
    static let minimumWidth: CGFloat = 1024

    /// La taille est celle de l'ossature DANS sa zone sûre : 867 pt de large sur
    /// le Duo ouvert, dont la barre d'état mange 84 pt à droite.
    /// `nil` (premier rendu) : on ne replie rien sans mesure.
    static func collapsesSidebar(showsBoard: Bool, size: CGSize?) -> Bool {
        guard showsBoard, let size, size.width > 0, size.height > 0 else { return false }
        return size.width < minimumWidth && size.width > size.height
    }
}

/// Les écrans d'échiquier VISIBLES, tenus à jour par leur apparition et leur
/// disparition dans la pile de détail. Un écran recouvert par un autre
/// (l'analyse empilée sur une partie) disparaît au sens de SwiftUI : seul
/// compte celui qu'on voit.
@MainActor @Observable
final class BoardScreenPresence {
    private(set) var visible: Set<UUID> = []

    var showsBoard: Bool { !visible.isEmpty }

    func appeared(_ id: UUID) { visible.insert(id) }
    func disappeared(_ id: UUID) { visible.remove(id) }
}

private struct BoardScreenReporter: ViewModifier {
    let presence: BoardScreenPresence
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { presence.appeared(id) }
            .onDisappear { presence.disappeared(id) }
    }
}

extension View {
    /// Signale à l'ossature que cet écran montre un échiquier — voir
    /// ``BoardSidebarPolicy``. Sans effet quand `showsBoard` est faux.
    @ViewBuilder
    func reportsBoardScreen(_ showsBoard: Bool, to presence: BoardScreenPresence) -> some View {
        if showsBoard {
            modifier(BoardScreenReporter(presence: presence))
        } else {
            self
        }
    }
}
