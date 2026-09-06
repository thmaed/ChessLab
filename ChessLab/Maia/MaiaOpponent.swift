import ChessKit
import Foundation

/// L'adversaire humain : Maia-3 interrogé sur la position courante et son
/// historique, puis un tirage à la température du personnage.
///
/// Ne connaît ni le filet ni le tempérament : il rend un coup et la
/// distribution dont il sort, `PlayViewModel` décide du reste.
actor MaiaOpponent {

    struct Choice: Sendable {
        /// Le coup tiré, en UCI côté plateau réel.
        let uci: String
        /// Toute la distribution sur les coups légaux, triée.
        let candidates: [MaiaCandidate]
        /// Issue humaine prédite pour le camp au trait.
        let win: Double
        let draw: Double
        let loss: Double
    }

    private let model: MaiaModel

    init?(bundle: Bundle = .main) {
        guard let model = MaiaModel(bundle: bundle) else { return nil }
        self.model = model
    }

    /// - parameter history: positions de la partie, de la plus ancienne à la
    ///   courante (voir ``MaiaEncoder/tokens(history:)``).
    /// - parameter board: le plateau courant, pour les coups légaux.
    /// - returns: `nil` si aucun coup n'est légal.
    func chooseMove(
        history: [Position], board: Board,
        selfElo: Double, oppoElo: Double,
        temperature: Double, topP: Double,
        style: StyleProfile = .none
    ) async throws -> Choice? {
        let legal = MaiaLegalMoves.moves(in: board)
        guard !legal.isEmpty else { return nil }
        let tokens = MaiaEncoder.tokens(history: history)
        let prediction = try await model.predict(tokens: tokens, selfElo: selfElo, oppoElo: oppoElo)
        // Le style repondère la distribution HUMAINE de Maia (borné, voir
        // ``OpponentStyle``), puis le tirage se fait dans le résultat.
        let candidates = OpponentStyle.apply(style, to: MaiaPolicy.candidates(logits: prediction.moveLogits, legal: legal), board: board)
        var generator = SystemRandomNumberGenerator()
        guard let pick = MaiaPolicy.sample(candidates, temperature: temperature, topP: topP, using: &generator) else {
            return nil
        }
        return Choice(
            uci: pick.move.uci, candidates: candidates,
            win: prediction.win, draw: prediction.draw, loss: prediction.loss
        )
    }
}
