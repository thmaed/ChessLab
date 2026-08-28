import SwiftUI

/// Descripteur du Duck Chess — volontairement plus pauvre que
/// ``FairyVariant`` et ``EngineLegalityVariant`` : ces deux-là décrivent une
/// variante que le MOTEUR joue (identifiant UCI, force, cadence). Ici il n'y
/// a pas d'adversaire artificiel, donc rien de tout cela — seulement de quoi
/// nommer la variante, l'illustrer, et en énoncer la règle.
struct DuckChessVariant {
    static let shared = DuckChessVariant()

    let id = "duck"
    var displayName: String { LocalizationController.string("Duck Chess") }
    var shortName: String { LocalizationController.string("Canard") }
    var tagline: String { LocalizationController.string("Un canard bloque une case après chaque coup") }
    var shortTagline: String { LocalizationController.string("Le canard bloque") }
    var rules: String {
        LocalizationController.string("Chaque tour se joue en DEUX temps : vous déplacez une pièce, puis vous posez le canard sur une case vide de votre choix. Le canard n'appartient à personne et bloque totalement sa case — aucune pièce ne peut s'y poser ni la traverser, et il ne se capture pas. Il doit changer de case à chaque tour. Il n'y a NI ÉCHEC NI MAT : un roi a le droit de rester sous une attaque, et on gagne en le capturant. Faute de moteur capable d'arbitrer cette variante, elle se joue à deux sur le même appareil.")
    }
    let icon = "bird.fill"
    let tint = Theme.warning
}
