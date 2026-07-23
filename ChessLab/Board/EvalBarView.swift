import SwiftUI

/// Barre horizontale d'avantage (blanc à gauche, noir à droite), basée sur
/// la même conversion éval→probabilité de gain que le mode Analyser
/// (voir ``EvalConversion``). Partagée entre le mode Jouer et le mode
/// Analyser.
struct EvalBarView: View {
    let evalCp: Int?
    let evalMate: Int?

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

                if let label {
                    Text(label)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(advantage == .white ? Color.black : Color.white)
                        .padding(.horizontal, 9)
                        .frame(maxWidth: .infinity, alignment: advantage == .white ? .leading : .trailing)
                }
            }
        }
        .frame(height: 20)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.gray.opacity(0.55), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
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
            ? String(localized: "les blancs")
            : String(localized: "les noirs")
        if let evalMate {
            return String(localized: "mat en \(abs(evalMate)) pour \(side)")
        }
        guard advantage != .equal, let evalCp else { return String(localized: "position égale") }
        // Le nombre se formate à part : « %.1f » est du formatage numérique,
        // pas de la langue, et une phrase traduisible ne doit pas transporter
        // des spécificateurs de format que le traducteur risque de casser.
        let amount = String(format: "%.1f", abs(Double(evalCp)) / 100)
        return String(localized: "\(amount) pour \(side)")
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
