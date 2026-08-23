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
    @Bindable var viewModel: OpeningLabsViewModel
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
                        .accessibilityIdentifier("labsIndex_close")
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
        VStack(alignment: .leading, spacing: 7) {
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
        VStack(alignment: .leading, spacing: 3) {
            if let title = row.chapterTitle?.resolved(languageCode) {
                branchLabel(title, depth: row.depth, tint: BranchMarker.tint(for: row.depth))
            } else if let eco = row.ecoName, row.depth > 0 {
                branchLabel(eco, depth: row.depth, tint: Theme.textTertiary)
            }

            HStack(alignment: .top, spacing: 0) {
                // Rails de profondeur : de fins traits verticaux qui rattachent
                // la branche à celle dont elle descend. Sans eux, à quatre
                // niveaux, le retrait seul ne dit plus de qui on descend.
                ForEach(0..<indentLevels(row.depth), id: \.self) { level in
                    Rectangle()
                        .fill(BranchMarker.tint(for: level + 1).opacity(0.22))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.trailing, Self.indentStep - 1)
                }
                if row.depth > 0 {
                    BranchMarker.icon(for: row.depth)
                        .padding(.trailing, 5)
                        .padding(.top, 4)
                }
                FlowLayout(spacing: 4, lineSpacing: 6) {
                    ForEach(Array(row.moves.enumerated()), id: \.element.id) { position, move in
                        moveChip(move, isFirstOfLine: position == 0, isOnMainLine: row.isOnMainLine)
                    }
                    if row.isTransposition { transpositionChip(for: row, proxy: proxy) }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        // Surbrillance du renvoi : elle déborde la rangée pour l'encadrer, et
        // s'estompe d'elle-même.
        .padding(.vertical, highlightedRowID == row.id ? 4 : 0)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.info.opacity(highlightedRowID == row.id ? 0.16 : 0))
        )
        .animation(Theme.gentle, value: highlightedRowID)
    }

    /// Le nom que porte une branche : titre de chapitre écrit à la main, ou à
    /// défaut le nom de variante que la donnée connaît.
    private func branchLabel(_ text: String, depth: Int, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(2)
            .padding(.leading, CGFloat(indentLevels(depth)) * Self.indentStep + 17)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Retrait par étage. Assez pour se voir, assez peu pour qu'une branche de
    /// profondeur 6 (le maximum du catalogue) garde de la place pour ses coups
    /// sur un écran de 320 pt.
    private static let indentStep: CGFloat = 11

    /// Étages de retrait DESSINÉS. Plafonnés : au-delà, l'imbrication continue
    /// mais le retrait ne creuse plus, sinon les coups finiraient écrasés
    /// contre le bord droit. Le marqueur, lui, continue de distinguer.
    private func indentLevels(_ depth: Int) -> Int { min(depth, 5) }

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
        .accessibilityIdentifier("labsIndex_transposition")
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
        .accessibilityIdentifier("labsIndex_move_\(move.ply)_\(move.uci)")
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

            // Les étages RÉELLEMENT présents : une ouverture qui ne débranche
            // que deux fois n'a pas besoin d'une légende à six symboles.
            if presentDepths >= 1 {
                ForEach(1...presentDepths, id: \.self) { depth in
                    legendRow(
                        BranchMarker.icon(for: depth),
                        verbatim: LocalizationController.string("Débranchement, étage %lld", depth)
                    )
                }
            }
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

    /// Étage de débranchement le plus profond affiché.
    private var presentDepths: Int {
        min(viewModel.rows.map(\.depth).max() ?? 0, BranchMarker.levels)
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

/// Le marqueur d'un ÉTAGE de débranchement : une forme et une couleur par
/// niveau, cohérentes dans tout l'arbre.
///
/// Forme ET couleur, pas l'une ou l'autre : la couleur seule ne se distingue
/// pas en niveaux de gris ni pour un daltonien, la forme seule se confond à
/// 8 pt. Ensemble, on retrouve un étage d'un coup d'œil en balayant l'écran —
/// c'est ce qui permet de lire un arbre profond sans compter les retraits.
enum BranchMarker {
    /// Étages qui ont leur propre marqueur ; au-delà, on recycle (le catalogue
    /// livré ne dépasse pas six).
    static let levels = 6

    private static let symbols = [
        "arrow.turn.down.right",   // ↳ étage 1
        "circle",                  // ○ étage 2
        "square",                  // □ étage 3
        "diamond",                 // ◇ étage 4
        "triangle",                // △ étage 5
        "hexagon",                 // ⬡ étage 6
    ]

    /// Teintes distinctes et non conflictuelles avec celles des verdicts
    /// (jaune → rouge) : famille froide, du bleu clair au violet.
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

    @ViewBuilder
    static func icon(for depth: Int) -> some View {
        let index = max(0, depth - 1) % symbols.count
        Image(systemName: symbols[index])
            .font(.system(size: depth == 1 ? 10 : 8, weight: .semibold))
            .foregroundStyle(tint(for: depth))
            .accessibilityHidden(true)
    }
}
