import Foundation
import SwiftData

/// La copie iCloud d'une collection de puzzles importée : UN enregistrement par
/// collection, qui contient son fichier PGN (celui de ``PuzzleCollectionExporter``)
/// compressé. Il vit dans le store « Games », synchronisé, parce que le store
/// « Puzzles » — où sont les puzzles eux-mêmes — ne l'est jamais (voir
/// ``PuzzleCollectionStore``).
///
/// Pas de relation, pas de contrainte d'unicité, tout est valué par défaut :
/// les règles d'un modèle CloudKit.
///
/// - important: Un nouveau type d'enregistrement. Avant une version publiée, le
///   schéma CloudKit doit être DÉPLOYÉ en production (console CloudKit), sinon
///   les collections ne voyageront pas.
@Model
final class SyncedPuzzleCollection {
    var id: UUID = UUID()
    var name: String = ""
    var puzzleCount: Int = 0
    var updatedAt: Date = Date()
    /// Le PGN compressé. Stocké hors de la ligne : une grande collection dépasse
    /// vite la limite d'un champ ordinaire, CloudKit le transporte alors comme un fichier.
    @Attribute(.externalStorage) var pgnData: Data?

    init() {}
}

/// Garde les collections importées d'un appareil à l'autre, et les rend après un
/// store « Puzzles » détruit. Pas de pendant Android : l'iCloud est hors périmètre
/// (voir CLAUDE.md), l'export PGN en fait office.
///
/// ## Ce qui voyage, et ce qui ne voyage pas
///
/// - **Voyage** : la collection (ses puzzles) et son nom.
/// - **Ne voyage pas** : la progression sur ces puzzles (réussites, échéances) ni
///   la suppression. Supprimer une collection retire sa copie iCloud ; les autres
///   appareils gardent la leur, sans la perdre — ils ne l'effacent jamais d'eux-mêmes.
///
/// ## Comment un appareil s'y retrouve
///
/// Chaque appareil retient, dans ses réglages, quel enregistrement correspond à
/// quelle collection LOCALE (par l'identifiant de l'enregistrement) : c'est ce
/// qui fait suivre un renommage fait ailleurs au lieu de dédoubler la collection.
/// Il retient aussi la date de ce qu'il a déjà rendu, pour ne relire un PGN que
/// s'il a changé. Une collection mappée mais absente en local (store détruit) est
/// rendue même si rien n'a changé.
@MainActor
enum PuzzleCollectionSync {
    private static let namesKey = "puzzleCollectionSync.names"
    private static let stampsKey = "puzzleCollectionSync.stamps"
    private static let backfilledKey = "puzzleCollectionSync.backfilled"
    private static var isRunning = false

    /// À appeler à l'ouverture des écrans : rend ce qui est arrivé d'iCloud, puis,
    /// UNE fois par appareil, envoie les collections déjà présentes. Sans effet
    /// quand rien n'a changé.
    static func sync(in context: ModelContext, defaults: UserDefaults = .standard) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        await restore(in: context, defaults: defaults)
        backfillIfNeeded(in: context, defaults: defaults)
    }

    // MARK: Envoyer

    /// Écrit (ou réécrit) la copie de la collection `name` : à appeler après un import.
    static func backup(_ name: String, in context: ModelContext, defaults: UserDefaults = .standard) {
        let puzzles = PuzzleCollectionStore.puzzles(inCollection: name, in: context)
        guard !puzzles.isEmpty else { return }
        let pgn = PuzzleCollectionExporter.pgn(
            collection: name, entries: puzzles.map(PuzzleCollectionExporter.Entry.init)
        )
        guard let data = pack(pgn) else { return }

        var names = readNames(defaults)
        var stamps = readStamps(defaults)
        let all = records(in: context)
        var targets = all.filter { names[$0.id.uuidString] == name }
        // Une copie du même nom que cet appareil n'a pas encore reconnue : la reprendre
        // plutôt que d'en créer une seconde.
        if targets.isEmpty, let same = all.first(where: { $0.name == name && names[$0.id.uuidString] == nil }) {
            targets = [same]
        }
        if targets.isEmpty {
            let record = SyncedPuzzleCollection()
            context.insert(record)
            targets = [record]
        }
        let now = Date()
        for record in targets {
            record.name = name
            record.pgnData = data
            record.puzzleCount = puzzles.count
            record.updatedAt = now
            names[record.id.uuidString] = name
            stamps[record.id.uuidString] = now.timeIntervalSince1970
        }
        PersistenceLog.save(context)
        writeNames(names, defaults)
        writeStamps(stamps, defaults)
    }

    /// La collection vient d'être renommée en local : sa copie suit.
    static func renamed(from old: String, to new: String, in context: ModelContext, defaults: UserDefaults = .standard) {
        var names = readNames(defaults)
        var stamps = readStamps(defaults)
        let targets = records(in: context).filter { names[$0.id.uuidString] == old }
        guard !targets.isEmpty else {
            backup(new, in: context, defaults: defaults)
            return
        }
        let now = Date()
        for record in targets {
            record.name = new
            record.updatedAt = now
            names[record.id.uuidString] = new
            stamps[record.id.uuidString] = now.timeIntervalSince1970
        }
        PersistenceLog.save(context)
        writeNames(names, defaults)
        writeStamps(stamps, defaults)
    }

    /// La collection vient d'être supprimée en local : sa copie l'est aussi.
    static func deleted(_ name: String, in context: ModelContext, defaults: UserDefaults = .standard) {
        var names = readNames(defaults)
        var stamps = readStamps(defaults)
        for record in records(in: context) where names[record.id.uuidString] == name {
            names[record.id.uuidString] = nil
            stamps[record.id.uuidString] = nil
            context.delete(record)
        }
        PersistenceLog.save(context)
        writeNames(names, defaults)
        writeStamps(stamps, defaults)
    }

    /// Les collections présentes avant cette fonction n'ont pas de copie : on les
    /// envoie, une seule fois par appareil. Une suppression faite ailleurs depuis
    /// ne les ressuscite donc pas.
    static func backfillIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: backfilledKey) else { return }
        defaults.set(true, forKey: backfilledKey)
        let names = readNames(defaults)
        let mapped = Set(records(in: context).compactMap { names[$0.id.uuidString] })
        for name in PuzzleCollectionStore.names(in: context) where !mapped.contains(name) {
            backup(name, in: context, defaults: defaults)
        }
    }

    // MARK: Rendre

    /// Verse dans le store local ce que les copies contiennent : une collection
    /// absente est recréée, une collection présente reçoit les puzzles qui lui manquent
    /// (jamais deux fois le même), un renommage fait ailleurs est suivi.
    static func restore(in context: ModelContext, defaults: UserDefaults = .standard) async {
        let all = records(in: context).sorted { $0.updatedAt < $1.updatedAt }
        guard !all.isEmpty else { return }
        var names = readNames(defaults)
        var stamps = readStamps(defaults)
        var present = PuzzleCollectionStore.names(in: context)

        for record in all {
            guard let data = record.pgnData, let text = unpack(data) else { continue }
            let key = record.id.uuidString

            var target = record.name
            if let old = names[key], old != record.name, present.contains(old) {
                if !present.contains(record.name),
                   PuzzleCollectionStore.rename(old, to: record.name, in: context) {
                    present.remove(old)
                    present.insert(record.name)
                } else {
                    target = old
                }
            }
            let changed = record.updatedAt.timeIntervalSince1970 - (stamps[key] ?? 0) > 1
            guard changed || !present.contains(target) else {
                names[key] = target
                continue
            }

            let parsed = await Task.detached(priority: .utility) {
                PuzzleCollectionImporter.parse(text)
            }.value
            PuzzleCollectionStore.add(parsed, toCollection: target, in: context)
            present.insert(target)
            names[key] = target
            stamps[key] = record.updatedAt.timeIntervalSince1970
        }
        writeNames(names, defaults)
        writeStamps(stamps, defaults)
    }

    // MARK: Le PGN compressé

    /// Un octet nul, puis le PGN en UTF-8 compressé (zlib) : le même format que le
    /// plan Woodpecker (``WoodpeckerPlan``), et pour la même raison — un PGN de
    /// mille puzzles se réduit à une trentaine de Ko.
    static func pack(_ pgn: String) -> Data? {
        guard let packed = try? (Data(pgn.utf8) as NSData).compressed(using: .zlib) else { return nil }
        return Data([0]) + (packed as Data)
    }

    static func unpack(_ data: Data) -> String? {
        guard data.first == 0,
              let raw = try? (data.dropFirst() as NSData).decompressed(using: .zlib)
        else { return nil }
        return String(data: raw as Data, encoding: .utf8)
    }

    // MARK: Réglages de l'appareil

    private static func records(in context: ModelContext) -> [SyncedPuzzleCollection] {
        (try? context.fetch(FetchDescriptor<SyncedPuzzleCollection>())) ?? []
    }

    private static func readNames(_ defaults: UserDefaults) -> [String: String] {
        defaults.dictionary(forKey: namesKey) as? [String: String] ?? [:]
    }

    private static func writeNames(_ names: [String: String], _ defaults: UserDefaults) {
        defaults.set(names, forKey: namesKey)
    }

    private static func readStamps(_ defaults: UserDefaults) -> [String: Double] {
        defaults.dictionary(forKey: stampsKey) as? [String: Double] ?? [:]
    }

    private static func writeStamps(_ stamps: [String: Double], _ defaults: UserDefaults) {
        defaults.set(stamps, forKey: stampsKey)
    }
}
