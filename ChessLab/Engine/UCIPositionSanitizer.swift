import Foundation

/// Garde-fou entre l'app et le moteur : une FEN dont le champ de roque annonce un droit que l'échiquier ne
/// permet plus FAIT PLANTER Stockfish.
///
/// Retour d'un joueur (27/10/2026) : l'app plantait à chaque reprise d'une partie. `Position::set` cherche, pour
/// chaque `K`/`Q`/`k`/`q`, la tour du roque en balayant la rangée depuis le coin — sans borne : si la tour a
/// été capturée dans son coin, la boucle sort de l'échiquier et lit la mémoire d'autres fils. Or la FEN que
/// produit ChessKit garde le droit de roque d'un camp quand sa tour est prise dans son coin.
///
/// On corrige donc la FEN AVANT de l'envoyer : un droit n'est conservé que s'il existe, sur la rangée de fond,
/// un roi du camp et une tour du camp du bon côté de ce roi. Les droits « Shredder » (lettres de colonnes) ne
/// font pas balayer le moteur : ils sont laissés tels quels.
enum UCIPositionSanitizer {

    /// La commande UCI, avec la FEN assainie si c'est un `position fen …`. Toute autre commande passe telle quelle.
    static func sanitize(_ uci: String) -> String {
        let prefix = "position fen "
        guard uci.hasPrefix(prefix) else { return uci }
        let rest = String(uci.dropFirst(prefix.count))
        // La FEN court jusqu'à « moves » (ou la fin).
        let parts = rest.components(separatedBy: " moves ")
        let fixed = castlingFixed(parts[0])
        guard parts.count > 1 else { return prefix + fixed }
        return prefix + fixed + " moves " + parts.dropFirst().joined(separator: " moves ")
    }

    /// La FEN, droits de roque ramenés à ce que l'échiquier permet.
    static func castlingFixed(_ fen: String) -> String {
        var fields = fen.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard fields.count >= 3 else { return fen }
        let placement = fields[0].split(separator: "[", maxSplits: 1).first.map(String.init) ?? fields[0]
        let ranks = placement.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        // Seul l'échiquier 8 × 8 a des coins connus ; ailleurs on ne touche à rien.
        guard ranks.count == 8, let whiteBack = expand(ranks[7]), let blackBack = expand(ranks[0]),
              whiteBack.count == 8, blackBack.count == 8
        else { return fen }

        var kept = ""
        for right in fields[2] {
            switch right {
            case "K": if hasRook(whiteBack, king: "K", rook: "R", kingside: true) { kept.append(right) }
            case "Q": if hasRook(whiteBack, king: "K", rook: "R", kingside: false) { kept.append(right) }
            case "k": if hasRook(blackBack, king: "k", rook: "r", kingside: true) { kept.append(right) }
            case "q": if hasRook(blackBack, king: "k", rook: "r", kingside: false) { kept.append(right) }
            default: kept.append(right)   // « - » ou une lettre de colonne (Shredder-FEN)
            }
        }
        // « - » ne reste que si plus aucun droit : on ne mélange pas « - » et des lettres.
        let letters = kept.filter { $0 != "-" }
        fields[2] = letters.isEmpty ? "-" : String(letters)
        return fields.joined(separator: " ")
    }

    /// Une rangée de FEN dépliée en huit cases (« . » = vide) ; `nil` si elle ne fait pas huit cases.
    private static func expand(_ rank: String) -> [Character]? {
        var squares: [Character] = []
        for character in rank {
            if let digit = character.wholeNumberValue, (1...8).contains(digit) {
                squares.append(contentsOf: Array(repeating: ".", count: digit))
            } else {
                squares.append(character)
            }
        }
        return squares.count == 8 ? squares : nil
    }

    private static func hasRook(_ back: [Character], king: Character, rook: Character, kingside: Bool) -> Bool {
        guard let kingFile = back.firstIndex(of: king) else { return false }
        let range = kingside ? (kingFile + 1)..<8 : 0..<kingFile
        return range.contains { back[$0] == rook }
    }
}
