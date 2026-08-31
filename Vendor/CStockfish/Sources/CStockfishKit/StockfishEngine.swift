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

    /// Vrai si **cette instance-ci** possède le process moteur.
    ///
    /// Sans ce drapeau, `isRunning` lisait l'état GLOBAL du shim : une seconde
    /// instance créée pendant que la première se libérait (les libérations sont
    /// asynchrones — `Task { await engine.stop() }`) se croyait démarrée alors
    /// qu'elle n'avait rien démarré, ne recevait aucune ligne, et voyait sa
    /// banniere « Moteur indisponible » se lever après 5 s de vaine attente.
    private var didStart = false

    /// Démarre le moteur. `binaryPath` : chemin fictif dont le DOSSIER contient
    /// les réseaux `nn-*.nnue` (le dossier des ressources du bundle).
    ///
    /// - returns: `false` si le process est **déjà pris** par une autre
    ///   instance. L'appelant doit alors attendre sa libération, jamais faire
    ///   comme si de rien n'était.
    @discardableResult
    public func start(binaryPath: String) -> Bool {
        // `Unmanaged` : on passe `self` au callback C sans le faire retenir en
        // boucle. L'instance vit tant que le moteur tourne (garanti par l'app).
        let context = Unmanaged.passUnretained(self).toOpaque()
        var code: Int32 = -1
        binaryPath.withCString { cPath in
            code = cstockfish_start(cPath, { line, ctx in
                guard let line, let ctx else { return }
                let engine = Unmanaged<StockfishEngine>.fromOpaque(ctx).takeUnretainedValue()
                engine.continuation.yield(String(cString: line))
            }, context)
        }
        didStart = (code == 0)
        return didStart
    }

    /// Envoie une commande UCI (sans le saut de ligne, ajouté par le shim).
    public func send(_ command: String) {
        command.withCString { cstockfish_send($0) }
    }

    /// Arrête le moteur (`quit` + join du thread) et clôt le flux.
    ///
    /// **Seul le propriétaire arrête.** Une instance qui n'a jamais démarré ne
    /// doit pas couper le process d'une autre : elle clôt son propre flux et
    /// s'arrête là. Sans cette garde, l'instance « fantôme » du bug d'état
    /// global tuait le moteur de l'écran réellement actif en se libérant.
    public func stop() {
        guard didStart else {
            continuation.finish()
            return
        }
        didStart = false
        cstockfish_stop()
        continuation.finish()
    }

    /// Vrai si CETTE instance a démarré le moteur et qu'il tourne toujours.
    public var isRunning: Bool {
        didStart && cstockfish_is_running() != 0
    }

    /// Vrai si un moteur — le nôtre ou celui d'une autre instance — occupe le
    /// process. Sert à savoir s'il faut attendre avant de démarrer.
    /// Aucun fil moteur détaché ne traîne — le shim acceptera un `start`.
    public static var isProcessSettled: Bool {
        cstockfish_is_settled() != 0
    }

    public static var isProcessBusy: Bool {
        cstockfish_is_running() != 0
    }
}
