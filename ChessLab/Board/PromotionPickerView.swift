import ChessKit
import SwiftUI

/// Fenêtre de choix de la pièce de promotion (Dame, Tour, Fou, Cavalier).
struct PromotionPickerView: View {
    let color: Piece.Color
    let onSelect: (Piece.Kind) -> Void

    private let choices: [(kind: Piece.Kind, label: String)] = [
        (.queen, "Dame"), (.rook, "Tour"), (.bishop, "Fou"), (.knight, "Cavalier"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Promotion")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 12) {
                ForEach(choices, id: \.kind) { choice in
                    Button {
                        onSelect(choice.kind)
                    } label: {
                        VStack(spacing: 6) {
                            PieceGlyphView(piece: Piece(choice.kind, color: color, square: .a1))
                                .frame(width: 56, height: 56)
                            Text(choice.label)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(10)
                        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(choice.label)
                }
            }
        }
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16)
    }
}
