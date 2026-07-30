import SwiftData
import SwiftUI

/// Liste des parties enregistrées (mode Jouer et Deux joueurs), avec
/// recherche (noms des joueurs) et filtres par mode et par résultat. Les
/// parties sont peu nombreuses (centaines au plus) : on charge tout via
/// `@Query` et on filtre en mémoire, ce qui garde recherche et filtres
/// instantanés sans requête dynamique.
struct AnalysisLibraryView: View {
    let onSelect: (AnalysisSource) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameRecord.playedAt, order: .reverse) private var records: [GameRecord]

    @State private var searchText = ""
    @State private var modeFilter: GameRecordMode?
    @State private var resultFilter: ResultFilter = .all

    /// Résultat du point de vue de l'utilisateur. N'a de sens que face à
    /// l'ordinateur (le côté « Vous » est identifiable) ; en deux joueurs,
    /// seules les nulles sont classables, les parties décisives restent
    /// neutres (elles n'apparaissent que sous « Toutes »).
    private enum ResultFilter: Hashable {
        case all, wins, draws, losses
    }

    private var filteredRecords: [GameRecord] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return records.filter { record in
            if let modeFilter, record.mode != modeFilter { return false }
            if resultFilter != .all, userResult(record) != resultFilter { return false }
            if query.isEmpty { return true }
            let haystack = [record.whiteName, record.blackName, record.resultRaw]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
            return haystack.contains(query)
        }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "Aucune partie enregistrée",
                    systemImage: "books.vertical",
                    description: Text("Les parties terminées (mode Jouer et Deux joueurs) apparaîtront ici.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        filterBar

                        if filteredRecords.isEmpty {
                            ContentUnavailableView(
                                "Aucun résultat",
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text("Aucune partie ne correspond à la recherche ou aux filtres.")
                            )
                            .padding(.top, 40)
                        } else {
                            ForEach(filteredRecords) { record in
                                Button {
                                    guard let pgn = record.pgn, !pgn.isEmpty else { return }
                                    onSelect(.pgn(pgn))
                                } label: {
                                    recordRow(record)
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                    }
                    .padding(20)
                }
                .searchable(text: $searchText, prompt: "Rechercher un joueur")
            }
        }
        .appBackground()
        .navigationTitle("Bibliothèque")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // Les parties enregistrées AVANT l'ajout de `moveCount` n'en ont pas :
        // on le reconstruit depuis leur PGN, une seule fois, pour que la
        // bibliothèque existante ne reste pas muette sur sa longueur.
        .task { GameRecord.backfillMoveCounts(in: modelContext) }
    }

    // MARK: Filtres

    @ViewBuilder
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "Tous les modes", tint: Theme.accent, isSelected: modeFilter == nil) {
                        modeFilter = nil
                    }
                    FilterChip(label: "Ordinateur", icon: "cpu", tint: Theme.accent, isSelected: modeFilter == .vsEngine) {
                        modeFilter = (modeFilter == .vsEngine) ? nil : .vsEngine
                    }
                    FilterChip(label: "Deux joueurs", icon: "person.2.fill", tint: Theme.accent, isSelected: modeFilter == .twoHuman) {
                        modeFilter = (modeFilter == .twoHuman) ? nil : .twoHuman
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "Tous résultats", tint: Theme.info, isSelected: resultFilter == .all) {
                        resultFilter = .all
                    }
                    FilterChip(label: "Gagnées", icon: "trophy.fill", tint: Theme.info, isSelected: resultFilter == .wins) {
                        resultFilter = (resultFilter == .wins) ? .all : .wins
                    }
                    FilterChip(label: "Nulles", icon: "equal", tint: Theme.info, isSelected: resultFilter == .draws) {
                        resultFilter = (resultFilter == .draws) ? .all : .draws
                    }
                    FilterChip(label: "Perdues", icon: "flag.slash", tint: Theme.info, isSelected: resultFilter == .losses) {
                        resultFilter = (resultFilter == .losses) ? .all : .losses
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }

    /// Classe une partie du point de vue de l'utilisateur. « Vous » est stocké
    /// littéralement par ``GameLibraryService`` (indépendant de la langue),
    /// donc identifiable. Deux joueurs : nulle si nulle, sinon neutre.
    private func userResult(_ record: GameRecord) -> ResultFilter {
        guard let result = record.resultRaw else { return .all }
        if result == "1/2-1/2" { return .draws }
        guard record.mode == .vsEngine else { return .all }
        let userIsWhite = record.whiteName == "Vous"
        let whiteWon = result == "1-0"
        return (whiteWon == userIsWhite) ? .wins : .losses
    }

    // MARK: Ligne

    private func recordRow(_ record: GameRecord) -> some View {
        HStack(spacing: 14) {
            IconBadge(systemImage: "flag.checkered", tint: Theme.teal, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(record.whiteName ?? "Blancs") – \(record.blackName ?? "Noirs")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 8) {
                    Text(record.resultRaw ?? "?")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.accent, in: Capsule())
                    if let date = record.playedAt {
                        // Date ET heure : deux parties du même jour ne se
                        // distinguaient pas l'une de l'autre. `.formatted`
                        // localise l'ordre et le format (24 h / AM-PM).
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if let moveCount = record.moveCount {
                        Text("\(moveCount) coups")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.textTertiary)
        }
        .cardStyle()
    }
}
