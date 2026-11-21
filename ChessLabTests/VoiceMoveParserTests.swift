import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Retrouver un coup dans une phrase dite (étude « coups à la voix », 19/11/2026) — comparée aux seuls coups légaux.
struct VoiceMoveParserTests {

    private func candidates(_ fen: String? = nil, after lans: [String] = []) -> [VoiceMoveParser.Candidate] {
        var board = Board(position: fen.flatMap { Position(fen: $0) } ?? .standard)
        for lan in lans {
            board.move(pieceAt: Square(String(lan.prefix(2))), to: Square(String(lan.suffix(2))))
        }
        return VoiceMoveParser.candidates(in: board)
    }

    private func uci(_ text: String, _ legal: [VoiceMoveParser.Candidate]) -> String? {
        if case let .move(move) = VoiceMoveParser.resolve(transcripts: [text], among: legal) { return move.uci }
        return nil
    }

    /// Banc de voix SYNTHÉTIQUES du 21/11/2026 (Galaxy et iPhone, plusieurs voix) : ce que les moteurs ont écrit.
    @Test func writtenFormsFromSyntheticVoices() {
        let start = candidates()
        let rooks = candidates("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
        let italianGame = candidates(after: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"])
        let ruy = candidates(after: ["e2e4", "e7e5", "g1f3", "b8c6"])
        func play(_ language: String, _ heard: String, _ legal: [VoiceMoveParser.Candidate]) -> String? {
            if case let .move(move) = VoiceMoveParser.resolve(
                transcripts: [heard], among: legal, vocabulary: VoiceMoveParser.vocabulary(for: language)) { return move.uci }
            return nil
        }
        let cases: [(String, String, [VoiceMoveParser.Candidate], String)] = [
            ("en", "Rotates H8", rooks, "h1h8"), ("en", "Castles queen size", rooks, "e1c1"),
            ("en", "Castle skin side", italianGame, "e1g1"), ("en", "Night C3", start, "b1c3"),
            ("de", "Tom schlägt A8", rooks, "a1a8"), ("de", "Kurze Rockade", italianGame, "e1g1"),
            ("de", "Baue D3", ruy, "d2d3"), ("de", "Bauer definiert", start, "d2d4"),
            ("de", "Die vier", start, "d2d4"), ("de", "springen als C3", start, "b1c3"),
            ("it", "Cavallo Citroën", start, "b1c3"), ("it", "Marocco corto", italianGame, "e1g1"),
            ("it", "A Rocco Cordo", italianGame, "e1g1"),
            ("es", "Caballo centro", start, "b1c3"), ("es", "Entró que cortó", italianGame, "e1g1"),
            ("es", "Zorro come a ocho", rooks, "a1a8"),
            ("fr", "Détroit", start, "d2d3"), ("fr", "Les quatre", start, "d2d4"),
        ]
        for (language, heard, legal, expected) in cases {
            #expect(play(language, heard, legal) == expected, "« \(heard) » (\(language))")
        }
        for heard in ["I do", "Under", "undue"] {
            #expect(VoiceMoveParser.isUndo(heard, vocabulary: VoiceMoveParser.vocabulary(for: "en")), "« \(heard) »")
        }
    }

    @Test func theStartingPositionHasTwentyMoves() {
        #expect(candidates().count == 20)
    }

    @Test(arguments: [
        ("e4", "e2e4"), ("E4", "e2e4"), ("pion e4", "e2e4"), ("Pion en e 4", "e2e4"), ("euh 4", "e2e4"),
        ("Cavalier f3", "g1f3"), ("cavalier en F3.", "g1f3"), ("Cavalier effe trois", "g1f3"), ("Cf3", "g1f3"),
        ("c'est 4", "c2c4"), ("dé 4", "d2d4"), ("Cavalier c3", "b1c3"), ("f3", "f2f3"),
    ])
    func movesFromTheStart(text: String, expected: String) {
        #expect(uci(text, candidates()) == expected, "« \(text) »")
    }

    @Test func aMoveThatNoPieceCanMakeIsImpossible() {
        #expect(VoiceMoveParser.resolve(transcripts: ["fou c4"], among: candidates()) == .illegal)
        #expect(VoiceMoveParser.resolve(transcripts: ["bonjour"], among: candidates()) == .notUnderstood)
    }

    @Test func eFourHeardAsAuQuatre() {
        // iPhone3 et iPhone XS, 20/11/2026 : « e4 » écrit « Au quatre » ou « O quatre ».
        #expect(uci("Au quatre", candidates()) == "e2e4")
        #expect(uci("O quatre", candidates()) == "e2e4")
        #expect(VoiceMoveParser.resolve(transcripts: ["au revoir"], among: candidates()) == .notUnderstood)
    }

    @Test func castling() {
        let italian = candidates(after: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"])
        #expect(uci("petit roque", italian) == "e1g1")
        #expect(VoiceMoveParser.resolve(transcripts: ["grand roque"], among: italian) == .illegal)
        #expect(uci("roque", italian) == "e1g1")
        // Ce que la reconnaissance a écrit en partie sur iPhone3 (20/11/2026).
        for heard in ["Petit rock", "Roi, Petit roc", "P rock", "Roi Petitoc", "Rock"] {
            #expect(uci(heard, italian) == "e1g1", "« \(heard) »")
        }
        #expect(VoiceMoveParser.resolve(transcripts: ["Grand rock"], among: italian) == .illegal)
    }

    @Test func twoKnightsForOneSquareAskWhichOne() {
        // Cavaliers b1 et f3, d2 libre.
        let legal = candidates("4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1")
        guard case let .ambiguous(moves) = VoiceMoveParser.resolve(transcripts: ["cavalier d2"], among: legal) else {
            Issue.record("deux cavaliers peuvent aller en d2")
            return
        }
        #expect(Set(moves.map(\.uci)) == ["b1d2", "f3d2"])
        #expect(uci("cavalier b d2", legal) == "b1d2")
        #expect(uci("cavalier f3 d2", legal) == "f3d2")
    }

    @Test(arguments: [
        // Les façons de dire « tour h, en e1 » — la version officielle (Rhe1) — que la reconnaissance peut écrire.
        "Tour H E 1", "Tour h e1", "Tour H E un", "tour he1", "Tour HE1", "Tour, H, E 1", "Tour hache e un",
        "Tour H en e1", "Tour h1 en e1", "The1", "Tour H 1 en E 1", "Tour ache e un",
    ])
    func twoRooksForOneSquareTheOfficialWay(text: String) {
        // Tours a1 et h1, roi e2 : les deux tours peuvent aller en e1.
        let legal = candidates("4k3/8/8/8/8/8/4K3/R6R w - - 0 1")
        #expect(uci(text, legal) == "h1e1", "« \(text) »")
    }

    @Test func theRealSANOfTwoRooksCarriesTheStartFileAndIsReadBack() {
        // La position donne « Rhe1 » / « Rae1 » ; l'annonce qui répète le coup dit donc LAQUELLE a bougé.
        let legal = candidates("4k3/8/8/8/8/8/4K3/R6R w - - 0 1")
        let toE1 = legal.filter { $0.to == "e1" && $0.piece == "R" }
        #expect(Set(toE1.map(\.san)) == ["Rhe1", "Rae1"])
        #expect(MoveNarration.describe(san: "Rhe1") == "tour h en e 1")
        // Et ce qu'elle répète se comprend en retour : « tour h en e 1 » → h1e1.
        #expect(uci(MoveNarration.describe(san: "Rhe1"), legal) == "h1e1")
    }

    @Test(arguments: ["Tour A E 1", "Tour a e1", "Tour ae1", "Tour a1 en e1"])
    func theOtherRookIsChosenByItsFile(text: String) {
        let legal = candidates("4k3/8/8/8/8/8/4K3/R6R w - - 0 1")
        #expect(uci(text, legal) == "a1e1", "« \(text) »")
    }

    @Test func theRankOfDepartureTellsTwoRooksApartToo() {
        // Tours a1 et a5, roi h8 : les deux vont en a3.
        let legal = candidates("7k/8/8/R7/8/8/8/R3K3 w - - 0 1")
        #expect(uci("Tour 1 a3", legal) == "a1a3")
        #expect(uci("Tour 5 en a 3", legal) == "a5a3")
        #expect(uci("Tour 5 a 3", legal) == "a5a3")
    }

    @Test func promotionToTheQueenUnlessAnotherPieceIsNamed() {
        let legal = candidates("8/P7/8/8/8/8/8/k6K w - - 0 1")
        #expect(uci("a8", legal) == "a7a8q")
        #expect(uci("a8 dame", legal) == "a7a8q")
        #expect(uci("a8 cavalier", legal) == "a7a8n")
        #expect(uci("pion a8 promotion tour", legal) == "a7a8r")
    }

    @Test func aMisheardLetterThatRhymesIsRescuedWhenOnlyOneMoveFits() {
        // Un seul pion, en d2 : « bé 4 » n'existe pas, « dé 4 » si.
        let legal = candidates("4k3/8/8/8/8/8/3P4/4K3 w - - 0 1")
        #expect(uci("bé 4", legal) == "d2d4")
        #expect(VoiceMoveParser.resolve(transcripts: ["bé 4"], among: legal, confusions: false) == .illegal)
    }

    @Test func theFirstTranscriptThatGivesAMoveWins() {
        #expect(VoiceMoveParser.resolve(transcripts: ["bonjour", "cavalier f3"], among: candidates())
                == .move(.init(uci: "g1f3", san: "Nf3")))
    }

    @Test func spokenFormsCoverTheUsualWays() {
        let forms = VoiceMoveParser.spokenForms(of: candidates())
        #expect(forms.contains("cavalier f3"))
        #expect(forms.contains("pion en e4"))
        #expect(forms.contains("e4"))
    }

    // MARK: Quand la reconnaissance hésite (iPhone 11, 21/11/2026)

    /// « e3 » dit, entendu `["A3", "E3"]` : a3 ET e3 sont légaux, à égalité de voix. On ne joue PLUS la première
    /// alternative (c'était a3) : la reconnaissance hésite, et la partie le dira.
    @Test func twoLegalMovesAtEqualVotesMakeTheRecognitionHesitate() {
        let legal = candidates()
        guard case let .conflicting(moves) = VoiceMoveParser.resolve(transcripts: ["A3", "E3"], among: legal) else {
            Issue.record("« A3 » et « E3 » désignent deux coups légaux : il faut hésiter")
            return
        }
        #expect(moves.map(\.uci) == ["a2a3", "e2e3"], "le meilleur d'abord")
        guard case let .conflicting(others) = VoiceMoveParser.resolve(transcripts: ["pion c3", "Pion des quatre"],
                                                                      among: legal) else {
            Issue.record("c3 ou d4")
            return
        }
        #expect(others.map(\.uci) == ["c2c3", "d2d4"])
    }

    /// Le coup que PLUS d'alternatives désignent l'emporte : `["A3", "13", "E3", "Eux trois"]` (entendu pour « e3 »).
    @Test func theMoveMostAlternativesNameWins() {
        let legal = candidates()
        #expect(uci("pion d4", legal) == "d2d4")
        #expect(VoiceMoveParser.resolve(transcripts: ["A3", "13", "E3", "Eux trois"], among: legal)
            == .move(legal.first { $0.uci == "e2e3" }!))
        // Les variantes d'un MÊME coup ne sont pas une hésitation.
        #expect(VoiceMoveParser.resolve(transcripts: ["D4", "Des quatre", "pion en d4"], among: legal)
            == .move(legal.first { $0.uci == "d2d4" }!))
    }

    /// Après « a 3 ou e 3 ? » : « premier » ou « deuxième », dans les cinq langues.
    @Test(arguments: [
        ("Premier", "fr", 0), ("le deuxième", "fr", 1), ("deux", "fr", 1), ("Second", "fr", 1), ("e4", "fr", nil),
        ("first", "en", 0), ("the second one", "en", 1), ("primero", "es", 0), ("el segundo", "es", 1),
        ("erster", "de", 0), ("zweiter", "de", 1), ("primo", "it", 0), ("il secondo", "it", 1),
    ] as [(String, String, Int?)])
    func theAnswerFirstOrSecondChoosesBetweenTwoMoves(text: String, language: String, expected: Int?) {
        #expect(VoiceMoveParser.choice(in: [text], language: language) == expected, "« \(text) » (\(language))")
    }
}

/// Les 51 essais RÉELS du 19/11/2026 (iPhone3, l'utilisateur, cinq reconnaissances) rejoués : ce que chaque
/// reconnaissance a entendu passe de nouveau par le module. Garde-fou : le module ne doit pas régresser sur de la
/// vraie parole, et ne doit presque jamais choisir un AUTRE coup que celui dit.
struct VoiceMoveRealTrialsTests {
    private struct Trial: Decodable {
        struct Result: Decodable { let engine: String; let transcripts: [String] }
        let target: VoiceMoveParser.Candidate
        let candidates: [VoiceMoveParser.Candidate]
        let results: [Result]
    }

    private static func trials() throws -> [Trial] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appending(path: "VoiceDictation/trials-2026-11-19-iphone3.jsonl")
        let text = try String(contentsOf: url, encoding: .utf8)
        return try text.split(separator: "\n").map { try JSONDecoder().decode(Trial.self, from: Data($0.utf8)) }
    }

    @Test func replayTheRealTrials() throws {
        let trials = try Self.trials()
        #expect(trials.count == 51)
        var right: [String: Int] = [:], wrong: [String: Int] = [:], anyRight = 0
        for trial in trials {
            var found = false
            for result in trial.results {
                switch VoiceMoveParser.resolve(transcripts: result.transcripts, among: trial.candidates) {
                case let .move(move) where move == trial.target:
                    right[result.engine, default: 0] += 1
                    found = true
                case .move:
                    wrong[result.engine, default: 0] += 1
                default:
                    break
                }
            }
            if found { anyRight += 1 }
        }
        for engine in right.keys.sorted() {
            print("REJEU \(engine) : \(right[engine] ?? 0)/\(trials.count) justes, \(wrong[engine] ?? 0) faux coups")
        }
        print("REJEU au moins une : \(anyRight)/\(trials.count)")
        // Avant l'amélioration du 19/11 : 36 à 42 justes selon la reconnaissance, 45 avec au moins une.
        #expect(anyRight >= 45)
        #expect((right["D iOS 26"] ?? 0) >= 42)
    }
}

/// Les CINQ langues de l'app (décision du 19/11/2026) : les mêmes coups, dits comme on les dit dans chaque langue.
struct VoiceMoveParserLanguagesTests {
    private func uci(_ text: String, _ language: String, after lans: [String] = []) -> String? {
        var board = Board(position: .standard)
        for lan in lans { board.move(pieceAt: Square(String(lan.prefix(2))), to: Square(String(lan.suffix(2)))) }
        let vocabulary = VoiceMoveParser.vocabulary(for: language)
        if case let .move(move) = VoiceMoveParser.resolve(
            transcripts: [text], among: VoiceMoveParser.candidates(in: board), vocabulary: vocabulary) {
            return move.uci
        }
        return nil
    }

    private static let italianGame = ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"]

    @Test(arguments: [
        ("knight f3", "en"), ("Knight to F3", "en"), ("Nf3", "en"), ("knight to foxtrot three", "en"),
        ("caballo f3", "es"), ("caballo a efe tres", "es"), ("Cf3", "es"),
        ("Springer f3", "de"), ("Springer nach f drei", "de"), ("Sf3", "de"),
        ("cavallo f3", "it"), ("cavallo in effe tre", "it"), ("Cf3", "it"),
        ("cavalier f3", "fr"), ("Cavalier Foxtrot 3", "fr"),
    ])
    func theKnightToF3(text: String, language: String) {
        #expect(uci(text, language) == "g1f3", "« \(text) » (\(language))")
    }

    @Test func englishWritesTwoForToSoItIsNotARank() {
        let english = VoiceMoveParser.vocabulary(for: "en")
        #expect(VoiceMoveParser.heard("knight 2 f3", vocabulary: english).fromRank == nil)
        #expect(VoiceMoveParser.heard("rook 1 a3", vocabulary: english).fromRank == nil)
        #expect(VoiceMoveParser.heard("tour 1 a3").fromRank == "1")
    }

    @Test(arguments: [
        ("pawn e4", "en"), ("e four", "en"), ("peón e4", "es"), ("e cuatro", "es"),
        ("Bauer e4", "de"), ("e vier", "de"), ("pedone e4", "it"), ("e quattro", "it"),
    ])
    func thePawnToE4(text: String, language: String) {
        #expect(uci(text, language) == "e2e4", "« \(text) » (\(language))")
    }

    @Test(arguments: [
        ("castles kingside", "en"), ("enroque corto", "es"), ("kurze Rochade", "de"), ("arrocco corto", "it"),
        ("petit roque", "fr"),
    ])
    func shortCastling(text: String, language: String) {
        #expect(uci(text, language, after: Self.italianGame) == "e1g1", "« \(text) » (\(language))")
    }

    @Test func undoIsHeardInEveryLanguage() {
        for (text, language) in [("annule", "fr"), ("take back", "en"), ("deshacer", "es"), ("zurück", "de"),
                                 ("annulla", "it")] {
            #expect(VoiceMoveParser.isUndo(text, vocabulary: VoiceMoveParser.vocabulary(for: language)), "\(text)")
        }
        #expect(!VoiceMoveParser.isUndo("cavalier f3"))
    }

    @Test func aConversationIsNotChess() {
        #expect(!VoiceMoveParser.soundsLikeChess(["tu veux un café ?"]))
        #expect(VoiceMoveParser.soundsLikeChess(["cavalier f3"]))
        #expect(VoiceMoveParser.soundsLikeChess(["annule"]))
    }
}
