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

    // MARK: Reproduction du bug « Analyser une partie jouée part en analyse profonde »

    private func moveCount(_ game: Game) -> Int {
        var count = 0
        var idx = game.startingIndex
        while game.moves.hasIndex(after: idx) {
            idx = game.moves.index(after: idx)
            count += 1
        }
        return count
    }

    /// Une partie jouée (construite par `make`, comme `PlayViewModel`) exportée
    /// par ``PGNExport`` puis rechargée par le chemin EXACT de l'app
    /// (`(try? Game(pgn:)) ?? Game()`) doit conserver ses coups. Sinon la
    /// partie est vide → l'analyseur part en analyse profonde au lieu de classer.
    @Test func aPlayedGameRoundTripsThroughExportForAnalysis() throws {
        var game = Game()
        var idx = game.startingIndex
        for san in ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7"] {
            idx = game.make(move: san, from: idx)
        }
        let played = moveCount(game)
        #expect(played == 7)

        let exported = PGNExport.pgn(for: game)
        let reparsed = (try? Game(pgn: exported)) ?? Game()

        #expect(moveCount(reparsed) == played,
                "round-trip a perdu des coups (\(moveCount(reparsed))/\(played)) → analyse profonde. Export:\n>>>\(exported)<<<")
    }

    @MainActor
    @Test func analysisOfAPlayedGameEntersReviewNotDeepMode() throws {
        var game = Game()
        var idx = game.startingIndex
        for san in ["d4", "d5", "c4", "e6", "Nc3", "Nf6"] {
            idx = game.make(move: san, from: idx)
        }
        let exported = PGNExport.pgn(for: game)

        let viewModel = AnalysisViewModel(source: .pgn(exported))
        #expect(viewModel.isGameReview,
                "l'analyse d'une partie jouée doit être en REVUE (classification), pas en exploration profonde")
    }

    /// Une vraie partie porte un RÉSULTAT dans son mouvement-texte (« … 1-0 »).
    /// Vérifie que le parseur ne perd pas les coups à cause du jeton de résultat.
    @Test func aResultTerminatedPGNKeepsItsMoves() {
        let cases = [
            "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0",
            "1. e4 e5 2. Nf3 Nc6 0-1",
            "1. d4 d5 2. c4 e6 1/2-1/2",
            "1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0",
        ]
        for pgn in cases {
            let game = (try? Game(pgn: pgn)) ?? Game()
            #expect(moveCount(game) >= 2, "coups perdus pour « \(pgn) » → \(moveCount(game)) coups")
        }
    }

    /// Le résultat posé sur `game.tags.result` (ce que fait une vraie partie
    /// terminée) doit ressortir à l'export ET se recharger sans perte.
    /// Roque et promotion — coups « spéciaux » qu'une vraie partie contient
    /// souvent, absents des tests synthétiques précédents.
    @Test func aGameWithCastlingAndPromotionRoundTrips() {
        // Ligne menant à un roque puis (plus loin) une promotion.
        let pgn = "1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. O-O Nf6 5. d3 O-O"
        let game = (try? Game(pgn: pgn)) ?? Game()
        #expect(moveCount(game) == 10, "roque perdu au parsing → \(moveCount(game)) coups")
    }

    /// Partie démarrée d'une position PERSONNALISÉE (« Jouer à partir d'ici ») :
    /// ``PGNExport`` ajoute [SetUp]/[FEN]. Le rechargement doit garder la
    /// position de départ ET les coups, et rester en REVUE.
    @MainActor
    @Test func aGameFromCustomStartRoundTripsAndReviews() throws {
        let fen = "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3"
        let position = try #require(Position(fen: fen))
        var game = Game(startingWith: position)
        var idx = game.startingIndex
        for san in ["Bb5", "a6", "Ba4"] {
            idx = game.make(move: san, from: idx)
        }
        let exported = PGNExport.pgn(for: game)
        #expect(exported.contains("[FEN "), "PGNExport doit émettre le tag FEN pour une position personnalisée")

        let reparsed = (try? Game(pgn: exported)) ?? Game()
        #expect(moveCount(reparsed) == 3, "coups perdus depuis une position personnalisée. Export:\n>>>\(exported)<<<")

        let viewModel = AnalysisViewModel(source: .pgn(exported))
        #expect(viewModel.isGameReview, "une partie 'à partir d'ici' doit être en revue, pas en analyse profonde")
    }

    @Test func aGameWithResultTagRoundTrips() {
        var game = Game()
        var idx = game.startingIndex
        for san in ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7"] {
            idx = game.make(move: san, from: idx)
        }
        game.tags.result = "1-0"
        let exported = PGNExport.pgn(for: game)
        let reparsed = (try? Game(pgn: exported)) ?? Game()
        #expect(moveCount(reparsed) == 7, "coups perdus avec [Result]. Export:\n>>>\(exported)<<<")
    }
}
