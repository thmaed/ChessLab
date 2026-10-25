import SwiftData
import SwiftUI

/// L'offre d'analyse automatique, à la fin d'une partie contre l'ordinateur —
/// là où l'utilisateur a quelque chose à analyser, et où le bénéfice se dit
/// avec des mots simples. Remplace l'alerte du démarrage (25/10/2026).
///
/// N'apparaît que tant que le choix n'est pas fait (`.undecided`), et au plus
/// ``maxShowings`` fois : une offre qu'on ignore deux fois est une réponse.
struct AutoAnalysisOfferCard: View {
    /// Appelé quand l'utilisateur dit oui : la partie qui vient de finir rejoint la
    /// file (elle a été rangée AVANT le choix, donc pas encore dans la file).
    let onAccept: () -> Void
    @State private var settings = AppSettings.shared

    static let maxShowings = 2
    private static let countKey = "autoAnalysisOfferShowings"

    /// Vrai s'il faut montrer l'offre — et compte cette présentation.
    @MainActor
    static func shouldShow(defaults: UserDefaults = .standard) -> Bool {
        guard AppSettings.shared.autoAnalysisChoice == .undecided else { return false }
        return defaults.integer(forKey: countKey) < maxShowings
    }

    static func noteShown(defaults: UserDefaults = .standard) {
        defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
    }

    var body: some View {
        if settings.autoAnalysisChoice == .undecided {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(Theme.teal)
                    Text("Voir vos erreurs sans rien faire ?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Text("ChessLab peut analyser chacune de vos parties pour repérer vos erreurs, en tirer des puzzles et suivre votre progression. Cela se fait sur l'appareil, en 1 à 3 minutes par partie.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button {
                        settings.autoAnalysisChoice = .on
                        AutoAnalysisService.shared.settingChanged()
                        onAccept()
                    } label: {
                        Text("Oui, automatiquement")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Theme.teal, in: Capsule())
                    }
                    .accessibilityIdentifier("autoAnalysisOfferYes")
                    Button {
                        settings.autoAnalysisChoice = .off
                    } label: {
                        Text("Non merci")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                    .accessibilityIdentifier("autoAnalysisOfferNo")
                    Spacer(minLength: 0)
                }
                Text("Modifiable à tout moment dans les Réglages.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.teal.opacity(0.30), lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("autoAnalysisOffer")
        }
    }
}
