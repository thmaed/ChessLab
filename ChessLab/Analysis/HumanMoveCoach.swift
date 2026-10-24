import ChessKit
import Foundation

/// Le « Coach » de l'analyse (B1) : ce que jouent les humains du niveau du
/// joueur dans la position d'un coup, et ce que cela dit du coup joué.
///
/// Maia ne CALCULE pas : ses probabilités disent ce que les humains jouent,
/// pas ce qui est bon (elle ne trouve jamais certains sacrifices profonds). Le
/// Coach ne contredit donc jamais le moteur : il ajoute une ligne — « erreur
/// typique » ou « accident » — à un verdict déjà rendu par Stockfish.
struct HumanMoveInsight: Equatable, Sendable {

    enum Kind: Equatable, Sendable {
        /// Faute que beaucoup de joueurs de ce niveau commettent : une leçon.
        case typicalMistake
        /// Faute que presque personne ne commet à ce niveau : fatigue, clic.
        case accident
        /// Bon coup que peu de joueurs de ce niveau trouvent.
        case rareFind
    }

    /// Niveau (échelle Maia/Lichess) auquel Maia a été interrogée.
    let level: Int
    /// Part des joueurs de ce niveau qui jouent le coup joué (0...1).
    let playedProbability: Double
    /// Le coup le plus courant à ce niveau, en notation de la partie.
    let topMoveSAN: String
    let topProbability: Double
    /// Le coup joué EST le plus courant : inutile de le répéter.
    let playedIsTop: Bool

    /// La qualification dépend du verdict du moteur, qui peut arriver APRÈS la
    /// réponse de Maia : elle se lit donc à l'affichage, pas au calcul.
    @MainActor func kind(isFault: Bool) -> Kind? {
        HumanMoveCoach.classify(probability: playedProbability, isFault: isFault)
    }
}

@MainActor
enum HumanMoveCoach {

    /// Seuils de qualification, en part de joueurs. Une faute jouée par au
    /// moins un joueur sur douze est « typique » ; sous un sur trente, c'est
    /// un « accident » ; entre les deux, on donne le chiffre sans étiquette.
    static let typicalThreshold = 0.08
    static let accidentThreshold = 0.03
    /// Un bon coup joué par moins d'un joueur sur vingt-cinq est « rare ».
    static let rareFindThreshold = 0.04

    /// Bornes de l'échelle du Coach : celle sur laquelle Maia a été mesurée.
    static let levelRange: ClosedRange<Int> = 600...2600

    static func classify(probability: Double, isFault: Bool) -> HumanMoveInsight.Kind? {
        if isFault {
            if probability >= typicalThreshold { return .typicalMistake }
            if probability < accidentThreshold { return .accident }
            return nil
        }
        return probability < rareFindThreshold ? .rareFind : nil
    }

    /// Le niveau du joueur tant qu'aucune estimation fiable n'existe : celui
    /// choisi à la création de la dernière partie, sinon 1200.
    static func defaultLevel() -> Int {
        let chosen = PlaySettingsStore.load()?.eloSliderValue ?? 1200
        return Int(chosen.rounded()).clamped(to: levelRange)
    }

    /// Lit la distribution de Maia sur la position PARENT du coup.
    ///
    /// - parameter history: positions de la partie, de la première à la
    ///   position parent comprise.
    /// - parameter parent: plateau avant le coup.
    /// - returns: `nil` si le coup joué n'est pas dans le vocabulaire de Maia
    ///   (variante, position illégale) — mieux vaut se taire.
    static func insight(
        distribution: [MaiaCandidate], playedLAN: String, parent: Board, level: Int
    ) -> HumanMoveInsight? {
        guard let top = distribution.first else { return nil }
        let played = distribution.first { $0.move.uci == playedLAN }
        // Un coup absent de la distribution a une probabilité nulle pour Maia
        // (promotion rare, par exemple) ; seul un coup réellement illégal doit
        // faire taire le Coach, et la distribution ne contient que des légaux.
        let probability = played?.probability ?? 0
        return HumanMoveInsight(
            level: level,
            playedProbability: probability,
            topMoveSAN: san(ofUCI: top.move.uci, in: parent),
            topProbability: top.probability,
            playedIsTop: top.move.uci == playedLAN
        )
    }

    /// La notation SAN d'un coup UCI sur `board`, sans toucher à `board`.
    /// Une promotion retombe sur l'UCI : la SAN d'une promotion dépend de la
    /// pièce choisie, et ce n'est pas ici qu'on la complète.
    static func san(ofUCI uci: String, in board: Board) -> String {
        guard uci.count == 4 else { return uci }
        var scratch = board
        let from = Square(String(uci.prefix(2)))
        let to = Square(String(uci.suffix(2)))
        guard let made = scratch.move(pieceAt: from, to: to) else { return uci }
        return SANFormatter.display(made.san)
    }

    /// « 12 % », ou « moins de 1 % » : un coup que Maia juge presque
    /// impossible ne s'écrit pas « 0 % ».
    static func percentText(_ probability: Double) -> String {
        let percent = Int((probability * 100).rounded())
        if percent < 1 { return LocalizationController.string("moins de 1 %") }
        return "\(percent) %"
    }

    /// La ligne du Coach, ou `nil` s'il n'y a rien à en dire.
    static func sentence(for insight: HumanMoveInsight, isFault: Bool) -> String? {
        let played = percentText(insight.playedProbability)
        let level = insight.level
        let common = insight.playedIsTop
            ? ""
            : " " + LocalizationController.string(
                "Le plus courant : %@ (%@).", insight.topMoveSAN, percentText(insight.topProbability))
        switch insight.kind(isFault: isFault) {
        case .typicalMistake:
            return LocalizationController.string(
                "Coach · %@ des joueurs de niveau %lld jouent ce coup : erreur typique.", played, level) + common
        case .accident:
            return LocalizationController.string(
                "Coach · %@ des joueurs de niveau %lld jouent ce coup : un accident, pas une habitude.",
                played, level) + common
        case .rareFind:
            return LocalizationController.string(
                "Coach · coup rare : %@ des joueurs de niveau %lld le trouvent.", played, level)
        case nil:
            guard isFault else { return nil }
            return LocalizationController.string(
                "Coach · %@ des joueurs de niveau %lld jouent ce coup.", played, level) + common
        }
    }

    /// La mise en garde, en une phrase : Maia dit ce que jouent les humains.
    static var caveat: String {
        LocalizationController.string("D'après Maia : ce que jouent les humains, pas ce qui est bon.")
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int { Swift.min(Swift.max(self, range.lowerBound), range.upperBound) }
}
