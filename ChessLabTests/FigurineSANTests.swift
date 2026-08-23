import ChessKit
import Testing
@testable import ChessLab

/// La notation figurine remplace la LETTRE DE PIÈCE par son dessin — et rien
/// d'autre. Ces tests verrouillent les cas où l'on se trompe : le « b » de la
/// colonne b, le « O » du roque, le « = » de la promotion.
struct FigurineSANTests {

    /// Raccourci de lecture : la suite des morceaux, pièces notées par leur
    /// lettre anglaise entre chevrons.
    private func rendered(_ san: String) -> String {
        FigurineSAN.tokens(for: san).map { token in
            switch token {
            case let .piece(kind):
                switch kind {
                case .king: "<K>"
                case .queen: "<Q>"
                case .rook: "<R>"
                case .bishop: "<B>"
                case .knight: "<N>"
                case .pawn: "<P>"
                }
            case let .text(text): text
            }
        }.joined()
    }

    @Test("La lettre de tête devient une pièce")
    func leadingLetterBecomesAPiece() {
        #expect(rendered("Nf3") == "<N>f3")
        #expect(rendered("Qxd5+") == "<Q>xd5+")
        #expect(rendered("Kxe4") == "<K>xe4")
        #expect(rendered("Bb5") == "<B>b5")
    }

    @Test("Un coup de pion n'a aucune pièce à dessiner")
    func pawnMovesCarryNoPiece() {
        #expect(rendered("e4") == "e4")
        #expect(rendered("exd5") == "exd5")
        #expect(rendered("d4") == "d4")
    }

    /// Le piège classique : dans « bxc3 », le `b` est une COLONNE. Le traduire
    /// en fou (ou en dessiner un) ferait lire « le fou prend en c3 » là où
    /// c'est un pion. Même piège que ``SANFormatter`` côté lettres.
    @Test("Une colonne minuscule n'est jamais une pièce")
    func lowercaseFileIsNeverAPiece() {
        #expect(rendered("bxc3") == "bxc3")
        #expect(rendered("b4") == "b4")
        #expect(rendered("axb5") == "axb5")
    }

    @Test("Le roque reste du texte")
    func castlingStaysText() {
        #expect(rendered("O-O") == "O-O")
        #expect(rendered("O-O-O") == "O-O-O")
        #expect(rendered("O-O+") == "O-O+")
    }

    /// La promotion porte une SECONDE lettre de pièce, après le « = ».
    @Test("La promotion dessine la pièce promue")
    func promotionDrawsThePromotedPiece() {
        #expect(rendered("e8=Q") == "e8=<Q>")
        #expect(rendered("e8=Q+") == "e8=<Q>+")
        #expect(rendered("exd8=N#") == "exd8=<N>#")
        // Sous-promotion en tour, avec le roi qui reste du texte autour.
        #expect(rendered("b1=R") == "b1=<R>")
    }

    /// Une désambiguïsation (« Nbd7 », « R1e2 », « Qh4xe1 ») ne concerne que le
    /// texte APRÈS la lettre de tête.
    @Test("La désambiguïsation traverse intacte")
    func disambiguationPassesThrough() {
        #expect(rendered("Nbd7") == "<N>bd7")
        #expect(rendered("R1e2") == "<R>1e2")
        #expect(rendered("Qh4xe1") == "<Q>h4xe1")
    }

    @Test("Une chaîne vide ne produit rien")
    func emptyProducesNothing() {
        #expect(FigurineSAN.tokens(for: "").isEmpty)
    }

    /// Aucun caractère ne doit se perdre en route : le texte reconstitué, en
    /// remettant les lettres à la place des pièces, doit être le SAN d'origine.
    @Test("Aucun caractère perdu", arguments: [
        "e4", "Nf3", "O-O", "O-O-O", "exd5", "e8=Q+", "Qxd5#", "Rae1", "R1e2",
        "bxc3", "Nbd7", "Kf1", "axb8=N", "Bxf7+", "c8=B",
    ])
    func nothingIsLost(san: String) {
        let letters: [Piece.Kind: String] = [
            .king: "K", .queen: "Q", .rook: "R", .bishop: "B", .knight: "N", .pawn: "P",
        ]
        let rebuilt = FigurineSAN.tokens(for: san).map { token in
            switch token {
            case let .piece(kind): letters[kind] ?? "?"
            case let .text(text): text
            }
        }.joined()
        #expect(rebuilt == san)
    }
}
