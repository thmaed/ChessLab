import ChessKit

/// Résultat d'analyse mis en cache pour un nœud de l'arbre (un coup joué),
/// tenu par ``AnalysisViewModel`` dans un `[MoveTree.Index:
/// AnalysisMoveEvaluation]` — jamais recalculé une fois obtenu, sauf si
/// la partie change.
struct AnalysisMoveEvaluation: Equatable {
    /// Probabilité de gain (0...100) APRÈS ce coup, du point de vue du
    /// joueur qui vient de jouer.
    let winPercentAfterMover: Double
    /// Catégorie du coup sur l'échelle complète — TOUJOURS présente : un
    /// coup analysé sans catégorie n'existe plus (voir ``MoveClassifier``).
    let quality: MoveQuality
    /// POURQUOI le coup était mauvais, lu sur la réfutation du moteur (voir
    /// ``MoveExplainer``). `nil` pour tous les coups sains — on n'explique que
    /// les fautes — et pour les fautes dont la ligne ne dit rien
    /// d'exploitable, ce qui arrive et n'est pas un défaut : mieux vaut se
    /// taire que meubler.
    var explanation: MoveExplanation?
}
