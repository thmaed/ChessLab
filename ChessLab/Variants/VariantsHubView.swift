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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("D'autres façons de jouer aux échecs, contre l'ordinateur — mêmes réglages de force et de cadence que le mode classique.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: ModeGridMetrics.minTileIPhone), spacing: ModeGridMetrics.spacing)],
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
                            subtitle: LocalizedStringKey(variant.tagline),
                            systemImage: variant.icon,
                            tint: variant.tint,
                            isEnabled: true,
                            accessibilityID: "variant_\(variant.id)"
                        ) {
                            onOpenFairyVariant(variant)
                        }
                    }
                    ForEach(EngineLegalityVariant.all, id: \.id) { variant in
                        ModeCard(
                            title: LocalizedStringKey(variant.displayName),
                            shortTitle: LocalizedStringKey(variant.shortName),
                            subtitle: LocalizedStringKey(variant.tagline),
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
                        subtitle: LocalizedStringKey(StolenMoveVariant.shared.tagline),
                        systemImage: StolenMoveVariant.shared.icon,
                        tint: StolenMoveVariant.shared.tint,
                        isEnabled: true,
                        accessibilityID: "variant_\(StolenMoveVariant.shared.id)",
                        action: onOpenStolenMove
                    )
                }

                Text("Sans réseau de neurones dédié aux six premières : le moteur y joue avec son évaluation classique, un cran sous le mode normal. Coup Volé, lui, garde le moteur habituel — seul le déroulement du tour change.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Variantes d'échecs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
