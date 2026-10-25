import Testing
@testable import ChessLab

@MainActor
struct ClassicOpeningsTests {

    @Test("Chaque classique existe au catalogue, et ils restent un sous-ensemble net")
    func classicsExistInTheCatalog() {
        let ids = Set(OpeningCatalogFeature.catalog.map(\.id))
        #expect(OpeningCatalogFeature.classicIDs.isSubset(of: ids))
        #expect(OpeningCatalogFeature.classicIDs.count >= 15)
        #expect(OpeningCatalogFeature.classicIDs.count < ids.count / 2)
    }

    @Test("Les classiques mêlent les deux camps")
    func classicsCoverBothSides() {
        let sides = Set(OpeningCatalogFeature.catalog
            .filter { OpeningCatalogFeature.classicIDs.contains($0.id) }.map(\.side))
        #expect(sides == [.white, .black])
    }
}
