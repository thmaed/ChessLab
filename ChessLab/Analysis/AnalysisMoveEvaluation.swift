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
}
