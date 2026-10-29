import Foundation
import StoreKit
import SwiftUI

/// Quand demander un avis sur l'App Store.
///
/// Né le 29/10/2026 : la 2.0 n'avait AUCUNE note sur l'App Store, et rien dans
/// l'app ne la demandait. Le nombre et la moyenne des notes pèsent dans le
/// classement des stores — c'est le levier de visibilité le moins coûteux.
///
/// La règle est volontairement prudente : demander au mauvais moment coûte une
/// mauvaise note. On ne demande que JUSTE APRÈS une réussite (une partie gagnée
/// contre l'ordinateur, un cycle Woodpecker bouclé), à quelqu'un qui revient
/// (trois jours d'entraînement au moins), une fois par version au plus, et pas
/// plus d'une fois tous les 120 jours. Apple plafonne de son côté l'affichage à
/// trois fois par an ; la règle reste en deçà.
///
/// Pendant Android : `ReviewPrompt.kt` (même règle ; une invitation dans l'app
/// mène à la fiche Play, faute d'API système sans bibliothèque propriétaire).
struct ReviewPromptPolicy: Equatable {
    var positiveMoments = 0
    var trainingDays = 0
    var lastAskedVersion: String?
    var lastAskedAt: Date?

    static let minimumPositiveMoments = 2
    static let minimumTrainingDays = 3
    static let minimumDaysBetweenAsks = 120

    func shouldAsk(version: String, now: Date = Date()) -> Bool {
        guard positiveMoments >= Self.minimumPositiveMoments,
              trainingDays >= Self.minimumTrainingDays,
              lastAskedVersion != version
        else { return false }
        guard let lastAskedAt else { return true }
        let days = Calendar.current.dateComponents([.day], from: lastAskedAt, to: now).day ?? 0
        return days >= Self.minimumDaysBetweenAsks
    }
}

/// L'état de la règle, dans `UserDefaults` (local à l'appareil, comme les jours
/// d'entraînement dont elle se sert).
@MainActor
enum ReviewPrompt {
    private static let positivesKey = "reviewPrompt.positiveMoments"
    private static let versionKey = "reviewPrompt.lastAskedVersion"
    private static let dateKey = "reviewPrompt.lastAskedAt"

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static func policy(defaults: UserDefaults = .standard) -> ReviewPromptPolicy {
        ReviewPromptPolicy(
            positiveMoments: defaults.integer(forKey: positivesKey),
            trainingDays: TrainingDays.all(defaults: defaults).count,
            lastAskedVersion: defaults.string(forKey: versionKey),
            lastAskedAt: defaults.object(forKey: dateKey) as? Date
        )
    }

    /// Une réussite vient d'avoir lieu. Renvoie `true` s'il est temps de demander
    /// un avis — l'appelant le fait alors, et la demande est aussitôt notée.
    @discardableResult
    static func recordPositiveMoment(defaults: UserDefaults = .standard, now: Date = Date()) -> Bool {
        defaults.set(defaults.integer(forKey: positivesKey) + 1, forKey: positivesKey)
        guard policy(defaults: defaults).shouldAsk(version: appVersion, now: now) else { return false }
        defaults.set(appVersion, forKey: versionKey)
        defaults.set(now, forKey: dateKey)
        return true
    }

    /// Note la réussite et, le moment venu, présente la demande système — deux
    /// secondes plus tard, le temps de savourer la victoire. En Debug, jamais sauf
    /// `-allowReviewPrompt` : l'alerte surgirait au milieu des tests d'interface.
    static func celebrate(with requestReview: RequestReviewAction) {
        #if DEBUG
        guard CommandLine.arguments.contains("-allowReviewPrompt") else { return }
        #endif
        guard recordPositiveMoment() else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            requestReview()
        }
    }
}
