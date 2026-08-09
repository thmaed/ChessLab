import SwiftUI

/// Choix d'un cours à explorer, depuis le catalogue embarqué. Regroupé par camp
/// d'étude. Écran d'APERÇU (gardé par ``OpeningsGraphFeature``) — pas de barre
/// de navigation propre, l'hôte porte le titre.
struct OpeningCoursePickerView: View {
    let onSelect: (String) -> Void

    private var entries: [OpeningCatalogEntry] { OpeningCourseLoader.catalog }
    private var white: [OpeningCatalogEntry] { entries.filter { $0.side == .white } }
    private var black: [OpeningCatalogEntry] { entries.filter { $0.side == .black } }

    var body: some View {
        List {
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
    }

    private func section(_ title: LocalizedStringKey, _ items: [OpeningCatalogEntry]) -> some View {
        Section {
            ForEach(items, id: \.id) { entry in
                Button { onSelect(entry.id) } label: { row(entry) }
                    .listRowBackground(Theme.surface)
            }
        } header: {
            Text(title).foregroundStyle(Theme.textSecondary)
        }
    }

    private func row(_ entry: OpeningCatalogEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(entry.name))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 6) {
                    if let eco = entry.eco, !eco.isEmpty {
                        Text(eco.joined(separator: "–"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.info)
                    }
                    Text("\(entry.positionCount) positions")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
