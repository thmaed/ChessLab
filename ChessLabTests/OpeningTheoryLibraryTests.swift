import Testing
@testable import ChessLab

/// La ressource des 149 familles nourrit la détection « coup de théorie »
/// de l'analyse — héritière des tests de l'ancienne bibliothèque, réduite
/// comme son chargeur à ce que le code vivant consomme.
struct OpeningTheoryLibraryTests {

    @Test func bundledTheoryIsNotEmpty() {
        #expect(OpeningTheoryLibrary.standard.count > 100)
    }

    @Test func everyEntryCarriesAUsablePGN() {
        for entry in OpeningTheoryLibrary.standard {
            #expect(!entry.family.isEmpty)
            #expect(!EcoOpeningLoader.sanMoves(fromPGN: entry.pgn).isEmpty,
                    "\(entry.family) : PGN sans coups exploitables")
        }
    }
}
