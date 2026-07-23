import UIKit

/// Retour haptique pour les événements de l'échiquier.
///
/// Utilise uniquement les générateurs système UIKit (aucun asset,
/// aucune question de licence).
enum Haptics {
    // Générateurs retenus et PRÉPARÉS plutôt que recréés à chaque coup :
    // un générateur jetable non préparé introduit une latence perceptible
    // sur le premier retour. On les re-prépare juste après usage pour que
    // le prochain coup reste instantané.
    @MainActor private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    @MainActor private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    @MainActor private static let notification = UINotificationFeedbackGenerator()

    /// À appeler au démarrage (ou à l'apparition d'un plateau) pour amorcer
    /// le moteur Taptic avant le premier coup.
    @MainActor
    static func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
    }

    @MainActor
    static func move() {
        guard AppSettings.shared.hapticsEnabled else { return }
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    @MainActor
    static func capture() {
        guard AppSettings.shared.hapticsEnabled else { return }
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    @MainActor
    static func check() {
        guard AppSettings.shared.hapticsEnabled else { return }
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    @MainActor
    static func gameEnded() {
        guard AppSettings.shared.hapticsEnabled else { return }
        notification.notificationOccurred(.success)
    }

    @MainActor
    static func illegal() {
        guard AppSettings.shared.hapticsEnabled else { return }
        notification.notificationOccurred(.error)
    }
}
