import Foundation
import SwiftData
import SwiftUI

/// Ce que la carte d'un cours montre en plus de son texte (C5) : la position
/// clé en vignette et la maîtrise (positions travaillées / positions à
/// travailler).
struct CourseCardInfo: Equatable {
    let fen: String
    let studied: Int
    let total: Int

    var progress: Double { total == 0 ? 0 : min(1, Double(studied) / Double(total)) }

    /// Une ouverture : la position après dix demi-coups de la ligne principale
    /// (l'ouverture reconnaissable) ; une finale : la position de départ.
    static let openingPlies = 10

    static func thumbnailFEN(of course: OpeningCourse) -> String {
        if course.isEndgame { return course.rootFEN }
        let line = OpeningTrainingQueue.mainLine(of: course)
        return line.edges.prefix(openingPlies).last?.toFEN ?? course.rootFEN
    }

    static func compute(course: OpeningCourse, studied: Set<String>) -> CourseCardInfo {
        let cards = OpeningTrainingQueue.trainableCards(of: course)
        return CourseCardInfo(
            fen: thumbnailFEN(of: course),
            studied: cards.filter { studied.contains($0.fenKey) }.count,
            total: cards.count
        )
    }
}

/// Les cartes de tous les cours d'une liste, calculées hors du dessin : charger
/// un cours décode son JSON, et une liste en montre des dizaines.
@MainActor
@Observable
final class CourseCardInfoStore {
    private(set) var infos: [String: CourseCardInfo] = [:]

    func load(ids: [String], in context: ModelContext) async {
        let rows = (try? context.fetch(FetchDescriptor<OpeningPositionProgress>())) ?? []
        let studied = Set(rows.filter { $0.reps > 0 }.map(\.fenKey))
        var result: [String: CourseCardInfo] = [:]
        for id in ids {
            if let course = OpeningCatalog.course(id: id) {
                result[id] = CourseCardInfo.compute(course: course, studied: studied)
            }
            if result.count % 8 == 0 { await Task.yield() }
        }
        infos = result
    }
}

/// La pastille de niveau, aux teintes des puzzles : vert, ambre, rose.
enum CourseLevelStyle {
    static func label(_ level: OpeningLevel) -> String {
        switch level {
        case .beginner: LocalizationController.string("Débutant")
        case .club: LocalizationController.string("Club")
        case .advanced: LocalizationController.string("Avancé")
        }
    }
}

/// Pastille de niveau et barre de maîtrise partagées par les listes (C5).
struct CourseMasteryBar: View {
    let progress: Double
    let tint: Color
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceElevated)
                Capsule().fill(tint).frame(width: max(progress > 0 ? 4 : 0, proxy.size.width * progress))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

struct CourseLevelPill: View {
    let level: OpeningLevel
    private var tint: Color {
        switch level {
        case .beginner: Theme.accent
        case .club: Theme.warning
        case .advanced: Theme.rose
        }
    }
    var body: some View {
        Text(CourseLevelStyle.label(level))
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(tint.opacity(0.16), in: Capsule())
            .fixedSize()
    }
}
