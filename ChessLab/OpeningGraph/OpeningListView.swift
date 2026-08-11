import SwiftData
import SwiftUI

/// Écran « Ouvertures » simplifié : une liste claire des ouvertures, groupées
/// par camp. Taper une ouverture ouvre le LECTEUR (avancer coup par coup avec
/// les explications). Un bouton « Réviser » discret en tête si des positions
/// sont dues. Remplace l'ancienne bibliothèque linéaire des 149 familles.
struct OpeningListView: View {
    /// Ouvre le lecteur d'une ouverture.
    let onSelect: (String) -> Void
    /// Lance la révision espacée du jour.
    var onReview: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var dueCount = 0

    private var entries: [OpeningCatalogEntry] { OpeningCourseLoader.catalog }
    private var white: [OpeningCatalogEntry] { sortedByName(entries.filter { $0.side == .white }) }
    private var black: [OpeningCatalogEntry] { sortedByName(entries.filter { $0.side == .black }) }
    private var languageCode: String { AppSettings.shared.appLanguage.resolvedCode }

    /// Nom affiché (traduit dans la langue de l'app via le bundle redirigé).
    private func displayName(_ entry: OpeningCatalogEntry) -> String {
        Bundle.main.localizedString(forKey: entry.name, value: entry.name, table: nil)
    }

    /// Tri alphabétique par nom affiché (accents pris en compte).
    private func sortedByName(_ items: [OpeningCatalogEntry]) -> [OpeningCatalogEntry] {
        items.sorted { displayName($0).localizedStandardCompare(displayName($1)) == .orderedAscending }
    }

    var body: some View {
        List {
            if dueCount > 0 { reviewSection }
            if !white.isEmpty { section("Répertoire blanc", white) }
            if !black.isEmpty { section("Répertoire noir", black) }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Ouvertures")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        OpeningProgressSync.reconcile(in: modelContext)
        let now = Date()
        let snapshots = OpeningTrainViewModel.snapshots(in: modelContext)
        dueCount = snapshots.values.filter { $0.reps > 0 && ($0.dueDate ?? .distantFuture) <= now }.count
    }

    private var reviewSection: some View {
        Section {
            Button(action: onReview) {
                HStack(spacing: 12) {
                    Image(systemName: "checklist").foregroundStyle(Theme.accent).frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Réviser aujourd'hui").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Text("\(dueCount) position(s) à revoir").font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Text("\(dueCount)").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.16), in: Capsule())
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(Theme.surface)
        }
    }

    private func section(_ title: LocalizedStringKey, _ items: [OpeningCatalogEntry]) -> some View {
        Section {
            ForEach(items, id: \.id) { entry in
                Button { onSelect(entry.id) } label: { row(entry) }
                    .listRowBackground(Theme.surface)
                    .accessibilityIdentifier("opening_\(entry.id)")
            }
        } header: {
            Text(title).foregroundStyle(Theme.textSecondary)
        }
    }

    private func row(_ entry: OpeningCatalogEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(entry.name))
                    .font(.body.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                if let summary = entry.summary?.resolved(languageCode) {
                    Text(summary).font(.caption).foregroundStyle(Theme.textTertiary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
