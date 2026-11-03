import Foundation
import SwiftData

/// Les collections de puzzles importées (``PuzzleSource/imported``) : les créer
/// depuis un fichier lu, les lister, les renommer, les supprimer. Pendant :
/// `PuzzleCollectionStore.kt`.
///
/// Une collection n'a pas d'enregistrement à elle — c'est l'ensemble des
/// ``Puzzle`` qui portent son nom dans ``Puzzle/collection``. Rien à garder en
/// accord : renommer réécrit ce champ, supprimer retire les puzzles.
///
/// ## Où ils vivent
///
/// Dans le store local « Puzzles », avec les puzzles de vos parties : jamais
/// synchronisés. Ce store est détruit si SwiftData le déclare corrompu (voir
/// ``LocalStoreMaintenance``) : le fichier d'origine reste la sauvegarde, et
/// réimporter un fichier déjà importé n'ajoute que ce qui manque.
///
/// Ces puzzles n'ont volontairement PAS d'`externalID` : c'est lui qui les
/// ferait refléter vers le store synchronisé (``PuzzleProgressSync``).
@MainActor
enum PuzzleCollectionStore {
    struct Summary: Identifiable, Equatable {
        var name: String
        var count: Int
        /// Ceux dont la DERNIÈRE tentative est ratée (voir ``PuzzleSessionFilter/missedOnly``).
        var missedCount: Int
        var id: String { name }
    }

    struct ImportReport: Equatable {
        var collection: String
        var added: Int
        /// Déjà dans la collection (même position) : un fichier réimporté.
        var alreadyThere: Int
        var parsed: PuzzleCollectionImporter.Result
    }

    // MARK: Importer

    /// Verse les puzzles lus dans la collection `name` (créée au besoin). Une
    /// position déjà présente n'est pas ajoutée deux fois : réimporter la
    /// version à jour d'un fichier complète la collection sans rien dédoubler.
    @discardableResult
    static func add(
        _ parsed: PuzzleCollectionImporter.Result, toCollection name: String, in context: ModelContext
    ) -> ImportReport {
        let name = normalized(name)
        var known = Set(puzzles(inCollection: name, in: context).compactMap(\.fen))
        var added = 0
        var already = 0
        let now = Date()
        for item in parsed.puzzles {
            guard known.insert(item.fen).inserted else {
                already += 1
                continue
            }
            let puzzle = Puzzle()
            puzzle.fen = item.fen
            puzzle.solutionLANs = item.solutionLANs
            puzzle.themeRaw = item.themeRaw
            puzzle.phaseRaw = item.phaseRaw
            puzzle.sourceRaw = PuzzleSource.imported.rawValue
            puzzle.collection = name
            // L'ordre du fichier : `createdAt` croît d'une milliseconde par puzzle.
            puzzle.createdAt = now.addingTimeInterval(Double(added) / 1000)
            context.insert(puzzle)
            added += 1
        }
        if added > 0 { PersistenceLog.save(context) }
        return ImportReport(collection: name, added: added, alreadyThere: already, parsed: parsed)
    }

    /// Le nom proposé pour un fichier : son nom sans l'extension.
    static func suggestedName(fromFile url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        let name = normalized(base)
        return name.isEmpty ? LocalizationController.string("Collection importée") : name
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Lire

    /// Les collections, par ordre alphabétique.
    static func collections(in context: ModelContext) -> [Summary] {
        let importedRaw = PuzzleSource.imported.rawValue
        var descriptor = FetchDescriptor<Puzzle>(predicate: #Predicate { ($0.sourceRaw ?? "") == importedRaw })
        // Le nom suffit pour compter ; les FEN et les solutions restent en base.
        descriptor.propertiesToFetch = [\.collection]
        let names = ((try? context.fetch(descriptor)) ?? []).compactMap(\.collection)
        let counts = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { name in
            Summary(
                name: name, count: counts[name] ?? 0,
                missedCount: PuzzleSessionDrawer.count(
                    matching: PuzzleSessionFilter(collection: name, missedOnly: true), in: context
                )
            )
        }
    }

    /// Tous les puzzles d'une collection, dans l'ordre du fichier.
    static func puzzles(inCollection name: String, in context: ModelContext) -> [Puzzle] {
        let target: String? = name
        let descriptor = FetchDescriptor<Puzzle>(
            predicate: #Predicate { $0.collection == target },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: Modifier

    /// `false` si le nouveau nom est vide ou déjà pris par une AUTRE collection
    /// (les fusionner en silence mélangerait deux fichiers).
    @discardableResult
    static func rename(_ old: String, to new: String, in context: ModelContext) -> Bool {
        let new = normalized(new)
        guard !new.isEmpty else { return false }
        if new == old { return true }
        guard !collections(in: context).contains(where: { $0.name == new }) else { return false }
        for puzzle in puzzles(inCollection: old, in: context) { puzzle.collection = new }
        PersistenceLog.save(context)
        return true
    }

    static func delete(_ name: String, in context: ModelContext) {
        for puzzle in puzzles(inCollection: name, in: context) { context.delete(puzzle) }
        PersistenceLog.save(context)
    }
}
