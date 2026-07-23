import Foundation

/// Largeur du livre : lignes principales uniquement, ou avec variantes
/// secondaires.
enum OpeningBookWidth: String, Codable, Equatable, Hashable {
    case mainLinesOnly
    case includeSidelines
}

/// Logique de tirage dans le livre d'ouvertures — pure, sans dépendance à
/// `Board`/`Piece.Color`, réutilisable telle quelle par tout mode qui
/// pilote un moteur (Jouer aujourd'hui, Laboratoire plus tard).
enum OpeningBookEngine {
    /// `sanPath` : les coups déjà joués dans la partie, en SAN, depuis le
    /// début. Retourne le SAN du prochain coup à jouer, ou `nil` si la
    /// position ne figure plus dans le livre (ou si le livre est vide) —
    /// il faut alors basculer sur le calcul normal du moteur.
    static func pickNextMove(book: OpeningBook, sanPath: [String], width: OpeningBookWidth) -> String? {
        var candidates = book.roots
        for played in sanPath {
            guard let match = candidates.first(where: { $0.san == played }) else {
                return nil
            }
            candidates = match.children
        }

        let eligible = width == .mainLinesOnly ? candidates.filter(\.isMainLine) : candidates
        guard !eligible.isEmpty else { return nil }
        return weightedRandom(eligible)
    }

    private static func weightedRandom(_ nodes: [OpeningBookNode]) -> String? {
        let total = nodes.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nodes.first?.san }

        var roll = Int.random(in: 0..<total)
        for node in nodes {
            if roll < node.weight { return node.san }
            roll -= node.weight
        }
        return nodes.last?.san
    }
}
