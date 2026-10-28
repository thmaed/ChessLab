import Foundation

/// Comment s'est terminée la DERNIÈRE tentative d'un puzzle — trois états là
/// où le succès/échec binaire en cachait un : un puzzle raté au dernier coup
/// d'une séquence de quatre n'est pas un puzzle raté d'emblée.
///
/// - mastered : trouvé sans fausse tentative.
/// - partial : au moins un coup juste, mais pas la séquence propre — soit
///   raté plus loin dans la séquence, soit trouvé après une fausse tentative
///   (réglage « 3 essais »).
/// - missed : raté dès le premier coup, ou puzzle d'un seul coup raté.
///
/// L'indice ne fait PAS passer un puzzle en « partiel » : réussi avec
/// l'indice compte comme réussi pour la répétition espacée (décision du
/// 23/10/2026) ; seule la cote personnelle en tient compte.
///
/// Stocké en entier (`rawValue`) sur ``Puzzle`` et ``PuzzleProgress`` ; `nil`
/// pour un puzzle tenté avant ce champ, lu alors comme avant (voir
/// ``PuzzleSessionDrawer``).
enum PuzzleOutcome: Int {
    case mastered = 0
    case partial = 1
    case missed = 2

    /// - Parameters:
    ///   - solved: la séquence a été menée au bout (ou close par un mat).
    ///   - hadWrongAttempt: au moins une fausse tentative pendant ce puzzle.
    ///   - playerMovesFound: coups du joueur trouvés avant la fin.
    static func classify(solved: Bool, hadWrongAttempt: Bool, playerMovesFound: Int) -> PuzzleOutcome {
        if solved { return hadWrongAttempt ? .partial : .mastered }
        return playerMovesFound >= 1 ? .partial : .missed
    }
}
