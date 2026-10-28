import SwiftUI

/// Raccourci de barre d'outils pour emporter la position affichée vers un
/// autre grand mode de l'app.
///
/// Un seul bouton, quel que soit le nombre de destinations : la demande
/// initiale envisageait un bouton par destination, mais empilés sur les écrans
/// qui ont déjà leurs propres boutons cela surchargeait la barre.
///
/// ## Pourquoi ce composant existe (harmonisation du 24/08)
///
/// La même capacité vivait sous DEUX apparences. Six écrans — Ouvertures,
/// Finales, Puzzles — avaient ce bouton violet ; les trois écrans de partie
/// cachaient les mêmes destinations dans une section « Continuer ailleurs »
/// d'un menu annoncé comme **Exporter** (icône de partage, grise) ou noyées
/// dans un menu « … » avec le thème du plateau et le retournement. Rien ne
/// laissait deviner qu'il s'agissait de la même chose.
///
/// Désormais : une icône, une couleur, une place, un vocabulaire — et les
/// menus d'export ne parlent plus que d'export.
///
/// ## Les destinations se déclarent, elles ne s'excluent pas
///
/// Chaque écran fournit les fermetures qui ont un sens chez lui, et seules
/// celles-là s'affichent. L'ancien paramètre `excluding` ne savait dire qu'une
/// chose — « je suis ce mode-ci » — et ne pouvait pas exprimer le cas de
/// l'analyse, qui propose une partie contre l'ordinateur mais pas à deux.
///
/// Libellés et icônes sont ceux des TUILES DE L'ACCUEIL, dans le même ordre :
/// le menu est un raccourci vers la grille, il en reprend les mots.
struct QuickSwitchMenu: View {
    var onPlayVsEngine: (() -> Void)?
    var onOpenTwoPlayer: (() -> Void)?
    var onAnalyze: (() -> Void)?
    var onOpenLab: (() -> Void)?

    init(
        onPlayVsEngine: (() -> Void)? = nil,
        onOpenTwoPlayer: (() -> Void)? = nil,
        onAnalyze: (() -> Void)? = nil,
        onOpenLab: (() -> Void)? = nil
    ) {
        self.onPlayVsEngine = onPlayVsEngine
        self.onOpenTwoPlayer = onOpenTwoPlayer
        self.onAnalyze = onAnalyze
        self.onOpenLab = onOpenLab
    }

    var body: some View {
        Menu {
            if let onPlayVsEngine {
                Button(action: onPlayVsEngine) {
                    Label("Contre l'ordinateur", systemImage: "cpu")
                }
            }
            if let onOpenTwoPlayer {
                Button(action: onOpenTwoPlayer) {
                    Label("Deux joueurs", systemImage: "person.2.fill")
                }
            }
            if let onAnalyze {
                Button(action: onAnalyze) {
                    Label("Analyser", systemImage: "chart.xyaxis.line")
                }
            }
            if let onOpenLab {
                Button(action: onOpenLab) {
                    Label("Laboratoire", systemImage: "flask")
                }
            }
        } label: {
            // L'icône SEULE ne disait rien (retour d'un utilisateur, 28/10/2026 : il
            // n'a pas deviné que les quatre carrés menaient à l'Analyse) : un mot
            // court l'accompagne. Le nom complet reste celui que lit VoiceOver et
            // que l'aide emploie : « Changer de mode ».
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2")
                Text("Modes")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Changer de mode"))
        }
        .tint(Theme.violet)
        .accessibilityIdentifier("quickSwitchMenu")
    }
}
