import ChessKit
import Charts
import SwiftUI

/// Écran principal du mode Analyser : plateau + analyse en continu,
/// liste de coups avec variantes navigables et icônes de classification,
/// courbe d'évaluation, en-tête d'ouverture (ECO), export PGN et
/// "Jouer à partir d'ici".
struct AnalysisView: View {
    @Bindable var viewModel: AnalysisViewModel
    let onPlayFromHere: (String) -> Void
    /// Ouvre le Laboratoire pré-rempli avec la position affichée — le
    /// pendant de « Jouer à partir d'ici », pour regarder deux moteurs
    /// trancher la position au lieu de la jouer soi-même.
    var onOpenLab: (String) -> Void = { _ in }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }
    /// Liaison manuelle : `AppSettings` est un singleton `@Observable`, pas
    /// une propriété `@Bindable` de la vue.
    private var boardThemeSelection: Binding<String> {
        Binding(get: { appSettings.boardThemeID }, set: { appSettings.boardThemeID = $0 })
    }
    @State private var boardOrientation: Piece.Color = .white
    @State private var showExportSheet = false
    @State private var showSummarySheet = false
    @State private var isGeneratingPuzzles = false
    @State private var puzzleGenerationMessage: String?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .appBackground()
        .navigationTitle("Analyser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            // Les deux passerelles vers d'autres modes ont quitté ce menu pour
            // ``QuickSwitchMenu`` (harmonisation du 24/08) : elles y voisinaient
            // avec le thème du plateau et le retournement, sous une icône « … »
            // qui ne laissait rien deviner. « Jouer à partir d'ici » portait de
            // surcroît une icône `play.fill` là où l'accueil et les six autres
            // écrans nomment ce mode « Contre l'ordinateur » sous `cpu`.
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                QuickSwitchMenu(
                    onPlayVsEngine: { onPlayFromHere(viewModel.currentFEN) },
                    onOpenLab: { onOpenLab(viewModel.currentFEN) }
                )
                Menu {
                    Button("Bilan de la partie", systemImage: "chart.bar.xaxis") {
                        showSummarySheet = true
                    }
                    Button("Exporter le PGN", systemImage: "square.and.arrow.up") {
                        showExportSheet = true
                    }
                    Button("Créer des puzzles depuis les erreurs", systemImage: "puzzlepiece.extension") {
                        generatePuzzles()
                    }
                    .disabled(viewModel.isClassifying || isGeneratingPuzzles)
                    // `Picker` et non des `Button` : le réglage COURANT porte
                    // sa coche — avant, ces deux sous-menus ne disaient pas
                    // lequel était actif.
                    Menu("Flèches du moteur") {
                        Picker("Flèches du moteur", selection: $viewModel.arrowMode) {
                            ForEach(ArrowMode.allCases) { mode in
                                Label(LocalizedStringKey(mode.label), systemImage: mode.systemImage)
                                    .tag(mode)
                            }
                        }
                    }
                    Button("Retourner le plateau", systemImage: "arrow.up.arrow.down") {
                        boardOrientation = boardOrientation.opposite
                    }
                    .keyboardShortcut("f", modifiers: .command)
                    Menu("Thème du plateau") {
                        Picker("Thème du plateau", selection: boardThemeSelection) {
                            ForEach(BoardTheme.all) { theme in
                                Text(LocalizedStringKey(theme.label)).tag(theme.id)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Plus d'options")
            }
        }
        .overlay(alignment: .top) { engineUnavailableBanner }
        .overlay { promotionOverlay }
        .background(
            // Marqueur invisible pour les tests UI : nombre de coups joués
            // sur la ligne actuellement affichée (indépendant du layout).
            Color.clear
                .accessibilityIdentifier("analysisMoveCount")
                .accessibilityValue("\(viewModel.moveListRows.count)")
        )
        .onAppear { viewModel.handleViewAppear() }
        .onDisappear {
            viewModel.handleViewDisappear()
            // Le bilan chiffré rejoint la partie enregistrée quand il est
            // COMPLET (le view model s'en assure). À la sortie d'écran plutôt
            // qu'à la fin de la classification : c'est le seul moment où l'on
            // sait que plus rien ne va changer, et le contexte SwiftData vit
            // ici, pas dans le view model.
            viewModel.persistMetrics(in: modelContext)
        }
        .onChange(of: viewModel.isClassifying) { _, isClassifying in
            // Fin de classification écran ouvert : on écrit sans attendre la
            // sortie, pour que la bibliothèque montre la précision tout de suite.
            if !isClassifying { viewModel.persistMetrics(in: modelContext) }
        }
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: [viewModel.exportedPGN])
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSummarySheet) {
            GameSummaryView(
                summary: viewModel.gameSummary,
                whiteName: viewModel.whitePlayerName,
                blackName: viewModel.blackPlayerName,
                opening: viewModel.openingName
            )
        }
        .alert(
            "Puzzles",
            isPresented: Binding(
                get: { puzzleGenerationMessage != nil },
                set: { if !$0 { puzzleGenerationMessage = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(puzzleGenerationMessage ?? "")
        }
    }

    /// Cherche, parmi les coups déjà classés imprécision/erreur/gaffe,
    /// ceux dont la solution est assez nette pour faire un bon puzzle —
    /// voir `AnalysisViewModel.generatePuzzles(in:)` pour le filtre.
    private func generatePuzzles() {
        isGeneratingPuzzles = true
        Task {
            let count = await viewModel.generatePuzzles(in: modelContext)
            isGeneratingPuzzles = false
            puzzleGenerationMessage = count > 0
                ? "\(count) puzzle(s) créé(s) — retrouvez-les dans le mode Puzzles."
                : "Aucune gaffe assez nette pour un puzzle sans ambiguïté dans cette partie."
        }
    }

    // MARK: Layouts

    /// Même gabarit que l'iPad (tout défile ensemble, panneau
    /// courbe/coups intégré en dessous du plateau) — l'iPhone utilisait
    /// jusqu'ici une feuille séparée pour ce panneau, jugée peu pratique
    /// à l'usage (il fallait l'ouvrir pour voir ne serait-ce que la
    /// courbe d'éval).
    private var iPhoneLayout: some View {
        ScrollView {
            VStack(spacing: 0) {
                openingHeader
                    .padding(.horizontal, 16)

                board

                VStack(spacing: 14) {
                    EvalBarView(evalCp: viewModel.currentEvalCp, evalMate: viewModel.currentEvalMate)
                    navigationBar
                    candidatesBar
                    coachBar
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                analysisPanel
                    .padding(16)
            }
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
    }

    /// iPad : deux colonnes en PAYSAGE (large), une seule colonne verticale en
    /// PORTRAIT (haut). Le portrait côte-à-côte laissait la moitié basse vide et
    /// écrasait le panneau de droite (texte « précision » empilé, coups tronqués).
    private var iPadLayout: some View {
        GeometryReader { geo in
            if geo.size.height > geo.size.width {
                iPadPortraitBody(geo)
            } else {
                iPadLandscapeBody(geo)
            }
        }
    }

    /// Paysage : plateau borné + éval/navigation à gauche, panneau d'analyse
    /// (en-tête, courbe, coups) défilant à droite.
    private func iPadLandscapeBody(_ geo: GeometryProxy) -> some View {
        return HStack(alignment: .top, spacing: 24) {
            // AUCUNE constante de chrome soustraite à la main. La version
            // d'origine bornait le plateau à `geo.size.height - 48`, alors que
            // la colonne empile sous lui le badge d'analyse (26), la barre
            // d'éval (20), la navigation (44), les candidats (~34), la barre
            // coach (~40), leurs espacements et 24 pt de marge haut et bas —
            // de l'ordre de **270 pt, pas 48**. La colonne n'étant pas dans un
            // `ScrollView`, le débordement était franc et irrécupérable : la
            // barre coach passait sous le bord de l'écran (iPad mini paysage,
            // iPad Pro 13" sidebar repliée, Stage Manager en fenêtre basse,
            // Catalyst à sa taille minimale de 820 pt).
            //
            // Même remède que ``PlayView`` (voir PROGRESS.md, « Revue UX —
            // disposition iPad ») : le plateau se sert en PREMIER via
            // `layoutPriority`, les barres à hauteur fixe prennent ce qui
            // reste, et plus aucun chiffre deviné ne peut mentir quand une
            // police ou une marge bouge.
            VStack(spacing: 12) {
                board
                    .layoutPriority(1)
                EvalBarView(evalCp: viewModel.currentEvalCp, evalMate: viewModel.currentEvalMate)
                navigationBar
                candidatesBar
                coachBar
            }
            // Carré : la colonne ne peut pas être plus large que haute, sinon
            // le plateau déborderait verticalement. La largeur reste par
            // ailleurs bornée à ~55 % de la fenêtre pour laisser au panneau
            // d'analyse de quoi être lisible.
            .frame(maxWidth: min(geo.size.width * 0.55, geo.size.height), maxHeight: .infinity)

            ScrollView {
                VStack(spacing: 16) {
                    openingHeader
                    analysisPanel
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Portrait : une colonne verticale centrée. Plateau (plus grand qu'avant)
    /// + éval/navigation FIXES en haut, puis le panneau d'analyse qui REMPLIT
    /// toute la hauteur restante (il défile si besoin) — ainsi plus de moitié
    /// basse vide, et le panneau occupe toute la largeur de la colonne (fini la
    /// carte « précision » écrasée en vertical et les coups tronqués).
    private func iPadPortraitBody(_ geo: GeometryProxy) -> some View {
        let boardSide = min(geo.size.width - 40, geo.size.height * 0.5)
        return VStack(spacing: 14) {
            openingHeader
            board
                .frame(width: boardSide)
            EvalBarView(evalCp: viewModel.currentEvalCp, evalMate: viewModel.currentEvalMate)
            navigationBar
            candidatesBar
            coachBar
            // Le panneau récupère TOUTE la hauteur restante (défile au besoin) :
            // c'est ce qui supprime le vide en bas.
            ScrollView {
                analysisPanel
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // maxWidth (et non width fixe) borne la colonne à la largeur du plateau
        // TOUT EN laissant maxHeight étirer la pile — sans quoi le ScrollView ne
        // remplirait pas la hauteur.
        .frame(maxWidth: boardSide, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: Sous-vues

    private var board: some View {
        VStack(spacing: 8) {
            analyzingBadge
            ThermalBadge()
            ChessBoardView(
                board: viewModel.board,
                orientation: boardOrientation,
                theme: boardTheme,
                selectedSquare: viewModel.selectedSquare,
                legalTargetSquares: viewModel.legalTargetSquares,
                lastMove: viewModel.lastMove,
                // La menace s'ajoute aux flèches de coups : même couche, même
                // géométrie, seule la couleur (rouge) la distingue.
                hintMoves: viewModel.displayedArrows,
                qualityBadge: viewModel.qualityBadge,
                interactionEnabled: true,
                showCoordinates: true,
                draggableColor: viewModel.board.position.sideToMove,
                onTapSquare: { viewModel.selectSquare($0) },
                onDropPiece: { viewModel.attemptMove(from: $0, to: $1) },
                onTapArrow: { hint in
                    // Taper une flèche candidate joue ce coup (LAN exact retrouvé
                    // sur le candidat correspondant, promotion comprise).
                    if let candidate = viewModel.candidateMoves.first(
                        where: { $0.from == hint.from && $0.to == hint.to }
                    ) {
                        viewModel.playCandidate(candidate)
                    }
                }
            )
        }
    }

    /// Dans le flux (au-dessus du plateau, qu'elle pousse légèrement vers
    /// le bas) plutôt qu'en superposition, qui recouvrait les cases du
    /// haut. Hauteur fixe + opacité (plutôt qu'un `if`) pour ne pas
    /// décaler la mise en page quand la profondeur apparaît/disparaît.
    private var analyzingBadge: some View {
        // L'ancien bandeau disait « Analyse en continu — profondeur 18 » en
        // ORANGE, la couleur des avertissements de l'app : il se lisait comme
        // un problème, alors qu'il décrit le fonctionnement NORMAL. Et
        // « profondeur » ne veut rien dire pour qui ne connaît pas les
        // moteurs. Devient une ligne d'état neutre, qui nomme ce qui
        // travaille et jusqu'où il a calculé.
        HStack(spacing: 7) {
            Circle()
                .fill(viewModel.isLiveAnalyzing ? Theme.accent : Theme.textTertiary)
                .frame(width: 6, height: 6)
                .opacity(viewModel.isLiveAnalyzing ? 1 : 0.5)

            Text(engineStatusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        .frame(height: 26)
        .animation(Theme.gentle, value: viewModel.isLiveAnalyzing)
        .accessibilityLabel(Text(engineStatusText))
    }

    /// « Stockfish calcule — 18 coups d'avance » plutôt que « profondeur 18 » :
    /// la profondeur EST un nombre de demi-coups explorés, autant le dire.
    private var engineStatusText: String {
        if viewModel.isEngineUnavailable { return LocalizationController.string("Moteur indisponible") }
        guard viewModel.isLiveAnalyzing, let depth = viewModel.liveDepth else {
            return LocalizationController.string("Moteur en attente")
        }
        return LocalizationController.string("L'ordinateur calcule — %lld coups d'avance", depth)
    }

    @ViewBuilder
    private var openingHeader: some View {
        if let opening = viewModel.openingName {
            HStack(spacing: 8) {
                Text(opening.eco)
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.accentGradient, in: Capsule())
                Text(opening.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 6)
        }
    }

    /// Raccourcis clavier iPad (Lot 4.A) : ←/→ pour naviguer, espace pour
    /// lancer/arrêter la lecture automatique (Lot 5.A), ⌘F pour retourner le
    /// plateau (le prompt).
    ///
    /// Posés sur les VRAIS boutons plutôt que sur des boutons cachés : un
    /// bouton masqué ne reçoit pas toujours son raccourci selon l'état du
    /// focus, et la barre porte déjà exactement ces actions.
    private var navigationBar: some View {
        HStack(spacing: 12) {
            navButton("backward.end.fill", disabled: !viewModel.canGoPrevious) { viewModel.goToStart() }
            navButton("chevron.left", disabled: !viewModel.canGoPrevious) { viewModel.goToPrevious() }
                .keyboardShortcut(.leftArrow, modifiers: [])
            navButton("chevron.right", disabled: !viewModel.canGoNext) { viewModel.goToNext() }
                .keyboardShortcut(.rightArrow, modifiers: [])

            // Lecture automatique, un coup par seconde (Lot 5.A).
            navButton(
                viewModel.isAutoplaying ? "pause.fill" : "play.fill",
                disabled: !viewModel.canGoNext && !viewModel.isAutoplaying
            ) {
                viewModel.toggleAutoplay()
            }
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(viewModel.isAutoplaying ? "Arrêter la lecture" : "Lire la partie")
            .accessibilityIdentifier("autoplay")

            // Jouer le meilleur coup du moteur : déroule la meilleure ligne
            // coup par coup depuis une position (scan, FEN, éditeur). Teinté
            // accent car c'est l'action « intelligente » de l'écran.
            bestMoveButton

            Spacer()
            if viewModel.isClassifying, let progress = viewModel.classificationProgress {
                classificationIndicator(progress)
            }
        }
    }

    /// Coups candidats de la position (analyse en continu) : les 3 meilleurs,
    /// notation + éval, chacun cliquable pour jouer/explorer cette variante —
    /// pas seulement le meilleur. Complète la flèche/le bouton « meilleur
    /// coup » ; les flèches du plateau sont elles aussi cliquables.
    @ViewBuilder
    private var candidatesBar: some View {
        if !viewModel.candidateMoves.isEmpty {
            HStack(spacing: 8) {
                ForEach(viewModel.candidateMoves) { candidate in
                    Button {
                        viewModel.playCandidate(candidate)
                    } label: {
                        HStack(spacing: 6) {
                            Text(SANFormatter.display(candidate.san))
                                .font(.subheadline.weight(candidate.rank == 1 ? .bold : .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Text(candidate.eval)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            candidate.rank == 1 ? AnyShapeStyle(Theme.accent.opacity(0.16)) : AnyShapeStyle(Theme.surface),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                candidate.rank == 1 ? Theme.accent.opacity(0.5) : Theme.stroke,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("candidate_\(candidate.rank)")
                    .accessibilityLabel(Text("Jouer \(SANFormatter.display(candidate.san)), évaluation \(candidate.eval)"))
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Bandeau « coach » : la catégorie du coup affiché, en toutes lettres,
    /// et — pour les fautes — le coup qu'il fallait jouer. La pastille sur
    /// le plateau dit la même chose en un symbole ; ici c'est la phrase
    /// complète, celle qui apprend quelque chose.
    @ViewBuilder
    private var coachBar: some View {
        if let quality = viewModel.lastMoveQuality, let move = viewModel.lastMove {
            // ``ViewThatFits`` et non un `if` : la colonne de gauche de l'iPad
            // en PAYSAGE n'est pas dans un `ScrollView` (voir
            // ``iPadLandscapeBody``), et c'est précisément là que la barre
            // coach était déjà passée sous le bord de l'écran une fois. Une
            // seconde ligne posée sans filet rouvrirait ce trou.
            //
            // Ici, la version à deux lignes n'est retenue que si elle TIENT
            // dans la hauteur proposée ; sinon on retombe sur la barre d'hier,
            // à l'octet près. Aucune constante de chrome devinée, et la phrase
            // ne peut pas repousser le plateau : elle prend la place restante
            // ou elle s'efface.
            ViewThatFits(in: .vertical) {
                coachCard(quality: quality, move: move, explanation: viewModel.lastMoveExplanation)
                coachCard(quality: quality, move: move, explanation: nil)
            }
            .transition(.opacity)
            .animation(Theme.gentle, value: quality)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("coachBar")
        }
    }

    /// La carte du bandeau coach. `explanation` à `nil` rend EXACTEMENT la
    /// barre d'une ligne d'avant ce chantier — c'est ce qui en fait un repli
    /// sûr pour ``ViewThatFits``.
    private func coachCard(
        quality: MoveQuality, move: Move, explanation: MoveExplanation?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                MoveQualityBadgeView(quality: quality, squareSize: 56)

                Group {
                    Text(SANFormatter.display(move.san)).bold()
                        + Text(verbatim: " — ")
                        + Text(quality.label).bold().foregroundStyle(quality.tint)
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

                // Le meilleur coup n'est plus rappelé ici en toutes lettres :
                // la flèche verte sur le plateau le montre déjà, c'était un
                // doublon. À la place, le GAIN ou la PERTE du coup joué (en
                // points de % de gain, POV du joueur), aligné à droite.
                Spacer(minLength: 8)

                if let delta = viewModel.lastMoveWinDelta {
                    // Lu par VoiceOver via le bandeau combiné (children:
                    // .combine) : « e5 — Erreur, −12 % ».
                    Text(winDeltaLabel(delta))
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(winDeltaColor(delta, quality: quality))
                        .lineLimit(1)
                }
            }

            if let explanation {
                // LE contenu du chantier : ce qui punit le coup, en toutes
                // lettres. Deux lignes au plus — au-delà ce n'est plus une
                // explication, c'est un paragraphe, et la place vient du
                // plateau.
                Text(explanation.sentence)
                    .font(.footnote)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("coachExplanation")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface, in: Theme.controlShape)
        .overlay(Theme.controlShape.strokeBorder(quality.tint.opacity(0.45), lineWidth: 1))
    }

    /// Sous ½ point de % le coup est neutre (« ≈ 0 % ») : afficher « −0 % »
    /// pour le meilleur coup n'aurait aucun sens. Au-delà, le signe explicite
    /// (+ gain, − perte, vrai signe moins U+2212) et l'entier suffisent — le
    /// bandeau coach n'est pas un tableau de bord au dixième près.
    private func winDeltaLabel(_ delta: Double) -> String {
        if abs(delta) < 0.5 { return "≈ 0 %" }
        let sign = delta > 0 ? "+" : "\u{2212}"
        return "\(sign)\(Int(abs(delta).rounded())) %"
    }

    private func winDeltaColor(_ delta: Double, quality: MoveQuality) -> Color {
        if abs(delta) < 0.5 { return Theme.textSecondary }
        // Gain → émeraude ; perte → la teinte de la pastille (elle encode déjà
        // la gravité : jaune imprécision, orange erreur, rouge gaffe).
        return delta > 0 ? Theme.accent : quality.tint
    }

    /// « Jouer le meilleur coup » : bouton accentué qui avance d'un demi-coup
    /// le long de la meilleure ligne du moteur. ⌘→ en raccourci iPad.
    private var bestMoveButton: some View {
        Button {
            viewModel.playBestMove()
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(viewModel.canPlayBestMove ? Theme.background : Theme.textTertiary)
                .frame(width: 44, height: 44)
                .background(
                    viewModel.canPlayBestMove
                        ? AnyShapeStyle(Theme.accentGradient)
                        : AnyShapeStyle(Theme.surface),
                    in: Circle()
                )
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .disabled(!viewModel.canPlayBestMove)
        .keyboardShortcut(.rightArrow, modifiers: .command)
        .accessibilityLabel("Jouer le meilleur coup")
        .accessibilityIdentifier("playBestMove")
    }

    /// Indicateur de classification, qui **renonce à du contenu** plutôt que
    /// de pousser les boutons de transport hors de l'écran (Lot 3.2).
    ///
    /// La barre porte cinq boutons de 44 pt et leurs espacements, soit 268 pt
    /// incompressibles ; il reste environ 75 pt utiles sur un iPhone SE, et
    /// à peine 20 en Display Zoom — alors que « Analyse : coup 12/40 » en
    /// réclame ~125. Le libellé était donc écrasé jusqu'à une lettre. Et ce
    /// n'est pas un cas rare : la classification démarre à l'ouverture de
    /// n'importe quel PGN et dure des dizaines de secondes.
    ///
    /// `ViewThatFits` choisit la première version qui tient : phrase complète,
    /// puis compteur seul, puis le seul rouet. Aucune de ces étapes ne ment
    /// sur l'état — l'analyse tourne, et ça se voit.
    private func classificationIndicator(
        _ progress: (done: Int, total: Int)
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                classificationSpinner
                Text("Analyse : coup \(progress.done)/\(progress.total)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .fixedSize()
            }
            HStack(spacing: 6) {
                classificationSpinner
                Text("\(progress.done)/\(progress.total)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .fixedSize()
            }
            classificationSpinner
        }
    }

    private var classificationSpinner: some View {
        ProgressView().tint(Theme.textSecondary).scaleEffect(0.6)
    }

    private func navButton(_ systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(disabled ? Theme.textTertiary : Theme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .disabled(disabled)
    }

    private var analysisPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !viewModel.evalCurvePoints.isEmpty {
                EvalCurveView(
                    points: viewModel.evalCurvePoints,
                    currentPly: viewModel.currentPly
                ) { index in
                    viewModel.goTo(index: index)
                }
            }

            if !viewModel.accuracyByColor.isEmpty {
                summaryCard
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Coups joués")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                MoveStripView(
                    rows: viewModel.moveListRows,
                    currentIndex: viewModel.currentIndex,
                    evaluations: viewModel.moveEvaluations
                ) { index in
                    viewModel.goTo(index: index)
                }
            }
        }
    }

    /// Les deux précisions + la porte d'entrée du bilan complet : toute la
    /// carte est un bouton, pas seulement un chevron de 20 points.
    private var summaryCard: some View {
        Button {
            showSummarySheet = true
        } label: {
            HStack(spacing: 10) {
                ForEach([Piece.Color.white, .black], id: \.self) { color in
                    if let accuracy = viewModel.accuracyByColor[color] {
                        HStack(spacing: 9) {
                            Circle()
                                .fill(color == .white ? Color.white : Color.black)
                                .overlay(Circle().strokeBorder(Theme.strokeStrong, lineWidth: 1))
                                .frame(width: 11, height: 11)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(Int(accuracy.rounded()))%")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(Theme.textPrimary)
                                Text("précision")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                Text("Bilan")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.surface, in: Theme.controlShape)
            .overlay(Theme.controlShape.strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("gameSummaryButton")
    }

    /// Sans ce signalement, un échec de démarrage de Stockfish laissait
    /// l'écran muet — ni éval, ni flèches, ni classification, sans
    /// explication (voir ``AnalysisViewModel/isEngineUnavailable``).
    @ViewBuilder
    private var engineUnavailableBanner: some View {
        if viewModel.isEngineUnavailable {
            EngineUnavailableBanner(
                message: "L'ordinateur n'a pas démarré : ni évaluation ni classification. La partie reste navigable.",
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
                // Taper en dehors du sélecteur annule la promotion, comme en
                // mode Jouer : sans cela, un pion glissé par erreur sur la
                // dernière rangée imposait une branche non voulue.
                .onTapGesture { viewModel.cancelPromotion() }
                .overlay {
                    PromotionPickerView(color: pending.move.piece.color) { kind in
                        viewModel.completePromotion(to: kind)
                    }
                }
        }
    }
}

/// Ruban de coups HORIZONTAL, qui défile et suit la position affichée.
///
/// La liste verticale obligeait à quitter le plateau des yeux et à chercher
/// où l'on en était dans une colonne qui s'allongeait à chaque coup. Un
/// ruban tient sur deux lignes quelle que soit la longueur de la partie,
/// se lit dans le sens de la partie, et se recentre tout seul sur le coup
/// courant — le geste naturel devient « faire défiler la partie », pas
/// « chercher son coup ».
///
/// Les variantes gardent leur indentation logique sous forme de préfixe
/// discret : un ruban ne peut pas indenter, mais il peut nommer.
private struct MoveStripView: View {
    let rows: [MoveListRow]
    let currentIndex: MoveTree.Index
    /// Classifications de NOTRE analyse — prioritaires sur les NAG du PGN
    /// importé, qui servent de repli tant qu'un nœud n'est pas classifié.
    let evaluations: [MoveTree.Index: AnalysisMoveEvaluation]
    let onSelect: (MoveTree.Index) -> Void

    var body: some View {
        if rows.isEmpty {
            Text("Aucun coup joué")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(rows) { row in
                            chip(for: row)
                                .id(row.id)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
                .onChange(of: currentIndex) { _, index in
                    // Recentrer plutôt que coller au bord : on veut voir ce
                    // qui précède ET ce qui suit le coup courant.
                    withAnimation(Theme.gentle) { proxy.scrollTo(index, anchor: .center) }
                }
                .onAppear { proxy.scrollTo(currentIndex, anchor: .center) }
            }
        }
    }

    private func chip(for row: MoveListRow) -> some View {
        let isCurrent = row.id == currentIndex
        // Symbole seulement pour les catégories remarquables : un ruban où
        // chaque chip porte une icône ne met plus rien en relief.
        let quality = (evaluations[row.id]?.quality ?? MoveQuality(row.assessment))
            .flatMap { $0.showsInMoveList ? $0 : nil }

        return Button {
            onSelect(row.id)
        } label: {
            HStack(spacing: 4) {
                if let numberLabel = row.numberLabel {
                    Text(numberLabel)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(isCurrent ? Theme.background.opacity(0.7) : Theme.textTertiary)
                }
                Text(SANFormatter.display(row.san))
                    .font(.callout.weight(isCurrent ? .bold : .medium))
                    .foregroundStyle(isCurrent ? Theme.background : Theme.textPrimary)
                if let quality {
                    qualityGlyph(quality, isCurrent: isCurrent)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                isCurrent ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surface),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    quality.map { $0.tint.opacity(isCurrent ? 0 : 0.7) } ?? Theme.stroke,
                    lineWidth: quality == nil ? 1 : 1.5
                )
            )
            // Une variante n'est pas la partie : elle se distingue sans
            // occuper d'espace supplémentaire.
            .opacity(row.depth > 0 ? 0.75 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(SANFormatter.display(row.san) + row.assessmentSuffix)
    }

    /// Le symbole d'une catégorie, en version chip : texte NAG tel quel,
    /// glyphe SF Symbol réduit sinon.
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


/// Courbe d'évaluation (Swift Charts), bornée ±10 pions, cliquable pour
/// naviguer au coup correspondant.
private struct EvalCurveView: View {
    let points: [AnalysisViewModel.EvalCurvePoint]
    let currentPly: Int?
    let onSelect: (MoveTree.Index) -> Void

    /// 64 pt au lieu de 100 : la courbe sert à REPÉRER les décrochages et à
    /// y sauter, pas à lire une valeur — trois fois moins haute, elle laisse
    /// la place aux coups tout en restant parfaitement lisible.
    private let height: CGFloat = 64

    var body: some View {
        Chart {
            ForEach(points) { point in
                // Aire signée depuis la ligne d'équilibre : le regard voit
                // TOUT DE SUITE qui est devant, sans lire d'axe. Une courbe
                // toujours verte, quel que soit le camp qui mène, ne disait
                // rien de tel.
                AreaMark(
                    x: .value("Coup", point.ply),
                    yStart: .value("Éval", 0),
                    yEnd: .value("Éval", point.pawns)
                )
                .foregroundStyle(point.pawns >= 0 ? Theme.accent.opacity(0.28) : Theme.info.opacity(0.28))
                .interpolationMethod(.monotone)

                LineMark(x: .value("Coup", point.ply), y: .value("Éval", point.pawns))
                    .foregroundStyle(Theme.textPrimary.opacity(0.75))
                    .lineStyle(StrokeStyle(lineWidth: 1.6))
                    .interpolationMethod(.monotone)
            }

            // Les MOMENTS CRITIQUES, épinglés sur la courbe : brillant,
            // grand coup, occasion manquée, erreur, gaffe. Petites pastilles
            // volontairement — elles disent OÙ regarder, la liste de coups
            // dit quoi. Le halo sombre les détache de l'aire colorée.
            ForEach(points.filter { $0.quality?.marksCriticalPhase == true }) { point in
                PointMark(x: .value("Coup", point.ply), y: .value("Éval", point.pawns))
                    .foregroundStyle(Theme.background)
                    .symbolSize(64)
                PointMark(x: .value("Coup", point.ply), y: .value("Éval", point.pawns))
                    .foregroundStyle(point.quality?.tint ?? Theme.textSecondary)
                    .symbolSize(30)
            }

            // Ligne d'équilibre, discrète mais présente : sans elle, une
            // aire signée n'a pas de repère.
            RuleMark(y: .value("Équilibre", 0))
                .foregroundStyle(Theme.stroke)
                .lineStyle(StrokeStyle(lineWidth: 1))

            // Où l'on se trouve dans la partie.
            if let currentPly {
                RuleMark(x: .value("Position", currentPly))
                    .foregroundStyle(Theme.accent.opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .chartYScale(domain: -10...10)
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .frame(height: height)
        .padding(.vertical, 2)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let origin = geometry[plotFrame].origin
                                let x = value.location.x - origin.x
                                guard let tappedPly: Int = proxy.value(atX: x) else { return }
                                if let closest = points.min(by: { abs($0.ply - tappedPly) < abs($1.ply - tappedPly) }) {
                                    onSelect(closest.id)
                                }
                            }
                    )
            }
        }
        .accessibilityLabel("Courbe d'évaluation")
    }
}

/// Feuille de partage système, utilisée ici pour exporter le PGN.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
