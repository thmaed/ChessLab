import Foundation

/// Prétraitement de PGN partagé par TOUS les points d'import (coller,
/// fichier, étude Lichess). `ChessKit.PGNParser` rejette deux cas très
/// courants dans les exports réels (Lichess, chess.com) : plusieurs lignes
/// vides (`.tooManyLineBreaks`) et un commentaire avant le 1er coup. Un
/// fichier `.pgn` peut aussi contenir PLUSIEURS parties (le cas normal
/// d'une base). Ces fonctions étaient à l'origine internes au service
/// Lichess ; centralisées ici, elles protègent aussi « Coller un PGN » et
/// « Importer un fichier ». Voir instructions.md §A5.
enum PGNSanitizer {
    /// Nettoyage complet d'une partie unique : aplatit les lignes vides
    /// surnuméraires puis retire un éventuel commentaire d'introduction.
    static func sanitize(_ pgn: String) -> String {
        stripLeadingComment(collapseExtraBlankLines(pgn))
    }

    /// Retire un commentaire `{ … }` placé AVANT le premier coup — pourtant
    /// courant, il fait échouer le parsing (`.unexpectedMoveTextToken`).
    static func stripLeadingComment(_ pgn: String) -> String {
        guard let separatorRange = pgn.range(of: "\n\n") else { return pgn }
        let tagsSection = pgn[pgn.startIndex..<separatorRange.lowerBound]
        var movetext = String(pgn[separatorRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

        while movetext.hasPrefix("{"), let closingRange = movetext.range(of: "}") {
            movetext = String(movetext[closingRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return tagsSection + "\n\n" + movetext
    }

    /// N'autorise qu'UNE ligne vide (le séparateur tags/coups) : au-delà,
    /// `PGNParser` lève `.tooManyLineBreaks`.
    static func collapseExtraBlankLines(_ pgn: String) -> String {
        var seenSeparator = false
        var result: [String] = []
        // Les lignes vides de TÊTE (copie d'écran, fichier avec BOM/entête)
        // sont retirées d'abord : sans cela, la première d'entre elles
        // consommait l'unique séparateur conservé, la vraie ligne vide entre
        // tags et coups était supprimée, et le PGN — valide à l'œil — était
        // rejeté (« Ce PGN n'a pas pu être lu ») malgré l'assainisseur.
        let lines = pgn.components(separatedBy: "\n")
            .drop { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        for line in lines {
            let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
            if isBlank {
                guard !seenSeparator else { continue }
                seenSeparator = true
            }
            result.append(line)
        }
        return result.joined(separator: "\n")
    }

    /// Découpe un texte multi-parties : chaque nouvelle partie recommence
    /// par une paire de crochets `[Event …]`.
    static func splitIntoGames(_ pgnText: String) -> [String] {
        let lines = pgnText.components(separatedBy: "\n")
        var games: [String] = []
        var current: [String] = []
        for line in lines {
            if line.hasPrefix("[Event ") && !current.isEmpty {
                games.append(current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
                current = []
            }
            current.append(line)
        }
        let last = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { games.append(last) }
        return games
    }
}
