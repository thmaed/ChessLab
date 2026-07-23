import ChessKit
import SwiftUI

/// Plateau de l'éditeur : grille 8×8 tapable, sans aucune règle du jeu.
///
/// Volontairement distinct de ``ChessBoardView``, qui s'appuie sur un
/// `Board` ChessKit (coups légaux, dernier coup, échec, drag) : un éditeur
/// manipule des positions arbitraires, souvent illégales et parfois sans roi
/// — rien de tout cela n'a de sens ici. On ne partage que ce qui compte
/// vraiment : le thème (``BoardTheme``) et les glyphes (``PieceGlyphView``),
/// pour un rendu identique au reste de l'app.
struct PositionEditorBoardView: View {
    let pieces: [Square: Piece]
    let orientation: Piece.Color
    let theme: BoardTheme
    /// Cases mises en évidence : case en passant choisie, lectures peu sûres
    /// du scanner.
    var highlightedSquares: Set<Square> = []
    /// Pièces lues sur un plateau réel dont le type reste à préciser
    /// (Lot 1.E) : un disque à la couleur détectée, faute de mieux — dessiner
    /// une pièce arbitraire serait mentir sur ce qu'on a lu.
    var unknownPieces: [Square: Piece.Color] = [:]
    /// Case dont on attend le type — celle que vise la palette de complétion.
    var selectedSquare: Square?
    let onTapSquare: (Square) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { col in
                        squareCell(row: row, col: col)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private func squareCell(row: Int, col: Int) -> some View {
        let sq = square(row: row, col: col)

        return ZStack {
            Rectangle()
                .fill(sq.color == .light ? theme.lightSquare : theme.darkSquare)

            if highlightedSquares.contains(sq) {
                Rectangle().fill(theme.selectedColor)
            }

            if let piece = pieces[sq] {
                PieceGlyphView(piece: piece)
                    .padding(2)
            } else if let color = unknownPieces[sq] {
                unknownPieceMarker(color: color)
            }

            if sq == selectedSquare {
                Rectangle()
                    .strokeBorder(Theme.accent, lineWidth: 3)
            }

            coordinates(for: sq, row: row, col: col)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapSquare(sq) }
        // `children: .ignore` d'ABORD : sans lui, une case OCCUPÉE n'est pas
        // un élément unique (le glyphe et les coordonnées restent des
        // éléments à part) et `square_e2` devenait introuvable pour
        // XCUITest, alors que les cases vides, elles, répondaient — piège
        // vérifié par capture. ``ChessBoardView`` y échappe sans le savoir :
        // ses pièces vivent dans une COUCHE séparée de ses cases.
        // Pas de trait `.isButton` en revanche : les cases de
        // ``ChessBoardView`` n'en ont pas, et les tests UI du projet les
        // cherchent toutes dans `otherElements`.
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("square_\(sq.notation)")
        .accessibilityLabel(accessibilityLabel(for: sq))
    }

    /// Disque plein pour une pièce blanche, cerclé pour une noire — le même
    /// code visuel que ○/● sur un diagramme, lisible sans couleur.
    private func unknownPieceMarker(color: Piece.Color) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.55

            ZStack {
                Circle()
                    .fill(color == .white ? Color.white : Color.black)
                Circle()
                    .strokeBorder(color == .white ? Color.black.opacity(0.6) : Color.white.opacity(0.7), lineWidth: 1.5)
                Text("?")
                    .font(.system(size: side * 0.5, weight: .bold))
                    .foregroundStyle(color == .white ? Color.black.opacity(0.7) : Color.white.opacity(0.85))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func coordinates(for sq: Square, row: Int, col: Int) -> some View {
        GeometryReader { geo in
            let size = geo.size.width * 0.2

            ZStack {
                if col == 0 {
                    Text("\(sq.rank.value)")
                        .font(.system(size: size, weight: .semibold))
                        .foregroundStyle(theme.coordinateColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(2)
                }
                if row == 7 {
                    Text(sq.file.rawValue)
                        .font(.system(size: size, weight: .semibold))
                        .foregroundStyle(theme.coordinateColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(2)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Libellé explicite : sans lui, VoiceOver (et XCUITest) lirait la
    /// concaténation imprévisible des `Text` de coordonnées.
    private func accessibilityLabel(for sq: Square) -> String {
        if let piece = pieces[sq] { return "\(sq.notation), \(PieceNaming.french(piece))" }
        if let color = unknownPieces[sq] {
            return "\(sq.notation), pièce \(color == .white ? "blanche" : "noire") à préciser"
        }
        return "\(sq.notation), case vide"
    }

    private func square(row: Int, col: Int) -> Square {
        let files = Square.File.allCases
        if orientation == .white {
            return PositionEditorViewModel.square(files[col], 8 - row)
        } else {
            return PositionEditorViewModel.square(files[7 - col], row + 1)
        }
    }
}
