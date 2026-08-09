import Foundation

/// Index inverse FEN normalisée → cours qui contiennent cette position, pour
/// afficher les TRANSPOSITIONS dans l'Explorer (« cette position se rejoint
/// aussi via la Caro-Kann »).
///
/// PUR et injectable (`init(courses:)`) — donc testable sans bundle. La version
/// `bundled` charge tous les cours du catalogue une seule fois, PARESSEUSEMENT
/// (au premier accès, c.-à-d. à l'ouverture de l'Explorer, jamais au lancement).
/// Pour le catalogue complet (J9), on précalculera cet index hors app si le
/// coût de chargement devient sensible.
struct OpeningTranspositionIndex {
    private let byFEN: [String: [(id: String, name: String)]]

    init(courses: [OpeningCourse]) {
        var map: [String: [(id: String, name: String)]] = [:]
        for course in courses {
            for key in course.positions.keys {
                var list = map[key] ?? []
                if !list.contains(where: { $0.id == course.id }) {
                    list.append((id: course.id, name: course.name))
                    map[key] = list
                }
            }
        }
        byFEN = map
    }

    /// Noms des AUTRES cours contenant cette position (hors `courseID`).
    func courses(for fen: String, excluding courseID: String) -> [String] {
        (byFEN[fen] ?? []).filter { $0.id != courseID }.map(\.name)
    }

    /// Index de tous les cours embarqués (construit une seule fois).
    static let bundled: OpeningTranspositionIndex = {
        let courses = OpeningCourseLoader.catalog.compactMap { OpeningCourseLoader.course(id: $0.id) }
        return OpeningTranspositionIndex(courses: courses)
    }()
}
