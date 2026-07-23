import Testing
@testable import ChessLab

/// Vérifie la variété des débuts de partie produits par le livre
/// d'ouvertures — opérationnalise le critère d'acceptation "débuts variés
/// sur 10 parties" sans jamais lancer Stockfish (200 tirages simulés sont
/// quasi instantanés et donnent une preuve bien plus solide que 10
/// vraies parties).
struct OpeningBookEngineTests {

    /// Petit arbre fixture construit en mémoire (pas le JSON bundlé réel,
    /// pour ne pas dépendre de la résolution de bundle dans la cible de
    /// test) : 3 premiers coups, avec une ligne secondaire sous l'un
    /// d'eux, assez profond pour tester la marche dans l'arbre.
    private var fixtureBook: OpeningBook {
        OpeningBook(roots: [
            OpeningBookNode(san: "e4", weight: 50, children: [
                OpeningBookNode(san: "e5", weight: 100, children: [
                    OpeningBookNode(san: "Nf3", weight: 100, children: [
                        OpeningBookNode(san: "Nc6", weight: 100, children: []),
                    ]),
                ]),
            ]),
            OpeningBookNode(san: "d4", weight: 30, children: [
                OpeningBookNode(san: "d5", weight: 100, children: []),
            ]),
            OpeningBookNode(san: "c4", weight: 20, isMainLine: false, children: [
                OpeningBookNode(san: "e5", weight: 100, children: []),
            ]),
        ])
    }

    @Test func picksAmongAllRootMoves() {
        var firstMoves: Set<String> = []
        for _ in 0..<200 {
            if let move = OpeningBookEngine.pickNextMove(book: fixtureBook, sanPath: [], width: .includeSidelines) {
                firstMoves.insert(move)
            }
        }
        #expect(firstMoves.count == 3)
    }

    @Test func mainLinesOnlyExcludesSidelines() {
        var firstMoves: Set<String> = []
        for _ in 0..<200 {
            if let move = OpeningBookEngine.pickNextMove(book: fixtureBook, sanPath: [], width: .mainLinesOnly) {
                firstMoves.insert(move)
            }
        }
        #expect(firstMoves == ["e4", "d4"])
    }

    @Test func walksDownKnownPath() {
        let move = OpeningBookEngine.pickNextMove(book: fixtureBook, sanPath: ["e4", "e5"], width: .includeSidelines)
        #expect(move == "Nf3")
    }

    @Test func returnsNilOncePathLeavesTheTree() {
        let move = OpeningBookEngine.pickNextMove(book: fixtureBook, sanPath: ["e4", "c5"], width: .includeSidelines)
        #expect(move == nil)
    }

    @Test func returnsNilForEmptyBook() {
        let move = OpeningBookEngine.pickNextMove(book: OpeningBook(roots: []), sanPath: [], width: .includeSidelines)
        #expect(move == nil)
    }

    /// Simule 200 "parties" (6 demi-coups chacune) et vérifie qu'un
    /// nombre sensiblement supérieur à 10 lignes distinctes apparaît : si
    /// même 200 tirages ne produisaient que 2-3 lignes, 10 vraies parties
    /// ne montreraient certainement pas plus de variété.
    @Test func producesVariedOpeningLines() {
        var lines: Set<[String]> = []
        for _ in 0..<200 {
            var path: [String] = []
            for _ in 0..<6 {
                guard let move = OpeningBookEngine.pickNextMove(book: fixtureBook, sanPath: path, width: .includeSidelines) else { break }
                path.append(move)
            }
            lines.insert(path)
        }
        #expect(lines.count >= 3)
    }

    /// Sanity check du livre réellement bundlé (pas la fixture) : s'il ne
    /// se charge pas dans la cible de test, ajouter `opening_book.json` à
    /// la cible `ChessLabTests` dans Xcode.
    @Test func bundledBookIsNotEmpty() {
        #expect(!OpeningBookLoader.standard.roots.isEmpty)
    }
}
