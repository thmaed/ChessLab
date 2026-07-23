import SwiftData
import SwiftUI

/// Liste simple des parties enregistrées (mode Jouer et Deux joueurs) —
/// pas encore de recherche/filtre par tag, voir PROGRESS.md.
struct AnalysisLibraryView: View {
    let onSelect: (AnalysisSource) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameRecord.playedAt, order: .reverse) private var records: [GameRecord]

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
                        ForEach(records) { record in
                            Button {
                                guard let pgn = record.pgn, !pgn.isEmpty else { return }
                                onSelect(.pgn(pgn))
                            } label: {
                                recordRow(record)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .padding(20)
                }
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
