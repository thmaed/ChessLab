import ChessKit

/// Traduction d'une FEN de Barricades vers une FEN que ChessKit lit
/// CORRECTEMENT.
///
/// La FEN du moteur porte la lettre du mur
/// (``BarricadesConfiguration/wallLetter``), que ChessKit ne connaît pas.
///
/// ## Ce que ChessKit en fait AUJOURD'HUI — mesuré, pas supposé
///
/// Version 0.17.0, sondée avant d'écrire ce fichier : un caractère inconnu au
/// MILIEU d'une rangée fait avancer d'une colonne sans rien poser. Le mur
/// devient donc une case vide, et le reste de la rangée reste à sa place.
/// `rnbqkbnr/pppppppp/8/3pW1n1/…` se relit `…/3p2n1/…` : le pion d5 et le
/// cavalier g5 sont exactement où ils doivent être.
///
/// Autrement dit, ce filtre n'est pas ce qui sauve l'affichage aujourd'hui.
/// Il existe pour deux raisons quand même :
///
/// - **Ne pas dépendre d'une tolérance non écrite.** Rien, dans ChessKit, ne
///   promet ce comportement. Le Crazyhouse a déjà montré ce que coûte le pari
///   inverse : sa réserve, elle, arrive APRÈS la 8e colonne de la dernière
///   rangée, `Square.File` plafonne, et les caractères en trop s'empilent sur
///   h1 en masquant la tour (voir ``CrazyhouseFEN``).
/// - **Un seul chemin pour toutes les variantes.** ``VariantFEN`` compose les
///   deux nettoyages, si bien qu'aucun écran n'a à savoir laquelle des deux
///   enrichit sa FEN.
///
/// La règle reste celle du Crazyhouse : tout ce qui part vers ChessKit passe
/// par ``forChessKit(_:)`` ; tout ce qui part vers le MOTEUR garde la FEN
/// brute, seule à porter les murs.
enum BarricadesFEN {

    /// Remplace chaque mur par une case vide — le plateau seul, tel que
    /// ChessKit sait le lire.
    static func forChessKit(_ fen: String) -> String {
        var fields = fen.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        // Le test porte sur le PLACEMENT seul, jamais sur la FEN entière : le
        // champ du trait vaut « w » une fois sur deux, et le chercher partout
        // ferait retraiter chaque position de toutes les variantes pour rien.
        guard let placement = fields.first, placement.contains(where: isWall) else { return fen }

        fields[0] = placement.split(separator: "/", omittingEmptySubsequences: false)
            .map { compress(expand(String($0))) }
            .joined(separator: "/")
        return fields.joined(separator: " ")
    }

    /// Les cases murées d'une FEN. Lues plutôt que supposées : c'est le moteur
    /// qui fait autorité sur le plateau, ici comme ailleurs.
    static func wallSquares(in fen: String) -> [Square] {
        guard let placement = fen.split(separator: " ").first else { return [] }
        var squares: [Square] = []
        for (index, rankText) in placement.split(separator: "/", omittingEmptySubsequences: false).enumerated() {
            let rank = 8 - index
            guard (1...8).contains(rank) else { continue }
            let files = Array("abcdefgh")
            for (index, slot) in expand(String(rankText)).enumerated() where isWall(slot) {
                guard index < files.count else { continue }
                squares.append(Square("\(files[index])\(rank)"))
            }
        }
        return squares
    }

    // MARK: Rangée

    private static func isWall(_ character: Character) -> Bool {
        Character(character.uppercased()) == BarricadesConfiguration.wallLetter
    }

    /// Une rangée en 8 cases exactement, `.` pour une case vide.
    private static func expand(_ rank: String) -> [Character] {
        var slots: [Character] = []
        for character in rank {
            if let empty = character.wholeNumberValue, (1...8).contains(empty) {
                slots.append(contentsOf: Array(repeating: ".", count: empty))
            } else {
                slots.append(character)
            }
        }
        return slots
    }

    /// L'inverse, murs compris — ils comptent pour du vide.
    private static func compress(_ slots: [Character]) -> String {
        var result = ""
        var empty = 0
        for slot in slots {
            if slot == "." || isWall(slot) {
                empty += 1
            } else {
                if empty > 0 { result += "\(empty)"; empty = 0 }
                result.append(slot)
            }
        }
        if empty > 0 { result += "\(empty)" }
        return result
    }
}
