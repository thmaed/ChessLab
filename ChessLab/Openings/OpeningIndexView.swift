import ChessKit
import SwiftUI

/// **Écran A — l'index des lignes, en arbre.**
///
/// Le tronc commun écrit UNE FOIS, puis les débranchements successifs :
///
///     1.e4 d5 2.exd5 ♛xd5
///       ↳ 3.♘c3
///           ○ 3…♛a5 4.d4 ♞f6 …
///           ○ 3…♛e5+
///               □ 4.♕e2 …
///       ↳ 3.♘f3 ♗g4 …
///
/// On y arrive en ouvrant l'ouverture, et on y revient quand on veut par
/// l'icône de la barre d'outils.
///
/// ## Chaque coup est un bouton
///
/// C'est la fonction centrale de l'écran : taper le 7ᵉ coup de la ligne
/// « Fried Liver » amène directement à cette position, avec le fil des coups
/// déjà rempli — pas « au début de la ligne, puis sept fois Suivant ».
///
/// ## Ce que porte chaque étage
///
/// Un marqueur PROPRE à l'étage (forme + couleur, voir ``BranchMarker``) et un
/// retrait proportionnel. À quatre niveaux d'imbrication, le retrait seul ne
/// dit plus de quelle ligne on descend ; la forme, elle, se reconnaît d'un coup
/// d'œil et se retrouve d'une rangée à l'autre.
///
/// Les coups du chemin COURANT sont surlignés dans tout l'arbre : rouvrir
/// l'index en cours de lecture montre où l'on est et par où l'on est passé.
struct OpeningIndexView: View {
    @Bindable var viewModel: OpeningReaderViewModel
    /// Saut demandé : le chemin à rejouer, puis fermeture de l'index.
    let onSelect: ([String]) -> Void
    let onClose: () -> Void

    @State private var appSettings = AppSettings.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Rangée mise en évidence après un renvoi de transposition — le temps de
    /// la retrouver du regard, puis elle s'éteint. Une surbrillance qui reste
    /// se confondrait avec celle de la position courante.
    @State private var highlightedRowID: String?
    /// Le renvoi en cours, pour que la surbrillance précédente s'éteigne quand
    /// on en déclenche un autre.
    @State private var highlightTask: Task<Void, Never>?

    private var languageCode: String { appSettings.appLanguage.resolvedCode }
    private static let highlightDuration: Duration = .seconds(2.5)

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        header
                        treeCard(proxy)
                        legend
                    }
                    .padding(16)
                }
                .onAppear {
                    // Rouvrir l'index en cours de lecture doit montrer OÙ l'on
                    // est, pas le haut de l'arbre.
                    guard let id = viewModel.currentRowID else { return }
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .appBackground()
            .navigationTitle("Index des lignes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer", systemImage: "xmark", action: onClose)
                        .accessibilityIdentifier("openingIndex_close")
                }
            }
        }
    }

    // MARK: En-tête

    /// En-tête : le nom de l'ouverture, son résumé, et trois repères chiffrés.
    ///
    /// Le RÉSUMÉ disparaît aux tailles d'accessibilité. Mesuré : en AX5 il
    /// occupe à lui seul deux écrans, et l'arbre — le contenu même de cet
    /// écran — passe hors d'atteinte sans un long défilement. Le résumé reste
    /// lisible sur l'écran précédent, où il a sa place ; ici, il n'est qu'un
    /// rappel. « Adapter la mise en page aux grandes tailles », et « conserver
    /// la hiérarchie de l'information quelle que soit la taille du texte ».
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(viewModel.course.name))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            if let summary = viewModel.course.summary?.resolved(languageCode),
               !dynamicTypeSize.isAccessibilitySize {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // FlowLayout et non HStack : à grande taille, les trois repères
            // ne tiennent plus sur une ligne et se tronquaient.
            FlowLayout(spacing: 8, lineSpacing: 6) {
                // Chaînes CALCULÉES : elles passent par le catalogue à la main
                // (`Text(String)` ne localise pas, contrairement à
                // `Text(LocalizedStringKey)`) — sinon l'écran reste français
                // en anglais.
                pill(LocalizationController.string("%lld variantes", branchCount), "arrow.triangle.branch")
                pill(LocalizationController.string("%lld positions", viewModel.course.positions.count),
                     "square.grid.3x3")
                pill(LocalizationController.string(viewModel.course.side == .white ? "Côté blanc" : "Côté noir"),
                     viewModel.course.side == .white ? "circle" : "circle.fill")
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Les rangées de DÉBRANCHEMENT (le tronc n'en est pas une).
    private var branchCount: Int { max(0, viewModel.rows.count - 1) }

    private func pill(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.surfaceElevated, in: Capsule())
    }

    // MARK: L'arbre

    private func treeCard(_ proxy: ScrollViewProxy) -> some View {
        // Espacement NUL entre les rangées, l'air étant pris à l'intérieur de
        // chacune : sinon les rails verticaux se coupent d'une rangée à
        // l'autre et l'arbre se lit comme une série de tirets.
        VStack(alignment: .leading, spacing: 0) {
            // Identité par RANG : les rangées sont une liste ordonnée qui ne se
            // réordonne jamais, et le rang est la seule clé dont l'unicité est
            // garantie sans reconstruire une chaîne par rangée à chaque rendu.
            ForEach(Array(viewModel.rows.enumerated()), id: \.offset) { _, row in
                treeRow(row, proxy: proxy).id(row.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }

    private func treeRow(_ row: OpeningLineTree.Node, proxy: ScrollViewProxy) -> some View {
        // Le nom de la branche est DANS la colonne des connecteurs, pas
        // au-dessus : posé en dehors, il ouvrait dans les rails un trou de sa
        // propre hauteur. Le coude vise donc sa ligne quand il y en a un, et
        // la première rangée de pastilles sinon.
        let label = row.chapterTitle?.resolved(languageCode)
            ?? (row.depth > 0 ? row.ecoName : nil)

        return HStack(alignment: .top, spacing: 0) {
            // Un vrai ARBRE, dessiné comme on dessine les arbres : un rail par
            // étage encore ouvert au-dessus, et un connecteur « └ » ou « ├ »
            // à l'étage de la rangée.
            //
            // Il y avait ici six formes d'alphabets différents — une flèche,
            // puis cercle, carré, losange, triangle, hexagone — à poids et
            // tailles optiques inégaux, pour encoder une profondeur que le
            // RETRAIT et les RAILS encodaient déjà. Un marqueur redondant,
            // dans un vocabulaire arbitraire à apprendre. Le connecteur, lui,
            // ne s'apprend pas : il montre à quoi la ligne se rattache.
            ForEach(0..<row.depth, id: \.self) { level in
                TreeConnector(
                    isLast: row.lineage.indices.contains(level) ? row.lineage[level] : true,
                    isElbow: level == row.depth - 1,
                    // Le coude vise le MILIEU de ce que la rangée montre en
                    // premier : 4 pt de marge + la moitié d'une pastille
                    // (≈ 28 pt), ou + la moitié d'une ligne de `caption2`
                    // (≈ 14 pt) quand la rangée porte un nom.
                    elbowY: label == nil ? 18 : 11
                )
                .stroke(BranchMarker.tint(for: level + 1).opacity(0.55), lineWidth: 1.5)
                .frame(width: Self.indentStep)
            }

            VStack(alignment: .leading, spacing: 3) {
                if let label {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(
                            row.chapterTitle != nil
                                ? BranchMarker.tint(for: row.depth) : Theme.textTertiary
                        )
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                FlowLayout(spacing: 5, lineSpacing: 7) {
                    ForEach(Array(row.moves.enumerated()), id: \.element.id) { position, move in
                        moveChip(move, isFirstOfLine: position == 0, isOnMainLine: row.isOnMainLine)
                    }
                    if row.isTransposition { transpositionChip(for: row, proxy: proxy) }
                }
            }
            // L'air est porté par le CONTENU, pas par la rangée : appliqué à
            // l'extérieur du `HStack`, il tombait hors des connecteurs, qui
            // s'arrêtaient donc 4 pt avant le bord — huit points de trou entre
            // deux rangées, et des rails en pointillés.
            .padding(.vertical, 4)
            .padding(.leading, row.depth > 0 ? 5 : 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.info.opacity(highlightedRowID == row.id ? 0.16 : 0))
        )
        .animation(Theme.gentle, value: highlightedRowID)
    }

    /// Largeur d'un étage de connecteur. Assez pour se voir, assez peu pour
    /// qu'une branche de profondeur 6 (le maximum du catalogue) garde de la
    /// place pour ses coups sur un écran de 320 pt.
    private static let indentStep: CGFloat = 13

    /// « La suite est ailleurs » : la position a déjà été dépliée par un autre
    /// chemin. On le DIT plutôt que de couper en silence (on croirait la ligne
    /// finie) ou de tout réafficher (des coups en double).
    ///
    /// Et surtout : c'est un RENVOI. Taper la puce fait défiler l'index jusqu'à
    /// la rangée qui déplie vraiment cette position, et l'y met en évidence le
    /// temps de la retrouver. Sans cela, « transposition » serait une impasse —
    /// on saurait que la suite existe sans pouvoir l'atteindre.
    @ViewBuilder
    private func transpositionChip(for row: OpeningLineTree.Node, proxy: ScrollViewProxy) -> some View {
        let destination = viewModel.destinationRow(of: row)
        Button {
            guard let destination else { return }
            highlightTask?.cancel()
            withAnimation(Theme.gentle) { proxy.scrollTo(destination, anchor: .center) }
            highlightedRowID = destination
            highlightTask = Task {
                try? await Task.sleep(for: Self.highlightDuration)
                guard !Task.isCancelled else { return }
                highlightedRowID = nil
            }
        } label: {
            Label("transposition", systemImage: "arrow.triangle.swap")
                .scaledSystemFont(size: 9, relativeTo: .caption2, weight: .medium, maximumScale: 1.6)
                .foregroundStyle(destination == nil ? Theme.textTertiary : Theme.info)
                .padding(.horizontal, 7).padding(.vertical, 7)
                .background(
                    (destination == nil ? Theme.surfaceElevated.opacity(0.5) : Theme.info.opacity(0.14)),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(
                        destination == nil ? .clear : Theme.info.opacity(0.4), lineWidth: 1
                    )
                )
        }
        .buttonStyle(.pressable(scale: 0.9))
        .disabled(destination == nil)
        .accessibilityIdentifier("openingIndex_transposition")
        .accessibilityHint(Text("Aller à la ligne qui poursuit cette position"))
    }

    // MARK: Une pastille de coup

    /// - Parameter isOnMainLine: la rangée appartient-elle à la ligne
    ///   PRINCIPALE de l'ouverture ? Elle se lit alors en gras et en texte
    ///   plein, les variantes restant en demi-teinte — c'est la hiérarchie
    ///   qu'on cherche du regard en ouvrant l'index.
    private func moveChip(
        _ move: OpeningLineIndex.IndexedMove, isFirstOfLine: Bool, isOnMainLine: Bool
    ) -> some View {
        let isCurrent = viewModel.isCurrent(move)
        let isOnPath = viewModel.isOnCurrentPath(move)

        return Button {
            onSelect(move.path)
        } label: {
            HStack(spacing: 2) {
                if let prefix = move.numberPrefix(isFirstOfLine: isFirstOfLine) {
                    Text(prefix)
                        .font(.caption2.monospacedDigit())
                        // 58 % et non 38 % : un numéro de coup est du PETIT
                        // texte, et 38 % de blanc le laisse à 3,5:1 — sous le
                        // seuil AA (4,5:1). Mesuré, pas supposé.
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                FigurineSANText(
                    san: move.san, color: move.color,
                    font: .caption.weight(isOnMainLine || isCurrent ? .heavy : .medium).monospaced(),
                    glyphSize: 13,
                    // Dessin agrandi d'un tiers, empreinte inchangée : les
                    // pièces se lisent, les pastilles gardent leur taille.
                    glyphOverscan: 1.35
                )
                .foregroundStyle(
                    isCurrent ? Theme.accent
                        : (isOnMainLine ? Theme.textPrimary : Theme.textSecondary)
                )
                // UN SEUL marqueur par pastille, et seulement quand il y a
                // quelque chose à signaler. L'index portait auparavant trois
                // pictogrammes concurrents (commenté, à mémoriser, rôle) : sur
                // une carte de cinquante coups, plus rien ne ressortait.
                if let quality = move.quality { qualityBadge(quality) }
            }
            .padding(.horizontal, 7).padding(.vertical, 7)
            .background(
                chipBackground(isCurrent: isCurrent, isOnPath: isOnPath, isOnMainLine: isOnMainLine),
                in: chipShape
            )
            // Toute la pastille est tappable, marges comprises.
            .contentShape(chipShape)
            .overlay(
                chipShape.strokeBorder(
                    isCurrent ? Theme.accent : (isOnMainLine ? Theme.strokeStrong : Theme.stroke),
                    lineWidth: isCurrent ? 1.5 : 1
                )
            )
        }
        .buttonStyle(.pressable(scale: 0.9))
        .accessibilityLabel(Text(accessibilityLabel(move)))
        .accessibilityIdentifier("openingIndex_move_\(move.ply)_\(move.uci)")
    }

    /// Le verdict du moteur, en notation d'échecs quand elle existe (« ?? »,
    /// « ? », « ?! », « !! ») — un joueur la lit sans légende — et en glyphe
    /// pour l'occasion manquée, que la notation ne sait pas dire.
    @ViewBuilder
    private func qualityBadge(_ quality: MoveQuality) -> some View {
        switch quality.icon {
        case let .text(symbol):
            Text(symbol)
                // Du TEXTE, donc Dynamic Type — plafonné, sinon « ?? » à la
                // taille accessibilité maximale déborderait la pastille.
                .scaledSystemFont(size: 10, relativeTo: .caption2, weight: .heavy, maximumScale: 1.6)
                .foregroundStyle(quality.tint)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.leading, 2)
        case let .symbol(name):
            Image(systemName: name)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(quality.tint)
                .padding(.leading, 2)
        }
    }

    private var chipShape: RoundedRectangle { RoundedRectangle(cornerRadius: 7, style: .continuous) }

    private func chipBackground(isCurrent: Bool, isOnPath: Bool, isOnMainLine: Bool) -> Color {
        if isCurrent { return Theme.accent.opacity(0.22) }
        if isOnPath { return Theme.accent.opacity(0.10) }
        return Theme.surfaceElevated.opacity(isOnMainLine ? 0.9 : 0.4)
    }

    private func accessibilityLabel(_ move: OpeningLineIndex.IndexedMove) -> String {
        let number = move.color == .white ? "\(move.moveNumber)." : "\(move.moveNumber)…"
        let spoken = "\(number) \(FigurineSAN.spoken(move.san))"
        // « ?? » ne se prononce pas : VoiceOver lit le libellé en clair.
        guard let quality = move.quality else { return spoken }
        return "\(spoken), \(quality.label)"
    }

    // MARK: Légende

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Légende")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase).tracking(0.4)

            // Plus de symboles à décoder : l'arbre se lit. Une seule ligne
            // suffit à dire ce que le retrait signifie.
            legendRow(
                TreeConnector(isLast: true, isElbow: true, elbowY: 9)
                    .stroke(BranchMarker.tint(for: 1).opacity(0.7), lineWidth: 1.5)
                    .frame(width: 14, height: 18),
                verbatim: LocalizationController.string("Variante : elle repart du coup indiqué")
            )
            // Les verdicts RÉELLEMENT présents dans cette ouverture. Annoncer
            // « occasion manquée » alors qu'aucun coup n'en porte fait chercher
            // pour rien — et sur les 58 ouvertures, cette catégorie-là ne se
            // produit jamais (les positions de théorie sont rarement gagnées).
            ForEach(presentQualities, id: \.self) { quality in
                legendRow(qualityBadge(quality), verbatim: quality.label)
            }
            legendRow(
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 9)).foregroundStyle(Theme.info),
                verbatim: LocalizationController.string("Transposition : taper pour voir la suite")
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }

    /// Ordre de la légende : du plus glorieux au plus douloureux, comme
    /// ``MoveQuality`` lui-même.
    private static let legendQualities: [MoveQuality] = [
        .brilliant, .inaccuracy, .mistake, .miss, .blunder,
    ]

    /// Ce que cette ouverture contient vraiment, dans l'ordre canonique.
    private var presentQualities: [MoveQuality] {
        let present = Set(viewModel.rows.flatMap { $0.moves.compactMap(\.quality) })
        return Self.legendQualities.filter(present.contains)
    }

    /// Libellé DÉJÀ traduit (``MoveQuality/label`` et
    /// ``LocalizationController/string(_:)`` résolvent eux-mêmes leur chaîne) :
    /// le repasser par le catalogue le traduirait deux fois.
    private func legendRow(_ mark: some View, verbatim text: String) -> some View {
        HStack(spacing: 8) {
            mark.frame(width: 16)
            Text(verbatim: text).font(.caption).foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
        }
    }
}

/// La TEINTE d'un étage de débranchement.
///
/// Née comme un jeu de six symboles (flèche, cercle, carré, losange,
/// triangle, hexagone) censés dire la profondeur. Ils la disaient mal : six
/// formes d'alphabets différents, à poids et tailles optiques inégaux, pour
/// une information que le retrait portait déjà. Depuis que l'arbre se dessine
/// avec de vrais connecteurs (``TreeConnector``), il ne reste que la couleur —
/// et elle n'est plus porteuse d'information, seulement une aide à suivre un
/// étage du regard.
///
/// Famille FROIDE, du bleu clair au violet : elle ne doit jamais se confondre
/// avec les verdicts du moteur, qui vont du jaune au rouge.
enum BranchMarker {
    private static let tints: [Color] = [
        Color(red: 0.353, green: 0.651, blue: 1.000),
        Color(red: 0.294, green: 0.518, blue: 0.949),
        Color(red: 0.290, green: 0.388, blue: 0.878),
        Color(red: 0.435, green: 0.365, blue: 0.902),
        Color(red: 0.580, green: 0.400, blue: 0.906),
        Color(red: 0.706, green: 0.443, blue: 0.878),
    ]

    static func tint(for depth: Int) -> Color {
        guard depth >= 1 else { return Theme.textTertiary }
        return tints[(depth - 1) % tints.count]
    }
}

/// Un segment d'arbre : le rail vertical d'un étage encore ouvert, ou le
/// connecteur « └ » / « ├ » de la rangée elle-même.
///
/// C'est la manière dont les vues arborescentes se dessinent depuis toujours,
/// et elle a un mérite qu'aucun jeu de symboles n'a : elle ne s'apprend pas.
/// Le trait MONTRE à quoi la ligne se rattache, et où la fratrie s'arrête.
struct TreeConnector: Shape {
    /// La branche de cet étage est-elle la DERNIÈRE de sa fratrie ? Le rail ne
    /// se prolonge alors pas sous la rangée.
    let isLast: Bool
    /// Cet étage est-il celui de la rangée (« └ »/« ├ ») ou un simple rail
    /// hérité d'un ancêtre ?
    let isElbow: Bool

    /// Hauteur à laquelle le trait horizontal rejoint la rangée.
    ///
    /// Elle DÉPEND de ce que la rangée montre en premier : le centre de sa
    /// première ligne de pastilles, ou celui de son nom de variante quand elle
    /// en porte un. Une rangée dont les coups se replient est haute ; brancher
    /// au milieu de sa hauteur totale viserait le vide.
    let elbowY: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x = rect.midX
        let y = min(elbowY, rect.maxY)
        let stop = isElbow && isLast ? y : rect.maxY

        path.move(to: CGPoint(x: x, y: rect.minY))
        path.addLine(to: CGPoint(x: x, y: stop))

        if isElbow {
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}
