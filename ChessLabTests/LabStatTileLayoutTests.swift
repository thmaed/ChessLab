import SwiftUI
import UIKit
import XCTest
@testable import ChessLab

/// Les tuiles de statistiques du Laboratoire sont TENDUES : sur un iPhone en
/// Zoom d'affichage, une tuile ne laisse que 62 pt à son libellé, et
/// « parties jouées » en réclame 74 — il ne tient que grâce au facteur de
/// réduction, et il n'y a aucune marge derrière.
///
/// Ce qui a motivé ce test : le picto « ? » ajouté le 24/08 avait d'abord été
/// posé DANS la rangée. Il coûtait 26 pt (14 de glyphe + 12 d'écart) et
/// coupait les six libellés d'un coup — sur tous les iPhone, pas seulement en
/// Zoom. Passé en incrustation d'angle, il ne coûte plus rien. Sans mesure,
/// rien ne distinguait les deux versions : elles compilent aussi bien.
@MainActor
final class LabStatTileLayoutTests: XCTestCase {

    /// iPhone 11 Pro en Zoom d'affichage : 320 pt au lieu de 375.
    private static let zoomedWidth: CGFloat = 320
    /// `LabRunView` pose 20 pt de marge et une grille de deux colonnes
    /// espacées de 12.
    private static var tileWidth: CGFloat { (zoomedWidth - 40 - 12) / 2 }

    /// Ce que la tuile laisse au texte : ses 12 pt de marge de chaque côté,
    /// la pastille d'icône (36) et l'écart qui la suit (12).
    private static var textWidth: CGFloat { tileWidth - 12 - 36 - 12 - 12 }

    /// Facteur de réduction appliqué au libellé par ``LabStatTile``.
    private static let minimumScale: CGFloat = 0.7

    private func intrinsicWidth(_ view: some View) -> CGFloat {
        UIHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: 5000, height: 200))
            .width
    }

    /// Les six libellés réellement affichés par ``LabRunView``.
    private static let labels = [
        "score de A", "V · N · D (A)", "écart Elo ±42",
        "LOS (A > B)", "coups / partie", "parties jouées",
    ]

    func testEveryStatLabelStillFitsOnAZoomedIPhone() {
        for label in Self.labels {
            let needed = intrinsicWidth(Text(label).font(.caption2)) * Self.minimumScale
            XCTAssertLessThanOrEqual(
                needed, Self.textWidth,
                "« \(label) » réclame \(needed) pt même réduit au maximum, pour \(Self.textWidth) "
                    + "disponibles : il sera coupé. Quelque chose a été ajouté dans la rangée de la tuile."
            )
        }
    }

    /// Le picto d'aide doit rester HORS de la rangée. S'il y revient, ce test
    /// tombe avant que les libellés ne se coupent en silence.
    func testTheHelpGlyphCostsNoWidth() {
        let bare = intrinsicWidth(
            HStack(spacing: 12) {
                IconBadge(systemImage: "percent", tint: .green, size: 36)
                Text("parties jouées").font(.caption2)
            }
        )
        let tile = intrinsicWidth(
            LabStatTile(value: "50/100", label: "parties jouées", icon: "percent",
                        tint: .green, explanation: .gamesPlayed)
                .fixedSize()
        )
        // La tuile ajoute à cette rangée : ses 24 pt de marge horizontale, et
        // l'écart de 12 pt que son `Spacer` final ouvre en tant que troisième
        // enfant du `HStack`. Rien d'autre — le picto d'aide est incrusté.
        let expected = bare + 24 + 12
        XCTAssertEqual(
            tile, expected, accuracy: 1,
            "La tuile réclame \(tile) pt là où sa rangée n'en vaut que \(expected) : "
                + "un élément de plus y occupe de la largeur."
        )
    }
}
