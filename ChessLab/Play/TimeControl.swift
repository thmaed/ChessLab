import Foundation

/// Catégorie d'une cadence, pour le regroupement à l'affichage.
enum TimeControlCategory: String, CaseIterable, Codable {
    case none = "Sans limite"
    case bullet = "Bullet"
    case blitz = "Blitz"
    case rapid = "Rapide"
    case classical = "Classique"
    case custom = "Personnalisé"

    /// Symbole de la famille : un repère visuel qui se lit plus vite que le
    /// mot, du plus rapide au plus lent.
    var symbolName: String {
        switch self {
        case .none: "infinity"
        case .bullet: "hare.fill"
        case .blitz: "bolt.fill"
        case .rapid: "timer"
        case .classical: "tortoise.fill"
        case .custom: "slider.horizontal.3"
        }
    }

    /// Libellé affiché. `rawValue` reste la clé de sérialisation (Codable) et
    /// ne doit donc PAS changer ; l'affichage passe par ce label localisé.
    var label: String {
        switch self {
        case .none: "Sans limite"
        case .bullet: "Bullet"
        case .blitz: "Blitz"
        case .rapid: "Rapide"
        case .classical: "Classique"
        case .custom: "Personnalisé"
        }
    }
}

/// Cadence de jeu (double pendule) pour une partie.
struct TimeControl: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let category: TimeControlCategory
    let label: String
    /// Temps de départ par joueur, en secondes.
    let initialSeconds: Int
    /// Incrément par coup joué, en secondes.
    let incrementSeconds: Int

    var hasClock: Bool { initialSeconds > 0 }

    /// Construit une cadence personnalisée à partir de minutes/secondes
    /// choisies par l'utilisateur.
    static func custom(minutes: Int, incrementSeconds: Int) -> TimeControl {
        TimeControl(
            id: "custom",
            category: .custom,
            label: incrementSeconds > 0 ? "\(minutes)+\(incrementSeconds)" : "\(minutes)+0",
            initialSeconds: minutes * 60,
            incrementSeconds: incrementSeconds
        )
    }

    static let none = TimeControl(id: "none", category: .none, label: "Sans limite de temps", initialSeconds: 0, incrementSeconds: 0)

    static let bullet1_0 = TimeControl(id: "bullet_1_0", category: .bullet, label: "1+0", initialSeconds: 60, incrementSeconds: 0)
    static let bullet2_1 = TimeControl(id: "bullet_2_1", category: .bullet, label: "2+1", initialSeconds: 120, incrementSeconds: 1)

    static let blitz3_0 = TimeControl(id: "blitz_3_0", category: .blitz, label: "3+0", initialSeconds: 180, incrementSeconds: 0)
    static let blitz3_2 = TimeControl(id: "blitz_3_2", category: .blitz, label: "3+2", initialSeconds: 180, incrementSeconds: 2)
    static let blitz5_0 = TimeControl(id: "blitz_5_0", category: .blitz, label: "5+0", initialSeconds: 300, incrementSeconds: 0)

    static let rapid10_0 = TimeControl(id: "rapid_10_0", category: .rapid, label: "10+0", initialSeconds: 600, incrementSeconds: 0)
    static let rapid15_10 = TimeControl(id: "rapid_15_10", category: .rapid, label: "15+10", initialSeconds: 900, incrementSeconds: 10)
    static let rapid30_0 = TimeControl(id: "rapid_30_0", category: .rapid, label: "30+0", initialSeconds: 1800, incrementSeconds: 0)

    static let classical30_30 = TimeControl(id: "classical_30_30", category: .classical, label: "30+30", initialSeconds: 1800, incrementSeconds: 30)
    static let classical90_30 = TimeControl(id: "classical_90_30", category: .classical, label: "90+30", initialSeconds: 5400, incrementSeconds: 30)

    /// Préréglages proposés (hors "Personnalisé", géré séparément dans l'UI).
    static let presets: [TimeControl] = [
        .none,
        .bullet1_0, .bullet2_1,
        .blitz3_0, .blitz3_2, .blitz5_0,
        .rapid10_0, .rapid15_10, .rapid30_0,
        .classical30_30, .classical90_30,
    ]
}
