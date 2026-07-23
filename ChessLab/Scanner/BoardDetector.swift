import CoreGraphics
import Foundation
import Vision

/// Détection automatique des quatre coins d'un plateau dans une image.
///
/// Pur et sans UI. **Le résultat n'est jamais une vérité** : il ne fait que
/// pré-positionner les poignées de l'ajustement manuel (``BoardCropView``),
/// qui reste le vrai filet de sécurité — un plateau en bois peu contrasté
/// avec la table, ou une photo d'écran pleine de reflets, mettront cette
/// détection en défaut régulièrement.
enum BoardDetector {

    /// Réglages de `VNDetectRectanglesRequest`, regroupés pour être ajustés
    /// d'un seul endroit au vu des fixtures.
    struct Configuration {
        /// Un plateau est carré : on écarte tout ce qui s'en éloigne trop
        /// (une perspective légère l'aplatit un peu, d'où 0.8 et non 1).
        var minimumAspectRatio: Float = 0.8
        var maximumAspectRatio: Float = 1.0
        /// Fraction minimale de l'image couverte : un plateau qu'on veut
        /// scanner remplit le cadre, pas un timbre-poste.
        var minimumSize: Float = 0.2
        var minimumConfidence: VNConfidence = 0.5
        /// Écart toléré à l'angle droit, en degrés.
        var quadratureTolerance: Float = 30
        var maximumObservations: Int = 8

        static let `default` = Configuration()
    }

    /// Résultat d'une détection : les coins, et si l'on peut s'y FIER assez
    /// pour sauter le cadrage manuel.
    struct Detection {
        var quad: BoardQuad
        /// Vrai quand le motif de damier a été reconnu avec certitude : le
        /// scanner enchaîne alors directement sur la reconnaissance, sans
        /// demander de recadrer.
        var isConfident: Bool
    }

    /// - parameter source: pilote la stratégie. Pour une photo d'écran, le
    ///   plus grand rectangle trouvé est souvent l'ÉCRAN lui-même : on
    ///   relance alors une détection à l'intérieur pour trouver le plateau.
    /// - returns: les coins en pixels, origine en haut à gauche
    ///   (convention ``BoardQuad``), ou `nil` si rien de plausible.
    static func detect(
        in image: CGImage,
        source: ScanSource,
        configuration: Configuration = .default
    ) -> BoardQuad? {
        detectBoard(in: image, source: source, configuration: configuration)?.quad
    }

    /// Détection AVEC niveau de confiance (pour l'auto-cadrage).
    ///
    /// Pour un diagramme numérique (capture, photo d'écran), on cherche
    /// d'abord le motif de DAMIER (``CheckerboardDetector``), bien plus fiable
    /// que la détection de rectangles de Vision : le plateau y est aligné sur
    /// les axes et sa signature 8×8 est imparable. Vision reste le repli, et
    /// la seule voie pour un plateau réel en perspective.
    static func detectBoard(
        in image: CGImage,
        source: ScanSource,
        configuration: Configuration = .default
    ) -> Detection? {
        if let checker = CheckerboardDetector.detect(in: image) {
            return Detection(quad: BoardQuad.covering(rect: checker.rect), isConfident: true)
        }

        guard let outer = largestRectangle(in: image, configuration: configuration) else { return nil }
        let quad = source == .screenPhoto
            ? (boardInsideScreen(of: image, outer: outer, configuration: configuration) ?? outer)
            : outer
        // Vision ne donne jamais la certitude d'un damier : on repasse par le
        // cadrage manuel.
        return Detection(quad: quad, isConfident: false)
    }

    /// Second passage POUR LES PHOTOS D'ÉCRAN : si le rectangle détecté est
    /// l'écran entier, le plateau est un rectangle plus petit à l'intérieur.
    private static func boardInsideScreen(
        of image: CGImage, outer: BoardQuad, configuration: Configuration
    ) -> BoardQuad? {
        let bounds = boundingBox(of: outer).integral
        let clamped = bounds.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard clamped.width > 100, clamped.height > 100,
              let cropped = image.cropping(to: clamped),
              let inner = largestRectangle(in: cropped, configuration: configuration)
        else { return nil }

        // Le rectangle intérieur n'a d'intérêt que s'il est NETTEMENT plus
        // petit que l'écran : sinon c'est le même bord redétecté, et le
        // garder ne ferait que rogner le plateau.
        let croppedArea = Double(clamped.width * clamped.height)
        guard inner.area < croppedArea * 0.9 else { return nil }

        return inner.translated(by: CGPoint(x: clamped.minX, y: clamped.minY))
    }

    /// Le plus grand rectangle plausible, converti dans l'espace pixels
    /// origine-haut-gauche.
    static func largestRectangle(
        in image: CGImage, configuration: Configuration = .default
    ) -> BoardQuad? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = configuration.minimumAspectRatio
        request.maximumAspectRatio = configuration.maximumAspectRatio
        request.minimumSize = configuration.minimumSize
        request.minimumConfidence = configuration.minimumConfidence
        request.quadratureTolerance = configuration.quadratureTolerance
        request.maximumObservations = configuration.maximumObservations

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let width = Double(image.width)
        let height = Double(image.height)

        let candidates = (request.results ?? []).compactMap { observation -> BoardQuad? in
            // Vision : coordonnées normalisées, origine en BAS à gauche.
            // Conversion vers pixels / origine en HAUT à gauche ici, à la
            // frontière du framework — le reste du scanner ignore Vision.
            func toPixels(_ point: CGPoint) -> CGPoint {
                CGPoint(x: Double(point.x) * width, y: (1 - Double(point.y)) * height)
            }

            return BoardQuad.ordering([
                toPixels(observation.topLeft), toPixels(observation.topRight),
                toPixels(observation.bottomRight), toPixels(observation.bottomLeft)
            ])
        }

        return candidates.max { $0.area < $1.area }
    }

    private static func boundingBox(of quad: BoardQuad) -> CGRect {
        let xs = quad.corners.map { Double($0.x) }
        let ys = quad.corners.map { Double($0.y) }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

extension BoardQuad {
    /// Décale les 4 coins (retour d'un recadrage vers l'image d'origine).
    func translated(by offset: CGPoint) -> BoardQuad {
        func move(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x + offset.x, y: point.y + offset.y)
        }
        return BoardQuad(
            topLeft: move(topLeft), topRight: move(topRight),
            bottomRight: move(bottomRight), bottomLeft: move(bottomLeft)
        )
    }
}
