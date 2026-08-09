import ChessKit
import SwiftUI

/// Écran « Ouvertures » : la bibliothèque ECO embarquée, directement.
///
/// Il y avait ici un sélecteur « Mes répertoires » / « Bibliothèque », avec
/// création de répertoires personnels et import de PGN annotés. C'est parti
/// (18/07/2026) : deux modes de travail cohabitaient dans un écran dont le
/// titre n'en annonçait qu'un, et le premier tapé — « Mes répertoires » —
/// s'ouvrait presque toujours vide, avec une invitation à importer un fichier.
/// La bibliothèque, elle, marche sans rien fournir.
///
/// Ne reste donc qu'un seul chemin : choisir une ouverture, choisir son camp,
/// jouer la ligne (``OpeningLibraryView`` → ``OpeningLineTrainingView``).
struct RepertoireListView: View {
    /// Va directement à l'échiquier, ligne entière.
    let onStartLibraryLine: (OpeningLibraryEntry, Piece.Color) -> Void
    /// Ouvre le nouvel Explorer en graphe (aperçu) — présenté seulement quand
    /// ``OpeningsGraphFeature/isActive`` (drapeau off par défaut) : la
    /// bibliothèque linéaire reste l'expérience par défaut, extension additive.
    var onOpenExplorer: () -> Void = {}

    var body: some View {
        OpeningLibraryView(onStartLine: onStartLibraryLine)
            .appBackground()
            .navigationTitle("Ouvertures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if OpeningsGraphFeature.isActive {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onOpenExplorer) {
                            Label("Explorateur", systemImage: "safari")
                        }
                        .tint(Theme.accent)
                    }
                }
            }
    }
}
