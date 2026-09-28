import Foundation

/// Le nom d'un joueur, tel qu'il s'AFFICHE — plaque de partie, ligne de
/// bibliothèque, en-tête d'analyse, annonce VoiceOver.
///
/// Deux choses passent par ici, et c'est exprès qu'elles n'en font qu'une :
///
/// - **la traduction.** La bibliothèque stocke « Vous » EN CLAIR dans ses
///   enregistrements (``GameLibraryService``), parce que ce nom est aussi une
///   sentinelle : c'est par lui que les plus vieux enregistrements, sans
///   couleur de moteur, retrouvent de quel côté jouait l'utilisateur. Affiché
///   tel quel, il montrait « Vous » à une interface anglaise — premier défaut
///   remonté par un testeur anglophone le 27/09/2026. Le stockage ne change
///   pas ; c'est l'affichage qui traduit, ici et nulle part ailleurs ;
/// - **le nom choisi.** ``AppSettings/playerName`` remplace « Vous » partout
///   dès qu'il est renseigné — le même testeur cherchait comment signer ses
///   parties.
///
/// Les deux langues sont reconnues : une partie enregistrée en anglais puis
/// relue en français doit se retourner elle aussi. C'est la langue DU JOUR qui
/// décide, pas celle du jour de la partie. Le prix de cette symétrie : un
/// joueur importé qui s'appellerait littéralement « White » s'afficherait
/// « Blancs ». Le cas est théorique, la gêne nulle, et l'inverse — des parties
/// à moitié traduites — se voyait tous les jours.
@MainActor
enum PlayerName {

    /// Le nom de l'utilisateur : le sien s'il s'en est donné un, sinon
    /// « Vous » dans la langue active.
    static var you: String {
        let chosen = AppSettings.shared.playerName.trimmingCharacters(in: .whitespaces)
        return chosen.isEmpty ? LocalizationController.string("Vous") : chosen
    }

    /// Nom par défaut des Blancs / des Noirs (parties à deux sur le même
    /// appareil), dans la langue active.
    static var white: String { LocalizationController.string("Blancs") }
    static var black: String { LocalizationController.string("Noirs") }

    /// Nom de l'adversaire machine, dans la langue active.
    static var computer: String { LocalizationController.string("Ordinateur") }

    /// Traduit les noms « spéciaux » stockés en clair ; laisse intact un vrai
    /// nom saisi par l'utilisateur ou venu d'un PGN importé.
    ///
    /// Rend `nil` pour une valeur absente ou vide, à charge de l'appelant de
    /// choisir son repli — la ligne de bibliothèque ne veut pas le même que
    /// l'en-tête d'analyse.
    static func display(_ stored: String?) -> String? {
        guard let stored else { return nil }
        let trimmed = stored.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "?" else { return nil }
        switch trimmed {
        case "Vous", "You": return you
        case "Blancs", "White": return white
        case "Noirs", "Black": return black
        // « Stockfish » : nom stocké par les parties antérieures au renommage —
        // affiché « Ordinateur » comme les nouvelles, pour l'uniformité.
        case "Ordinateur", "Computer", "Stockfish": return computer
        default: return trimmed
        }
    }

    /// Même chose, avec un repli quand rien n'est stocké.
    static func display(_ stored: String?, fallback: @autoclosure () -> String) -> String {
        display(stored) ?? fallback()
    }
}
