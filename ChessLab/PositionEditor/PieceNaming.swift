import ChessKit

/// Nom complet d'une pièce, LOCALISÉ selon la langue active de l'app, pour les
/// libellés d'accessibilité de l'éditeur et de sa palette (« dame blanche » /
/// « white queen »).
///
/// (Le nom `french…` est historique : l'app était monolingue au départ.)
///
/// Passe par ``LocalizationController/string(_:)`` et non `String(localized:)` :
/// un libellé d'accessibilité doit suivre le choix de langue DANS l'app, pas
/// celui de l'OS.
enum PieceNaming {
    static func french(_ kind: Piece.Kind, color: Piece.Color) -> String {
        LocalizationController.string(frenchKey(kind, color: color))
    }

    static func french(_ piece: Piece) -> String {
        french(piece.kind, color: piece.color)
    }

    /// Texte source (clé du catalogue).
    private static func frenchKey(_ kind: Piece.Kind, color: Piece.Color) -> String {
        switch (kind, color) {
        case (.king, .white): "roi blanc"
        case (.king, .black): "roi noir"
        case (.queen, .white): "dame blanche"
        case (.queen, .black): "dame noire"
        case (.rook, .white): "tour blanche"
        case (.rook, .black): "tour noire"
        case (.bishop, .white): "fou blanc"
        case (.bishop, .black): "fou noir"
        case (.knight, .white): "cavalier blanc"
        case (.knight, .black): "cavalier noir"
        case (.pawn, .white): "pion blanc"
        case (.pawn, .black): "pion noir"
        }
    }

    /// Le seul type, sans couleur — clé du catalogue (la palette de complétion
    /// du scanner la passe à un `Text`, qui la localise). La palette est déjà
    /// filtrée à une couleur connue : répéter la couleur n'apporterait rien.
    static func frenchKind(_ kind: Piece.Kind) -> String {
        switch kind {
        case .king: "Roi"
        case .queen: "Dame"
        case .rook: "Tour"
        case .bishop: "Fou"
        case .knight: "Cavalier"
        case .pawn: "Pion"
        }
    }
}
