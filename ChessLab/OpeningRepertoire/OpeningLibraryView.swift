import ChessKit
import SwiftUI

/// Contenu de l'onglet "Bibliothèque" de ``RepertoireListView`` : mêmes
/// facettes de sélection que ``PuzzleQueueView`` (chips capsules
/// teintées), adaptées à des familles nommées plutôt qu'à un tirage
/// aléatoire — camp puis catégorie ECO filtrent une LISTE (149 familles,
/// trop nombreuses pour des chips). Taper une ligne va DIRECTEMENT à
/// l'échiquier (``onStartLine``), qui rejoue toute la ligne coup après
/// coup (``OpeningLineTrainingViewModel``) — pas de menu intermédiaire
/// "Réviser/Construire/Importer" comme pour un répertoire personnel, et
/// pas de fiche isolée par position : une entrée de bibliothèque se
/// pratique d'un bout à l'autre. Pas de navigation/toolbar propre : cette
/// vue est embarquée, ``RepertoireListView`` porte le titre et le "+".
struct OpeningLibraryView: View {
    let onStartLine: (OpeningLibraryEntry, Piece.Color) -> Void

    @State private var selectedColor: Piece.Color = .white
    @State private var selectedCategory: String?
    @State private var selectedStyle: OpeningStyle?
    @State private var searchText = ""

    private static let categories: [(letter: String, label: String)] = [
        ("A", "Flanc"), ("B", "Semi-ouvertes"), ("C", "Ouvertes"), ("D", "Fermées"), ("E", "Indiennes"),
    ]

    private var filteredEntries: [OpeningLibraryEntry] {
        // Tri sur le nom AFFICHÉ, pas sur la clé anglaise de la donnée :
        // le JSON est trié anglais, et sans re-tri la liste française
        // paraîtrait mélangée — « Partie espagnole » rangée au R de « Ruy
        // Lopez ». `localizedStandardCompare` : accents et casse à la
        // française (« Défense écossaise » ne part pas en fin de liste).
        sortedByDisplayName.filter { entry in
            guard selectedColor == .white || entry.hasBlack else { return false }
            guard selectedCategory == nil || entry.category == selectedCategory else { return false }
            // Multi-styles : une ouverture matche si elle CONTIENT le style
            // filtré — la Londres apparaît sous « Système » ET « Classiques ».
            guard selectedStyle == nil || entry.styleCategories.contains(selectedStyle!) else { return false }
            // La recherche matche le nom AFFICHÉ (français quand l'app est
            // en français : « sicilienne » doit trouver « Sicilian
            // Defense ») ET le nom anglais d'origine — un joueur
            // francophone qui connaît « Ruy Lopez » ne doit pas le perdre.
            guard searchText.isEmpty
                || entry.family.localizedCaseInsensitiveContains(searchText)
                || LocalizationController.string(entry.family).localizedCaseInsensitiveContains(searchText)
            else { return false }
            return true
        }
    }

    /// Bibliothèque re-triée sur le nom localisé. Recalculée à chaque
    /// évaluation de `body` — 149 entrées, coût négligeable — plutôt que
    /// mise en cache : un cache devrait être invalidé au changement de
    /// langue in-app, complexité sans bénéfice mesurable ici.
    private var sortedByDisplayName: [OpeningLibraryEntry] {
        OpeningLibraryLoader.standard.sorted {
            LocalizationController.string($0.family)
                .localizedStandardCompare(LocalizationController.string($1.family)) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                filterGroup(title: "Camp") {
                    FilterChip(label: "Blancs", icon: "circle.fill", tint: Theme.accent, isSelected: selectedColor == .white) {
                        selectedColor = .white
                    }
                    FilterChip(label: "Noirs", icon: "circle", tint: Theme.accent, isSelected: selectedColor == .black) {
                        selectedColor = .black
                    }
                }

                filterGroup(title: "Catégorie") {
                    FilterChip(label: "Toutes", tint: Theme.info, isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(Self.categories, id: \.letter) { category in
                        FilterChip(
                            label: "\(category.letter) · \(category.label)", tint: Theme.info,
                            isSelected: selectedCategory == category.letter
                        ) {
                            selectedCategory = (selectedCategory == category.letter) ? nil : category.letter
                        }
                    }
                }

                // Style stratégique : 2e axe, orthogonal à ECO (voir
                // ``OpeningStyle``). « Toutes » désélectionne.
                filterGroup(title: "Style") {
                    FilterChip(label: "Tous", tint: Theme.violet, isSelected: selectedStyle == nil) {
                        selectedStyle = nil
                    }
                    ForEach(OpeningStyle.allCases, id: \.self) { style in
                        FilterChip(
                            label: LocalizedStringKey(style.label), icon: style.systemImage, tint: Theme.violet,
                            isSelected: selectedStyle == style
                        ) {
                            selectedStyle = (selectedStyle == style) ? nil : style
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            if filteredEntries.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView("Aucune ouverture", systemImage: "books.vertical", description: Text("Essayez une autre catégorie."))
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                List {
                    ForEach(filteredEntries, id: \.family) { entry in
                        Button {
                            onStartLine(entry, selectedColor)
                        } label: {
                            entryRow(entry)
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        // Attaché au conteneur STABLE (pas à la List, qui disparaît quand le
        // filtre ne renvoie rien) : sinon le champ de recherche s'auto-
        // détruisait avec son texte encore actif → écran soft-locké.
        .searchable(text: $searchText, prompt: "Rechercher une ouverture")
    }

    private func entryRow(_ entry: OpeningLibraryEntry) -> some View {
        HStack(spacing: 12) {
            Text(entry.category)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.info)
                .frame(width: 20, height: 20)
                .background(Theme.info.opacity(0.14), in: Circle())
            // `LocalizedStringKey` et non la String brute : le nom passe
            // par le catalogue (bundle détourné par LocalizationController)
            // — « Défense sicilienne » en français, nom d'origine sinon.
            Text(LocalizedStringKey(entry.family))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
