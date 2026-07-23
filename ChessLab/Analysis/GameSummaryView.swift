import ChessKit
import SwiftUI

/// Feuille « Bilan de la partie » : précision et décompte de chaque
/// catégorie de coup, joueur par joueur — le tableau récapitulatif que
/// chess.com montre à la fin d'une Game Review.
struct GameSummaryView: View {
    let summary: GameSummary
    let whiteName: String
    let blackName: String
    let opening: EcoOpening?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let opening {
                        openingRow(opening)
                    }
                    accuracyCards
                    categoryTable
                    if !summary.isComplete {
                        incompleteNote
                    }
                }
                .padding(16)
            }
            .appBackground()
            .navigationTitle("Bilan de la partie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
    }

    private func openingRow(_ opening: EcoOpening) -> some View {
        HStack(spacing: 8) {
            Text(opening.eco)
                .font(.caption2.weight(.bold).monospaced())
                .foregroundStyle(Theme.background)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.accentGradient, in: Capsule())
            Text(opening.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    /// Les deux joueurs côte à côte, la précision en grand — c'est LE
    /// chiffre que tout le monde vient chercher.
    private var accuracyCards: some View {
        HStack(spacing: 12) {
            accuracyCard(name: whiteName, side: summary.white, color: .white)
            accuracyCard(name: blackName, side: summary.black, color: .black)
        }
    }

    private func accuracyCard(name: String, side: GameSummary.Side, color: Piece.Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                Circle()
                    .fill(color == .white ? Color.white : Color.black)
                    .overlay(Circle().strokeBorder(Theme.strokeStrong, lineWidth: 1))
                    .frame(width: 10, height: 10)
                Text(name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            if let accuracy = side.accuracy {
                Text("\(Int(accuracy.rounded()))")
                    .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    + Text(" %")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text(verbatim: "—")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            Text("précision")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.surface, in: Theme.cardShape)
        .overlay(Theme.cardShape.strokeBorder(Theme.stroke, lineWidth: 1))
    }

    /// Une ligne par catégorie, le libellé et sa pastille au centre, les
    /// décomptes de chaque joueur de part et d'autre — les zéros restent
    /// affichés mais s'effacent : la ligne « Gaffes 0 | 0 » est une bonne
    /// nouvelle qui mérite d'être lisible.
    private var categoryTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(MoveQuality.allCases.enumerated()), id: \.element) { position, quality in
                categoryRow(quality)
                if position < MoveQuality.allCases.count - 1 {
                    Divider().overlay(Theme.stroke)
                }
            }
        }
        .background(Theme.surface, in: Theme.cardShape)
        .overlay(Theme.cardShape.strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func categoryRow(_ quality: MoveQuality) -> some View {
        let whiteCount = summary.white.count(of: quality)
        let blackCount = summary.black.count(of: quality)

        return HStack(spacing: 10) {
            countText(whiteCount)
                .frame(width: 44, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                MoveQualityBadgeView(quality: quality, squareSize: 52)
                Text(quality.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(whiteCount + blackCount > 0 ? quality.tint : Theme.textTertiary)
            }

            Spacer(minLength: 0)

            countText(blackCount)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(quality.label) : \(whiteCount) pour les Blancs, \(blackCount) pour les Noirs")
    }

    private func countText(_ count: Int) -> some View {
        Text("\(count)")
            .font(.body.bold().monospacedDigit())
            .foregroundStyle(count > 0 ? Theme.textPrimary : Theme.textTertiary.opacity(0.6))
    }

    private var incompleteNote: some View {
        HStack(spacing: 8) {
            ProgressView().tint(Theme.textSecondary).scaleEffect(0.7)
            Text("Analyse en cours — le bilan se complète au fil des coups classés.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
