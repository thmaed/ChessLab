import ChessKit
import SwiftUI

/// Fenêtre de choix de la pièce de promotion (Dame, Tour, Fou, Cavalier).
///
/// Apparaît sur **sept écrans** — toute promotion de pion —, donc son gabarit
/// se paie partout.
///
/// ## Ce qui a été corrigé (Lot 3.1)
///
/// La version d'origine était **incompressible** : quatre tuiles de
/// `10 + 56 + 10 = 76 pt`, trois espacements de 12 et deux marges de 20, soit
/// **380 pt** rigides — dans un iPhone SE de 375 pt. Mesuré, aucune tuile
/// n'était réellement coupée (les quatre tenaient entre 17,5 et 357,5 pt) :
/// ce qui dépassait, c'étaient les 2,5 pt de fond de carte de chaque côté. Le
/// symptôme était donc un liseré rogné, pas des boutons tronqués — moins
/// spectaculaire qu'annoncé, mais la rigidité, elle, était bien réelle et
/// explosait aux tailles d'accessibilité (« Cavalier » en `.caption` monte à
/// ~110 pt en AX1).
///
/// Désormais les tuiles se **partagent** la largeur disponible et le glyphe
/// suit, borné à 56 pt : la fenêtre s'adapte de l'iPhone SE au grand iPad.
///
/// ## Bug de localisation corrigé au passage
///
/// `choices` portait des `String`, et `Text(_: String)` **ne localise pas** :
/// « Dame / Tour / Fou / Cavalier » restaient en français même en anglais,
/// alors que les traductions existaient dans le catalogue. C'est aussi ce qui
/// rendait le pire cas de largeur permanent, l'anglais étant plus court.
struct PromotionPickerView: View {
    let color: Piece.Color
    let onSelect: (Piece.Kind) -> Void

    /// `LocalizedStringKey` et non `String` : voir la note de localisation.
    private let choices: [(kind: Piece.Kind, label: LocalizedStringKey)] = [
        (.queen, "Dame"), (.rook, "Tour"), (.bishop, "Fou"), (.knight, "Cavalier"),
    ]

    /// Côté maximal du glyphe. C'est un PLAFOND, plus un gabarit figé : sur
    /// un écran étroit la tuile donne moins, et le glyphe suit.
    private let maxGlyph: CGFloat = 56

    var body: some View {
        VStack(spacing: 16) {
            Text("Promotion")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 12) {
                ForEach(choices, id: \.kind) { choice in
                    Button {
                        onSelect(choice.kind)
                    } label: {
                        VStack(spacing: 6) {
                            PieceGlyphView(piece: Piece(choice.kind, color: color, square: .a1))
                                .frame(maxWidth: maxGlyph, maxHeight: maxGlyph)
                                .aspectRatio(1, contentMode: .fit)
                            Text(choice.label)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                // Le libellé ne dicte plus la largeur de la
                                // tuile : en taille d'accessibilité, il se
                                // réduit au lieu de pousser ses voisins dehors.
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        // Part égale de la largeur offerte — c'est ce qui rend
                        // l'ensemble compressible.
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(choice.label))
                }
            }
        }
        .padding(20)
        // Borne haute : sur un iPad, quatre tuiles étirées sur 1 200 pt
        // seraient absurdes.
        .frame(maxWidth: 420)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16)
        // Marge de sécurité : la carte ne touche jamais les bords de l'écran,
        // quel que soit l'écran qui la présente (elle est posée en `overlay`
        // par sept vues différentes).
        .padding(.horizontal, 12)
        // Identifiant sur la CARTE : le détecteur de débordement ignore les
        // conteneurs `.other`, donc les fonds de carte — c'est par cette
        // ancre que le test du Lot 5 mesure la fenêtre entière, et pas
        // seulement ses tuiles.
        .accessibilityIdentifier("promotionPicker")
    }
}
