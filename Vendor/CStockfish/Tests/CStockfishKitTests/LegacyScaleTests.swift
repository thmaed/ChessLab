import CStockfish
import XCTest

/// L'échelle des centipions de Stockfish 19, ramenée sur celle de la 17.1 (voir `shim.cpp`).
///
/// Les points de repère sont ceux MESURÉS le 08/11/2026 sur 3 513 positions de vraies parties :
/// presque l'identité près de l'égalité, puis la 19 annonce 30 à 45 % de plus.
final class LegacyScaleTests: XCTestCase {

    private func scaled(_ cp: Int) -> Int { Int(cstockfish_legacy_cp(Int32(cp))) }

    func testEqualityIsLeftAlone() {
        XCTAssertEqual(scaled(0), 0)
        XCTAssertEqual(scaled(36), 40)
        XCTAssertEqual(scaled(70), 72)
    }

    func testLargeAdvantagesAreBroughtBackToTheOldScale() {
        XCTAssertEqual(scaled(250), 209)
        XCTAssertEqual(scaled(450), 319)
        XCTAssertEqual(scaled(810), 615)
    }

    func testTheCurveIsSymmetricForBlack() {
        for cp in [1, 36, 100, 250, 450, 810, 1500] {
            XCTAssertEqual(scaled(-cp), -scaled(cp), "cp \(cp)")
        }
    }

    /// Une échelle qui s'inverse ou fait du surplace réordonnerait les coups : elle doit croître.
    func testTheCurveIsStrictlyIncreasingFromZeroToTwoThousand() {
        var previous = scaled(0)
        for cp in 1...2000 {
            let scaled = scaled(cp)
            XCTAssertGreaterThanOrEqual(scaled, previous, "recul en cp \(cp)")
            previous = scaled
        }
        XCTAssertGreaterThan(scaled(2000), scaled(1000))
    }

    func testTablebaseWinsAndMatesAreNeverTouched() {
        XCTAssertEqual(scaled(20000 - 12), 20000 - 12)
        XCTAssertEqual(scaled(-20000 + 7), -20000 + 7)
        XCTAssertEqual(scaled(10000), 10000)
    }

    /// Jamais plus grand que l'original au-delà de l'égalité : la 19 gonfle, on ne gonfle pas encore.
    func testNoAdvantageIsInflated() {
        for cp in stride(from: 150, through: 3000, by: 25) {
            XCTAssertLessThanOrEqual(scaled(cp), cp, "cp \(cp)")
        }
    }
}
