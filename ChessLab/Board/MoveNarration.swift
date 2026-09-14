/// Verbalise un coup à partir de son SAN, pour les annonces VoiceOver
/// (« Stockfish : cavalier en f 3, échec »). Un utilisateur VoiceOver ne voit
/// pas le plateau bouger : sans annonce, il ne sait pas ce que l'adversaire
/// vient de jouer. Voir instructions.md §F2.
///
/// Tout passe par ``LocalizationController/string(_:)`` : ces phrases étaient
/// écrites en français DUR, et un utilisateur anglophone se faisait donc
/// annoncer « cavalier en f 3 » par une voix anglaise. Le portage Android l'a
/// révélé — les deux apps disent désormais la même chose dans les deux
/// langues (`MoveNarration.kt`).
enum MoveNarration {
    private static func pieceName(_ letter: Character) -> String? {
        switch letter {
        case "N": LocalizationController.string("cavalier")
        case "B": LocalizationController.string("fou")
        case "R": LocalizationController.string("tour")
        case "Q": LocalizationController.string("dame")
        case "K": LocalizationController.string("roi")
        default: nil
        }
    }

    static func describe(san: String) -> String {
        if san.hasPrefix("O-O-O") { return decorate(LocalizationController.string("grand roque"), san: san) }
        if san.hasPrefix("O-O") { return decorate(LocalizationController.string("petit roque"), san: san) }

        let chars = Array(san)
        var phrase: String
        var index = 0
        if let name = pieceName(chars.first ?? " ") {
            phrase = name
            index = 1
        } else {
            phrase = LocalizationController.string("pion")
        }

        let rest = String(chars[index...])
        let isCapture = rest.contains("x")
        // Destination = les deux caractères juste avant un éventuel =, + ou #.
        let core = rest.prefix { $0 != "=" && $0 != "+" && $0 != "#" }
        let destination = spell(String(core.suffix(2)))

        var sentence = isCapture
            ? LocalizationController.string("%@ prend en %@", phrase, destination)
            : LocalizationController.string("%@ en %@", phrase, destination)

        if let equal = san.firstIndex(of: "="), san.index(after: equal) < san.endIndex,
           let promoted = pieceName(san[san.index(after: equal)]) {
            sentence = LocalizationController.string("%@, promotion en %@", sentence, promoted)
        }

        return decorate(sentence, san: san)
    }

    private static func decorate(_ base: String, san: String) -> String {
        if san.hasSuffix("#") { return LocalizationController.string("%@, échec et mat", base) }
        if san.hasSuffix("+") { return LocalizationController.string("%@, échec", base) }
        return base
    }

    /// Épelle une case ("e4" → "e 4") pour une lecture non ambiguë.
    private static func spell(_ square: String) -> String {
        square.map(String.init).joined(separator: " ")
    }
}
