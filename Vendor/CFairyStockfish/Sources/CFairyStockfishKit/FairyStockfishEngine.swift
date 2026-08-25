import CFairyStockfish
import Foundation

/// Moteur Fairy-Stockfish embarqué, piloté en process via ``CFairyStockfish``
/// — copie conforme de ``StockfishEngine`` (`CStockfishKit`), pour les
/// variantes que le Stockfish standard ne joue pas.
///
/// - important: **Un seul moteur — Stockfish OU Fairy-Stockfish — par
///   process** : les deux se disputent les mêmes flux globaux
///   `std::cin`/`std::cout`. Même discipline que ``StockfishEngine`` :
///   ``start(binaryPath:)`` échoue si un moteur (l'un ou l'autre) tourne
///   déjà.
public final class FairyStockfishEngine: @unchecked Sendable {

    public let lines: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    public init() {
        var cont: AsyncStream<String>.Continuation!
        lines = AsyncStream(bufferingPolicy: .unbounded) { cont = $0 }
        continuation = cont
    }

    private var didStart = false

    @discardableResult
    public func start(binaryPath: String) -> Bool {
        let context = Unmanaged.passUnretained(self).toOpaque()
        var code: Int32 = -1
        binaryPath.withCString { cPath in
            code = cfairystockfish_start(cPath, { line, ctx in
                guard let line, let ctx else { return }
                let engine = Unmanaged<FairyStockfishEngine>.fromOpaque(ctx).takeUnretainedValue()
                engine.continuation.yield(String(cString: line))
            }, context)
        }
        didStart = (code == 0)
        return didStart
    }

    public func send(_ command: String) {
        command.withCString { cfairystockfish_send($0) }
    }

    public func stop() {
        guard didStart else {
            continuation.finish()
            return
        }
        didStart = false
        cfairystockfish_stop()
        continuation.finish()
    }

    public var isRunning: Bool {
        didStart && cfairystockfish_is_running() != 0
    }

    public static var isProcessBusy: Bool {
        cfairystockfish_is_running() != 0
    }
}
