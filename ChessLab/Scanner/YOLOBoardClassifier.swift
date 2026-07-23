import ChessKit
import CoreGraphics
import Foundation
import Vision

/// Reconnaissance d'un plateau **entier** par détection d'objets (YOLO), par
/// opposition au classement case par case de ``SquareClassifying``.
///
/// Pourquoi un protocole séparé : un détecteur d'objets ne regarde pas 64
/// vignettes découpées, il regarde l'IMAGE REDRESSÉE du plateau d'un seul
/// tenant et renvoie des boîtes « telle pièce, ici ». Le point d'entrée n'est
/// donc plus la case mais le plateau — d'où cette abstraction parallèle, que
/// ``BoardScanner`` sait utiliser à la place du classifieur de cases quand un
/// modèle est disponible.
///
/// Le protocole rend `nil` quand il ne peut pas conclure (modèle absent du
/// bundle, image illisible) : c'est ce qui permet au pipeline de retomber, en
/// silence, sur le classifieur par gabarits — l'app fonctionne AVANT même que
/// le modèle soit entraîné et livré.
protocol BoardClassifying {
    /// - parameter board: image **redressée** du plateau (carrée, axée), telle
    ///   que produite par ``BoardRectifier/rectify(_:quad:side:)``.
    /// - returns: la grille lue `[ligne][colonne]`, ligne 0 en haut de
    ///   l'image, ou `nil` si le modèle n'a pas pu être appliqué.
    func classifyBoard(_ board: CGImage) -> [[SquareReading]]?
}

/// Classifieur de plateau par un modèle YOLO exporté en Core ML.
///
/// Le modèle n'est PAS référencé par une classe générée (qui n'existerait pas
/// tant qu'il n'est pas ajouté au projet) mais chargé par URL depuis le
/// bundle : ce fichier compile et l'app tourne même sans modèle, `classifyBoard`
/// renvoyant alors `nil`. Déposer le `.mlpackage` dans la cible suffit à
/// l'activer, sans toucher au code.
struct YOLOBoardClassifier: BoardClassifying {

    /// Nom de la ressource compilée attendue dans le bundle (Xcode compile un
    /// `.mlpackage`/`.mlmodel` en `.mlmodelc`).
    static let modelResourceName = "ChessPiecesYOLO"

    private let vnModel: VNCoreMLModel

    /// - returns: `nil` si le modèle n'est pas présent dans le bundle — le
    ///   pipeline retombe alors sur le classifieur par gabarits.
    init?(bundle: Bundle = .main) {
        guard let model = Self.loadModel(from: bundle),
              let vnModel = try? VNCoreMLModel(for: model)
        else { return nil }
        self.vnModel = vnModel
    }

    private static func loadModel(from bundle: Bundle) -> MLModel? {
        let candidates = [
            bundle.url(forResource: modelResourceName, withExtension: "mlmodelc"),
            bundle.url(forResource: modelResourceName, withExtension: "mlpackage")
        ].compactMap { $0 }
        guard let url = candidates.first else { return nil }
        return try? MLModel(contentsOf: url)
    }

    func classifyBoard(_ board: CGImage) -> [[SquareReading]]? {
        let request = VNCoreMLRequest(model: vnModel)
        // Le plateau redressé est déjà carré : on remplit sans rogner, pour ne
        // pas décaler les boîtes par rapport à la grille.
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(cgImage: board, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results as? [VNRecognizedObjectObservation] else { return nil }

        let detections = observations.compactMap { observation -> YOLODetectionMapper.Detection? in
            guard let top = observation.labels.first,
                  let piece = PieceLabelResolver.resolve(top.identifier)
            else { return nil }
            // Vision : boîte normalisée, origine en BAS à gauche. On repasse en
            // origine HAUT à gauche à la frontière du framework — le mapper,
            // pur et testé, ne raisonne qu'en coordonnées « ligne 0 en haut ».
            let box = observation.boundingBox
            let topLeftBox = CGRect(
                x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height
            )
            return YOLODetectionMapper.Detection(
                color: piece.color, kind: piece.kind,
                confidence: Double(top.confidence), boundingBox: topLeftBox
            )
        }

        return YOLODetectionMapper.grid(from: detections)
    }
}

/// Traduit une liste de détections YOLO en grille 8×8 de lectures.
///
/// Pur (aucun modèle, aucune image) : c'est ce qui rend la logique de mapping
/// — la seule partie subtile, et celle qui peut casser — testable au carré
/// près sans jamais charger un `.mlpackage`.
enum YOLODetectionMapper {

    /// Une pièce détectée sur le plateau redressé.
    struct Detection: Equatable {
        let color: Piece.Color
        let kind: Piece.Kind
        let confidence: Double
        /// Boîte normalisée 0...1, **origine en haut à gauche** (déjà
        /// convertie depuis Vision).
        let boundingBox: CGRect
    }

    /// Confiance attribuée à une case laissée VIDE (aucune détection dessus).
    /// L'absence n'est pas une preuve — une pièce ratée ressemble à une case
    /// vide — mais rester en dessous du seuil de signalement inonderait la
    /// confirmation. On la garde confiante sans être certaine.
    static let emptyConfidence = 0.9

    static func grid(from detections: [Detection]) -> [[SquareReading]] {
        var grid = [[SquareReading]](
            repeating: [SquareReading](repeating: .empty, count: 8), count: 8
        )
        // À confiance égale sur une même case, la première l'emporte ; on ne
        // remplace que par STRICTEMENT mieux.
        var confidence = [[Double]](repeating: [Double](repeating: 0, count: 8), count: 8)

        // Demi-case, en coordonnées normalisées (8 cases sur 0...1).
        let halfCell = 1.0 / 16

        for detection in detections {
            // La pièce « pose » près du BAS de sa boîte : on l'ancre sur le bas
            // (robuste aux glyphes hauts comme le roi, dont le sommet déborde
            // de la case) puis on remonte d'une demi-case. Sans cette remontée,
            // le bas de boîte tomberait pile sur la ligne de grille et
            // basculerait dans la case du dessous.
            let column = clampIndex(Int((detection.boundingBox.midX * 8).rounded(.down)))
            let baseY = detection.boundingBox.maxY - halfCell
            let row = clampIndex(Int((baseY * 8).rounded(.down)))

            guard detection.confidence > confidence[row][column] else { continue }
            confidence[row][column] = detection.confidence
            grid[row][column] = SquareReading(
                occupancy: .piece(color: detection.color, kind: detection.kind),
                confidence: detection.confidence
            )
        }

        // Les cases restées vides reçoivent leur confiance « d'absence ».
        for row in 0..<8 {
            for column in 0..<8 where grid[row][column].occupancy.isEmpty {
                grid[row][column] = SquareReading(occupancy: .empty, confidence: emptyConfidence)
            }
        }
        return grid
    }

    private static func clampIndex(_ value: Int) -> Int { min(max(value, 0), 7) }
}

/// Étiquettes du modèle : couleur + type. Les identifiants doivent
/// correspondre EXACTEMENT aux noms de classes du dataset d'entraînement
/// (`data.yaml`) — c'est le contrat entre le modèle et l'app.
enum PieceLabel: String, CaseIterable {
    case whitePawn = "white-pawn"
    case whiteKnight = "white-knight"
    case whiteBishop = "white-bishop"
    case whiteRook = "white-rook"
    case whiteQueen = "white-queen"
    case whiteKing = "white-king"
    case blackPawn = "black-pawn"
    case blackKnight = "black-knight"
    case blackBishop = "black-bishop"
    case blackRook = "black-rook"
    case blackQueen = "black-queen"
    case blackKing = "black-king"

    var color: Piece.Color {
        switch self {
        case .whitePawn, .whiteKnight, .whiteBishop, .whiteRook, .whiteQueen, .whiteKing: .white
        case .blackPawn, .blackKnight, .blackBishop, .blackRook, .blackQueen, .blackKing: .black
        }
    }

    var kind: Piece.Kind {
        switch self {
        case .whitePawn, .blackPawn: .pawn
        case .whiteKnight, .blackKnight: .knight
        case .whiteBishop, .blackBishop: .bishop
        case .whiteRook, .blackRook: .rook
        case .whiteQueen, .blackQueen: .queen
        case .whiteKing, .blackKing: .king
        }
    }

    /// L'ordre des classes du modèle (indices 0...11), tel qu'il doit figurer
    /// dans `data.yaml`. Exposé pour garder les deux côtés synchronisés — c'est
    /// le contrat de NOTRE dataset synthétique (piste A).
    static var trainingOrder: [String] { allCases.map(\.rawValue) }
}

/// Traduit l'identifiant de classe d'un modèle — quelle qu'en soit la
/// convention — en (couleur, type).
///
/// Un modèle tout fait (Hugging Face, Roboflow) nomme ses classes à sa façon :
/// « white-pawn », « White Pawn », « whitePawn », le code « wp », ou la lettre
/// FEN « P »/« p ». Plutôt que de coder en dur UN schéma et de casser au
/// prochain modèle déposé, on reconnaît les conventions courantes. Le mapping
/// reste ainsi correct quel que soit le `.mlpackage` mis dans le bundle —
/// y compris le nôtre (« white-pawn »).
enum PieceLabelResolver {

    static func resolve(_ identifier: String) -> (color: Piece.Color, kind: Piece.Kind)? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Lettre FEN unique : la CASSE porte la couleur (« P » blanc, « p »
        // noir), la lettre le type (P N B R Q K).
        if trimmed.count == 1, let letter = trimmed.first, let kind = fenKind(letter) {
            return (letter.isUppercase ? .white : .black, kind)
        }

        // Code à deux lettres « wp », « bk », « wb » : 1re = couleur, 2e = type.
        // « wb » est donc white-bishop, « bb » black-bishop — sans ambiguïté ici.
        if trimmed.count == 2 {
            let chars = Array(trimmed.lowercased())
            if chars[0] == "w" || chars[0] == "b", let kind = fenKind(chars[1]) {
                return (chars[0] == "w" ? .white : .black, kind)
            }
        }

        // Schéma en mots : « white-pawn », « White Pawn », « pawn_white »,
        // « whitePawn »… On découpe sur les non-lettres ET les bosses de casse,
        // puis on cherche un jeton de couleur et un de type.
        let tokens = tokenize(trimmed)
        guard let color = color(in: tokens), let kind = kind(in: tokens) else { return nil }
        return (color, kind)
    }

    private static func fenKind(_ letter: Character) -> Piece.Kind? {
        switch Character(letter.lowercased()) {
        case "p": return .pawn
        case "n": return .knight
        case "b": return .bishop
        case "r": return .rook
        case "q": return .queen
        case "k": return .king
        default: return nil
        }
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for character in text {
            if character.isLetter {
                if let last = current.last, last.isLowercase, character.isUppercase {
                    tokens.append(current.lowercased()); current = ""
                }
                current.append(character)
            } else if !current.isEmpty {
                tokens.append(current.lowercased()); current = ""
            }
        }
        if !current.isEmpty { tokens.append(current.lowercased()) }
        return tokens
    }

    private static func color(in tokens: [String]) -> Piece.Color? {
        for token in tokens {
            if token == "white" || token == "w" { return .white }
            if token == "black" || token == "b" { return .black }
        }
        return nil
    }

    private static func kind(in tokens: [String]) -> Piece.Kind? {
        for token in tokens {
            switch token {
            case "pawn", "p": return .pawn
            case "knight", "n": return .knight
            // « b » seul est déjà pris pour la couleur (noir) ; le fou en toutes
            // lettres seulement, pour ne pas confondre.
            case "bishop": return .bishop
            case "rook", "r": return .rook
            case "queen", "q": return .queen
            case "king", "k": return .king
            default: continue
            }
        }
        return nil
    }
}
