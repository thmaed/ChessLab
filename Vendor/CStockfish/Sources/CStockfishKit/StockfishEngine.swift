import CStockfish
import Foundation

/// Moteur Stockfish embarqué, piloté en process via ``CStockfish``.
///
/// Expose la sortie UCI en un ``AsyncStream`` de LIGNES brutes (le parsing en
/// ``EngineResponse`` structuré est fait plus haut, côté app). Le transport
/// (thread dédié, redirection des flux C++) vit dans le shim C++ ; ici on ne
/// fait que relayer.
///
/// - important: **Un seul moteur par process** (Stockfish a un état global).
///   Créer une seconde instance sans arrêter la première n'a pas de sens ;
///   ``start(binaryPath:)`` est sans effet si un moteur tourne déjà.
public final class StockfishEngine: @unchecked Sendable {

    /// Lignes de sortie UCI, dans l'ordre d'émission. Un seul consommateur.
    public let lines: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    public init() {
        var cont: AsyncStream<String>.Continuation!
        lines = AsyncStream(bufferingPolicy: .unbounded) { cont = $0 }
        continuation = cont
    }

    /// Démarre le moteur. `binaryPath` : chemin fictif dont le DOSSIER contient
    /// les réseaux `nn-*.nnue` (le dossier des ressources du bundle).
    public func start(binaryPath: String) {
        // `Unmanaged` : on passe `self` au callback C sans le faire retenir en
        // boucle. L'instance vit tant que le moteur tourne (garanti par l'app).
        let context = Unmanaged.passUnretained(self).toOpaque()
        binaryPath.withCString { cPath in
            cstockfish_start(cPath, { line, ctx in
                guard let line, let ctx else { return }
                let engine = Unmanaged<StockfishEngine>.fromOpaque(ctx).takeUnretainedValue()
                engine.continuation.yield(String(cString: line))
            }, context)
        }
    }

    /// Envoie une commande UCI (sans le saut de ligne, ajouté par le shim).
    public func send(_ command: String) {
        command.withCString { cstockfish_send($0) }
    }

    /// Arrête le moteur (`quit` + join du thread) et clôt le flux.
    public func stop() {
        cstockfish_stop()
        continuation.finish()
    }

    public var isRunning: Bool {
        cstockfish_is_running() != 0
    }
}
