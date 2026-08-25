import ChessKit
import Foundation

/// La couche de règles Chess960, PARTAGÉE par tous les modes (jouer contre
/// l'ordinateur, deux joueurs, laboratoire, analyse — décision du 25/08).
///
/// ## Le contrat avec ChessKit
///
/// ChessKit code le roque en dur (roi e1/e8, lettres KQkq) : impossible en
/// 960. Mais son parseur de FEN IGNORE les lettres Shredder sans échouer — on
/// lui confie donc la position avec des droits de roque VIDES : il valide et
/// joue tous les coups ordinaires (échecs, clouages, en passant, promotions,
/// horloge des 50 coups) et ne produira jamais un roque faux. Le roque, lui,
/// vit entièrement ici : droits par colonnes de tour, validation, exécution
/// par chirurgie de FEN, notation O-O/O-O-O.
///
/// ## Le garde-fou
///
/// Chaque règle de ce fichier est arbitrée par PERFT contre python-chess
/// (`Chess960RulesTests`, fixtures générées par
/// `tools/opening-generator/gen_chess960_fixtures.py`) : une génération de
/// coups fausse ne peut pas donner les bons comptes. Même discipline d'oracle
/// que la tablebase Syzygy pour les Finales.
///
/// - important: la reconstruction de plateau qu'exige un roque remet à zéro le
/// compteur de répétitions interne de ChessKit. La détection de nulle par
/// répétition d'une PARTIE complète devra donc vivre au niveau du view model
/// (lot 2), pas dans cette couche.
struct Chess960Game {

    /// Droits de roque d'UN camp : la colonne (0...7) de chaque tour d'origine,
    /// `nil` une fois le droit perdu. En 960 la colonne du roi et des tours
    /// est celle du départ, connue du FEN Shredder.
    struct ColorRights: Equatable {
        var kingSideRookFile: Int?
        var queenSideRookFile: Int?
        var isEmpty: Bool { kingSideRookFile == nil && queenSideRookFile == nil }
    }

    enum Move: Equatable, Hashable {
        case ordinary(from: Square, to: Square, promotion: Piece.Kind?)
        case castle(kingSide: Bool)
    }

    /// Plateau ChessKit — droits de roque TOUJOURS vides, voir l'en-tête.
    private(set) var board: Board
    private(set) var whiteRights: ColorRights
    private(set) var blackRights: ColorRights

    // MARK: Initialisation

    /// `fen` : FEN Shredder (droits en lettres de colonnes) ou classique
    /// (KQkq, accepté pour la position 518 et les FEN standards).
    init?(fen: String) {
        let fields = fen.split(separator: " ").map(String.init)
        guard fields.count >= 4 else { return nil }

        var rights = fields[2]
        // KQkq (X-FEN classique) → lettres de colonnes, via la position des
        // tours EXTÉRIEURES au roi sur la rangée de base.
        if rights != "-", rights.rangeOfCharacter(from: CharacterSet(charactersIn: "KQkq")) != nil {
            guard let translated = Self.translateClassicRights(rights, placement: fields[0]) else { return nil }
            rights = translated
        }

        var stripped = fields
        stripped[2] = "-"
        guard let position = Position(fen: stripped.joined(separator: " ")) else { return nil }
        board = Board(position: position)

        whiteRights = ColorRights()
        blackRights = ColorRights()
        if rights != "-" {
            guard let whiteKing = Self.kingFile(in: fields[0], white: true),
                  let blackKing = Self.kingFile(in: fields[0], white: false) else { return nil }
            for letter in rights {
                guard let value = letter.asciiValue else { return nil }
                if letter.isUppercase {
                    let file = Int(value - 65)
                    guard (0...7).contains(file) else { return nil }
                    if file > whiteKing { whiteRights.kingSideRookFile = file } else { whiteRights.queenSideRookFile = file }
                } else {
                    let file = Int(value - 97)
                    guard (0...7).contains(file) else { return nil }
                    if file > blackKing { blackRights.kingSideRookFile = file } else { blackRights.queenSideRookFile = file }
                }
            }
        }
    }

    /// Position de départ du numéro de Scharnagl `number`.
    init?(number: Int) {
        guard let fen = Chess960Position.startingFEN(number: number) else { return nil }
        self.init(fen: fen)
    }

    // MARK: FEN

    /// FEN Shredder complet — le dialecte du moteur sous `UCI_Chess960`.
    var shredderFEN: String {
        var fields = board.position.fen.split(separator: " ").map(String.init)
        var rights = ""
        if let f = whiteRights.kingSideRookFile { rights += fileLetter(f, upper: true) }
        if let f = whiteRights.queenSideRookFile { rights += fileLetter(f, upper: true) }
        if let f = blackRights.kingSideRookFile { rights += fileLetter(f, upper: false) }
        if let f = blackRights.queenSideRookFile { rights += fileLetter(f, upper: false) }
        while fields.count < 6 { fields.append(fields.count == 4 ? "0" : "1") }
        fields[2] = rights.isEmpty ? "-" : rights
        return fields.joined(separator: " ")
    }

    // MARK: Coups légaux

    func legalMoves() -> [Move] {
        var moves: [Move] = []
        let mover = board.position.sideToMove
        let lastRank = mover == .white ? "8" : "1"
        for piece in board.position.pieces where piece.color == mover {
            for destination in board.legalMoves(forPieceAt: piece.square) {
                if piece.kind == .pawn, destination.notation.hasSuffix(lastRank) {
                    for kind in [Piece.Kind.queen, .rook, .bishop, .knight] {
                        moves.append(.ordinary(from: piece.square, to: destination, promotion: kind))
                    }
                } else {
                    moves.append(.ordinary(from: piece.square, to: destination, promotion: nil))
                }
            }
        }
        if canCastle(kingSide: true) { moves.append(.castle(kingSide: true)) }
        if canCastle(kingSide: false) { moves.append(.castle(kingSide: false)) }
        return moves
    }

    // MARK: Application

    /// Joue `move` et rend son SAN (`nil` si le coup est illégal).
    @discardableResult
    mutating func apply(_ move: Move) -> String? {
        switch move {
        case let .ordinary(from, to, promotion):
            return applyOrdinary(from: from, to: to, promotion: promotion)
        case let .castle(kingSide):
            return applyCastle(kingSide: kingSide)
        }
    }

    /// Joue un coup en notation UCI **du dialecte `UCI_Chess960`** : le roque
    /// s'y écrit « le roi prend sa propre tour » (ex. `e1h1`) — c'est ce que
    /// rend Stockfish, et ce que python-chess écrit dans les fixtures.
    @discardableResult
    mutating func apply(uci: String) -> String? {
        guard uci.count >= 4,
              let from = Square(String(uci.prefix(2))) as Square?,
              let to = Square(String(uci.dropFirst(2).prefix(2))) as Square?
        else { return nil }

        let mover = board.position.sideToMove
        if let piece = board.position.piece(at: from), piece.kind == .king,
           let target = board.position.piece(at: to), target.kind == .rook, target.color == mover {
            let rights = mover == .white ? whiteRights : blackRights
            let toFile = fileIndex(of: to)
            if toFile == rights.kingSideRookFile { return apply(.castle(kingSide: true)) }
            if toFile == rights.queenSideRookFile { return apply(.castle(kingSide: false)) }
            return nil
        }

        var promotion: Piece.Kind?
        if uci.count == 5 {
            promotion = Piece.Kind(rawValue: String(uci.suffix(1)).uppercased())
            guard promotion != nil else { return nil }
        }
        return apply(.ordinary(from: from, to: to, promotion: promotion))
    }

    // MARK: État de partie

    /// Le camp au trait est-il en échec ? (La couche, pas ChessKit : son
    /// `Board.state` reste `.active` après tout init — voir `attacked`.)
    var isInCheck: Bool {
        let mover = board.position.sideToMove
        return isCheck(placement: String(board.position.fen.split(separator: " ")[0]), on: mover)
    }

    /// Compteur des 50 coups (demi-coups depuis pion ou prise), lu du FEN.
    var halfmoveClock: Int {
        let fields = board.position.fen.split(separator: " ")
        return fields.count > 4 ? Int(fields[4]) ?? 0 : 0
    }

    /// Clé de RÉPÉTITION : les quatre premiers champs du FEN Shredder —
    /// position, trait, droits, en passant. Le compteur vit dans le view
    /// model : la reconstruction qu'exige un roque remet à zéro celui de
    /// ChessKit (documenté en tête de fichier).
    var repetitionKey: String {
        shredderFEN.split(separator: " ").prefix(4).joined(separator: " ")
    }

    /// Fin de partie « sur l'échiquier » : mat, pat, matériel insuffisant,
    /// 50 coups. La répétition et le temps appartiennent au view model.
    enum BoardEnd: Equatable {
        case checkmate(winner: Piece.Color)
        case stalemate
        case insufficientMaterial
        case fiftyMoves
    }

    var boardEnd: BoardEnd? {
        let mover = board.position.sideToMove
        if legalMoves().isEmpty {
            return isInCheck ? .checkmate(winner: mover.opposite) : .stalemate
        }
        if board.position.hasInsufficientMaterial { return .insufficientMaterial }
        if halfmoveClock >= 100 { return .fiftyMoves }
        return nil
    }

    /// UCI (dialecte roi-prend-tour) d'un coup — surtout utile aux tests.
    func uciFor(_ move: Move) -> String {
        switch move {
        case let .ordinary(from, to, promotion):
            return from.notation + to.notation + (promotion.map { $0.rawValue.lowercased() } ?? "")
        case let .castle(kingSide):
            let mover = board.position.sideToMove
            let rights = mover == .white ? whiteRights : blackRights
            let rookFile = (kingSide ? rights.kingSideRookFile : rights.queenSideRookFile) ?? 0
            let king = board.position.pieces.first { $0.kind == .king && $0.color == mover }!.square
            return king.notation + fileLetter(rookFile, upper: false) + (mover == .white ? "1" : "8")
        }
    }

    // MARK: Perft

    /// Nombre de feuilles de l'arbre des coups légaux à `depth` demi-coups —
    /// l'instrument de la campagne d'oracle, pas une API de production.
    func perft(depth: Int) -> Int {
        guard depth > 0 else { return 1 }
        var total = 0
        for move in legalMoves() {
            var child = self
            guard child.apply(move) != nil else { continue }
            total += depth == 1 ? 1 : child.perft(depth: depth - 1)
        }
        return total
    }

    // MARK: - Coups ordinaires

    private mutating func applyOrdinary(from: Square, to: Square, promotion: Piece.Kind?) -> String? {
        let mover = board.position.sideToMove
        guard let piece = board.position.piece(at: from), piece.color == mover else { return nil }
        // Un roi qui « prend » sa tour est un roque, pas un coup ordinaire :
        // ChessKit le refuserait — et il ne doit passer QUE par `.castle`.
        guard board.canMove(pieceAt: from, to: to) else { return nil }

        let capturedFile = board.position.piece(at: to) != nil ? fileIndex(of: to) : nil
        var scratch = board
        guard var made = scratch.move(pieceAt: from, to: to) else { return nil }
        if case .promotion = scratch.state {
            made = scratch.completePromotion(of: made, to: promotion ?? .queen)
        } else if promotion != nil {
            return nil  // promotion demandée sur un coup qui n'en est pas une
        }
        board = scratch

        // Tenue des droits : roi bougé = tout perdu ; tour bougée depuis sa
        // colonne d'origine = ce côté perdu ; tour d'origine ADVERSE capturée
        // sur sa case de départ = ce côté adverse perdu.
        if piece.kind == .king {
            setRights(for: mover, ColorRights())
        } else if piece.kind == .rook, rankIndex(of: from) == backRank(of: mover) {
            clearRight(for: mover, file: fileIndex(of: from))
        }
        if let capturedFile, rankIndex(of: to) == backRank(of: mover.opposite) {
            clearRight(for: mover.opposite, file: capturedFile)
        }
        return made.san
    }

    // MARK: - Roque

    /// Règles FRC : droits intacts, trajets du roi ET de la tour libres (eux
    /// exceptés), roi jamais attaqué de sa case de départ à sa case d'arrivée
    /// incluses, et position finale légale. L'arbitre de ces règles est le
    /// perft contre python-chess, pas ce commentaire.
    private func canCastle(kingSide: Bool) -> Bool {
        let mover = board.position.sideToMove
        let rights = mover == .white ? whiteRights : blackRights
        guard let rookFile = kingSide ? rights.kingSideRookFile : rights.queenSideRookFile else { return false }

        let rank = backRank(of: mover)
        guard let kingSquare = board.position.pieces
            .first(where: { $0.kind == .king && $0.color == mover })?.square,
            rankIndex(of: kingSquare) == rank else { return false }
        let kingFile = fileIndex(of: kingSquare)

        let kingTarget = kingSide ? 6 : 2
        let rookTarget = kingSide ? 5 : 3

        // Trajets libres, roi et tour castlante exceptés.
        let travelled = Set([kingFile, rookFile])
        for file in path(kingFile, kingTarget) where !travelled.contains(file) {
            if pieceAt(file: file, rank: rank) != nil { return false }
        }
        for file in path(rookFile, rookTarget) where !travelled.contains(file) {
            if pieceAt(file: file, rank: rank) != nil { return false }
        }

        // Le roi ne traverse aucune case attaquée (départ et arrivée comprises).
        for file in path(kingFile, kingTarget) {
            if squareAttacked(kingFile: kingFile, testFile: file, rookFile: rookFile,
                              rookTarget: rookTarget, rank: rank, mover: mover) { return false }
        }

        // Position finale légale — attrape le cas propre au 960 où c'est le
        // DÉPART de la tour qui exposait le roi.
        guard let after = castledPlacement(kingFile: kingFile, kingTarget: kingTarget,
                                           rookFile: rookFile, rookTarget: rookTarget,
                                           rank: rank, mover: mover) else { return false }
        return !isCheck(placement: after, on: mover)
    }

    private mutating func applyCastle(kingSide: Bool) -> String? {
        guard canCastle(kingSide: kingSide) else { return nil }
        let mover = board.position.sideToMove
        let rights = mover == .white ? whiteRights : blackRights
        guard let rookFile = kingSide ? rights.kingSideRookFile : rights.queenSideRookFile,
              let kingSquare = board.position.pieces
                  .first(where: { $0.kind == .king && $0.color == mover })?.square
        else { return nil }

        let rank = backRank(of: mover)
        guard let placement = castledPlacement(
            kingFile: fileIndex(of: kingSquare), kingTarget: kingSide ? 6 : 2,
            rookFile: rookFile, rookTarget: kingSide ? 5 : 3, rank: rank, mover: mover
        ) else { return nil }

        var fields = board.position.fen.split(separator: " ").map(String.init)
        while fields.count < 6 { fields.append(fields.count == 4 ? "0" : "1") }
        fields[0] = placement
        fields[1] = mover.opposite.rawValue
        fields[3] = "-"                                   // pas d'en passant après un roque
        fields[4] = String((Int(fields[4]) ?? 0) + 1)     // ni pion ni prise
        if mover == .black { fields[5] = String((Int(fields[5]) ?? 1) + 1) }

        guard let position = Position(fen: fields.joined(separator: " ")) else { return nil }
        board = Board(position: position)
        setRights(for: mover, ColorRights())

        var san = kingSide ? "O-O" : "O-O-O"
        // `board.state` est toujours `.active` après un init : l'échec se
        // calcule ici, le mat en constatant l'absence de réponse légale.
        if isCheck(placement: placement, on: mover.opposite) {
            san += legalMoves().isEmpty ? "#" : "+"
        }
        return san
    }

    // MARK: - Lecture du FEN entrant

    /// Colonne (0...7) du roi `white` dans un champ de placement FEN.
    private static func kingFile(in placement: String, white: Bool) -> Int? {
        let target: Character = white ? "K" : "k"
        for row in placement.split(separator: "/") {
            var file = 0
            for ch in row {
                if let digit = ch.wholeNumberValue, (1...8).contains(digit) {
                    file += digit
                } else {
                    if ch == target { return file }
                    file += 1
                }
            }
        }
        return nil
    }

    /// KQkq → lettres de colonnes, en retrouvant les tours EXTRÊMES de chaque
    /// rangée de base — la seule lecture correcte d'un X-FEN classique.
    private static func translateClassicRights(_ rights: String, placement: String) -> String? {
        let rows = placement.split(separator: "/").map(String.init)
        guard rows.count == 8 else { return nil }
        func rookFiles(inRow row: String, white: Bool) -> [Int] {
            let rook: Character = white ? "R" : "r"
            var files: [Int] = []; var file = 0
            for ch in row {
                if let digit = ch.wholeNumberValue, (1...8).contains(digit) { file += digit } else {
                    if ch == rook { files.append(file) }
                    file += 1
                }
            }
            return files
        }
        let whiteRooks = rookFiles(inRow: rows[7], white: true)
        let blackRooks = rookFiles(inRow: rows[0], white: false)
        guard let whiteKing = kingFile(in: rows[7], white: true) ?? kingFile(in: placement, white: true),
              let blackKing = kingFile(in: rows[0], white: false) ?? kingFile(in: placement, white: false)
        else { return nil }

        var out = ""
        for letter in rights {
            switch letter {
            case "K":
                guard let file = whiteRooks.filter({ $0 > whiteKing }).max() else { return nil }
                out += String(Character(UnicodeScalar(UInt8(65 + file))))
            case "Q":
                guard let file = whiteRooks.filter({ $0 < whiteKing }).min() else { return nil }
                out += String(Character(UnicodeScalar(UInt8(65 + file))))
            case "k":
                guard let file = blackRooks.filter({ $0 > blackKing }).max() else { return nil }
                out += String(Character(UnicodeScalar(UInt8(97 + file))))
            case "q":
                guard let file = blackRooks.filter({ $0 < blackKing }).min() else { return nil }
                out += String(Character(UnicodeScalar(UInt8(97 + file))))
            default: return nil
            }
        }
        return out
    }

    // MARK: - Géométrie & chirurgie de FEN

    private func fileIndex(of square: Square) -> Int {
        Int(square.notation.unicodeScalars.first!.value) - 97
    }

    private func rankIndex(of square: Square) -> Int {
        Int(String(square.notation.dropFirst()))! - 1
    }

    private func backRank(of color: Piece.Color) -> Int { color == .white ? 0 : 7 }

    private func fileLetter(_ file: Int, upper: Bool) -> String {
        String(Character(UnicodeScalar(UInt8((upper ? 65 : 97) + file))))
    }

    private func path(_ from: Int, _ to: Int) -> [Int] {
        from <= to ? Array(from...to) : Array(to...from)
    }

    private func pieceAt(file: Int, rank: Int) -> Piece? {
        guard let square = Square("\(fileLetter(file, upper: false))\(rank + 1)") as Square? else { return nil }
        return board.position.piece(at: square)
    }

    private mutating func setRights(for color: Piece.Color, _ rights: ColorRights) {
        if color == .white { whiteRights = rights } else { blackRights = rights }
    }

    private mutating func clearRight(for color: Piece.Color, file: Int) {
        var rights = color == .white ? whiteRights : blackRights
        if rights.kingSideRookFile == file { rights.kingSideRookFile = nil }
        if rights.queenSideRookFile == file { rights.queenSideRookFile = nil }
        setRights(for: color, rights)
    }

    /// Rangée par rangée, chiffres dépliés en points — la seule forme sur
    /// laquelle une chirurgie de rangée soit lisible.
    private func expandedRows(of placement: String) -> [[Character]] {
        placement.split(separator: "/").map { row in
            row.flatMap { ch -> [Character] in
                if let digit = ch.wholeNumberValue, (1...8).contains(digit) {
                    return Array(repeating: ".", count: digit)
                }
                return [ch]
            }
        }
    }

    private func collapse(rows: [[Character]]) -> String {
        rows.map { row in
            var out = ""; var empty = 0
            for ch in row {
                if ch == "." { empty += 1 } else {
                    if empty > 0 { out += String(empty); empty = 0 }
                    out.append(ch)
                }
            }
            if empty > 0 { out += String(empty) }
            return out
        }.joined(separator: "/")
    }

    /// Placement après le roque : roi et tour retirés puis reposés.
    private func castledPlacement(
        kingFile: Int, kingTarget: Int, rookFile: Int, rookTarget: Int,
        rank: Int, mover: Piece.Color
    ) -> String? {
        let placement = String(board.position.fen.split(separator: " ")[0])
        var rows = expandedRows(of: placement)
        let rowIndex = 7 - rank                          // le FEN commence rangée 8
        guard rows.count == 8, rows[rowIndex].count == 8 else { return nil }
        rows[rowIndex][kingFile] = "."
        rows[rowIndex][rookFile] = "."
        rows[rowIndex][kingTarget] = mover == .white ? "K" : "k"
        rows[rowIndex][rookTarget] = mover == .white ? "R" : "r"
        return collapse(rows: rows)
    }

    /// La case (`testFile`, `rank`) est-elle attaquée par l'adversaire de
    /// `mover`, le roi étant réputé l'occuper ?
    ///
    /// Le roi est retiré de sa case d'origine (ce qui ouvre correctement les
    /// lignes derrière lui) ; si la case testée est occupée par la tour
    /// castlante, celle-ci est posée sur SA case d'arrivée — l'occupation la
    /// plus proche du coup réel.
    private func squareAttacked(
        kingFile: Int, testFile: Int, rookFile: Int, rookTarget: Int,
        rank: Int, mover: Piece.Color
    ) -> Bool {
        let placement = String(board.position.fen.split(separator: " ")[0])
        var rows = expandedRows(of: placement)
        let rowIndex = 7 - rank
        guard rows.count == 8, rows[rowIndex].count == 8 else { return true }
        rows[rowIndex][kingFile] = "."
        if testFile == rookFile {
            rows[rowIndex][rookFile] = "."
            if rookTarget != testFile, rows[rowIndex][rookTarget] == "." {
                rows[rowIndex][rookTarget] = mover == .white ? "R" : "r"
            }
        }
        return Self.attacked(rows, row: rowIndex, col: testFile, byWhite: mover == .black)
    }

    /// Détection d'attaque MAISON, sur les rangées dépliées.
    ///
    /// Elle existe parce que l'astuce d'API envisagée d'abord — poser le roi
    /// sur la case testée et lire `Board.state` — ne marche pas : `Board`
    /// rend `.active` À L'INIT même roi en échec, l'état n'est calculé
    /// qu'après un coup. Le perft de la campagne d'oracle a attrapé ce no-op
    /// silencieux (+40 nœuds sur la position 177 : un roque autorisé sous
    /// échec) ; c'est lui, et non ce commentaire, qui garantit ces lignes.
    ///
    /// Une pièce CLOUÉE attaque quand même — règle des échecs, pas un détail :
    /// c'est pour l'avoir qu'on n'utilise pas `legalMoves` de l'adversaire.
    static func attacked(_ rows: [[Character]], row: Int, col: Int, byWhite: Bool) -> Bool {
        func piece(_ r: Int, _ c: Int) -> Character? {
            guard (0..<8).contains(r), (0..<8).contains(c) else { return nil }
            let ch = rows[r][c]
            return ch == "." ? nil : ch
        }
        func enemy(_ ch: Character, _ kind: Character) -> Bool {
            byWhite ? ch == kind : ch == Character(kind.lowercased())
        }

        for (dr, dc) in [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)] {
            if let ch = piece(row + dr, col + dc), enemy(ch, "N") { return true }
        }
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                if let ch = piece(row + dr, col + dc), enemy(ch, "K") { return true }
            }
        }
        // rows[0] = 8e rangée : un pion BLANC attaque donc vers les indices
        // décroissants — il se trouve à row + 1 de sa cible.
        let pawnRow = byWhite ? row + 1 : row - 1
        for dc in [-1, 1] {
            if let ch = piece(pawnRow, col + dc), enemy(ch, "P") { return true }
        }
        for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            var r = row + dr, c = col + dc
            while (0..<8).contains(r), (0..<8).contains(c), rows[r][c] == "." {
                r += dr; c += dc
            }
            if let ch = piece(r, c), enemy(ch, "R") || enemy(ch, "Q") { return true }
        }
        for (dr, dc) in [(-1, -1), (-1, 1), (1, -1), (1, 1)] {
            var r = row + dr, c = col + dc
            while (0..<8).contains(r), (0..<8).contains(c), rows[r][c] == "." {
                r += dr; c += dc
            }
            if let ch = piece(r, c), enemy(ch, "B") || enemy(ch, "Q") { return true }
        }
        return false
    }

    /// Le roi de `color` est-il en échec dans `placement` ?
    private func isCheck(placement: String, on color: Piece.Color) -> Bool {
        let rows = expandedRows(of: placement)
        let king: Character = color == .white ? "K" : "k"
        for (r, rowChars) in rows.enumerated() {
            if let c = rowChars.firstIndex(of: king) {
                return Self.attacked(rows, row: r, col: c, byWhite: color == .black)
            }
        }
        return true  // pas de roi : position invalide, refuser
    }
}
