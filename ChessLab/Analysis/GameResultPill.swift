import SwiftUI

/// Pastille de RÉSULTAT : elle RESSEMBLE au camp qui a gagné.
///
/// Née dans la bibliothèque, extraite ici parce que l'accueil montrait les
/// mêmes parties avec une pastille émeraude uniforme : deux écrans, deux
/// langages pour le même résultat. La palette est celle de l'échiquier —
/// ivoire pour les Blancs, ardoise pour les Noirs, moitié-moitié pour la
/// nulle — et non des couleurs sémantiques (vert/rouge), qui supposeraient
/// un camp « bon ».
///
/// Règles héritées de la bibliothèque, qui restent vraies partout :
/// - l'ivoire n'est PAS le blanc du texte, l'ardoise n'est PAS le fond ;
/// - l'ardoise porte un liseré clair, sans quoi elle disparaîtrait dans le
///   fond de la carte, lui-même sombre ;
/// - la couleur ne porte jamais seule : le texte reste lisible dans la
///   pastille et VoiceOver annonce « Victoire des Blancs » — sinon
///   l'information s'évanouit pour un daltonien comme pour un non-voyant.
struct GameResultPill: View {
    let raw: String?

    private enum ResultStyle {
        case white, black, draw, unknown

        static func of(_ raw: String?) -> ResultStyle {
            switch raw {
            case "1-0": .white
            case "0-1": .black
            case "1/2-1/2", "1/2": .draw
            default: .unknown
            }
        }

        var label: String {
            switch self {
            case .white: "1-0"
            case .black: "0-1"
            // « 1/2-1/2 » est deux fois plus large que les autres et
            // déformait l'alignement des lignes sans rien apprendre de plus.
            case .draw: "1/2"
            case .unknown: "?"
            }
        }
    }

    /// Ivoire de la pièce claire — pas le blanc du texte.
    private static let ivory = Color(red: 0.898, green: 0.882, blue: 0.839)
    /// Ardoise de la pièce sombre, plus claire que le fond de carte pour
    /// rester une forme et non un trou.
    private static let slate = Color(red: 0.110, green: 0.133, blue: 0.180)

    var body: some View {
        let style = ResultStyle.of(raw)
        Text(style.label)
            .font(.caption2.monospaced().weight(.bold))
            .foregroundStyle(foreground(style))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            // Largeur commune : sans elle, « 1/2 » et « ? » rétrécissent la
            // pastille et les dates ne s'alignent plus d'une ligne à l'autre.
            .frame(minWidth: 34)
            .background { background(style) }
            .overlay {
                // Le liseré n'est utile qu'aux fonds sombres ou absents.
                if style != .white {
                    Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                }
            }
            .clipShape(Capsule())
            .accessibilityLabel(Self.resultDescription(raw))
    }

    private func foreground(_ style: ResultStyle) -> Color {
        switch style {
        case .white: Theme.background
        case .black: Theme.textPrimary
        // Sur une pastille mi-ivoire mi-ardoise, ni le clair ni le sombre ne
        // tiennent partout : le texte reste blanc et l'ivoire est assez
        // atténué de son côté pour qu'il se lise.
        case .draw: Theme.textPrimary
        case .unknown: Theme.textSecondary
        }
    }

    @ViewBuilder
    private func background(_ style: ResultStyle) -> some View {
        switch style {
        case .white:
            Capsule().fill(Self.ivory)
        case .black:
            Capsule().fill(Self.slate)
        case .draw:
            // Partagée, littéralement : la moitié gauche revient aux Blancs.
            Capsule().fill(
                LinearGradient(
                    stops: [
                        .init(color: Self.ivory.opacity(0.55), location: 0),
                        .init(color: Self.ivory.opacity(0.55), location: 0.5),
                        .init(color: Self.slate, location: 0.5),
                        .init(color: Self.slate, location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
        case .unknown:
            // Pas de résultat, pas de remplissage.
            Color.clear
        }
    }

    /// Ce que VoiceOver annonce : « 1-0 » ne se dit pas.
    static func resultDescription(_ raw: String?) -> String {
        switch raw {
        case "1-0": return LocalizationController.string("Victoire des Blancs")
        case "0-1": return LocalizationController.string("Victoire des Noirs")
        case "1/2-1/2", "1/2": return LocalizationController.string("Partie nulle")
        default: return LocalizationController.string("Résultat inconnu")
        }
    }
}
