import SwiftUI

/// Écran d'accueil du Duck Chess : la règle, puis on commence.
///
/// Beaucoup plus court que ``FairyVariantSetupView``, et c'est normal — il n'y
/// a ici ni force de moteur, ni cadence, ni couleur à choisir, puisqu'on joue
/// à deux sur le même appareil. Reste ce qui compte pour une variante que
/// personne ne connaît d'avance : sa règle, énoncée avant de commencer.
struct DuckChessSetupView: View {
    let onStart: () -> Void
    private let variant = DuckChessVariant.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSection(title: "Règle", systemImage: variant.icon, tint: variant.tint) {
                    Text(variant.rules)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(maxWidth: Theme.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .appBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle(Text(variant.displayName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            // `.confirmationAction`, comme ``FairyVariantSetupView`` : sur un
            // `.navigationBarTrailing`, l'identifiant d'accessibilité ne
            // remontait pas et les tests ne trouvaient pas le bouton.
            ToolbarItem(placement: .confirmationAction) {
                Button("Commencer", action: onStart)
                    .fontWeight(.semibold)
                    .tint(DuckChessVariant.shared.tint)
                    .accessibilityIdentifier("duck_start")
            }
        }
    }
}
