import SwiftUI

/// L'avancement de l'analyse d'une partie : une capsule qui SE REMPLIT d'orange vif, coup par coup.
///
/// Elle remplace le petit compteur de la barre de boutons : il n'avait que ~75 pt de large, se
/// repliait sur le seul rouet dès que le nombre passait à trois chiffres (« 100/126 »), et une
/// ligne grise minuscule se lit à peine (retour d'un utilisateur, 08/11/2026 : « le compteur a
/// disparu vers 100 coups, l'avancement est peu visible »). Ici, la place est celle de toute la
/// largeur au-dessus du plateau, et la jauge se lit sans le texte.
struct ClassificationProgressBadge: View {
    let done: Int
    let total: Int

    private var fraction: Double { total > 0 ? min(1, max(0, Double(done) / Double(total))) : 0 }

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().tint(Theme.textPrimary).scaleEffect(0.6)
            Text("Analyse : coup \(done)/\(total)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Theme.surface
                    Theme.progress.opacity(0.65)
                        .frame(width: geometry.size.width * fraction)
                }
            }
        }
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.progress, lineWidth: 1.5))
        // Même hauteur que la ligne d'état qu'elle remplace : rien ne bouge sur l'écran. Largeur
        // FIXE : la jauge ne doit pas changer de longueur quand le compteur gagne un chiffre.
        .frame(width: 250, height: 26)
        .animation(Theme.gentle, value: done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Analyse de la partie"))
        .accessibilityValue(Text("coup \(done) sur \(total)"))
        .accessibilityIdentifier("classificationProgress")
    }
}
