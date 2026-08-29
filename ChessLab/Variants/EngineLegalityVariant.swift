import ChessKit
import SwiftUI

/// Une variante où Fairy-Stockfish est l'ARBITRE de légalité — pas seulement
/// un conseiller comme pour ``FairyVariant`` (Roi de la colline/Trois échecs/
/// Horde, lot A). Course des rois, Antéchecs et Atomique changent la
/// LÉGALITÉ elle-même (échec interdit, capture obligatoire, explosions) :
/// ChessKit seul ne suffit plus à en juger.
///
/// Architecture validée le 25/08 avant tout code réel (même discipline que
/// le patch d'espace de noms C++) : `go perft 1` énumère les coups légaux
/// exacts de la position (`FairyEngineController.legalMoves(startFEN:
/// uciLog:)`), et `d` donne le FEN résultant après un coup
/// (`positionAfter(startFEN:uciLog:)`) — y compris les cases vidées par une
/// explosion Atomique, qu'aucune règle ChessKit ne pourrait deviner. Lu dans
/// `position.cpp` (`is_immediate_game_end`) : la fin de partie « capture the
/// flag » de Course des rois implémente déjà la règle officielle du coup de
/// grâce (si les Blancs arrivent en 8e rangée, les Noirs ont EXACTEMENT un
/// coup pour égaliser en y arrivant aussi) — inutile de la reprogrammer,
/// `legalMoves` la reflète déjà (liste vide seulement quand la partie est
/// VRAIMENT finie).
///
/// ChessKit garde un rôle : reconstruire un `Board` d'AFFICHAGE à partir du
/// FEN donné par le moteur, pour le rendu du plateau — jamais pour statuer
/// sur la légalité d'un coup ici.
struct EngineLegalityVariant: Identifiable {
    /// Identifiant STABLE, et valeur EXACTE de `setoption UCI_Variant`.
    let id: String
    /// Texte FRANÇAIS source — même convention que ``FairyVariant`` : une
    /// propriété calculée traduit à CHAQUE lecture, jamais un résultat figé.
    private let displayNameKey: String
    private let shortNameKey: String
    /// Accroche raccourcie pour les tuiles des petits iPhone — voir
    /// ``FairyVariant/shortTagline``.
    private let shortTaglineKey: String
    private let rulesKey: String
    let icon: String
    let tint: Color
    let startFEN: String

    var displayName: String { LocalizationController.string(displayNameKey) }
    var shortName: String { LocalizationController.string(shortNameKey) }
    var shortTagline: String { LocalizationController.string(shortTaglineKey) }
    var rules: String { LocalizationController.string(rulesKey) }

    static let racingKings = EngineLegalityVariant(
        id: "racingkings",
        displayNameKey: "Course des rois",
        shortNameKey: "Course rois",
        shortTaglineKey: "Le roi en 8e",
        rulesKey: "Pas de pions, pas de roque. Aucun coup n'a le droit de mettre le roi adverse en échec — sauf s'il gagne la partie sur-le-champ. Le but : amener votre roi sur la 8e rangée avant l'adversaire. Si les Blancs y arrivent les premiers, les Noirs ont EXACTEMENT un coup pour égaliser en y arrivant aussi — sinon les Blancs ont gagné.",
        icon: "flag.checkered",
        tint: Theme.info,
        startFEN: "8/8/8/8/8/8/krbnNBRK/qrbnNBRQ w - - 0 1"
    )

    static let atomic = EngineLegalityVariant(
        id: "atomic",
        displayNameKey: "Atomique",
        shortNameKey: "Atomique",
        shortTaglineKey: "Prises explosives",
        rulesKey: "Toute capture fait exploser la case d'arrivée : la pièce qui capture ET la pièce capturée disparaissent, ainsi que toute pièce SAUF les pions sur les huit cases voisines. La partie se termine dès qu'un roi explose — un coup qui ferait exploser votre PROPRE roi est interdit. Deux rois peuvent se toucher sans risque : aucun ne peut capturer l'autre sans se détruire lui-même.",
        icon: "burst.fill",
        tint: Theme.danger,
        startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    )

    /// Crazyhouse — la seule variante du hub où l'on POSE des pièces.
    ///
    /// Fairy-Stockfish la joue nativement, avec un réseau NNUE dédié : le
    /// moteur y est fort, contrairement aux variantes qu'il arbitre sans
    /// réseau. Côté app, elle est la première à avoir une RÉSERVE — lue dans
    /// la section entre crochets de la FEN, voir
    /// ``FairyEngineController/parsePocket(fromFEN:)``.
    static let crazyhouse = EngineLegalityVariant(
        id: "crazyhouse",
        displayNameKey: "Crazyhouse",
        shortNameKey: "Crazyhouse",
        shortTaglineKey: "Les prises reviennent",
        rulesKey: "Toute pièce que vous capturez change de camp et rejoint votre RÉSERVE. À votre tour, au lieu de déplacer une pièce, vous pouvez en poser une de votre réserve sur n'importe quelle case vide — y compris pour donner échec ou mat. Un pion ne peut se poser ni sur la 1re ni sur la 8e rangée. Un pion promu qui se fait capturer redevient un simple pion dans la réserve adverse. Pour tout le reste, les règles sont celles du jeu classique.",
        icon: "tray.full.fill",
        tint: Theme.accent,
        startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    )

    static let antichess = EngineLegalityVariant(
        id: "antichess",
        displayNameKey: "Antéchecs",
        shortNameKey: "Antéchecs",
        shortTaglineKey: "Perdre pour gagner",
        rulesKey: "Le but est INVERSÉ : vous gagnez en perdant toutes vos pièces, ou en étant dans l'incapacité de jouer un coup. Capturer est OBLIGATOIRE dès que c'est possible — s'il existe plusieurs captures, vous choisissez laquelle. Il n'y a ni échec ni mat : le roi se capture comme n'importe quelle pièce, et le roque n'existe pas.",
        icon: "arrow.triangle.swap",
        tint: Theme.rose,
        startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    )

    /// Barricades — les échecs ordinaires, avec deux cases MURÉES.
    ///
    /// La seule variante du hub que Fairy-Stockfish ne connaît pas d'origine :
    /// elle lui est ENSEIGNÉE au démarrage, par un fichier de définition que
    /// l'app engendre elle-même (voir ``BarricadesConfiguration``). Le moteur
    /// reste l'arbitre — c'est bien lui qui refuse de poser une pièce sur un
    /// mur ou de le traverser, rien n'en est réimplémenté ici.
    static let barricades = EngineLegalityVariant(
        id: BarricadesConfiguration.variantID,
        displayNameKey: "Barricades",
        shortNameKey: "Barricades",
        shortTaglineKey: "Deux cases murées",
        rulesKey: "Les règles des échecs, à un détail près : les cases d4 et e5 sont MURÉES dès le départ. Aucune pièce ne peut s'y poser ni les traverser, et un mur ne se capture pas — il ne bougera jamais de la partie. Les tours, fous et dames butent donc dessus comme sur une pièce, tandis que les cavaliers leur sautent par-dessus sans pouvoir s'y arrêter. Tout le reste — échec, mat, pat, roque, prise en passant, promotion — est inchangé.",
        icon: "square.grid.3x3.fill",
        tint: Theme.warning,
        startFEN: BarricadesConfiguration.startFEN
    )

    /// Barricades ALÉATOIRES — les mêmes murs, mais qui changent de case à
    /// chaque demi-coup.
    ///
    /// Deux différences de fond avec sa sœur fixe, toutes deux dues au fait
    /// que les murs bougent :
    ///
    /// - la position ne se REJOUE pas depuis le départ (le tirage des murs
    ///   n'est pas dans les coups) : la vue-modèle enchaîne de position en
    ///   position, voir ``rewritesPositionEachMove`` ;
    /// - `mobilityRegion` étant figé par variante, il ne peut pas suivre des
    ///   murs mobiles : les prises de mur sont retirées de la liste du moteur
    ///   côté app, voir ``removingWallCaptures(from:in:)``.
    static let randomBarricades = EngineLegalityVariant(
        id: BarricadesConfiguration.randomVariantID,
        displayNameKey: "Barricades aléatoires",
        // Pas de dé ⚄ (U+2684) : SF Pro ne le porte pas, la tuile affichait un
        // carré vide. Vérifié à l'écran.
        shortNameKey: "Murs mobiles",
        shortTaglineKey: "Ils bougent chaque coup",
        rulesKey: "Les règles des échecs, avec TROIS murs qui ne tiennent pas en place. Après chaque coup, deux d'entre eux — tirés au sort, jamais les mêmes — sautent sur des cases vides entre la 2e et la 7e rangée ; le troisième reste où il est. Aucune pièce ne peut s'y poser ni les traverser, et ils ne se capturent pas. Un fou qui tenait une diagonale la perd au coup suivant, une tour cloue puis ne cloue plus : rien n'est acquis, et calculer loin ne sert pas à grand-chose.",
        icon: "die.face.4.fill",
        tint: Theme.violet,
        startFEN: BarricadesConfiguration.randomStartFEN
    )

    static let all: [EngineLegalityVariant] = [
        .racingKings, .atomic, .antichess, .crazyhouse, .barricades, .randomBarricades,
    ]

    // MARK: Place dans le hub

    /// Les variantes de cette famille montrées AVANT le Coup Volé et le Duck
    /// Chess, dans l'ordre du hub.
    static var hubOrdered: [EngineLegalityVariant] {
        all.filter { variant in !hubTrailing.contains { $0.id == variant.id } }
    }

    /// Celles qui ferment la marche, après toutes les autres tuiles.
    ///
    /// ``all`` sert aux RECHERCHES par identifiant, et son ordre n'a donc
    /// aucune raison de commander l'affichage : le hub mêle trois familles de
    /// variantes, aucune liste seule ne peut dire où va une tuile.
    static let hubTrailing: [EngineLegalityVariant] = [.barricades, .randomBarricades]

    // MARK: Définition à enseigner au moteur

    /// Chemin d'un fichier de définition à charger AVANT de choisir la
    /// variante, ou `nil` quand le moteur la connaît déjà.
    ///
    /// Écrit à chaque appel plutôt que gardé : le fichier est engendré et
    /// minuscule, et une version périmée serait un piège silencieux — le
    /// moteur chargerait d'anciennes règles sans que rien ne le dise.
    var customDefinitionPath: String? {
        guard id == Self.barricades.id || id == Self.randomBarricades.id else { return nil }
        return BarricadesConfiguration.writeConfigurationFile()
    }

    // MARK: Murs mobiles — propre aux Barricades aléatoires

    /// La position se réécrit-elle après chaque demi-coup ?
    ///
    /// Vrai pour les Barricades aléatoires, et pour elles seules : le tirage
    /// des murs ne figure dans aucun coup, donc rejouer `startFEN + coups` ne
    /// le reproduirait pas. La vue-modèle enchaîne alors de position en
    /// position au lieu de rejouer depuis le départ.
    var rewritesPositionEachMove: Bool { id == Self.randomBarricades.id }

    /// La position de DÉPART réelle d'une partie.
    ///
    /// Les Barricades aléatoires y posent leurs trois premiers murs : le
    /// modèle de variante ne peut pas les porter, ils changent à chaque
    /// partie.
    func initialPosition() -> String {
        guard rewritesPositionEachMove else { return startFEN }
        var generator = SystemRandomNumberGenerator()
        return BarricadesConfiguration.openingPosition(using: &generator)
    }

    /// La position après un demi-coup : deux des trois murs, tirés au sort,
    /// ont changé de case. Le troisième reste — mais pas le même d'un coup à
    /// l'autre, et rien à retenir d'un appel au suivant.
    func rewrittenPosition(after fen: String) -> String? {
        guard rewritesPositionEachMove else { return nil }
        var generator = SystemRandomNumberGenerator()
        return BarricadesConfiguration.relocatingWalls(in: fen, using: &generator)
    }

    /// Retire les coups qui PRENNENT un mur.
    ///
    /// Le moteur les propose : faute de `mobilityRegion` — impossible à
    /// figer sur des murs mobiles — il voit deux pièces blanches immobiles et
    /// sans valeur, donc capturables. Les retirer ici est une soustraction
    /// d'une ligne sur une liste que le moteur a produite ; tout le reste de
    /// la légalité (échec, clouage, roque, prise en passant) reste la sienne,
    /// et reste juste : un mur EST une pièce sur son échiquier, donc il
    /// bloque les lignes et les cavaliers lui sautent par-dessus.
    ///
    /// Si un camp n'avait plus QUE des prises de mur, il n'aurait réellement
    /// aucun coup : rendre une liste vide est alors la bonne réponse, et la
    /// partie se conclut sur un mat ou un pat comme il se doit.
    func removingWallCaptures(from moves: [String], in fen: String) -> [String] {
        guard rewritesPositionEachMove else { return moves }
        let walls = Set(BarricadesFEN.wallSquares(in: fen).map(\.notation))
        guard !walls.isEmpty else { return moves }
        return moves.filter { move in
            guard move.count >= 4 else { return true }
            return !walls.contains(String(move.dropFirst(2).prefix(2)))
        }
    }

    // MARK: Fin de partie

    /// Détecte la fin de partie APRÈS un coup, uniquement à partir de ce que
    /// le moteur rapporte — jamais de règle réimplémentée à la main.
    ///
    /// - parameter fen: position APRÈS le coup (``FairyEngineController/
    ///   positionAfter(startFEN:uciLog:)``).
    /// - parameter legalMovesForNextMover: coups légaux de la position
    ///   ci-dessus, déjà interrogés (``FairyEngineController/
    ///   legalMoves(startFEN:uciLog:)``) — vide seulement si la partie est
    ///   RÉELLEMENT terminée (voir le commentaire de tête sur le coup de
    ///   grâce de Course des rois, déjà reflété ici).
    /// - parameter inCheck: le camp au trait de `fen` est-il en échec —
    ///   ligne `Checkers:` de `d`, non vide. Ignoré hors Atomique (les
    ///   deux autres variantes n'ont pas de notion d'échec qui bloque un
    ///   coup, seulement la légalité déjà filtrée en amont).
    /// - parameter pocketIsEmpty: les deux réserves sont-elles vides ? Seul
    ///   le Crazyhouse en a ; ailleurs, `true` par défaut.
    func outcome(
        afterFEN fen: String, legalMovesForNextMover: [String], inCheck: Bool,
        pocketIsEmpty: Bool = true
    ) -> GameOutcome? {
        // FEN ÉPURÉE : la brute porte la réserve du Crazyhouse et les murs de
        // Barricades, que ChessKit ne connaît pas (voir ``VariantFEN``).
        guard let position = Position(fen: VariantFEN.forChessKit(fen)) else { return nil }
        let nextMover = position.sideToMove
        let kings = position.pieces.filter { $0.kind == .king }

        if id == EngineLegalityVariant.atomic.id {
            // L'explosion d'un roi termine la partie qu'il reste ou non des
            // coups légaux ensuite — vérifié EN PREMIER.
            if !kings.contains(where: { $0.color == .white }) {
                return GameOutcome(winner: .black, reason: .atomicKingExploded)
            }
            if !kings.contains(where: { $0.color == .black }) {
                return GameOutcome(winner: .white, reason: .atomicKingExploded)
            }
        }

        // Plus personne ne peut mater : nulle, avant même de regarder s'il
        // reste des coups. La règle ne vaut PAS pour toutes les variantes —
        // voir ``VariantDrawRules/declaresInsufficientMaterial(variantID:)``,
        // qui explique pourquoi l'Atomique, l'Antéchecs ou la Course des rois
        // s'y refusent.
        if VariantDrawRules.isInsufficientMaterial(
            fen: fen, variantID: id, pocketIsEmpty: pocketIsEmpty
        ) {
            return GameOutcome(winner: nil, reason: .draw(.insufficientMaterial))
        }

        guard legalMovesForNextMover.isEmpty else { return nil }

        switch id {
        case EngineLegalityVariant.racingKings.id:
            let rank8 = Set(kings.filter { $0.square.rank == 8 }.map(\.color))
            if rank8.count == 2 { return GameOutcome(winner: nil, reason: .racingKingsDraw) }
            if let winner = rank8.first { return GameOutcome(winner: winner, reason: .racingKingsGoal) }
            // Ni l'une ni l'autre : pat générique, hors course.
            return GameOutcome(winner: nil, reason: .draw(.stalemate))

        case EngineLegalityVariant.antichess.id:
            // Bloqué, plus de coup possible : le camp au trait GAGNE — le but
            // est inversé (perdre ses pièces, ou être immobilisé).
            return GameOutcome(winner: nextMover, reason: .antichessStuck)

        default:
            // MAT OU PAT AU SENS CLASSIQUE — et c'est volontairement le cas
            // par DÉFAUT, non une liste d'identifiants.
            //
            // Il l'était : `atomic` et `crazyhouse` y étaient nommés, et tout
            // le reste tombait sur `return nil`. Barricades, ajouté sans
            // toucher à ce `switch`, n'a donc jamais eu de fin de partie —
            // un mat s'y jouait sans que rien ne l'annonce, signalé par
            // l'utilisateur le 29/08. Renversé : une variante qui ne
            // redéfinit PAS la fin de partie hérite maintenant de celle des
            // échecs, et l'oubli devient impossible.
            //
            // Atomique : l'explosion d'un roi est traitée plus haut, avant
            // même le test « plus de coup légal ». Crazyhouse : « plus de
            // coup légal » compte AUSSI les poses, que le moteur énumère —
            // un camp qui tient une pièce en réserve n'est donc mat que si
            // aucune pose ne pare l'échec, ce que Fairy-Stockfish sait, et
            // nous pas.
            return inCheck
                ? GameOutcome(winner: nextMover.opposite, reason: .checkmate)
                : GameOutcome(winner: nil, reason: .draw(.stalemate))
        }
    }
}
