import ChessKit
import Testing
@testable import ChessLab

/// L'explicateur ne calcule rien : il REJOUE la variante du moteur. Ces tests
/// lui donnent donc des variantes écrites à la main — ce qui les rend
/// indépendants de Stockfish, de sa version et de sa profondeur.
struct MoveExplanationTests {

    private func explain(after fen: String, refutation: [String]) throws -> MoveExplanation? {
        let position = try #require(Position(fen: fen))
        return MoveExplainer.explain(
            .init(positionAfterMove: position, refutationLANs: refutation)
        )
    }

    // MARK: Mat

    @Test func countsMovesToMateNotHalfMoves() throws {
        // Trois demi-coups (Dd5, Rh8, Dd8#) = mat en DEUX coups. Compter les
        // demi-coups annoncerait « mat en 3 » et personne ne parle comme ça.
        let explanation = try explain(
            after: "6k1/5ppp/8/8/8/8/8/3QK2R w K - 0 1",
            refutation: ["d1d5", "g8h8", "d5d8"]
        )
        #expect(explanation?.motif == .checkmate(inMoves: 2, isBackRank: true))
    }

    @Test func mateSilencesTheMaterialCount() throws {
        // « Mat en 2. Vous perdez 3 points. » serait grotesque : quand la ligne
        // mate, le matériel ne veut plus rien dire.
        let explanation = try explain(
            after: "6k1/5ppp/8/8/8/8/8/3QK3 w - - 0 1",
            refutation: ["d1d8"]
        )
        let sentence = try #require(explanation?.sentence(notation: .french))
        // Le « # » vient du SAN de ChessKit et traverse la francisation intact.
        #expect(sentence == "Dd8# : mat du couloir.")
    }

    // MARK: Matériel

    @Test func readsMaterialAtTheEndOfTheExchange() throws {
        // Le pion prend le cavalier, le pion c3 reprend : la ligne coûte un
        // cavalier contre un pion, soit 2 points nets — pas 3.
        let explanation = try explain(
            after: "4k3/8/8/4p3/3N4/2P5/8/4K3 b - - 0 1",
            refutation: ["e5d4", "c3d4"]
        )
        #expect(explanation?.materialLoss == 2)
    }

    @Test func fallsBackToTheLastPlyWhenTheLineIsCutMidExchange() throws {
        // MÊME position, variante TRONQUÉE juste après la prise. Aucun point
        // calme dans la ligne : le verdict se rabat sur le dernier demi-coup et
        // annonce 3 au lieu de 2. C'est le prix assumé d'une variante coupée —
        // le test fige le comportement pour qu'une régression se voie.
        let explanation = try explain(
            after: "4k3/8/8/4p3/3N4/2P5/8/4K3 b - - 0 1",
            refutation: ["e5d4"]
        )
        #expect(explanation?.materialLoss == 3)
    }

    @Test func ignoresAQuietLineThatCostsNothing() throws {
        // Rien à dire : ni mat, ni motif, ni matériel. Mieux vaut se taire que
        // meubler — le bandeau coach n'affichera simplement pas de phrase.
        let explanation = try explain(
            after: "4k3/p7/8/8/8/8/1P6/4K3 b - - 0 1",
            refutation: ["a7a6", "b2b3"]
        )
        #expect(explanation == nil)
    }

    @Test func saysNothingWithoutARefutation() throws {
        #expect(try explain(after: "4k3/8/8/8/8/8/8/4K3 b - - 0 1", refutation: []) == nil)
    }

    // MARK: Phrases

    @Test func namesTheHangingPieceRatherThanItsPointValue() throws {
        // « votre dame était en prise » apprend quelque chose ; « vous perdez
        // 9 points » ne dit pas QUOI.
        let explanation = try explain(
            after: "4k3/8/2n5/8/3Q4/8/8/4K3 b - - 0 1",
            refutation: ["c6d4"]
        )
        #expect(explanation?.motif == .hangingPiece(kind: .queen, on: .d4))
        #expect(try #require(explanation).sentence(notation: .french)
            == "Cxd4 : votre dame était en prise.")
    }

    @Test func followsThePieceNotationSetting() throws {
        // La phrase cite un coup : elle doit suivre le réglage de notation
        // comme le reste de l'app, sans quoi on lirait « Cxd4 » dans la liste
        // des coups et « Nxd4 » dans l'explication du même coup.
        let explanation = try #require(try explain(
            after: "4k3/8/2n5/8/3Q4/8/8/4K3 b - - 0 1",
            refutation: ["c6d4"]
        ))
        #expect(explanation.sentence(notation: .english) == "Nxd4 : votre dame était en prise.")
    }

    @Test func spellsOutTheCostWhenTheMotifDoesNotCarryIt() throws {
        // Une fourchette ne dit pas d'elle-même ce qu'elle coûte : la phrase
        // ajoute le chiffre. Une pièce en prise, si (test ci-dessus).
        let explanation = try #require(try explain(
            after: "3q2k1/2r5/8/2N5/8/8/8/4K3 w - - 0 1",
            refutation: ["c5e6", "g8h8", "e6d8"]
        ))
        #expect(explanation.motif == .fork(by: .knight, on: .e6, targets: [.queen, .rook]))
        #expect(explanation.sentence(notation: .french)
            == "Ce6 : fourchette sur votre dame et votre tour. Vous perdez 9 points.")
    }
}
