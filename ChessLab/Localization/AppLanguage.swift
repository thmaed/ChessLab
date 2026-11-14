import Foundation
import SwiftUI

/// Langue de l'interface.
///
/// L'app parle cinq langues : français, anglais, espagnol, allemand, italien. Par
/// défaut elle suit la langue du système (la première langue préférée qui est
/// l'une des cinq — variantes régionales comprises : fr-CH, es-MX, de-AT… —,
/// anglais sinon), mais un réglage permet de forcer l'une d'elles.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Suit la langue du système (le défaut).
    case system
    case french
    case english
    case spanish
    case german
    case italian

    var id: String { rawValue }

    /// Les langues dans lesquelles l'app est traduite (codes ISO 639-1). Une
    /// seule liste : le choix système, les repli et les tests s'y réfèrent.
    static let supportedCodes: [String] = ["fr", "en", "es", "de", "it"]

    /// Libellé du réglage. `LocalizedStringKey` (et non `String(localized:)`)
    /// pour que le basculement instantané fonctionne : c'est SwiftUI qui
    /// résout la clé via le bundle détourné, là où `String(localized:)`
    /// suivrait la langue de l'OS. « Français »/« English » ne sont pas des
    /// clés du catalogue : ils restent tels quels — un nom de langue s'affiche
    /// dans sa propre langue, comme dans les Réglages d'iOS.
    var settingsLabel: LocalizedStringKey {
        switch self {
        case .system: "Automatique"
        case .french: "Français"
        case .english: "English"
        case .spanish: "Español"
        case .german: "Deutsch"
        case .italian: "Italiano"
        }
    }

    /// Code de langue effectif à appliquer, une fois « système » résolu.
    var resolvedCode: String {
        switch self {
        case .french: "fr"
        case .english: "en"
        case .spanish: "es"
        case .german: "de"
        case .italian: "it"
        case .system: Self.systemPreferredCode()
        }
    }

    /// La première langue préférée du système que l'app parle (`fr`, `en`,
    /// `es`, `de`, `it`, variantes régionales comprises), anglais sinon.
    ///
    /// On regarde le CODE DE LANGUE (`languageCode`), pas la région : « fr-CA »
    /// (français canadien) doit donner du français, quand bien même le pays
    /// est le Canada. C'est exactement le piège que la consigne signale.
    static func systemPreferredCode() -> String {
        preferredCode(among: Locale.preferredLanguages)
    }

    /// Cœur testable de ``systemPreferredCode()`` : une liste d'identifiants
    /// de locale dans l'ordre de préférence → l'un des codes pris en charge.
    static func preferredCode(among identifiers: [String]) -> String {
        for identifier in identifiers {
            if let language = Locale(identifier: identifier).language.languageCode?.identifier,
               supportedCodes.contains(language) {
                return language
            }
        }
        // Aucune des langues de l'app dans les préférences : anglais par
        // défaut (langue de repli de l'app).
        return "en"
    }
}
