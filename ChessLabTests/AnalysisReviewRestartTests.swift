import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// La revue d'une partie doit **finir par avoir lieu**.
///
/// Symptôme rapporté le 14/08/2026 : « je viens de finir une partie, et quand
/// j'ai cliqué sur analyse, l'app ne m'a pas affiché le graphique ni
/// pré-calculé tous les coups ; à la place le message *Moteur en attente*
/// était affiché ». Intermittent — la partie suivante a fonctionné.
///
/// Ce que la lecture du code montre : `classifyMainLine()` est mis en FILE par
/// `setupEngine()`, et son maillon commence par `guard !self.isTornDown`. Si
/// l'écran est marqué disparu pendant que ce maillon attend son tour (le
/// démarrage du moteur qui le précède prend ~1 s : réseau NNUE de 78 Mo), la
/// classification est **abandonnée en silence**. Et rien ne la redemande
/// jamais : `handleViewAppear()` ne relance `setupEngine()` que si le moteur
/// avait été LIBÉRÉ en partant, ce qui n'est pas le cas ici, et sa branche de
/// revue se contente d'afficher une éval en cache — un cache vide.
///
/// L'écran reste alors indéfiniment sur « Moteur en attente » : moteur bien
/// vivant (donc pas de bannière « Moteur indisponible »), aucune évaluation,
/// aucune courbe.
///
/// - important: Moteur RÉEL, donc gated comme les autres tests d'intégration
/// moteur du dépôt (Stockfish est unique par process et coûte ~1 s de
/// démarrage). Lancer :
/// `TEST_RUNNER_ENGINE_INTEGRATION=1 xcodebuild test -scheme ChessLab -destination '…' -only-testing:ChessLabTests/AnalysisReviewRestartTests`
@Suite(.serialized)
struct AnalysisReviewRestartTests {

    /// PGN d'une partie courte et terminée, comme en produit ``PGNExport``.
    private static func shortGamePGN() -> String {
        pgn(forSANs: ["e4", "e5", "Nf3", "Nc6"])
    }

    /// Partie assez LONGUE pour qu'on puisse la quitter en cours de revue.
    /// Avec quatre coups, la classification se termine avant même qu'un test
    /// ait le temps d'appeler `handleViewDisappear()` — il passait alors sans
    /// rien prouver.
    private static let longGameSANs: [String] = [
        "e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4", "Nf6", "O-O", "Be7",
        "Re1", "b5", "Bb3", "d6", "c3", "O-O", "h3", "Nb8", "d4", "Nbd7",
    ]

    private static func longGamePGN() -> String {
        pgn(forSANs: longGameSANs)
    }

    private static func pgn(forSANs sans: [String]) -> String {
        var game = Game()
        var idx = game.startingIndex
        for san in sans {
            idx = game.make(move: san, from: idx)
        }
        game.tags.result = "*"
        return PGNExport.pgn(for: game)
    }

    /// Attente active bornée : la classification passe par la file moteur, son
    /// délai dépend de la machine. Sort dès que la condition est vraie.
    @MainActor
    private func wait(upTo seconds: TimeInterval, until condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    /// **Le bug.** L'écran signale sa disparition avant que le maillon de
    /// classification n'ait pu tourner, puis revient. La revue doit avoir lieu.
    ///
    /// La fenêtre est reproduite de façon déterministe : `handleViewDisappear()`
    /// est appelé alors que `engine` est encore `nil` (le démarrage est en
    /// cours dans la file). Sa tâche sort donc sur `guard let engine` sans rien
    /// libérer — `wasEngineReleasedOnDisappear` reste faux — mais `isTornDown`,
    /// lui, reste VRAI, et c'est lui que le maillon suivant consulte.
    @MainActor
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENGINE_INTEGRATION"] == "1"))
    func aReviewSkippedWhileTheScreenWasAwayIsRestartedOnReturn() async throws {
        let viewModel = AnalysisViewModel(source: .pgn(Self.shortGamePGN()))
        #expect(viewModel.isGameReview, "prérequis : le PGN doit être lu comme une revue")

        // Dans la fenêtre : le moteur démarre, la classification est enfilée
        // derrière, et l'écran est déjà marqué disparu quand elle démarre.
        viewModel.handleViewDisappear()

        // Laisse la file se vider : démarrage moteur (~1 s) puis maillon de
        // classification, qui doit sortir aussitôt sur `isTornDown`.
        try await Task.sleep(nanoseconds: 12_000_000_000)
        #expect(
            viewModel.moveEvaluations.isEmpty,
            "prérequis de la reproduction : la classification a bien été sautée"
        )

        // Retour sur l'écran. C'est ICI que tout doit repartir.
        viewModel.handleViewAppear()

        await wait(upTo: 90) { !viewModel.moveEvaluations.isEmpty }

        #expect(
            !viewModel.moveEvaluations.isEmpty,
            """
            la revue n'a jamais lieu : ni courbe d'évaluation, ni coups classés, \
            et l'écran reste sur « Moteur en attente » sans que rien ne la redemande
            """
        )
        #expect(
            viewModel.isEngineUnavailable == false,
            "le moteur est vivant — c'est bien pourquoi aucune bannière n'alerte l'utilisateur"
        )

        viewModel.handleViewDisappear()
    }

    /// Cas jumeau, plus banal : l'utilisateur quitte l'écran **pendant** la
    /// revue puis revient. Les coups déjà classés sont en cache, les autres
    /// doivent être repris — sans quoi la partie reste éternellement à
    /// moitié analysée, courbe tronquée comprise.
    @MainActor
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENGINE_INTEGRATION"] == "1"))
    func aReviewLeftHalfwayIsResumedOnReturn() async throws {
        let total = Self.longGameSANs.count
        let viewModel = AnalysisViewModel(source: .pgn(Self.longGamePGN()))

        // Quitte l'écran dès le PREMIER coup classé : la boucle sort sur
        // `isTornDown` et laisse la ligne largement incomplète.
        await wait(upTo: 90) { !viewModel.moveEvaluations.isEmpty }
        try #require(!viewModel.moveEvaluations.isEmpty, "la revue doit avoir démarré")
        viewModel.handleViewDisappear()
        try await Task.sleep(nanoseconds: 2_000_000_000)

        let classifiedBeforeLeaving = viewModel.moveEvaluations.count
        try #require(
            classifiedBeforeLeaving < total,
            "reproduction invalide : la revue a fini avant qu'on quitte l'écran"
        )

        viewModel.handleViewAppear()
        await wait(upTo: 180) { viewModel.moveEvaluations.count == total }

        #expect(
            viewModel.moveEvaluations.count == total,
            "revue restée incomplète : \(viewModel.moveEvaluations.count)/\(total) coups classés (\(classifiedBeforeLeaving) avant de quitter)"
        )

        viewModel.handleViewDisappear()
    }
}
