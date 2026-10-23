import ChessKit
import Foundation

/// Un mat forcé que le camp au trait tenait, et que le coup joué a laissé
/// filer — candidat à un puzzle « Mat » de vos parties. Trouvé par
/// `AnalysisViewModel.findMissedMates()`.
struct MissedMate: Identifiable, Equatable {
    let id = UUID()
    /// Position d'avant le coup joué : c'est au camp qui y a le trait de
    /// retrouver le mat.
    let fen: String
    let playedMoveSAN: String
    /// La ligne COMPLÈTE jusqu'au mat, en LAN, coups du résolveur et
    /// ripostes alternés — jamais tronquée (voir ``MissedMateDetector``).
    let solutionLANs: [String]
    let mateIn: Int
    let mover: Piece.Color
    /// Numéro du coup dans la partie, pour le dire à l'utilisateur.
    let moveNumber: Int
}

/// Les règles pures de la recherche des mats manqués — sans moteur, donc
/// vérifiables en test.
///
/// Pourquoi PAS ``PuzzleSolutionTrimmer`` : il plafonne une solution à six
/// demi-coups et la coupe dès qu'un gain de matériel est acquis. Un mat en
/// trois avec sacrifice aurait été coupé AVANT le mat — le puzzle aurait
/// demandé de gagner du matériel, pas de mater.
enum MissedMateDetector {
    /// Au-delà, la ligne d'un mat se calcule mal de tête et le moteur la
    /// trouve mal en budget mobile : on ne propose que des mats en 5 au plus.
    static let maxMateMoves = 5

    /// Seuil de présélection, en probabilité de gain du camp au trait (POV
    /// trait, 0…100). Environ +9,5 : tout mat court trouvé par la
    /// classification y est (un mat vaut ~100 %), et la recherche dédiée,
    /// plus chère, n'est lancée que sur ces positions.
    static let candidateWinPercent = 97.0

    static func mightHoldMate(winPercentForMover: Double) -> Bool {
        winPercentForMover >= candidateWinPercent
    }

    /// La ligne jusqu'au mat, si la variante du moteur y mène bien : rejouée
    /// coup par coup depuis `startFEN` et coupée au premier mat. `nil` si la
    /// variante est illégale, n'aboutit pas au mat, ou dépasse
    /// ``maxMateMoves`` coups du résolveur.
    static func solution(pv: [String], startFEN: String) -> [String]? {
        guard let start = Position(fen: startFEN) else { return nil }
        var board = Board(position: start)
        var line: [String] = []
        for lan in pv.prefix(2 * maxMateMoves - 1) {
            guard lan.count >= 4 else { return nil }
            let from = Square(String(lan.prefix(2)))
            let to = Square(String(lan.dropFirst(2).prefix(2)))
            // ChessKit ne consulte pas le trait : on le vérifie ici.
            guard board.position.piece(at: from)?.color == board.position.sideToMove,
                  board.canMove(pieceAt: from, to: to),
                  let move = board.move(pieceAt: from, to: to) else { return nil }
            if case .promotion = board.state {
                let kind = lan.count == 5
                    ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen)
                    : .queen
                _ = board.completePromotion(of: move, to: kind)
            }
            line.append(lan)
            if case .checkmate = board.state { return line }
        }
        return nil
    }

    /// Numéro de coup lu dans le FEN (6e champ), 1 à défaut.
    static func moveNumber(fen: String) -> Int {
        let fields = fen.split(separator: " ")
        return fields.count >= 6 ? Int(fields[5]) ?? 1 : 1
    }
}
