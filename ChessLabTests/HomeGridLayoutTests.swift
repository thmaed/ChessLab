import SwiftUI
import XCTest

@testable import ChessLab

/// L'accueil sur l'écran le plus étroit à supporter — iPhone 11 Pro en Zoom
/// d'affichage, 320 pt.
///
/// Les sept modes s'y empilaient sur UNE colonne : la grille adaptative
/// réclamait 2 × 160 + 14 = 334 pt pour 280 disponibles. Le défaut est de la
/// même famille que celui de ``PlayControlBar`` — une largeur figée qui tient
/// à 375 pt et pas en dessous — et il se mesure de la même façon, hors
/// interface, à une largeur qu'aucun simulateur iOS 26 ne sait produire.
@MainActor
final class HomeGridLayoutTests: XCTestCase {


    /// Les sept modes tels qu'``HomeView`` les déclare — libellés compris,
    /// puisque c'est justement la longueur des textes qui décide de ce qui
    /// tient dans une tuile étroite.
    private static let realModes: [(title: LocalizedStringKey, shortTitle: LocalizedStringKey?, subtitle: LocalizedStringKey?, shortSubtitle: LocalizedStringKey?, symbol: String, tint: Color)] = [
        ("Contre l'ordinateur", "Ordinateur", "Force, cadence, aides", nil, "cpu", Theme.accent),
        ("Deux joueurs", "2 joueurs", "Sur le même appareil", nil, "person.2.fill", Theme.info),
        ("Puzzles", nil, "Tactique et bibliothèque Lichess", "Tactique et Lichess", "puzzlepiece.fill", Theme.violet),
        ("Ouvertures", nil, "Apprends et révise tes ouvertures", "Apprends et révise", "books.vertical.fill", Theme.warning),
        ("Finales", nil, "Lucena, Philidor, opposition — prouvées", "Techniques prouvées", "crown.fill", Theme.gold),
        ("Analyser", nil, "PGN, FEN, bibliothèque", "PGN, FEN", "chart.xyaxis.line", Theme.teal),
        ("Laboratoire", nil, "L'ordinateur contre lui-même", "Face à lui-même", "flask", Theme.rose),
    ]

    /// La grille de l'accueil, reconstruite avec les VRAIES constantes et les
    /// VRAIES tuiles : seules les actions sont neutralisées. Ce n'est pas une
    /// copie du calcul — c'est `LazyVGrid` qui décide, comme dans l'app.
    private func modeGrid(tileMinimum: CGFloat) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: tileMinimum), spacing: ModeGridMetrics.spacing)],
            spacing: ModeGridMetrics.spacing
        ) {
            ForEach(Array(Self.realModes.enumerated()), id: \.offset) { _, mode in
                ModeCard(
                    title: mode.title,
                    shortTitle: mode.shortTitle,
                    subtitle: mode.subtitle,
                    shortSubtitle: mode.shortSubtitle,
                    systemImage: mode.symbol,
                    tint: mode.tint,
                    isEnabled: true
                ) {}
            }
        }
        .environment(\.horizontalSizeClass, .compact)
    }

    /// Hauteur rendue de la grille pour une largeur d'écran donnée.
    private func gridHeight(screen: CGFloat, tileMinimum: CGFloat) -> CGFloat {
        let usable = ModeGridMetrics.usableWidth(screen: screen)
        let host = UIHostingController(rootView: modeGrid(tileMinimum: tileMinimum).frame(width: usable))
        return host.sizeThatFits(in: CGSize(width: usable, height: .greatestFiniteMagnitude)).height
    }

    // MARK: Le nombre de colonnes, mesuré et non calculé

    /// Sept tuiles sur deux colonnes font quatre rangées ; sur une seule,
    /// sept. Les deux hauteurs sont si éloignées qu'aucune tolérance n'est
    /// nécessaire — et c'est `LazyVGrid` lui-même qui tranche.
    func testGridGivesTwoColumnsOnTheNarrowestScreen() {
        let narrow = ModeGridMetrics.narrowestScreen
        let twoColumns = gridHeight(screen: narrow, tileMinimum: ModeGridMetrics.minTileIPhone)
        let oneColumn = gridHeight(screen: narrow, tileMinimum: 160)

        XCTAssertLessThan(
            twoColumns, oneColumn * 0.7,
            "À \(narrow) pt, la grille rend \(twoColumns) pt de haut contre \(oneColumn) à une colonne : "
                + "les sept modes s'empilent encore."
        )
    }

    /// Et l'accueil ne change pas là où il allait déjà bien.
    func testGridStillGivesTwoColumnsAtStandardWidth() {
        let atNarrow = gridHeight(screen: ModeGridMetrics.narrowestScreen, tileMinimum: ModeGridMetrics.minTileIPhone)
        let at375 = gridHeight(screen: 375, tileMinimum: ModeGridMetrics.minTileIPhone)
        XCTAssertEqual(at375, atNarrow, accuracy: 1, "le nombre de rangées ne doit pas dépendre de la largeur ici")
    }

    // MARK: Les chiffres qui décident

    func testTwoColumnsFitAndThreeDoNot() {
        let tile = ModeGridMetrics.minTileIPhone
        let narrow = ModeGridMetrics.narrowestScreen
        XCTAssertTrue(
            ModeGridMetrics.fits(columns: 2, tile: tile, screen: narrow),
            "deux colonnes de \(tile) pt ne tiennent pas dans \(ModeGridMetrics.usableWidth(screen: narrow)) pt utiles"
        )
        // Garde-fou dans l'autre sens : une tuile trop étroite ouvrirait une
        // troisième colonne sur les grands iPhone, ce que la maquette ne
        // prévoit pas.
        XCTAssertFalse(
            ModeGridMetrics.fits(columns: 3, tile: tile, screen: 440),
            "trois colonnes apparaîtraient sur un iPhone Pro Max"
        )
    }
}

// MARK: - Aperçu à l'œil, aux largeurs qu'aucun simulateur ne produit

extension HomeGridLayoutTests {

    /// Écrit dans `/tmp` un PNG de la grille à 320 et 375 pt, plus le rendu
    /// d'AVANT pour comparaison.
    ///
    /// Inerte par défaut — un test ne doit pas semer des fichiers à chaque
    /// exécution. Pour regarder :
    ///
    /// ```
    /// CHESSLAB_RENDER_PREVIEWS=1 xcodebuild … \
    ///   -only-testing:ChessLabTests/HomeGridLayoutTests/testRenderGridPreviews test
    /// ```
    ///
    /// C'est l'instrument qui manquait au Lot 3 : `ImageRenderer` rend
    /// n'importe quelle vue à n'importe quelle largeur, sans appareil ni
    /// simulateur. Un débordement de mise en page se REGARDE en dix secondes.
    func testRenderGridPreviews() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CHESSLAB_RENDER_PREVIEWS"] == "1",
            "aperçu à la demande (CHESSLAB_RENDER_PREVIEWS=1)"
        )
        for (screen, tile, name) in [
            (ModeGridMetrics.narrowestScreen, ModeGridMetrics.minTileIPhone, "320-apres"),
            (CGFloat(375), ModeGridMetrics.minTileIPhone, "375-apres"),
            (CGFloat(375), CGFloat(160), "375-avant"),
        ] {
            let usable = ModeGridMetrics.usableWidth(screen: screen)
            let renderer = ImageRenderer(
                content: modeGrid(tileMinimum: tile)
                    .frame(width: usable)
                    .padding(ModeGridMetrics.contentPadding)
                    .background(Theme.background)
            )
            renderer.scale = 3
            guard let image = renderer.uiImage, let data = image.pngData() else {
                XCTFail("rendu impossible"); return
            }
            try data.write(to: URL(fileURLWithPath: "/tmp/chesslab-grid-\(name).png"))
        }
    }
}
