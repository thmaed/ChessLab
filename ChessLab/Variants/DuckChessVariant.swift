import SwiftUI

/// Descripteur du Duck Chess — volontairement plus pauvre que
/// ``FairyVariant`` et ``EngineLegalityVariant`` : ces deux-là portent un
/// identifiant de variante UCI, que Fairy-Stockfish reconnaît. Le Duck Chess
/// n'en a pas, et n'en aura pas : aucun moteur ne sait l'arbitrer (voir
/// ``DuckChessRules``). Il se joue quand même contre l'ordinateur — Stockfish
/// standard borné aux coups que le canard autorise, voir ``DuckChessEngine``
/// — d'où un descripteur réduit à ce qui nomme la variante, l'illustre, et en
/// énonce la règle.
struct DuckChessVariant {
    static let shared = DuckChessVariant()

    let id = "duck"
    var displayName: String { LocalizationController.string("Duck Chess") }
    var shortName: String { LocalizationController.string("Canard") }
    var shortTagline: String { LocalizationController.string("Le canard bloque") }
    var rules: String {
        LocalizationController.string("Chaque tour se joue en DEUX temps : vous déplacez une pièce, puis vous posez le canard sur une case vide de votre choix. Le canard n'appartient à personne et bloque totalement sa case — aucune pièce ne peut s'y poser ni la traverser, et il ne se capture pas. Il doit changer de case à chaque tour. Il n'y a NI ÉCHEC NI MAT : un roi a le droit de rester sous une attaque, et on gagne en le capturant. L'ordinateur joue cette variante avec Stockfish, restreint aux coups que le canard laisse passer : il joue bien, mais il ne voit pas le canard dans son évaluation.")
    }
    let icon = "bird.fill"
    let tint = Theme.warning
}
