import ChessKit
import Foundation

/// Un trait de coup, lu en rejouant le coup sur un plateau : ce qu'un
/// personnage AIME ou ÉVITE. Chaque trait vaut entre −1 et 1 (souvent 0 ou 1).
enum StyleTrait: String, CaseIterable, Codable, Hashable, Sendable {
    /// Le coup donne échec.
    case check
    /// Le coup capture.
    case capture
    /// Gain de matériel net (capture moins risque immédiat), ramené à ±1.
    case materialGain
    /// La pièce jouée peut être prise par une pièce de valeur nettement
    /// inférieure sans que le coup ne rapporte autant : un sacrifice, ou une
    /// pièce laissée en prise.
    case sacrifice
    /// Une pièce (ni pion ni roi) se rapproche du roi adverse.
    case towardKing
    /// Un pion avance sur l'aile où le roi adverse a roqué.
    case pawnStorm
    /// Roque.
    case castle
    /// Une pièce mineure quitte sa case de départ.
    case development
    /// Pions isolés ou doublés créés (positif) ou résorbés (négatif).
    case weakPawn
    /// Échange de pièces de même valeur (au moins une pièce mineure).
    case equalTrade
    /// Échange des dames.
    case queenTrade
    /// Captures nouvellement offertes à l'adversaire : la position se complique.
    case tension
    /// Mobilité gagnée par la pièce jouée.
    case mobility
}

/// Le style d'un personnage : un poids par trait, et une borne.
///
/// Le score d'un coup est la somme pondérée de ses traits, BORNÉE à
/// ±`strength` (en nats) : la probabilité que Maia lui attribue est
/// multipliée par e^score. Avec `strength` = 1, un coup adoré pèse au plus
/// 2,7 fois plus, un coup détesté 2,7 fois moins — le style colore la
/// distribution humaine, il ne la remplace pas, et il n'achète jamais une
/// gaffe que Maia jugeait improbable.
struct StyleProfile: Hashable, Sendable {
    var weights: [StyleTrait: Double]
    var strength: Double

    static let none = StyleProfile(weights: [:], strength: 0)

    var isNeutral: Bool { strength <= 0 || weights.isEmpty }

    /// Le même style, avec des poids ajoutés (style dynamique selon le score).
    func adding(_ extra: [StyleTrait: Double]) -> StyleProfile {
        guard !extra.isEmpty else { return self }
        var merged = weights
        for (trait, weight) in extra { merged[trait, default: 0] += weight }
        return StyleProfile(weights: merged, strength: max(strength, 0.6))
    }
}

/// Les traits d'UN coup, mesurés.
struct MoveTraits: Equatable, Sendable {
    var check = false
    var capture = false
    var capturedValue = 0
    var movedValue = 0
    var sacrifice = false
    var towardKing = false
    var pawnStorm = false
    var castle = false
    var development = false
    var weakPawnDelta = 0
    var equalTrade = false
    var queenTrade = false
    var tensionDelta = 0
    var mobilityDelta = 0

    /// Valeur du trait entre −1 et 1.
    func value(of trait: StyleTrait) -> Double {
        switch trait {
        case .check: check ? 1 : 0
        case .capture: capture ? 1 : 0
        case .materialGain: Self.clamp(Double(capturedValue - (sacrifice ? movedValue : 0)) / 5)
        case .sacrifice: sacrifice ? 1 : 0
        case .towardKing: towardKing ? 1 : 0
        case .pawnStorm: pawnStorm ? 1 : 0
        case .castle: castle ? 1 : 0
        case .development: development ? 1 : 0
        case .weakPawn: Self.clamp(Double(weakPawnDelta) / 2)
        case .equalTrade: equalTrade ? 1 : 0
        case .queenTrade: queenTrade ? 1 : 0
        case .tension: Self.clamp(Double(tensionDelta) / 3)
        case .mobility: Self.clamp(Double(mobilityDelta) / 6)
        }
    }

    private static func clamp(_ x: Double) -> Double { min(1, max(-1, x)) }
}

/// Extraction des traits et repondération de la distribution de Maia.
/// Module pur : ChessKit seulement, testé sur cas choisis.
enum OpponentStyle {

    static func value(of kind: Piece.Kind) -> Int {
        switch kind {
        case .pawn: 1
        case .knight, .bishop: 3
        case .rook: 5
        case .queen: 9
        case .king: 0
        }
    }

    /// Les traits du coup `lan` (UCI) pour le camp au trait, ou `nil` si le
    /// coup n'est pas applicable.
    static func traits(of lan: String, on board: Board) -> MoveTraits? {
        guard lan.count >= 4 else { return nil }
        let mover = board.position.sideToMove
        let from = Square(String(lan.prefix(2)))
        let to = Square(String(lan.dropFirst(2).prefix(2)))
        guard let piece = board.position.piece(at: from), piece.color == mover else { return nil }

        var scratch = board
        guard let made = scratch.move(pieceAt: from, to: to) else { return nil }
        var promotedKind: Piece.Kind?
        if case .promotion = scratch.state {
            let kind = lan.count == 5 ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen) : .queen
            scratch.completePromotion(of: made, to: kind)
            promotedKind = kind
        }

        var traits = MoveTraits()
        traits.movedValue = value(of: promotedKind ?? piece.kind)
        if case let .capture(captured) = made.result {
            traits.capture = true
            traits.capturedValue = value(of: captured.kind)
            traits.queenTrade = captured.kind == .queen && piece.kind == .queen
        }
        switch scratch.state {
        case .check, .checkmate: traits.check = true
        default: break
        }
        traits.castle = piece.kind == .king && abs(from.file.number - to.file.number) == 2
        let homeRank = mover == .white ? 1 : 8
        traits.development = (piece.kind == .knight || piece.kind == .bishop)
            && from.rank.value == homeRank && to.rank.value != homeRank

        let enemy = mover.opposite
        if let king = board.position.pieces.first(where: { $0.kind == .king && $0.color == enemy }) {
            if piece.kind != .pawn, piece.kind != .king {
                let before = distance(from, king.square)
                let after = distance(to, king.square)
                traits.towardKing = after < before && after <= 3
            }
            if piece.kind == .pawn {
                let kingFile = king.square.file.number
                let kingWing: Int? = kingFile <= 3 ? 0 : (kingFile >= 6 ? 1 : nil)
                let pawnWing: Int? = to.file.number <= 3 ? 0 : (to.file.number >= 6 ? 1 : nil)
                let relativeRank = mover == .white ? to.rank.value : 9 - to.rank.value
                traits.pawnStorm = kingWing != nil && kingWing == pawnWing && relativeRank >= 4
            }
        }

        // Attaquants adverses de la case d'arrivée, APRÈS le coup.
        // `legalMoves(forPieceAt:)` ignore le trait : on peut interroger les
        // pièces adverses directement.
        var lowestAttacker: Int?
        for enemyPiece in scratch.position.pieces where enemyPiece.color == enemy {
            if scratch.legalMoves(forPieceAt: enemyPiece.square).contains(to) {
                let attackerValue = value(of: enemyPiece.kind)
                lowestAttacker = min(lowestAttacker ?? Int.max, attackerValue)
            }
        }
        if let lowestAttacker {
            let netCapture = traits.capture && traits.capturedValue >= traits.movedValue
            traits.sacrifice = lowestAttacker + 1 < traits.movedValue && !netCapture
            traits.equalTrade = traits.capture && traits.capturedValue == traits.movedValue && traits.movedValue >= 3
        }

        traits.weakPawnDelta = weakPawns(in: scratch.position, of: mover) - weakPawns(in: board.position, of: mover)
        traits.tensionDelta = captures(available: enemy, in: scratch) - captures(available: enemy, in: board)
        let mobilityBefore = board.legalMoves(forPieceAt: from).count
        let mobilityAfter = scratch.legalMoves(forPieceAt: to).count
        traits.mobilityDelta = mobilityAfter - mobilityBefore
        return traits
    }

    /// Score de style d'un coup, borné à ±`strength`.
    static func score(_ traits: MoveTraits, style: StyleProfile) -> Double {
        guard !style.isNeutral else { return 0 }
        let raw = style.weights.reduce(0.0) { $0 + $1.value * traits.value(of: $1.key) }
        return min(style.strength, max(-style.strength, raw))
    }

    /// Repondère les `topK` premiers candidats de Maia par leur score de
    /// style, puis renormalise. L'ordre de sortie est celui des probabilités
    /// repondérées.
    static func apply(_ style: StyleProfile, to candidates: [MaiaCandidate], board: Board, topK: Int = 8) -> [MaiaCandidate] {
        guard !style.isNeutral, !candidates.isEmpty else { return candidates }
        var weighted = candidates
        for index in 0..<min(topK, candidates.count) {
            guard let traits = traits(of: candidates[index].move.uci, on: board) else { continue }
            let factor = exp(score(traits, style: style))
            weighted[index] = MaiaCandidate(move: candidates[index].move, probability: candidates[index].probability * factor)
        }
        let total = weighted.reduce(0.0) { $0 + $1.probability }
        guard total > 0 else { return candidates }
        return weighted
            .map { MaiaCandidate(move: $0.move, probability: $0.probability / total) }
            .sorted { $0.probability > $1.probability }
    }

    // MARK: Outils

    static func distance(_ a: Square, _ b: Square) -> Int {
        max(abs(a.file.number - b.file.number), abs(a.rank.value - b.rank.value))
    }

    /// Pions isolés + pions doublés d'un camp.
    static func weakPawns(in position: Position, of color: Piece.Color) -> Int {
        var perFile = [Int](repeating: 0, count: 10)   // index 1...8, marges à 0 et 9
        for pawn in position.pieces where pawn.color == color && pawn.kind == .pawn {
            perFile[pawn.square.file.number] += 1
        }
        var weak = 0
        for file in 1...8 where perFile[file] > 0 {
            if perFile[file - 1] == 0, perFile[file + 1] == 0 { weak += perFile[file] }
            if perFile[file] > 1 { weak += perFile[file] - 1 }
        }
        return weak
    }

    /// Captures disponibles pour `color` (le trait est ignoré par ChessKit).
    static func captures(available color: Piece.Color, in board: Board) -> Int {
        var count = 0
        for piece in board.position.pieces where piece.color == color {
            for target in board.legalMoves(forPieceAt: piece.square) {
                if let victim = board.position.piece(at: target), victim.color != color { count += 1 }
            }
        }
        return count
    }
}

extension OpponentProfile {
    /// Le personnage tel qu'il joue MAINTENANT : température et style
    /// modulés par le score de la partie (point de vue du personnage).
    struct Mood: Equatable, Sendable {
        let temperature: Double
        let style: StyleProfile
    }

    func mood(lastMoverCp: Int?) -> Mood {
        guard let cp = lastMoverCp else { return Mood(temperature: temperature, style: style) }
        if cp >= Temperament.winningThresholdCp {
            return Mood(temperature: temperament.temperatureWhenWinning ?? temperature,
                        style: style.adding(temperament.styleWhenWinning))
        }
        if cp <= -Temperament.winningThresholdCp {
            return Mood(temperature: temperament.temperatureWhenLosing ?? temperature,
                        style: style.adding(temperament.styleWhenLosing))
        }
        return Mood(temperature: temperature, style: style)
    }
}
