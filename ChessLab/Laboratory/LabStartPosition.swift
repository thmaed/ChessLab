import ChessKit
import Foundation

/// Résout une position de départ de série Laboratoire à partir d'un texte qui
/// peut être un **FEN** OU un **PGN**. Un PGN est ramené à la FEN de sa
/// position FINALE (ligne principale) — pour lancer une série depuis la fin
/// d'une ouverture collée/importée.
enum LabStartPosition {

    /// - Returns: la FEN de départ, le nombre de demi-coups joués pour
    ///   l'atteindre (`0` pour un FEN direct), et si la source était un PGN.
    ///   `nil` si le texte n'est ni un FEN légal ni un PGN lisible.
    static func resolve(_ text: String) -> (fen: String, plies: Int, fromPGN: Bool)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Un FEN légal l'emporte : on le prend tel quel.
        if FENValidator.isLegal(trimmed) {
            return (trimmed, 0, false)
        }

        // Sinon, on tente le PGN (première partie d'un éventuel multi-parties),
        // et on remonte sa position finale.
        let candidate = PGNSanitizer.sanitize(PGNSanitizer.splitIntoGames(trimmed).first ?? trimmed)
        // PGNLoader : même robustesse que la bibliothèque et l'analyse — un
        // PGN avec prise en passant doit pouvoir donner sa position finale.
        guard !candidate.isEmpty, let game = PGNLoader.game(from: candidate) else { return nil }

        var index = game.startingIndex
        var plies = 0
        while game.moves.hasIndex(after: index) {
            index = game.moves.index(after: index)
            plies += 1
        }
        guard let fen = game.positions[index]?.fen else { return nil }
        return (fen, plies, true)
    }
}
