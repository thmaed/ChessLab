import SwiftData
import SwiftUI

/// Choix d'un cours à explorer/apprendre/entraîner, depuis le catalogue
/// embarqué. Chaque ligne montre la COUVERTURE (positions vues/maîtrisées), un
/// BADGE de niveau, le nombre de positions DUES, et permet de marquer
/// l'ouverture dans son RÉPERTOIRE (étoile). Écran d'aperçu (gardé par
/// ``OpeningsGraphFeature``) ; l'hôte porte le titre.
///
/// La couverture et le répertoire viennent de la progression SYNCHRONISÉE :
/// on réconcilie à l'apparition (comme les écrans de puzzles).
struct OpeningCoursePickerView: View {
    let onSelect: (String) -> Void
    var onTrainDaily: () -> Void = {}
    var onTrainHardest: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var coverage: [String: OpeningCoverage] = [:]
    @State private var repertoire: Set<String> = []
    @State private var dailyCount = 0
    @State private var hardestCount = 0

    private var entries: [OpeningCatalogEntry] { OpeningCourseLoader.catalog }
    private var white: [OpeningCatalogEntry] { entries.filter { $0.side == .white } }
    private var black: [OpeningCatalogEntry] { entries.filter { $0.side == .black } }

    var body: some View {
        List {
            trainingSection
            if !white.isEmpty { section("Répertoire blanc", white) }
            if !black.isEmpty { section("Répertoire noir", black) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Explorateur")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        OpeningProgressSync.reconcile(in: modelContext)
        let snapshots = OpeningTrainViewModel.snapshots(in: modelContext)
        repertoire = RepertoireStore.memberIDs(in: modelContext)

        var newCoverage: [String: OpeningCoverage] = [:]
        var relevant: [OpeningCourse] = []
        for entry in entries {
            guard let course = OpeningCourseLoader.course(id: entry.id) else { continue }
            newCoverage[entry.id] = OpeningCoverage.compute(course: course, progress: snapshots)
            if repertoire.isEmpty || repertoire.contains(entry.id) { relevant.append(course) }
        }
        coverage = newCoverage

        let cards = relevant.flatMap { OpeningTrainingQueue.trainableCards(of: $0) }
        dailyCount = OpeningTrainingQueue.dailyQueue(cards: cards, progress: snapshots).count
        hardestCount = OpeningTrainingQueue.hardestQueue(cards: cards, progress: snapshots).count
    }

    // MARK: Entraînement

    private var trainingSection: some View {
        Section {
            Button(action: onTrainDaily) {
                trainingRow(icon: "calendar", tint: Theme.accent, title: "Réviser aujourd'hui",
                            subtitle: dailyCount > 0 ? "\(dailyCount) position(s) à réviser" : "À jour",
                            count: dailyCount)
            }
            .listRowBackground(Theme.surface)
            Button(action: onTrainHardest) {
                trainingRow(icon: "flame", tint: Theme.warning, title: "Positions difficiles",
                            subtitle: "Les nœuds les plus ratés", count: hardestCount)
            }
            .listRowBackground(Theme.surface)
            .disabled(hardestCount == 0)
            .opacity(hardestCount == 0 ? 0.5 : 1)
        } header: {
            Text("Entraînement").foregroundStyle(Theme.textSecondary)
        }
    }

    private func trainingRow(icon: String, tint: Color, title: LocalizedStringKey, subtitle: LocalizedStringKey, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                Text(subtitle).font(.caption2).foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if count > 0 {
                Text("\(count)").font(.caption.weight(.bold)).foregroundStyle(tint)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(tint.opacity(0.16), in: Capsule())
            }
            Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: Cours

    private func section(_ title: LocalizedStringKey, _ items: [OpeningCatalogEntry]) -> some View {
        Section {
            ForEach(items, id: \.id) { entry in
                row(entry).listRowBackground(Theme.surface)
            }
        } header: {
            Text(title).foregroundStyle(Theme.textSecondary)
        }
    }

    private func row(_ entry: OpeningCatalogEntry) -> some View {
        let cover = coverage[entry.id]
        let isMember = repertoire.contains(entry.id)
        return HStack(spacing: 12) {
            Button {
                let now = RepertoireStore.toggle(courseID: entry.id, side: entry.side, in: modelContext)
                if now { repertoire.insert(entry.id) } else { repertoire.remove(entry.id) }
            } label: {
                Image(systemName: isMember ? "star.fill" : "star")
                    .foregroundStyle(isMember ? Theme.warning : Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isMember ? "Retirer du répertoire" : "Ajouter au répertoire")

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(entry.name))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                if let cover, cover.total > 0 { coverageBar(cover) }
                HStack(spacing: 6) {
                    if let eco = entry.eco, !eco.isEmpty {
                        Text(eco.joined(separator: "–")).font(.caption2.weight(.bold)).foregroundStyle(Theme.info)
                    }
                    if let cover { badgeChip(cover.badge) }
                    if let cover, cover.due > 0 {
                        Text("\(cover.due) à revoir").font(.caption2.weight(.medium)).foregroundStyle(Theme.warning)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect(entry.id) }

            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private func coverageBar(_ cover: OpeningCoverage) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(Theme.accent.opacity(0.35))
                    .frame(width: geo.size.width * cover.seenFraction)
                Capsule().fill(Theme.accent)
                    .frame(width: geo.size.width * cover.masteryFraction)
            }
        }
        .frame(height: 4)
        .frame(maxWidth: 180)
    }

    private func badgeChip(_ badge: OpeningBadge) -> some View {
        let tint: Color = switch badge {
        case .notStarted: Theme.textTertiary
        case .discovery: Theme.info
        case .worked: Theme.violet
        case .solid: Theme.accent
        }
        return Label(LocalizedStringKey(badge.label), systemImage: badge.systemImage)
            .font(.caption2.weight(.semibold)).foregroundStyle(tint)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(tint.opacity(0.14), in: Capsule())
    }
}
