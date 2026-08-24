import SwiftData
import SwiftUI

/// Le choix de l'ouverture, en entrée du module Labs.
///
/// Volontairement plus SEC que l'écran Ouvertures en production : ici on ne
/// gère ni révision, ni import, ni édition — on choisit ce qu'on va DISSÉQUER.
/// Une recherche en tête (cinquante-huit ouvertures, on tape trois lettres
/// plutôt que de faire défiler), deux filtres de camp, et c'est tout.
///
/// Taper une ouverture ouvre le lecteur avec l'index des lignes DÉJÀ DÉPLIÉ —
/// le prompt : « au moment du choix du type d'ouverture, je souhaite avoir un
/// écran (index ouvertures) ».
struct OpeningListView: View {
    let onSelect: (String) -> Void
    /// Ouvre l'ÉDITEUR d'arbre — répertoires personnels seulement.
    var onEdit: (String) -> Void = { _ in }
    var onOpenLab: () -> Void = {}
    var onPlayVsEngine: () -> Void = {}
    var onOpenTwoPlayer: () -> Void = {}

    @State private var search = ""
    @State private var sideFilter: OpeningSide?
    @State private var levelFilter: OpeningLevel?
    @State private var showImport = false
    @State private var appSettings = AppSettings.shared
    /// Observé : la liste se rafraîchit d'elle-même après un import.
    @State private var store = UserOpeningStore.shared
    @State private var pendingDeletion: OpeningCatalogEntry?

    /// Les répertoires personnels tels que la BASE les voit.
    ///
    /// 🐛 Sans cette requête, l'écran ne voit jamais arriver les répertoires
    /// créés sur un autre appareil : `store.catalog` est un tableau mis en
    /// cache, recalculé par `reload()` seulement, et CloudKit ne prévient
    /// personne. `@Query` fait le lien — SwiftData réévalue la vue quand des
    /// enregistrements arrivent, et on relit le catalogue à ce moment-là.
    @Query private var userRecords: [UserOpeningRecord]

    /// Empreinte de ce que contient la base : identifiants et dates.
    private var recordsSignature: String {
        userRecords
            .map { "\($0.id)@\(Int($0.updatedAt.timeIntervalSince1970))" }
            .sorted()
            .joined(separator: "|")
    }

    private var languageCode: String { appSettings.appLanguage.resolvedCode }

    private var entries: [OpeningCatalogEntry] {
        OpeningCatalogFeature.catalog
            .filter { sideFilter == nil || $0.side == sideFilter }
            // Les répertoires IMPORTÉS échappent au filtre de niveau : ils
            // n'en portent pas de significatif (l'app leur met « club » par
            // défaut), et ce que l'utilisateur a apporté lui-même ne doit pas
            // disparaître derrière un filtre qu'il n'a pas renseigné.
            .filter { levelFilter == nil || $0.level == levelFilter || UserOpeningStore.isUserCourse(id: $0.id) }
            .filter { matches($0, query: search) }
    }

    private func sorted(_ items: [OpeningCatalogEntry]) -> [OpeningCatalogEntry] {
        items.sorted { displayName($0).localizedStandardCompare(displayName($1)) == .orderedAscending }
    }

    /// Les répertoires PERSONNELS ont leur SECTION, en tête : rangés
    /// alphabétiquement au milieu de cinquante-huit ouvertures livrées, ils
    /// étaient introuvables, et rien ne disait qu'un import avait marché.
    private var mine: [OpeningCatalogEntry] {
        sorted(entries.filter { UserOpeningStore.isUserCourse(id: $0.id) })
    }
    private var white: [OpeningCatalogEntry] {
        sorted(entries.filter { !UserOpeningStore.isUserCourse(id: $0.id) && $0.side == .white })
    }
    private var black: [OpeningCatalogEntry] {
        sorted(entries.filter { !UserOpeningStore.isUserCourse(id: $0.id) && $0.side == .black })
    }

    /// Nom affiché (traduit via le bundle redirigé, comme l'écran Ouvertures).
    private func displayName(_ entry: OpeningCatalogEntry) -> String {
        Bundle.main.localizedString(forKey: entry.name, value: entry.name, table: nil)
    }

    /// Recherche sur le nom ET le code ECO : on cherche « C50 » aussi souvent
    /// que « italienne ». Insensible à la casse et aux accents.
    private func matches(_ entry: OpeningCatalogEntry, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        let haystack = ([displayName(entry), entry.name] + (entry.eco ?? [])).joined(separator: " ")
        return haystack.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                intro
                filterBar
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Aucune ouverture", systemImage: "magnifyingglass",
                        description: Text("Aucune ouverture ne correspond à cette recherche.")
                    )
                    .padding(.top, 40)
                } else {
                    if !mine.isEmpty { section("Mes répertoires", mine) }
                    if !white.isEmpty { section("Répertoire blanc", white) }
                    if !black.isEmpty { section("Répertoire noir", black) }
                }
            }
            .padding(16)
        }
        .searchable(text: $search, prompt: Text("Rechercher une ouverture ou un code ECO"))
        .appBackground()
        .navigationTitle("Ouvertures")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showImport = true } label: {
                    Label("Ajouter un répertoire", systemImage: "plus")
                }
                .tint(Theme.accent)
                .accessibilityIdentifier("opening_add")
            }
            ToolbarItem(placement: .topBarTrailing) {
                QuickSwitchMenu(
                    onPlayVsEngine: onPlayVsEngine,
                    onOpenTwoPlayer: onOpenTwoPlayer,
                    onOpenLab: onOpenLab
                )
            }
        }
        .onAppear {
            // Le répertoire personnel de test (`-seedUserOpening`) : sans lui,
            // le menu d'actions et l'éditeur d'arbre ne se regardent qu'après
            // avoir importé un PGN à la main, autrement dit jamais. Ce point
            // d'appel vivait dans l'écran Ouvertures d'origine ; il suit ici.
            UserOpeningSeeder.seedIfRequested()
        }
        .onChange(of: recordsSignature) { _, _ in store.reload() }
        .confirmationDialog(
            "Supprimer ce répertoire ?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let pendingDeletion { store.delete(id: pendingDeletion.id) }
                pendingDeletion = nil
            }
            Button("Annuler", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Le fichier quitte cet appareil. Votre progression sur ces positions est conservée.")
        }
        .sheet(isPresented: $showImport) {
            // Même feuille d'import que l'écran Ouvertures — PGN collé,
            // fichier, ou étude Lichess publique. Le magasin est le MÊME
            // (``UserOpeningStore``) : un répertoire importé d'un côté est
            // visible de l'autre, il n'y a qu'une bibliothèque.
            OpeningImportSheet { _ in }
        }
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: "books.vertical.fill", tint: Theme.warning, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text("Chaque position, disséquée")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("L'index de toutes les lignes, les coups des maîtres avec leurs pourcentages, et les trois meilleurs coups de Stockfish — calculés d'avance.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }

    /// Les mêmes filtres que l'écran Ouvertures, avec les mêmes puces : c'est
    /// la même bibliothèque, on ne réapprend pas une commande en changeant
    /// d'écran. Défilement horizontal — cinq puces tiennent sur un iPhone
    /// standard, mais pas en Display Zoom ni aux grandes tailles de texte.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "Tous", tint: Theme.warning,
                           isSelected: sideFilter == nil && levelFilter == nil) {
                    sideFilter = nil
                    levelFilter = nil
                }
                PieceFilterChip(glyph: "♙", isSelected: sideFilter == .white,
                                accessibilityLabel: "Répertoire blanc") {
                    sideFilter = sideFilter == .white ? nil : .white
                }
                PieceFilterChip(glyph: "♟\u{FE0E}", isSelected: sideFilter == .black,
                                accessibilityLabel: "Répertoire noir") {
                    sideFilter = sideFilter == .black ? nil : .black
                }
                FilterChip(label: "Club", tint: Theme.accent, isSelected: levelFilter == .club) {
                    levelFilter = levelFilter == .club ? nil : .club
                }
                FilterChip(label: "Avancé", tint: Theme.warning, isSelected: levelFilter == .advanced) {
                    levelFilter = levelFilter == .advanced ? nil : .advanced
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filtres des ouvertures")
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, _ items: [OpeningCatalogEntry]) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .textCase(.uppercase).tracking(0.4)
            .padding(.top, 6)
        ForEach(items) { entry in
            // Le bouton d'ouverture et le menu d'actions sont FRÈRES, pas
            // imbriqués : un `Menu` posé dans le label d'un `Button` ne reçoit
            // jamais ses propres taps, le bouton extérieur les avale.
            HStack(spacing: 4) {
                row(entry)
                if UserOpeningStore.isUserCourse(id: entry.id) { actionsMenu(entry) }
            }
        }
    }

    /// Actions d'un répertoire personnel, TOUJOURS VISIBLES.
    ///
    /// Une fonctionnalité qui demande de deviner qu'il faut balayer une ligne
    /// n'existe pas vraiment : c'est ce qui rendait l'éditeur d'arbre
    /// introuvable dans l'écran qu'on remplace.
    @ViewBuilder
    private func actionsMenu(_ entry: OpeningCatalogEntry) -> some View {
        Menu {
            Button { onEdit(entry.id) } label: {
                Label("Modifier le répertoire", systemImage: "pencil")
            }
            if let url = store.exportFileURL(for: entry.id) {
                ShareLink(item: url) { Label("Partager", systemImage: "square.and.arrow.up") }
            }
            Divider()
            Button(role: .destructive) { pendingDeletion = entry } label: {
                Label("Supprimer", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Actions du répertoire")
        .accessibilityIdentifier("openingActions_\(entry.id)")
    }

    private func row(_ entry: OpeningCatalogEntry) -> some View {
        Button { onSelect(entry.id) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(LocalizedStringKey(entry.name))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if let eco = ecoLabel(entry) {
                        Text(eco)
                            .font(.caption2.weight(.semibold).monospaced())
                            .foregroundStyle(Theme.teal)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.teal.opacity(0.14), in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                if let summary = entry.summary?.resolved(languageCode) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Les pastilles ne se coupant plus, la RANGÉE doit pouvoir
                // passer à la ligne.
                FlowLayout(spacing: 8, lineSpacing: 6) {
                    if UserOpeningStore.isUserCourse(id: entry.id) {
                        stat(LocalizationController.string("Mon répertoire"), "person.crop.circle")
                    }
                    // Chaînes CALCULÉES : `Text(String)` ne localise pas, on
                    // passe donc par le catalogue à la main.
                    stat(LocalizationController.string(entry.side == .white ? "Blancs" : "Noirs"),
                         entry.side == .white ? "circle" : "circle.fill")
                    if let count = entry.positionCount {
                        stat(LocalizationController.string("%lld positions", count), "square.grid.3x3")
                    }
                    if let depth = entry.maxDepth {
                        stat(LocalizationController.string("%lld coups", depth / 2), "arrow.down.to.line")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 14)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("opening_\(entry.id)")
    }

    private func ecoLabel(_ entry: OpeningCatalogEntry) -> String? {
        guard let eco = entry.eco, let first = eco.first else { return nil }
        // Le catalogue porte un intervalle (« C60 »…« C99 ») ou un code seul.
        if eco.count > 1, let last = eco.last, last != first { return "\(first)–\(last)" }
        return first
    }

    private func stat(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2)
            .foregroundStyle(Theme.textTertiary)
            // Une pastille ne se coupe JAMAIS en plein mot : « Blancs »
            // devenait « Blanc/s » et « Mon répertoire » « Mon réper-/toire ».
            // Même remède que ``FilterChip``, qui documente déjà ce piège.
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Theme.surfaceElevated.opacity(0.6), in: Capsule())
    }
}
