import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Reconnaissance des doublons à l'import de bibliothèque.
///
/// Le test qui porte les autres est `sameGameFromTwoSourcesIsOneGame` : c'est
/// le cas réel — le même PGN exporté par deux sites diffère par ses balises,
/// ses commentaires et ses espaces. Une comparaison de texte brut ne
/// reconnaîtrait rien, et l'utilisateur se retrouverait avec sa bibliothèque
/// en double.
///
/// À l'inverse, `differentPlayersSameMovesAreTwoGames` protège contre l'excès :
/// écarter une partie DIFFÉRENTE est bien pire que laisser passer un doublon,
/// puisque l'utilisateur la perd sans le savoir.
@MainActor
struct LibraryDuplicateTests {

    private let scholars = """
    [Event "Test"]
    [White "Alice"]
    [Black "Bob"]
    [Result "1-0"]

    1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0
    """

    @Test func movetextStripsEverythingButTheMoves() {
        let moves = GameLibraryService.movetext(of: scholars)
        #expect(moves == "e4 e5 Bc4 Nc6 Qh5 Nf6 Qxf7#")
    }

    @Test func commentsAndVariationsAreIgnored() {
        let annotated = """
        [White "Alice"]
        [Black "Bob"]

        1. e4 {une bonne case} e5 2. Bc4 (2. Nf3 Nc6) 2... Nc6 3. Qh5!? Nf6?? 4. Qxf7# 1-0
        """
        #expect(GameLibraryService.movetext(of: annotated) == GameLibraryService.movetext(of: scholars))
    }

    /// LE cas réel : mêmes coups, mêmes joueurs, présentation différente.
    @Test func sameGameFromTwoSourcesIsOneGame() throws {
        let other = """
        [Event "Autre tournoi"]
        [Site "Ailleurs"]
        [Date "2024.01.01"]
        [White "alice"]
        [Black "BOB"]
        [Result "1-0"]
        [ECO "C20"]

        1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6 4.Qxf7# 1-0
        """
        let a = try #require(GameLibraryService.signature(ofPGN: scholars))
        let b = try #require(GameLibraryService.signature(ofPGN: other))
        #expect(a == b)
    }

    /// Le garde-fou inverse : deux parties qui partagent leurs coups mais pas
    /// leurs joueurs restent deux parties.
    @Test func differentPlayersSameMovesAreTwoGames() throws {
        let other = scholars
            .replacingOccurrences(of: "Alice", with: "Carole")
            .replacingOccurrences(of: "Bob", with: "David")
        let a = try #require(GameLibraryService.signature(ofPGN: scholars))
        let b = try #require(GameLibraryService.signature(ofPGN: other))
        #expect(a != b)
    }

    @Test func unreadablePGNHasNoSignature() {
        #expect(GameLibraryService.signature(ofPGN: "ceci n'est pas un PGN") == nil)
        #expect(GameLibraryService.signature(ofPGN: "") == nil)
    }

    /// Un fichier qui contient DEUX fois la même partie n'en range qu'une :
    /// le dédoublonnage vaut à l'intérieur d'un même lot, pas seulement
    /// contre ce qui est déjà en bibliothèque.
    @Test func duplicatesInsideOneFileAreCollapsed() throws {
        let container = try ModelContainer(
            for: GameRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let outcome = GameLibraryService.importPGNCollection(
            text: scholars + "\n\n" + scholars, in: context
        )
        #expect(outcome.imported == 1)
        #expect(outcome.duplicates == 1)

        // Et un second import du même fichier n'ajoute rien.
        let again = GameLibraryService.importPGNCollection(text: scholars, in: context)
        #expect(again.imported == 0)
        #expect(again.duplicates == 1)

        let stored = try context.fetch(FetchDescriptor<GameRecord>())
        #expect(stored.count == 1)
    }

    @Test func deleteRemovesTheGame() throws {
        let container = try ModelContainer(
            for: GameRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        GameLibraryService.importPGNCollection(text: scholars, in: context)

        let stored = try context.fetch(FetchDescriptor<GameRecord>())
        let record = try #require(stored.first)
        GameLibraryService.delete(record, in: context)

        #expect(try context.fetch(FetchDescriptor<GameRecord>()).isEmpty)
    }
}
