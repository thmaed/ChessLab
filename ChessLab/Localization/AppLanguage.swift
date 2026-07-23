import Foundation
import SwiftUI

/// Langue de l'interface.
///
/// L'app est bilingue français / anglais. Par défaut elle suit la langue du
/// système (français si l'OS est en français — de France, de Suisse ou du
/// Canada —, anglais sinon), mais un réglage permet de forcer l'une ou
/// l'autre.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Suit la langue du système (le défaut).
    case system
    case french
    case english

    var id: String { rawValue }

    /// Libellé du réglage. `LocalizedStringKey` (et non `String(localized:)`)
    /// pour que le basculement instantané fonctionne : c'est SwiftUI qui
    /// résout la clé via le bundle détourné, là où `String(localized:)`
    /// suivrait la langue de l'OS. « Français »/« English » ne sont pas des
    /// clés du catalogue : ils restent tels quels — un nom de langue s'affiche
    /// dans sa propre langue, comme dans les Réglages d'iOS.
    var settingsLabel: LocalizedStringKey {
        switch self {
        case .system: "Langue du système"
        case .french: "Français"
        case .english: "English"
        }
    }

    /// Code de langue effectif à appliquer, une fois « système » résolu.
    var resolvedCode: String {
        switch self {
        case .french: "fr"
        case .english: "en"
        case .system: Self.systemPreferredCode()
        }
    }

    /// Français si la première langue préférée du système est une variante du
    /// français (`fr`, `fr-CH`, `fr-CA`…), anglais sinon.
    ///
    /// On regarde le CODE DE LANGUE (`languageCode`), pas la région : « fr-CA »
    /// (français canadien) doit donner du français, quand bien même le pays
    /// est le Canada. C'est exactement le piège que la consigne signale.
    static func systemPreferredCode() -> String {
        for identifier in Locale.preferredLanguages {
            let language = Locale(identifier: identifier).language.languageCode?.identifier
            if language == "fr" { return "fr" }
            if language == "en" { return "en" }
        }
        // Ni français ni anglais dans les préférences : anglais par défaut
        // (langue de repli de l'app).
        return "en"
    }
}
