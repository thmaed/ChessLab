import Testing
@testable import ChessLab

/// Les caractéristiques montrées en jauges se lisent dans les réglages des personnages (17/11/2026).
struct OpponentTraitsTests {
    @Test func maiaIsTheYardstick_inTheMiddleEverywhere() {
        #expect(OpponentTraits(.maia) == OpponentTraits(.maia))
        let maia = OpponentTraits(.maia)
        #expect([maia.attack, maia.solidity, maia.trades, maia.unpredictability] == [3, 3, 3, 3])
    }

    @Test func eachCharacterReadsLikeItsSentence() {
        #expect(OpponentTraits(.lea).attack == 5, "Lena attaque")
        #expect(OpponentTraits(.marc).solidity == 5, "Nils est solide")
        #expect(OpponentTraits(.marc).attack <= 2)
        #expect(OpponentTraits(.pablo).unpredictability == 5, "Pablo est imprévisible")
        #expect(OpponentTraits(.nadia).trades == 5, "Nadia échange les dames")
        #expect(OpponentTraits(.lea).trades == 1, "Lena évite les échanges")
    }

    /// Les deux paires qui se ressemblaient (retouche du 17/11/2026) se distinguent désormais.
    @Test func theLookalikePairsNowDiffer() {
        #expect(OpponentTraits(.theo).solidity < OpponentTraits(.lea).solidity, "Milo néglige roque et développement, pas Lena")
        #expect(OpponentTraits(.pablo).solidity == 1, "Pablo oublie son roi")
        #expect(OpponentTraits(.pablo).attack > OpponentTraits(.sacha).attack, "Pablo fonce, Sacha tend des pièges")
        #expect(OpponentTraits(.yuri).attack == 1, "Yuri ne sacrifie rien")
    }

    /// La table EXACTE, la même qu'Android (`OpponentTraitsTest`) : une divergence se voit ici.
    @Test func theWholeTableMatchesAndroid() {
        let expected: [String: [Int]] = [
            "maia": [3, 3, 3, 3], "lea": [5, 3, 1, 3], "theo": [5, 2, 1, 4],
            "sacha": [4, 2, 3, 4], "pablo": [5, 1, 3, 5], "marc": [1, 5, 3, 1],
            "nadia": [2, 4, 5, 1], "yuri": [1, 4, 4, 2], "ines": [3, 4, 3, 2],
        ]
        for (id, values) in expected {
            let t = OpponentTraits(OpponentProfile.named(id)!)
            #expect([t.attack, t.solidity, t.trades, t.unpredictability] == values, "\(id)")
        }
    }

    @Test func everyNoteIsBetweenOneAndFive() {
        for profile in OpponentProfile.all {
            let t = OpponentTraits(profile)
            for value in [t.attack, t.solidity, t.trades, t.unpredictability] { #expect((1...5).contains(value), "\(profile.id)") }
        }
    }
}
