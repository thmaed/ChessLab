import SwiftUI

/// Les quatre jauges d'un personnage (Attaque, Solidité, Échanges, Imprévisible), de cinq points chacune.
///
/// Elles s'adaptent à la largeur disponible au lieu d'en exiger une : la grille d'avant fixait le libellé à 82 pt et les
/// points à 72 pt, deux fois, soit 342 pt (+ 24 pt de marges) quel que soit l'écran. Sur un iPhone en affichage
/// « Zoomé » (écran de 320 pt, retour de l'utilisateur sur TestFlight le 20/11/2026) cette largeur gagnait TOUT
/// l'écran : cartes centrées et rognées des deux côtés (« taque », « iveau », « 165 »). Android avait déjà corrigé ce
/// défaut sur le Galaxy (police agrandie) par deux colonnes qui se partagent la largeur.
///
/// Deux dispositions, la première qui tient gagne : la grille d'avant, À L'IDENTIQUE, quand il y a 342 pt ; sinon une
/// grille resserrée (points plus petits, colonnes plus proches) dont le libellé se réduit encore au besoin.
struct OpponentGaugesView: View {
    let traits: OpponentTraits
    let tint: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            grid(compact: false)
            grid(compact: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("opponentTraits")
    }

    private func grid(compact: Bool) -> some View {
        Grid(horizontalSpacing: compact ? 10 : 18, verticalSpacing: 6) {
            GridRow {
                gauge("Attaque", traits.attack, compact: compact)
                gauge("Solidité", traits.solidity, compact: compact)
            }
            GridRow {
                gauge("Échanges", traits.trades, compact: compact)
                gauge("Imprévisible", traits.unpredictability, compact: compact)
            }
        }
    }

    private func gauge(_ title: LocalizedStringKey, _ value: Int, compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 8) {
            Group {
                if compact {
                    // Se réduit (échelle, puis troncature) plutôt que d'imposer sa largeur.
                    Text(title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: 82, alignment: .leading)
                } else {
                    Text(title).frame(width: 82, alignment: .leading)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            HStack(spacing: compact ? 2 : 3) {
                ForEach(1...5, id: \.self) { step in
                    Capsule()
                        .fill(step <= value ? tint : Color.white.opacity(0.12))
                        .frame(width: compact ? 9 : 12, height: 6)
                }
            }
            .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(value) sur 5"))
    }
}
