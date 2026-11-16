import Foundation

/// « iPhone12,1 » → « iPhone 11 » : le nom commercial d'un appareil, à partir de l'identifiant matériel que
/// l'app lit d'elle-même (aucune autorisation, aucun réseau).
///
/// Pourquoi : la liste « Vos appareils » et le bandeau « Dernier coup joué sur votre … » ne disaient que
/// « iPhone » — deux iPhone devenaient indiscernables (essai sur trois iPhone, 16/11/2026).
///
/// La table vient des profils d'appareils de Xcode 27.1 (`modelIdentifier` de chaque `.simdevicetype`),
/// complétés des variantes Wi-Fi/cellulaire des iPad, pour tout ce qu'iOS 18 (la cible minimale) fait
/// tourner. Un modèle plus récent que la table s'affiche simplement « iPhone » ou « iPad ».
///
/// Les noms restent les mêmes dans toutes les langues, sauf deux détails composés ici : la taille (« 12,9″ »
/// en français, « 12.9″ » en anglais) et la génération (« 3ᵉ génération », « 3rd generation »…).
enum DeviceModelName {
    enum Detail: Equatable {
        case none
        /// La puce, qui distingue les modèles récents : « M4 », « A16 »…
        case chip(String)
        case generation(Int)
    }

    struct Model: Equatable {
        let base: String
        /// En pouces, avec un POINT décimal (« 12.9 ») ; la langue choisit le séparateur.
        var inches: String? = nil
        var detail: Detail = .none
    }

    // MARK: Nom

    /// Le nom d'un identifiant connu, dans la langue active de l'app ; `nil` s'il est inconnu.
    static func name(for identifier: String, language: String = LocalizationController.activeLanguageCode) -> String? {
        model(for: identifier).map { format($0, language: language) }
    }

    /// Ce qu'on affiche pour une valeur qui est SOIT un identifiant (« iPhone12,1 »), SOIT un nom déjà
    /// lisible — un type (« iPad », tel que l'écrivaient les premières versions) ou le nom que l'utilisateur
    /// a donné à l'appareil, rendu tel quel : le nom du modèle s'il est connu, sinon la famille.
    static func display(_ value: String, language: String = LocalizationController.activeLanguageCode) -> String {
        if let name = name(for: value, language: language) { return name }
        guard value.wholeMatch(of: #/(iPhone|iPad)\d+,\d+/#) != nil else { return value }
        return value.hasPrefix("iPad") ? "iPad" : "iPhone"
    }

    static func model(for identifier: String) -> Model? {
        table[identifier]
    }

    static func format(_ model: Model, language: String) -> String {
        var name = model.base
        if let inches = model.inches {
            name += " " + (language == "en" ? inches : inches.replacingOccurrences(of: ".", with: ",")) + "″"
        }
        switch model.detail {
        case .none: break
        case let .chip(chip): name += " (\(chip))"
        case let .generation(n): name += " (\(generation(n, language: language)))"
        }
        return name
    }

    /// « 3ᵉ génération », « 3rd generation », « 3.ª generación », « 3. Generation », « 3ª generazione » —
    /// les formes qu'Apple emploie dans chaque langue.
    static func generation(_ n: Int, language: String) -> String {
        switch language {
        case "en":
            let suffix: String
            switch (n % 10, n % 100) {
            case (_, 11...13): suffix = "th"
            case (1, _): suffix = "st"
            case (2, _): suffix = "nd"
            case (3, _): suffix = "rd"
            default: suffix = "th"
            }
            return "\(n)\(suffix) generation"
        case "es": return "\(n).ª generación"
        case "de": return "\(n). Generation"
        case "it": return "\(n)ª generazione"
        default: return n == 1 ? "1ʳᵉ génération" : "\(n)ᵉ génération"
        }
    }

    // MARK: Table

    private static let table: [String: Model] = {
        var table: [String: Model] = [:]
        func add(_ family: String, _ major: Int, _ minors: ClosedRange<Int>, _ model: Model) {
            for minor in minors { table["\(family)\(major),\(minor)"] = model }
        }
        func phone(_ major: Int, _ minor: Int, _ name: String, _ detail: Detail = .none) {
            add("iPhone", major, minor...minor, Model(base: name, detail: detail))
        }

        // iPhone (iOS 18 et au-delà : depuis l'iPhone XS).
        phone(11, 2, "iPhone XS"); phone(11, 4, "iPhone XS Max"); phone(11, 6, "iPhone XS Max")
        phone(11, 8, "iPhone XR")
        phone(12, 1, "iPhone 11"); phone(12, 3, "iPhone 11 Pro"); phone(12, 5, "iPhone 11 Pro Max")
        phone(12, 8, "iPhone SE", .generation(2))
        phone(13, 1, "iPhone 12 mini"); phone(13, 2, "iPhone 12"); phone(13, 3, "iPhone 12 Pro")
        phone(13, 4, "iPhone 12 Pro Max")
        phone(14, 2, "iPhone 13 Pro"); phone(14, 3, "iPhone 13 Pro Max"); phone(14, 4, "iPhone 13 mini")
        phone(14, 5, "iPhone 13"); phone(14, 6, "iPhone SE", .generation(3))
        phone(14, 7, "iPhone 14"); phone(14, 8, "iPhone 14 Plus")
        phone(15, 2, "iPhone 14 Pro"); phone(15, 3, "iPhone 14 Pro Max")
        phone(15, 4, "iPhone 15"); phone(15, 5, "iPhone 15 Plus")
        phone(16, 1, "iPhone 15 Pro"); phone(16, 2, "iPhone 15 Pro Max")
        phone(17, 1, "iPhone 16 Pro"); phone(17, 2, "iPhone 16 Pro Max"); phone(17, 3, "iPhone 16")
        phone(17, 4, "iPhone 16 Plus"); phone(17, 5, "iPhone 16e")
        phone(18, 1, "iPhone 17 Pro"); phone(18, 2, "iPhone 17 Pro Max"); phone(18, 3, "iPhone 17")
        phone(18, 4, "iPhone Air"); phone(18, 5, "iPhone 17e")
        phone(19, 2, "iPhone 18 Pro"); phone(19, 3, "iPhone 18 Pro Max"); phone(19, 4, "iPhone Duo")

        // iPad (iPadOS 18 et au-delà), chaque modèle avec ses variantes Wi-Fi et cellulaires.
        add("iPad", 7, 11...12, Model(base: "iPad", detail: .generation(7)))
        add("iPad", 8, 1...4, Model(base: "iPad Pro", inches: "11", detail: .generation(1)))
        add("iPad", 8, 5...8, Model(base: "iPad Pro", inches: "12.9", detail: .generation(3)))
        add("iPad", 8, 9...10, Model(base: "iPad Pro", inches: "11", detail: .generation(2)))
        add("iPad", 8, 11...12, Model(base: "iPad Pro", inches: "12.9", detail: .generation(4)))
        add("iPad", 11, 1...2, Model(base: "iPad mini", detail: .generation(5)))
        add("iPad", 11, 3...4, Model(base: "iPad Air", detail: .generation(3)))
        add("iPad", 11, 6...7, Model(base: "iPad", detail: .generation(8)))
        add("iPad", 12, 1...2, Model(base: "iPad", detail: .generation(9)))
        add("iPad", 13, 1...2, Model(base: "iPad Air", detail: .generation(4)))
        add("iPad", 13, 4...7, Model(base: "iPad Pro", inches: "11", detail: .generation(3)))
        add("iPad", 13, 8...11, Model(base: "iPad Pro", inches: "12.9", detail: .generation(5)))
        add("iPad", 13, 16...17, Model(base: "iPad Air", detail: .generation(5)))
        add("iPad", 13, 18...19, Model(base: "iPad", detail: .generation(10)))
        add("iPad", 14, 1...2, Model(base: "iPad mini", detail: .generation(6)))
        add("iPad", 14, 3...4, Model(base: "iPad Pro", inches: "11", detail: .generation(4)))
        add("iPad", 14, 5...6, Model(base: "iPad Pro", inches: "12.9", detail: .generation(6)))
        add("iPad", 14, 8...9, Model(base: "iPad Air", inches: "11", detail: .chip("M2")))
        add("iPad", 14, 10...11, Model(base: "iPad Air", inches: "13", detail: .chip("M2")))
        add("iPad", 15, 3...4, Model(base: "iPad Air", inches: "11", detail: .chip("M3")))
        add("iPad", 15, 5...6, Model(base: "iPad Air", inches: "13", detail: .chip("M3")))
        add("iPad", 15, 7...8, Model(base: "iPad", detail: .chip("A16")))
        add("iPad", 16, 1...2, Model(base: "iPad mini", detail: .chip("A17 Pro")))
        add("iPad", 16, 3...4, Model(base: "iPad Pro", inches: "11", detail: .chip("M4")))
        add("iPad", 16, 5...6, Model(base: "iPad Pro", inches: "13", detail: .chip("M4")))
        add("iPad", 16, 8...9, Model(base: "iPad Air", inches: "11", detail: .chip("M4")))
        add("iPad", 16, 10...11, Model(base: "iPad Air", inches: "13", detail: .chip("M4")))
        add("iPad", 17, 1...2, Model(base: "iPad Pro", inches: "11", detail: .chip("M5")))
        add("iPad", 17, 3...4, Model(base: "iPad Pro", inches: "13", detail: .chip("M5")))
        return table
    }()
}
