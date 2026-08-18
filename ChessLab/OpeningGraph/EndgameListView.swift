import SwiftData
import SwiftUI

/// Écran « Finales » : les cours de finales du catalogue, groupés par
/// famille (pions, tours, dames, mats, études).
///
/// Même infrastructure que les ouvertures — mêmes fichiers JSON, même
/// lecteur, même entraînement espacé, même synchro — mais un ÉCRAN dédié :
/// mélanger la Lucena entre la London et la Najdorf aurait noyé les deux
/// catalogues. Le champ `kind` du catalogue fait le tri.
///
/// Chaque cours affiché ici a une propriété qu'aucun livre n'offre : ses
/// lignes sont PROUVÉES par tablebase (≤ 7 pièces, verdict exact) — le
/// pied de l'écran le dit, parce que c'est un engagement, pas un slogan.
struct EndgameListView: View {
    /// Ouvre le lecteur d'un cours (même route que les ouvertures).
    let onSelect: (String) -> Void
    /// Lance la révision espacée du jour.
    var onReview: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var dueCount = 0

    private var entries: [OpeningCatalogEntry] { OpeningCatalog.all.filter(\.isEndgame) }
    private var languageCode: String { AppSettings.shared.appLanguage.resolvedCode }

    /// L'ordre pédagogique des familles — du pion (tout part de là) aux études.
    private static let familyOrder = ["pawns", "rooks", "bishops", "knights", "imbalances", "queens", "mates", "practical"]

    private static let familyTitles: [String: LocalizedStringKey] = [
        "pawns": "Finales de pions",
        "rooks": "Finales de tours",
        "bishops": "Finales de fous",
        "knights": "Finales de cavaliers",
        "imbalances": "Déséquilibres matériels",
        "queens": "Finales de dames",
        "mates": "Mats élémentaires",
        "practical": "Études célèbres",
    ]

    private static let familyIcons: [String: (name: String, tint: Color)] = [
        "pawns": ("arrow.up.square.fill", Theme.accent),
        "rooks": ("building.columns.fill", Theme.info),
        "bishops": ("triangle.fill", Theme.teal),
        "knights": ("hexagon.fill", Theme.danger),
        "imbalances": ("scalemass.fill", Theme.accentSecondary),
        "queens": ("crown.fill", Theme.violet),
        "mates": ("flag.checkered", Theme.warning),
        "practical": ("sparkles", Theme.rose),
    ]

    var body: some View {
        List {
            if dueCount > 0 { reviewSection }
            ForEach(Self.familyOrder, id: \.self) { family in
                let items = entries.filter { $0.family == family }
                if !items.isEmpty {
                    section(family: family, items)
                }
            }
            provenFooter
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Finales")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { refresh() }
    }

    /// Même file de révision que les ouvertures : la mémorisation est
    /// attachée aux POSITIONS, une séance mêle naturellement les deux.
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

    private func section(family: String, _ items: [OpeningCatalogEntry]) -> some View {
        Section {
            ForEach(items, id: \.id) { entry in
                Button { onSelect(entry.id) } label: { row(entry) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("endgame_\(entry.id)")
                    .listRowBackground(Theme.surface)
            }
        } header: {
            HStack(spacing: 6) {
                if let icon = Self.familyIcons[family] {
                    Image(systemName: icon.name)
                        .font(.caption2)
                        .foregroundStyle(icon.tint)
                }
                Text(Self.familyTitles[family] ?? "")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func row(_ entry: OpeningCatalogEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(entry.name))
                        .font(.body.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    // La nulle s'APPREND autant que le gain — le badge dit
                    // d'emblée quel demi-point le cours défend.
                    if entry.level == .advanced {
                        Text("Avancé")
                            .font(.caption2.weight(.bold)).foregroundStyle(Theme.warning)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.warning.opacity(0.16), in: Capsule())
                    }
                }
                if let summary = entry.summary?.resolved(languageCode) {
                    Text(summary).font(.caption).foregroundStyle(Theme.textTertiary)
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// L'engagement de la maison, en pied de liste.
    private var provenFooter: some View {
        Section {
            EmptyView()
        } footer: {
            Label {
                Text("Chaque ligne de ces cours est vérifiée par table de finales (Syzygy) : aucun coup enseigné ne lâche le gain, aucune défense proposée ne perd la nulle.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}
