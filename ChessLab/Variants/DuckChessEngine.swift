import ChessKit
import CStockfishKit
import Foundation

/// L'adversaire du Duck Chess — et l'analyste de fin de partie.
///
/// Aucun moteur d'échecs ne connaît cette variante, et il n'a pas fallu en
/// écrire un : Stockfish standard reste un excellent joueur d'échecs, il
/// suffit de ne JAMAIS le laisser choisir hors des coups que le canard
/// autorise. C'est le rôle de `searchmoves`, qui restreint sa recherche à une
/// liste imposée — les coups légaux calculés ici par ``DuckChessRules``.
///
/// ## Ce que le moteur ne voit pas, et ce qu'on fait à la place
///
/// Il ignore le canard dans son ÉVALUATION : il croit ouvertes des lignes que
/// le canard barre. Son jeu reste bon, sans être parfait — c'est le compromis
/// assumé, et il est annoncé au joueur dans l'écran de réglages.
///
/// Trois cas le mettraient carrément en défaut, tous traités AVANT lui :
///
/// - **Le roi adverse est prenable.** Aux échecs, une telle position est
///   ILLÉGALE : le moteur la refuse ou répond n'importe quoi, et ne
///   proposerait jamais la prise — qui est pourtant le coup gagnant. On la
///   joue donc sans le consulter.
/// - **La position est illégale sans l'être pour nous.** Un roi qui reste
///   sous une attaque est normal ici, interdit là-bas — même quand le canard
///   pare cette attaque, puisqu'il ne figure pas dans la FEN. On vérifie donc
///   ``DuckChessRules/isStandardLegal(_:)`` avant CHAQUE envoi.
/// - **Plus rien à chercher.** Si tous les coups légaux au canard laissent le
///   roi en prise, le moteur les tient pour illégaux, sa liste devient vide et
///   il répond `bestmove (none)`. Une heuristique locale prend le relais.
actor DuckChessEngine {

    private let controller = EngineController()
    private var isReady = false

    /// Budget de réflexion, calé sur la force choisie — mêmes ordres de
    /// grandeur que le mode Jouer.
    private let movetimeMs: Int
    private let strength: EngineStrength

    init(strength: EngineStrength) {
        self.strength = strength
        // Budget calé sur la force : un débutant réfléchit peu, un maître
        // davantage — sans jamais dépasser une seconde et demie, la variante
        // se jouant à un rythme de salon.
        let elo = strength.sliderValue
        movetimeMs = Int(max(150, min(150 + (elo - 800) * 0.55, 1500)))
    }

    func start() async -> Bool {
        guard !isReady else { return true }
        guard await controller.start(coreCount: DevicePerformance.recommendedThreads) else {
            return false
        }
        for command in strength.setupCommands {
            await controller.send(command)
        }
        isReady = true
        return true
    }

    func stop() async {
        await controller.stop()
        isReady = false
    }

    // MARK: Le coup

    /// Choisit un coup pour le camp au trait.
    func chooseMove(
        position: Position, duck: Square?, enPassant: Square?
    ) async -> DuckChessRules.Move? {
        let legal = DuckChessRules.moves(in: position, duck: duck, enPassant: enPassant)
        guard !legal.isEmpty else { return nil }

        // 1. Le roi adverse est à portée : on gagne, inutile de réfléchir.
        if let win = legal.first(where: { DuckChessRules.capturesKing($0, in: position) != nil }) {
            return win
        }

        // 2. Stockfish, borné aux coups que le canard autorise.
        if isReady, DuckChessRules.isStandardLegal(position) {
            let uciList = legal.map(\.uci)
            if let best = await controller.computeBestMove(
                fen: position.fen, setupCommands: [], movetimeMs: movetimeMs,
                // Sous 1320 Elo, la force se simule en plafonnant la
                // PROFONDEUR (voir ``EngineStrength``) : sans cela, un
                // « débutant » à qui on donne un dixième de seconde reste
                // un joueur redoutable sur un plateau à 32 pièces.
                depth: strength.maxDepth, searchmoves: uciList
            )?.lan, let chosen = legal.first(where: { $0.uci == best }) {
                return chosen
            }
        }

        // 3. Repli : la meilleure prise, sinon un coup au hasard.
        return heuristicMove(among: legal, position: position)
    }

    /// À défaut du moteur : prendre ce qui vaut le plus, sinon avancer.
    private func heuristicMove(
        among moves: [DuckChessRules.Move], position: Position
    ) -> DuckChessRules.Move? {
        let captures = moves.compactMap { move -> (DuckChessRules.Move, Int)? in
            guard let victim = position.piece(at: move.to) else { return nil }
            return (move, pieceValue(victim.kind))
        }
        if let best = captures.max(by: { $0.1 < $1.1 }) { return best.0 }
        return moves.randomElement()
    }

    // MARK: Le canard

    /// Où poser le canard : sur le chemin du meilleur coup ADVERSE.
    ///
    /// C'est l'esprit de la variante — on ne pose pas le canard au hasard, on
    /// le pose là où il gêne. On demande donc au moteur ce que l'adversaire
    /// voudrait jouer, et on bloque : sa case d'arrivée si elle est libre,
    /// sinon une case de son trajet.
    ///
    /// - parameter position: la position APRÈS le coup — le trait y appartient
    ///   encore à celui qui vient de jouer, le tour n'étant pas fini. La
    ///   question posée au moteur portant sur ce que l'ADVERSAIRE veut faire,
    ///   c'est une position au trait retourné qu'on lui envoie.
    func chooseDuckSquare(
        position: Position, currentDuck: Square?, enPassant: Square?
    ) async -> Square? {
        let targets = DuckChessRules.duckTargets(in: position, currentDuck: currentDuck)
        guard !targets.isEmpty else { return nil }

        if isReady, let opponentToMove = Self.sideToMoveFlipped(position),
           DuckChessRules.isStandardLegal(opponentToMove),
           let threat = await controller.computeBestMove(
               fen: opponentToMove.fen, setupCommands: [], movetimeMs: max(80, movetimeMs / 3),
               depth: nil, searchmoves: nil
           )?.lan, threat.count >= 4 {
            let from = Square(String(threat.prefix(2)))
            let to = Square(String(threat.dropFirst(2).prefix(2)))
            // La case d'arrivée d'abord : le canard y annule le coup.
            if targets.contains(to) { return to }
            // Sinon une case du trajet, pour les pièces à distance.
            for square in DuckChessRules.pathBetween(from: from, to: to) where targets.contains(square) {
                return square
            }
        }
        // Faute de mieux, une case au centre plutôt qu'un coin : elle gêne
        // statistiquement davantage.
        return targets.max { centrality($0) < centrality($1) }
    }

    private func centrality(_ square: Square) -> Int {
        let file = square.file.number
        let rank = square.rank.value
        return -(abs(file * 2 - 9) + abs(rank * 2 - 9))
    }

    /// Même position, trait retourné. `nil` si la FEN est illisible.
    static func sideToMoveFlipped(_ position: Position) -> Position? {
        var fields = position.fen.split(separator: " ").map(String.init)
        guard fields.count >= 2 else { return nil }
        fields[1] = fields[1] == "w" ? "b" : "w"
        return Position(fen: fields.joined(separator: " "))
    }

    // MARK: Évaluation

    /// Ce que vaut une position, et le meilleur coup qui s'y trouve.
    ///
    /// Toujours **du point de vue des Blancs** : c'est ce qu'attendent la
    /// barre d'éval et la classification des coups. `nil` quand la question
    /// n'a pas de sens pour Stockfish — position illégale à ses yeux, moteur
    /// arrêté, ou recherche sans réponse.
    struct Evaluation: Sendable {
        var cpWhite: Int
        var bestUCI: String?
    }

    /// - parameter nodes: budget en nœuds, pour une passe de classification
    ///   qui doit rendre le même verdict sur tous les appareils.
    func evaluate(
        position: Position, duck: Square?, enPassant: Square?,
        movetimeMs override: Int? = nil, nodes: Int? = nil
    ) async -> Evaluation? {
        guard isReady, DuckChessRules.isStandardLegal(position) else { return nil }
        let legal = DuckChessRules.moves(in: position, duck: duck, enPassant: enPassant)
        guard !legal.isEmpty else { return nil }

        guard let result = await controller.computeBestMove(
            fen: position.fen, setupCommands: [], movetimeMs: override ?? movetimeMs,
            depth: nil, searchmoves: legal.map(\.uci), nodes: nodes
        ), let moverCp = result.moverCp else { return nil }

        // Un « mat » annoncé par Stockfish n'en est pas un ici : le canard
        // peut barrer la ligne au coup suivant. On le ramène donc à un très
        // gros avantage plutôt que de le donner pour certain — la barre
        // d'éval n'affichera jamais « M3 » en Duck Chess.
        let clamped = max(-Self.winningCentipawns, min(moverCp, Self.winningCentipawns))
        return Evaluation(
            cpWhite: position.sideToMove == .white ? clamped : -clamped,
            bestUCI: result.lan == "(none)" ? nil : result.lan
        )
    }

    /// Plafond d'éval affichée. Au-delà, l'avantage est écrasant sans être
    /// pour autant un mat forcé — notion que cette variante n'a pas.
    static let winningCentipawns = 2000
}
