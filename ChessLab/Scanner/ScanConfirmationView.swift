import ChessKit
import SwiftUI

/// Écran de confirmation du scanner — **obligatoire** : le prompt interdit
/// toute action directe image → moteur. Rien de ce qui sort d'ici n'a
/// échappé au regard de l'utilisateur.
///
/// C'est l'éditeur du Lot 1.A pré-rempli avec la position lue, augmenté des
/// deux choses qu'une image ne peut pas donner : l'orientation de lecture et
/// le trait. Les cases douteuses sont surlignées ; toute correction se fait
/// à la palette, comme dans l'éditeur.
struct ScanConfirmationView: View {
    let reading: BoardScanReading
    @Binding var rotation: BoardReadingRotation
    /// Les 64 vignettes de l'image d'origine, `[ligne][colonne]`, avant toute
    /// rotation : de quoi montrer, à côté d'une case douteuse, ce que l'image
    /// contient vraiment.
    var squareImages: [[CGImage]]? = nil
    let exit: PositionEditorExit
    let onBackToCrop: () -> Void

    /// Les cases douteuses déjà passées en revue, et celle qu'on regarde.
    @State private var reviewed: Set<Square> = []
    @State private var focusedIndex = 0

    /// Les cases douteuses restant à vérifier, les moins sûres d'abord.
    private var pending: [Square] {
        reading.reviewSquares(rotation: rotation).filter { !reviewed.contains($0) }
    }

    private var focusedSquare: Square? {
        let squares = pending
        guard !squares.isEmpty else { return nil }
        return squares[min(focusedIndex, squares.count - 1)]
    }

    var body: some View {
        PositionEditorView(
            // Le trait ne se lit JAMAIS sur une image, mais un roi en échec le
            // trahit (``BoardScanReading/suggestedSideToMove(rotation:)``) ;
            // sans indice, les Blancs. C'est ensuite la section « Trait » de
            // l'éditeur qui fait autorité — un second contrôle ici créerait
            // deux sources de vérité pour la même donnée.
            initialFEN: reading.fen(rotation: rotation, sideToMove: reading.suggestedSideToMove(rotation: rotation)),
            exit: exit,
            title: "Vérifier la position",
            lowConfidenceSquares: Set(pending),
            unknownPieces: reading.unknownPieces(rotation: rotation),
            focusedSquare: focusedSquare
        ) { vm in
            VStack(alignment: .leading, spacing: 12) {
                kindCompletionSection(vm)
                reviewSection(vm)
                confidenceBanner
                rotationControls
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Recadrer", action: onBackToCrop)
            }
        }
        // Une rotation relit tout : les cases vérifiées ne sont plus les mêmes.
        .onChange(of: rotation) { _, _ in
            reviewed = []
            focusedIndex = 0
        }
    }

    // MARK: Revue des cases douteuses

    @ViewBuilder
    private func reviewSection(_ vm: PositionEditorViewModel) -> some View {
        let squares = pending
        if let square = focusedSquare, let current = reading.squares(rotation: rotation)[square] {
            let index = min(focusedIndex, squares.count - 1)
            ScanReviewSection(
                square: square, reading: current,
                image: thumbnail(of: square),
                remaining: squares.count, position: index + 1,
                onChoose: { choice in
                    withAnimation(Theme.gentle) { vm.place(choice, at: square) }
                    resolve(square)
                },
                onKeep: { resolve(square) },
                onPrevious: { focusedIndex = (index - 1 + squares.count) % squares.count },
                onNext: { focusedIndex = (index + 1) % squares.count }
            )
        }
    }

    /// La case est réglée : on passe à la suivante (la liste raccourcit, l'indice pointe déjà dessus).
    private func resolve(_ square: Square) {
        withAnimation(Theme.gentle) { _ = reviewed.insert(square) }
        focusedIndex = min(focusedIndex, max(pending.count - 1, 0))
    }

    /// La vignette de l'image d'origine pour une case de l'échiquier, une fois
    /// la rotation de lecture appliquée.
    private func thumbnail(of square: Square) -> CGImage? {
        guard let squareImages else { return nil }
        let rotated = BoardScanReading.rotate(squareImages, quarterTurns: rotation.rawValue)
        let row = 8 - square.rank.value
        guard let column = Square.File.allCases.firstIndex(of: square.file),
              rotated.indices.contains(row), rotated[row].indices.contains(column)
        else { return nil }
        return rotated[row][column]
    }

    // MARK: Complétion assistée des types (plateau réel)

    /// Un plateau réel vu du dessus donne l'occupation et la couleur, jamais
    /// le type : l'utilisateur le complète ici, **un tap par pièce**. La case
    /// en attente est cernée sur le plateau et la palette est filtrée à sa
    /// couleur — assigner fait passer à la suivante tout seul.
    ///
    /// Ordre des types : la dame d'abord, puis les plus nombreuses. Sur une
    /// position complète, l'utilisateur descend le plateau rangée par rangée
    /// et tape surtout « Pion ».
    @ViewBuilder
    private func kindCompletionSection(_ vm: PositionEditorViewModel) -> some View {
        if let square = vm.selectedUnknownSquare, let color = vm.selectedUnknownColor {
            SettingsSection(title: "Pièces à préciser", systemImage: "questionmark.circle.fill", tint: Theme.teal) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        "\(vm.unknownPieces.count) pièce(s) à préciser — case \(square.notation), pièce \(color == .white ? "blanche" : "noire").",
                        systemImage: "questionmark.square.dashed"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("kindCompletionBanner")
                    .accessibilityElement(children: .combine)

                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(Self.completionKinds, id: \.self) { kind in
                            // Pas d'identifiant technique : le libellé fait
                            // foi, comme pour la palette de l'éditeur (dont
                            // les tests UI cherchent « dame blanche »).
                            ChipButton(label: LocalizedStringKey(PieceNaming.frenchKind(kind)), systemImage: nil, isSelected: false) {
                                withAnimation(Theme.gentle) { vm.assignKindToSelectedUnknown(kind) }
                            }
                        }
                    }

                    Text("Une photo prise du dessus ne dit pas quelle pièce est laquelle : la couleur a été lue, le type vous revient.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private static let completionKinds: [Piece.Kind] = [.queen, .pawn, .rook, .bishop, .knight, .king]

    // MARK: Confiance

    private var lowConfidenceCount: Int { pending.count }

    /// Des cases ont été signalées au départ et toutes ont été passées en revue.
    private var allReviewed: Bool {
        !reviewed.isEmpty && pending.isEmpty
    }

    @ViewBuilder
    private var confidenceBanner: some View {
        if lowConfidenceCount > 0 {
            Label(
                "\(lowConfidenceCount) case(s) incertaine(s), surlignée(s) sur le plateau : vérifiez-les avant de continuer.",
                systemImage: "questionmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(Theme.warning)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 12)
            .accessibilityIdentifier("scanLowConfidenceBanner")
            .accessibilityElement(children: .combine)
        } else if allReviewed {
            Label("Toutes les cases douteuses ont été vérifiées — relisez le plateau une dernière fois.", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 12)
                .accessibilityIdentifier("scanReviewedBanner")
                .accessibilityElement(children: .combine)
        } else {
            Label("Toutes les cases ont été lues avec certitude — vérifiez tout de même.", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 12)
                .accessibilityIdentifier("scanConfidentBanner")
                .accessibilityElement(children: .combine)
        }
    }

    // MARK: Orientation de lecture

    /// Une image ne dit jamais de quel côté on la regarde — mais un diagramme
    /// numérique n'a que DEUX orientations plausibles (Blancs en bas ou en
    /// haut), d'où un simple bouton d'inversion. Le quart de tour n'existait
    /// que pour la photo zénithale de plateau réel, retirée le 20/07/2026.
    @ViewBuilder
    private var rotationControls: some View {
        SettingsSection(title: "Sens de lecture", systemImage: "arrow.triangle.2.circlepath", tint: Theme.teal) {
            VStack(alignment: .leading, spacing: 10) {
                ChipButton(label: "Inverser la lecture", systemImage: "arrow.up.arrow.down", isSelected: false) {
                    withAnimation(Theme.gentle) {
                        rotation = rotation == .none ? .half : .none
                    }
                }
                .accessibilityIdentifier("flipReading")

                Text(rotationHint)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var rotationHint: String {
        // Une clé du catalogue, pas un `String` interpolé : ce dernier n'est jamais
        // traduit, et l'anglais affichait cette phrase en français.
        LocalizationController.string(
            "Lecture pivotée de %lld°. Si le plateau apparaît à l'envers, inversez la lecture.",
            rotation.degrees
        )
    }
}
