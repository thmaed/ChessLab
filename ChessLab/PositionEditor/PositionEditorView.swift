import ChessKit
import SwiftUI
import UIKit

/// Éditeur de position (étape 7 / Lot 1.A) : composer une position à la
/// main, la valider, puis la jouer, l'analyser ou en faire le départ d'une
/// série de laboratoire.
///
/// C'est aussi le **fallback exigé par le prompt** quand le scanner se
/// trompe, et le socle de son écran de confirmation (Lot 1.D).
///
/// Le routage reste dans ``HomeView`` (convention du projet) : cet écran ne
/// fait que remonter le FEN validé par callback.
/// Ce qu'un écran de composition de position (éditeur ou scanner) propose une
/// fois la position valide.
///
/// Type de PREMIER NIVEAU, et non imbriqué dans ``PositionEditorView`` : les
/// types imbriqués d'un générique sont distincts pour chaque spécialisation,
/// si bien qu'une sortie construite pour un éditeur sans en-tête ne serait pas
/// du même type que celle d'un éditeur avec en-tête — et le scanner, qui ne
/// fait que la transmettre, ne pourrait pas la déclarer.
/// Position imposée à l'éditeur par son appelant : le FEN lu, et les pièces
/// dont le type reste à préciser. Regroupées parce qu'elles changent toujours
/// ensemble (une rotation du scanner refait les deux).
struct PositionEditorSeed: Equatable {
    var fen: String?
    var unknownPieces: [Square: Piece.Color] = [:]
}

enum PositionEditorExit {
    /// Écran autonome (poussé depuis « Analyser ») : l'écran est le point de
    /// départ, il route lui-même vers un mode de jeu.
    case standalone(
        onPlay: (String) -> Void,
        onAnalyze: (String) -> Void,
        onUseAsLabStart: ((String) -> Void)? = nil
    )
    /// Ouvert depuis un écran qui ATTEND une position (réglages de nouvelle
    /// partie, départ de Labo) : une seule action, qui rend le FEN à
    /// l'appelant. Sans ce mode, « Jouer » depuis les réglages aurait
    /// redémarré sur les réglages MÉMORISÉS en jetant ceux que l'utilisateur
    /// venait de choisir à l'écran.
    case picker(label: String, action: (String) -> Void)
}

struct PositionEditorView<Header: View>: View {
    typealias Exit = PositionEditorExit

    /// `nil` = position standard.
    let initialFEN: String?
    let exit: Exit
    let title: LocalizedStringKey
    /// Cases dont la lecture du scanner est douteuse : surlignées pour que
    /// l'utilisateur les vérifie en priorité (Lot 1.D). Vide hors scanner.
    let lowConfidenceSquares: Set<Square>
    /// Pièces lues sur un plateau réel dont le type reste à préciser
    /// (Lot 1.E). Vide hors scanner.
    let unknownPieces: [Square: Piece.Color]
    /// Contenu propre à l'appelant, inséré sous le plateau (bandeaux et
    /// contrôles du scanner). `EmptyView` dans l'éditeur autonome.
    ///
    /// En-tête GÉNÉRIQUE plutôt qu'`AnyView` : le compilateur garde le type
    /// réel, et l'éditeur n'a pas à connaître le scanner. Il reçoit le
    /// ViewModel, seule source de vérité de la position — sans quoi la palette
    /// de complétion du scanner devrait tenir un second état de la même
    /// grille.
    @ViewBuilder let header: (PositionEditorViewModel) -> Header

    @State private var vm: PositionEditorViewModel
    @State private var appSettings = AppSettings.shared
    /// La palette et les actions de plateau sont REPLIÉES par défaut : une
    /// position reconnue par le scanner est le plus souvent correcte, l'écran
    /// n'a alors qu'à confirmer. On les déploie s'il y a des pièces à préciser
    /// (le scanner attend une saisie) ou d'un tap sur « Éditer le jeu ».
    @State private var isEditingExpanded: Bool

    init(
        initialFEN: String? = nil,
        exit: Exit,
        title: LocalizedStringKey = "Éditeur de position",
        lowConfidenceSquares: Set<Square> = [],
        unknownPieces: [Square: Piece.Color] = [:],
        @ViewBuilder header: @escaping (PositionEditorViewModel) -> Header
    ) {
        self.initialFEN = initialFEN
        self.exit = exit
        self.title = title
        self.lowConfidenceSquares = lowConfidenceSquares
        self.unknownPieces = unknownPieces
        self.header = header
        // Aucun effet de bord dans ce ViewModel (pas de moteur) : la règle
        // de l'hôte paresseux (`ActiveGameHost`) ne s'applique pas ici.
        let model = PositionEditorViewModel(fen: initialFEN)
        if let initialFEN, !unknownPieces.isEmpty {
            model.load(fen: initialFEN, unknownPieces: unknownPieces)
        }
        _vm = State(initialValue: model)
        _isEditingExpanded = State(initialValue: !unknownPieces.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PositionEditorBoardView(
                    pieces: vm.pieces,
                    orientation: vm.orientation,
                    theme: appSettings.boardTheme,
                    highlightedSquares: highlightedSquares,
                    unknownPieces: vm.unknownPieces,
                    selectedSquare: vm.selectedUnknownSquare
                ) { square in
                    withAnimation(Theme.gentle) { vm.apply(at: square) }
                }
                // Plein écran sur iPhone, borné sur iPad : au-delà, le
                // plateau écrase les contrôles hors de vue.
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)

                header(vm)
                editGameSection
                errorsBanner
                sideToMoveSection
                castlingSection
                enPassantSection
                fenSection
                exitActions
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .appBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // Le scanner refait sa lecture quand on pivote le plateau : la graine
        // change, l'éditeur doit repartir de la NOUVELLE lecture. Les
        // corrections manuelles sont alors écrasées — c'est le sens même d'une
        // rotation, qui relit tout.
        //
        // Sur la GRAINE et non sur le seul FEN : une rotation peut laisser le
        // FEN inchangé (position symétrique) tout en déplaçant les pièces à
        // préciser, et l'éditeur ne verrait rien passer.
        .onChange(of: seed) { _, newValue in
            if let fen = newValue.fen { vm.load(fen: fen, unknownPieces: newValue.unknownPieces) }
        }
    }

    // MARK: Plateau

    /// Ce que l'appelant impose à l'éditeur, en un seul bloc comparable.
    private var seed: PositionEditorSeed {
        PositionEditorSeed(fen: initialFEN, unknownPieces: unknownPieces)
    }

    private var highlightedSquares: Set<Square> {
        var squares = lowConfidenceSquares
        if let file = vm.enPassantFile {
            squares.insert(PositionEditorViewModel.square(file, vm.enPassantRank))
        }
        return squares
    }

    private var boardActions: some View {
        HStack(spacing: 8) {
            ChipButton(label: "Standard", systemImage: "arrow.counterclockwise", isSelected: false) {
                withAnimation(Theme.gentle) { vm.resetToStandard() }
            }
            ChipButton(label: "Vider", systemImage: "trash", isSelected: false) {
                withAnimation(Theme.gentle) { vm.clearBoard() }
            }
            ChipButton(label: "Inverser", systemImage: "arrow.up.arrow.down", isSelected: false) {
                withAnimation(Theme.gentle) { vm.flipOrientation() }
            }
        }
    }

    // MARK: Édition du plateau (repliable)

    /// Un seul en-tête « Éditer le jeu » qui déploie, au tap, la palette de
    /// pièces, la gomme et les actions de plateau (Standard / Vider /
    /// Inverser). Replié, l'écran ne montre que la position et les réglages
    /// qui comptent après une reconnaissance — pas l'outillage de composition.
    private var editGameSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(Theme.gentle) { isEditingExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.warning)
                        .frame(width: 22, height: 22)
                        .background(Theme.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text("Éditer le jeu")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(isEditingExpanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("editGameDisclosure")
            .accessibilityLabel("Éditer le jeu")
            .accessibilityAddTraits(isEditingExpanded ? [.isSelected] : [])

            if isEditingExpanded {
                VStack(spacing: 10) {
                    paletteRow(color: .white)
                    paletteRow(color: .black)

                    HStack(spacing: 8) {
                        eraserButton
                        Text(toolHint)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }

                    boardActions
                        .padding(.top, 2)
                }
                .cardStyle()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var toolHint: String {
        switch vm.selectedTool {
        case .eraser:
            return "Tapez une pièce pour la retirer."
        case let .piece(kind, color):
            return "Tapez une case pour poser un \(PieceNaming.french(kind, color: color)) ; re-tapez-le pour l'effacer."
        }
    }

    private func paletteRow(color: Piece.Color) -> some View {
        HStack(spacing: 8) {
            ForEach(PositionEditorViewModel.paletteKinds, id: \.self) { kind in
                paletteButton(kind: kind, color: color)
            }
        }
    }

    private func paletteButton(kind: Piece.Kind, color: Piece.Color) -> some View {
        let tool = PositionEditorViewModel.Tool.piece(kind: kind, color: color)
        let isSelected = vm.selectedTool == tool

        return Button {
            vm.selectedTool = tool
        } label: {
            // Une pièce noire sur la tuile sombre est illisible (vérifié par
            // capture) : même contour blanc que le bandeau des prises, qui
            // règle exactement ce problème. Inutile une fois la tuile
            // sélectionnée — son fond d'accent est clair.
            PieceGlyphView(
                piece: Piece(kind, color: color, square: .a1),
                outline: (color == .black && !isSelected) ? Color.white.opacity(0.85) : nil
            )
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .padding(.vertical, 5)
                .background(paletteBackground(isSelected: isSelected))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : Theme.stroke, lineWidth: 1)
                )
                .glow(Theme.accent, radius: 7, isActive: isSelected)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(PieceNaming.french(kind, color: color))
        .accessibilityIdentifier("palette_\(color == .white ? "w" : "b")\(kind.notation.isEmpty ? "P" : kind.notation)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func paletteBackground(isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if isSelected {
            shape.fill(Theme.accentGradient)
        } else {
            shape.fill(Theme.surfaceElevated)
        }
    }

    private var eraserButton: some View {
        let isSelected = vm.selectedTool == .eraser

        return Button {
            vm.selectedTool = .eraser
        } label: {
            Image(systemName: "eraser.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.background : Theme.textPrimary)
                .frame(width: 48, height: 40)
                .background(paletteBackground(isSelected: isSelected))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : Theme.stroke, lineWidth: 1)
                )
                .glow(Theme.accent, radius: 7, isActive: isSelected)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Gomme")
        .accessibilityIdentifier("palette_eraser")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Contrôles

    @ViewBuilder
    private var errorsBanner: some View {
        if !vm.errors.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(vm.errors, id: \.self) { error in
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 12)
            .accessibilityIdentifier("editorErrors")
            .accessibilityElement(children: .combine)
        }
    }

    /// Trait sur UNE ligne : le libellé, puis un pion blanc et un pion noir
    /// côte à côte — celui du camp au trait est mis en avant. Plus rapide à
    /// lire qu'une paire de chips « Aux Blancs / Aux Noirs », et deux fois
    /// moins haut.
    private var sideToMoveSection: some View {
        HStack(spacing: 10) {
            Text("Trait")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Spacer(minLength: 0)
            sideToMovePawn(.white)
            sideToMovePawn(.black)
        }
        .padding(.vertical, 4)
    }

    private func sideToMovePawn(_ color: Piece.Color) -> some View {
        let isSelected = vm.sideToMove == color
        return Button {
            withAnimation(Theme.snappySpring) { vm.sideToMove = color }
        } label: {
            PieceGlyphView(
                piece: Piece(.pawn, color: color, square: .a1),
                outline: (color == .black && !isSelected) ? Color.white.opacity(0.85) : nil
            )
            .frame(width: 30, height: 30)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.accentGradient : Theme.tintGradient(Theme.surfaceElevated))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Theme.stroke, lineWidth: 1)
            )
            .glow(Theme.accent, radius: 7, isActive: isSelected)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(color == .white ? "Trait aux blancs" : "Trait aux noirs")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Les quatre roques POSSIBLES dans la position (roi + tour sur leur case),
    /// avec l'état activé. Un roque impossible n'apparaît pas du tout.
    private var possibleCastlings: [(label: LocalizedStringKey, isOn: Binding<Bool>)] {
        var rows: [(LocalizedStringKey, Binding<Bool>)] = []
        if vm.isWhiteKingsideAvailable { rows.append(("O-O ⚪", $vm.whiteCanCastleKingside)) }
        if vm.isWhiteQueensideAvailable { rows.append(("O-O-O ⚪", $vm.whiteCanCastleQueenside)) }
        if vm.isBlackKingsideAvailable { rows.append(("O-O ⚫", $vm.blackCanCastleKingside)) }
        if vm.isBlackQueensideAvailable { rows.append(("O-O-O ⚫", $vm.blackCanCastleQueenside)) }
        return rows
    }

    /// Roques CONDENSÉS : une chip par roque possible, cliquable pour
    /// l'activer / le désactiver. Aucun roque possible (roi ou tours déplacés)
    /// → section entièrement masquée, plus de « toutes cases grisées ».
    @ViewBuilder
    private var castlingSection: some View {
        let castlings = possibleCastlings
        if !castlings.isEmpty {
            HStack(spacing: 8) {
                Text("Roques")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(Array(castlings.enumerated()), id: \.offset) { _, row in
                        ChipButton(label: row.label, systemImage: nil, isSelected: row.isOn.wrappedValue) {
                            row.isOn.wrappedValue.toggle()
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
    }

    /// Prise en passant CONDENSÉE : une chip par colonne possible (+ « Aucune »).
    /// Aucune prise possible → section masquée : c'est le cas le plus fréquent,
    /// autant ne pas occuper l'écran avec un message « rien ici ».
    @ViewBuilder
    private var enPassantSection: some View {
        let files = vm.availableEnPassantFiles
        if !files.isEmpty {
            HStack(spacing: 8) {
                Text("Prise en passant")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ChipButton(label: "Aucune", systemImage: nil, isSelected: vm.enPassantFile == nil) {
                        vm.enPassantFile = nil
                    }
                    ForEach(files, id: \.self) { file in
                        ChipButton(
                            label: "\(file.rawValue)\(vm.enPassantRank)",
                            systemImage: nil,
                            isSelected: vm.enPassantFile == file
                        ) {
                            vm.enPassantFile = file
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
    }

    /// FEN sur UNE ligne, tronquée, avec un bouton « Copier ». Le pavé
    /// monospace multiligne d'avant prenait quatre lignes pour une donnée
    /// qu'on ne fait que copier.
    private var fenSection: some View {
        HStack(spacing: 10) {
            Text(vm.fen)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("editorFEN")

            Button {
                UIPasteboard.general.string = vm.fen
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.doc")
                    Text("Copier")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Copier la position FEN")
            .accessibilityIdentifier("copyFEN")
        }
        .padding(.vertical, 4)
    }

    // MARK: Sorties

    @ViewBuilder
    private var exitActions: some View {
        switch exit {
        case let .standalone(onPlay, onAnalyze, onUseAsLabStart):
            VStack(spacing: 10) {
                exitButton(title: "Jouer cette position", systemImage: "play.fill", tint: Theme.accent) {
                    onPlay(vm.fen)
                }
                exitButton(title: "Analyser cette position", systemImage: "chart.line.uptrend.xyaxis", tint: Theme.info) {
                    onAnalyze(vm.fen)
                }
                if let onUseAsLabStart {
                    exitButton(title: "Départ du Laboratoire", systemImage: "flask.fill", tint: Theme.violet) {
                        onUseAsLabStart(vm.fen)
                    }
                }
            }

        case let .picker(label, action):
            exitButton(title: LocalizedStringKey(label), systemImage: "checkmark", tint: Theme.accent) {
                action(vm.fen)
            }
        }
    }

    private func exitButton(
        title: LocalizedStringKey, systemImage: String, tint: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.semibold)
                Spacer(minLength: 0)
            }
            .foregroundStyle(vm.isValid ? Theme.background : Theme.textTertiary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(exitButtonBackground(tint: tint))
        }
        .buttonStyle(.pressable)
        .disabled(!vm.isValid)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func exitButtonBackground(tint: Color) -> some View {
        if vm.isValid {
            Theme.controlShape.fill(Theme.tintGradient(tint))
        } else {
            Theme.controlShape.fill(Theme.surfaceElevated)
        }
    }
}

extension PositionEditorView where Header == EmptyView {
    /// Éditeur sans en-tête — l'usage courant (écran autonome, feuille de
    /// sélection de position).
    init(
        initialFEN: String? = nil,
        exit: Exit,
        title: LocalizedStringKey = "Éditeur de position",
        lowConfidenceSquares: Set<Square> = []
    ) {
        self.init(
            initialFEN: initialFEN, exit: exit, title: title,
            lowConfidenceSquares: lowConfidenceSquares
        ) { _ in EmptyView() }
    }
}
