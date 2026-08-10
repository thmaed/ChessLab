import SwiftUI

/// Écran « Sources » : crédite les jeux de données et services utilisés pour
/// PRÉ-GÉNÉRER les ouvertures (hors application). Aucune requête réseau n'est
/// faite à l'exécution — tout est figé et embarqué.
struct SourcesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                intro
                sourceCard(
                    icon: "textformat.abc", tint: Theme.info,
                    title: "Noms et codes ECO",
                    body: "Jeu de données public lichess-org/chess-openings (domaine public). Sert à nommer chaque position atteinte."
                )
                sourceCard(
                    icon: "chart.bar.fill", tint: Theme.accent,
                    title: "Coups et statistiques",
                    body: "API Lichess Opening Explorer : parties de maîtres et parties en ligne filtrées par niveau (≈1400-2000). Popularité et scores des coups."
                )
                sourceCard(
                    icon: "cpu", tint: Theme.violet,
                    title: "Évaluations",
                    body: "Moteur Stockfish, en amont, pour annoter les coups critiques et repérer les pièges."
                )
                footer
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var intro: some View {
        Text("Les ouvertures sont pré-générées à partir de sources ouvertes, puis embarquées. Les coups et statistiques sont des faits ; les explications, quand elles existent, sont rédigées à la main.")
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sourceCard(icon: String, tint: Color, title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                Text(body).font(.caption).foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "wifi.slash").foregroundStyle(Theme.textTertiary)
            Text("Aucune donnée d'ouverture n'est téléchargée à l'usage : tout fonctionne hors ligne.")
                .font(.caption2).foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }
}
