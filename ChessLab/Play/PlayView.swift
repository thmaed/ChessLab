import ChessKit
import SwiftUI

/// Écran de jeu contre Stockfish, avec layouts adaptatifs iPhone/iPad.
struct PlayView: View {
    @Bindable var viewModel: PlayViewModel
    let onExit: () -> Void
    let onAnalyze: (String) -> Void
    var onRematch: (PlayGameSettings) -> Void = { _ in }
    /// Ouvre l'analyse sur la position AFFICHÉE (FEN) — sans attendre la fin
    /// de partie, contrairement à `onAnalyze` qui porte le PGN complet.
    var onAnalyzePosition: (String) -> Void = { _ in }
    /// Ouvre le Laboratoire pré-rempli avec la position affichée : deux
    /// moteurs y rejouent la position en série.
    var onOpenLab: (String) -> Void = { _ in }
    /// Bascule vers Deux joueurs (réglages neufs — cette partie contre le
    /// moteur reste dans la pile, comme pour le Laboratoire ci-dessus).
    var onOpenTwoPlayer: () -> Void = {}

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }
    /// Liaison manuelle : `AppSettings` est un singleton `@Observable`, pas
    /// une propriété `@Bindable` de la vue.
    private var boardThemeSelection: Binding<String> {
        Binding(get: { appSettings.boardThemeID }, set: { appSettings.boardThemeID = $0 })
    }
    @State private var showPanelSheet = false
    @State private var copiedMessage: String?
    @State private var showResignConfirmation = false
    @State private var showResumeConfirmation = false
    @State private var showDrawConfirmation = false

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // L'orientation, et non la classe de taille, décide de la
                // disposition : c'est la HAUTEUR disponible qui dit si un
                // plateau pleine largeur tient à l'écran. En Split View ou en
                // Stage Manager, une fenêtre étroite repasse en classe
                // compacte, donc sur la disposition iPhone — et c'est bien.
                GeometryReader { geo in
                    if geo.size.width > geo.size.height {
                        iPadWideLayout(size: geo.size)
                    } else {
                        iPadTallLayout
                    }
                }
            } else {
                iPhoneLayout
            }
        }
        .appBackground()
        .navigationTitle("Jouer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                exportMenu
                Menu {
                    // `Picker` et non des `Button` : le thème COURANT porte
                    // sa coche — avant, le menu ne disait pas lequel était
                    // actif et il fallait essayer pour voir.
                    Picker("Thème du plateau", selection: boardThemeSelection) {
                        ForEach(BoardTheme.all) { theme in
                            Text(LocalizedStringKey(theme.label)).tag(theme.id)
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Thème du plateau")
            }
        }
        .alert(
            "Copié",
            isPresented: Binding(
                get: { copiedMessage != nil },
                set: { if !$0 { copiedMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { copiedMessage = nil }
        } message: {
            Text(copiedMessage ?? "")
        }
        .overlay(alignment: .top) { engineUnavailableBanner }
        .overlay { promotionOverlay }
        .overlay { gameOverOverlay }
        .background(moveCountMarker)
        .modifier(GameDialogs(
            viewModel: viewModel,
            showResignConfirmation: $showResignConfirmation,
            showResumeConfirmation: $showResumeConfirmation,
            showDrawConfirmation: $showDrawConfirmation
        ))
        // Le couple appear/disappear, et pas seulement `disappear` : le view
        // model survit désormais à la reconstruction de la vue (bascule
        // d'ossature), il faut donc lui rendre son moteur au retour.
        .onAppear { viewModel.handleViewAppear() }
        .onDisappear { viewModel.handleViewDisappear() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                viewModel.handleAppBackgrounded()
            case .active:
                viewModel.handleAppForegrounded()
            @unknown default:
                break
            }
        }
    }

    // MARK: Layouts

    private var iPhoneLayout: some View {
        VStack(spacing: 6) {
            // Bandeau thermique dans le FLUX et non en superposition : il ne
            // recouvre ainsi jamais la 8e rangée, et n'occupe aucune place
            // tant que l'appareil est froid.
            ThermalBadge()
            // Lignes joueurs COLLÉES au plateau (haut = adversaire, bas =
            // vous) : identité + pièces prises + avantage + pendule sur une
            // seule ligne chacune, sans marge qui les détacherait du plateau.
            topClock
            // Plateau de BORD À BORD : il annule la marge horizontale du
            // conteneur pour lui seul. C'est le seul élément dont la taille
            // est utile — chaque point gagné en largeur est un point sur les
            // 64 cases — alors que les lignes joueurs et la barre de
            // transport restent des cartes, qui ont besoin de leur marge.
            board
                .padding(.horizontal, -12)
            bottomClock

            // Tout ce qui suit est à HAUTEUR FIXE et toujours présent : le
            // plateau ne rétrécit donc plus quand on joue (avant, la barre de
            // transport n'apparaissait qu'au 1er coup et poussait tout).
            if viewModel.settings.showEvalBar {
                EvalBarView(evalCp: viewModel.currentEvalCp, evalMate: viewModel.currentEvalMate)
            }
            if viewModel.outcome == nil {
                controlBar(showMoveList: true)
            } else {
                gameOverPanel
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .animation(Theme.spring, value: viewModel.outcome != nil)
        .sheet(isPresented: $showPanelSheet) {
            NavigationStack {
                ScrollView {
                    MoveListView(
                        moves: viewModel.sanMoveList,
                        currentPly: viewModel.displayedPly,
                        onSelectMove: {
                            viewModel.review(toPly: $0 + 1)
                            showPanelSheet = false
                        }
                    )
                }
                .background(Theme.background)
                .navigationTitle("Coups")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Theme.background, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") { showPanelSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.dark)
        }
    }

    /// iPad en hauteur (portrait) : **colonne unique, plateau pleine
    /// largeur**, tout le reste au-dessus et en dessous.
    ///
    /// Aucun calcul de côté ici, contrairement au paysage : le plateau garde
    /// son ratio et se contente de la place laissée par les éléments à
    /// hauteur fixe. Sur un iPad en portrait, cette place, c'est toute la
    /// largeur — et il reste de quoi dérouler la liste des coups en dessous,
    /// sans feuille ni panneau.
    private var iPadTallLayout: some View {
        VStack(spacing: 10) {
            ThermalBadge()
            topClock
            board
                // BORD À BORD : annule la marge horizontale du conteneur pour
                // le seul plateau (même principe qu'en iPhone), qui touche
                // alors les deux bords de l'écran — chaque point de largeur est
                // un point sur les 64 cases.
                .padding(.horizontal, -20)
                // Le plateau se sert en PREMIER, la liste prend ce qui reste.
                // Sans cette priorité, deux vues gourmandes en hauteur (le
                // plateau et le défilement des coups) se partagent l'espace à
                // parts égales : l'échiquier tombait à la moitié de la largeur
                // disponible, la liste s'octroyait le bas de l'écran, vide.
                .layoutPriority(1)
            bottomClock

            if viewModel.settings.showEvalBar {
                EvalBarView(evalCp: viewModel.currentEvalCp, evalMate: viewModel.currentEvalMate)
            }
            if viewModel.outcome == nil {
                controlBar(showMoveList: false)
            } else {
                gameOverPanel
            }

            // La liste prend ce qui reste, mais jamais moins que de quoi lire
            // quelques coups : un plateau VRAIMENT pleine largeur ne laissait
            // qu'un filet de 60 pt, où l'on ne voyait que le titre. Ce
            // minimum est ce qui rend le plateau « quasi » pleine largeur
            // (~84 %) plutôt que strictement pleine largeur — et c'est le bon
            // compromis : l'échiquier reste énorme, la liste reste lisible.
            ScrollView {
                movesSection
            }
            .frame(minHeight: 150, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .animation(Theme.spring, value: viewModel.outcome != nil)
    }

    /// iPad en largeur (paysage) : deux colonnes. Un plateau pleine largeur
    /// n'y tiendrait pas verticalement — on lui donne donc toute la HAUTEUR
    /// disponible, et la colonne de droite occupe ce qui reste.
    ///
    /// Le plateau reste **borné** plutôt que posé dans un `ScrollView` :
    /// autrement il dépasse l'écran et pousse pendules et contrôles sous le
    /// pli (finding #6, déjà corrigé une fois).
    private func iPadWideLayout(size: CGSize) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Colonne plateau, BORD À BORD : elle touche les bords haut, bas et
            // gauche de l'écran ; seules les fines lignes joueurs le bordent.
            // C'est le seul élément dont chaque point de taille compte (64
            // cases), d'où la marge réduite au strict minimum, contrairement à
            // la colonne de droite qui reste un panneau confortablement margé.
            VStack(spacing: 6) {
                ThermalBadge()
                topClock
                board
                    // Le plateau se sert en premier et prend toute la hauteur
                    // laissée par les pendules.
                    .layoutPriority(1)
                bottomClock
            }
            // Carré, donc borné à la hauteur : au-delà il déborderait
            // verticalement. Toute la largeur restante va au panneau de droite.
            .frame(maxWidth: size.height, maxHeight: .infinity)
            .padding(.vertical, 6)

            // Colonne droite : barre d'éval (sortie de la colonne plateau pour
            // lui rendre sa hauteur), actions, transport et liste des coups.
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.settings.showEvalBar {
                        EvalBarView(evalCp: viewModel.currentEvalCp, evalMate: viewModel.currentEvalMate)
                    }
                    if viewModel.outcome == nil {
                        controlBar(showMoveList: false)
                    } else {
                        gameOverPanel
                    }
                    movesSection
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Liste des coups affichée en continu : l'iPad a la place, la feuille de
    /// l'iPhone n'a donc pas lieu d'être.
    ///
    /// Sans défilement propre : chaque disposition l'enveloppe à sa façon (le
    /// portrait lui donne la hauteur restante, le paysage la met dans le
    /// défilement de sa colonne). Deux `ScrollView` imbriqués ne défileraient
    /// ni l'un ni l'autre correctement.
    private var movesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coups joués")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            MoveListView(
                moves: viewModel.sanMoveList,
                currentPly: viewModel.displayedPly,
                onSelectMove: { viewModel.review(toPly: $0 + 1) }
            )
        }
    }

    // MARK: Sous-vues

    /// Export de la partie en cours — et PASSERELLES vers les autres modes.
    ///
    /// Un MENU et non un bouton unique : « exporter sa position » recouvre
    /// deux besoins distincts et l'app ne peut pas deviner lequel — la FEN
    /// pour reprendre CETTE position ailleurs (analyse, forum, autre app), le
    /// PGN pour garder la partie entière. Les deux sont copiables d'un geste,
    /// et partageables si l'on veut sortir de l'app.
    ///
    /// La section « Continuer ailleurs » évite le détour copier → accueil →
    /// mode → coller : la position part DIRECTEMENT vers l'analyse ou le
    /// Laboratoire, et la partie reste en dessous dans la pile — le retour
    /// la retrouve telle quelle.
    ///
    /// Ce qui est exporté est la position AFFICHÉE : si le joueur revoit un
    /// coup antérieur, c'est celle-là qu'il a sous les yeux, et donc celle
    /// qu'il croit exporter.
    @ViewBuilder
    private var exportMenu: some View {
        Menu {
            Section("Continuer ailleurs") {
                Button {
                    onAnalyzePosition(viewModel.displayedFEN)
                } label: {
                    Label("Analyser cette position", systemImage: "chart.xyaxis.line")
                }
                Button {
                    onOpenLab(viewModel.displayedFEN)
                } label: {
                    Label("Continuer au Laboratoire", systemImage: "flask")
                }
                Button(action: onOpenTwoPlayer) {
                    Label("Deux joueurs", systemImage: "person.2.fill")
                }
            }
            Button {
                UIPasteboard.general.string = viewModel.displayedFEN
                copiedMessage = LocalizationController.string("Position (FEN) copiée dans le presse-papiers.")
            } label: {
                Label("Copier la position (FEN)", systemImage: "square.grid.3x3")
            }
            Button {
                UIPasteboard.general.string = viewModel.exportedPGN
                copiedMessage = LocalizationController.string("Partie (PGN) copiée dans le presse-papiers.")
            } label: {
                Label("Copier la partie (PGN)", systemImage: "doc.on.doc")
            }
            .disabled(!viewModel.hasGameToExport)
            Divider()
            ShareLink(item: viewModel.displayedFEN) {
                Label("Partager la position", systemImage: "square.and.arrow.up")
            }
            if viewModel.hasGameToExport {
                ShareLink(item: viewModel.exportedPGN) {
                    Label("Partager la partie", systemImage: "square.and.arrow.up.on.square")
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityLabel("Exporter")
        .accessibilityIdentifier("exportGame")
    }

    private var board: some View {
        ChessBoardView(
            board: viewModel.displayedBoard,
            orientation: viewModel.userColor,
            theme: boardTheme,
            selectedSquare: viewModel.selectedSquare,
            legalTargetSquares: viewModel.legalTargetSquares,
            lastMove: viewModel.displayedLastMove,
            hintMoves: viewModel.isReviewing ? [] : viewModel.hintMoves,
            interactionEnabled: viewModel.outcome == nil && !viewModel.isReviewing,
            showCoordinates: true,
            draggableColor: viewModel.userColor,
            onTapSquare: { viewModel.selectSquare($0) },
            onDropPiece: { viewModel.attemptUserMove(from: $0, to: $1) }
        )
    }

    private var topClock: some View {
        let opponent = viewModel.userColor.opposite
        let captured = viewModel.capturedMaterial
        return PlayerRowView(
            name: "Ordinateur",
            color: opponent,
            isActive: viewModel.outcome == nil && viewModel.board.position.sideToMove == opponent,
            captured: captured.captures(by: opponent),
            advantage: captured.advantage(for: opponent),
            remaining: viewModel.clock?.displayRemaining(for: opponent),
            isThinking: viewModel.isEngineThinking
        )
    }

    private var bottomClock: some View {
        let me = viewModel.userColor
        let captured = viewModel.capturedMaterial
        return PlayerRowView(
            name: LocalizationController.string("Vous"),
            color: me,
            isActive: viewModel.outcome == nil && viewModel.board.position.sideToMove == me,
            captured: captured.captures(by: me),
            advantage: captured.advantage(for: me),
            remaining: viewModel.clock?.displayRemaining(for: me)
        )
    }

    /// Rangée de contrôle UNIQUE, sur une seule ligne : à gauche la navigation
    /// (précédent / suivant) et, en consultation, « Reprendre ici » ; à droite
    /// les actions (indice, nulle, abandon).
    ///
    /// L'ancienne barre de transport — sauts début/fin **et** curseur — a été
    /// retirée : deux chevrons suffisent à parcourir la partie coup par coup, et
    /// « Coups joués » (iPhone) reste le moyen de sauter directement à un coup.
    private func controlBar(showMoveList: Bool) -> some View {
        let hasMoves = viewModel.totalPlies > 0
        return HStack(spacing: 10) {
            controlButton(
                "chevron.left",
                label: "Coup précédent",
                disabled: !hasMoves || viewModel.displayedPly == 0
            ) {
                viewModel.reviewPrevious()
            }
            // Raccourcis clavier iPad : ←/→ parcourent la partie, comme avant.
            .keyboardShortcut(.leftArrow, modifiers: [])
            controlButton(
                "chevron.right",
                label: "Coup suivant",
                disabled: !hasMoves || viewModel.displayedPly >= viewModel.totalPlies
            ) {
                viewModel.reviewNext()
            }
            .keyboardShortcut(.rightArrow, modifiers: [])

            // « Reprendre ici » n'apparaît qu'en consultation d'un coup passé —
            // c'est aussi le signe visible qu'on n'est plus sur la position vive.
            if viewModel.isReviewing, viewModel.canResumeFromReview {
                Button { showResumeConfirmation = true } label: {
                    Text("Reprendre ici")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.pressable)
                .transition(.opacity)
            }

            Spacer()

            controlButton(
                "lightbulb.fill",
                label: viewModel.hintsWanted ? "Arrêter l'indice" : "Indice",
                tint: viewModel.hintsWanted ? Theme.accent : Theme.textPrimary,
                highlighted: viewModel.hintsWanted,
                disabled: !viewModel.settings.hintsEnabled || viewModel.outcome != nil
            ) {
                viewModel.toggleHint()
            }
            // « Coups joués » et « Reprendre ici » ne coexistent jamais : en
            // consultation, la reprise prend la place de la liste, si bien que
            // la rangée tient sur UNE ligne même sur les iPhone étroits.
            if showMoveList, !viewModel.isReviewing {
                controlButton("list.bullet", label: "Coups joués", disabled: false) { showPanelSheet = true }
            }
            controlButton(text: "½", label: "Proposer nulle", tint: Theme.info, disabled: viewModel.outcome != nil || viewModel.isEngineThinking) {
                showDrawConfirmation = true
            }
            controlButton("flag.fill", label: "Abandonner", tint: Theme.danger, disabled: viewModel.outcome != nil) {
                showResignConfirmation = true
            }
        }
        .animation(Theme.gentle, value: viewModel.isReviewing)
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
            .frame(width: 46, height: 46)
            .background(highlighted ? Theme.accent.opacity(0.16) : Theme.surface, in: Circle())
            .overlay(Circle().strokeBorder(highlighted ? Theme.accent.opacity(0.5) : Theme.stroke, lineWidth: 1))
            .glow(Theme.accent, radius: 7, isActive: highlighted)
        }
        .buttonStyle(.pressable)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    /// Sans ce signalement, un échec de démarrage de Stockfish donnait un
    /// écran d'apparence normale où le moteur ne jouait jamais : partie
    /// figée sans le moindre message — voir
    /// ``PlayViewModel/isEngineUnavailable``.
    @ViewBuilder
    private var engineUnavailableBanner: some View {
        if viewModel.isEngineUnavailable {
            EngineUnavailableBanner(
                message: "L'ordinateur n'a pas démarré : il ne jouera pas.",
                isRetrying: viewModel.isRetryingEngine
            ) {
                viewModel.retryEngine()
            }
            .padding(.horizontal, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var promotionOverlay: some View {
        if let pending = viewModel.pendingPromotion {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                // Taper en dehors du sélecteur annule la promotion (le coup
                // n'est pas joué, la pièce revient) — standard des apps d'échecs.
                .onTapGesture { viewModel.cancelPromotion() }
                .overlay {
                    PromotionPickerView(color: pending.move.piece.color) { kind in
                        viewModel.completePromotion(to: kind)
                    }
                }
        }
    }

    /// À la fin de partie, seuls les confettis passent en superposition (si
    /// victoire) : le bilan et les actions s'affichent SOUS le plateau
    /// (``gameOverPanel``), qui reste visible et rejouable via la barre de
    /// transport — même principe que Puzzles/Répertoires.
    @ViewBuilder
    private var gameOverOverlay: some View {
        if let outcome = viewModel.outcome, outcome.winner == viewModel.userColor {
            CelebrationView()
        }
    }

    /// Bilan compact affiché sous le plateau en fin de partie : résultat +
    /// raison, sortie de répertoire éventuelle, et les actions (Accueil,
    /// Analyser, Revanche).
    @ViewBuilder
    private var gameOverPanel: some View {
        if let outcome = viewModel.outcome {
            let didWin = outcome.winner == viewModel.userColor
            let isDraw = outcome.winner == nil
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: didWin ? "trophy.fill" : (isDraw ? "hand.raised.fill" : "flag.checkered"))
                        .font(.title2)
                        .foregroundStyle(didWin ? Theme.warning : Theme.textSecondary)
                        .glow(Theme.warning, radius: 8, isActive: didWin)
                    Text(outcome.summary(userColor: viewModel.userColor))
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    panelButton("Accueil", icon: "house.fill") { onExit() }
                    // `PGNExport` et non `game.pgn` brut : ChessKit n'émet pas
                    // les tags [SetUp]/[FEN] pour une position de départ
                    // personnalisée, et l'analyse rechargerait alors les coups
                    // DEPUIS la position standard — analyse vide au lieu de la
                    // partie (tout le flux « Jouer à partir d'ici » était
                    // concerné).
                    panelButton("Analyser", icon: "chart.xyaxis.line") { onAnalyze(PGNExport.pgn(for: viewModel.game)) }
                    panelButton("Revanche", icon: "arrow.triangle.2.circlepath", filled: true) { onRematch(rematchSettings()) }
                }
            }
            .cardStyle()
            .overlay(Theme.cardShape.strokeBorder(Theme.strokeStrong, lineWidth: 1))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func panelButton(_ title: LocalizedStringKey, icon: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(filled ? Theme.background : Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if filled {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accentGradient)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(filled ? Color.clear : Theme.stroke, lineWidth: 1))
            .glow(Theme.accent, radius: 8, isActive: filled)
        }
        .buttonStyle(.pressable)
    }

    /// Revanche : mêmes réglages, mais l'utilisateur joue l'autre camp que
    /// celui qu'il vient de jouer.
    private func rematchSettings() -> PlayGameSettings {
        var settings = viewModel.settings
        settings.colorChoice = (viewModel.userColor.opposite == .white ? PlayerColorChoice.white : .black).rawValue
        return settings
    }

    /// Marqueur invisible exposant le nombre de coups joués pour les
    /// tests UI, indépendamment du layout iPhone/iPad. Extrait en
    /// propriété calculée séparée : inline dans `body`, cette expression
    /// faisait dépasser le budget du vérificateur de types au compilateur
    /// ("unable to type-check ... in reasonable time").
    private var moveCountMarker: some View {
        let count = viewModel.sanMoveList.count
        return Color.clear
            .accessibilityIdentifier("moveCount")
            .accessibilityValue("\(count)")
    }
}

// MARK: - Sous-vues auxiliaires

/// Ligne d'un joueur : pastille de couleur + nom + pièces capturées, et à
/// droite la pendule (si cadence). Surlignée quand c'est son trait. Toujours
/// affichée (même sans pendule) — donne aussi l'identité des joueurs et le
/// différentiel de matériel.
private struct PlayerRowView: View {
    let name: String
    let color: Piece.Color
    let isActive: Bool
    let captured: [Piece.Kind]
    let advantage: Int
    let remaining: TimeInterval?
    /// Vrai pour la ligne du moteur pendant qu'il calcule : affiche un petit
    /// indicateur à la place du badge « réfléchit » séparé (qui prenait de la
    /// hauteur au-dessus du plateau et le faisait rétrécir).
    var isThinking: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color == .white ? Color.white : Color.black)
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                .frame(width: 9, height: 9)
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isActive ? Theme.textPrimary : Theme.textSecondary)
            if isThinking {
                ProgressView()
                    .tint(Theme.warning)
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
                    .transition(.opacity)
            }
            CapturedTrayView(kinds: captured, glyphColor: color.opposite, advantage: advantage)
            Spacer(minLength: 0)
            if let remaining {
                Text(formatted(remaining))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(isActive ? Theme.textPrimary : Theme.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Theme.surfaceElevated : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isActive ? Theme.accent.opacity(0.40) : Color.clear, lineWidth: 1)
        )
        .glow(Theme.accent, radius: 6, isActive: isActive)
        .animation(Theme.spring, value: isActive)
        .animation(Theme.gentle, value: isThinking)
    }

    private func formatted(_ remaining: TimeInterval) -> String {
        let clamped = max(0, remaining)
        // Dixièmes sous 10 s (zeitnot / bullet), MM:SS au-delà.
        if clamped < 10 {
            return String(format: "%.1f", clamped)
        }
        let totalSeconds = Int(clamped.rounded())
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct MoveListView: View {
    let moves: [String]
    /// Demi-coup actuellement consulté (pour surligner le coup courant) ;
    /// chaque coup est tapable pour y naviguer en lecture seule.
    var currentPly: Int = -1
    var onSelectMove: (Int) -> Void = { _ in }

    private var pairs: [(number: Int, white: String?, whiteIndex: Int, black: String?, blackIndex: Int)] {
        stride(from: 0, to: moves.count, by: 2).map { i in
            (number: i / 2 + 1, white: moves[i], whiteIndex: i, black: i + 1 < moves.count ? moves[i + 1] : nil, blackIndex: i + 1)
        }
    }

    var body: some View {
        if moves.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title2)
                    .foregroundStyle(Theme.textTertiary)
                Text("Aucun coup joué")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(pairs, id: \.number) { pair in
                    HStack(spacing: 8) {
                        Text("\(pair.number)")
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 26, alignment: .trailing)
                        moveCell(pair.white, index: pair.whiteIndex)
                        moveCell(pair.black, index: pair.blackIndex)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(pair.number.isMultiple(of: 2) ? Theme.surface.opacity(0.35) : Color.clear)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
            .padding(.horizontal, 2)
        }
    }

    /// Chaque coup est tapable pour naviguer (consultation) ; le coup
    /// correspondant au demi-coup consulté est surligné d'une pastille accent.
    @ViewBuilder
    private func moveCell(_ san: String?, index: Int) -> some View {
        if let san {
            let isCurrent = index + 1 == currentPly
            Button {
                onSelectMove(index)
            } label: {
                // Traduction ICI, au dernier moment : `moves` reste la liste
                // de SAN anglais, celle qui sert au PGN et aux comparaisons.
                Text(SANFormatter.display(san))
                    .font(.callout.weight(isCurrent ? .bold : .medium))
                    .foregroundStyle(isCurrent ? Theme.background : Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        isCurrent ? Theme.accentGradient : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(maxWidth: .infinity)
        }
    }
}

/// Alertes et dialogues de la partie, extraits du corps de ``PlayView``
/// pour éviter que la chaîne de modificateurs ne dépasse le budget du
/// vérificateur de types (piège récurrent sur ce fichier — voir PROGRESS).
private struct GameDialogs: ViewModifier {
    @Bindable var viewModel: PlayViewModel
    @Binding var showResignConfirmation: Bool
    @Binding var showResumeConfirmation: Bool
    @Binding var showDrawConfirmation: Bool

    private var blunderBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingBlunderWarning != nil },
            set: { if !$0 { viewModel.dismissBlunderWarning() } }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(
                "Coup risqué",
                isPresented: blunderBinding,
                presenting: viewModel.pendingBlunderWarning
            ) { _ in
                Button("Ignorer", role: .cancel) { viewModel.dismissBlunderWarning() }
                Button("Reprendre le coup", role: .destructive) { viewModel.takebackAfterBlunderWarning() }
            } message: { pending in
                Text(pending.message)
            }
            .alert("Le moteur propose nulle", isPresented: $viewModel.pendingDrawOffer) {
                Button("Refuser", role: .cancel) { viewModel.declineDrawOffer() }
                Button("Accepter") { viewModel.acceptDrawOffer() }
            }
            .alert("Nulle refusée", isPresented: $viewModel.drawOfferDeclinedByEngine) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Le moteur préfère continuer la partie.")
            }
            .confirmationDialog(
                "Abandonner la partie ?",
                isPresented: $showResignConfirmation,
                titleVisibility: .visible
            ) {
                Button("Abandonner", role: .destructive) { viewModel.userResigns() }
                Button("Annuler", role: .cancel) {}
            }
            .confirmationDialog(
                "Proposer nulle au moteur ?",
                isPresented: $showDrawConfirmation,
                titleVisibility: .visible
            ) {
                Button("Proposer nulle") { viewModel.offerDrawToEngine() }
                Button("Annuler", role: .cancel) {}
            }
            .confirmationDialog(
                "Reprendre depuis le coup \(viewModel.displayedPly) ?",
                isPresented: $showResumeConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reprendre ici", role: .destructive) { viewModel.resumeFromReview() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les \(viewModel.totalPlies - viewModel.displayedPly) coup(s) suivants seront effacés.")
            }
    }
}
