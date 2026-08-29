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

    /// La variante SŒUR, où les murs se déplacent à chaque demi-coup.
    ///
    /// Elle ne peut pas se protéger comme la fixe : `mobilityRegion` est une
    /// propriété STATIQUE de la variante, elle ne suit pas des murs qui
    /// bougent. Les murs y restent donc capturables aux yeux du moteur, et
    /// c'est la vue-modèle qui retire ces coups de la liste — une soustraction
    /// d'une ligne, pas une réimplémentation des échecs. Voir
    /// ``EngineLegalityVariant/removingWallCaptures(from:in:)``.
    static let randomVariantID = "randombarricades"

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

    /// Position de départ de la variante ALÉATOIRE : les échecs ordinaires.
    /// Ses deux murs sont posés au premier coup, au hasard — il n'y a donc
    /// rien à écrire ici.
    static let randomStartFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    /// Rangées où un mur mobile a le droit de se poser. Ni la première ni la
    /// dernière : un mur surgi sur la rangée de départ enfermerait une tour
    /// dans son coin sans que personne y soit pour rien.
    static let randomWallRanks = 2...7

    /// Trois murs en tout.
    static let wallCount = 3

    /// Combien se REDÉPLOIENT à chaque demi-coup — deux sur les trois, tirés
    /// au sort. Celui qui reste n'est pas le même d'un coup à l'autre : c'est
    /// ce tirage-là, et non un mur figé pour la partie, qui fait la variante.
    /// Un mur immobile donnerait un point d'appui permanent ; ici, le seul
    /// point d'appui dure un coup, et on ne sait pas lequel ce sera.

    /// Le fichier de définition, tel que `VariantPath` l'attend — les DEUX
    /// variantes dans un seul fichier, qu'un seul chargement suffit à
    /// enseigner au moteur.
    static var configurationText: String {
        let wall = String(wallLetter).lowercased()
        var lines = [
            "# Barricades — engendré par BarricadesConfiguration, ne pas éditer à la main.",
            "[\(variantID):chess]",
            "immobile = \(wall)",
            "startFen = \(startFEN)",
            "pieceValueMg = \(wall):0",
            "pieceValueEg = \(wall):0",
        ]
        let open = openSquaresBitboard
        for piece in restrictedPieceNames {
            lines.append("mobilityRegionBlack\(piece) = \(open)")
        }
        // La variante ALÉATOIRE n'a PAS de `mobilityRegion` : ses murs se
        // déplacent, aucune région figée ne pourrait les suivre.
        lines += [
            "",
            "[\(randomVariantID):chess]",
            "immobile = \(wall)",
            "startFen = \(randomStartFEN)",
            "pieceValueMg = \(wall):0",
            "pieceValueEg = \(wall):0",
        ]
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: Murs mobiles

    /// Redéploie DEUX des trois murs, tirés au sort ; le troisième reste où
    /// il est.
    ///
    /// Celui qui reste change à chaque appel — c'est un tirage, pas un mur
    /// désigné pour la partie. Les deux qui bougent vont sur des cases vides
    /// des rangées 2 à 7, et jamais sur l'une des trois cases murées
    /// d'avant : sans cette exclusion, un « mur qui bouge » pourrait retomber
    /// sur sa propre case et ne pas bouger du tout.
    ///
    /// Quand la position n'a pas encore ses trois murs — au tout premier
    /// appel — ils sont simplement tous posés.
    ///
    /// Rend `nil` si la position est illisible ou s'il n'y a pas assez de
    /// cases libres : la partie continue alors avec les murs qu'elle avait,
    /// plutôt que de s'arrêter sur un détail.
    static func relocatingWalls(
        in fen: String, using generator: inout some RandomNumberGenerator
    ) -> String? {
        let cleared = BarricadesFEN.forChessKit(fen)
        guard let position = Position(fen: cleared) else { return nil }
        let current = BarricadesFEN.wallSquares(in: fen)

        // Le mur épargné ce coup-ci, s'il y en a trois à départager.
        let staying: Set<Square> = current.count >= wallCount
            ? Set([current.randomElement(using: &generator)].compactMap { $0 })
            : []
        let moving = wallCount - staying.count

        let occupied = Set(position.pieces.map(\.square))
        let forbidden = occupied.union(current)
        let candidates = DuckChessRules.allSquares.filter {
            randomWallRanks.contains($0.rank.value) && !forbidden.contains($0)
        }
        guard candidates.count >= moving else { return nil }

        var chosen = staying
        while chosen.count < wallCount {
            guard let square = candidates.randomElement(using: &generator) else { return nil }
            chosen.insert(square)
        }
        return inserting(walls: chosen, into: cleared)
    }

    /// La position d'ouverture : les trois murs posés au hasard.
    static func openingPosition(using generator: inout some RandomNumberGenerator) -> String {
        relocatingWalls(in: randomStartFEN, using: &generator) ?? randomStartFEN
    }

    /// Réécrit une FEN SANS mur en y plaçant ceux qu'on lui donne.
    static func inserting(walls: Set<Square>, into fen: String) -> String? {
        var fields = fen.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard let placement = fields.first else { return nil }
        let files = Array("abcdefgh")
        var ranks: [String] = []
        for (index, rankText) in placement.split(separator: "/", omittingEmptySubsequences: false).enumerated() {
            let rank = 8 - index
            var slots: [Character] = []
            for character in rankText {
                if let empty = character.wholeNumberValue, (1...8).contains(empty) {
                    slots.append(contentsOf: Array(repeating: ".", count: empty))
                } else {
                    slots.append(character)
                }
            }
            for (file, slot) in slots.enumerated() where slot == "." {
                guard file < files.count, walls.contains(Square("\(files[file])\(rank)")) else { continue }
                slots[file] = wallLetter
            }
            var line = ""
            var empty = 0
            for slot in slots {
                if slot == "." {
                    empty += 1
                } else {
                    if empty > 0 { line += "\(empty)"; empty = 0 }
                    line.append(slot)
                }
            }
            if empty > 0 { line += "\(empty)" }
            ranks.append(line)
        }
        fields[0] = ranks.joined(separator: "/")
        return fields.joined(separator: " ")
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
