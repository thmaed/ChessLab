import ChessKitEngine

/// Réglage de la force du moteur pour le mode Jouer.
///
/// Stockfish ne permet de limiter `UCI_Elo` qu'entre 1320 et 3190. En
/// dessous, on simule un niveau plus faible en désactivant `UCI_LimitStrength`
/// et en abaissant `Skill Level` + la profondeur de recherche à la place.
enum EngineStrength: Equatable {
    /// Force plafonnée via `UCI_LimitStrength` + `UCI_Elo` (1320...3190).
    case limited(elo: Int)
    /// Simulation d'un niveau sous 1320 : `Skill Level` bas + profondeur limitée.
    case belowMinimum(approximateElo: Int, skillLevel: Int, depth: Int)
    /// Aucune limite : pleine puissance du moteur.
    case maximum

    /// Plage complète (Laboratoire) : jusqu'à la pleine puissance, qui est
    /// tout l'intérêt de faire s'affronter deux moteurs.
    static let sliderRange: ClosedRange<Double> = 800...3190
    /// Plage du mode **Jouer**, plafonnée à 2500 : au-delà, on ne propose plus
    /// un adversaire, on propose une défaite. Le Laboratoire, lui, garde la
    /// plage complète.
    static let playSliderRange: ClosedRange<Double> = 800...2500
    static let ratedMinimum = 1320

    /// Construit un réglage à partir d'une valeur de slider continue.
    init(sliderValue: Double) {
        let elo = Int(sliderValue.rounded())

        if elo >= 3190 {
            self = .maximum
        } else if elo >= Self.ratedMinimum {
            self = .limited(elo: elo)
        } else {
            // Interpole skill level (0...5) et profondeur (1...6) sur la
            // plage 800...1319 pour approcher un niveau très faible.
            let t = Double(elo - 800) / Double(Self.ratedMinimum - 1 - 800)
            let skill = Int((t * 5).rounded())
            let depth = Int((1 + t * 5).rounded())
            self = .belowMinimum(approximateElo: elo, skillLevel: max(0, skill), depth: max(1, depth))
        }
    }

    /// Valeur à afficher sur le slider pour ce réglage.
    var sliderValue: Double {
        switch self {
        case let .limited(elo): Double(elo)
        case let .belowMinimum(approximateElo, _, _): Double(approximateElo)
        case .maximum: Self.sliderRange.upperBound
        }
    }

    /// Commandes `setoption` UCI à envoyer au moteur pour appliquer ce réglage.
    var setupCommands: [EngineCommand] {
        switch self {
        case let .limited(elo):
            [
                .setoption(id: "UCI_LimitStrength", value: "true"),
                .setoption(id: "UCI_Elo", value: "\(elo)"),
                .setoption(id: "Skill Level", value: "20"),
            ]
        case let .belowMinimum(_, skillLevel, _):
            [
                .setoption(id: "UCI_LimitStrength", value: "false"),
                .setoption(id: "Skill Level", value: "\(skillLevel)"),
            ]
        case .maximum:
            [
                .setoption(id: "UCI_LimitStrength", value: "false"),
                .setoption(id: "Skill Level", value: "20"),
            ]
        }
    }

    /// Profondeur de recherche maximale à utiliser pour `go depth`, si
    /// applicable (les niveaux sous 1320 plafonnent aussi la profondeur).
    var maxDepth: Int? {
        if case let .belowMinimum(_, _, depth) = self {
            depth
        } else {
            nil
        }
    }

    /// Description courte pour affichage.
    var displayLabel: String {
        switch self {
        case let .limited(elo): "Elo \(elo)"
        case let .belowMinimum(approximateElo, _, _): "Elo ~\(approximateElo)"
        case .maximum: "Maximum"
        }
    }
}

/// Préréglages proposés à l'utilisateur en plus du slider libre.
struct EnginePreset: Identifiable, Equatable {
    let id: String
    let label: String
    let strength: EngineStrength

    /// Libellé affiché sur le chip, avec l'Elo approximatif.
    var chipLabel: String {
        strength == .maximum ? label : "\(label) (\(Int(strength.sliderValue)))"
    }

    /// Échelle du mode Jouer. Plus de « Élite mondiale » (2800) ni de
    /// « Maximum » : ces deux-là ne se jouent pas, ils se subissent. Les deux
    /// marches ajoutées en bas (1000 et 1400) resserrent au contraire l'écart
    /// là où l'on progresse vraiment — entre le grand débutant et le joueur de
    /// club, l'ancienne échelle sautait de 800 à 1200 puis à 1600.
    static let all: [EnginePreset] = [
        .init(id: "e800", label: "Grand débutant", strength: EngineStrength(sliderValue: 800)),
        .init(id: "e1000", label: "Débutant", strength: EngineStrength(sliderValue: 1000)),
        .init(id: "e1200", label: "Débutant confirmé", strength: EngineStrength(sliderValue: 1200)),
        .init(id: "e1400", label: "Intermédiaire", strength: .limited(elo: 1400)),
        .init(id: "e1600", label: "Intermédiaire confirmé", strength: .limited(elo: 1600)),
        .init(id: "e2000", label: "Avancé / Expert", strength: .limited(elo: 2000)),
        .init(id: "e2300", label: "Maître national", strength: .limited(elo: 2300)),
        .init(id: "e2500", label: "Grand Maître", strength: .limited(elo: 2500)),
    ]
}
