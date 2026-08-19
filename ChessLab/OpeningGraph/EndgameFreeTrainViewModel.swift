import ChessKit
import Foundation
import Observation

/// Verdict théorique d'une position, DU POINT DE VUE DU CAMP AU TRAIT.
enum EndgameVerdict: Equatable {
    case win, draw, loss

    /// Le même verdict, vu de l'autre camp.
    var flipped: EndgameVerdict {
        switch self {
        case .win: .loss
        case .draw: .draw
        case .loss: .win
        }
    }

    /// Libellé localisé (« gagnant », « nulle », « perdant »).
    var displayLabel: String {
        switch self {
        case .win: LocalizationController.string("gagnant")
        case .draw: LocalizationController.string("nulle")
        case .loss: LocalizationController.string("perdant")
        }
    }
}

/// Ce que l'arbitre sait dire d'une position : son verdict, et le meilleur
/// coup s'il en connaît un (sert de correction après un coup qui lâche).
struct EndgameAssessment: Equatable {
    let verdict: EndgameVerdict
    let bestLan: String?
}

/// L'ARBITRE de l'entraînement libre : qui décide du verdict d'une position.
///
/// Un protocole, et non le moteur en dur, parce que la promesse d'honnêteté
/// du module varie selon la source : le moteur VÉRIFIE (seuil en centipions,
/// faillible aux frontières), une table de finales PROUVERAIT. L'UI affiche
/// « vérifié moteur » tant que la seule implémentation est le moteur ; un
/// fournisseur exact (tables Syzygy embarquées ou en ligne — décision
/// produit : ~177 Mo à embarquer, ou premier appel réseau de l'app) se
/// branchera ici sans toucher au reste.
@MainActor
protocol EndgameVerdictJudging {
    func assess(fen: String) async -> EndgameAssessment?
}

/// La DÉFENSE : qui joue les coups de l'adversaire.
@MainActor
protocol EndgameOpponentMoving {
    /// Coup UCI (« e2e4 ») de l'adversaire dans cette position, ou `nil` si
    /// le fournisseur est en panne.
    func reply(fen: String) async -> String?
}

/// Entraînement LIBRE d'une finale : l'utilisateur joue SON camp depuis la
/// position du cours, l'adversaire défend au mieux, et chaque coup joué est
/// arbitré — non pas « est-ce LE coup de la leçon ? » mais « ce coup
/// préserve-t-il le verdict théorique ? ». Tout coup gagnant est accepté ;
/// un coup qui lâche le gain (ou la nulle) est repris, avec le verdict
/// avant/après en toutes lettres.
///
/// C'est le complément du mode guidé (``OpeningTrainViewModel``) : le guidé
/// enseigne UNE technique, le libre vérifie qu'on sait CONCLURE — n'importe
/// comment, pourvu que ce soit théoriquement juste.
///
/// Pas de répétition espacée ici (voulu) : la FSRS note la restitution d'une
/// ligne précise ; une conversion libre réussie n'est pas une « carte ».
@Observable
@MainActor
final class EndgameFreeTrainViewModel {
    enum Phase: Equatable {
        case preparing        // premier verdict en cours de calcul
        case awaiting         // à l'utilisateur de jouer
        case arbitrating      // coup joué, verdict en cours
        case opponentMoving   // coup accepté, la défense réfléchit
        case slipped          // le coup lâche le verdict : correction affichée
        case finished         // mat, pat, nulle — fin de partie
        case unavailable      // arbitre/défense en panne (moteur)
    }

    private var judge: EndgameVerdictJudging
    private var opponent: EndgameOpponentMoving
    let course: OpeningCourse

    /// Rebranche l'arbitre et la défense après un redémarrage du moteur
    /// (bouton « Réessayer ») : le view model survit dans la ``SessionStore``,
    /// le process moteur non.
    func replaceProviders(judge: EndgameVerdictJudging, opponent: EndgameOpponentMoving) {
        self.judge = judge
        self.opponent = opponent
    }

    private(set) var board: Board
    private(set) var orientation: Piece.Color
    private(set) var lastMove: Move?
    private(set) var playedSANs: [String] = []
    private(set) var phase: Phase = .preparing
    private(set) var outcome: GameOutcome?

    /// Verdict de la position COURANTE (POV utilisateur), affiché en bandeau
    /// — c'est l'objectif à tenir (« gagnant » : à convertir sans le lâcher).
    private(set) var baselineVerdict: EndgameVerdict?
    /// Après un coup qui lâche : les deux verdicts, pour le message.
    private(set) var slipFrom: EndgameVerdict?
    private(set) var slipTo: EndgameVerdict?
    /// Nombre de coups repris (affiché en fin de séance, honnêteté du bilan).
    private(set) var slipCount = 0

    var selectedSquare: Square?
    var legalTargetSquares: [Square] = []
    var pendingPromotion: PendingPromotion?
    private(set) var hintMoves: [HintMove] = []

    /// Meilleur coup connu de la position courante (celui de l'arbitre) —
    /// alimenté par l'évaluation de base, montré seulement après un coup
    /// repris, à la demande.
    private var bestLanAtBaseline: String?

    /// Jeton d'ÉPOQUE : incrémenté à chaque arbitrage ET à chaque
    /// redémarrage. Toute continuation (verdict, riposte) qui revient d'un
    /// `await` vérifie qu'elle appartient encore à l'époque courante —
    /// sinon un `restart()` pendant la réflexion de la défense laissait la
    /// riposte de l'ANCIENNE partie s'appliquer à la nouvelle (revue du
    /// 19/08).
    private var arbitrationToken = 0

    var userColor: Piece.Color { course.side.color }
    var isUserTurn: Bool {
        phase == .awaiting && pendingPromotion == nil
            && board.position.sideToMove == userColor
    }

    init(
        course: OpeningCourse,
        judge: EndgameVerdictJudging,
        opponent: EndgameOpponentMoving
    ) {
        self.course = course
        self.judge = judge
        self.opponent = opponent
        let position = OpeningFENKey.position(from: course.rootFEN) ?? .standard
        self.board = Board(position: position)
        self.orientation = course.side.color
    }

    /// Premier verdict + éventuelle riposte si le trait est à l'adversaire
    /// dans la position du cours (rare mais légal : cours « au trait
    /// adverse »).
    func start() async {
        await refreshBaseline()
        guard phase != .unavailable else { return }
        if board.position.sideToMove != userColor, outcome == nil {
            await playOpponentReply()
        }
    }

    // MARK: Interaction plateau (même contrat que l'entraîneur guidé)

    func selectSquare(_ square: Square) {
        guard isUserTurn else { return }
        if let selected = selectedSquare {
            if square == selected {
                clearSelection()
                return
            }
            if legalTargetSquares.contains(square) {
                attemptMove(from: selected, to: square)
                return
            }
        }
        guard board.position.piece(at: square)?.color == board.position.sideToMove else {
            clearSelection()
            return
        }
        selectedSquare = square
        legalTargetSquares = board.legalMoves(forPieceAt: square)
    }

    func clearSelection() {
        selectedSquare = nil
        legalTargetSquares = []
    }

    func attemptMove(from start: Square, to end: Square) {
        guard
            isUserTurn,
            board.position.piece(at: start)?.color == board.position.sideToMove,
            board.canMove(pieceAt: start, to: end)
        else {
            Haptics.illegal()
            clearSelection()
            return
        }
        var scratch = board
        guard let move = scratch.move(pieceAt: start, to: end) else {
            clearSelection()
            return
        }
        clearSelection()
        if case .promotion = scratch.state {
            pendingPromotion = PendingPromotion(scratch: scratch, move: move)
            return
        }
        Task { await arbitrate(scratch: scratch, move: move) }
    }

    func completePromotion(to kind: Piece.Kind) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        var scratch = pending.scratch
        let move = scratch.completePromotion(of: pending.move, to: kind)
        Task { await arbitrate(scratch: scratch, move: move) }
    }

    func cancelPromotion() { pendingPromotion = nil }

    // MARK: Arbitrage

    /// Le cœur du mode : le coup est-il théoriquement à la hauteur ?
    ///
    /// Un verdict qui S'AMÉLIORE est accepté sans commentaire : sous jeu
    /// optimal c'est impossible, donc c'est l'ARBITRE qui se corrige
    /// (bruit du moteur aux frontières) — on ne félicite pas l'utilisateur
    /// d'un artefact, on ne l'accuse surtout pas.
    ///
    /// Interne (pas `private`) : c'est la couture de test — les tests
    /// construisent le `scratch` eux-mêmes et attendent l'arbitrage sans
    /// dépendre du `Task` que crée `attemptMove`.
    func arbitrate(scratch: Board, move: Move) async {
        guard let baseline = baselineVerdict else { return }
        phase = .arbitrating
        arbitrationToken &+= 1
        let token = arbitrationToken

        // Fins de partie par les RÈGLES : pas besoin d'arbitre.
        if let ended = GameOutcome.fromBoardState(scratch.state) {
            // Le pat en position gagnante EST le coup qui lâche — le cas
            // d'école (dame contre roi dépouillé). Il se voit sans moteur.
            if ended.winner == nil, baseline == .win {
                presentSlip(from: .win, to: .draw)
                return
            }
            commit(scratch: scratch, move: move)
            finish(with: ended)
            return
        }

        guard let after = await judge.assess(fen: scratch.position.fen) else {
            guard token == arbitrationToken else { return }
            phase = .unavailable
            return
        }
        guard token == arbitrationToken else { return }

        // `after` est POV adversaire (c'est à lui de jouer) : on retourne.
        let achieved = after.verdict.flipped
        if isDegradation(from: baseline, to: achieved) {
            presentSlip(from: baseline, to: achieved)
            return
        }

        commit(scratch: scratch, move: move)
        // L'évaluation d'arbitrage a DÉJÀ calculé le meilleur coup du camp
        // au trait dans cette position — c'est-à-dire la riposte de la
        // défense : la rejouer épargne une seconde recherche identique
        // (~500 ms par coup accepté, revue du 19/08).
        await playOpponentReply(preferring: after.bestLan)
    }

    private func isDegradation(from before: EndgameVerdict, to after: EndgameVerdict) -> Bool {
        func rank(_ verdict: EndgameVerdict) -> Int {
            switch verdict {
            case .loss: 0
            case .draw: 1
            case .win: 2
            }
        }
        return rank(after) < rank(before)
    }

    private func presentSlip(from: EndgameVerdict, to: EndgameVerdict) {
        slipFrom = from
        slipTo = to
        slipCount += 1
        if let best = bestLanAtBaseline {
            hintMoves = [arrow(for: best)]
        }
        phase = .slipped
        Haptics.illegal()
    }

    /// « Réessayer » après un coup repris : le plateau n'a jamais bougé, on
    /// efface juste la correction.
    func retryAfterSlip() {
        slipFrom = nil
        slipTo = nil
        hintMoves = []
        phase = .awaiting
    }

    /// « Jouer le meilleur coup » : l'arbitre l'applique et la partie suit.
    func playBestAfterSlip() {
        Task { await playBestAfterSlipAndContinue() }
    }

    /// Couture de test de ``playBestAfterSlip()`` — même corps, attendable.
    func playBestAfterSlipAndContinue() async {
        guard let best = bestLanAtBaseline, let move = applyLan(best) else {
            retryAfterSlip()
            return
        }
        slipFrom = nil
        slipTo = nil
        hintMoves = []
        playedSANs.append(move.san)
        lastMove = move
        if let ended = GameOutcome.fromBoardState(board.state) {
            finish(with: ended)
            return
        }
        await playOpponentReply()
    }

    func restart() {
        let position = OpeningFENKey.position(from: course.rootFEN) ?? .standard
        board = Board(position: position)
        lastMove = nil
        playedSANs = []
        outcome = nil
        slipFrom = nil
        slipTo = nil
        slipCount = 0
        hintMoves = []
        baselineVerdict = nil
        bestLanAtBaseline = nil
        clearSelection()
        pendingPromotion = nil
        arbitrationToken &+= 1  // invalide toute continuation en vol
        phase = .preparing
        Task { await start() }
    }

    // MARK: Défense et cadence

    private func playOpponentReply(preferring preferredLan: String? = nil) async {
        phase = .opponentMoving
        arbitrationToken &+= 1
        let token = arbitrationToken
        // Riposte déjà connue (meilleur coup de l'éval d'arbitrage) : on la
        // joue sans reconsulter la défense. Si elle est absente ou
        // inapplicable (prudence), le fournisseur reste la voie normale.
        if let preferredLan, let move = applyLan(preferredLan) {
            playedSANs.append(move.san)
            lastMove = move
            if let ended = GameOutcome.fromBoardState(board.state) {
                finish(with: ended)
                return
            }
            await refreshBaseline()
            return
        }
        guard let lan = await opponent.reply(fen: board.position.fen) else {
            if token == arbitrationToken { phase = .unavailable }
            return
        }
        guard token == arbitrationToken else { return }
        guard let move = applyLan(lan) else {
            phase = .unavailable
            return
        }
        playedSANs.append(move.san)
        lastMove = move
        if let ended = GameOutcome.fromBoardState(board.state) {
            finish(with: ended)
            return
        }
        await refreshBaseline()
    }

    /// (Re)calcule le verdict de la position courante — l'objectif affiché,
    /// et la référence du prochain arbitrage. Pendant ce calcul l'utilisateur
    /// ne peut pas jouer (phase `preparing`), ce qui évite d'arbitrer contre
    /// une référence périmée.
    private func refreshBaseline() async {
        phase = .preparing
        arbitrationToken &+= 1
        let token = arbitrationToken
        guard let assessment = await judge.assess(fen: board.position.fen) else {
            if token == arbitrationToken { phase = .unavailable }
            return
        }
        guard token == arbitrationToken else { return }
        let mover = board.position.sideToMove
        baselineVerdict = mover == userColor
            ? assessment.verdict : assessment.verdict.flipped
        bestLanAtBaseline = mover == userColor ? assessment.bestLan : nil
        phase = .awaiting
    }

    private func commit(scratch: Board, move: Move) {
        board = scratch
        lastMove = move
        playedSANs.append(move.san)
        hintMoves = []
    }

    private func finish(with outcome: GameOutcome) {
        self.outcome = outcome
        phase = .finished
    }

    private func applyLan(_ lan: String) -> Move? {
        guard lan.count >= 4 else { return nil }
        let from = Square(String(lan.prefix(2)))
        let to = Square(String(lan.dropFirst(2).prefix(2)))
        var scratch = board
        guard let move = scratch.move(pieceAt: from, to: to) else { return nil }
        if case .promotion = scratch.state {
            let kind: Piece.Kind = switch String(lan.dropFirst(4)) {
            case "r": .rook
            case "b": .bishop
            case "n": .knight
            default: .queen
            }
            let promoted = scratch.completePromotion(of: move, to: kind)
            board = scratch
            return promoted
        }
        board = scratch
        return move
    }

    private func arrow(for lan: String) -> HintMove {
        HintMove(
            rank: 1,
            from: Square(String(lan.prefix(2))),
            to: Square(String(lan.dropFirst(2).prefix(2))),
            strength: 1
        )
    }
}

// MARK: - Implémentation moteur (la seule, ce soir)

/// Arbitre ET défenseur adossés au MÊME moteur plein pot : une seule
/// recherche par question, le coup rendu sert de correction et l'éval de
/// verdict. Seuil en centipions identique à celui de l'audit
/// (`audit_endgames.py`, `ENGINE_WIN_CP = 250`) : au-delà, « gagnant » au
/// sens pratique. C'est un VERDICT VÉRIFIÉ, pas prouvé — l'UI le dit.
@MainActor
final class EngineEndgameDriver: EndgameVerdictJudging, EndgameOpponentMoving {
    private let engine: EngineController
    /// Budget par question. 500 ms : assez pour trancher une finale ≤ 7
    /// pièces à profondeur confortable, assez court pour que l'aller-retour
    /// arbitrage + riposte reste sous la seconde et demie perçue.
    private let movetimeMs: Int

    /// Seuil « gagnant au sens pratique » — même valeur que l'audit.
    static let winThresholdCp = 250

    init(engine: EngineController, movetimeMs: Int = 500) {
        self.engine = engine
        self.movetimeMs = movetimeMs
    }

    func assess(fen: String) async -> EndgameAssessment? {
        guard let result = await engine.computeBestMove(
            fen: fen,
            setupCommands: EngineStrength.maximum.setupCommands,
            movetimeMs: adjustedMovetime, depth: nil
        ) else { return nil }
        guard let cp = result.moverCp else {
            // Coup rendu sans éval : rare (mat déjà sur l'échiquier n'arrive
            // pas ici). Sans verdict, pas d'arbitrage honnête.
            return nil
        }
        let verdict: EndgameVerdict = if cp >= Self.winThresholdCp {
            .win
        } else if cp <= -Self.winThresholdCp {
            .loss
        } else {
            .draw
        }
        return EndgameAssessment(verdict: verdict, bestLan: result.lan)
    }

    func reply(fen: String) async -> String? {
        await engine.computeBestMove(
            fen: fen,
            setupCommands: EngineStrength.maximum.setupCommands,
            movetimeMs: adjustedMovetime, depth: nil
        )?.lan
    }

    /// Surchauffe : moitié moins de temps par question, comme partout.
    private var adjustedMovetime: Int {
        Int(Double(movetimeMs) * ThermalMonitor.shared.movetimeFactor)
    }
}
