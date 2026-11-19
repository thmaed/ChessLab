import ChessKit
import Foundation

/// Retrouver un coup dans une phrase DITE (« Cavalier f3 », « fou prend c6 », « petit roque »).
///
/// Né de l'étude « jouer ses coups à la voix » (19/11/2026) : on ne cherche pas à comprendre n'importe quelle phrase,
/// on compare ce que la reconnaissance a entendu aux SEULS coups légaux de la position (une trentaine). Un « dé 2 » mal
/// entendu se résout tout seul quand un seul coup va en d2. Le module est pur (aucun micro, aucun moteur) : la mesure
/// sur appareil et les tests le font tourner sur les phrases réellement entendues.
///
/// Langue : le français d'abord (mesure du 19/11) ; les autres langues viendront si l'on implémente.
enum VoiceMoveParser {

    /// Un coup légal, tel que la position le donne : UCI (« g1f3 », « e7e8q ») et SAN brute (« Nf3 », « e8=Q+ »).
    struct Candidate: Hashable, Sendable, Codable {
        let uci: String
        let san: String

        var from: String { String(uci.prefix(2)) }
        var to: String { String(uci.dropFirst(2).prefix(2)) }
        var promotion: Character? { uci.count > 4 ? uci.last : nil }
        var isCastle: Bool { san.hasPrefix("O-O") }
        var isLongCastle: Bool { san.hasPrefix("O-O-O") }
        /// K, Q, R, B, N ou P.
        var piece: Character {
            if isCastle { return "K" }
            guard let first = san.first, "KQRBN".contains(first) else { return "P" }
            return first
        }
    }

    enum Outcome: Equatable, Sendable {
        case move(Candidate)
        /// Plusieurs coups répondent (deux cavaliers peuvent aller en d2) : il faut préciser le départ.
        case ambiguous([Candidate])
        /// On a entendu un coup, mais aucun coup légal ne lui répond.
        case illegal
        case notUnderstood
    }

    /// Ce qu'une phrase dit, avant de la confronter à la position.
    struct Heard: Equatable, Sendable {
        enum Castle: Equatable, Sendable { case short, long, unspecified }
        var piece: Character?
        /// Les cases entières entendues, dans l'ordre : la dernière est l'arrivée, l'avant-dernière le départ.
        var squares: [String] = []
        /// « cavalier b d2 », « tour 1 d1 » : une colonne ou une rangée de départ.
        var fromFile: Character?
        var fromRank: Character?
        var castle: Castle?
        var promotion: Character?
        var capture = false

        var isEmpty: Bool { piece == nil && squares.isEmpty && castle == nil }
    }

    // MARK: Le vocabulaire (français)

    private static let pieces: [String: Character] = [
        "roi": "K", "rois": "K",
        "dame": "Q", "dames": "Q", "reine": "Q", "reines": "Q",
        "tour": "R", "tours": "R",
        "fou": "B", "fous": "B",
        "cavalier": "N", "cavaliers": "N", "chevalier": "N", "chevaliers": "N",
        "pion": "P", "pions": "P",
    ]
    private static let captureWords: Set<String> = ["prend", "prends", "prent", "pren", "mange", "manges", "x", "prise"]
    private static let promotionWords: Set<String> = ["promotion", "promu", "promeut", "promouvoir"]

    /// Les lettres SÛRES : un mot qui ne peut guère être autre chose qu'une lettre de colonne.
    private static let strongFiles: [String: Character] = [
        "a": "a", "b": "b", "bé": "b", "c": "c", "cé": "c", "d": "d", "dé": "d", "e": "e", "é": "e",
        "f": "f", "effe": "f", "g": "g", "gé": "g", "h": "h", "ache": "h", "hache": "h",
    ]
    /// Les lettres DOUTEUSES : des mots courants qui sonnent comme une lettre ; comptées seulement juste avant
    /// un chiffre (« c'est 4 » = c4), jamais comme indice de départ.
    private static let weakFiles: [String: Character] = [
        "à": "a", "ah": "a", "ha": "a",
        "bey": "b", "baie": "b", "bée": "b",
        "ces": "c", "ses": "c", "c'est": "c", "s'est": "c", "sait": "c",
        "des": "d", "dès": "d", "dais": "d",
        "euh": "e", "eux": "e", "eu": "e", "et": "e", "est": "e",
        "ef": "f", "effet": "f",
        "j'ai": "g", "geai": "g", "jet": "g", "j": "g",
        "hash": "h", "hach": "h",
    ]
    private static let ranks: [String: Character] = [
        "1": "1", "un": "1", "une": "1",
        "2": "2", "deux": "2",
        "3": "3", "trois": "3",
        "4": "4", "quatre": "4",
        "5": "5", "cinq": "5",
        "6": "6", "six": "6",
        "7": "7", "sept": "7", "set": "7", "cette": "7",
        "8": "8", "huit": "8",
    ]

    // MARK: Lire une phrase

    static func tokens(_ text: String) -> [String] {
        var lowered = text.lowercased().replacingOccurrences(of: "’", with: "'")
        // « Cf3 », « Fxc6 » : une initiale de pièce collée à une case, comme on l'écrit.
        lowered = lowered.replacingOccurrences(
            of: #"\b([cftdr])x?([a-h][1-8])\b"#, with: "$1 $2", options: .regularExpression)
        // Une lettre collée à son chiffre (« f3 », « e4 ») : deux mots.
        lowered = lowered.replacingOccurrences(of: #"([a-h])([1-8])"#, with: "$1 $2", options: .regularExpression)
        let separators = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted
        return lowered.components(separatedBy: separators).filter { !$0.isEmpty }
    }

    static func heard(_ text: String) -> Heard {
        var result = Heard()
        let lowered = text.lowercased()
        if lowered.contains("grand roque") || lowered.contains("o-o-o") || lowered.contains("0-0-0") {
            result.castle = .long
        } else if lowered.contains("petit roque") || lowered.contains("o-o") || lowered.contains("0-0") {
            result.castle = .short
        } else if lowered.contains("roque") {
            result.castle = .unspecified
        }

        let words = tokens(text)
        // Les initiales écrites (« C f3 ») ne valent pièce que collées à une case.
        let writtenInitials: [String: Character] = ["c": "N", "f": "B", "t": "R", "d": "Q", "r": "K"]
        var index = 0
        var promotionNext = false
        while index < words.count {
            let word = words[index]
            let next = index + 1 < words.count ? words[index + 1] : nil
            let afterNext = index + 2 < words.count ? words[index + 2] : nil

            if let piece = pieces[word] {
                if promotionNext || !result.squares.isEmpty {
                    // « e8 dame », « e8 promotion dame » : la pièce après la case est la promotion.
                    if piece != "P" { result.promotion = piece }
                } else if result.piece == nil {
                    result.piece = piece
                }
                promotionNext = false
                index += 1
                continue
            }
            if captureWords.contains(word) { result.capture = true; index += 1; continue }
            if promotionWords.contains(word) { promotionNext = true; index += 1; continue }

            // Une initiale écrite suivie d'une case complète : « C f 3 ».
            if result.piece == nil, result.squares.isEmpty, let initial = writtenInitials[word],
               let next, strongFiles[next] != nil, let afterNext, ranks[afterNext] != nil {
                result.piece = initial
                index += 1
                continue
            }

            let file = strongFiles[word] ?? weakFiles[word]
            if let file, let next, let rank = ranks[next] {
                result.squares.append("\(file)\(rank)")
                index += 2
                continue
            }
            if let file = strongFiles[word] {
                // Une colonne seule, avant la case d'arrivée : l'indice de départ.
                if result.squares.isEmpty { result.fromFile = file }
                index += 1
                continue
            }
            if let rank = ranks[word], result.squares.isEmpty, result.piece != nil {
                result.fromRank = rank
            }
            index += 1
        }
        return result
    }

    // MARK: Confronter à la position

    static func resolve(_ heard: Heard, among candidates: [Candidate]) -> Outcome {
        if let castle = heard.castle, heard.squares.isEmpty {
            let castles = candidates.filter { candidate in
                guard candidate.isCastle else { return false }
                switch castle {
                case .short: return !candidate.isLongCastle
                case .long: return candidate.isLongCastle
                case .unspecified: return true
                }
            }
            return outcome(castles)
        }
        guard let destination = heard.squares.last else { return .notUnderstood }

        var pool = candidates.filter { $0.to == destination && !$0.isCastle }
        // Le roque dit par la case du roi (« roi g1 ») reste un roque.
        pool += candidates.filter { $0.isCastle && $0.to == destination && heard.piece == "K" }
        if heard.squares.count >= 2 {
            let start = heard.squares[heard.squares.count - 2]
            pool = pool.filter { $0.from == start }
        }
        if let piece = heard.piece {
            pool = pool.filter { $0.piece == piece }
        } else {
            // « e4 » : un pion, s'il en est un qui peut y aller ; sinon la seule pièce qui le peut.
            let pawns = pool.filter { $0.piece == "P" }
            if !pawns.isEmpty { pool = pawns }
        }
        if let file = heard.fromFile {
            let narrowed = pool.filter { $0.from.first == file }
            if !narrowed.isEmpty { pool = narrowed }
        }
        if let rank = heard.fromRank {
            let narrowed = pool.filter { $0.from.last == rank }
            if !narrowed.isEmpty { pool = narrowed }
        }
        if pool.count > 1, pool.allSatisfy({ $0.promotion != nil }) {
            // Promotion : la pièce dite, sinon la dame (la confirmation la nomme, on peut annuler).
            let wanted = Character((heard.promotion ?? "Q").lowercased())
            pool = pool.filter { $0.promotion == wanted }
        }
        return outcome(pool)
    }

    private static func outcome(_ pool: [Candidate]) -> Outcome {
        switch pool.count {
        case 0: .illegal
        case 1: .move(pool[0])
        default: .ambiguous(pool)
        }
    }

    /// Les lettres qui riment en « é » se confondent à l'oreille : b, c, d, e, g. Quand la case entendue ne donne
    /// rien, on essaie ses voisines ; on ne retient le résultat que s'il désigne UN seul coup.
    private static let confusable: Set<Character> = ["b", "c", "d", "e", "g"]

    static func resolveWithConfusions(_ heard: Heard, among candidates: [Candidate]) -> Outcome {
        let direct = resolve(heard, among: candidates)
        guard case .illegal = direct, let destination = heard.squares.last,
              let file = destination.first, confusable.contains(file) else { return direct }
        var found: [Candidate] = []
        for other in confusable where other != file {
            var variant = heard
            variant.squares[variant.squares.count - 1] = "\(other)\(destination.dropFirst())"
            if case let .move(move) = resolve(variant, among: candidates) { found.append(move) }
        }
        return found.count == 1 ? .move(found[0]) : direct
    }

    /// Plusieurs transcriptions d'un même enregistrement (la meilleure d'abord) : le premier coup trouvé l'emporte ;
    /// à défaut une ambiguïté, puis « impossible », puis « pas compris ».
    static func resolve(transcripts: [String], among candidates: [Candidate], confusions: Bool = true) -> Outcome {
        let outcomes = transcripts.map { text -> Outcome in
            let heard = heard(text)
            if heard.isEmpty { return .notUnderstood }
            return confusions ? resolveWithConfusions(heard, among: candidates) : resolve(heard, among: candidates)
        }
        if let move = outcomes.first(where: { if case .move = $0 { true } else { false } }) { return move }
        if let ambiguous = outcomes.first(where: { if case .ambiguous = $0 { true } else { false } }) { return ambiguous }
        if outcomes.contains(.illegal) { return .illegal }
        return .notUnderstood
    }

    // MARK: Ce qu'on s'attend à entendre

    private static let pieceWords: [Character: String] = [
        "K": "roi", "Q": "dame", "R": "tour", "B": "fou", "N": "cavalier", "P": "pion",
    ]

    /// Les façons courantes de dire un coup — indices pour la reconnaissance (`contextualStrings`).
    static func spokenForms(of candidate: Candidate) -> [String] {
        if candidate.isLongCastle { return ["grand roque"] }
        if candidate.isCastle { return ["petit roque"] }
        let to = candidate.to
        let name = pieceWords[candidate.piece] ?? ""
        var forms = ["\(name) \(to)", "\(name) en \(to)"]
        if candidate.san.contains("x") { forms.append("\(name) prend \(to)") }
        if candidate.piece == "P" { forms.append(to) }
        if let promotion = candidate.promotion, let promoted = pieceWords[Character(promotion.uppercased())] {
            forms.append("\(to) \(promoted)")
        }
        return forms
    }

    static func spokenForms(of candidates: [Candidate]) -> [String] {
        var seen = Set<String>()
        return candidates.flatMap { spokenForms(of: $0) }.filter { seen.insert($0).inserted }
    }
}

extension VoiceMoveParser {
    /// Les coups légaux de `board`, avec leur SAN (une promotion compte quatre coups : dame, tour, fou, cavalier).
    static func candidates(in board: Board) -> [Candidate] {
        let side = board.position.sideToMove
        var result: [Candidate] = []
        for piece in board.position.pieces where piece.color == side {
            for end in board.legalMoves(forPieceAt: piece.square) {
                let base = piece.square.notation + end.notation
                let promotes = piece.kind == .pawn && (end.rank.value == 8 || end.rank.value == 1)
                if promotes {
                    for kind in [Piece.Kind.queen, .rook, .bishop, .knight] {
                        var scratch = board
                        guard let move = scratch.move(pieceAt: piece.square, to: end) else { continue }
                        let promoted = scratch.completePromotion(of: move, to: kind)
                        result.append(Candidate(uci: base + kind.notation.lowercased(), san: promoted.san))
                    }
                } else {
                    var scratch = board
                    guard let move = scratch.move(pieceAt: piece.square, to: end) else { continue }
                    result.append(Candidate(uci: base, san: move.san))
                }
            }
        }
        return result
    }
}
