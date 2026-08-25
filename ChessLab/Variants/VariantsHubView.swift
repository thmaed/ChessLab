import SwiftUI

/// Le hub des variantes d'échecs — l'écran qu'ouvre la tuile « Variantes »
/// de l'accueil. Une carte par variante, dans la grammaire des tuiles de
/// mode ; le Chess960 inaugure la liste, les suivantes s'ajouteront ici.
struct VariantsHubView: View {
    let onOpenChess960: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("D'autres façons de jouer aux échecs, contre l'ordinateur — mêmes réglages de force et de cadence que le mode classique.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onOpenChess960) {
                    HStack(alignment: .top, spacing: 14) {
                        IconBadge(systemImage: "die.face.5.fill", tint: Theme.violet, size: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Chess960")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Les pièces de la rangée de base sont mélangées — 960 départs possibles, zéro théorie à réciter, que de la compréhension. Aussi appelé « Fischer Random ».")
                                .font(.callout)
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("variant_chess960")

                Text("D'autres variantes viendront s'installer ici.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
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
