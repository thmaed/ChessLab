import ChessKit
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import ChessLab

/// Une image réelle et la vérité attendue. Voir
/// `ScannerFixtures/README.md`.
struct ScannerFixture: Codable, Sendable, CustomStringConvertible {
    let file: String
    let source: String
    /// Placement attendu (premier champ d'un FEN), vu du côté des Blancs.
    let fen: String
    let minCorrectSquares: Int
    /// Plateau réel : la v1 ne déduit pas le type des pièces (Lot 1.E), la
    /// comparaison ignore alors le type.
    /// Coins en pixels (origine en haut à gauche), si la détection
    /// automatique échoue sur cette image.
    var corners: [[Double]]?
    /// Quarts de tour à appliquer, quand l'orientation de la prise de vue est
    /// CONNUE. Une fixture mesure la reconnaissance ; la deviner en plus
    /// mélangerait deux échecs différents dans un seul chiffre — et
    /// l'orientation, elle, dépend d'un test de légalité que le moindre roi
    /// manquant met hors-jeu. Absent : on laisse `suggestedRotation`.
    var rotation: Int?
    /// Cases fausses ET données pour sûres tolérées. Une erreur signalée est
    /// rattrapable à l'écran de confirmation ; une erreur silencieuse, non.
    var maxSilentlyWrong: Int?

    var description: String { file }

    var scanSource: ScanSource {
        ScanSource(rawValue: source) ?? .screenshot
    }
}

/// Chargement du manifeste depuis le bundle de tests.
enum ScannerFixtures {
    static let all: [ScannerFixture] = {
        guard let url = Bundle(for: ScannerFixtureBundleToken.self)
            .url(forResource: "manifest", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let fixtures = try? JSONDecoder().decode([ScannerFixture].self, from: data)
        else { return [] }
        return fixtures
    }()

    static var isAvailable: Bool { !all.isEmpty }
}

/// Ancre pour retrouver le bundle de tests (`Bundle(for:)` exige une classe).
private final class ScannerFixtureBundleToken {}

/// Tests sur **images réelles** — la seule question à laquelle les tests
/// synthétiques ne répondent pas : « ça marche vraiment ? ».
///
/// Tant que `ScannerFixtures/manifest.json` est vide, cette suite ne produit
/// aucun cas et la suite globale reste verte : c'est voulu (les images sont
/// une action utilisateur, l'agent ne peut pas les fabriquer). Le jour où
/// elles arrivent, ces tests deviennent le juge de paix des seuils.
@Suite(.enabled(if: ScannerFixtures.isAvailable, "Aucune fixture : voir ChessLabTests/ScannerFixtures/README.md"))
@MainActor
struct ScannerFixtureTests {

    @Test(arguments: ScannerFixtures.all)
    func aFixtureIsReadWithinItsTolerance(fixture: ScannerFixture) throws {
        let image = try #require(loadImage(named: fixture.file), "image \(fixture.file) introuvable dans le bundle")

        let quad = try #require(
            boardQuad(for: fixture, image: image),
            "ni coins explicites ni détection automatique pour \(fixture.file)"
        )
        // LE VRAI CHEMIN DE L'APP, celui de `ScannerViewModel` : YOLO d'abord
        // pour un diagramme numérique, gabarits en repli. Tester les gabarits
        // seuls mesurerait un code que l'utilisateur n'exécute plus.
        let reading = try #require(realPipelineReading(image: image, quad: quad, fixture: fixture))
        let rotation = fixture.rotation.flatMap(BoardReadingRotation.init(rawValue:))
            ?? reading.suggestedRotation()
        let read = reading.squares(rotation: rotation)

        let expected = try #require(
            Position(fen: "\(fixture.fen) w - - 0 1"),
            "FEN de référence illisible pour \(fixture.file)"
        )

        var correct = 0
        var wrong: [String] = []

        for square in Square.allCases {
            if matches(
                truth: expected.piece(at: square),
                read: read[square]?.occupancy ?? .empty,
                ignoringKind: false
            ) {
                correct += 1
            } else {
                wrong.append(square.notation)
            }
        }

        #expect(
            correct >= fixture.minCorrectSquares,
            "\(fixture.file) : \(correct)/64 (attendu ≥ \(fixture.minCorrectSquares)) — cases fausses : \(wrong.joined(separator: " "))"
        )

        // Les cases fausses doivent au moins être SIGNALÉES : une erreur
        // silencieuse est pire qu'une erreur avouée, puisque l'écran de
        // confirmation surligne les cases douteuses.
        let flagged = reading.lowConfidenceSquares(rotation: rotation)
        let silentlyWrong = wrong.filter { !flagged.contains(Square($0)) }
        #expect(
            silentlyWrong.count <= (fixture.maxSilentlyWrong ?? 2),
            "\(fixture.file) : \(silentlyWrong.count) cases fausses ET données pour sûres : \(silentlyWrong.joined(separator: " "))"
        )
    }

    /// Reproduit `ScannerViewModel` : détection d'objets sur le plateau entier
    /// pour les sources numériques, découpe en cases + gabarits sinon.
    private func realPipelineReading(
        image: CGImage, quad: BoardQuad, fixture: ScannerFixture
    ) -> BoardScanReading? {
        // Toutes les sources restantes sont des diagrammes numériques : le
        // chemin YOLO est le seul (le scanner de plateau réel a été retiré).
        if let rectified = BoardRectifier.rectify(image, quad: quad),
           let squares = BoardRectifier.rectifyAndSlice(image, quad: quad),
           let yolo = YOLOBoardClassifier(),
           let primary = BoardScanner.scan(
               board: rectified, source: fixture.scanSource, boardClassifier: yolo
           ) {
            // Recroisement YOLO × gabarits, comme `ScannerViewModel` : ce sont
            // les cases signalées qui comptent pour `maxSilentlyWrong`.
            let secondary = BoardScanner.scan(
                squares: squares, source: fixture.scanSource,
                classifier: TemplateSquareClassifier(source: fixture.scanSource)
            )
            return primary.crossChecked(against: secondary)
        }
        guard let squares = BoardRectifier.rectifyAndSlice(image, quad: quad) else { return nil }
        return BoardScanner.scan(
            squares: squares, source: fixture.scanSource,
            classifier: TemplateSquareClassifier(source: fixture.scanSource)
        )
    }

    private func matches(truth: Piece?, read: SquareOccupancy, ignoringKind: Bool) -> Bool {
        switch (truth, read) {
        case (nil, .empty):
            return true
        case let (piece?, .piece(color, kind)):
            guard piece.color == color else { return false }
            return ignoringKind || piece.kind == kind
        default:
            return false
        }
    }

    private func boardQuad(for fixture: ScannerFixture, image: CGImage) -> BoardQuad? {
        if let corners = fixture.corners, corners.count == 4 {
            return BoardQuad.ordering(corners.map { CGPoint(x: $0[0], y: $0[1]) })
        }
        return BoardDetector.detect(in: image, source: fixture.scanSource)
    }

    private func loadImage(named name: String) -> CGImage? {
        let bundle = Bundle(for: ScannerFixtureBundleToken.self)
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension

        guard let url = bundle.url(forResource: base, withExtension: ext),
              let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data)
        else { return nil }

        return ScannerViewModel.prepare(uiImage)
    }
}
