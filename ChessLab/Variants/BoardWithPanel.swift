import SwiftUI

/// Plateau et commandes d'un écran de partie de variante : en colonne, ou côte
/// à côte quand la place est nettement plus LARGE que haute.
///
/// **Le problème.** Les six écrans de partie des variantes empilaient tout en
/// une colonne : bandeaux, plateau, barre de contrôle, bande des coups. Le
/// plateau prend ce qui reste en HAUTEUR. Sur l'iPhone Duo ouvert (colonne de
/// détail ~867 × 585 pt une fois la barre latérale repliée), il restait
/// **330 pt** au plateau de Chess960 et **280 pt** à celui du Duck Chess —
/// moins que sur l'écran extérieur, replié, du même téléphone — avec 500 pt
/// de vide de part et d'autre.
///
/// **La règle**, fondée sur la place (ni appareil, ni orientation, comme Apple
/// le demande pour le Duo) : à partir d'un rapport largeur/hauteur de
/// ``BoardPanelLayout/sidePanelMinimumRatio``, les commandes passent dans un
/// panneau à droite et le plateau garde toute la hauteur. En dessous — iPhone,
/// écran extérieur du Duo, iPad debout ou en paysage, dont la colonne de
/// détail est presque carrée —, rien ne change.
struct BoardWithPanel<BoardColumn: View, Panel: View>: View {
    private let boundsColumnToHeight: Bool
    private let boardColumn: BoardColumn
    private let panel: Panel

    /// `boundsColumnToHeight: false` garde, en colonne, toute la largeur aux
    /// commandes — ce que faisaient déjà les analyses Chess960 et des
    /// variantes, qu'on ne change pas en passant.
    init(
        boundsColumnToHeight: Bool = true,
        @ViewBuilder boardColumn: () -> BoardColumn,
        @ViewBuilder panel: () -> Panel
    ) {
        self.boundsColumnToHeight = boundsColumnToHeight
        self.boardColumn = boardColumn()
        self.panel = panel()
    }

    var body: some View {
        GeometryReader { geo in
            if BoardPanelLayout.usesSidePanel(in: geo.size) {
                HStack(alignment: .top, spacing: BoardPanelLayout.gap) {
                    VStack(spacing: 10) { boardColumn }
                        // Bandeaux à la largeur du plateau, pas de la colonne.
                        .frame(maxWidth: geo.size.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    VStack(spacing: 10) { panel }
                        .frame(width: BoardPanelLayout.panelWidth(in: geo.size))
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    boardColumn
                    panel
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                // Colonne bornée par la HAUTEUR de la fenêtre. Le plateau est
                // carré, donc déjà borné par la hauteur : sans cette borne, les
                // bandeaux joueurs, la barre de contrôle et la bande des coups
                // s'étiraient seuls sur toute la largeur d'une fenêtre Mac
                // large — le transport à un bout, l'abandon à l'autre, séparés
                // par un mètre de vide. Ils restent à la largeur du plateau.
                // Sans effet en portrait (hauteur > largeur) : ni l'iPhone ni
                // l'iPad debout ne changent.
                .frame(maxWidth: boundsColumnToHeight ? geo.size.height : .infinity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

/// Les nombres de ``BoardWithPanel``, à part pour être testés.
enum BoardPanelLayout {

    /// À partir de ce rapport largeur/hauteur, le panneau passe à droite.
    /// L'iPad en paysage, barre latérale ouverte, reste en dessous (colonne de
    /// détail de 874 × 760 pt sur un 11 pouces : 1,15) ; l'iPhone Duo ouvert,
    /// barre repliée, au-dessus (~867 × 585 pt : 1,48).
    static let sidePanelMinimumRatio: CGFloat = 1.3

    static let gap: CGFloat = 16
    static let panelMinimumWidth: CGFloat = 300
    static let panelMaximumWidth: CGFloat = 380

    static func usesSidePanel(in size: CGSize) -> Bool {
        guard size.width > 0, size.height > 0 else { return false }
        return size.width >= size.height * sidePanelMinimumRatio
    }

    /// Un gros tiers de la largeur, borné : assez pour la barre de contrôle,
    /// pas plus — le reste revient au plateau.
    static func panelWidth(in size: CGSize) -> CGFloat {
        min(max(size.width * 0.36, panelMinimumWidth), panelMaximumWidth)
    }

    /// Les marges de ``BoardWithPanel`` : 12 de chaque côté, 8 en haut et en bas.
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 16

    /// Ce qui reste à la colonne du plateau quand le panneau est à droite —
    /// pour les écrans qui calculent eux-mêmes le côté de leur plateau.
    static func boardColumnWidth(in size: CGSize) -> CGFloat {
        max(0, size.width - horizontalPadding - gap - panelWidth(in: size))
    }
}
