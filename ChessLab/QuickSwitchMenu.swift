import SwiftUI

/// Raccourci de barre d'outils pour sauter vers un autre grand mode de l'app
/// (Laboratoire, Contre l'ordinateur, Deux joueurs) depuis Puzzles,
/// Ouvertures, Finales, ou l'un des deux modes de jeu eux-mêmes.
///
/// Un seul bouton, quel que soit le nombre de destinations proposées : la
/// demande initiale envisageait un bouton par destination, mais empilés sur
/// les écrans qui ont déjà leurs propres boutons (lecteur d'ouverture, partie
/// en cours…) cela surchargeait la barre. Un menu unique garde la barre
/// stable partout, et chaque destination reste identifiable par son icône et
/// sa couleur habituelles (mêmes tokens que l'accueil).
struct QuickSwitchMenu: View {
    /// Le mode DANS lequel on se trouve déjà : son propre raccourci n'a pas
    /// de sens (« aller à Deux joueurs » depuis l'écran Deux joueurs).
    enum CurrentMode {
        case none, vsEngine, twoPlayer
    }

    var excluding: CurrentMode = .none
    var onOpenLab: () -> Void
    var onPlayVsEngine: () -> Void
    var onOpenTwoPlayer: () -> Void

    var body: some View {
        Menu {
            Button(action: onOpenLab) {
                Label("Laboratoire", systemImage: "flask")
            }
            if excluding != .vsEngine {
                Button(action: onPlayVsEngine) {
                    Label("Contre l'ordinateur", systemImage: "cpu")
                }
            }
            if excluding != .twoPlayer {
                Button(action: onOpenTwoPlayer) {
                    Label("Deux joueurs", systemImage: "person.2.fill")
                }
            }
        } label: {
            Label("Changer de mode", systemImage: "square.grid.2x2")
        }
        .accessibilityIdentifier("quickSwitchMenu")
    }
}
