import SwiftUI

/// Rangée de contrôle de l'écran *Jouer*, extraite de ``PlayView`` pour être
/// **mesurable hors interface** — même parti pris que ``BoardGeometry`` : la
/// géométrie qui pose problème vit dans un type qu'un test unitaire peut
/// instancier, pas dans une méthode privée de vue.
///
/// ## Le défaut qu'elle corrige (22/08)
///
/// Un testeur en **Zoom d'affichage** (iPhone 11 Pro : 320 pt de large au lieu
/// de 375) voyait TOUT l'écran de jeu rogné — les deux lignes joueurs, la
/// barre, et surtout le plateau, coupé d'une demi-colonne de chaque côté.
///
/// La cause n'était pas le plateau. `HStack(spacing: 10)` réserve ses écarts
/// quoi qu'il arrive : six boutons de 46 pt figés et six écarts de 10 font
/// **336 pt incompressibles**, soit 360 pt avec la marge du conteneur. Sous
/// cette largeur, la pile de ``PlayView`` devenait plus large que l'écran et
/// centrait tous ses enfants à cheval sur les deux bords. Le plateau, qui
/// reprend la largeur de la pile et y ajoute ses 24 pt de bord à bord, était
/// le plus visiblement touché — d'où le faux coupable.
///
/// Les écarts cèdent maintenant avant l'écran (``elasticGap``). Les boutons
/// gardent leurs 46 pt, donc leur cible tactile HIG, et la barre tombe à
/// **276 pt incompressibles** : elle tient dans les 296 pt utiles d'un écran
/// de 320. À 375 pt le rendu est inchangé — les écarts reprennent leurs 10 pt
/// dès qu'il y a la place. `PlayControlBarLayoutTests` chiffre les deux.
struct PlayControlBar: View {

    // MARK: État lu

    let hasMoves: Bool
    let displayedPly: Int
    let totalPlies: Int
    let isReviewing: Bool
    let canResumeFromReview: Bool
    /// Nombre de coups écartés par la reprise qu'on peut encore annuler,
    /// `nil` quand il n'y a rien à annuler. Pilote la pastille « Annuler ».
    let undoableResumeCount: Int?
    /// « Coups joués » n'existe que dans la disposition iPhone : ailleurs, la
    /// liste est déjà à l'écran.
    let showMoveList: Bool
    let hintsWanted: Bool
    let hintsEnabled: Bool
    let isFinished: Bool
    let isEngineThinking: Bool

    // MARK: Actions

    let onPrevious: () -> Void
    let onNext: () -> Void
    let onResumeHere: () -> Void
    let onUndoResume: () -> Void
    let onToggleHint: () -> Void
    let onShowMoveList: () -> Void
    /// `nil` masque le bouton « ½ ».
    ///
    /// Il ne se propose pas partout : contre l'ordinateur dans une variante,
    /// personne n'est là pour négocier, et en Duck Chess la nulle n'existe
    /// même pas — on gagne en capturant le roi. Ces écrans passaient jusqu'ici
    /// une fermeture VIDE : le bouton s'affichait, on pouvait le presser, et
    /// il ne se passait rien. Un bouton mort promet quelque chose que l'écran
    /// ne tient pas ; mieux vaut ne pas le montrer.
    let onOfferDraw: (() -> Void)?
    let onResign: () -> Void

    /// Côté d'un bouton rond. Le minimum des Human Interface Guidelines est
    /// 44 pt : ces 46 ne se négocient pas quand la place manque, ce sont les
    /// écarts qui cèdent.
    static let buttonSide: CGFloat = 46
    /// Écart nominal entre deux boutons, **plafond** et non plancher.
    static let nominalGap: CGFloat = 10

    var body: some View {
        HStack(spacing: 0) {
            controlButton(
                "chevron.left",
                label: "Coup précédent",
                disabled: !hasMoves || displayedPly == 0,
                action: onPrevious
            )
            // Raccourcis clavier iPad : ←/→ parcourent la partie, comme avant.
            .keyboardShortcut(.leftArrow, modifiers: [])
            elasticGap
            controlButton(
                "chevron.right",
                label: "Coup suivant",
                disabled: !hasMoves || displayedPly >= totalPlies,
                action: onNext
            )
            .keyboardShortcut(.rightArrow, modifiers: [])

            // « Reprendre ici » n'apparaît qu'en consultation d'un coup passé —
            // c'est aussi le signe visible qu'on n'est plus sur la position vive.
            if isReviewing, canResumeFromReview {
                elasticGap
                Button(action: onResumeHere) {
                    Text("Reprendre ici")
                        .font(.caption.weight(.semibold))
                        // La pastille est le seul élément de la rangée dont la
                        // largeur dépend d'un texte traduit : sur un écran
                        // étroit, elle rétrécit plutôt que de pousser un bouton
                        // hors de l'écran.
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.pressable)
                .transition(.opacity)
            }

            // Juste après la reprise, la même place accueille l'annulation :
            // le doigt est déjà là, le retour en arrière ne coûte qu'un geste
            // au même endroit. Elle s'efface d'elle-même au bout de 8 s.
            // `!isFinished` : après un abandon dans la fenêtre des 8 s, la
            // pastille proposerait d'annuler la reprise d'une partie FINIE —
            // le view model refuse désormais, la barre ne doit rien promettre.
            if !isReviewing, !isFinished, let undoableResumeCount {
                elasticGap
                Button(action: onUndoResume) {
                    // Texte SEUL, comme « Reprendre ici » : une icône ajoutée
                    // devant coûtait 17 pt incompressibles (image + écart), et
                    // ces 17 pt suffisaient à faire déborder la rangée sur un
                    // iPhone en Zoom d'affichage — mesuré, voir
                    // `PlayControlBarLayoutTests`.
                    Text("Annuler la reprise")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceElevated, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)
                .transition(.opacity)
                .accessibilityHint("Rétablit les \(undoableResumeCount) coups écartés")
            }

            Spacer(minLength: 0)

            controlButton(
                "lightbulb.fill",
                label: hintsWanted ? "Arrêter l'indice" : "Indice",
                tint: hintsWanted ? Theme.accent : Theme.textPrimary,
                highlighted: hintsWanted,
                disabled: !hintsEnabled || isFinished,
                action: onToggleHint
            )
            // « Coups joués » ne coexiste ni avec « Reprendre ici » ni avec
            // « Annuler » : la pastille prend la place de la liste, si bien que
            // la rangée tient sur UNE ligne même sur les iPhone étroits.
            if showMoveList, !isReviewing, undoableResumeCount == nil {
                elasticGap
                controlButton(
                    "list.bullet",
                    label: "Coups joués",
                    disabled: false,
                    action: onShowMoveList
                )
            }
            if let onOfferDraw {
                elasticGap
                controlButton(
                    text: "½",
                    label: "Proposer nulle",
                    tint: Theme.info,
                    disabled: isFinished || isEngineThinking,
                    action: onOfferDraw
                )
            }
            elasticGap
            controlButton(
                "flag.fill",
                label: "Abandonner",
                tint: Theme.danger,
                disabled: isFinished,
                action: onResign
            )
        }
        .animation(Theme.gentle, value: isReviewing)
        .animation(Theme.gentle, value: undoableResumeCount)
    }

    /// Écart de 10 pt **qui sait se réduire jusqu'à 0**.
    ///
    /// C'est toute la correction : l'espacement d'un `HStack` est un plancher,
    /// celui-ci est un plafond. Tant qu'il y a la place, il vaut ses 10 pt et
    /// le rendu est celui d'avant ; quand elle manque, il cède avant l'écran.
    private var elasticGap: some View {
        Spacer(minLength: 0).frame(maxWidth: Self.nominalGap)
    }

    private func controlButton(
        _ systemImage: String? = nil,
        text: String? = nil,
        label: LocalizedStringKey,
        tint: Color = Theme.textPrimary,
        highlighted: Bool = false,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let text {
                    Text(text).font(.system(size: 19, weight: .bold, design: .rounded))
                } else if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 17, weight: .medium))
                }
            }
            .foregroundStyle(disabled ? Theme.textTertiary : tint)
            .frame(width: Self.buttonSide, height: Self.buttonSide)
            .background(highlighted ? Theme.accent.opacity(0.16) : Theme.surface, in: Circle())
            .overlay(Circle().strokeBorder(highlighted ? Theme.accent.opacity(0.5) : Theme.stroke, lineWidth: 1))
            .glow(Theme.accent, radius: 7, isActive: highlighted)
        }
        .buttonStyle(.pressable)
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}
