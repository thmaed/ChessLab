import Foundation

/// Commande UCI envoyée au moteur. Ne couvre QUE ce dont l'app se sert — le
/// sous-ensemble consommé par ``EngineController`` — avec des valeurs
/// associées optionnelles par défaut pour que `.go(depth:)`, `.go(nodes:)` et
/// `.go(nodes:movetime:)` coexistent sur un seul cas.
public enum EngineCommand: Equatable, Sendable {
    case uci
    case isready
    case ucinewgame
    case stop
    case quit
    case setoption(id: String, value: String)
    case position(Position)
    // Ordre des labels aligné sur les appels de l'app : `.go(nodes:movetime:)`.
    case go(depth: Int? = nil, nodes: Int? = nil, movetime: Int? = nil)

    /// Argument de `position` (l'app ne se sert que du FEN, mais `startpos`
    /// reste utile et sans coût).
    public enum Position: Equatable, Sendable {
        case fen(String)
        case startpos
    }

    /// Texte UCI (sans saut de ligne final).
    public var uciString: String {
        switch self {
        case .uci: return "uci"
        case .isready: return "isready"
        case .ucinewgame: return "ucinewgame"
        case .stop: return "stop"
        case .quit: return "quit"
        case let .setoption(id, value):
            return "setoption name \(id) value \(value)"
        case let .position(position):
            switch position {
            case let .fen(fen): return "position fen \(fen)"
            case .startpos: return "position startpos"
            }
        case let .go(depth, nodes, movetime):
            var parts = ["go"]
            if let depth { parts.append("depth \(depth)") }
            if let nodes { parts.append("nodes \(nodes)") }
            if let movetime { parts.append("movetime \(movetime)") }
            return parts.joined(separator: " ")
        }
    }
}

/// Réponse UCI parsée. Ne modélise que ce que l'app lit : `info`, `bestmove`,
/// `readyok`. Les autres lignes (id, option, uciok…) rendent `nil`.
public enum EngineResponse: Equatable, Sendable {
    case info(Info)
    case bestmove(move: String, ponder: String?)
    case readyok

    /// Champs d'une ligne `info` utilisés par l'app.
    public struct Info: Equatable, Sendable {
        public var depth: Int?
        public var seldepth: Int?
        public var multipv: Int?
        public var nodes: Int?
        public var time: Int?
        public var pv: [String]?
        public var score: Score?

        public init(depth: Int? = nil, seldepth: Int? = nil, multipv: Int? = nil,
                    nodes: Int? = nil, time: Int? = nil, pv: [String]? = nil, score: Score? = nil) {
            self.depth = depth
            self.seldepth = seldepth
            self.multipv = multipv
            self.nodes = nodes
            self.time = time
            self.pv = pv
            self.score = score
        }

        /// Score d'une ligne : centipions OU mat (Stockfish envoie l'un ou
        /// l'autre). L'INTERPRÉTATION (mat = ±10000, priorité au mat) reste
        /// côté app (`EngineScore`).
        public struct Score: Equatable, Sendable {
            // Types alignés sur ce que l'app attend (comme ChessKitEngine) :
            // `cp` en Double (affecté à des `[Int: Double]`, lu via `Int(cp)`),
            // `mate` en Int (affecté directement à des `Int?`).
            public var cp: Double?
            public var mate: Int?
            public init(cp: Double? = nil, mate: Int? = nil) {
                self.cp = cp
                self.mate = mate
            }
        }
    }

    /// Parse une ligne UCI brute. `nil` pour les lignes non modélisées.
    public init?(rawValue: String) {
        let tokens = rawValue.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let first = tokens.first else { return nil }

        switch first {
        case "readyok":
            self = .readyok
        case "bestmove":
            let move = tokens.count > 1 ? tokens[1] : "(none)"
            var ponder: String?
            if let idx = tokens.firstIndex(of: "ponder"), idx + 1 < tokens.count {
                ponder = tokens[idx + 1]
            }
            self = .bestmove(move: move, ponder: ponder)
        case "info":
            self = .info(Self.parseInfo(tokens))
        default:
            return nil
        }
    }

    private static func parseInfo(_ tokens: [String]) -> Info {
        var info = Info()
        var i = 1
        func intAfter(_ index: Int) -> Int? {
            index + 1 < tokens.count ? Int(tokens[index + 1]) : nil
        }
        while i < tokens.count {
            switch tokens[i] {
            case "depth": info.depth = intAfter(i); i += 2
            case "seldepth": info.seldepth = intAfter(i); i += 2
            case "multipv": info.multipv = intAfter(i); i += 2
            case "nodes": info.nodes = intAfter(i); i += 2
            case "time": info.time = intAfter(i); i += 2
            case "score":
                // « score cp N » | « score mate N », suivi parfois de
                // lowerbound/upperbound (ignorés).
                if i + 2 < tokens.count {
                    let kind = tokens[i + 1]
                    if kind == "cp" {
                        info.score = Info.Score(cp: Double(tokens[i + 2]), mate: nil)
                    } else if kind == "mate" {
                        info.score = Info.Score(cp: nil, mate: Int(tokens[i + 2]))
                    }
                }
                i += 3
            case "pv":
                info.pv = Array(tokens[(i + 1)...])
                i = tokens.count
            case "string":
                // « info string … » : texte libre, on ignore le reste.
                i = tokens.count
            default:
                i += 1
            }
        }
        return info
    }
}
