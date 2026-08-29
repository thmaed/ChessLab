import SwiftUI

/// Le hub des variantes d'échecs — l'écran qu'ouvre la tuile « Variantes »
/// de l'accueil. Une grille de tuiles ``ModeCard`` (le composant le plus
/// abouti de l'accueil : icône fantôme, dégradé de bordure, flèche de
/// lancement) — plus cohérent visuellement qu'une simple liste de lignes,
/// et ça grandit bien à mesure que d'autres variantes s'ajoutent.
struct VariantsHubView: View {
    let onOpenChess960: () -> Void
    let onOpenFairyVariant: (FairyVariant) -> Void
    let onOpenEngineLegalityVariant: (EngineLegalityVariant) -> Void
    let onOpenStolenMove: () -> Void
    let onOpenDuckChess: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// En *regular*, ``ModeCard`` affiche les libellés longs : la grille a
    /// besoin de colonnes plus larges qu'en compact, sinon les tuiles
    /// tronquent leur texte (voir ``ModeGridMetrics/minTileRegular``).
    private var minTile: CGFloat {
        horizontalSizeClass == .regular
            ? ModeGridMetrics.minTileRegular
            : ModeGridMetrics.minTileIPhone
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("D'autres façons de jouer aux échecs, contre l'ordinateur — mêmes réglages de force et de cadence que le mode classique.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: minTile), spacing: ModeGridMetrics.spacing)],
                    spacing: ModeGridMetrics.spacing
                ) {
                    ModeCard(
                        title: "Chess960",
                        subtitle: "960 départs, zéro théorie",
                        shortSubtitle: "Zéro théorie",
                        systemImage: "die.face.5.fill",
                        tint: Theme.violet,
                        isEnabled: true,
                        accessibilityID: "variant_chess960",
                        action: onOpenChess960
                    )
                    ForEach(FairyVariant.all) { variant in
                        ModeCard(
                            title: LocalizedStringKey(variant.displayName),
                            shortTitle: LocalizedStringKey(variant.shortName),
                            subtitle: LocalizedStringKey(variant.shortTagline),
                            systemImage: variant.icon,
                            tint: variant.tint,
                            isEnabled: true,
                            accessibilityID: "variant_\(variant.id)"
                        ) {
                            onOpenFairyVariant(variant)
                        }
                    }
                    ForEach(EngineLegalityVariant.hubOrdered, id: \.id) { variant in
                        ModeCard(
                            title: LocalizedStringKey(variant.displayName),
                            shortTitle: LocalizedStringKey(variant.shortName),
                            subtitle: LocalizedStringKey(variant.shortTagline),
                            systemImage: variant.icon,
                            tint: variant.tint,
                            isEnabled: true,
                            accessibilityID: "variant_\(variant.id)"
                        ) {
                            onOpenEngineLegalityVariant(variant)
                        }
                    }
                    ModeCard(
                        title: LocalizedStringKey(StolenMoveVariant.shared.displayName),
                        shortTitle: LocalizedStringKey(StolenMoveVariant.shared.shortName),
                        subtitle: LocalizedStringKey(StolenMoveVariant.shared.shortTagline),
                        systemImage: StolenMoveVariant.shared.icon,
                        tint: StolenMoveVariant.shared.tint,
                        isEnabled: true,
                        accessibilityID: "variant_\(StolenMoveVariant.shared.id)",
                        action: onOpenStolenMove
                    )
                    ModeCard(
                        title: LocalizedStringKey(DuckChessVariant.shared.displayName),
                        shortTitle: LocalizedStringKey(DuckChessVariant.shared.shortName),
                        subtitle: LocalizedStringKey(DuckChessVariant.shared.shortTagline),
                        systemImage: DuckChessVariant.shared.icon,
                        // Un canard, pas un passereau : la tuile porte le
                        // dessin qu'on retrouve ensuite sur le plateau.
                        customGlyph: .duck,
                        tint: DuckChessVariant.shared.tint,
                        isEnabled: true,
                        accessibilityID: "variant_\(DuckChessVariant.shared.id)",
                        action: onOpenDuckChess
                    )
                    // Barricades ferme la marche — voir
                    // ``EngineLegalityVariant/hubTrailing``.
                    ForEach(EngineLegalityVariant.hubTrailing, id: \.id) { variant in
                        ModeCard(
                            title: LocalizedStringKey(variant.displayName),
                            shortTitle: LocalizedStringKey(variant.shortName),
                            subtitle: LocalizedStringKey(variant.shortTagline),
                            systemImage: variant.icon,
                            tint: variant.tint,
                            isEnabled: true,
                            accessibilityID: "variant_\(variant.id)"
                        ) {
                            onOpenEngineLegalityVariant(variant)
                        }
                    }
                }
            }
            .padding(20)
            // Même mesure de lecture que l'Aide et les Réglages : sans elle,
            // une fenêtre Mac large alignait les huit tuiles sur UNE rangée
            // écrasée en haut de l'écran, le reste vide. Bornée, la grille se
            // replie en un bloc de trois colonnes à taille confortable.
            .frame(maxWidth: Theme.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .appBackground()
        .navigationTitle("Variantes d'échecs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
