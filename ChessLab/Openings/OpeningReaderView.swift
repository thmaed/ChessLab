import ChessKit
import SwiftUI

/// **Écran B — le lecteur Labs.**
///
/// L'échiquier en haut, TOUJOURS visible, avec les coups du répertoire en
/// flèches colorées et une fine barre d'évaluation collée dessous. Le reste
/// défile : le fil des coups, le commentaire de l'auteur, les coups du
/// répertoire, ce que jouent les maîtres, et les trois meilleurs coups du
/// moteur — tous calculés d'avance, aucun Stockfish ne tourne ici.
///
/// ## La disposition
///
/// Un seul critère, la FORME de la fenêtre, et non la famille d'appareil :
/// - plus large que haute (iPad ou Mac en paysage, iPhone couché) → plateau à
///   gauche, panneau à droite ;
/// - plus haute que large (iPhone debout, iPad en portrait) → plateau en haut,
///   panneau défilant en dessous.
///
/// Le plateau est ANCRÉ hors du défilement : on lit les statistiques EN
/// REGARDANT la position, et un plateau qui sort de l'écran au premier
/// glissement rendrait le panneau inutile.
///
/// ## Pourquoi aucun moteur ne tourne
///
/// Les trois meilleurs coups et l'évaluation viennent du sidecar
/// (``OpeningStatsSidecar``), calculés à profondeur 20 au moment de la
/// génération. Un Stockfish embarqué donnerait les mêmes chiffres après
/// plusieurs secondes d'attente, en chauffant l'appareil, et redémarrerait à
/// chaque coup. Ici, l'information est là avant que le doigt ne quitte l'écran.
struct OpeningReaderView: View {
    @Bindable var viewModel: OpeningReaderViewModel
    /// Entraînement de la LIGNE affichée, en répétition espacée.
    var onTrain: () -> Void = {}
    var onContinueVsStockfish: (String) -> Void = { _ in }
    var onOpenLab: (String) -> Void = { _ in }
    var onOpenTwoPlayer: (String) -> Void = { _ in }

    @State private var appSettings = AppSettings.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var boardTheme: BoardTheme { appSettings.boardTheme }
    private var languageCode: String { appSettings.appLanguage.resolvedCode }

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
        // TROIS boutons de barre laissent peu de place au titre : `.inline`
        // le tronque proprement plutôt que de bousculer les boutons, et le nom
        // complet reste en tête de l'index, à un tap.
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // L'index se ROUVRE ici — le prompt : « on doit pouvoir le
                // réouvrir plus tard p.ex. en mettant l'icône en haut à droite ».
                Button {
                    viewModel.isIndexPresented = true
                } label: {
                    Label("Index des lignes", systemImage: "list.bullet.indent")
                }
                .tint(Theme.info)
                .accessibilityIdentifier("opening_openIndex")

                Button { onTrain() } label: {
                    Label("S'entraîner", systemImage: "graduationcap.fill")
                }
                .tint(Theme.accent)
                .accessibilityIdentifier("opening_train")

                // Débranchement : Laboratoire / Ordinateur / Deux joueurs.
                QuickSwitchMenu(
                    onPlayVsEngine: { onContinueVsStockfish(viewModel.currentFEN) },
                    onOpenTwoPlayer: { onOpenTwoPlayer(viewModel.currentFEN) },
                    onOpenLab: { onOpenLab(viewModel.currentFEN) }
                )
            }
        }
        .sheet(isPresented: $viewModel.isIndexPresented) {
            OpeningIndexView(viewModel: viewModel) { path in
                viewModel.jump(path: path)
                viewModel.isIndexPresented = false
            } onClose: {
                viewModel.isIndexPresented = false
            }
        }
    }

    // MARK: Dispositions

    /// Portrait : plateau ancré en haut, barre d'éval, panneau défilant,
    /// transport en bas. Le plateau est plafonné pour qu'il reste toujours de
    /// la place au panneau — c'est lui qui porte le contenu de ce module.
    private func tallLayout(size: CGSize) -> some View {
        // Aux tailles d'accessibilité, le texte du panneau occupe trois fois
        // plus de place : on rend de la hauteur au panneau, sans quoi il ne
        // reste qu'un liseré entre le plateau et la barre de transport.
        let share = dynamicTypeSize.isAccessibilitySize ? 0.34 : 0.46
        let side = size.width >= 700
            ? min(size.width - 32, size.height * (dynamicTypeSize.isAccessibilitySize ? 0.42 : 0.55), 780)
            : min(size.width - 32, size.height * share, 520)
        return VStack(spacing: 0) {
            boardStack(side: side)
            panel
            controlBar
        }
    }

    /// Paysage : plateau à gauche, tout le reste à droite.
    private func wideLayout(size: CGSize) -> some View {
        let side = size.width >= 1000
            ? min(size.height - 40, size.width * 0.52, 800)
            : min(size.height - 40, size.width * 0.48, 560)
        // Les deux colonnes partent du HAUT. Le plateau était centré
        // verticalement pendant que le panneau, lui, restait accroché en
        // haut : dès que la fenêtre dépassait le plafond de taille du plateau
        // (800 pt), un vide s'ouvrait au-dessus du plateau et un autre sous
        // le panneau, et l'écran paraissait cassé alors que chaque colonne,
        // isolément, était juste. Sans effet tant que le plateau remplit la
        // hauteur, c'est-à-dire dans toutes les fenêtres jusqu'au plafond.
        return HStack(alignment: .top, spacing: 0) {
            boardStack(side: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            VStack(spacing: 0) {
                panel
                controlBar
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func boardStack(side: CGFloat) -> some View {
        VStack(spacing: 8) {
            board
                .frame(width: side, height: side)
            evalStrip
                .frame(width: side)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var board: some View {
        ChessBoardView(
            board: viewModel.board,
            orientation: viewModel.orientation,
            theme: boardTheme,
            selectedSquare: nil,
            legalTargetSquares: [],
            lastMove: viewModel.lastMove,
            hintMoves: OpeningMovePalette.arrows(for: coloredMoves),
            interactionEnabled: false,
            showCoordinates: true,
            draggableColor: .white,
            onTapSquare: { _ in },
            onDropPiece: { _, _ in },
            // Taper une flèche joue son coup : le geste le plus direct
            // possible pour explorer une variante qu'on voit sur le plateau.
            onTapArrow: { hint in
                if let edge = viewModel.edge(from: hint.from.notation, to: hint.to.notation) {
                    viewModel.play(edge)
                }
            }
        )
    }

    // MARK: Barre d'évaluation (fine, sous le plateau)

    /// « Une barre d'évaluation relativement fine pour montrer les
    /// centipions » : 7 pt, le chiffre à côté plutôt que dedans (il n'y
    /// tiendrait pas), et la profondeur du calcul en regard — une évaluation
    /// sans sa profondeur ne veut pas dire grand-chose.
    private var evalStrip: some View {
        HStack(spacing: 8) {
            Text(verbatim: evalText)
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(evalTint)
                // Pas de cadre de largeur FIXE : à grande taille le chiffre
                // n'y tenait plus et disparaissait purement et simplement.
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            EvalBarView(
                evalCp: viewModel.evalCp, evalMate: viewModel.evalMate,
                height: 7, showsLabel: false
            )
            if let depth = viewModel.engineDepth, viewModel.hasPrecomputedEval {
                Text(verbatim: LocalizationController.string("p%lld", depth))
                    .scaledSystemFont(size: 9, relativeTo: .caption2, maximumScale: 1.4)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        // Repère de MISE EN PAGE pour les tests d'interface : la barre est
        // collée sous le plateau, donc sa position dit de quel côté se trouve
        // le plateau par rapport au panneau (dessous en portrait, à gauche en
        // paysage). Voir `OpeningsModuleUITests`.
        .accessibilityIdentifier("opening_evalBar")
    }

    private var evalText: String {
        if let mate = viewModel.evalMate { return "M\(abs(mate))" }
        guard let cp = viewModel.evalCp else { return "—" }
        return String(format: "%+.2f", Double(cp) / 100)
    }

    private var evalTint: Color {
        if let mate = viewModel.evalMate { return mate > 0 ? Theme.accent : Theme.danger }
        guard let cp = viewModel.evalCp else { return Theme.textTertiary }
        if cp > 50 { return Theme.accent }
        if cp < -50 { return Theme.danger }
        return Theme.textSecondary
    }

    // MARK: Panneau défilant

    private var panel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                moveTrail
                if let name = viewModel.positionName { positionNameRow(name) }
                commentCard
                repertoireSection
                statsColumns
                Spacer(minLength: 8)
            }
            .padding(.vertical, 12)
        }
    }

    private func positionNameRow(_ name: String) -> some View {
        Text(name)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.info)
            .padding(.horizontal, 16)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Fil des coups

    /// « La liste des coups joués sous forme de ligne » — en figurine, et
    /// chaque coup ramène à sa position.
    private var moveTrail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    Button { viewModel.reset() } label: {
                        Image(systemName: "house.fill")
                            .font(.caption2)
                            .foregroundStyle(viewModel.isRoot ? Theme.background : Theme.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(viewModel.isRoot ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surface),
                                        in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Position de départ")

                    ForEach(Array(viewModel.playedSANs.enumerated()), id: \.offset) { index, san in
                        let isCurrent = index == viewModel.playedSANs.count - 1
                        Button { viewModel.jump(toPly: index + 1) } label: {
                            HStack(spacing: 2) {
                                if index % 2 == 0 {
                                    Text(verbatim: "\(index / 2 + 1).")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(isCurrent ? Theme.background.opacity(0.7) : Theme.textTertiary)
                                }
                                FigurineSANText(
                                    san: san, color: index % 2 == 0 ? .white : .black,
                                    font: .caption.weight(.semibold).monospaced(), glyphSize: 13
                                )
                                .foregroundStyle(isCurrent ? Theme.background : Theme.textSecondary)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(isCurrent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surface),
                                        in: Capsule())
                        }
                        .buttonStyle(.pressable)
                        .id(index)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: viewModel.playedSANs.count) { _, count in
                withAnimation(Theme.gentle) { proxy.scrollTo(count - 1, anchor: .trailing) }
            }
        }
    }

    // MARK: Commentaire

    /// « Les commentaires sur les coups clés » : l'explication du coup qui a
    /// mené ici, et le plan typique de la structure. Jamais un brouillon —
    /// ``MoveEdge/displayableComment(_:)`` ne rend que le validé.
    @ViewBuilder
    private var commentCard: some View {
        let comment = viewModel.currentComment
        let plan = viewModel.plan
        if comment?.isEmpty == false || plan?.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                if let comment, !comment.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "text.bubble.fill").foregroundStyle(Theme.accent)
                        Text(comment).font(.subheadline).foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
                if let plan, !plan.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "map.fill").foregroundStyle(Theme.violet)
                        Text(plan).font(.subheadline).foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal, 16)
            .transition(.opacity)
        } else if viewModel.isEnd {
            infoCard("flag.checkered", "Fin de la ligne. Reviens en arrière ou ouvre l'index pour explorer une autre variante.")
        }
    }

    private func infoCard(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.textTertiary)
            Text(text).font(.subheadline).foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .cardStyle()
        .padding(.horizontal, 16)
    }

    // MARK: Coups du répertoire (ceux des flèches)

    private var coloredMoves: [OpeningMovePalette.Colored] {
        OpeningMovePalette.colorize(viewModel.candidates)
    }

    @ViewBuilder
    private var repertoireSection: some View {
        let moves = coloredMoves
        if !moves.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Répertoire", icon: "arrow.triangle.branch", tint: Theme.accent)
                ForEach(moves) { repertoireRow($0) }
            }
            .padding(.horizontal, 16)
        }
    }

    private func repertoireRow(_ item: OpeningMovePalette.Colored) -> some View {
        // Le NOM de la variante qu'ouvre ce coup, quand la donnée en connaît
        // un : « Gambit portugais », « Attaque Fried Liver »… Savoir ce qu'on
        // s'apprête à explorer AVANT de taper dessus, c'est ce qui distingue
        // une liste de coups d'un sommaire.
        let name = viewModel.branchName(for: item.edge)

        // Aux tailles d'ACCESSIBILITÉ, la notation, l'étiquette et le nom ne
        // tiennent plus côte à côte : le nom passe alors dessous, sur toute la
        // largeur, plutôt que d'être amputé à trois lettres.
        let stacked = dynamicTypeSize.isAccessibilitySize

        return Button { viewModel.play(item.edge) } label: {
            VStack(alignment: .leading, spacing: stacked ? 6 : 0) {
            // Tout sur une ligne tant que ça tient ; le NOM, lui, passe à la
            // ligne plutôt que de se tronquer — « Contre-attaque Traxler »
            // amputée en « Contre-attaque T… » ne nomme plus rien. La notation
            // et la flèche, elles, ne bougent jamais : ce sont les deux repères
            // qu'on balaie du regard en descendant la liste.
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(item.color)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                FigurineSANText(san: item.edge.san, color: sideToMoveColor)
                    .foregroundStyle(Theme.textPrimary)
                    .layoutPriority(2)
                if item.isRecommended {
                    tag("Principale", Theme.accent)
                        .layoutPriority(1)
                }
                if let label = OpeningMovePalette.roleLabel(item.edge.role),
                   let tint = OpeningMovePalette.roleTint(item.edge.role) {
                    tag(label, tint).layoutPriority(1)
                }
                // NOMMÉ, pas symbolisé. C'était un « ! » orange nu, sans
                // libellé ni légende sur cet écran : le premier lecteur a dû
                // demander ce qu'il voulait dire. Un marqueur qu'il faut aller
                // chercher ailleurs n'informe personne.
                if item.edge.isCritical {
                    tag("À mémoriser", Theme.warning).layoutPriority(1)
                }
                if let name, !stacked {
                    Text(name)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(item.color)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Spacer(minLength: 4)
                }
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption).foregroundStyle(Theme.textTertiary)
                    .padding(.top, 1)
                    .layoutPriority(2)
            }
            if let name, stacked {
                Text(name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(item.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            }
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(item.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(item.color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("opening_repertoire_\(item.edge.uci)")
        .accessibilityLabel(Text(repertoireAccessibility(item, name: name)))
    }

    private func repertoireAccessibility(_ item: OpeningMovePalette.Colored, name: String?) -> String {
        let move = FigurineSAN.spoken(item.edge.san)
        guard let name else { return move }
        return LocalizationController.string("%@, %@", move, name)
    }

    /// Camp au trait dans la position affichée — la couleur des figurines de
    /// toutes les listes de coups jouables.
    private var sideToMoveColor: Piece.Color {
        viewModel.currentNode?.sideToMove.color ?? .white
    }

    // MARK: Maîtres et Stockfish, côte à côte

    /// Les deux sources de vérité de la position, EN REGARD : ce que les
    /// humains forts ont joué, et ce que le moteur préfère.
    ///
    /// Côte à côte et non l'une sous l'autre, parce que la question qu'on se
    /// pose est une COMPARAISON — « le coup le plus joué est-il le meilleur ? »
    /// — et qu'elle ne se lit pas en faisant défiler. Chaque colonne est
    /// délibérément maigre : le coup, sa mesure, et rien de plus.
    ///
    /// Deux colonnes tiennent jusque sur un écran de 320 pt (panneau de 288 pt,
    /// deux colonnes de ~138 pt) : une ligne de maîtres demande ~95 pt, une
    /// ligne de moteur ~105 pt.
    @ViewBuilder
    private var statsColumns: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // Deux colonnes de ~140 pt ne tiennent plus une notation à la
            // taille d'accessibilité : on empile plutôt que de tronquer.
            VStack(alignment: .leading, spacing: 14) {
                mastersColumn
                engineColumn
            }
            .padding(.horizontal, 16)
        } else {
            HStack(alignment: .top, spacing: 10) {
                mastersColumn.frame(maxWidth: .infinity, alignment: .leading)
                engineColumn.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
        }
    }

    /// « Les coups les plus joués par les Maîtres dans la position donnée en
    /// indiquant les pourcentages de chaque variante. »
    @ViewBuilder
    private var mastersColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let stats = viewModel.masterStats, stats.totalGames > 0 {
                sectionHeader(
                    "Maîtres", icon: "person.3.fill", tint: Theme.gold,
                    trailing: formatted(stats.totalGames)
                )
                ForEach(stats.moves) { masterRow($0, stats: stats) }
            } else {
                sectionHeader("Maîtres", icon: "person.3.fill", tint: Theme.gold)
                Text("Aucune partie de maître connue pour cette position.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func masterRow(_ move: OpeningMasterMove, stats: OpeningMasterStats) -> some View {
        let share = stats.share(of: move)
        let edge = viewModel.edge(forUCI: move.uci)

        return Button {
            if let edge { viewModel.play(edge) }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    FigurineSANText(
                        san: move.san, color: sideToMoveColor,
                        font: .caption.weight(.semibold).monospaced(), glyphSize: 13
                    )
                    .foregroundStyle(edge == nil ? Theme.textSecondary : Theme.textPrimary)
                    Spacer(minLength: 2)
                    Text(verbatim: percent(share))
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.gold)
                    Text(verbatim: formatted(move.games))
                        .scaledSystemFont(size: 9, relativeTo: .caption2, maximumScale: 1.6)
                        .monospacedDigit()
                        // 58 % : petit texte, 38 % le laissait sous AA.
                        .foregroundStyle(Theme.textSecondary)
                }
                // Bilan blanc / nulle / noir seulement : la barre de part
                // faisait doublon avec le pourcentage écrit juste à côté, et
                // deux barres empilées de longueurs voisines se confondaient.
                resultBar(move)
            }
            .padding(.vertical, 7).padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Teinte de la SECTION, comme le violet côté Stockfish : d'un coup
            // d'œil, on sait de quelle colonne vient une ligne, même en la
            // regardant seule.
            .background(Theme.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.32), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .disabled(edge == nil)
        .accessibilityIdentifier("opening_master_\(move.uci)")
        .accessibilityLabel(Text(masterAccessibility(move, share: share)))
    }

    private func masterAccessibility(_ move: OpeningMasterMove, share: Double) -> String {
        LocalizationController.string(
            "%@, %@ des parties de maîtres", FigurineSAN.spoken(move.san), percent(share)
        )
    }

    /// Bilan du coup : blanc / nulle / noir, dans les couleurs des camps.
    /// FINE (2 pt) : c'est une indication de tendance, pas une mesure qu'on lit
    /// au dixième — et elle partage sa colonne avec le reste.
    private func resultBar(_ move: OpeningMasterMove) -> some View {
        let total = max(1, move.games)
        return GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(Color.white.opacity(0.88))
                    .frame(width: geo.size.width * Double(move.whiteWins) / Double(total))
                Rectangle().fill(Color.gray.opacity(0.55))
                    .frame(width: geo.size.width * Double(move.draws) / Double(total))
                Rectangle().fill(Color(white: 0.13))
            }
        }
        .frame(height: 2)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    /// « Les meilleurs (maximum 3) coups de stockfish qui doivent être calculés
    /// en avance au maximum » — ils le sont entièrement : le sidecar les porte,
    /// le moteur ne démarre jamais sur cet écran.
    @ViewBuilder
    private var engineColumn: some View {
        let lines = viewModel.engineLines
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                "Stockfish", icon: "cpu", tint: Theme.violet,
                trailing: viewModel.engineDepth.map { LocalizationController.string("p%lld", $0) }
            )
            if lines.isEmpty {
                Text("Analyse indisponible pour cette position.")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            } else {
                ForEach(Array(lines.enumerated()), id: \.element.id) { rank, line in
                    engineRow(line, rank: rank)
                }
            }
        }
    }

    private func engineRow(_ line: OpeningEngineLine, rank: Int) -> some View {
        let edge = viewModel.edge(forUCI: line.uci)
        return Button {
            if let edge { viewModel.play(edge) }
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: "\(rank + 1)")
                    .scaledSystemFont(size: 9, relativeTo: .caption2, weight: .bold, maximumScale: 1.4)
                    .monospacedDigit()
                    .foregroundStyle(rank == 0 ? Theme.background : Theme.violet)
                    .frame(width: 15, height: 15)
                    .background(
                        rank == 0 ? AnyShapeStyle(Theme.violet) : AnyShapeStyle(Theme.violet.opacity(0.18)),
                        in: Circle()
                    )
                FigurineSANText(
                    san: line.san, color: sideToMoveColor,
                    font: .caption.weight(.semibold).monospaced(), glyphSize: 13
                )
                .foregroundStyle(edge == nil ? Theme.textSecondary : Theme.textPrimary)
                Spacer(minLength: 2)
                Text(verbatim: engineScore(line))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(engineTint(line))
                repertoireMark(isInRepertoire: edge != nil)
            }
            .padding(.vertical, 8).padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.violet.opacity(rank == 0 ? 0.14 : 0.07),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.violet.opacity(rank == 0 ? 0.45 : 0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .disabled(edge == nil)
        .accessibilityIdentifier("opening_engine_\(line.uci)")
    }

    /// Ce coup mène-t-il quelque part ?
    ///
    /// La flèche dit « on peut y aller » ; le cercle pointillé dit « le
    /// répertoire s'arrête ici ». C'était écrit « hors répertoire » en toutes
    /// lettres, ce qui prenait plus de place que le coup lui-même une fois les
    /// colonnes réduites de moitié. Le sens reste dit — à VoiceOver, et dans
    /// la légende de l'index.
    private func repertoireMark(isInRepertoire: Bool) -> some View {
        Image(systemName: isInRepertoire ? "arrow.turn.down.right" : "circle.dotted")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(isInRepertoire ? Theme.textSecondary : Theme.textTertiary)
            .accessibilityLabel(Text(isInRepertoire ? "dans le répertoire" : "hors répertoire"))
    }

    /// Score TOUJOURS du point de vue des blancs, comme la barre — deux
    /// conventions à l'écran, c'est une inversion de signe garantie.
    private func engineScore(_ line: OpeningEngineLine) -> String {
        if let mate = line.mate { return mate > 0 ? "M\(mate)" : "-M\(abs(mate))" }
        guard let cp = line.cp else { return "—" }
        return String(format: "%+.2f", Double(cp) / 100)
    }

    private func engineTint(_ line: OpeningEngineLine) -> Color {
        if let mate = line.mate { return mate > 0 ? Theme.accent : Theme.danger }
        guard let cp = line.cp else { return Theme.textTertiary }
        if cp > 50 { return Theme.accent }
        if cp < -50 { return Theme.danger }
        return Theme.textSecondary
    }

    // MARK: Éléments partagés

    private func sectionHeader(
        _ title: LocalizedStringKey, icon: String, tint: Color, trailing: String? = nil
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption2).foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase).tracking(0.4)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(.caption2.monospacedDigit()).foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 4)
    }

    private func tag(_ text: LocalizedStringKey, _ color: Color) -> some View {
        Text(text).font(.caption2.weight(.bold)).foregroundStyle(color)
            // Une étiquette ne se coupe JAMAIS en deux : « Principale » se
            // repliait en « Princi-/pale » à la taille d'accessibilité.
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    /// Pourcentage affiché. L'espace avant le « % » suit la typographie de la
    /// langue (« 60 % » en français, « 60% » en anglais) : le catalogue porte
    /// déjà ce séparateur sous la clé « %tab » — ici « " %" ».
    private func percent(_ share: Double) -> String {
        let separator = LocalizationController.string(" %")
        // Sous 1 %, « 0 % » serait faux et « 0,4 % » plus juste que rien.
        let value = share < 0.01
            ? String(format: "%.1f", share * 100)
            : "\(Int((share * 100).rounded()))"
        return value + separator
    }

    private func formatted(_ count: Int) -> String {
        count >= 1_000_000 ? String(format: "%.1f M", Double(count) / 1_000_000)
            : count >= 1_000 ? String(format: "%.0f k", Double(count) / 1_000)
            : "\(count)"
    }

    // MARK: Transport

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button { viewModel.back() } label: {
                Label("Précédent", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    // Une seule ligne, quitte à rétrécir : à la taille
                    // d'accessibilité, « Précédent » se repliait en
                    // « Pré-/cé-/dent » et la barre mangeait la moitié de
                    // l'écran.
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Theme.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(.pressable)
            .disabled(!viewModel.canGoBack)
            .opacity(viewModel.canGoBack ? 1 : 0.4)
            .accessibilityIdentifier("reader_prev")

            Button { viewModel.next() } label: {
                Label("Suivant", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.bold)).foregroundStyle(Theme.background)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Theme.accentGradient, in: Capsule())
                    .glow(Theme.accent, radius: 8)
            }
            .buttonStyle(.pressable)
            .disabled(viewModel.isEnd)
            .opacity(viewModel.isEnd ? 0.4 : 1)
            .accessibilityIdentifier("reader_next")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.background)
    }
}

/// Héberge le lecteur Labs : charge le cours ET son sidecar une seule fois.
struct OpeningReaderHost: View {
    let courseID: String
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    let onExit: () -> Void
    var onTrain: () -> Void = {}
    var onContinueVsStockfish: (String) -> Void = { _ in }
    var onOpenLab: (String) -> Void = { _ in }
    var onOpenTwoPlayer: (String) -> Void = { _ in }

    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: OpeningReaderViewModel?

    var body: some View {
        Group {
            if let viewModel {
                OpeningReaderView(
                    viewModel: viewModel, onTrain: onTrain,
                    onContinueVsStockfish: onContinueVsStockfish,
                    onOpenLab: onOpenLab, onOpenTwoPlayer: onOpenTwoPlayer
                )
            } else {
                ContentUnavailableView("Ouverture indisponible", systemImage: "questionmark.folder")
                    .appBackground()
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            viewModel = sessionStore.value(for: sessionKey) {
                OpeningCatalog.course(id: courseID).map {
                    OpeningReaderViewModel(course: $0, sidecar: OpeningStatsLoader.sidecar(id: courseID))
                }
            }
        }
    }
}
