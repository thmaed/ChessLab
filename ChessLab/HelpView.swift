import SwiftUI
import UIKit

/// Aide : décrit brièvement chaque module de l'app.
///
/// Volontairement succinct — une carte par module, l'essentiel de ce qu'on y
/// fait. Tous les libellés sont des `LocalizedStringKey` : ils basculent
/// FR/EN comme le reste de l'app.
struct HelpView: View {
    private struct Module: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let modules: [Module] = [
        .init(
            icon: "sparkles", tint: Theme.accent,
            title: "Nouveautés depuis la 1.0",
            body: "Depuis la 1.0, ChessLab a beaucoup évolué :\n\n• Ouvertures entièrement repensées : un lecteur guidé coup par coup, 58 ouvertures rédigées à la main et bilingues, des flèches colorées (coup recommandé, pièges, autres coups) et un entraînement en répétition espacée qui se règle tout seul.\n• iPad & Mac : interface à barre latérale, échiquier bord à bord, raccourcis clavier et survol au trackpad.\n• Synchronisation iCloud optionnelle : parties, puzzles et ouvertures suivent vos appareils, sans compte ni serveur tiers.\n• Analyse : suivez la meilleure ligne de Stockfish un demi-coup à la fois ; alerte « coup risqué » plus juste.\n• Progrès : un tableau de bord depuis l'accueil, avec un set de puzzles ciblé sur vos thèmes faibles.\n• Scanner plus fiable, moteur Stockfish recompilé (plus rapide et sans saccade), et nouveaux thèmes de plateau et de pièces."
        ),
        .init(
            icon: "cpu", tint: Theme.accent,
            title: "Contre l'ordinateur",
            body: "Jouez une partie contre le moteur Stockfish. Réglez votre couleur, la force de l'adversaire (Elo), la cadence, et les aides : indice (flèches des meilleurs coups), alerte en cas de coup risqué et barre d'évaluation. Après la partie, un bouton mène directement à l'analyse."
        ),
        .init(
            icon: "person.2.fill", tint: Theme.info,
            title: "Deux joueurs",
            body: "Deux personnes jouent sur le même appareil. Le mode « table » retourne les pièces pour rester lisible face à face. La partie terminée s'enregistre dans la bibliothèque."
        ),
        .init(
            icon: "puzzlepiece.fill", tint: Theme.violet,
            title: "Puzzles",
            body: "Résolvez des problèmes tactiques, issus de la bibliothèque Lichess embarquée ou générés depuis vos propres erreurs en analyse. Filtrez par niveau, phase de partie et thème. La répétition espacée planifie les révisions et un bilan suit votre réussite et vos thèmes faibles."
        ),
        .init(
            icon: "chart.bar.fill", tint: Theme.rose,
            title: "Progrès",
            body: "Un tableau de bord accessible depuis l'accueil : votre bilan face à l'ordinateur (victoires, nulles, défaites) et vos statistiques de puzzles par thème. En un tap sur un thème faible, l'app vous prépare un set de puzzles ciblé pour le travailler."
        ),
        .init(
            icon: "books.vertical.fill", tint: Theme.warning,
            title: "Ouvertures",
            body: "Progressez sur 58 ouvertures rédigées à la main et bilingues, aux grandes lignes vérifiées. Un lecteur guidé avance coup par coup, explique chaque coup et propose les autres coups jouables ; des flèches colorées signalent le coup recommandé, les pièges et les imprécisions. Entraînez-les en répétition espacée — l'app planifie vos révisions toute seule — et retrouvez votre progression sur tous vos appareils via iCloud."
        ),
        .init(
            icon: "chart.xyaxis.line", tint: Theme.teal,
            title: "Analyser",
            body: "Analysez une partie ou une position avec Stockfish : classification des coups (imprécision, erreur, gaffe), courbe d'évaluation, flèches des meilleurs coups et flèche rouge de la menace adverse, lecture automatique, et création de puzzles depuis les erreurs. Export PGN rechargeable. Entrée par PGN, FEN, éditeur ou scanner."
        ),
        .init(
            icon: "flask", tint: Theme.rose,
            title: "Laboratoire",
            body: "Faites s'affronter deux instances de Stockfish sur une série de parties pour comparer des réglages. Statistiques, écart Elo estimé avec intervalle de confiance, courbe de progression et répartition des résultats."
        ),
        .init(
            icon: "camera.viewfinder", tint: Theme.accent,
            title: "Éditeur et scanner de position",
            body: "Composez une position à la main sur le plateau, ou scannez-la depuis une capture d'écran, la photo d'un écran, ou un plateau réel vu du dessus. Un écran de confirmation vous laisse corriger la lecture avant de jouer ou d'analyser la position."
        ),
        .init(
            icon: "gearshape.fill", tint: Theme.textSecondary,
            title: "Réglages",
            body: "Langue de l'interface (français, anglais, ou celle du système), thème du plateau, notation des pièces (française R D T F C ou anglaise), et synchronisation iCloud."
        ),
        .init(
            icon: "icloud", tint: Theme.info,
            title: "Synchronisation iCloud",
            body: "Activez-la dans les Réglages pour que vos parties suivent tous vos appareils via votre iCloud privé — aucun compte à créer, aucun serveur tiers. Désactivée par défaut : l'app fonctionne entièrement hors ligne. La modification prend effet au prochain lancement."
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Chaque mode de ChessLab en bref.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 2)

                ForEach(modules) { module in
                    moduleCard(module)
                }

                contactCard
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Aide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func moduleCard(_ module: Module) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemImage: module.icon, tint: module.tint, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(module.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(module.body)
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    /// Largeur de la photo de l'auteur : 60 % de l'écran (le prompt), pas de
    /// la carte — sinon elle rétrécit avec les marges au lieu de rester une
    /// proportion stable de l'appareil.
    private var authorImageWidth: CGFloat { UIScreen.main.bounds.width * 0.6 }

    /// Largeur de la colonne icône + espacement du `moduleCard` — reprise ici
    /// pour aligner la photo sous le même retrait que le titre et le texte.
    private static let cardLeadingInset: CGFloat = 42 + 14

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                IconBadge(systemImage: "envelope.fill", tint: Theme.accent, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Contactez le développeur")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Vos retours et suggestions pour améliorer l'app sont toujours les bienvenus : tout est lu, et chaque message compte. En cas de bug ou de comportement inattendu, n'hésitez pas à écrire par e-mail, en précisant le modèle de votre iPhone ou iPad, la version d'iOS, et une courte description du problème.")
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Link("variospeed67@gmail.com", destination: URL(string: "mailto:variospeed67@gmail.com")!)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            HStack {
                Spacer().frame(width: Self.cardLeadingInset)
                Image("Author")
                    .resizable()
                    .scaledToFit()
                    .frame(width: authorImageWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
