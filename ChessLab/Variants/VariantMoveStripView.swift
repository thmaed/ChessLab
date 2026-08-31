import SwiftUI

/// Le ruban de coups des analyses de VARIANTES — même langage visuel que la
/// bande du mode Contre l'ordinateur (`MoveStripView`) : une capsule par
/// demi-coup, bordée de la couleur de sa catégorie d'évaluation, le coup
/// affiché en dégradé d'accent, défilement horizontal recentré sur lui.
///
/// Trois écrans (variantes Fairy, Chess960, Duck Chess) montraient les
/// coups en GRILLE verticale, chacun avec sa copie du même code ; la bande
/// unique remplace les trois. Elle parle en DEMI-COUPS (ply, 1-indexé)
/// plutôt qu'en ``MoveTree.Index`` : les parties de variantes sont des
/// lignes simples, sans arborescence.
struct VariantMoveStripView: View {
    let numberedMoves: [(number: Int, white: String, black: String?)]
    /// 0 = position de départ : aucune capsule n'est alors en surbrillance.
    let currentPly: Int
    let quality: [Int: MoveQuality]
    let onSelect: (Int) -> Void

    /// La hauteur que les écrans doivent RÉSERVER au bloc (capsules +
    /// marges + boîte), pour leurs budgets de plateau mesurés.
    static let reservedHeight: CGFloat = 54

    private var chips: [(ply: Int, numberLabel: String?, san: String)] {
        numberedMoves.flatMap { entry -> [(ply: Int, numberLabel: String?, san: String)] in
            var result: [(ply: Int, numberLabel: String?, san: String)] = [
                (entry.number * 2 - 1, "\(entry.number).", entry.white)
            ]
            if let black = entry.black {
                result.append((entry.number * 2, nil, black))
            }
            return result
        }
    }

    var body: some View {
        Group {
            if chips.isEmpty {
                Text("Aucun coup joué")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(chips, id: \.ply) { chip in
                                capsule(for: chip).id(chip.ply)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: currentPly) { _, ply in
                        withAnimation(Theme.gentle) {
                            proxy.scrollTo(max(ply, 1), anchor: .center)
                        }
                    }
                    .onAppear { proxy.scrollTo(max(currentPly, 1), anchor: .center) }
                }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func capsule(for chip: (ply: Int, numberLabel: String?, san: String)) -> some View {
        let isCurrent = chip.ply == currentPly
        // Symbole et bordure seulement pour les catégories remarquables — un
        // ruban où chaque capsule crie ne met plus rien en relief.
        let quality = quality[chip.ply].flatMap { $0.showsInMoveList ? $0 : nil }

        return Button {
            onSelect(chip.ply)
        } label: {
            HStack(spacing: 4) {
                if let numberLabel = chip.numberLabel {
                    Text(numberLabel)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(isCurrent ? Theme.background.opacity(0.7) : Theme.textTertiary)
                }
                Text(SANFormatter.display(chip.san))
                    .font(.callout.weight(isCurrent ? .bold : .medium))
                    .foregroundStyle(isCurrent ? Theme.background : Theme.textPrimary)
                if let quality {
                    qualityGlyph(quality, isCurrent: isCurrent)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                isCurrent ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surfaceElevated),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    quality.map { $0.tint.opacity(isCurrent ? 0 : 0.7) } ?? Theme.stroke,
                    lineWidth: quality == nil ? 1 : 1.5
                )
            )
        }
        .buttonStyle(.plain)
        // Sans label explicite, VoiceOver lirait le texte brut du glyphe
        // (« !! ») ou le nom du symbole SF — ni l'un ni l'autre ne dit
        // « coup brillant ». Même patron que la grille qu'on remplace.
        .accessibilityLabel(
            quality.map { Text(SANFormatter.display(chip.san) + ", " + $0.label) }
                ?? Text(SANFormatter.display(chip.san))
        )
    }

    @ViewBuilder
    private func qualityGlyph(_ quality: MoveQuality, isCurrent: Bool) -> some View {
        let tint = isCurrent ? Theme.background : quality.tint
        switch quality.icon {
        case let .text(text):
            Text(text)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(tint)
        case let .symbol(name):
            Image(systemName: name)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
        }
    }
}
