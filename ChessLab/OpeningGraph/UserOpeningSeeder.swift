import Foundation

/// Dépose un répertoire PERSONNEL de test, pour vérifier les écrans qui n'en
/// montrent que dans ce cas — le menu d'actions et l'éditeur d'arbre.
///
/// Activé par `-seedUserOpening`, même convention que ``LayoutTraitsProbe`` et
/// ``LibrarySampleSeeder``. Sans lui, ces écrans ne se regardent qu'après
/// avoir importé un PGN à la main, autrement dit jamais.
///
/// **Compilé sous `#if DEBUG` uniquement.**
enum UserOpeningSeeder {

    #if DEBUG
    @MainActor
    static func seedIfRequested() {
        guard CommandLine.arguments.contains("-seedUserOpening") else { return }
        let store = UserOpeningStore.shared
        guard !store.catalog.contains(where: { $0.name == "Répertoire de test" }) else { return }
        guard let result = try? OpeningPGNImporter.course(
            fromPGN: "[Event \"Répertoire de test\"]\n\n1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *",
            name: "Répertoire de test",
            side: .white,
            id: UserOpeningStore.newIdentifier()
        ) else { return }
        try? store.save(result.course)
    }
    #else
    @MainActor
    static func seedIfRequested() {}
    #endif
}
