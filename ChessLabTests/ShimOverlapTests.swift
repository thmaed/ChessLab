import CFairyStockfishKit
import CStockfishKit
import Foundation
import Testing
@testable import ChessLab

/// Le CHEVAUCHEMENT des deux moteurs — la racine des trois modes de
/// défaillance trouvés les 30 et 31/08.
///
/// Les deux shims détournent le MÊME `std::cin`/`std::cout` globaux. Quand
/// les moteurs se chevauchent un instant, trois choses pouvaient arriver :
/// une corruption de tas côté sortie (corrigée par verrou le 30/08), un flux
/// Swift mort (corrigé le même jour), et — trouvé le 31/08 en voyant une
/// suite PENDUE 5 h 40 — un GEL : `getline` lit le tampon COURANT de
/// `std::cin`, que l'autre shim a remplacé ; le « quit » de l'arrêt part
/// donc dans un tampon que le fil moteur n'écoute pas, et le `join()`
/// aveugle gelait le MainActor pour toujours, `deinit` compris.
///
/// Cette suite REPRODUIT le chevauchement exprès et exige que l'arrêt soit
/// borné. Elle se nettoie de son mieux : un fil moteur détaché peut
/// subsister (c'est le prix du dégel), et le shim refuse alors de
/// redémarrer tant qu'il vit — la purge le fait sortir.
@Suite(.serialized)
@MainActor
struct ShimOverlapTests {

    private var stockfishPath: String { (Bundle.main.resourcePath ?? "") + "/stockfish" }
    private var fairyPath: String { (Bundle.main.resourcePath ?? "") + "/fairystockfish" }

    @Test("Arrêter un moteur rendu sourd par le chevauchement ne gèle plus")
    func stoppingADeafenedEngineIsBounded() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            // Avec de la PATIENCE au démarrage, comme l'app : ce test parle
            // au C directement, sans la boucle de retry
            // d'`acquireEngineProcess` — or sous la charge d'une suite
            // complète, le moteur du test précédent peut mettre quelques
            // instants à rendre le process, et un unique essai échouait à
            // tort (constaté le 31/08, vert en isolation).
            func patientStart(_ start: @MainActor () -> Bool) async -> Bool {
                let deadline = Date().addingTimeInterval(8)
                while Date() < deadline {
                    if await start() { return true }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                return false
            }

            let standard = StockfishEngine()
            let standardStarted = await patientStart { standard.start(binaryPath: self.stockfishPath) }
            try #require(standardStarted, "démarrage standard refusé")

            // Le CHEVAUCHEMENT, volontaire : Fairy démarre par-dessus et
            // détourne std::cin. (Les gardes de l'app l'empêchent en temps
            // normal ; le défaut ne se produit que quand elles sont prises
            // de vitesse — c'est ce qu'on simule.)
            let fairy = FairyStockfishEngine()
            let fairyStarted = await patientStart { fairy.start(binaryPath: self.fairyPath) }
            try #require(fairyStarted, "démarrage fairy refusé")

            // Faire BOUCLER le fil standard : il lit une commande dans SON
            // tampon (où il attendait déjà), puis son `getline` suivant lit
            // le tampon COURANT de std::cin — celui de Fairy. Le voilà sourd.
            standard.send("uci")
            try await Task.sleep(for: .milliseconds(400))

            // AVANT le join borné, cette ligne ne revenait JAMAIS.
            let stopStart = Date()
            standard.stop()
            let stopDuration = Date().timeIntervalSince(stopStart)
            #expect(stopDuration < 5, "l'arrêt a pris \(stopDuration) s — le gel est de retour")

            let fairyStop = Date()
            fairy.stop()
            #expect(Date().timeIntervalSince(fairyStop) < 5, "l'arrêt fairy doit être borné aussi")

            // PURGE : un fil détaché peut rester à l'écoute d'un tampon.
            // Démarrer/arrêter chaque moteur repousse un « quit » dans les
            // tampons concernés jusqu'à ce que les deux shims acceptent de
            // repartir — c'est aussi la preuve que l'app, elle, s'en remet.
            // DEUX cycles propres CONSÉCUTIFS, et pas « chacun a réussi une
            // fois » : un stop de purge peut réveiller le mauvais dormeur
            // (le zombie vole le « quit » du fil neuf) et recréer un fil
            // sourd de l'autre côté. Réussir une fois ne prouve donc rien ;
            // deux tours de suite où les DEUX moteurs démarrent et
            // s'arrêtent sans accroc prouvent que plus personne ne dort.
            var cleanStreak = 0
            let deadline = Date().addingTimeInterval(15)
            while Date() < deadline, cleanStreak < 2 {
                var cycleClean = true
                let standardProbe = StockfishEngine()
                if standardProbe.start(binaryPath: self.stockfishPath) {
                    standardProbe.stop()
                    if StockfishEngine.isProcessBusy { cycleClean = false }
                } else {
                    cycleClean = false
                }
                let fairyProbe = FairyStockfishEngine()
                if fairyProbe.start(binaryPath: self.fairyPath) {
                    fairyProbe.stop()
                    if FairyStockfishEngine.isProcessBusy { cycleClean = false }
                } else {
                    cycleClean = false
                }
                cleanStreak = cycleClean ? cleanStreak + 1 : 0
                try await Task.sleep(for: .milliseconds(200))
            }
            #expect(cleanStreak >= 2,
                    "la purge n'a pas rendu les deux shims démarrables deux cycles de suite")
        }
    }
}
