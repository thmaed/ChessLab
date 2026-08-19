import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// L'entraînement LIBRE des finales : l'arbitrage au verdict, pas au coup.
///
/// Tout passe par des fournisseurs FACTICES (verdicts scriptés par FEN,
/// défense scriptée) : ces tests prouvent la MÉCANIQUE — acceptation,
/// reprise, correction, fins de partie — pas la qualité du moteur, qui
/// n'est pas convoquée ici.
@MainActor
struct EndgameFreeTrainViewModelTests {

    // MARK: Fabriques

    /// Arbitre scripté : verdict par FEN (préfixe suffisant), et un meilleur
    /// coup optionnel. Les FEN non scriptées reçoivent `fallback`.
    final class FakeJudge: EndgameVerdictJudging {
        var byFENPrefix: [(prefix: String, assessment: EndgameAssessment)] = []
        var fallback: EndgameAssessment?
        private(set) var callCount = 0

        func assess(fen: String) async -> EndgameAssessment? {
            callCount += 1
            for entry in byFENPrefix where fen.hasPrefix(entry.prefix) {
                return entry.assessment
            }
            return fallback
        }
    }

    /// Défense scriptée : rend les coups UCI dans l'ordre.
    final class FakeOpponent: EndgameOpponentMoving {
        var moves: [String]
        private(set) var callCount = 0
        init(_ moves: [String] = []) { self.moves = moves }
        func reply(fen: String) async -> String? {
            callCount += 1
            return moves.isEmpty ? nil : moves.removeFirst()
        }
    }

    /// Cours minimal : dame contre roi, camp blanc. Le GRAPHE du cours est
    /// sans importance ici (le mode libre ne le consulte pas) — seule la
    /// racine et le camp comptent.
    private func queenCourse(rootFEN: String = "7k/8/5K2/8/8/8/8/6Q1 w - - 0 1") -> OpeningCourse {
        let key = OpeningFENKey.normalize(rootFEN) ?? rootFEN
        var course = OpeningCourse(
            id: "test-free-endgame", name: "Test Free Endgame",
            side: .white, rootFEN: key,
            positions: [key: PositionNode(fen: key, moves: [])]
        )
        course.kind = "endgame"
        return course
    }

    private func makeModel(
        rootFEN: String = "7k/8/5K2/8/8/8/8/6Q1 w - - 0 1",
        judge: FakeJudge, opponent: FakeOpponent
    ) -> EndgameFreeTrainViewModel {
        EndgameFreeTrainViewModel(course: queenCourse(rootFEN: rootFEN), judge: judge, opponent: opponent)
    }

    private func scratchAfter(_ vm: EndgameFreeTrainViewModel, from: Square, to: Square) -> (Board, Move)? {
        var scratch = vm.board
        guard let move = scratch.move(pieceAt: from, to: to) else { return nil }
        return (scratch, move)
    }

    // MARK: Démarrage

    @Test func startEstablishesTheBaselineVerdict() async {
        let judge = FakeJudge()
        judge.fallback = EndgameAssessment(verdict: .win, bestLan: "g1g8")
        let vm = makeModel(judge: judge, opponent: FakeOpponent())

        await vm.start()

        #expect(vm.phase == .awaiting)
        #expect(vm.baselineVerdict == .win)
        #expect(vm.isUserTurn)
    }

    @Test func aDeadJudgeSurfacesTheUnavailableState() async {
        let vm = makeModel(judge: FakeJudge(), opponent: FakeOpponent())
        await vm.start()
        #expect(vm.phase == .unavailable)
    }

    // MARK: Arbitrage

    @Test func aVerdictPreservingMoveIsCommittedAndTheDefenceReplies() async {
        let judge = FakeJudge()
        // Toute position évaluée : gagnante pour le camp au trait quand c'est
        // aux Blancs, perdante quand c'est aux Noirs — un gain blanc stable.
        judge.byFENPrefix = []
        judge.fallback = nil
        let vm = makeModel(judge: judge, opponent: FakeOpponent(["h8h7"]))

        // Baseline : gagnant POV Blancs (trait aux Blancs à la racine).
        judge.fallback = EndgameAssessment(verdict: .win, bestLan: "g1g7")
        await vm.start()
        #expect(vm.baselineVerdict == .win)

        // Le coup joué (Qg2, coup calme — PAS Qg7 qui serait mat et
        // court-circuiterait l'arbitre) : après lui, trait aux Noirs, verdict
        // POV Noirs = perdant → POV utilisateur = gagnant → préservé.
        judge.fallback = EndgameAssessment(verdict: .loss, bestLan: nil)
        guard let (scratch, move) = scratchAfter(vm, from: Square("g1"), to: Square("g2")) else {
            Issue.record("coup de préparation illégal")
            return
        }
        await vm.arbitrate(scratch: scratch, move: move)

        // Accepté, la défense a répondu h8h7, et l'utilisateur reprend la main
        // sur une baseline rafraîchie.
        #expect(vm.playedSANs.count == 2)
        #expect(vm.phase == .awaiting)
        #expect(vm.slipCount == 0)
        #expect(vm.isUserTurn)
    }

    @Test func aVerdictDroppingMoveIsTakenBackNotCommitted() async {
        let judge = FakeJudge()
        let vm = makeModel(judge: judge, opponent: FakeOpponent())

        judge.fallback = EndgameAssessment(verdict: .win, bestLan: "g1g7")
        await vm.start()

        let fenBefore = vm.board.position.fen
        // Après le coup : nulle POV camp au trait (Noirs) → nulle POV Blancs
        // aussi → le gain est lâché.
        judge.fallback = EndgameAssessment(verdict: .draw, bestLan: nil)
        guard let (scratch, move) = scratchAfter(vm, from: Square("g1"), to: Square("a1")) else {
            Issue.record("coup de préparation illégal")
            return
        }
        await vm.arbitrate(scratch: scratch, move: move)

        #expect(vm.phase == .slipped)
        #expect(vm.slipFrom == .win)
        #expect(vm.slipTo == .draw)
        #expect(vm.slipCount == 1)
        // Le PLATEAU n'a pas bougé : le coup fautif n'est jamais commité.
        #expect(vm.board.position.fen == fenBefore)
        #expect(vm.playedSANs.isEmpty)
        // La flèche de correction pointe le meilleur coup de l'arbitre.
        #expect(vm.hintMoves.count == 1)
    }

    @Test func retryAfterSlipReturnsToTheSamePosition() async {
        let judge = FakeJudge()
        let vm = makeModel(judge: judge, opponent: FakeOpponent())
        judge.fallback = EndgameAssessment(verdict: .win, bestLan: "g1g7")
        await vm.start()
        judge.fallback = EndgameAssessment(verdict: .draw, bestLan: nil)
        guard let (scratch, move) = scratchAfter(vm, from: Square("g1"), to: Square("a1")) else { return }
        await vm.arbitrate(scratch: scratch, move: move)

        vm.retryAfterSlip()

        #expect(vm.phase == .awaiting)
        #expect(vm.slipFrom == nil)
        #expect(vm.hintMoves.isEmpty)
        #expect(vm.isUserTurn)
        // Le compteur de reprises, lui, RESTE : c'est le bilan honnête.
        #expect(vm.slipCount == 1)
    }

    @Test func playBestAfterSlipAppliesTheArbitersMove() async {
        let judge = FakeJudge()
        let vm = makeModel(judge: judge, opponent: FakeOpponent(["h8h7"]))
        // Meilleur coup CALME (Qg2) : un meilleur coup qui materait (Qg7#)
        // finirait la partie au lieu de tester la reprise de flux.
        judge.fallback = EndgameAssessment(verdict: .win, bestLan: "g1g2")
        await vm.start()
        judge.fallback = EndgameAssessment(verdict: .draw, bestLan: nil)
        guard let (scratch, move) = scratchAfter(vm, from: Square("g1"), to: Square("a1")) else { return }
        await vm.arbitrate(scratch: scratch, move: move)
        #expect(vm.phase == .slipped)

        judge.fallback = EndgameAssessment(verdict: .win, bestLan: "g2g8")
        await vm.playBestAfterSlipAndContinue()

        // Le meilleur coup (Qg2) est sur l'échiquier, la défense a répondu.
        #expect(vm.playedSANs.first == "Qg2")
        #expect(vm.playedSANs.count == 2)
        #expect(vm.phase == .awaiting)
    }

    @Test func theDefenceReusesTheArbitersBestLineWithoutASecondSearch() async {
        let judge = FakeJudge()
        let opponent = FakeOpponent(["zzzz"])  // sentinelle : ne doit JAMAIS servir
        let vm = makeModel(judge: judge, opponent: opponent)

        judge.fallback = EndgameAssessment(verdict: .win, bestLan: "g1g7")
        await vm.start()

        // L'éval d'arbitrage (POV défense) fournit la riposte Kh7 : elle est
        // rejouée telle quelle — aucune seconde recherche.
        judge.fallback = EndgameAssessment(verdict: .loss, bestLan: "h8h7")
        guard let (scratch, move) = scratchAfter(vm, from: Square("g1"), to: Square("g2")) else { return }
        await vm.arbitrate(scratch: scratch, move: move)

        #expect(vm.playedSANs.count == 2)
        #expect(vm.playedSANs.last == "Kh7")
        #expect(opponent.callCount == 0)
        #expect(vm.phase == .awaiting)
    }

    // MARK: Fins de partie par les règles

    @Test func deliveringCheckmateFinishesWithoutConsultingTheJudge() async {
        let judge = FakeJudge()
        // Dame en g7 : mat immédiat (roi h8 coincé, roi blanc f6 soutient).
        judge.fallback = EndgameAssessment(verdict: .win, bestLan: "g1g7")
        let vm = makeModel(judge: judge, opponent: FakeOpponent())
        await vm.start()
        let callsBefore = judge.callCount

        guard let (scratch, move) = scratchAfter(vm, from: Square("g1"), to: Square("g7")) else { return }
        // Qg7# — ChessKit marque l'état checkmate sur le scratch.
        guard case .checkmate = scratch.state else {
            Issue.record("la position de test devait être un mat en un")
            return
        }
        await vm.arbitrate(scratch: scratch, move: move)

        #expect(vm.phase == .finished)
        #expect(vm.outcome?.winner == .white)
        // Aucune évaluation demandée pour un mat : les règles suffisent.
        #expect(judge.callCount == callsBefore)
    }

    @Test func stalematingFromAWinningBaselineCountsAsASlip() async {
        // Roi noir a8, pion a7 BLOQUÉ par le roi blanc a6 (sinon a7-a6
        // resterait jouable et il n'y aurait pas pat) ; Qh2-c7 : le pat
        // classique de la dame trop gourmande, vérifié python-chess.
        let judge = FakeJudge()
        judge.fallback = EndgameAssessment(verdict: .win, bestLan: nil)
        let vm = makeModel(rootFEN: "k7/p7/K7/8/8/8/7Q/8 w - - 0 1", judge: judge, opponent: FakeOpponent())
        await vm.start()

        guard let (scratch, move) = scratchAfter(vm, from: Square("h2"), to: Square("c7")) else { return }
        guard case .draw = scratch.state else {
            Issue.record("la position de test devait être un pat en un")
            return
        }
        await vm.arbitrate(scratch: scratch, move: move)

        #expect(vm.phase == .slipped)
        #expect(vm.slipFrom == .win)
        #expect(vm.slipTo == .draw)
        #expect(vm.playedSANs.isEmpty)
    }

    // MARK: Point de vue (cours côté noir)

    @Test func baselineIsFlippedForABlackSideCourse() async {
        // Cours côté NOIR, trait aux Blancs à la racine : la défense (Blancs)
        // joue d'abord, puis la baseline est POV Noirs.
        let judge = FakeJudge()
        // Position Philidor-like simplifiée : évaluations scriptées.
        let root = "4k3/8/4K3/4P3/8/8/8/7r b - - 0 1"
        let key = OpeningFENKey.normalize(root) ?? root
        var course = OpeningCourse(
            id: "test-black-defence", name: "Test Black Defence",
            side: .black, rootFEN: key,
            positions: [key: PositionNode(fen: key, moves: [])]
        )
        course.kind = "endgame"
        let vm = EndgameFreeTrainViewModel(course: course, judge: judge, opponent: FakeOpponent())

        // Trait aux NOIRS à la racine (camp de l'utilisateur) : verdict rendu
        // POV camp au trait = POV utilisateur, sans retournement.
        judge.fallback = EndgameAssessment(verdict: .draw, bestLan: nil)
        await vm.start()

        #expect(vm.baselineVerdict == .draw)
        #expect(vm.isUserTurn)
        #expect(vm.orientation == .black)
    }
}
