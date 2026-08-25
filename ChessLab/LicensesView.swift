import SwiftUI

/// Licences des composants tiers embarqués dans ChessLab.
///
/// Existe pour deux raisons à la fois : honorer l'attribution requise par
/// la licence CC BY-SA des pièces cburnett, et rendre visibles — donc
/// difficiles à ignorer en revue — les mentions de copyright GPLv3 de
/// Stockfish ET de Fairy-Stockfish (voir le README, section licence, pour
/// le détail des obligations). Écran volontairement séparé de ``HelpView`` : l'un
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
            body: "Moteur d'échecs (Stockfish 17.1), compilé depuis ses sources C++ directement dans l'app. Cette licence impose la mise à disposition du code source complet de ChessLab, publié pour s'y conformer.",
            url: URL(string: "https://stockfishchess.org")
        ),
        .init(
            icon: "die.face.5.fill", tint: Theme.violet,
            name: "Fairy-Stockfish",
            license: "Licence GPLv3",
            body: "Moteur d'échecs pour les variantes (Roi de la colline, Trois échecs, Horde), fork de Stockfish compilé depuis ses sources C++ directement dans l'app. Même obligation de licence : le code source complet de ChessLab est publié pour s'y conformer.",
            url: URL(string: "https://fairy-stockfish.github.io")
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
            name: "ChessKit",
            license: "Licence MIT",
            body: "Règles du jeu (FEN/PGN/SAN). Bibliothèque Swift sous licence MIT.",
            url: URL(string: "https://github.com/chesskit-app/chesskit-swift")
        ),
        .init(
            icon: "crown.fill", tint: Theme.warning,
            name: "Pièces d'échiquier (cburnett)",
            license: "Licence CC BY-SA 3.0",
            body: "Jeu de pièces vectorielles par Colin M. L. Burnett, le même que Wikipédia et Lichess. Attribution requise, partage dans les mêmes conditions.",
            url: URL(string: "https://commons.wikimedia.org/wiki/User:Cburnett")
        ),
        .init(
            icon: "crown.fill", tint: Theme.warning,
            name: "Jeu de pièces « chessnut »",
            license: "Licence Apache 2.0",
            body: "Jeu de pièces vectorielles moderne par Alexis Luengas, issu de la collection open source de Lichess. Compatible avec la licence GPLv3 de l'app.",
            url: URL(string: "https://github.com/LexLuengas/chessnut-pieces")
        ),
        .init(
            icon: "crown.fill", tint: Theme.warning,
            name: "Jeu de pièces « merida »",
            license: "Licence GPLv2+",
            body: "Jeu de pièces vectorielles par Armando Hernandez Marroquin, issu de la collection open source de Lichess. Compatible avec la licence GPLv3 de l'app.",
            url: URL(string: "https://github.com/lichess-org/lila/tree/master/public/piece/merida")
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
