import ChessKit
import Observation
import SwiftUI

/// Éditeur graphique de position (étape 7 / Lot 1.A).
///
/// Modèle pur : aucune dépendance au moteur, aucun effet de bord. Il tient
/// une grille libre (n'importe quelle disposition de pièces, même illégale —
/// c'est le principe d'un éditeur), en génère le FEN, et délègue la
/// validation à ``FENValidator`` — l'unique autorité du projet sur « ce FEN
/// est-il envoyable au moteur ? ».
///
/// Sert deux écrans : l'éditeur autonome (``PositionEditorView``) et, plus
/// tard, l'écran de confirmation du scanner (Lot 1.D), qui l'instancie
/// pré-rempli via `init(fen:)`.
@Observable
@MainActor
final class PositionEditorViewModel {

    /// Outil actif de la palette : une pièce à poser, ou la gomme.
    enum Tool: Hashable {
        case piece(kind: Piece.Kind, color: Piece.Color)
        case eraser
    }

    /// Ordre d'affichage de la palette (le plus utilisé en dernier : le pion
    /// est la pièce qu'on pose le plus souvent, il reste sous le pouce).
    static let paletteKinds: [Piece.Kind] = [.king, .queen, .rook, .bishop, .knight, .pawn]

    // MARK: État

    /// Grille libre. La clé fait autorité : `pieces[sq]!.square == sq`.
    private(set) var pieces: [Square: Piece] = [:]

    /// Cases occupées dont le TYPE reste à préciser (lecture d'un plateau réel,
    /// Lot 1.E) : on connaît la couleur, pas la pièce.
    ///
    /// Volontairement HORS de `pieces` : une pièce sans type n'existe pas pour
    /// ChessKit, ne s'écrit pas en FEN, et ne doit surtout pas se retrouver
    /// dans une position envoyée au moteur. Elle vit donc à côté, et la
    /// position n'est valide que lorsque cette table est vide.
    private(set) var unknownPieces: [Square: Piece.Color] = [:]

    var sideToMove: Piece.Color = .white {
        didSet {
            // La case en passant dépend du trait (rangée 6 si les Blancs
            // jouent, 3 sinon) : un changement de trait la périme.
            pruneEnPassant()
            refresh()
        }
    }

    var whiteCanCastleKingside = false { didSet { refresh() } }
    var whiteCanCastleQueenside = false { didSet { refresh() } }
    var blackCanCastleKingside = false { didSet { refresh() } }
    var blackCanCastleQueenside = false { didSet { refresh() } }

    /// Colonne de la case en passant, `nil` = aucune. La rangée se déduit du
    /// trait, elle n'est donc jamais saisie.
    var enPassantFile: Square.File? { didSet { refresh() } }

    /// Couleur affichée en bas — confort d'affichage uniquement, sans effet
    /// sur le FEN produit.
    var orientation: Piece.Color = .white

    var selectedTool: Tool = .piece(kind: .pawn, color: .white)

    // MARK: Sorties (recalculées à chaque mutation, pas à chaque rendu)

    private(set) var fen = ""
    private(set) var errors: [String] = []

    var isValid: Bool { errors.isEmpty }

    // MARK: Cycle de vie

    /// - parameter fen: position de départ. `nil` → position standard.
    ///   Un FEN illisible retombe sur la position standard (l'éditeur ne
    ///   doit jamais s'ouvrir sur un plateau vide par accident).
    init(fen: String? = nil) {
        if let fen, load(fen: fen) { return }
        resetToStandard()
    }

    // MARK: Actions

    /// Applique l'outil actif à une case. Re-taper la même pièce avec le même
    /// outil l'efface : poser et retirer se font ainsi sans aller chercher la
    /// gomme.
    func apply(at square: Square) {
        // Une pièce sans type n'a rien à « re-taper pour effacer » : n'importe
        // quelle action la résout, en la remplaçant ou en la retirant.
        if unknownPieces[square] != nil {
            unknownPieces[square] = nil
            switch selectedTool {
            case .eraser:
                pieces[square] = nil
            case let .piece(kind, color):
                pieces[square] = Piece(kind, color: color, square: square)
            }
            boardDidChange()
            return
        }

        switch selectedTool {
        case .eraser:
            pieces[square] = nil
        case let .piece(kind, color):
            if let existing = pieces[square], existing.kind == kind, existing.color == color {
                pieces[square] = nil
            } else {
                pieces[square] = Piece(kind, color: color, square: square)
            }
        }
        boardDidChange()
    }

    func clearBoard() {
        pieces = [:]
        unknownPieces = [:]
        boardDidChange()
    }

    func resetToStandard() {
        pieces = Self.pieces(of: Position.standard)
        unknownPieces = [:]
        sideToMove = .white
        whiteCanCastleKingside = true
        whiteCanCastleQueenside = true
        blackCanCastleKingside = true
        blackCanCastleQueenside = true
        enPassantFile = nil
        refresh()
    }

    func flipOrientation() {
        orientation = orientation.opposite
    }

    // MARK: Complétion assistée des types (plateau réel, Lot 1.E)

    /// Cases sans type, dans l'ordre de lecture d'un échiquier : 8e rangée
    /// d'abord, de a à h. Ordre STABLE, sinon la case sélectionnée sauterait
    /// d'un bout à l'autre du plateau entre deux taps — l'utilisateur suit
    /// des yeux une progression, pas un dictionnaire.
    var unknownSquaresInOrder: [Square] {
        unknownPieces.keys.sorted { first, second in
            if first.rank.value != second.rank.value { return first.rank.value > second.rank.value }
            return first.file.number < second.file.number
        }
    }

    /// Case dont on attend le type. Dérivée, jamais stockée : assigner un type
    /// retire la case de la file, donc la suivante devient sélectionnée toute
    /// seule. Un état séparé se serait désynchronisé à la première correction
    /// manuelle.
    var selectedUnknownSquare: Square? { unknownSquaresInOrder.first }

    /// Couleur de la pièce à préciser — la palette n'affiche que celle-là :
    /// la couleur, elle, a bien été lue.
    var selectedUnknownColor: Piece.Color? {
        selectedUnknownSquare.flatMap { unknownPieces[$0] }
    }

    /// Assigne un type à la case en attente, et passe à la suivante.
    func assignKindToSelectedUnknown(_ kind: Piece.Kind) {
        guard let square = selectedUnknownSquare, let color = unknownPieces[square] else { return }
        unknownPieces[square] = nil
        pieces[square] = Piece(kind, color: color, square: square)
        boardDidChange()
    }

    /// Recharge l'éditeur depuis un FEN (écran de confirmation du scanner).
    /// - parameter unknownPieces: cases occupées dont le type reste à préciser.
    /// - returns: `false` si le FEN est illisible — l'état reste inchangé.
    @discardableResult
    func load(fen: String, unknownPieces: [Square: Piece.Color] = [:]) -> Bool {
        let trimmed = fen.trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = trimmed.split(separator: " ").map(String.init)
        guard fields.count == 6, let position = Position(fen: trimmed) else { return false }

        pieces = Self.pieces(of: position)
        self.unknownPieces = unknownPieces
        sideToMove = fields[1] == "b" ? .black : .white

        let castling = fields[2]
        whiteCanCastleKingside = castling.contains("K")
        whiteCanCastleQueenside = castling.contains("Q")
        blackCanCastleKingside = castling.contains("k")
        blackCanCastleQueenside = castling.contains("q")

        enPassantFile = fields[3].count == 2 ? Square(fields[3]).file : nil

        // Les champs relus peuvent être incohérents avec la grille (FEN
        // bricolé à la main, lecture d'un scanner) : on les élague comme une
        // mutation normale plutôt que de les propager tels quels.
        boardDidChange()
        return true
    }

    // MARK: Disponibilités (pilotent l'activation des contrôles)

    var isWhiteKingsideAvailable: Bool { hasKingAndRook(.white, king: "e1", rook: "h1") }
    var isWhiteQueensideAvailable: Bool { hasKingAndRook(.white, king: "e1", rook: "a1") }
    var isBlackKingsideAvailable: Bool { hasKingAndRook(.black, king: "e8", rook: "h8") }
    var isBlackQueensideAvailable: Bool { hasKingAndRook(.black, king: "e8", rook: "a8") }

    /// Rangée de la case en passant, imposée par le trait : les Blancs au
    /// trait ne peuvent capturer qu'un pion noir qui vient d'avancer de deux
    /// cases (case cible en 6e rangée), et réciproquement.
    var enPassantRank: Int { sideToMove == .white ? 6 : 3 }

    /// Colonnes où une case en passant est réellement plausible : le pion qui
    /// vient d'avancer de deux cases doit être là, et les deux cases qu'il a
    /// traversées doivent être libres.
    var availableEnPassantFiles: [Square.File] {
        let pawnRank = sideToMove == .white ? 5 : 4
        let originRank = sideToMove == .white ? 7 : 2
        let pawnColor = sideToMove.opposite

        return Square.File.allCases.filter { file in
            guard let pawn = pieces[Self.square(file, pawnRank)],
                  pawn.kind == .pawn, pawn.color == pawnColor else { return false }
            return pieces[Self.square(file, enPassantRank)] == nil
                && pieces[Self.square(file, originRank)] == nil
        }
    }

    // MARK: Interne

    /// Une mutation de la grille peut périmer les droits de roque et la case
    /// en passant : on les élague AVANT de régénérer le FEN, plutôt que de
    /// laisser le validateur crier pour une incohérence que l'utilisateur n'a
    /// pas provoquée (il a bougé une tour, pas décoché un roque).
    private func boardDidChange() {
        pruneCastlingRights()
        pruneEnPassant()
        refresh()
    }

    private func pruneCastlingRights() {
        if whiteCanCastleKingside, !isWhiteKingsideAvailable { whiteCanCastleKingside = false }
        if whiteCanCastleQueenside, !isWhiteQueensideAvailable { whiteCanCastleQueenside = false }
        if blackCanCastleKingside, !isBlackKingsideAvailable { blackCanCastleKingside = false }
        if blackCanCastleQueenside, !isBlackQueensideAvailable { blackCanCastleQueenside = false }
    }

    private func pruneEnPassant() {
        if let file = enPassantFile, !availableEnPassantFiles.contains(file) {
            enPassantFile = nil
        }
    }

    /// Les pièces sans type sont une erreur À PART ENTIÈRE, en tête : sans
    /// elles le FEN serait « valide » avec des pièces en moins, et
    /// l'utilisateur jouerait une position amputée sans le voir.
    private func refresh() {
        fen = generateFEN()

        var messages: [String] = []
        if !unknownPieces.isEmpty {
            let plural = unknownPieces.count > 1 ? "s" : ""
            messages.append("\(unknownPieces.count) pièce\(plural) sans type : précisez-la\(plural) pour continuer.")
        }
        errors = messages + FENValidator.errors(in: fen)
    }

    /// Génération des 6 champs. Compteurs figés à `0 1` : un éditeur ne
    /// connaît ni l'historique des demi-coups ni le numéro du coup, et le
    /// prompt ne les demande pas.
    private func generateFEN() -> String {
        var rows: [String] = []

        for rank in stride(from: 8, through: 1, by: -1) {
            var row = ""
            var emptyRun = 0

            for file in Square.File.allCases {
                if let piece = pieces[Self.square(file, rank)] {
                    if emptyRun > 0 {
                        row += "\(emptyRun)"
                        emptyRun = 0
                    }
                    row += Self.fenCharacter(for: piece)
                } else {
                    emptyRun += 1
                }
            }

            if emptyRun > 0 { row += "\(emptyRun)" }
            rows.append(row)
        }

        var castling = ""
        if whiteCanCastleKingside { castling += "K" }
        if whiteCanCastleQueenside { castling += "Q" }
        if blackCanCastleKingside { castling += "k" }
        if blackCanCastleQueenside { castling += "q" }
        if castling.isEmpty { castling = "-" }

        let enPassant = enPassantFile.map { "\($0.rawValue)\(enPassantRank)" } ?? "-"

        return "\(rows.joined(separator: "/")) \(sideToMove == .white ? "w" : "b") \(castling) \(enPassant) 0 1"
    }

    private func hasKingAndRook(_ color: Piece.Color, king: String, rook: String) -> Bool {
        let kingPiece = pieces[Square(king)]
        let rookPiece = pieces[Square(rook)]
        return kingPiece?.kind == .king && kingPiece?.color == color
            && rookPiece?.kind == .rook && rookPiece?.color == color
    }

    private static func pieces(of position: Position) -> [Square: Piece] {
        Dictionary(uniqueKeysWithValues: position.pieces.map { ($0.square, $0) })
    }

    /// `Square.init(_:_:)` (file, rank) n'est pas public dans ChessKit : on
    /// passe par la notation, seul chemin exposé.
    ///
    /// `nonisolated` : fonction pure, appelée aussi depuis le rendu bitmap
    /// du scanner (``BoardImageRenderer``), qui n'a aucune raison d'être sur
    /// le `MainActor`.
    nonisolated static func square(_ file: Square.File, _ rank: Int) -> Square {
        Square("\(file.rawValue)\(rank)")
    }

    /// Lettre FEN d'une pièce. `Piece.Kind.notation` renvoie `""` pour le
    /// pion (notation SAN) : inutilisable ici, d'où cette table dédiée.
    private static func fenCharacter(for piece: Piece) -> String {
        let letter: String
        switch piece.kind {
        case .pawn: letter = "P"
        case .knight: letter = "N"
        case .bishop: letter = "B"
        case .rook: letter = "R"
        case .queen: letter = "Q"
        case .king: letter = "K"
        }
        return piece.color == .white ? letter : letter.lowercased()
    }
}
