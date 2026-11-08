import ChessKit

/// Lecture d'un coup SAN, avec le correctif d'un défaut de ChessKit.
///
/// 🐛 `Move(san:position:)` perd la désambiguïsation d'une CAPTURE : dans
/// `Rfxd7+`, l'expression qui cherche la colonne (ou la rangée) de départ exige
/// qu'elle touche la case d'arrivée ; le `x` s'intercale, elle rend une chaîne
/// vide, et c'est la première tour trouvée qui joue, pas la tour f. La partie
/// continue alors avec une autre position, et le coup suivant « n'est plus
/// jouable ». Un coup sans capture (`Rhf1`) n'est pas touché. Encore présent
/// dans ChessKit 0.17.0, la dernière version.
///
/// Trouvé sur le fichier de 1100 puzzles de Ron (08/11/2026) : sept parties
/// écartées, toutes avec une capture désambiguïsée.
///
/// Le correctif : lire la même capture SANS son `x` (`Rfd7+`, que ChessKit lit
/// correctement), puis la refaire capture avec la pièce qui se trouve sur la
/// case d'arrivée.
enum SAN {
    /// Pièce, colonne et/ou rangée de départ, puis `x` : « Rfx », « R1x », « Ra1x ».
    private static let disambiguatedCapture = #"^[KQRBN]([a-h][1-8]?|[1-8])x"#

    static func move(_ san: String, in position: Position) -> Move? {
        guard san.range(of: disambiguatedCapture, options: .regularExpression) != nil else {
            return Move(san: san, position: position)
        }
        guard let quiet = Move(san: san.replacingOccurrences(of: "x", with: ""), position: position),
              let captured = position.piece(at: quiet.end),
              captured.color != quiet.piece.color
        else { return nil }
        // `disambiguation` n'est pas modifiable de l'extérieur : les appelants ne
        // prennent d'ailleurs que le départ, l'arrivée et la promotion, puis
        // rejouent le coup sur un `Board`, qui retrouve la désambiguïsation seul.
        return Move(
            result: .capture(captured), piece: quiet.piece,
            start: quiet.start, end: quiet.end, checkState: quiet.checkState
        )
    }
}
