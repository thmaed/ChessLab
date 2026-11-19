import ChessKit
import Foundation

/// Retrouver un coup dans une phrase DITE (« Cavalier f3 », « fou prend c6 », « petit roque »).
///
/// Né de l'étude « jouer ses coups à la voix » (19/11/2026) : on ne cherche pas à comprendre n'importe quelle phrase,
/// on compare ce que la reconnaissance a entendu aux SEULS coups légaux de la position (une trentaine). Un « dé 2 » mal
/// entendu se résout tout seul quand un seul coup va en d2. Le module est pur (aucun micro, aucun moteur) : la mesure
/// sur appareil et les tests le font tourner sur les phrases réellement entendues.
///
/// Les CINQ langues de l'app (décision du 19/11/2026) : un ``Vocabulary`` par langue. Le français a été mesuré sur
/// vraie voix (51 essais) et porte les mots appris de cette mesure ; les autres partent des mêmes règles.
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

    // MARK: Les vocabulaires

    /// Les mots d'une langue. Lettre « SÛRE » : un mot qui ne peut guère être autre chose qu'une colonne ; lettre
    /// « DOUTEUSE » : un mot courant qui sonne comme une lettre (« c'est », l'article « a » anglais, la préposition « a »
    /// espagnole ou italienne) — comptée seulement juste avant un chiffre, jamais comme indice de départ.
    struct Vocabulary: Sendable {
        let pieces: [String: Character]
        /// Des mots où la reconnaissance FOND une case (« géant » = g1) : redécoupés avant lecture.
        let fused: [String: [String]]
        let captureWords: Set<String>
        let promotionWords: Set<String>
        let strongFiles: [String: Character]
        let weakFiles: [String: Character]
        let ranks: [String: Character]
        /// Les initiales de la notation écrite dans cette langue (« C f3 », « Sf3 »).
        let writtenInitials: [String: Character]
        let shortCastle: [String]
        let longCastle: [String]
        let anyCastle: [String]
        /// « annule », « reprends » : reprendre son dernier coup.
        let undo: [String]
        /// Pour les indices donnés à la reconnaissance : le nom de chaque pièce, « en », « prend ».
        let pieceNames: [Character: String]
        let to: String
        let takes: String
        let shortCastleName: String
        let longCastleName: String
    }

    /// L'alphabet radio vaut dans toutes les langues : un filet pour les lettres difficiles (« Foxtrot 3 »).
    private static let radioAlphabet: [String: Character] = [
        "alpha": "a", "alfa": "a", "bravo": "b", "charlie": "c", "delta": "d", "echo": "e", "écho": "e",
        "foxtrot": "f", "golf": "g", "hotel": "h", "hôtel": "h",
    ]

    private static let digits: [String: Character] = [
        "1": "1", "2": "2", "3": "3", "4": "4", "5": "5", "6": "6", "7": "7", "8": "8",
    ]

    static let french = Vocabulary(
        pieces: [
            "roi": "K", "rois": "K", "dame": "Q", "dames": "Q", "reine": "Q", "reines": "Q",
            "tour": "R", "tours": "R", "fou": "B", "fous": "B",
            "cavalier": "N", "cavaliers": "N", "chevalier": "N", "chevaliers": "N", "pion": "P", "pions": "P",
            // Entendus le 19/11 (mesure sur iPhone3) : « Tout en cinq » pour « Tour en e5 », « Roy », « Rouen » (roi en).
            "tout": "R", "roy": "K", "rouen": "K",
        ],
        // Mesure du 19/11/2026, 51 essais : « en g1 » → « géant », « en d1 » → « indien », « en c1 » → « ancien »,
        // « en h6 » → « hachis », « d7 » → « décède », « 17 » (dix-sept), « b1 » → « bien un », « en g » → « Angers ».
        fused: [
            "géant": ["g", "1"], "indien": ["d", "1"], "indéen": ["d", "1"], "ancien": ["c", "1"], "hachis": ["h", "6"],
            "décède": ["d", "7"], "décès": ["d", "7"], "17": ["d", "7"], "18": ["d", "8"], "dix": ["d"], "10": ["d"],
            "bien": ["b"], "angers": ["g"], "of": ["f"], "off": ["f"],
        ],
        captureWords: ["prend", "prends", "prent", "pren", "mange", "manges", "x", "prise"],
        promotionWords: ["promotion", "promu", "promeut", "promouvoir"],
        strongFiles: [
            "a": "a", "b": "b", "bé": "b", "c": "c", "cé": "c", "d": "d", "dé": "d", "e": "e", "é": "e",
            "f": "f", "effe": "f", "g": "g", "gé": "g", "h": "h", "ache": "h", "hache": "h",
        ],
        weakFiles: [
            "à": "a", "ah": "a", "ha": "a", "bey": "b", "baie": "b", "bée": "b",
            "ces": "c", "ses": "c", "c'est": "c", "s'est": "c", "sait": "c", "des": "d", "dès": "d", "dais": "d",
            "euh": "e", "eux": "e", "eu": "e", "et": "e", "est": "e", "ef": "f", "effet": "f",
            "j'ai": "g", "geai": "g", "jet": "g", "j": "g", "hash": "h", "hach": "h",
        ],
        ranks: [
            "un": "1", "une": "1", "deux": "2", "trois": "3", "quatre": "4", "cinq": "5", "six": "6",
            "sept": "7", "set": "7", "cette": "7", "huit": "8",
        ],
        writtenInitials: ["c": "N", "f": "B", "t": "R", "d": "Q", "r": "K"],
        shortCastle: ["petit roque", "petit-roque"],
        longCastle: ["grand roque", "grand-roque"],
        anyCastle: ["roque"],
        undo: ["annule", "annuler", "annulé", "reprends", "reprendre", "reprend le coup", "retour"],
        pieceNames: ["K": "roi", "Q": "dame", "R": "tour", "B": "fou", "N": "cavalier", "P": "pion"],
        to: "en", takes: "prend", shortCastleName: "petit roque", longCastleName: "grand roque"
    )

    static let english = Vocabulary(
        pieces: [
            "king": "K", "kings": "K", "queen": "Q", "queens": "Q", "rook": "R", "rooks": "R",
            "bishop": "B", "bishops": "B", "knight": "N", "knights": "N", "night": "N", "nights": "N",
            "pawn": "P", "pawns": "P",
        ],
        fused: ["before": ["b", "4"]],
        captureWords: ["takes", "take", "captures", "capture", "x", "times"],
        promotionWords: ["promotes", "promote", "promotion", "equals"],
        strongFiles: [
            "b": "b", "bee": "b", "c": "c", "see": "c", "cee": "c", "d": "d", "dee": "d", "e": "e",
            "f": "f", "ef": "f", "g": "g", "gee": "g", "h": "h", "aitch": "h",
        ],
        weakFiles: ["a": "a", "ay": "a", "eh": "a", "be": "b", "sea": "c", "jee": "g", "age": "h"],
        ranks: [
            "one": "1", "won": "1", "two": "2", "to": "2", "too": "2", "three": "3", "tree": "3",
            "four": "4", "for": "4", "fore": "4", "five": "5", "six": "6", "seven": "7", "eight": "8", "ate": "8",
        ],
        writtenInitials: ["n": "N", "b": "B", "r": "R", "q": "Q", "k": "K"],
        shortCastle: ["castles kingside", "castle kingside", "kingside castle", "short castle", "castle short",
                      "castles short", "king side"],
        longCastle: ["castles queenside", "castle queenside", "queenside castle", "long castle", "castle long",
                     "castles long", "queen side"],
        anyCastle: ["castle", "castles", "castling"],
        undo: ["undo", "take back", "takeback", "take it back", "cancel"],
        pieceNames: ["K": "king", "Q": "queen", "R": "rook", "B": "bishop", "N": "knight", "P": "pawn"],
        to: "to", takes: "takes", shortCastleName: "castles kingside", longCastleName: "castles queenside"
    )

    static let spanish = Vocabulary(
        pieces: [
            "rey": "K", "reyes": "K", "dama": "Q", "damas": "Q", "reina": "Q", "torre": "R", "torres": "R",
            "alfil": "B", "alfiles": "B", "caballo": "N", "caballos": "N", "peón": "P", "peon": "P", "peones": "P",
        ],
        fused: [:],
        captureWords: ["come", "comes", "captura", "toma", "por", "x"],
        promotionWords: ["corona", "promociona", "promoción", "promocion"],
        strongFiles: [
            "b": "b", "c": "c", "d": "d", "e": "e", "f": "f", "efe": "f", "g": "g", "h": "h", "hache": "h", "ache": "h",
        ],
        weakFiles: ["a": "a", "ah": "a", "be": "b", "ve": "b", "ce": "c", "se": "c", "de": "d", "ge": "g", "je": "g"],
        ranks: [
            "uno": "1", "una": "1", "un": "1", "dos": "2", "tres": "3", "cuatro": "4", "cinco": "5", "seis": "6",
            "siete": "7", "ocho": "8",
        ],
        writtenInitials: ["c": "N", "a": "B", "t": "R", "d": "Q", "r": "K"],
        shortCastle: ["enroque corto"],
        longCastle: ["enroque largo"],
        anyCastle: ["enroque", "enroca"],
        undo: ["deshacer", "deshaz", "anula", "anular", "atrás", "atras"],
        pieceNames: ["K": "rey", "Q": "dama", "R": "torre", "B": "alfil", "N": "caballo", "P": "peón"],
        to: "a", takes: "come", shortCastleName: "enroque corto", longCastleName: "enroque largo"
    )

    static let german = Vocabulary(
        pieces: [
            "könig": "K", "koenig": "K", "dame": "Q", "turm": "R", "türme": "R", "läufer": "B", "laeufer": "B",
            "springer": "N", "pferd": "N", "bauer": "P", "bauern": "P",
        ],
        fused: [:],
        captureWords: ["schlägt", "schlaegt", "nimmt", "x", "mal"],
        promotionWords: ["umwandlung", "wandelt", "verwandelt"],
        strongFiles: [
            "a": "a", "b": "b", "be": "b", "c": "c", "ce": "c", "zeh": "c", "d": "d", "de": "d", "e": "e",
            "f": "f", "ef": "f", "g": "g", "ge": "g", "h": "h", "ha": "h",
        ],
        weakFiles: ["beh": "b", "tse": "c", "dee": "d", "eh": "e", "eff": "f", "geh": "g", "hah": "h"],
        ranks: [
            "eins": "1", "ein": "1", "zwei": "2", "zwo": "2", "drei": "3", "vier": "4", "fünf": "5", "fuenf": "5",
            "sechs": "6", "sieben": "7", "acht": "8",
        ],
        writtenInitials: ["s": "N", "l": "B", "t": "R", "d": "Q", "k": "K"],
        shortCastle: ["kurze rochade", "rochade kurz", "kleine rochade"],
        longCastle: ["lange rochade", "rochade lang", "große rochade", "grosse rochade"],
        anyCastle: ["rochade", "rochiert"],
        undo: ["zurück", "zurueck", "rückgängig", "rueckgaengig", "nimm zurück", "abbrechen"],
        pieceNames: ["K": "König", "Q": "Dame", "R": "Turm", "B": "Läufer", "N": "Springer", "P": "Bauer"],
        to: "nach", takes: "schlägt", shortCastleName: "kurze Rochade", longCastleName: "lange Rochade"
    )

    static let italian = Vocabulary(
        pieces: [
            "re": "K", "donna": "Q", "regina": "Q", "torre": "R", "torri": "R", "alfiere": "B", "alfieri": "B",
            "cavallo": "N", "cavalli": "N", "pedone": "P", "pedoni": "P",
        ],
        fused: [:],
        captureWords: ["prende", "mangia", "cattura", "per", "x"],
        promotionWords: ["promozione", "promuove"],
        strongFiles: [
            "b": "b", "bi": "b", "c": "c", "d": "d", "f": "f", "effe": "f", "g": "g", "gi": "g", "h": "h", "acca": "h",
        ],
        weakFiles: ["a": "a", "ci": "c", "di": "d", "e": "e", "è": "e"],
        ranks: [
            "uno": "1", "un": "1", "due": "2", "tre": "3", "quattro": "4", "cinque": "5", "sei": "6",
            "sette": "7", "otto": "8",
        ],
        writtenInitials: ["c": "N", "a": "B", "t": "R", "d": "Q", "r": "K"],
        shortCastle: ["arrocco corto"],
        longCastle: ["arrocco lungo"],
        anyCastle: ["arrocco", "arrocca"],
        undo: ["annulla", "indietro", "riprendi"],
        pieceNames: ["K": "re", "Q": "donna", "R": "torre", "B": "alfiere", "N": "cavallo", "P": "pedone"],
        to: "in", takes: "prende", shortCastleName: "arrocco corto", longCastleName: "arrocco lungo"
    )

    /// Le vocabulaire d'une langue de l'app (« fr », « en »…) ; le français par défaut.
    static func vocabulary(for language: String) -> Vocabulary {
        switch language.prefix(2) {
        case "en": english
        case "es": spanish
        case "de": german
        case "it": italian
        default: french
        }
    }

    // MARK: Lire une phrase

    static func tokens(_ text: String, vocabulary: Vocabulary = french) -> [String] {
        var lowered = text.lowercased().replacingOccurrences(of: "’", with: "'")
        // « Cf3 », « Fxc6 », « Sf3 » : une initiale de pièce collée à une case, comme on l'écrit.
        let initials = String(vocabulary.writtenInitials.keys.sorted().joined())
        lowered = lowered.replacingOccurrences(
            of: "\\b([\(initials)])x?([a-h][1-8])\\b", with: "$1 $2", options: .regularExpression)
        // Une lettre collée à son chiffre (« f3 », « e4 ») : deux mots.
        lowered = lowered.replacingOccurrences(of: #"([a-h])([1-8])"#, with: "$1 $2", options: .regularExpression)
        let separators = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted
        return lowered.components(separatedBy: separators).filter { !$0.isEmpty }
            .flatMap { vocabulary.fused[$0] ?? [$0] }
    }

    /// « annule », « take back » : une demande de reprise, sans case dedans.
    static func isUndo(_ text: String, vocabulary: Vocabulary = french) -> Bool {
        let lowered = " " + tokens(text, vocabulary: vocabulary).joined(separator: " ") + " "
        return vocabulary.undo.contains { lowered.contains(" \($0) ") }
    }

    static func heard(_ text: String, vocabulary: Vocabulary = french) -> Heard {
        var result = Heard()
        let words = tokens(text, vocabulary: vocabulary)
        let spaced = " " + words.joined(separator: " ") + " "
        let raw = text.lowercased()
        func says(_ phrases: [String]) -> Bool { phrases.contains { spaced.contains(" \($0) ") } }
        if says(vocabulary.longCastle) || raw.contains("o-o-o") || raw.contains("0-0-0") {
            result.castle = .long
        } else if says(vocabulary.shortCastle) || raw.contains("o-o") || raw.contains("0-0") {
            result.castle = .short
        } else if says(vocabulary.anyCastle) {
            result.castle = .unspecified
        }

        func strongFile(_ word: String) -> Character? { vocabulary.strongFiles[word] ?? radioAlphabet[word] }
        func rank(_ word: String) -> Character? { vocabulary.ranks[word] ?? digits[word] }

        var index = 0
        var promotionNext = false
        while index < words.count {
            let word = words[index]
            let next = index + 1 < words.count ? words[index + 1] : nil
            let afterNext = index + 2 < words.count ? words[index + 2] : nil

            if let piece = vocabulary.pieces[word] {
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
            if vocabulary.captureWords.contains(word) { result.capture = true; index += 1; continue }
            if vocabulary.promotionWords.contains(word) { promotionNext = true; index += 1; continue }

            // Initiale et colonne collées, puis le chiffre : « FB quatre » = fou b4 (entendu le 19/11).
            if result.piece == nil, result.squares.isEmpty, word.count == 2,
               let initial = vocabulary.writtenInitials[String(word.prefix(1))], let file = word.last,
               "abcdefgh".contains(file), let next, let rank = rank(next) {
                result.piece = initial
                result.squares.append("\(file)\(rank)")
                index += 2
                continue
            }
            // Une initiale écrite suivie d'une case complète : « C f 3 ».
            if result.piece == nil, result.squares.isEmpty, let initial = vocabulary.writtenInitials[word],
               let next, strongFile(next) != nil, let afterNext, rank(afterNext) != nil {
                result.piece = initial
                index += 1
                continue
            }

            let file = strongFile(word) ?? vocabulary.weakFiles[word]
            if let file, let next, let rank = rank(next) {
                result.squares.append("\(file)\(rank)")
                index += 2
                continue
            }
            if let file = strongFile(word) {
                // Une colonne seule, avant la case d'arrivée : l'indice de départ.
                if result.squares.isEmpty { result.fromFile = file }
                index += 1
                continue
            }
            // Une rangée seule : l'indice de départ (« tour 1 d1 »), ou l'arrivée quand la colonne s'est perdue. Pas
            // devant une colonne : « knight to f3 », où « to » sonne comme « two ».
            let beforeFile = next.map { strongFile($0) != nil || vocabulary.weakFiles[$0] != nil } ?? false
            if let rank = rank(word), result.squares.isEmpty, result.piece != nil, !beforeFile {
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
        guard let destination = heard.squares.last else {
            // La colonne s'est perdue (« Roi deux », « Dame en huit », « Tour cinq » — un tiers des ratés du 19/11) :
            // la pièce et la rangée suffisent si UN seul coup y répond ; sinon on demande de répéter.
            guard let piece = heard.piece, let rank = heard.fromRank else { return .notUnderstood }
            let pool = candidates.filter { !$0.isCastle && $0.piece == piece && $0.to.last == rank }
            return pool.isEmpty ? .notUnderstood : outcome(pool)
        }

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
            // Promotion : la pièce dite, sinon la dame.
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

    /// Les lettres qui riment se confondent à l'oreille : b, c, d, e, g (en « é » en français, en « i » en anglais).
    /// Quand la case entendue ne donne rien, on essaie ses voisines ; on ne retient le résultat que s'il désigne UN
    /// seul coup.
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
    static func resolve(transcripts: [String], among candidates: [Candidate], confusions: Bool = true,
                        vocabulary: Vocabulary = french) -> Outcome {
        let outcomes = transcripts.map { text -> Outcome in
            let heard = heard(text, vocabulary: vocabulary)
            if heard.isEmpty { return .notUnderstood }
            return confusions ? resolveWithConfusions(heard, among: candidates) : resolve(heard, among: candidates)
        }
        if let move = outcomes.first(where: { if case .move = $0 { true } else { false } }) { return move }
        if let ambiguous = outcomes.first(where: { if case .ambiguous = $0 { true } else { false } }) { return ambiguous }
        if outcomes.contains(.illegal) { return .illegal }
        return .notUnderstood
    }

    /// Une phrase sans rien d'échecs dedans (une conversation autour de la table) : l'écoute permanente l'ignore,
    /// au lieu de répondre « pas compris » à chaque mot prononcé dans la pièce.
    static func soundsLikeChess(_ transcripts: [String], vocabulary: Vocabulary = french) -> Bool {
        transcripts.contains { !heard($0, vocabulary: vocabulary).isEmpty || isUndo($0, vocabulary: vocabulary) }
    }

    // MARK: Ce qu'on s'attend à entendre

    /// Les façons courantes de dire un coup — indices pour la reconnaissance (`contextualStrings`).
    static func spokenForms(of candidate: Candidate, vocabulary: Vocabulary = french) -> [String] {
        if candidate.isLongCastle { return [vocabulary.longCastleName] }
        if candidate.isCastle { return [vocabulary.shortCastleName] }
        let to = candidate.to
        let name = vocabulary.pieceNames[candidate.piece] ?? ""
        var forms = ["\(name) \(to)", "\(name) \(vocabulary.to) \(to)"]
        if candidate.san.contains("x") { forms.append("\(name) \(vocabulary.takes) \(to)") }
        if candidate.piece == "P" { forms.append(to) }
        if let promotion = candidate.promotion, let promoted = vocabulary.pieceNames[Character(promotion.uppercased())] {
            forms.append("\(to) \(promoted)")
        }
        return forms
    }

    static func spokenForms(of candidates: [Candidate], vocabulary: Vocabulary = french) -> [String] {
        var seen = Set<String>()
        return candidates.flatMap { spokenForms(of: $0, vocabulary: vocabulary) }.filter { seen.insert($0).inserted }
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
