/// Verbalise un coup à partir de son SAN, en français, pour les annonces
/// VoiceOver (« Stockfish : cavalier en f3, échec »). Un utilisateur
/// VoiceOver ne voit pas le plateau bouger : sans annonce, il ne sait pas
/// ce que l'adversaire vient de jouer. Voir instructions.md §F2.
enum MoveNarration {
    private static let pieceNames: [Character: String] = [
        "N": "cavalier", "B": "fou", "R": "tour", "Q": "dame", "K": "roi"
    ]

    static func describe(san: String) -> String {
        if san.hasPrefix("O-O-O") { return decorate("grand roque", san: san) }
        if san.hasPrefix("O-O") { return decorate("petit roque", san: san) }

        let chars = Array(san)
        var phrase: String
        var index = 0
        if let name = pieceNames[chars.first ?? " "] {
            phrase = name
            index = 1
        } else {
            phrase = "pion"
        }

        let rest = String(chars[index...])
        let isCapture = rest.contains("x")
        // Destination = les deux caractères juste avant un éventuel =, + ou #.
        let core = rest.prefix { $0 != "=" && $0 != "+" && $0 != "#" }
        let destination = spell(String(core.suffix(2)))

        var sentence = isCapture ? "\(phrase) prend en \(destination)" : "\(phrase) en \(destination)"

        if let equal = san.firstIndex(of: "="), san.index(after: equal) < san.endIndex,
           let promoted = pieceNames[san[san.index(after: equal)]] {
            sentence += ", promotion en \(promoted)"
        }

        return decorate(sentence, san: san)
    }

    private static func decorate(_ base: String, san: String) -> String {
        if san.hasSuffix("#") { return base + ", échec et mat" }
        if san.hasSuffix("+") { return base + ", échec" }
        return base
    }

    /// Épelle une case ("e4" → "e 4") pour une lecture non ambiguë.
    private static func spell(_ square: String) -> String {
        square.map(String.init).joined(separator: " ")
    }
}
