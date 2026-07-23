import SwiftUI

/// Licences des composants tiers embarqués dans ChessLab.
///
/// Existe pour deux raisons à la fois : honorer l'attribution requise par
/// la licence CC BY-SA des pièces cburnett, et rendre visibles — donc
/// difficiles à ignorer en revue — les mentions de copyright GPLv3 de
/// Stockfish (voir le README, section licence, pour le détail des
/// obligations). Écran volontairement séparé de ``HelpView`` : l'un
/// explique l'app, l'autre ce qu'elle embarque.
struct LicensesView: View {
    private struct Entry: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let name: LocalizedStringKey
        let license: LocalizedStringKey
        let body: LocalizedStringKey
        let url: URL?
    }

    private let entries: [Entry] = [
        .init(
            icon: "cpu", tint: Theme.accent,
            name: "Stockfish",
            license: "Licence GPLv3",
            body: "Moteur d'échecs, intégré via ChessKitEngine. Cette licence impose la mise à disposition du code source complet de ChessLab, publié pour s'y conformer.",
            url: URL(string: "https://stockfishchess.org")
        ),
        .init(
            icon: "chevron.left.forwardslash.chevron.right", tint: Theme.info,
            name: "Code source de ChessLab",
            license: "GPLv3 (l'app entière)",
            body: "L'intégration de Stockfish fait de ChessLab, dans son ensemble, une œuvre dérivée sous GPLv3. Le code source, correspondant au binaire distribué, est publié ici.",
            url: URL(string: "https://github.com/thmaed/ChessLab")
        ),
        .init(
            icon: "shippingbox.fill", tint: Theme.teal,
            name: "ChessKit & ChessKitEngine",
            license: "Licence MIT",
            body: "Règles du jeu (FEN/PGN/SAN) et intégration UCI de Stockfish. Le wrapper lui-même est sous licence MIT ; seul le Stockfish qu'il embarque est sous GPLv3.",
            url: URL(string: "https://github.com/chesskit-app")
        ),
        .init(
            icon: "crown.fill", tint: Theme.warning,
            name: "Pièces d'échiquier (cburnett)",
            license: "Licence CC BY-SA 3.0",
            body: "Jeu de pièces vectorielles par Colin M. L. Burnett, le même que Wikipédia et Lichess. Attribution requise, partage dans les mêmes conditions.",
            url: URL(string: "https://commons.wikimedia.org/wiki/User:Cburnett")
        ),
        .init(
            icon: "puzzlepiece.fill", tint: Theme.violet,
            name: "Base de puzzles Lichess",
            license: "Domaine public (CC0)",
            body: "Les puzzles tactiques proposés dans l'app sont issus de la base de données publique de Lichess.",
            url: URL(string: "https://database.lichess.org/#puzzles")
        ),
        .init(
            icon: "network", tint: Theme.rose,
            name: "Réseaux NNUE Stockfish",
            license: "Licence GPLv3",
            body: "Réseaux de neurones utilisés par le moteur pour évaluer les positions, publiés par le projet Stockfish.",
            url: URL(string: "https://tests.stockfishchess.org")
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Bibliothèques, jeux de données et assets tiers utilisés par ChessLab.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 2)

                ForEach(entries) { entry in
                    entryCard(entry)
                }
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Licences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func entryCard(_ entry: Entry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemImage: entry.icon, tint: entry.tint, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(entry.license)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.tint)
                Text(entry.body)
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                if let url = entry.url {
                    Link(destination: url) {
                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
