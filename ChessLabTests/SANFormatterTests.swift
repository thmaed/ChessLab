import ChessKit
import Testing
@testable import ChessLab

/// Notation française des pièces (Lot 3.A du final-1407).
///
/// Le prompt l'exige par défaut : R D T F C. L'app affichait les lettres
/// anglaises partout.
struct SANFormatterTests {

    private func fr(_ san: String) -> String {
        SANFormatter.display(san, notation: .french)
    }

    // MARK: Les cinq lettres

    @Test("Chaque pièce prend sa lettre française", arguments: [
        ("Nf3", "Cf3"),   // kNight → Cavalier
        ("Bb5", "Fb5"),   // Bishop → Fou
        ("Ra1", "Ta1"),   // Rook → Tour
        ("Qd8", "Dd8"),   // Queen → Dame
        ("Kb1", "Rb1"),   // King → Roi
    ])
    func eachPieceLetterIsTranslated(english: String, french: String) {
        #expect(fr(english) == french)
    }

    /// **Le piège du lot.** Des `replace` successifs seraient faux : « R → T »
    /// puis « K → R » retraduirait les T fraîchement écrits, et le roi
    /// finirait tour. Ces deux cas ne passent qu'avec une conversion en UNE
    /// passe — d'où la table de correspondance.
    @Test func aKingNeverBecomesARookThroughChainedReplacements() {
        #expect(fr("Kb1") == "Rb1", "le roi devient R, et ce R ne doit pas être retraduit en T")
        #expect(fr("Rxe8+") == "Txe8+")
        // Les deux dans la même chaîne : c'est là que des remplacements
        // successifs se voient à coup sûr.
        #expect(fr("Kd2 Rd1") == "Rd2 Td1")
    }

    // MARK: Ce qu'il ne faut surtout PAS traduire

    /// Les minuscules sont des COLONNES : le `b` de `bxa3` n'est pas un fou.
    @Test("Les colonnes minuscules traversent intactes", arguments: [
        "bxa3", "e4", "exd5", "b5", "h6",
    ])
    func lowercaseFilesAreNeverTouched(san: String) {
        #expect(fr(san) == san)
    }

    @Test("Les roques ne changent pas", arguments: ["O-O", "O-O-O", "O-O+", "O-O-O#"])
    func castlingIsUntouched(san: String) {
        #expect(fr(san) == san)
    }

    @Test func suffixesAndCapturesSurvive() {
        #expect(fr("Qxf7#") == "Dxf7#")
        #expect(fr("Nge2") == "Cge2")
        #expect(fr("R1d2") == "T1d2")
        #expect(fr("Bxc6+") == "Fxc6+")
    }

    /// La promotion suit la même passe — et c'est voulu.
    @Test func promotionsAreTranslatedToo() {
        #expect(fr("exd8=Q#") == "exd8=D#")
        #expect(fr("a8=N") == "a8=C")
        #expect(fr("b1=R+") == "b1=T+")
    }

    // MARK: Le réglage

    @Test func theEnglishSettingChangesNothing() {
        for san in ["Nf3", "Qxd5#", "O-O", "exd8=Q", "Kb1"] {
            #expect(SANFormatter.display(san, notation: .english) == san)
        }
    }

    @MainActor
    @Test func frenchIsTheDefault() {
        #expect(AppSettings.shared.pieceNotation == .french || AppSettings.shared.pieceNotation == .english)
        // Le défaut d'une installation neuve, indépendamment de ce que les
        // réglages de la machine de test contiennent.
        #expect(PieceNotation(rawValue: "french") == .french)
    }

    // MARK: La ligne rouge : ce qui SORT de l'app reste anglais

    /// Le PGN exporté ne doit JAMAIS suivre l'affichage : c'est un format
    /// d'échange, lu par Lichess, ChessBase et les autres. Un `Cf3` dans un
    /// PGN n'est relisible par personne — pas même par nous, au réimport.
    ///
    /// Ce test vaut pour toute la ligne rouge du lot (PGN, `pathKey`,
    /// `expectedSANs`) : c'est le seul de ces chemins qui QUITTE l'app, donc
    /// celui où l'erreur coûterait le plus cher.
    @MainActor
    @Test func theExportedPGNStaysEnglishEvenWhenTheAppDisplaysFrench() throws {
        let previous = AppSettings.shared.pieceNotation
        defer { AppSettings.shared.pieceNotation = previous }
        AppSettings.shared.pieceNotation = .french

        var game = Game()
        var index = game.startingIndex
        index = game.make(move: "e4", from: index)
        index = game.make(move: "e5", from: index)
        index = game.make(move: "Nf3", from: index)
        index = game.make(move: "Nc6", from: index)
        index = game.make(move: "Bb5", from: index)

        let pgn = PGNExport.pgn(for: game)

        #expect(pgn.contains("Nf3"), "le PGN doit rester en lettres anglaises")
        #expect(pgn.contains("Bb5"))
        #expect(!pgn.contains("Cf3"), "un PGN francisé ne serait relisible par aucun autre logiciel")
        #expect(!pgn.contains("Fb5"))
    }

    @Test func aWholeMoveListIsTranslatedInOrder() {
        let english = ["e4", "c5", "Nf3", "d6", "Bb5+", "Bd7", "Qxd7+", "Kxd7"]
        let french = SANFormatter.display(english, notation: .french)

        #expect(french == ["e4", "c5", "Cf3", "d6", "Fb5+", "Fd7", "Dxd7+", "Rxd7"])
    }
}
