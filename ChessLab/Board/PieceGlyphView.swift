import ChessKit
import SwiftUI

/// Représentation visuelle d'une pièce.
///
/// Set vectoriel "cburnett" (licence CC BY-SA 3.0, Colin M.L. Burnett —
/// voir README pour l'attribution complète), embarqué en SVG dans
/// `Assets.xcassets/Pieces`. Rendu net à toutes les tailles.
struct PieceGlyphView: View {
    let piece: Piece
    /// Contour optionnel : une silhouette de cette couleur, légèrement
    /// agrandie derrière la pièce, la détache d'un fond peu contrasté.
    /// Utilisé pour les pièces NOIRES capturées, sinon invisibles sur le
    /// fond sombre du bandeau des prises.
    var outline: Color? = nil

    var body: some View {
        ZStack {
            if let outline {
                // Silhouette agrandie (contour net) + halo diffus de la même
                // couleur (visible même si le rendu template du SVG ne
                // produisait pas de silhouette pleine).
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(outline)
                    .scaleEffect(1.16)
                    .shadow(color: outline, radius: 1.2)
            }
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        .shadow(color: .black.opacity(0.35), radius: 1.5, x: 0, y: 1)
        .accessibilityHidden(true)
    }

    private var assetName: String {
        let color = piece.color == .white ? "w" : "b"
        let kind: String
        switch piece.kind {
        case .king: kind = "K"
        case .queen: kind = "Q"
        case .rook: kind = "R"
        case .bishop: kind = "B"
        case .knight: kind = "N"
        case .pawn: kind = "P"
        }
        return "piece_\(color)\(kind)"
    }
}
