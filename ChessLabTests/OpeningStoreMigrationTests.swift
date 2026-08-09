import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Scénario « MISE À JOUR depuis la version publiée » (pas seulement
/// l'installation neuve) : un store « Games » créé avec l'ANCIEN schéma
/// (parties + progression puzzle) est rouvert avec le NOUVEAU schéma qui ajoute
/// les trois modèles d'ouvertures. L'ajout étant purement additif (nouveaux
/// types, toutes propriétés optionnelles/à défaut, aucune contrainte, aucune
/// relation), la migration légère de SwiftData doit préserver les données
/// existantes — exactement le mécanisme qui a déjà porté l'ajout de
/// ``PuzzleProgress`` au même store.
///
/// - important: suite `.serialized` et store sur DISQUE dans un dossier
///   temporaire propre (la migration exige une réouverture, impossible en
///   mémoire), nettoyé en fin de test.
@MainActor
@Suite(.serialized)
struct OpeningStoreMigrationTests {

    @Test func additiveMigrationPreservesExistingGamesStore() throws {
        let url = URL.temporaryDirectory.appending(path: "GamesMigration-\(UUID().uuidString).store")
        defer { removeStoreFiles(at: url) }

        // 1) ANCIEN schéma : on écrit une partie et une progression puzzle.
        do {
            let container = try ModelContainer(
                for: GameRecord.self, PuzzleProgress.self,
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(container)
            let game = GameRecord()
            game.pgn = "1. e4 e5 2. Nf3"
            context.insert(game)
            let progress = PuzzleProgress(externalID: "abc12")
            progress.successCount = 3
            context.insert(progress)
            try context.save()
        }

        // 2) NOUVEAU schéma sur le MÊME fichier (les 3 modèles d'ouvertures en plus).
        let container = try ModelContainer(
            for: GameRecord.self, PuzzleProgress.self,
            OpeningPositionProgress.self, OpeningReviewLog.self, RepertoireMembership.self,
            configurations: ModelConfiguration(url: url)
        )
        let context = ModelContext(container)

        // Les données existantes ont survécu.
        let games = try context.fetch(FetchDescriptor<GameRecord>())
        #expect(games.count == 1)
        #expect(games.first?.pgn == "1. e4 e5 2. Nf3")
        #expect(try context.fetchCount(FetchDescriptor<PuzzleProgress>()) == 1)

        // Les nouveaux modèles sont utilisables dans le store migré.
        context.insert(OpeningPositionProgress(fenKey: OpeningFENKey.key(for: .standard)))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<OpeningPositionProgress>()) == 1)
    }

    private func removeStoreFiles(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            try? fm.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}
