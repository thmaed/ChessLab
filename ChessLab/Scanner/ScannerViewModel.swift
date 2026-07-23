import ChessKit
import CoreGraphics
import Observation
import SwiftUI
import UIKit

/// État du scanner d'échiquier : source choisie, image chargée, cadrage,
/// puis découpe en 64 vignettes.
///
/// Sans moteur (aucun effet de bord Stockfish). La classification des cases
/// est branchée au Lot 1.C, l'écran de confirmation au Lot 1.D.
@Observable
@MainActor
final class ScannerViewModel {

    enum Stage: Equatable {
        /// Choix du type de source + entrées d'image.
        case chooseSource
        /// Ajustement des 4 coins sur l'image.
        case adjustCrop
        /// Cadrage validé : plateau redressé et découpé.
        case rectified
    }

    private(set) var stage: Stage = .chooseSource
    var source: ScanSource = .screenshot

    /// Image de travail : orientation normalisée et taille bornée.
    private(set) var image: CGImage?
    /// Coins du plateau, en pixels de `image`, origine en haut à gauche.
    var quad = BoardQuad.covering(width: 1, height: 1)
    /// Vrai si les coins viennent de la détection automatique (et non d'un
    /// repli) : sert à dire à l'utilisateur ce qu'il regarde.
    private(set) var wasDetectedAutomatically = false

    private(set) var rectified: CGImage?
    /// 64 vignettes, `[ligne][colonne]`, ligne 0 en haut. Entrée du
    /// classifieur.
    private(set) var squareImages: [[CGImage]]?

    /// Lecture des 64 cases, et l'orientation retenue.
    private(set) var reading: BoardScanReading?
    var rotation = BoardReadingRotation.none
    /// Le trait n'est JAMAIS déductible d'une image : il est confirmé par
    /// l'utilisateur, blancs par défaut.
    var sideToMove = Piece.Color.white

    private(set) var errorMessage: String?
    private(set) var isProcessing = false

    /// Au-delà, on sous-échantillonne : une photo de 12 Mpx ne rend pas la
    /// détection meilleure, seulement plus lente (et le redressement final
    /// ne fait que 800 px de côté).
    private static let maximumWorkingSide = 1600.0

    /// Source imposée — porte dérobée des tests UI, qui doivent pouvoir viser
    /// un chemin précis sans dépendre de la déduction.
    var forcedSource: ScanSource?

    // MARK: Chargement

    /// Fixe ``source`` d'après l'image, et rend la détection faite au passage.
    ///
    /// Plus AUCUNE question à l'utilisateur : le scanner ne traite que les
    /// échiquiers à l'écran, et la distinction capture / photo d'écran se lit
    /// dans l'image — si le motif de damier se reconnaît avec certitude, c'est
    /// qu'il est net et aligné sur les axes (une capture) ; sinon l'image a été
    /// photographiée, avec sa perspective et son moiré, et il faut la stratégie
    /// de Vision. Les deux sont des « diagrammes numériques », donc les deux
    /// passent par le modèle YOLO.
    private func resolveSourceAndDetect(in prepared: CGImage) -> BoardDetector.Detection? {
        if let forcedSource {
            source = forcedSource
            return BoardDetector.detectBoard(in: prepared, source: forcedSource)
        }

        let asScreenshot = BoardDetector.detectBoard(in: prepared, source: .screenshot)
        if asScreenshot?.isConfident == true {
            source = .screenshot
            return asScreenshot
        }
        source = .screenPhoto
        return BoardDetector.detectBoard(in: prepared, source: .screenPhoto)
    }

    func load(_ uiImage: UIImage) {
        errorMessage = nil

        guard let prepared = Self.prepare(uiImage) else {
            errorMessage = "Cette image n'a pas pu être lue."
            return
        }

        image = prepared

        let detection = resolveSourceAndDetect(in: prepared)
        if let detection {
            quad = detection.quad
            wasDetectedAutomatically = true
        } else {
            // Aucun plateau trouvé : cadre à ~80 % de l'image comme point de
            // départ du cadrage manuel, plutôt qu'un message d'erreur.
            let inset = min(Double(prepared.width), Double(prepared.height)) * 0.1
            quad = BoardQuad.covering(width: Double(prepared.width), height: Double(prepared.height), inset: inset)
            wasDetectedAutomatically = false
        }

        // Cadrage AUTOMATIQUE : quand le motif de damier a été reconnu avec
        // certitude, on enchaîne directement sur la reconnaissance — plus
        // besoin d'ajuster les coins à la main. Le bouton « Recadrer » de
        // l'écran de confirmation reste là pour les cas où l'auto se trompe.
        if detection?.isConfident == true {
            confirmCrop()
            // 🐛 Un échec du cadrage AUTOMATIQUE laissait l'écran sur le choix
            // de source, avec un message d'erreur et une image chargée mais
            // invisible : aucune porte de sortie, alors que l'ajustement
            // manuel existe précisément pour ces cas-là.
            if stage != .rectified {
                stage = .adjustCrop
            }
        } else {
            stage = .adjustCrop
        }
    }

    /// Colle une image du presse-papiers.
    ///
    /// Lecture DIRECTE d'`UIPasteboard`, et non `PasteButton` : c'est le prix
    /// assumé pour que l'entrée « Coller » ait exactement le même look que
    /// « Photothèque » et « Appareil photo » (pastille colorée + titre +
    /// chevron). Le libellé d'un `PasteButton` est rendu par le SYSTÈME et ne
    /// peut pas être remplacé — impossible d'y mettre un `ScannerEntryLabel`.
    /// En contrepartie, iOS peut afficher sa confirmation de collage ; elle
    /// arrive juste après un tap sur un bouton nommé « Coller », donc dans le
    /// seul contexte où elle se comprend.
    ///
    /// `hasImages` est consulté d'ABORD : ce contrôle de métadonnée ne
    /// déclenche aucune invite, et permet de refuser proprement un
    /// presse-papiers sans image sans jamais lire son contenu.
    func loadFromPasteboard() {
        let pasteboard = UIPasteboard.general
        guard pasteboard.hasImages, let image = pasteboard.image else {
            errorMessage = LocalizationController.string("Le presse-papiers ne contient pas d'image.")
            return
        }
        load(image)
    }

    func loadFromDropped(data: Data) {
        guard let uiImage = UIImage(data: data) else {
            errorMessage = "Ce fichier n'est pas une image lisible."
            return
        }
        load(uiImage)
    }

    func loadFromFile(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) else {
            errorMessage = "Impossible de lire ce fichier."
            return
        }
        load(uiImage)
    }

    // MARK: Cadrage

    /// Valide le cadrage : redresse puis découpe.
    func confirmCrop() {
        guard let image else { return }
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        guard quad.isUsable else {
            errorMessage = "Les coins se croisent : replacez-les dans l'ordre autour du plateau."
            return
        }

        guard let rows = BoardRectifier.rectifyAndSlice(image, quad: quad) else {
            errorMessage = "Ce cadrage n'a pas pu être redressé — vérifiez que les quatre coins entourent bien le plateau."
            return
        }

        let rectifiedImage = BoardRectifier.rectify(image, quad: quad)
        rectified = rectifiedImage
        squareImages = rows

        // YOLO d'abord quand un modèle est présent ET pertinent pour la source :
        // il lit le plateau redressé d'un seul tenant. En son absence (ou pour
        // une source qu'il ne couvre pas), on retombe sur le classifieur par
        // cases — l'app se comporte à l'identique tant que le modèle n'est pas
        // livré.
        let scan = boardScan(rectified: rectifiedImage, squares: rows)
            ?? BoardScanner.scan(squares: rows, source: source, classifier: classifier(for: source))
        reading = scan
        rotation = scan.suggestedRotation(sideToMove: sideToMove)
        stage = .rectified
    }

    /// Le détecteur d'objets, chargé une seule fois. `nil` tant que le modèle
    /// n'est pas dans le bundle. `@ObservationIgnored` : ce n'est pas un état
    /// d'UI observable, et `@Observable` interdit `lazy` sur ses propriétés
    /// suivies.
    @ObservationIgnored
    private lazy var yoloClassifier: BoardClassifying? = YOLOBoardClassifier()

    /// Lecture par YOLO si un modèle couvre cette source, sinon `nil`.
    ///
    /// La lecture YOLO est RECROISÉE avec les gabarits sur les mêmes vignettes :
    /// deuxième avis gratuit sur les cases limites, sans réentraîner le modèle.
    /// Les gabarits ne votent que sur ce dont ils sont sûrs (voir
    /// ``BoardScanReading/crossChecked(against:)``).
    private func boardScan(rectified: CGImage?, squares: [[CGImage]]) -> BoardScanReading? {
        guard let rectified, let yoloClassifier,
              let primary = BoardScanner.scan(board: rectified, source: source, boardClassifier: yoloClassifier)
        else { return nil }

        let secondary = BoardScanner.scan(squares: squares, source: source, classifier: classifier(for: source))
        return primary.crossChecked(against: secondary)
    }

    /// Un classifieur par source (le protocole ``SquareClassifying`` est là
    /// pour ça) : les gabarits ne savent lire que des glyphes 2D, et la
    /// vision classique du plateau réel ne saurait pas lire un diagramme.
    private func classifier(for source: ScanSource) -> SquareClassifying {
        switch source {
        case .screenshot, .screenPhoto: TemplateSquareClassifier(source: source)
        }
    }

    /// FEN de la lecture courante, orientation et trait compris.
    var readFEN: String? {
        reading?.fen(rotation: rotation, sideToMove: sideToMove)
    }

    /// Bascule 0°/180° — les seules orientations plausibles d'un diagramme
    /// numérique. (Le quart de tour `rotateReading()` n'existait que pour la
    /// photo zénithale de plateau réel, retirée le 20/07/2026.)
    func flipReading() {
        rotation = rotation == .none ? .half : .none
    }

    func backToCrop() {
        // L'erreur qui a motivé le retour n'a plus lieu d'être affichée
        // au-dessus de l'écran où l'on vient la corriger.
        errorMessage = nil
        stage = .adjustCrop
    }

    func backToSource() {
        image = nil
        rectified = nil
        squareImages = nil
        errorMessage = nil
        // 🐛 `reading` et `rotation` SURVIVAIENT au retour en arrière : tant
        // qu'une nouvelle image n'était pas validée, `readFEN` rendait encore
        // la position du scan PRÉCÉDENT. Un appelant qui la lisait à ce
        // moment-là repartait sur un échiquier qui n'était plus à l'écran.
        reading = nil
        rotation = .none
        wasDetectedAutomatically = false
        quad = BoardQuad.covering(width: 1, height: 1)
        stage = .chooseSource
    }

    // MARK: Interne

    /// Normalise l'orientation puis borne la taille.
    ///
    /// ⚠️ L'orientation d'abord : une photo prise à la verticale porte son
    /// orientation dans les MÉTADONNÉES (`UIImage.imageOrientation`), et
    /// `cgImage` rend les pixels BRUTS, sans elle. Sauter cette étape ferait
    /// travailler tout le pipeline sur une image couchée, coins compris.
    static func prepare(_ uiImage: UIImage) -> CGImage? {
        let upright = uiImage.imageOrientation == .up ? uiImage : redraw(uiImage)
        guard let cgImage = upright.cgImage else { return nil }

        let longestSide = Double(max(cgImage.width, cgImage.height))
        guard longestSide > maximumWorkingSide else { return cgImage }

        let factor = maximumWorkingSide / longestSide
        return scale(cgImage, by: factor)
    }

    /// Redessine à l'endroit, en PIXELS.
    ///
    /// ⚠️ `UIImage.size` est en POINTS : pour une image d'échelle 2 ou 3, la
    /// redessiner à cette taille avec `format.scale = 1` la divise par 2 ou 3
    /// SANS RIEN DIRE — le scanner travaillait alors sur une image deux fois
    /// moins définie que celle fournie, uniquement pour les photos prises en
    /// orientation non standard (les seules à passer ici).
    private static func redraw(_ uiImage: UIImage) -> UIImage {
        let pixelSize = CGSize(
            width: uiImage.size.width * uiImage.scale,
            height: uiImage.size.height * uiImage.scale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: pixelSize, format: format).image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }

    private static func scale(_ image: CGImage, by factor: Double) -> CGImage? {
        let width = Int((Double(image.width) * factor).rounded())
        let height = Int((Double(image.height) * factor).rounded())
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return image }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}
