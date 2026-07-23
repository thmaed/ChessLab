import ChessKit
import Testing
@testable import ChessLab

/// Vérifie concrètement le critère d'acceptation de l'étape 3 : "export
/// PGN rechargeable sans perte". Ne teste aucun code de ChessLab — c'est
/// une vérification directe des garanties de `ChessKit.Game`/`PGNParser`
/// dont `AnalysisViewModel` dépend pour les variantes, NAG et
/// commentaires (voir `AnalysisViewModel.swift`, "Ce que la recherche a
/// confirmé" dans PROGRESS.md).
struct AnalysisPGNRoundTripTests {

    @Test func pgnWithVariationNagAndCommentRoundTripsLossless() throws {
        var game = Game()
        var index = game.startingIndex

        index = game.make(move: "e4", from: index)
        let afterE4 = index
        index = game.make(move: "e5", from: index)
        let afterE5 = index
        index = game.make(move: "Nf3", from: index)

        // Variante : à la même position (après 1...e5), 2.Nc3 au lieu de
        // 2.Nf3 — doit créer une branche, pas écraser la ligne principale.
        let variationIndex = game.make(move: "Nc3", from: afterE5)
        #expect(variationIndex != index, "2.Nc3 doit être une nouvelle variation, pas confondue avec 2.Nf3")

        game.annotate(moveAt: index, assessment: .null, comment: "Un développement naturel")
        game.annotate(moveAt: afterE4, assessment: .good)

        let exported = game.pgn

        // Les trois ingrédients doivent apparaître dans l'export : une
        // variante entre parenthèses, un commentaire entre accolades, et
        // un NAG (Move.Assessment.good = "$1").
        #expect(exported.contains("("), "La variante 2.Nc3 doit apparaître entre parenthèses")
        #expect(exported.contains("{Un développement naturel}"), "Le commentaire doit être exporté")
        #expect(exported.contains("$1"), "Le NAG de l'annotation 'good' doit être exporté")

        let reimported = try Game(pgn: exported)

        // Le vrai test de non-perte : réexporter la partie réimportée doit
        // produire EXACTEMENT le même texte PGN.
        #expect(reimported.pgn == exported)
    }

    @Test func malformedPgnThrowsRatherThanCrashing() {
        #expect(throws: (any Error).self) {
            _ = try Game(pgn: "1. e4 e5 2. Nf3 (( unbalanced")
        }
    }
}
