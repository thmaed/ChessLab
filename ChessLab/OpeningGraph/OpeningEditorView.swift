import ChessKit
import SwiftUI

/// Éditeur d'arbre d'un répertoire PERSONNEL : jouer un coup sur l'échiquier
/// l'ajoute, une variante se retire d'un balayage, un commentaire s'écrit sur
/// place.
///
/// Même disposition que le lecteur — plateau ANCRÉ, seul le texte défile —
/// pour la raison qui l'avait imposée là-bas : on écrit une variante en
/// REGARDANT la position, et un plateau qui sort de l'écran rend l'écran
/// inutilisable (retour testeur du 15/08).
///
/// Le geste central est l'ajout : il n'y a pas de bouton « ajouter un coup »,
/// on joue le coup. Le reste de l'app apprend déjà à jouer sur un échiquier ;
/// un éditeur qui demanderait de saisir « Cf3 » au clavier serait un formulaire
/// déguisé en jeu d'échecs.
struct OpeningEditorView: View {
    @Bindable var viewModel: OpeningEditorViewModel
    let onExit: () -> Void

    @State private var appSettings = AppSettings.shared
    @State private var editingEdge: MoveEdge?
    @State private var commentDraft: String = ""
    @State private var isRenaming = false
    @State private var nameDraft: String = ""

    private var boardTheme: BoardTheme { appSettings.boardTheme }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height * 1.1 {
                wideLayout(size: geo.size)
            } else {
                tallLayout(size: geo.size)
            }
        }
        .appBackground()
        .navigationTitle(LocalizedStringKey(viewModel.course.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    nameDraft = viewModel.course.name
                    isRenaming = true
                } label: {
                    Label("Renommer", systemImage: "pencil")
                }
                .tint(Theme.accent)
                .accessibilityIdentifier("renameCourse")
            }
        }
        .alert("Renommer le répertoire", isPresented: $isRenaming) {
            TextField("Nom", text: $nameDraft)
            Button("Annuler", role: .cancel) {}
            Button("Enregistrer") { viewModel.rename(to: nameDraft) }
        }
        .sheet(item: $editingEdge) { edge in
            commentSheet(for: edge)
        }
        .alert(
            "Modification impossible",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: Dispositions

    private func tallLayout(size: CGSize) -> some View {
        let side = min(size.width - 32, size.height * 0.5, 520)
        return VStack(spacing: 0) {
            board
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            panel
            controlBar
        }
    }

    private func wideLayout(size: CGSize) -> some View {
        let side = min(size.height - 24, size.width * 0.5, 560)
        return HStack(spacing: 0) {
            board
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 0) {
                panel
                controlBar
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var board: some View {
        ChessBoardView(
            board: viewModel.board,
            orientation: viewModel.orientation.color,
            theme: boardTheme,
            selectedSquare: viewModel.selectedSquare,
            legalTargetSquares: viewModel.legalTargets,
            lastMove: viewModel.lastMove,
            hintMoves: [],
            interactionEnabled: true,
            showCoordinates: true,
            // Seules les pièces du camp au trait se glissent : le graphe
            // alterne les couleurs, un coup hors tour n'a pas de sens.
            draggableColor: viewModel.board.position.sideToMove,
            onTapSquare: { viewModel.tap($0) },
            onDropPiece: { start, end in viewModel.drop(from: start, to: end) }
        )
    }

    // MARK: Panneau

    private var panel: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !viewModel.trail.isEmpty { moveTrail }
                hint
                movesSection
                Spacer(minLength: 8)
            }
            .padding(.vertical, 12)
        }
    }

    private var moveTrail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(viewModel.trail.enumerated()), id: \.offset) { index, step in
                    let isCurrent = index == viewModel.trail.count - 1
                    Button { viewModel.jump(toPly: index + 1) } label: {
                        Text(trailLabel(index: index, san: step.san))
                            .font(.caption.weight(.semibold).monospaced())
                            .foregroundStyle(isCurrent ? Theme.background : Theme.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(
                                isCurrent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surface),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func trailLabel(index: Int, san: String) -> String {
        index % 2 == 0 ? "\(index / 2 + 1). \(san)" : san
    }

    /// La consigne est PERMANENTE.
    ///
    /// 🐛 Elle ne s'affichait que sur une position sans suite. Dès qu'un coup
    /// existait, elle disparaissait et l'écran ressemblait à une liste en
    /// lecture seule : l'utilisateur a demandé si l'éditeur « ne servait qu'à
    /// renommer ou supprimer ». L'ajout est pourtant le geste CENTRAL, et il
    /// n'a pas de bouton — on joue le coup. Un geste sans bouton doit être
    /// annoncé, sinon il n'existe pas.
    ///
    /// Le ton change avec le contexte : invitation quand la position est
    /// vierge, rappel discret ensuite.
    private var hint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .foregroundStyle(Theme.accent)
            Text(viewModel.moves.isEmpty
                 ? "Joue un coup sur l'échiquier pour l'ajouter à ton répertoire."
                 : "Joue un autre coup sur l'échiquier pour ajouter une variante.")
                .font(.subheadline)
                .foregroundStyle(viewModel.moves.isEmpty ? Theme.textSecondary : Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .cardStyle()
        .padding(.horizontal, 16)
    }

    private var movesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Coups depuis cette position")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("\(viewModel.positionCount) positions")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 16)

            // Ce que font les deux icônes de chaque ligne. Une bulle et une
            // corbeille se devinent, mais « commenter » ne se devine pas comme
            // « écrire ce que l'élève lira pendant sa révision ».
            if !viewModel.moves.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble").foregroundStyle(Theme.accent)
                    Text("commenter").foregroundStyle(Theme.textTertiary)
                    Image(systemName: "trash").foregroundStyle(Theme.danger)
                        .padding(.leading, 8)
                    Text("supprimer la variante").foregroundStyle(Theme.textTertiary)
                    Spacer()
                }
                .font(.caption2)
                .padding(.horizontal, 16)
            }

            ForEach(viewModel.moves, id: \.uci) { edge in
                moveRow(edge)
            }
        }
    }

    private func moveRow(_ edge: MoveEdge) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { viewModel.enter(edge) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(edge.san)
                        .font(.headline.monospaced())
                        .foregroundStyle(Theme.textPrimary)
                    if let comment = viewModel.comment(for: edge) {
                        Text(comment)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)

            Button {
                commentDraft = viewModel.comment(for: edge) ?? ""
                editingEdge = edge
            } label: {
                Image(systemName: viewModel.comment(for: edge) == nil ? "text.bubble" : "text.bubble.fill")
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Commenter \(edge.san)")

            Button(role: .destructive) {
                viewModel.delete(edge)
            } label: {
                Image(systemName: "trash").foregroundStyle(Theme.danger)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Supprimer \(edge.san)")
        }
        .cardStyle()
        .padding(.horizontal, 16)
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button { viewModel.back() } label: {
                Label("Précédent", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pressable)
            .disabled(viewModel.isAtRoot)
            .opacity(viewModel.isAtRoot ? 0.4 : 1)

            Button { onExit() } label: {
                Label("Terminer", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("finishEditing")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Commentaire

    private func commentSheet(for edge: MoveEdge) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ce texte s'affichera sous le coup \(edge.san) pendant la révision.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                TextEditor(text: $commentDraft)
                    .frame(minHeight: 140)
                    .padding(8)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                Spacer()
            }
            .padding(16)
            .appBackground()
            .navigationTitle("Commenter \(edge.san)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { editingEdge = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        viewModel.setComment(commentDraft, for: edge)
                        editingEdge = nil
                    }
                }
            }
        }
        .presentationSizing(.page)
    }
}

/// `sheet(item:)` exige `Identifiable` ; l'UCI identifie une arête de façon
/// stable dans une position donnée.
extension MoveEdge: Identifiable {
    public var id: String { uci }
}

/// Charge le répertoire personnel et n'ouvre l'éditeur que s'il existe
/// vraiment.
///
/// Contrairement aux autres hôtes de ce module, celui-ci ne passe PAS par
/// `SessionStore` : une session d'édition ne se reprend pas. Le cours est déjà
/// sur le disque après chaque geste, donc il n'y a aucun état en vol à
/// conserver — et repartir de la racine est le comportement attendu quand on
/// rouvre un répertoire.
struct OpeningEditorHost: View {
    let courseID: String
    let onExit: () -> Void

    @State private var viewModel: OpeningEditorViewModel?

    var body: some View {
        Group {
            if let viewModel {
                OpeningEditorView(viewModel: viewModel, onExit: onExit)
            } else {
                unavailable
            }
        }
        .onAppear {
            guard viewModel == nil,
                  UserOpeningStore.isUserCourse(id: courseID),
                  let course = UserOpeningStore.shared.course(id: courseID)
            else { return }
            viewModel = OpeningEditorViewModel(course: course)
        }
    }

    private var unavailable: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.folder")
                .font(.largeTitle).foregroundStyle(Theme.textTertiary)
            Text("Ce répertoire est introuvable.")
                .font(.headline).foregroundStyle(Theme.textSecondary)
            Button("Retour") { onExit() }
                .buttonStyle(.pressable)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
}
