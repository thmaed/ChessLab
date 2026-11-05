import ChessKit
import Foundation

/// Écrit une collection de puzzles en PGN — la sauvegarde que le magasin local
/// ne fait pas, et le moyen de la passer à un autre appareil ou à un autre
/// logiciel. Pendant : `PuzzleCollectionExporter.kt`.
///
/// ## Le format
///
/// Une PARTIE par puzzle, que ``PuzzleCollectionImporter`` relit à l'identique :
/// - `[FEN]` : la position où le puzzle COMMENCE (celle d'après sa préparation) ;
/// - `[PuzzleSetup]` : le coup de préparation en LAN (`e7e5`), ou `-` s'il n'y
///   en a pas. C'est ce qui dit à l'importeur de ChessLab que le `[FEN]` est déjà
///   le départ du puzzle — sinon il prendrait le premier coup pour une
///   préparation, selon la convention de Lichess ;
/// - la ligne principale : la solution seule, en SAN.
///
/// Pourquoi ne pas écrire la position d'AVANT la préparation, comme Lichess ?
/// Parce qu'elle n'est pas gardée, et qu'elle ne se retrouve pas en défaisant le
/// coup (une prise, un droit de roque perdu). Un autre logiciel lit donc le
/// puzzle tel qu'il se pose — position et solution —, sans la préparation.
enum PuzzleCollectionExporter {
    struct Entry: Equatable {
        var fen: String
        var setupLAN: String?
        var solutionLANs: [String]
    }

    /// Le fichier d'une collection. Un puzzle dont la solution ne se rejoue pas
    /// (position illisible, coup illégal) est sauté : mieux vaut un fichier sans
    /// lui qu'un fichier que l'import refuserait en bloc.
    static func pgn(collection: String, entries: [Entry]) -> String {
        let event = collection
            .replacingOccurrences(of: "\"", with: "'")
            .components(separatedBy: .newlines).joined(separator: " ")
        var games: [String] = []
        for entry in entries {
            guard let movetext = movetext(for: entry) else { continue }
            games.append("""
            [Event "\(event)"]
            [SetUp "1"]
            [FEN "\(entry.fen)"]
            [PuzzleSetup "\(entry.setupLAN ?? "-")"]

            \(movetext)
            """)
        }
        return games.joined(separator: "\n\n") + (games.isEmpty ? "" : "\n")
    }

    /// Le nom du fichier proposé : celui de la collection, sans ce qu'un
    /// système de fichiers refuse.
    static func fileName(forCollection name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        let cleaned = name.components(separatedBy: forbidden).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned.isEmpty ? "ChessLab" : cleaned) + ".pgn"
    }

    // MARK: Une solution en SAN

    private static func movetext(for entry: Entry) -> String? {
        guard !entry.solutionLANs.isEmpty, let start = Position(fen: entry.fen) else { return nil }
        let fields = entry.fen.split(separator: " ")
        var fullmove = fields.count > 5 ? Int(fields[5]) ?? 1 : 1
        var whiteToMove = fields.count > 1 ? fields[1] == "w" : true

        var board = Board(position: start)
        var parts: [String] = []
        for (index, lan) in entry.solutionLANs.enumerated() {
            guard lan.count >= 4,
                  var move = board.move(pieceAt: Square(String(lan.prefix(2))), to: Square(String(lan.dropFirst(2).prefix(2))))
            else { return nil }
            if case .promotion = board.state {
                move = board.completePromotion(of: move, to: promotionKind(lan))
            }
            if whiteToMove {
                parts.append("\(fullmove). \(move.san)")
            } else {
                parts.append(index == 0 ? "\(fullmove)... \(move.san)" : move.san)
                fullmove += 1
            }
            whiteToMove.toggle()
        }
        return parts.joined(separator: " ") + " *"
    }

    private static func promotionKind(_ lan: String) -> Piece.Kind {
        switch lan.dropFirst(4).first?.lowercased() {
        case "n": return .knight
        case "b": return .bishop
        case "r": return .rook
        default: return .queen
        }
    }
}

extension PuzzleCollectionExporter.Entry {
    init(_ puzzle: Puzzle) {
        self.init(fen: puzzle.fen ?? "", setupLAN: puzzle.setupLAN, solutionLANs: puzzle.solutionLANs ?? [])
    }
}
