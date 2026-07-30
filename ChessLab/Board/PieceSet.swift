import Foundation

/// Jeu de pièces sélectionnable. L'``id`` sert aussi de préfixe d'asset :
/// ``PieceGlyphView`` charge `Image("<id>_wK")`, `"<id>_bQ"`, etc.
///
/// Sélection volontairement COURTE et curée — un classique, un moderne, un
/// contrasté : trois styles distincts (lisibilité / look), tous sous licence
/// libre et attribués dans ``LicensesView``. Les jeux propriétaires
/// (chess.com) sont exclus. Chaque jeu doit rester lisible sur chacun des
/// thèmes de plateau (voir ``BoardTheme``).
struct PieceSet: Identifiable, Equatable {
    /// Identifiant persistant ET préfixe d'asset.
    let id: String
    let label: String

    var assetPrefix: String { id }

    /// Le jeu d'origine (Colin M.L. Burnett, GPLv2+), déjà embarqué sous
    /// les noms `piece_*` — d'où un id « piece » qui diffère du libellé.
    static let classic = PieceSet(id: "piece", label: "Classique")
    /// Jeu épuré et moderne (Lichess « chessnut », Apache 2.0). A remplacé
    /// « maestro », dont la licence CC BY-NC-SA (non commerciale) était
    /// incompatible avec la GPLv3 de l'app — voir ``LicensesView``.
    static let chessnut = PieceSet(id: "chessnut", label: "Moderne")
    /// Jeu au trait marqué, plus contrasté (Lichess « merida », GPLv2+).
    static let merida = PieceSet(id: "merida", label: "Contrasté")

    static let all: [PieceSet] = [.classic, .chessnut, .merida]
}
