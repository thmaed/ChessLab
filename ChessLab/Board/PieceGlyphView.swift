import ChessKit
import SwiftUI

/// Représentation visuelle d'une pièce.
///
/// Pièces vectorielles (SVG dans `Assets.xcassets/Pieces`), rendues nettes à
/// toutes les tailles. Le JEU affiché suit ``AppSettings/pieceSet`` (défaut :
/// cburnett, CC BY-SA 3.0) ; ``overrideSet`` force un jeu précis pour l'aperçu
/// du sélecteur. Attributions dans ``LicensesView``.
struct PieceGlyphView: View {
    let piece: Piece
    /// Contour optionnel : une silhouette de cette couleur, légèrement
    /// agrandie derrière la pièce, la détache d'un fond peu contrasté.
    /// Utilisé pour les pièces NOIRES capturées, sinon invisibles sur le
    /// fond sombre du bandeau des prises.
    var outline: Color? = nil
    /// Force un jeu de pièces (aperçu du sélecteur) ; sinon suit le réglage.
    var overrideSet: PieceSet? = nil

    @State private var appSettings = AppSettings.shared

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
        let prefix = (overrideSet ?? appSettings.pieceSet).assetPrefix
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
        return "\(prefix)_\(color)\(kind)"
    }
}
