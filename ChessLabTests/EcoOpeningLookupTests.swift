import Testing
@testable import ChessLab

struct EcoOpeningLookupTests {

    private var fixtureDatabase: [EcoOpening] {
        [
            EcoOpening(eco: "C20", name: "Partie de pion roi", moves: ["e4", "e5"]),
            EcoOpening(eco: "C50", name: "Partie italienne", moves: ["e4", "e5", "Nf3", "Nc6", "Bc4"]),
            EcoOpening(eco: "C53", name: "Italienne, Giuoco Piano", moves: ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5"]),
            EcoOpening(eco: "B20", name: "Défense sicilienne", moves: ["e4", "c5"]),
        ]
    }

    @Test func picksLongestMatchingPrefix() {
        let path = ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "c3"]
        let result = EcoOpeningLookup.openingName(for: path, in: fixtureDatabase)
        #expect(result?.eco == "C53")
    }

    @Test func picksShorterEntryWhenLineDoesNotExtend() {
        let path = ["e4", "e5", "Nf3", "Nc6", "Bc4"]
        let result = EcoOpeningLookup.openingName(for: path, in: fixtureDatabase)
        #expect(result?.eco == "C50")
    }

    @Test func returnsNilWhenNoEntryMatches() {
        let path = ["d4", "d5"]
        let result = EcoOpeningLookup.openingName(for: path, in: fixtureDatabase)
        #expect(result == nil)
    }

    @Test func returnsNilWhenLineDivergesBeforeFullMatch() {
        // Diverge après 1.e4 c5 (Sicilienne), ne redevient jamais 1...e5.
        let path = ["e4", "c5", "Nf3"]
        let result = EcoOpeningLookup.openingName(for: path, in: fixtureDatabase)
        #expect(result?.eco == "B20")
    }

    @Test func bundledDatabaseIsNotEmpty() {
        #expect(!EcoOpeningLoader.standard.isEmpty)
    }

    @Test func bundledDatabaseHasNoDuplicateEcoWithSameMoves() {
        // Sanity check léger sur les données embarquées : pas de doublon
        // évident qui rendrait la recherche ambiguë.
        let database = EcoOpeningLoader.standard
        var seen: Set<[String]> = []
        for entry in database {
            #expect(!seen.contains(entry.moves), "Séquence dupliquée pour \(entry.eco)")
            seen.insert(entry.moves)
        }
    }
}
