import CoreGraphics
import CoreImage
import Foundation

/// Redressement d'un plateau photographié et découpe en 64 vignettes.
///
/// Pur (image entrante → images sortantes), sans UI ni état : c'est ce qui
/// le rend testable sur des images synthétiques, où l'on peut exiger la
/// découpe « au pixel près ».
enum BoardRectifier {

    /// Côté de l'image redressée. ~800 px suffisent pour reconnaître un
    /// glyphe (100 px par case) et **atténuent le moiré** d'une photo
    /// d'écran par sous-échantillonnage — inutile de garder du 4K.
    static let normalizedSide = 800

    /// `CIContext` est coûteux à créer et documenté thread-safe : une seule
    /// instance partagée. `CIContext` est `Sendable` et documenté thread-safe.
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Redresse le quadrilatère en une image carrée `normalizedSide`.
    ///
    /// - parameter quad: coins **en pixels, origine en haut à gauche**
    ///   (convention ``BoardQuad``). La conversion vers l'origine en bas à
    ///   gauche de CoreImage est faite ici, à la frontière.
    static func rectify(_ image: CGImage, quad: BoardQuad, side: Int = normalizedSide) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        let height = Double(image.height)

        func flipped(_ point: CGPoint) -> CIVector {
            CIVector(x: point.x, y: CGFloat(height - Double(point.y)))
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(flipped(quad.topLeft), forKey: "inputTopLeft")
        filter.setValue(flipped(quad.topRight), forKey: "inputTopRight")
        filter.setValue(flipped(quad.bottomRight), forKey: "inputBottomRight")
        filter.setValue(flipped(quad.bottomLeft), forKey: "inputBottomLeft")

        guard let output = filter.outputImage,
              !output.extent.isInfinite, !output.extent.isEmpty,
              let corrected = context.createCGImage(output, from: output.extent)
        else { return nil }

        return resize(corrected, to: side)
    }

    /// Redimensionne en carré `side` × `side`. Le redressement rend une
    /// image aux proportions du quadrilatère d'origine (rarement carrées) :
    /// c'est cette étape qui rétablit un plateau carré, donc des cases
    /// carrées.
    static func resize(_ image: CGImage, to side: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return context.makeImage()
    }

    /// Découpe une image redressée en 8×8 vignettes, **ligne 0 en haut**,
    /// **colonne 0 à gauche**.
    ///
    /// Aucune notion de case d'échiquier ici : une photo zénithale n'a pas
    /// d'orientation de référence, et même une capture peut être vue du côté
    /// des Noirs. La correspondance grille → `Square` est décidée plus tard,
    /// avec l'orientation (Lot 1.C).
    ///
    /// La découpe suit la grille **recalée sur les lignes du damier**
    /// (``BoardGridFinder``) et non huit parts égales : le cadrage, auto ou
    /// manuel, n'est jamais parfait au pixel près, et une grille décalée
    /// d'un dixième de case suffit à faire échouer la reconnaissance.
    static func slice(_ rectified: CGImage) -> [[CGImage]]? {
        slice(rectified, grid: BoardGridFinder.grid(in: rectified))
    }

    /// Marge rognée sur chaque bord de vignette, en fraction du côté de la
    /// case. Assez pour absorber l'interpolation du redressement et un
    /// résidu de recalage, trop peu pour entamer un glyphe (les gabarits sont
    /// rendus à trois échelles, ce qui absorbe le reste).
    static let edgeInset = 0.02

    static func slice(_ rectified: CGImage, grid: BoardGridFinder.Grid) -> [[CGImage]]? {
        guard grid.columns.count == 9, grid.rows.count == 9 else { return nil }

        var rows: [[CGImage]] = []
        rows.reserveCapacity(8)

        for row in 0..<8 {
            var columns: [CGImage] = []
            columns.reserveCapacity(8)

            for column in 0..<8 {
                let width = grid.columns[column + 1] - grid.columns[column]
                let height = grid.rows[row + 1] - grid.rows[row]
                // Rognage d'un cheveu à l'intérieur des lignes : sans lui,
                // chaque vignette emporte un liseré de la case VOISINE, de
                // couleur opposée. Ce liseré suffit à faire passer une case
                // vide pour contrastée — elle partait alors en corrélation, ne
                // ressemblait à aucune pièce, et se retrouvait signalée
                // « incertaine » (33 cases sur une capture pourtant parfaite).
                let rect = CGRect(
                    x: grid.columns[column] + width * edgeInset,
                    y: grid.rows[row] + height * edgeInset,
                    width: width * (1 - 2 * edgeInset),
                    height: height * (1 - 2 * edgeInset)
                ).integral
                guard rect.width > 0, rect.height > 0,
                      let cropped = rectified.cropping(to: rect) else { return nil }
                columns.append(cropped)
            }
            rows.append(columns)
        }

        return rows
    }

    /// Chaîne complète : image d'origine + 4 coins → 64 vignettes.
    static func rectifyAndSlice(_ image: CGImage, quad: BoardQuad, side: Int = normalizedSide) -> [[CGImage]]? {
        guard let rectified = rectify(image, quad: quad, side: side) else { return nil }
        return slice(rectified)
    }
}
