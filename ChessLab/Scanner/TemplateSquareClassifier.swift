import ChessKit
import CoreGraphics
import SwiftUI
import UIKit

/// Reconnaissance des pièces sur un **diagramme numérique** (capture d'écran
/// ou photo d'un écran), par corrélation contre des gabarits.
///
/// Pourquoi ça marche ici et pas sur un plateau réel : une capture affiche
/// des glyphes 2D, toujours identiques, vus de face. Et **cburnett est le set
/// par défaut de Lichess** — celui-là même qu'embarque l'app : une capture
/// Lichess tombe donc sur des glyphes au pixel près identiques aux gabarits.
///
/// Mesure : corrélation croisée **normalisée** (ZNCC), invariante à toute
/// transformation affine de la luminosité. C'est ce qui permet de reconnaître
/// les mêmes glyphes sur un thème de plateau inconnu, ou sur une photo
/// d'écran sous-exposée, sans calibrer quoi que ce soit.
///
/// Type VALEUR non isolé : seul le rendu des gabarits touche UIKit, et il est
/// cantonné à l'`init`. `classify` reste du calcul pur, exécutable hors du fil
/// principal si le besoin s'en fait sentir, sans toucher au protocole.
struct TemplateSquareClassifier: SquareClassifying {

    /// Côté des vignettes normalisées. 32 px suffisent à distinguer les 6
    /// silhouettes et gardent la comparaison rapide (64 cases × ~200
    /// gabarits × 1024 pixels).
    static let patchSide = 32

    struct Template {
        let color: Piece.Color
        let kind: Piece.Kind
        /// Vignette centrée-réduite : ZNCC se réduit alors à un produit
        /// scalaire, calculé une fois pour toutes ici.
        let normalized: [Double]
    }

    private let templates: [Template]
    private let source: ScanSource

    /// Seuil de score au-delà duquel on considère qu'il y a bien une pièce.
    private let matchThreshold: Double
    /// Écart-type en deçà duquel la case est jugée vide (aucun contraste).
    private let flatnessThreshold: Double

    /// Le rendu des gabarits passe par UIKit, d'où l'isolation ici — et ici
    /// seulement.
    @MainActor
    init(source: ScanSource, themes: [BoardTheme] = BoardTheme.all) {
        self.source = source

        // Une photo d'écran apporte moiré, reflets et exposition inégale :
        // on accepte des scores plus bas, quitte à marquer plus de cases
        // « incertaines ». Mieux vaut une case signalée qu'une erreur
        // silencieuse — l'utilisateur corrige d'un tap à la confirmation.
        matchThreshold = source == .screenshot ? 0.45 : 0.32
        flatnessThreshold = source == .screenshot ? 0.035 : 0.05

        templates = Self.makeTemplates(themes: themes)
    }

    // MARK: Gabarits

    /// Les 12 pièces × (case claire, case sombre) de chaque thème × plusieurs
    /// échelles. Deux fonds parce qu'un glyphe blanc sur case claire et le
    /// même sur case sombre ne dessinent pas le même motif ; plusieurs
    /// échelles parce que la marge autour de la pièce varie d'un site à
    /// l'autre.
    @MainActor
    private static func makeTemplates(themes: [BoardTheme]) -> [Template] {
        var templates: [Template] = []
        let renderSide = CGFloat(patchSide * 4)

        for color in Piece.Color.allCases {
            for kind in Piece.Kind.allCases {
                let piece = Piece(kind, color: color, square: .a1)

                for theme in themes {
                    for background in [theme.lightSquare, theme.darkSquare] {
                        for glyphScale in [0.78, 0.9, 1.0] as [CGFloat] {
                            guard let rendered = BoardImageRenderer.renderSquare(
                                piece: piece, background: background,
                                side: renderSide, glyphScale: glyphScale
                            ), let vector = ImagePatch.normalizedVector(of: rendered, side: patchSide)
                            else { continue }

                            templates.append(Template(color: color, kind: kind, normalized: vector))
                        }
                    }
                }
            }
        }
        return templates
    }

    // MARK: Classification

    func classify(_ square: CGImage) -> SquareReading {
        guard let patch = ImagePatch.grayscale(of: square, side: Self.patchSide) else {
            return SquareReading(occupancy: .empty, confidence: 0)
        }

        // Une case vide est un aplat : rien à corréler. Ce test AVANT le
        // matching évite qu'un gabarit quelconque « gagne » sur du bruit.
        let deviation = ImagePatch.standardDeviation(patch)
        if deviation < flatnessThreshold {
            return SquareReading(occupancy: .empty, confidence: 1)
        }

        // Coordonnées incrustées (chess.com, Lichess) : un « 8 » dans le COIN
        // d'une case vide la rend contrastée, mais son CENTRE reste un aplat —
        // alors qu'une pièce, elle, couvre toujours le centre. Sans ce test,
        // les 15 cases du bord partaient en corrélation et ressortaient
        // « incertaines » sur toute capture à coordonnées.
        let central = ImagePatch.centralRegion(patch, side: Self.patchSide, keeping: 0.6)
        if ImagePatch.standardDeviation(central) < flatnessThreshold {
            return SquareReading(occupancy: .empty, confidence: 0.9)
        }

        guard let normalized = ImagePatch.normalize(patch) else {
            return SquareReading(occupancy: .empty, confidence: 1)
        }

        var best: (template: Template, score: Double)?
        var bestOtherPieceScore = -1.0

        for template in templates {
            let score = ImagePatch.dot(normalized, template.normalized)

            if let current = best, score <= current.score {
                if template.kind != current.template.kind || template.color != current.template.color {
                    bestOtherPieceScore = max(bestOtherPieceScore, score)
                }
                continue
            }
            if let current = best {
                if template.kind != current.template.kind || template.color != current.template.color {
                    bestOtherPieceScore = max(bestOtherPieceScore, current.score)
                }
            }
            best = (template, score)
        }

        guard let best, best.score >= matchThreshold else {
            // Du contraste, mais qui ne ressemble à aucune pièce : plutôt que
            // d'inventer, on rend « vide » avec une confiance basse — la case
            // sera surlignée à la confirmation.
            return SquareReading(occupancy: .empty, confidence: 0.3)
        }

        return SquareReading(
            occupancy: .piece(color: best.template.color, kind: best.template.kind),
            confidence: confidence(best: best.score, runnerUp: bestOtherPieceScore)
        )
    }

    /// Confiance = qualité du score ET **avance sur la meilleure AUTRE
    /// pièce**. Un cavalier reconnu à 0.9 alors que le fou suit à 0.89 n'est
    /// pas une lecture sûre : c'est exactement le cas qu'il faut soumettre à
    /// l'utilisateur.
    private func confidence(best: Double, runnerUp: Double) -> Double {
        let quality = min(max(best, 0), 1)
        let margin = min(max(best - runnerUp, 0) * 4, 1)
        return min(max(quality * 0.65 + margin * 0.35, 0), 1)
    }
}

/// Vignette en niveaux de gris et corrélation.
///
/// Séparé du classifieur, sans UI ni état : c'est du calcul pur, donc
/// testable directement.
enum ImagePatch {

    /// Vignette `side` × `side` en niveaux de gris, valeurs 0...1.
    static func grayscale(of image: CGImage, side: Int) -> [Double]? {
        var pixels = [UInt8](repeating: 0, count: side * side)

        guard let context = CGContext(
            data: &pixels, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return pixels.map { Double($0) / 255 }
    }

    /// Région centrale d'une vignette carrée : la fraction `keeping` du côté,
    /// centrée. Sert à juger « vide » une case dont seuls les COINS sont
    /// marqués (coordonnées incrustées).
    static func centralRegion(_ patch: [Double], side: Int, keeping fraction: Double) -> [Double] {
        let inset = Int(Double(side) * (1 - fraction) / 2)
        guard inset > 0, side - 2 * inset > 0 else { return patch }
        var values = [Double]()
        values.reserveCapacity((side - 2 * inset) * (side - 2 * inset))
        for row in inset..<(side - inset) {
            for column in inset..<(side - inset) {
                values.append(patch[row * side + column])
            }
        }
        return values
    }

    static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    static func standardDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let average = mean(values)
        let variance = values.reduce(0) { $0 + ($1 - average) * ($1 - average) } / Double(values.count)
        return variance.squareRoot()
    }

    /// Centre et réduit : la corrélation ZNCC de deux vecteurs ainsi
    /// normalisés est leur simple produit scalaire. `nil` sur un aplat
    /// (écart-type nul), où la corrélation n'a aucun sens.
    static func normalize(_ values: [Double]) -> [Double]? {
        let average = mean(values)
        let deviation = standardDeviation(values)
        guard deviation > 1e-6 else { return nil }

        let scale = 1 / (deviation * Double(values.count).squareRoot())
        return values.map { ($0 - average) * scale }
    }

    static func normalizedVector(of image: CGImage, side: Int) -> [Double]? {
        guard let patch = grayscale(of: image, side: side) else { return nil }
        return normalize(patch)
    }

    /// Produit scalaire = ZNCC pour des vecteurs normalisés. Résultat
    /// dans -1...1.
    static func dot(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        var sum = 0.0
        for i in a.indices { sum += a[i] * b[i] }
        return sum
    }
}
