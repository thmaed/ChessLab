import ChessKit
import SwiftUI

/// Notation FIGURINE : le dessin de la pièce à la place de sa lettre
/// (« ♘f3 » plutôt que « Nf3 » ou « Cf3 »).
///
/// C'est la notation des livres et des revues d'échecs, et elle a un mérite
/// concret ici : elle est **indépendante de la langue**. L'app propose déjà la
/// notation française et l'anglaise (``PieceNotation``), et l'index des lignes
/// aligne des dizaines de coups où un « F » français et un « B » anglais
/// désignent la même pièce. Le glyphe supprime la question.
///
/// Le dessin utilisé est celui du JEU DE PIÈCES choisi par l'utilisateur
/// (``AppSettings/pieceSet``) : la notation et l'échiquier montrent la même
/// pièce, ce qui est tout l'intérêt d'un symbole plutôt que d'une lettre.
///
/// - important: transformation d'AFFICHAGE, et rien d'autre — même discipline
///   que ``SANFormatter``. Ne jamais appliquer aux SAN stockés, comparés ou
///   exportés : le standard PGN est en lettres anglaises.
enum FigurineSAN {

    /// Un morceau de coup à afficher : soit une pièce (à dessiner), soit du
    /// texte qui passe intact (cases, « x », « + », « O-O »…).
    enum Token: Hashable {
        case piece(Piece.Kind)
        case text(String)
    }

    /// Lettres de pièce du standard PGN (anglaises, majuscules seulement — un
    /// « b » minuscule est la colonne b, jamais le fou).
    private static let kinds: [Character: Piece.Kind] = [
        "K": .king, "Q": .queen, "R": .rook, "B": .bishop, "N": .knight,
    ]

    /// Découpe un SAN anglais en morceaux affichables.
    ///
    /// Deux endroits seulement portent une lettre de pièce, et ce sont les
    /// deux que l'on remplace :
    /// - le PREMIER caractère (« Nf3 », « Qxd5+», « Rae1 ») ;
    /// - la promotion, après le « = » (« e8=Q+ »).
    ///
    /// Tout le reste traverse tel quel. Le roque (« O-O ») n'a pas de lettre de
    /// pièce : c'est du texte, et le « O » n'est pas confondu avec autre chose
    /// puisque seul le premier caractère est consulté pour la pièce.
    static func tokens(for san: String) -> [Token] {
        guard !san.isEmpty else { return [] }
        var result: [Token] = []
        var pending = ""

        let characters = Array(san)
        // Le roque commence par « O » : aucune lettre de pièce à y chercher.
        let startsWithCastle = san.hasPrefix("O-O")

        var index = 0
        if !startsWithCastle, let kind = kinds[characters[0]] {
            result.append(.piece(kind))
            index = 1
        }

        while index < characters.count {
            let character = characters[index]
            // Promotion : « = » suivi d'une lettre de pièce.
            if character == "=", index + 1 < characters.count, let kind = kinds[characters[index + 1]] {
                pending.append("=")
                if !pending.isEmpty { result.append(.text(pending)); pending = "" }
                result.append(.piece(kind))
                index += 2
                continue
            }
            pending.append(character)
            index += 1
        }
        if !pending.isEmpty { result.append(.text(pending)) }
        return result
    }

    /// Le SAN en LETTRES, dans la notation réglée par l'utilisateur — la
    /// version lue par VoiceOver, et le repli partout où un dessin n'a pas sa
    /// place (export, champ de recherche, message d'erreur).
    @MainActor
    static func spoken(_ san: String) -> String { SANFormatter.display(san) }
}

/// Un coup en notation figurine : le dessin de la pièce suivi du reste du SAN.
///
/// Le glyphe est calé sur la HAUTEUR DE CAPITALE de la police courante (via
/// `@ScaledMetric`, donc il suit Dynamic Type) et non sur une taille fixe :
/// posé à côté du texte, un dessin doit avoir la taille d'une lettre, sinon la
/// ligne de coups danse.
struct FigurineSANText: View {
    let san: String
    /// Camp qui joue ce coup — décide de la couleur du dessin. Une notation
    /// figurine où toutes les pièces sont blanches est illisible dès qu'on
    /// aligne les coups des deux camps.
    let color: Piece.Color
    var font: Font = .subheadline.weight(.semibold).monospaced()
    /// Taille de référence du glyphe, mise à l'échelle par Dynamic Type.
    var glyphSize: CGFloat = 15
    /// Débord VISUEL du dessin par rapport à son empreinte de mise en page.
    ///
    /// Les pièces sont dessinées avec de l'air autour d'elles : à hauteur de
    /// capitale exacte, elles paraissent plus petites que les lettres qu'elles
    /// remplacent. On les dessine donc plus grandes que la place qu'elles
    /// occupent — la pastille, elle, ne bouge pas d'un point.
    var glyphOverscan: CGFloat = 1

    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(FigurineSAN.tokens(for: san).enumerated()), id: \.offset) { _, token in
                switch token {
                case let .piece(kind):
                    PieceGlyphView(piece: Piece(kind, color: color, square: .a1))
                        // Deux cadres : le premier fixe la taille DESSINÉE, le
                        // second l'empreinte de MISE EN PAGE. Le dessin déborde
                        // sans clipping et sans pousser quoi que ce soit.
                        .frame(width: glyphSize * scale * glyphOverscan,
                               height: glyphSize * scale * glyphOverscan)
                        .frame(width: glyphSize * scale, height: glyphSize * scale)
                        .padding(.trailing, 1)
                case let .text(text):
                    Text(text)
                        .font(font)
                        // Un coup ne se tronque JAMAIS. Mesuré dans un
                        // `FlowLayout`, un `Text` posé à sa largeur idéale
                        // exacte se rabat parfois sur « … » à un arrondi de
                        // rendu près : « ♞f6 » devenait « ♞… ». Même remède
                        // que ``FilterChip``, et pour la même raison.
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(FigurineSAN.spoken(san))
    }
}
