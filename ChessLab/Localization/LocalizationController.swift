import Foundation

/// Applique la langue choisie à TOUTE l'app, immédiatement.
///
/// Le problème : `Text("…")` de SwiftUI suit la locale de l'environnement,
/// mais `String(localized:)` interroge, lui, la localisation par défaut du
/// bundle principal — fixée au lancement. Changer de langue en cours de
/// session ne toucherait donc que la moitié des textes.
///
/// La solution classique, éprouvée : on remplace la classe de `Bundle.main`
/// par une sous-classe qui redirige toute recherche de chaîne vers le
/// `.lproj` de la langue choisie. `Text` ET `String(localized:)` passent tous
/// deux par là — un seul point de vérité, et le changement est instantané.
final class LocalizationController {

    /// Bundle de la langue active ; `nil` = comportement par défaut du système.
    fileprivate static nonisolated(unsafe) var overrideBundle: Bundle?

    /// Installe la redirection (une seule fois) et applique le code de langue.
    static func apply(languageCode: String) {
        installOverrideOnce()
        overrideBundle = lproj(for: languageCode)
    }

    /// Traduit une clé (le texte FRANÇAIS source) dans la langue ACTIVE de
    /// l'app, hors SwiftUI.
    ///
    /// `String(localized:)` suit la langue de l'OS, pas le choix in-app : pour
    /// tout ce qui n'est pas un `Text` — libellés d'accessibilité surtout — on
    /// passe par ici, qui lit dans le bundle détourné.
    static func string(_ frenchKey: String) -> String {
        guard let bundle = overrideBundle else { return frenchKey }
        return bundle.localizedString(forKey: frenchKey, value: frenchKey, table: nil)
    }

    private static nonisolated(unsafe) var installed = false

    private static func installOverrideOnce() {
        guard !installed else { return }
        installed = true
        object_setClass(Bundle.main, LanguageRedirectingBundle.self)
    }

    /// Bundle du `.lproj` demandé, avec repli sur l'anglais puis sur le bundle
    /// principal (jamais de crash si une langue manque).
    private static func lproj(for code: String) -> Bundle? {
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return nil
    }
}

/// `Bundle.main` réétiqueté : redirige la recherche de chaînes vers la langue
/// choisie. En dehors de la localisation, se comporte comme le bundle normal.
private final class LanguageRedirectingBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = LocalizationController.overrideBundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}
