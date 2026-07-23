import ChessKit
import Testing
@testable import ChessLab

struct OpeningLibraryTests {

    @Test func bundledLibraryIsNotEmpty() {
        #expect(OpeningLibraryLoader.standard.count > 100)
    }

    @Test func everyEntryHasUniqueFamilyAndValidCategory() {
        let entries = OpeningLibraryLoader.standard
        let families = Set(entries.map(\.family))
        #expect(families.count == entries.count)
        for entry in entries {
            #expect(["A", "B", "C", "D", "E"].contains(entry.category))
        }
    }

    /// Le point le plus fragile de la génération hors app (une ligne par
    /// famille extraite du jeu de données ECO `lichess-org/chess-openings`) :
    /// chaque PGN produit doit rester lisible par le VRAI parseur PGN de
    /// l'app. Volontairement une ligne UNIQUE sans variantes imbriquées —
    /// le parseur de variantes (RAV) de ChessKit s'est révélé produire des
    /// `.invalidMove` incorrects dès qu'un point de branchement a 2+
    /// alternatives dont l'une contient elle-même une sous-variation
    /// (bug confirmé par isolation manuelle, indépendant de la légalité
    /// des coups — voir git blame pour les cas de reproduction). Une
    /// ligne unique par famille est la structure la plus riche que ce
    /// parseur gère de façon fiable.
    @Test func everyEntryPGNParsesWithChessKit() throws {
        for entry in OpeningLibraryLoader.standard {
            do {
                let game = try Game(pgn: entry.pgn)
                #expect(!game.moves.indices.isEmpty, "PGN vide pour \(entry.family)")
            } catch {
                Issue.record("\(entry.family): \(error) — pgn: \(entry.pgn.prefix(200))")
            }
        }
    }
}
