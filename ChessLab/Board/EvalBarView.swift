import SwiftUI

/// Barre horizontale d'avantage (blanc à gauche, noir à droite), basée sur
/// la même conversion éval→probabilité de gain que le mode Analyser
/// (voir ``EvalConversion``). Partagée entre le mode Jouer et le mode
/// Analyser.
struct EvalBarView: View {
    let evalCp: Int?
    let evalMate: Int?
    /// Épaisseur par défaut — la valeur historique, celle des modes Jouer et
    /// Analyser où la barre est un élément à part entière. Exposée pour que
    /// les écrans qui réservent sa place dans leur budget de hauteur (les
    /// écrans de jeu des variantes) lisent la même valeur qu'elle.
    static let defaultHeight: CGFloat = 20
    /// Épaisseur de la barre. Le lecteur Labs la veut FINE (le prompt) : elle
    /// y accompagne l'échiquier au lieu de lui disputer la place.
    var height: CGFloat = EvalBarView.defaultHeight
    /// Score écrit DANS la barre. À masquer sous ~14 pt : le chiffre n'y tient
    /// plus, et l'écran hôte l'affiche alors à côté (voir ``OpeningReaderView``).
    var showsLabel: Bool = true

    private enum Advantage { case white, black, equal }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Côté noir : léger dégradé pour un peu de matière plutôt
                // qu'un aplat pur.
                Capsule().fill(
                    LinearGradient(colors: [Color(white: 0.16), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)
                )
                Capsule().fill(
                    LinearGradient(colors: [Color.white, Color(white: 0.86)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: geometry.size.width * whiteFraction)

                // Repère central (égalité) : fin trait à mi-largeur.
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 1)
                    .frame(maxWidth: .infinity, alignment: .center)

                if showsLabel, let label {
                    Text(label)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(advantage == .white ? Color.black : Color.white)
                        .padding(.horizontal, 9)
                        .frame(maxWidth: .infinity, alignment: advantage == .white ? .leading : .trailing)
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        // Liseré et ombre proportionnés : à 8 pt, un contour de 1,5 pt mange
        // près de la moitié de la barre et la rend grise.
        .overlay(Capsule().strokeBorder(Color.gray.opacity(0.55), lineWidth: height >= 14 ? 1.5 : 1))
        .shadow(color: .black.opacity(0.25), radius: height >= 14 ? 4 : 2, y: height >= 14 ? 2 : 1)
        .accessibilityElement()
        .accessibilityLabel("Évaluation")
        .accessibilityValue(accessibilityValue)
        // Sur la fraction affichée (pas sur `evalCp` seul) : un passage
        // cp → mat (ou l'inverse) change la largeur sans changer `evalCp`
        // et sautait brutalement au lieu de s'animer.
        .animation(.easeInOut(duration: 0.3), value: whiteFraction)
    }

    private var advantage: Advantage {
        if let evalMate {
            return evalMate > 0 ? .white : (evalMate < 0 ? .black : .equal)
        }
        guard let evalCp else { return .equal }
        if evalCp > 5 { return .white }
        if evalCp < -5 { return .black }
        return .equal
    }

    private var whiteFraction: Double {
        if let evalMate {
            return evalMate > 0 ? 1.0 : 0.0
        }
        guard let evalCp else { return 0.5 }
        return min(1, max(0, EvalConversion.winPercentage(cp: evalCp) / 100))
    }

    /// Valeur lue par VoiceOver (« +0,8 pour les blancs », « mat en 3 pour
    /// les noirs », « position égale »).
    private var accessibilityValue: String {
        let side = advantage == .white
            ? LocalizationController.string("les blancs")
            : LocalizationController.string("les noirs")
        if let evalMate {
            return LocalizationController.string("mat en %lld pour %@", abs(evalMate), side)
        }
        guard advantage != .equal, let evalCp else { return LocalizationController.string("position égale") }
        // Le nombre se formate à part : « %.1f » est du formatage numérique,
        // pas de la langue, et une phrase traduisible ne doit pas transporter
        // des spécificateurs de format que le traducteur risque de casser.
        let amount = String(format: "%.1f", abs(Double(evalCp)) / 100)
        return LocalizationController.string("%@ pour %@", amount, side)
    }

    /// `nil` en cas d'égalité : aucun score n'est alors affiché.
    private var label: String? {
        guard advantage != .equal else { return nil }
        if let evalMate {
            return "M\(abs(evalMate))"
        }
        guard let evalCp else { return nil }
        return String(format: "%+.1f", Double(evalCp) / 100)
    }
}
