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

    /// Déduit la source de l'image et rend la détection — HORS MainActor.
    ///
    /// `nonisolated async` pour que ce traitement (détection Vision, plusieurs
    /// secondes sur une photo) ne GÈLE PAS l'interface : le fil principal reste
    /// libre d'afficher et d'ANIMER l'indicateur d'activité (``isProcessing``).
    /// Auparavant tout tournait sur le MainActor, si bien qu'`isProcessing` ne
    /// s'affichait jamais — l'écran restait figé quelques secondes, à faire
    /// croire à un plantage.
    ///
    /// Plus AUCUNE question à l'utilisateur : le scanner ne traite que les
    /// échiquiers à l'écran, et la distinction capture / photo d'écran se lit
    /// dans l'image — si le motif de damier se reconnaît avec certitude, c'est
    /// une capture nette et axée ; sinon l'image a été photographiée, avec sa
    /// perspective, et il faut la stratégie de Vision. Les deux passent par YOLO.
    nonisolated private static func detectSourceAndBoard(
        in image: CGImage, forcedSource: ScanSource?
    ) async -> (source: ScanSource, detection: BoardDetector.Detection?) {
        if let forcedSource {
            return (forcedSource, BoardDetector.detectBoard(in: image, source: forcedSource))
        }
        let asScreenshot = BoardDetector.detectBoard(in: image, source: .screenshot)
        if asScreenshot?.isConfident == true {
            return (.screenshot, asScreenshot)
        }
        return (.screenPhoto, BoardDetector.detectBoard(in: image, source: .screenPhoto))
    }

    func load(_ uiImage: UIImage) async {
        errorMessage = nil

        guard let prepared = Self.prepare(uiImage) else {
            errorMessage = "Cette image n'a pas pu être lue."
            return
        }

        image = prepared
        isProcessing = true
        defer { isProcessing = false }

        let (resolvedSource, detection) = await Self.detectSourceAndBoard(in: prepared, forcedSource: forcedSource)
        source = resolvedSource

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

        // Cadrage AUTOMATIQUE quand le damier est reconnu avec certitude : on
        // enchaîne directement sur la reconnaissance (elle aussi hors fil
        // principal). Un échec de redressement (scan nil) ne laisse jamais
        // bloqué au choix de source : repli sur l'ajustement manuel des coins.
        if detection?.isConfident == true, let result = await runScan(image: prepared, quad: quad) {
            applyScan(result)
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
    func loadFromPasteboard() async {
        let pasteboard = UIPasteboard.general
        guard pasteboard.hasImages, let image = pasteboard.image else {
            errorMessage = LocalizationController.string("Le presse-papiers ne contient pas d'image.")
            return
        }
        await load(image)
    }

    func loadFromDropped(data: Data) async {
        guard let uiImage = UIImage(data: data) else {
            errorMessage = "Ce fichier n'est pas une image lisible."
            return
        }
        await load(uiImage)
    }

    func loadFromFile(_ result: Result<[URL], Error>) async {
        guard case let .success(urls) = result, let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) else {
            errorMessage = "Impossible de lire ce fichier."
            return
        }
        await load(uiImage)
    }

    // MARK: Cadrage

    /// Valide le cadrage : redresse puis découpe et classe — HORS fil
    /// principal (voir ``runScan(image:quad:)``), l'indicateur d'activité
    /// s'anime pendant les quelques secondes du traitement.
    func confirmCrop() async {
        guard let image else { return }
        errorMessage = nil

        guard quad.isUsable else {
            errorMessage = "Les coins se croisent : replacez-les dans l'ordre autour du plateau."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        guard let result = await runScan(image: image, quad: quad) else {
            errorMessage = "Ce cadrage n'a pas pu être redressé — vérifiez que les quatre coins entourent bien le plateau."
            return
        }
        applyScan(result)
    }

    /// Résultat d'une reconnaissance, prêt à appliquer sur le MainActor.
    /// `Sendable` : franchit la frontière depuis le calcul hors fil principal.
    private struct ScanResult: Sendable {
        let rectified: CGImage
        let rows: [[CGImage]]
        let scan: BoardScanReading
        let rotation: BoardReadingRotation
    }

    /// Lance le redressement + la découpe + le classement HORS MainActor,
    /// puis rend le résultat à appliquer. Ne touche aucun état observable
    /// pendant le calcul (tout est repassé sur le MainActor par ``applyScan``).
    ///
    /// Le classifieur par gabarits se CONSTRUIT sur le MainActor (son `init`
    /// rend des vignettes de thème) mais son `classify` est pur : on le
    /// fabrique ici, puis on le passe au calcul hors fil principal.
    private func runScan(image: CGImage, quad: BoardQuad) async -> ScanResult? {
        let templates = TemplateSquareClassifier(source: source)
        return await Self.rectifyAndScan(
            image: image, quad: quad, source: source, sideToMove: sideToMove, templates: templates
        )
    }

    private func applyScan(_ result: ScanResult) {
        rectified = result.rectified
        squareImages = result.rows
        reading = result.scan
        rotation = result.rotation
        stage = .rectified
    }

    /// Cœur de la reconnaissance, `nonisolated async` donc exécuté hors du
    /// MainActor. Le détecteur YOLO est recréé ICI plutôt que capturé : évite
    /// de faire traverser un type non-`Sendable` à la frontière d'isolation,
    /// et le chargement du modèle Core ML (compilé, mis en cache par l'OS) est
    /// négligeable devant la reconnaissance elle-même.
    ///
    /// YOLO d'abord quand un modèle est présent, RECROISÉ avec les gabarits sur
    /// les mêmes vignettes (2e avis gratuit sur les cases limites) ; en son
    /// absence, gabarits seuls — l'app se comporte à l'identique tant que le
    /// modèle n'est pas livré.
    nonisolated private static func rectifyAndScan(
        image: CGImage, quad: BoardQuad, source: ScanSource,
        sideToMove: Piece.Color, templates: TemplateSquareClassifier
    ) async -> ScanResult? {
        guard let rows = BoardRectifier.rectifyAndSlice(image, quad: quad),
              let rectified = BoardRectifier.rectify(image, quad: quad)
        else { return nil }

        let scan: BoardScanReading
        if let yolo = YOLOBoardClassifier(),
           let primary = BoardScanner.scan(board: rectified, source: source, boardClassifier: yolo) {
            let secondary = BoardScanner.scan(squares: rows, source: source, classifier: templates)
            scan = primary.crossChecked(against: secondary)
        } else {
            scan = BoardScanner.scan(squares: rows, source: source, classifier: templates)
        }
        return ScanResult(
            rectified: rectified, rows: rows, scan: scan,
            rotation: scan.suggestedRotation(sideToMove: sideToMove)
        )
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
