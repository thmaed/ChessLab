import Foundation

/// Les répertoires d'ouvertures des personnages (`opponent_books.json`) :
/// un arbre par identifiant, au format du livre général
/// (``OpeningBookNode``), servi par le même tirage (``OpeningBookEngine``).
///
/// Un arbre porte les DEUX camps : aux nœuds du personnage, les poids sont
/// ses préférences ; aux nœuds adverses, les réponses qu'il connaît. Dès que
/// l'adversaire en sort, Maia prend le relais — il connaît les ouvertures
/// bien au-delà de ces quelques lignes, ce livre ne sert qu'à donner à
/// chaque personnage SES premiers coups.
enum OpponentBooks {
    private static let books: [String: OpeningBook] = {
        guard let url = Bundle.main.url(forResource: "opponent_books", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: OpeningBook].self, from: data)
        else { return [:] }
        return decoded
    }()

    static func book(for profile: OpponentProfile) -> OpeningBook? {
        guard let id = profile.bookID else { return nil }
        return books[id]
    }

    static var loadedIDs: [String] { Array(books.keys).sorted() }
}
