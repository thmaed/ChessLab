import Foundation

/// Charge le livre d'ouvertures embarqué (`opening_book.json`).
enum OpeningBookLoader {
    /// Décodé une seule fois par process. En cas de fichier manquant ou
    /// corrompu, retombe silencieusement sur un livre vide : le moteur
    /// bascule alors simplement sur le calcul normal, jamais de crash.
    static let standard: OpeningBook = load(from: .main)

    static func load(from bundle: Bundle) -> OpeningBook {
        guard
            let url = bundle.url(forResource: "opening_book", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let book = try? JSONDecoder().decode(OpeningBook.self, from: data)
        else {
            return OpeningBook(roots: [])
        }
        return book
    }
}
