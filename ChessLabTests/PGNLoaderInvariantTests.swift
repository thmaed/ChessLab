import Foundation
import Testing

/// L'invariant né du bug « Aucun coup joué » (17/08) : dans le code de l'app,
/// SEUL ``PGNLoader`` a le droit d'appeler `Game(pgn:)`.
///
/// Le parseur de ChessKit refuse des parties légales (prise en passant, roque
/// avec échec). La bibliothèque importait via `PGNLoader` (blindé) mais
/// l'analyse relisait via `Game(pgn:)` brut : le MÊME texte passait l'import
/// puis s'ouvrait sur un plateau vide. Deux portes d'entrée, deux niveaux de
/// robustesse — ce test interdit la porte faible, définitivement.
///
/// Même procédé que ``PositionedGestureOrderTests`` : le défaut est invisible
/// tant qu'on ne teste pas avec la bonne partie, donc on verrouille l'USAGE
/// dans la source, pas un exemple.
struct PGNLoaderInvariantTests {

    @Test func onlyPGNLoaderParsesRawPGN() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // ChessLabTests/
            .deletingLastPathComponent()  // racine du dépôt
            .appendingPathComponent("ChessLab")
        let enumerator = try #require(FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil
        ))

        var offenders: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let name = url.lastPathComponent
            if name == "PGNLoader.swift" { continue }
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            // Recherche l'APPEL (`Game(pgn:` suivi d'une valeur), pas les
            // mentions en commentaire qui expliquent pourquoi on l'évite.
            for line in text.split(separator: "\n")
            where line.contains("Game(pgn:") && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
                && !line.trimmingCharacters(in: .whitespaces).hasPrefix("///") {
                offenders.append("\(name) : \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        let message = "Game(pgn:) brut hors PGNLoader — passer par PGNLoader.game(from:) :\n"
            + offenders.joined(separator: "\n")
        #expect(offenders.isEmpty, Comment(rawValue: message))
    }
}
