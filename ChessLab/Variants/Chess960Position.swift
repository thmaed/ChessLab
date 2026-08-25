import Foundation

/// Les 960 positions de départ du Chess960, par leur numéro de Scharnagl.
///
/// L'algorithme est le PORT FIDÈLE de `chess.BaseBoard._set_chess960_pos` de
/// python-chess (lui-même d'après russellcottrell.com/Chess/Chess960.htm) —
/// et le test `Chess960RulesTests` compare les 960 FEN produits à ceux de
/// python-chess, généré par `tools/opening-generator/gen_chess960_fixtures.py`.
/// La numérotation est donc INTERCHANGEABLE avec Lichess et les moteurs :
/// la position 518 est la partie classique.
enum Chess960Position {

    /// Rangée de base (blanche, a→h) du numéro `number` ∈ 0...959.
    static func backRank(number: Int) -> [Character]? {
        guard (0...959).contains(number) else { return nil }

        var n = number
        let bw = n % 4; n /= 4          // fou de cases claires : b, d, f, h
        let bb = n % 4; n /= 4          // fou de cases sombres : a, c, e, g
        let q = n % 6; n /= 6           // dame : q-ième case libre

        // Décomposition N5N : n ∈ 0...9 désigne la paire de cases des
        // cavaliers parmi les 5 restantes — même boucle que python-chess.
        var n1 = 0, n2 = 0
        for candidate in 0..<4 {
            n1 = candidate
            n2 = n + (3 - candidate) * (4 - candidate) / 2 - 5
            if n1 < n2, (1...4).contains(n2) { break }
        }

        var rank = [Character?](repeating: nil, count: 8)
        let bwFile = bw * 2 + 1
        let bbFile = bb * 2
        rank[bwFile] = "B"
        rank[bbFile] = "B"

        var qFile = q
        if min(bwFile, bbFile) <= qFile { qFile += 1 }
        if max(bwFile, bbFile) <= qFile { qFile += 1 }
        rank[qFile] = "Q"

        var counterN1 = n1, counterN2 = n2
        for file in 0..<8 where rank[file] == nil {
            if counterN1 == 0 || counterN2 == 0 {
                rank[file] = "N"
            }
            counterN1 -= 1
            counterN2 -= 1
        }

        // Les trois cases restantes, de gauche à droite : tour, roi, tour.
        for piece in "RKR" {
            guard let file = rank.firstIndex(of: nil) else { return nil }
            rank[file] = piece
        }
        return rank.compactMap(\.self)
    }

    /// La rangée `rank` (8 lettres, a→h) respecte-t-elle les règles du
    /// Chess960 ? Trois conditions, les mêmes que l'algorithme de Scharnagl
    /// impose par construction — nécessaires ici parce qu'un agencement
    /// composé À LA MAIN peut les violer :
    /// - le ROI est strictement ENTRE les deux tours (sans quoi le roque tel
    ///   que cette app le joue — « le roi prend sa tour » — perd son sens : on
    ///   ne saurait plus quelle tour est « petit côté ») ;
    /// - les deux FOUS sont sur des cases de couleurs DIFFÉRENTES (règle FIDE
    ///   du Chess960, pas une contrainte technique de cette app) ;
    /// - le jeu de pièces exact (2 tours, 2 cavaliers, 2 fous, 1 dame, 1 roi)
    ///   — automatiquement vrai si `rank` est un RÉARRANGEMENT d'une rangée
    ///   déjà légale (l'éditeur ne fait que permuter), mais vérifié quand
    ///   même : la fonction doit rester correcte pour tout appelant.
    static func isLegalBackRank(_ rank: [Character]) -> Bool {
        guard rank.count == 8, rank.sorted() == Array("BBKNNQRR") else { return false }
        guard let kingFile = rank.firstIndex(of: "K") else { return false }
        let rookFiles = rank.indices.filter { rank[$0] == "R" }
        guard rookFiles.count == 2, rookFiles[0] < kingFile, kingFile < rookFiles[1] else { return false }
        let bishopFiles = rank.indices.filter { rank[$0] == "B" }
        guard bishopFiles.count == 2 else { return false }
        return bishopFiles[0].isMultiple(of: 2) != bishopFiles[1].isMultiple(of: 2)
    }

    /// Numéro de Scharnagl (0...959) dont la rangée de base est EXACTEMENT
    /// `rank` — `nil` si elle n'est pas légale. Balayage linéaire : 960
    /// positions, coût négligeable, et ça évite d'inverser l'algorithme de
    /// génération pour un besoin qui ne se produit qu'au réglage d'une
    /// partie, jamais en boucle chaude.
    static func number(forBackRank rank: [Character]) -> Int? {
        guard isLegalBackRank(rank) else { return nil }
        return (0...959).first { backRank(number: $0) == rank }
    }

    /// FEN Shredder complet de la position `number` : droits de roque en
    /// lettres de colonnes (ex. `HFhf`), le dialecte que parle Stockfish
    /// sous `UCI_Chess960`.
    static func startingFEN(number: Int) -> String? {
        guard let rank = backRank(number: number) else { return nil }
        let white = String(rank)
        let black = white.lowercased()
        let rookFiles = rank.indices.filter { rank[$0] == "R" }
            .map { Character(UnicodeScalar(UInt8(65 + $0))) }
        // Ordre Shredder : colonnes décroissantes côté blanc (HAha pour la 518).
        let rights = String(rookFiles.sorted(by: >))
        return "\(black)/pppppppp/8/8/8/8/PPPPPPPP/\(white) w \(rights)\(rights.lowercased()) - 0 1"
    }
}
