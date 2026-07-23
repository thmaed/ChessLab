import Foundation

/// Une ouverture nommée de la base ECO (Encyclopaedia of Chess Openings) :
/// code, nom, et la ligne principale (SAN) qui l'identifie.
struct EcoOpening: Codable, Equatable, Sendable {
    let eco: String
    let name: String
    let moves: [String]
}

/// Recherche l'ouverture nommée pour une ligne jouée, par plus long
/// préfixe : parmi toutes les entrées dont `moves` est un préfixe exact
/// de `sanPath`, retourne celle dont `moves` est la plus longue — c'est
/// la classification ECO la plus précise que la ligne jouée confirme.
enum EcoOpeningLookup {
    static func openingName(for sanPath: [String], in database: [EcoOpening]) -> EcoOpening? {
        database
            .filter { entry in
                guard entry.moves.count <= sanPath.count else { return false }
                return Array(sanPath.prefix(entry.moves.count)) == entry.moves
            }
            .max { $0.moves.count < $1.moves.count }
    }

    /// Vrai tant que la ligne jouée est un préfixe d'une ligne de théorie
    /// connue — sens INVERSE de ``openingName(for:in:)`` : ici c'est la
    /// base qui doit prolonger la partie, pas la partie qui prolonge la
    /// base. C'est le critère « coup de théorie » de la classification.
    static func isInBook(_ sanPath: [String], in database: [EcoOpening]) -> Bool {
        guard !sanPath.isEmpty else { return false }
        return database.contains { entry in
            entry.moves.count >= sanPath.count
                && Array(entry.moves.prefix(sanPath.count)) == sanPath
        }
    }
}
