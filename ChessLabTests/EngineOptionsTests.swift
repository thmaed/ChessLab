import ChessKitEngine
import Foundation
import Testing
@testable import ChessLab

/// Réglages avancés du moteur (Lot 2.B du final-1407).
///
/// ⚠️ **Ce qu'UCI permet de vérifier, et ce qu'il ne permet pas.** `setoption`
/// n'a aucun accusé de réception, et le moteur n'annonce à l'ouverture que les
/// valeurs par DÉFAUT : on ne peut pas demander à Stockfish combien de threads
/// il utilise. Ce qui est vérifiable — et suffisant — c'est notre moitié du
/// contrat : la bonne commande, avec la bonne valeur, envoyée à un moteur
/// DÉMARRÉ, qui continue de répondre ensuite.
struct EngineOptionsTests {

    // MARK: Traduction threads → coreCount

    /// Le piège du lot : ChessKitEngine envoie `Threads = max(coreCount − 1, 1)`.
    /// Demander 2 threads en passant `coreCount = 2` en donnerait 1.
    @Test func requestedThreadsAreTranslatedIntoChessKitCoreCount() {
        #expect(EngineController.coreCount(forThreads: 2) == 3)
        #expect(EngineController.coreCount(forThreads: 1) == 2)
        #expect(EngineController.coreCount(forThreads: 4) == 5)
    }

    /// La formule de ChessKitEngine, rejouée ici : c'est elle qui donne son
    /// sens au « + 1 ». Si une version future la change, ce test tombe et le
    /// « + 1 » devra bouger.
    @Test(arguments: [1, 2, 3, 4])
    func theTranslationYieldsExactlyTheRequestedThreadCount(requested: Int) {
        let coreCount = EngineController.coreCount(forThreads: requested)
        let threadsSentByChessKitEngine = max(coreCount - 1, 1)

        #expect(threadsSentByChessKitEngine == requested)
    }

    // MARK: Réglages DÉDUITS

    /// Threads et mémoire ne sont plus demandés à l'utilisateur (18/07/2026) :
    /// la bonne valeur dépend de l'appareil, et aucune valeur figée n'est
    /// juste des deux côtés — 4 threads étouffent un appareil à deux cœurs,
    /// 2 brident un iPhone récent.
    @Test func threadsAreDerivedFromTheDeviceAndLeaveHeadroom() {
        let threads = AppSettings.recommendedEngineThreads
        let cores = ProcessInfo.processInfo.activeProcessorCount

        #expect(threads >= 1, "il faut toujours au moins un thread")
        #expect(threads <= 4, "au-delà, sur mobile, le gain part en chaleur")
        #expect(
            threads <= max(1, cores - 2),
            "deux cœurs doivent rester à l'interface et au système"
        )
    }

    @Test func theTranspositionTableIsSizedToTheDeviceRAM() {
        // Désormais adaptatif : 128 Mo là où il y a de la marge, réduit sur
        // appareil modeste (deux instances peuvent cohabiter via « Jouer à
        // partir d'ici », zone jetsam à 128 Mo × 2).
        #expect([32, 64, 128].contains(AppSettings.engineHashMB))
    }

    // MARK: Moteur réel

    /// Démarre un VRAI Stockfish avec les réglages, et vérifie que les
    /// commandes partent bien — puis qu'il calcule toujours.
    ///
    /// Le point non trivial : `Engine.send` ignore EN SILENCE tout ce qui
    /// arrive avant que le moteur ne tourne. Un `Hash` envoyé trop tôt serait
    /// donc parti dans le vide sans le moindre signe.
    ///
    /// ⚠️ **Opt-in** (`ENGINE_INTEGRATION=1`), et ce n'est pas un caprice :
    /// ChessKitEngine n'héberge **qu'un seul Stockfish par processus**, et
    /// d'autres tests unitaires (`BugFixes1407Tests`) construisent des
    /// `PlayViewModel` qui en démarrent un sans jamais l'arrêter. Dans la
    /// suite complète, ce test ne pouvait donc pas obtenir de moteur et
    /// échouait — non pas parce que le produit est cassé, mais parce que la
    /// place était prise. Le rendre tolérant à l'échec l'aurait vidé de son
    /// sens ; le laisser rouge aurait masqué les vraies régressions.
    /// Le lot 6.B (injection d'un moteur simulé) est ce qui débloquera ça pour
    /// de bon.
    ///
    /// Lancer (le préfixe `TEST_RUNNER_` est ce qui fait passer la variable au
    /// processus de test, xcodebuild ne transmet pas son propre
    /// environnement) :
    /// `TEST_RUNNER_ENGINE_INTEGRATION=1 xcodebuild test -scheme ChessLab -destination '…' -only-testing:ChessLabTests/EngineOptionsTests`
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENGINE_INTEGRATION"] == "1"))
    func aRealEngineStartsWithTheRequestedOptionsAndStillPlays() async throws {
        // Borne large : sous la charge d'une suite, le réseau NNUE de 78 Mo
        // met bien plus que les 5 s de l'app à se charger.
        let controller = EngineController(type: .stockfish, startTimeoutMs: 60_000)
        defer { Task { await controller.stop() } }

        let started = await controller.start(threads: 2, hashMB: AppSettings.engineHashMB, multipv: 1)
        try #require(started, "Stockfish devrait démarrer")

        let coreCount = await controller.lastStartCoreCount
        #expect(coreCount == 3, "2 threads voulus → coreCount 3, que ChessKitEngine traduira en Threads 2")

        let sent = await controller.sentCommands
        #expect(
            sent.contains(.setoption(id: "Hash", value: "\(AppSettings.engineHashMB)")),
            "Hash (dimensionné à la RAM) doit être envoyé au démarrage"
        )

        // Et il calcule toujours : des options refusées ou une table de
        // transposition impossible à allouer se verraient ici.
        let best = await controller.computeBestMove(
            fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            setupCommands: [], movetimeMs: 200, depth: nil
        )
        #expect(best?.lan.count ?? 0 >= 4, "le moteur doit rendre un coup après ces réglages")
    }
}
