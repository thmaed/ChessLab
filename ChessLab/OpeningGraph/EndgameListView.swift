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
    var onOpenLab: () -> Void = {}
    var onPlayVsEngine: () -> Void = {}
    var onOpenTwoPlayer: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    /// Même lien que dans l'écran Ouvertures : le catalogue des cours
    /// personnels est un CACHE, recalculé par `reload()` seulement, et
    /// CloudKit ne prévient personne. Sans ce `@Query`, une finale personnelle
    /// arrivée d'un autre appareil n'apparaissait ici qu'après un
    /// rafraîchissement déclenché ailleurs (corrigé le 20/08/2026).
    @Query private var userRecords: [UserOpeningRecord]
    @State private var dueCount = 0
    /// Filtres de tête de liste — 77 cours sur 9 familles, sans eux il faut
    /// ~14 écrans de défilement pour atteindre les études (retour
    /// utilisateur du 19/08). `nil` = tout montrer.
    @State private var levelFilter: OpeningLevel?
    @State private var familyFilter: String?

    private var entries: [OpeningCatalogEntry] { OpeningCatalog.all.filter(\.isEndgame) }

    /// Empreinte de la base : couvre l'arrivée d'un cours comme sa
    /// modification (un simple compte manquerait les secondes).
    private var recordsSignature: String {
        userRecords
            .map { "\($0.id)@\(Int($0.updatedAt.timeIntervalSince1970))" }
            .sorted()
            .joined(separator: "|")
    }
    private var languageCode: String { AppSettings.shared.appLanguage.resolvedCode }

    /// L'ordre pédagogique des familles — du pion (tout part de là) aux études.
    private static let familyOrder = ["pawns", "rooks", "bishops", "knights", "imbalances", "queens", "mates", "practical", "themes"]

    private static let familyTitles: [String: LocalizedStringKey] = [
        "pawns": "Finales de pions",
        "rooks": "Finales de tours",
        "bishops": "Finales de fous",
        "knights": "Finales de cavaliers",
        "imbalances": "Déséquilibres matériels",
        "queens": "Finales de dames",
        "mates": "Mats élémentaires",
        "practical": "Études célèbres",
        "themes": "Thèmes transversaux",
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
        "themes": ("lightbulb.fill", Theme.gold),
    ]

    /// Libellés COURTS des familles pour les puces (les titres de section,
    /// eux, gardent la forme longue « Finales de pions »).
    private static let familyChipTitles: [String: LocalizedStringKey] = [
        "pawns": "Pions", "rooks": "Tours", "bishops": "Fous",
        "knights": "Cavaliers", "imbalances": "Déséquilibres",
        "queens": "Dames", "mates": "Mats", "practical": "Études",
        "themes": "Thèmes",
    ]

    private var filteredByLevel: [OpeningCatalogEntry] {
        guard let levelFilter else { return entries }
        return entries.filter { $0.level == levelFilter }
    }

    private var visibleFamilies: [String] {
        Self.familyOrder.filter { family in
            (familyFilter == nil || familyFilter == family)
                && filteredByLevel.contains { $0.family == family }
        }
    }

    var body: some View {
        List {
            filterBar
            if dueCount > 0 { reviewSection }
            ForEach(visibleFamilies, id: \.self) { family in
                section(family: family, filteredByLevel.filter { $0.family == family })
            }
            if visibleFamilies.isEmpty {
                Section {
                    Text("Aucun cours ne correspond aux filtres.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .listRowBackground(Theme.surface)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                QuickSwitchMenu(
                    onOpenLab: onOpenLab, onPlayVsEngine: onPlayVsEngine, onOpenTwoPlayer: onOpenTwoPlayer
                )
            }
        }
        .onAppear { refresh() }
        .onChange(of: recordsSignature) { _, _ in UserOpeningStore.shared.reload() }
    }

    /// Même file de révision que les ouvertures : la mémorisation est
    /// attachée aux POSITIONS, une séance mêle naturellement les deux.
    private func refresh() {
        OpeningProgressSync.reconcileIfStale(in: modelContext)
        let now = Date()
        let snapshots = OpeningTrainViewModel.snapshots(in: modelContext)
        dueCount = snapshots.values.filter { $0.reps > 0 && ($0.dueDate ?? .distantFuture) <= now }.count
    }

    /// La barre de filtres : niveau (trois puces fixes) puis familles (neuf
    /// puces, défilement horizontal) — le composant ``FilterChip`` maison,
    /// même mécanique que la bibliothèque d'analyses. Re-taper une puce
    /// active la désactive.
    private var filterBar: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    FilterChip(label: "Tous", tint: Theme.gold, isSelected: levelFilter == nil) {
                        levelFilter = nil
                    }
                    FilterChip(label: "Club", tint: Theme.accent, isSelected: levelFilter == .club) {
                        levelFilter = levelFilter == .club ? nil : .club
                    }
                    FilterChip(label: "Avancé", tint: Theme.warning, isSelected: levelFilter == .advanced) {
                        levelFilter = levelFilter == .advanced ? nil : .advanced
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.familyOrder, id: \.self) { family in
                            if let icon = Self.familyIcons[family] {
                                FilterChip(
                                    label: Self.familyChipTitles[family] ?? "",
                                    icon: icon.name, tint: icon.tint,
                                    isSelected: familyFilter == family
                                ) {
                                    familyFilter = familyFilter == family ? nil : family
                                }
                                .accessibilityIdentifier("endgameFamilyChip_\(family)")
                            }
                        }
                    }
                    // Les capsules débordent d'un souffle de leur ScrollView
                    // (lueur de sélection) : un liseré vertical évite l'écrêtage.
                    .padding(.vertical, 2)
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Filtres des finales")
        }
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
