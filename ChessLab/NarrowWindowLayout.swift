import SwiftUI

/// Une fenêtre plus étroite que le plus étroit des iPad n'est plus un iPad :
/// elle reçoit la disposition iPhone.
///
/// **Le problème.** iPadOS décide de la classe de taille par paliers, et un
/// iPad de 13 pouces garde la classe `regular` très au-delà du point où la
/// fenêtre cesse d'être large. Partagée avec une autre app — ou simplement
/// redimensionnée, ce que le fenêtrage d'iPadOS 26 permet librement —, la
/// fenêtre peut tomber à 600 ou 700 pt en restant `regular`. ChessLab y
/// montrait alors encore barre latérale + détail : la barre prenait 290 pt,
/// et il restait au plateau moins de place que sur un iPhone.
///
/// Mesuré le 29/09/2026 sur l'iPad mini en portrait, la fenêtre `regular` la
/// plus étroite qu'on puisse obtenir en plein écran (744 pt) : plateau de
/// **454 pt**, soit 61 % de la fenêtre. La même partie en disposition iPhone
/// donnerait les 744 pt. Plus la fenêtre rétrécit, plus l'écart se creuse.
///
/// **Le seuil, et pourquoi celui-là.** 744 pt, la largeur en portrait de
/// l'iPad le plus étroit jamais vendu. Au-dessus, la disposition à deux
/// colonnes est celle qui a été dessinée et vérifiée sur appareil, et rien ne
/// change. En dessous, aucun écran d'iPad n'a jamais été aussi étroit : la
/// disposition iPad n'y a jamais été dimensionnée, et c'est celle de l'iPhone
/// — une colonne, plateau pleine largeur — qui convient.
///
/// **Ce que cela ne corrige pas**, et c'est à dire : pendant le glissement du
/// bord de la fenêtre, iPadOS montre l'ancienne mise en page rognée par la
/// nouvelle largeur, le temps de quelques images. C'est ce qu'on voit sur les
/// captures du testeur, et cela ne dépend pas de nous ; une disposition en une
/// seule colonne s'y montre simplement moins mal qu'un plateau et un panneau
/// côte à côte.
enum NarrowWindowLayout {

    /// Sous cette largeur, la disposition iPhone. C'est la largeur en portrait
    /// de l'iPad mini — le plus étroit des iPad.
    static let regularMinimumWidth: CGFloat = 744

    /// La classe de taille à FAIRE VOIR aux écrans, une fois la largeur réelle
    /// connue.
    ///
    /// `nil` en largeur (premier rendu, avant toute mesure) : on s'en remet
    /// alors à la classe du système, qui a raison partout sauf dans le cas
    /// qu'on corrige ici.
    static func effectiveSizeClass(
        actual: UserInterfaceSizeClass?, width: CGFloat?
    ) -> UserInterfaceSizeClass? {
        guard actual == .regular, let width, width > 0, width < regularMinimumWidth else {
            return actual
        }
        return .compact
    }
}

/// Pose la classe de taille corrigée pour TOUT l'arbre de vues.
///
/// On corrige la valeur d'environnement plutôt que chaque écran : les sept
/// écrans qui demandent « suis-je en régulier ? » — l'ossature d'accueil, la
/// partie, les deux joueurs, l'analyse, les puzzles, le hub des variantes, le
/// laboratoire — obtiennent la bonne réponse sans qu'aucun ne change. C'est le
/// mécanisme que ``SkeletonOverrideHost`` emploie déjà pour les tests.
private struct NarrowWindowSizeClassModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var actual
    /// `nil` tant que rien n'est mesuré — voir
    /// ``NarrowWindowLayout/effectiveSizeClass(actual:width:)``.
    @State private var width: CGFloat?

    func body(content: Content) -> some View {
        content
            .environment(
                \.horizontalSizeClass,
                NarrowWindowLayout.effectiveSizeClass(actual: actual, width: width)
            )
            // La largeur de la FENÊTRE, qui ne dépend pas de la classe qu'on
            // vient de poser : pas de boucle entre la mesure et la décision.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
    }
}

extension View {
    /// Applique la règle ci-dessus. À poser au plus HAUT de l'arbre, et donc
    /// en dernier dans la chaîne — au-dessus de ``View/skeletonOverride()``,
    /// pour qu'une bascule forcée par un test reste maîtresse.
    func narrowWindowSizeClass() -> some View {
        modifier(NarrowWindowSizeClassModifier())
    }
}
