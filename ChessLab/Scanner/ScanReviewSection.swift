import ChessKit
import CoreGraphics
import SwiftUI

/// La revue des cases douteuses du scanner : UNE case à la fois, avec la
/// vignette de l'image d'origine à côté de ce qui a été lu.
///
/// Sans elle, l'utilisateur voit une case surlignée sur le plateau et doit aller
/// chercher l'image source de son côté pour savoir qui a raison. Ici, la
/// vignette et la lecture sont côte à côte, et la bonne réponse se choisit d'un
/// tap : la lecture gardée, la deuxième hypothèse du détecteur, ou « case vide ».
struct ScanReviewSection: View {
    /// La case en cours de revue, et sa lecture.
    let square: Square
    let reading: SquareReading
    /// Sa vignette dans l'image d'origine, `nil` si l'image n'est plus là.
    let image: CGImage?
    /// Combien de cases restent à vérifier (celle-ci comprise), et quelle place elle y tient.
    let remaining: Int
    let position: Int
    let onChoose: ((kind: Piece.Kind, color: Piece.Color)?) -> Void
    let onKeep: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        SettingsSection(title: "Cases à vérifier", systemImage: "magnifyingglass.circle.fill", tint: Theme.warning) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Case \(square.notation) — \(position) sur \(remaining)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Lu : \(Text(verbatim: readName))")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    navigation
                }

                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ChipButton(label: keepLabel, systemImage: "checkmark", isSelected: false, action: onKeep)
                        .accessibilityIdentifier("scanReviewKeep")

                    ForEach(reading.alternatives, id: \.self) { choice in
                        ChipButton(
                            label: LocalizedStringKey(PieceNaming.french(choice.kind, color: choice.color)),
                            systemImage: nil, isSelected: false
                        ) { onChoose((choice.kind, choice.color)) }
                        .accessibilityIdentifier("scanReviewChoice_\(String(describing: choice.color))_\(String(describing: choice.kind))")
                    }

                    if !reading.occupancy.isEmpty {
                        ChipButton(label: "Case vide", systemImage: "square.dashed", isSelected: false) { onChoose(nil) }
                            .accessibilityIdentifier("scanReviewEmpty")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("scanReviewSection")
    }

    private var keepLabel: LocalizedStringKey {
        reading.occupancy.isEmpty ? "Vide, c'est bon" : "C'est bien ça"
    }

    private var readName: String {
        switch reading.occupancy {
        case .empty: LocalizationController.string("case vide")
        case let .piece(color, kind?): PieceNaming.french(kind, color: color)
        case let .piece(color, nil): color == .white ? LocalizationController.string("pièce blanche") : LocalizationController.string("pièce noire")
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var navigation: some View {
        if remaining > 1 {
            HStack(spacing: 6) {
                Button(action: onPrevious) { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Case précédente")
                    .accessibilityIdentifier("scanReviewPrevious")
                Button(action: onNext) { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Case suivante")
                    .accessibilityIdentifier("scanReviewNext")
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.accent)
        }
    }
}
