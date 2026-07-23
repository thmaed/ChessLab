import Foundation

/// Réglage bas niveau : aucune interface utilisateur ne l'expose encore
/// (pas d'écran Réglages avant une étape ultérieure). Existe seulement
/// pour que le `ModelConfiguration` de ``ChessLabApp`` puisse basculer
/// vers CloudKit plus tard sans revoir sa construction.
///
/// - important: Faux par défaut. Le mettre à vrai ne suffit pas à activer
/// une synchronisation réelle : il faut au préalable ajouter, une fois et
/// manuellement, la capacité iCloud dans Xcode (Signing & Capabilities) —
/// non automatisable de façon fiable dans cet environnement même si un
/// compte développeur (`DEVELOPMENT_TEAM`) est déjà configuré.
enum CloudSyncSettingsStore {
    private static let key = "cloudKitSyncEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
