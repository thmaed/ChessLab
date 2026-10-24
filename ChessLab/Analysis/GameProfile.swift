import ChessKit
import Foundation

/// Le code court d'une phase dans la chaîne stockée avec la partie (A4). La
/// phase elle-même est celle des puzzles (``GamePhaseClassifier``) : « Ouverture
/// » d'un puzzle et « ouverture » d'une partie veulent dire la même chose.
extension GamePhase {
    var code: String {
        switch self {
        case .opening: "o"
        case .middlegame: "m"
        case .endgame: "e"
        }
    }
}

/// Points de probabilité de gain perdus sur une phase, et nombre de coups
/// comptés (hors théorie).
struct PhaseLoss: Equatable, Sendable {
    var total: Double = 0
    var count: Int = 0

    var average: Double? { count == 0 ? nil : total / Double(count) }
}

/// Ce qu'une partie dit des faiblesses de CE joueur, rangé dans le
/// ``GameRecord`` (A4) : la perte par phase et les motifs tactiques manqués.
/// Deux chaînes courtes par camp, relues sans recalcul ni réanalyse.
enum GameProfileCodec {

    /// « o:12.5:6,m:30:9,e:4:2 » — phase : perte totale : coups.
    static func encode(phases: [GamePhase: PhaseLoss]) -> String {
        GamePhase.allCases.map { phase in
            let loss = phases[phase] ?? PhaseLoss()
            return "\(phase.code):\(String(format: "%.2f", loss.total)):\(loss.count)"
        }.joined(separator: ",")
    }

    static func decodePhases(_ text: String?) -> [GamePhase: PhaseLoss] {
        var result: [GamePhase: PhaseLoss] = [:]
        for part in (text ?? "").split(separator: ",") {
            let fields = part.split(separator: ":")
            guard fields.count == 3, let phase = GamePhase.allCases.first(where: { $0.code == fields[0] }),
                  let total = Double(fields[1]), let count = Int(fields[2])
            else { continue }
            result[phase] = PhaseLoss(total: total, count: count)
        }
        return result
    }

    /// « fork:2,pin:1 » — motif : fautes, triés par nom pour que deux
    /// analyses de la même partie donnent la même chaîne.
    static func encode(themes: [String: Int]) -> String {
        themes.filter { $0.value > 0 }.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ",")
    }

    static func decodeThemes(_ text: String?) -> [String: Int] {
        var result: [String: Int] = [:]
        for part in (text ?? "").split(separator: ",") {
            let fields = part.split(separator: ":")
            if fields.count == 2, let count = Int(fields[1]) { result[String(fields[0])] = count }
        }
        return result
    }
}

extension TacticalMotif {
    /// Le thème stocké dans le profil d'une partie. `other` (pas de motif
    /// nommable) est ajouté par l'appelant.
    var profileTheme: String {
        switch self {
        case .checkmate: "mate"
        case .hangingPiece: "hanging"
        case .fork: "fork"
        case .discoveredCheck: "discovery"
        case .pin: "pin"
        }
    }
}
