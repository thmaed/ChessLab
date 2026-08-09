import XCTest
@testable import CStockfishKit

final class UCIProtocolTests: XCTestCase {

    func testCommandFormatting() {
        XCTAssertEqual(EngineCommand.uci.uciString, "uci")
        XCTAssertEqual(EngineCommand.stop.uciString, "stop")
        XCTAssertEqual(EngineCommand.setoption(id: "Hash", value: "64").uciString,
                       "setoption name Hash value 64")
        XCTAssertEqual(EngineCommand.position(.fen("8/8/8/8/8/8/8/8 w - - 0 1")).uciString,
                       "position fen 8/8/8/8/8/8/8/8 w - - 0 1")
        XCTAssertEqual(EngineCommand.go(depth: 20).uciString, "go depth 20")
        XCTAssertEqual(EngineCommand.go(movetime: 200).uciString, "go movetime 200")
        XCTAssertEqual(EngineCommand.go(nodes: 300_000).uciString, "go nodes 300000")
        XCTAssertEqual(EngineCommand.go(nodes: 250_000, movetime: 1_500).uciString,
                       "go nodes 250000 movetime 1500")
    }

    func testParseInfoCentipawnAndPV() {
        guard case let .info(info)? = EngineResponse(rawValue:
            "info depth 20 seldepth 28 multipv 1 score cp 34 nodes 123456 time 100 pv e2e4 e7e5 g1f3") else {
            return XCTFail("info non parsée")
        }
        XCTAssertEqual(info.depth, 20)
        XCTAssertEqual(info.seldepth, 28)
        XCTAssertEqual(info.multipv, 1)
        XCTAssertEqual(info.nodes, 123456)
        XCTAssertEqual(info.time, 100)
        XCTAssertEqual(info.score?.cp, 34)
        XCTAssertNil(info.score?.mate)
        XCTAssertEqual(info.pv, ["e2e4", "e7e5", "g1f3"])
    }

    func testParseMate() {
        guard case let .info(info)? = EngineResponse(rawValue: "info depth 30 score mate -2 pv h7h8") else {
            return XCTFail("info mate non parsée")
        }
        XCTAssertEqual(info.score?.mate, -2)
        XCTAssertNil(info.score?.cp)
    }

    func testProgressLineHasNoScore() {
        guard case let .info(info)? = EngineResponse(rawValue:
            "info depth 12 seldepth 18 nodes 120000 nps 900000 time 133") else {
            return XCTFail()
        }
        XCTAssertNil(info.score)
    }

    func testBestmoveAndPonder() {
        XCTAssertEqual(EngineResponse(rawValue: "bestmove e2e4 ponder e7e5"),
                       .bestmove(move: "e2e4", ponder: "e7e5"))
        XCTAssertEqual(EngineResponse(rawValue: "bestmove (none)"),
                       .bestmove(move: "(none)", ponder: nil))
    }

    func testReadyokAndUnknown() {
        XCTAssertEqual(EngineResponse(rawValue: "readyok"), .readyok)
        XCTAssertNil(EngineResponse(rawValue: "id name Stockfish"))
        XCTAssertNil(EngineResponse(rawValue: "uciok"))
    }
}
