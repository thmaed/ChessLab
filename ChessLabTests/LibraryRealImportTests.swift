import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Import d'un VRAI fichier multi-parties, celui du testeur.
///
/// Neuf parties de tournoi réelles, avec ce que cela implique et qu'un
/// fixture écrit à la main n'aurait pas : des parties inachevées (résultat
/// `*`), une partie de 107 coups, des sauts de ligne au milieu du texte de
/// coups, des noms accentués, et deux parties jouées le MÊME JOUR par le même
/// joueur.
///
/// L'utilisateur signale que l'import ne fonctionne pas et soupçonne un effet
/// de bord du dédoublonnage. Ce test tranche : soit les neuf parties entrent,
/// soit il montre exactement où ça casse.
@MainActor
struct LibraryRealImportTests {

    /// Le fichier tel qu'il est fourni — non retouché.
    private var pgn: String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures_nils.pgn")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: GameRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func theFixtureIsReadable() {
        #expect(!pgn.isEmpty, "le fichier de test doit être présent dans la cible")
    }

    /// Étape 1 : le découpage. S'il rend autre chose que 9 blocs, le problème
    /// est là et pas ailleurs.
    @Test func splitterFindsAllNineGames() {
        let blocks = PGNSanitizer.splitIntoGames(pgn)
        #expect(blocks.count == 9, "9 blocs attendus, \(blocks.count) obtenus")
    }

    /// Étape 2 : chaque bloc doit être DÉCODABLE par ``PGNLoader`` — et non
    /// par `Game(pgn:)`, qui refuse des parties légales (prise en passant,
    /// roque avec échec). C'est ici que se joue le sort de l'import : un bloc
    /// illisible est compté « skipped » et disparaît sans bruit.
    @Test func everyBlockParses() {
        let blocks = PGNSanitizer.splitIntoGames(pgn)
        var failures: [String] = []
        for block in blocks {
            let candidate = PGNSanitizer.sanitize(block)
            if PGNLoader.game(from: candidate) == nil {
                let header = candidate.split(separator: "\n").first(where: { $0.hasPrefix("[White") })
                failures.append(String(header ?? "bloc sans en-tête"))
            }
        }
        #expect(failures.isEmpty, "blocs illisibles : \(failures.joined(separator: " | "))")
    }

    /// Étape 3 : l'import complet. Les neuf parties doivent entrer, aucune
    /// n'être prise pour un doublon.
    @Test func allNineGamesAreImported() throws {
        let context = try makeContext()
        let outcome = GameLibraryService.importPGNCollection(text: pgn, in: context)

        #expect(outcome.imported == 9, "importées : \(outcome.imported)")
        #expect(outcome.skipped == 0, "illisibles : \(outcome.skipped)")
        #expect(outcome.duplicates == 0, "prises pour doublons : \(outcome.duplicates)")
        #expect(try context.fetch(FetchDescriptor<GameRecord>()).count == 9)
    }

    /// Le dédoublonnage ne doit pas confondre deux parties DIFFÉRENTES du même
    /// joueur, jouées le même jour dans le même tournoi — le fichier en
    /// contient précisément deux (Prangins, 15/11/2025).
    @Test func twoGamesSameDayAreNotConfused() throws {
        let context = try makeContext()
        _ = GameLibraryService.importPGNCollection(text: pgn, in: context)
        let stored = try context.fetch(FetchDescriptor<GameRecord>())
        let prangins = stored.filter { $0.whiteName?.contains("Gauthey") == true }
        #expect(prangins.count >= 3, "les parties de Gauthey avec les Blancs doivent toutes être là")
    }

    /// Et le second import du même fichier n'ajoute rien : c'est le
    /// comportement demandé, il doit valoir sur un fichier réel.
    @Test func reimportingTheSameFileAddsNothing() throws {
        let context = try makeContext()
        _ = GameLibraryService.importPGNCollection(text: pgn, in: context)
        let again = GameLibraryService.importPGNCollection(text: pgn, in: context)

        #expect(again.imported == 0)
        #expect(again.duplicates == 9)
        #expect(try context.fetch(FetchDescriptor<GameRecord>()).count == 9)
    }
}
