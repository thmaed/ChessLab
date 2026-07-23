import Foundation

/// Une ligne suggérée par le livre d'ouvertures, formant un arbre : chaque
/// nœud est un coup en SAN relatif à la position de son parent.
struct OpeningBookNode: Codable, Sendable {
    /// Coup en SAN (ex. "e4", "Nf3", "O-O").
    let san: String
    /// Popularité relative pour le tirage pondéré (échelle libre, ex. 5...100).
    let weight: Int
    /// Faux pour une ligne secondaire — utilisé par le réglage "largeur".
    var isMainLine: Bool = true
    var children: [OpeningBookNode] = []

    init(san: String, weight: Int, isMainLine: Bool = true, children: [OpeningBookNode] = []) {
        self.san = san
        self.weight = weight
        self.isMainLine = isMainLine
        self.children = children
    }

    // Décodeur écrit à la main : la synthèse automatique de `Decodable`
    // n'utilise PAS les valeurs par défaut ci-dessus pour une clé JSON
    // absente sur une propriété non optionnelle — elle échouerait sur
    // tout nœud qui omet "isMainLine" (la quasi-totalité du livre, qui ne
    // précise ce champ que pour les lignes secondaires).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        san = try container.decode(String.self, forKey: .san)
        weight = try container.decode(Int.self, forKey: .weight)
        isMainLine = try container.decodeIfPresent(Bool.self, forKey: .isMainLine) ?? true
        children = try container.decodeIfPresent([OpeningBookNode].self, forKey: .children) ?? []
    }
}

/// Racine de l'arbre : les premiers coups possibles pour les Blancs. Le
/// même arbre sert que le moteur joue Blancs ou Noirs, la recherche étant
/// purement positionnelle (voir ``OpeningBookEngine``).
struct OpeningBook: Codable, Sendable {
    let roots: [OpeningBookNode]
}
