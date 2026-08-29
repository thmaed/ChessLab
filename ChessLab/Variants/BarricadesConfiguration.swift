import ChessKit
import Foundation

/// Barricades : les échecs ordinaires, avec deux cases MURÉES.
///
/// ## Le problème, et pourquoi ce fichier existe
///
/// Fairy-Stockfish, dans la version vendorisée ici (14), n'a aucune notion de
/// case-mur : ni `wallingRule`, ni `*` dans son parseur de FEN, rien dans
/// `position.h`. Il a en revanche tout ce qu'il faut pour en FABRIQUER une, et
/// c'est ce que fait la définition écrite ci-dessous :
///
/// - le type de pièce `immobile`, dont la notation Betza est vide — elle ne
///   peut donc jouer aucun coup ;
/// - `mobilityRegion<Couleur><Pièce>`, qui restreint les cases d'ARRIVÉE d'un
///   type de pièce, et interdit donc d'y capturer quoi que ce soit ;
/// - `pieceValueMg`/`pieceValueEg`, pour que les murs ne pèsent rien dans
///   l'évaluation.
///
/// Les deux murs sont BLANCS. Les Blancs ne peuvent donc pas les prendre — on
/// ne capture pas ses propres pièces — et il suffit de restreindre les six
/// types de pièces NOIRES pour que personne ne le puisse.
///
/// Le blocage des pièces glissantes ne vient PAS de `mobilityRegion`, qui
/// n'est qu'un masque d'arrivée appliqué après coup (`position.h`,
/// `board_bb(c, pt)`), mais de l'occupation : un mur est une pièce, donc il
/// arrête une ligne comme n'importe quelle autre — et un cavalier lui saute
/// par-dessus, comme il saute par-dessus n'importe quoi.
///
/// Chacun de ces points est vérifié contre le moteur RÉEL par
/// `BarricadesEngineSpikeTests`, écrite avant la moindre ligne d'interface.
///
/// ## Une seule source de vérité
///
/// ``wallSquares`` commande tout : la FEN de départ, les régions de mobilité,
/// et l'affichage du plateau. Déplacer un mur, c'est changer cette ligne.
enum BarricadesConfiguration {

    static let variantID = "barricades"

    /// Les cases murées. Le nom de la variante vient d'elles.
    static let wallSquares: [Square] = [Square("d4"), Square("e5")]

    /// Lettre du mur dans la FEN du moteur — le type `immobile`, en MAJUSCULE
    /// donc blanc. Elle n'a rien de standard : ChessKit ne la connaît pas, et
    /// c'est ``BarricadesFEN`` qui l'en protège.
    static let wallLetter: Character = "W"

    /// Position de départ : les échecs ordinaires, plus les deux murs.
    ///
    /// Écrite en toutes lettres plutôt que dérivée de ``wallSquares`` — une
    /// FEN se relit, une construction ne se relit pas. Un test vérifie que les
    /// deux disent bien la même chose.
    static let startFEN = "rnbqkbnr/pppppppp/8/4W3/3W4/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    // MARK: La définition envoyée au moteur

    /// Les six types de pièces qu'il faut brider — ceux des NOIRS.
    private static let restrictedPieceNames = ["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]

    /// Toutes les cases SAUF les murs, dans la syntaxe des bitboards du
    /// moteur : `*n` pour une rangée entière, sinon case par case.
    static var openSquaresBitboard: String {
        let walls = Set(wallSquares)
        var tokens: [String] = []
        for rank in 1...8 {
            let wallsOnRank = walls.filter { $0.rank.value == rank }
            if wallsOnRank.isEmpty {
                tokens.append("*\(rank)")
            } else {
                for file in "abcdefgh" {
                    let square = Square("\(file)\(rank)")
                    if !walls.contains(square) { tokens.append(square.notation) }
                }
            }
        }
        return tokens.joined(separator: " ")
    }

    /// Le fichier de définition, tel que `VariantPath` l'attend.
    static var configurationText: String {
        let open = openSquaresBitboard
        var lines = [
            "# Barricades — engendré par BarricadesConfiguration, ne pas éditer à la main.",
            "[\(variantID):chess]",
            "immobile = \(String(wallLetter).lowercased())",
            "startFen = \(startFEN)",
            "pieceValueMg = \(String(wallLetter).lowercased()):0",
            "pieceValueEg = \(String(wallLetter).lowercased()):0",
        ]
        for piece in restrictedPieceNames {
            lines.append("mobilityRegionBlack\(piece) = \(open)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Écrit la définition sur le disque et rend son chemin.
    ///
    /// Dans les Caches, et réécrite à chaque démarrage plutôt que conservée :
    /// le fichier est engendré, minuscule, et une version périmée laissée là
    /// par une mise à jour serait un piège silencieux — le moteur chargerait
    /// d'anciennes règles sans que rien ne le dise.
    static func writeConfigurationFile() -> String? {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = directory.appendingPathComponent("\(variantID).ini")
        do {
            try configurationText.write(to: url, atomically: true, encoding: .utf8)
            return url.path
        } catch {
            return nil
        }
    }
}
