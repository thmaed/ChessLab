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
struct OpeningLabsListView: View {
    let onSelect: (String) -> Void
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

    private var languageCode: String { appSettings.appLanguage.resolvedCode }

    private var entries: [OpeningCatalogEntry] {
        OpeningLabsFeature.catalog
            .filter { sideFilter == nil || $0.side == sideFilter }
            // Les répertoires IMPORTÉS échappent au filtre de niveau : ils
            // n'en portent pas de significatif (l'app leur met « club » par
            // défaut), et ce que l'utilisateur a apporté lui-même ne doit pas
            // disparaître derrière un filtre qu'il n'a pas renseigné.
            .filter { levelFilter == nil || $0.level == levelFilter || UserOpeningStore.isUserCourse(id: $0.id) }
            .filter { matches($0, query: search) }
            .sorted { sortKey($0) < sortKey($1) }
    }

    /// Les répertoires PERSONNELS en tête : ce sont ceux que l'utilisateur a
    /// choisi d'ajouter, ils ne doivent pas se perdre au milieu de
    /// cinquante-huit ouvertures livrées.
    private func sortKey(_ entry: OpeningCatalogEntry) -> String {
        (UserOpeningStore.isUserCourse(id: entry.id) ? "0" : "1") + displayName(entry).lowercased()
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
                    ForEach(entries) { row($0) }
                }
            }
            .padding(16)
        }
        .searchable(text: $search, prompt: Text("Rechercher une ouverture ou un code ECO"))
        .appBackground()
        .navigationTitle("Ouvertures — Labs")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showImport = true } label: {
                    Label("Ajouter un répertoire", systemImage: "plus")
                }
                .tint(Theme.accent)
                .accessibilityIdentifier("labsList_add")
            }
            ToolbarItem(placement: .topBarTrailing) {
                QuickSwitchMenu(
                    onOpenLab: onOpenLab,
                    onPlayVsEngine: onPlayVsEngine,
                    onOpenTwoPlayer: onOpenTwoPlayer
                )
            }
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
            IconBadge(systemImage: "chart.bar.doc.horizontal", tint: Theme.teal, size: 36)
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
                FilterChip(label: "Tous", tint: Theme.gold,
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
                HStack(spacing: 8) {
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
        .accessibilityIdentifier("labsList_\(entry.id)")
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
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Theme.surfaceElevated.opacity(0.6), in: Capsule())
    }
}
