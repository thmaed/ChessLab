import SwiftUI

/// « Une partie est en cours » : le garde-fou de « Commencer », commun aux modes Jouer et Deux joueurs —
/// lancer une nouvelle partie EFFACE celle en cours, l'écran le dit au lieu de le laisser découvrir.
///
/// Synchro iCloud allumée, la partie en cours est la même sur tous les appareils : le texte le dit, et le
/// titre nomme l'appareil d'où elle vient (essai sur trois iPhone, 16/11/2026).
struct ReplaceGameAlert: ViewModifier {
    @Binding var isPresented: Bool
    let moveCount: Int
    /// L'appareil où son dernier coup a été joué, s'il ne s'agit pas de celui-ci (« iPhone 11 »).
    let origin: String?
    let onResume: () -> Void
    let onReplace: () -> Void

    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented) {
            Button("Reprendre la partie en cours", action: onResume)
            Button("Remplacer par une nouvelle partie", role: .destructive, action: onReplace)
            Button("Annuler", role: .cancel) {}
        } message: {
            if CloudSyncSettingsStore.isEnabled {
                Text("Commencer une nouvelle partie l'effacera sur tous vos appareils (\(moveCount) coup(s) joué(s)).")
            } else {
                Text("Commencer une nouvelle partie effacera la partie en cours (\(moveCount) coup(s) joué(s)).")
            }
        }
    }

    private var title: Text {
        if let origin { Text("Une partie est en cours sur votre \(origin)") } else { Text("Une partie est en cours") }
    }
}

extension View {
    func replaceGameAlert(isPresented: Binding<Bool>, moveCount: Int, origin: String?,
                          onResume: @escaping () -> Void, onReplace: @escaping () -> Void) -> some View {
        modifier(ReplaceGameAlert(isPresented: isPresented, moveCount: moveCount, origin: origin,
                                  onResume: onResume, onReplace: onReplace))
    }
}
