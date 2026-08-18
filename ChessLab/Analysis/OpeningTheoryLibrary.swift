import Foundation

/// Les 149 familles d'ouvertures « linéaires » — réduites à ce que le code
/// VIVANT consomme : leur PGN, pour étendre la détection « coup de
/// théorie » de l'analyse (``EcoOpeningLoader/bookLines``).
///
/// L'écran qui présentait ces familles (l'ancienne bibliothèque) a été
/// supprimé le 18/08 avec le flux Explorateur (bug18aout §1, option A) ; le
/// compilateur a rappelé que la DONNÉE, elle, servait encore — c'est tout
/// l'intérêt d'un inventaire vérifié par le build. Le décodage n'extrait que
/// les champs utiles, le reste du JSON est ignoré.
struct OpeningTheoryEntry: Codable, Hashable {
    let family: String
    let pgn: String
}

enum OpeningTheoryLibrary {
    static let standard: [OpeningTheoryEntry] = load(from: .main)

    static func load(from bundle: Bundle) -> [OpeningTheoryEntry] {
        guard
            let url = bundle.url(forResource: "opening_library", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([OpeningTheoryEntry].self, from: data)
        else {
            return []
        }
        return entries
    }
}
