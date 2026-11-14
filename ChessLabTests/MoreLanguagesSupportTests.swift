import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// L'espagnol, l'allemand et l'italien (2.3) : le choix de la langue, la notation des
/// pièces, le repli des textes de cours, les noms d'ouvertures.
struct MoreLanguagesSupportTests {

    // MARK: La langue du système

    @Test("La première langue préférée que l'app parle l'emporte", arguments: [
        (["es-MX", "en-US"], "es"),
        (["de-CH", "fr-CH"], "de"),
        (["de-AT"], "de"),
        (["fr-CA", "es-ES"], "fr"),
        (["en-GB", "de-DE"], "en"),
        (["ja-JP", "de-DE", "en-US"], "de"),   // une langue inconnue est sautée
        (["it-CH", "de-CH"], "it"),
        (["ja-JP", "ko-KR"], "en"),            // aucune connue : anglais
        ([], "en"),
    ] as [([String], String)])
    func systemLanguageIsTheFirstSupportedPreference(preferences: [String], expected: String) {
        #expect(AppLanguage.preferredCode(among: preferences) == expected)
    }

    @Test func everyLanguageHasACodeAndALabel() {
        let codes = AppLanguage.allCases.filter { $0 != .system }.map(\.resolvedCode)
        #expect(Set(codes) == Set(AppLanguage.supportedCodes))
        #expect(codes.count == 5)
    }

    // MARK: La notation des pièces

    private func display(_ san: String, _ notation: PieceNotation) -> String {
        SANFormatter.display(san, notation: notation)
    }

    @Test("Espagnol : R D T A C", arguments: [
        ("Kb1", "Rb1"), ("Qxd5+", "Dxd5+"), ("Ra1", "Ta1"), ("Bb5", "Ab5"), ("Nf3", "Cf3"),
        ("exd8=Q#", "exd8=D#"), ("a8=N", "a8=C"), ("O-O", "O-O"), ("e4", "e4"), ("bxc3", "bxc3"),
    ])
    func spanishLetters(english: String, spanish: String) {
        #expect(display(english, .spanish) == spanish)
    }

    @Test("Italien : R D T A C (comme l'espagnol)", arguments: [
        ("Kb1", "Rb1"), ("Qxd5+", "Dxd5+"), ("Ra1", "Ta1"), ("Bb5", "Ab5"), ("Nf3", "Cf3"),
        ("exd8=Q#", "exd8=D#"), ("a8=N", "a8=C"), ("O-O-O", "O-O-O"),
    ])
    func italianLetters(english: String, italian: String) {
        #expect(display(english, .italian) == italian)
    }

    @Test("Allemand : K D T L S", arguments: [
        ("Kb1", "Kb1"), ("Qxd5+", "Dxd5+"), ("Ra1", "Ta1"), ("Bb5", "Lb5"), ("Nf3", "Sf3"),
        ("exd8=Q#", "exd8=D#"), ("a8=N", "a8=S"), ("O-O-O", "O-O-O"), ("bxc3", "bxc3"),
    ])
    func germanLetters(english: String, german: String) {
        #expect(display(english, .german) == german)
    }

    /// Une seule passe : un roi allemand reste un K, une tour devient un T, et
    /// rien n'est converti deux fois.
    @Test func aWholeMoveListIsConvertedInOnePass() {
        let line = ["Nf3", "Nc6", "Bb5", "a6", "Bxc6", "dxc6", "O-O", "Qd6", "Re1", "Kd8"]
        #expect(SANFormatter.display(line, notation: .german)
                == ["Sf3", "Sc6", "Lb5", "a6", "Lxc6", "dxc6", "O-O", "Dd6", "Te1", "Kd8"])
        #expect(SANFormatter.display(line, notation: .spanish)
                == ["Cf3", "Cc6", "Ab5", "a6", "Axc6", "dxc6", "O-O", "Dd6", "Te1", "Rd8"])
    }

    @Test func theDefaultNotationFollowsTheLanguage() {
        #expect(PieceNotation.defaultFor(languageCode: "es") == .spanish)
        #expect(PieceNotation.defaultFor(languageCode: "de") == .german)
        #expect(PieceNotation.defaultFor(languageCode: "it") == .italian)
        #expect(PieceNotation.defaultFor(languageCode: "fr") == .french)
        #expect(PieceNotation.defaultFor(languageCode: "en") == .french)   // le défaut historique
    }

    // MARK: Les textes de cours

    @Test func aCourseTextResolvesInEveryLanguage() {
        let text = LocalizedText(fr: "Bonjour", en: "Hello", es: "Hola", de: "Hallo", it: "Ciao")
        #expect(text.resolved("it") == "Ciao")
        #expect(text.resolved("fr") == "Bonjour")
        #expect(text.resolved("en") == "Hello")
        #expect(text.resolved("es") == "Hola")
        #expect(text.resolved("de") == "Hallo")
    }

    /// Un cours encore sans traduction espagnole s'affiche en anglais, pas en blanc.
    @Test func aMissingTranslationFallsBackToEnglishThenFrench() {
        let withoutSpanish = LocalizedText(fr: "Bonjour", en: "Hello")
        #expect(withoutSpanish.resolved("es") == "Hello")
        #expect(withoutSpanish.resolved("de") == "Hello")
        let frenchOnly = LocalizedText(fr: "Bonjour")
        #expect(frenchOnly.resolved("de") == "Bonjour")
        #expect(LocalizedText().resolved("es") == nil)
    }

    @Test func aPlainStringAppliesToEveryLanguage() throws {
        let decoded = try JSONDecoder().decode(LocalizedText.self, from: Data("\"1.e4\"".utf8))
        for code in AppLanguage.supportedCodes { #expect(decoded.resolved(code) == "1.e4") }
    }

    @Test func settingOneLanguageLeavesTheOthersIntact() {
        let text = LocalizedText(fr: "a", en: "b", es: "c", de: "d")
        let italian = text.setting("I", for: "it")
        #expect(italian.it == "I" && italian.de == "d")
        let edited = text.setting("D", for: "de")
        #expect(edited.de == "D" && edited.es == "c" && edited.en == "b" && edited.fr == "a")
        let cleared = text.setting(nil, for: "es")
        #expect(cleared.es == nil && cleared.de == "d")
    }

    // MARK: Les cours livrés

    /// Chaque texte localisé d'un cours livré existe dans les QUATRE langues, et
    /// les coups cités y sont les mêmes (la notation locale a été appliquée à la
    /// main, pas devinée : on vérifie que les cases citées sont identiques).
    @Test func everyBundledCourseTextExistsInFourLanguages() throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ChessLab/Resources/openings")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(files.count >= 137)

        let square = try NSRegularExpression(pattern: "(?<![A-Za-z0-9])[a-h][1-8](?![A-Za-z0-9])")
        func squares(_ s: String) -> [String] {
            let range = NSRange(s.startIndex..., in: s)
            return square.matches(in: s, range: range)
                .map { String(s[Range($0.range, in: s)!]) }.sorted()
        }
        var checked = 0
        func walk(_ any: Any, in file: String) {
            if let dict = any as? [String: Any] {
                if let fr = dict["fr"] as? String, let en = dict["en"] as? String {
                    checked += 1
                    let es = dict["es"] as? String ?? ""
                    let de = dict["de"] as? String ?? ""
                    let it = dict["it"] as? String ?? ""
                    #expect(!es.isEmpty && !de.isEmpty && !it.isEmpty, "\(file) : \(en.prefix(50))")
                    _ = fr
                    #expect(squares(es) == squares(en), "\(file) es : \(en.prefix(50))")
                    #expect(squares(de) == squares(en), "\(file) de : \(en.prefix(50))")
                    #expect(squares(it) == squares(en), "\(file) it : \(en.prefix(50))")
                    return
                }
                for value in dict.values { walk(value, in: file) }
            } else if let array = any as? [Any] {
                for value in array { walk(value, in: file) }
            }
        }
        for file in files {
            let data = try Data(contentsOf: file)
            walk(try JSONSerialization.jsonObject(with: data), in: file.lastPathComponent)
        }
        #expect(checked > 2000)
    }

    // MARK: Les noms par défaut des joueurs

    /// Un réglage de partie à deux enregistré dans une langue se relit dans une autre : « Blancas »,
    /// « Weiß », « Bianco »… redeviennent le nom des Blancs de la langue active.
    @MainActor
    @Test func defaultPlayerNamesFollowTheActiveLanguage() {
        for word in ["Blancs", "White", "Blancas", "Weiß", "Bianco"] {
            #expect(PlayerName.display(word) == PlayerName.white, "\(word)")
        }
        for word in ["Noirs", "Black", "Negras", "Schwarz", "Nero"] {
            #expect(PlayerName.display(word) == PlayerName.black, "\(word)")
        }
        #expect(PlayerName.display("Magnus") == "Magnus")
    }

    // MARK: Les noms d'ouvertures (ECO)

    @Test func everyEcoOpeningHasSpanishAndGermanNames() {
        for entry in EcoOpeningLoader.standard {
            #expect(entry.nameEs?.isEmpty == false, "\(entry.eco) es")
            #expect(entry.nameDe?.isEmpty == false, "\(entry.eco) de")
            #expect(entry.nameIt?.isEmpty == false, "\(entry.eco) it")
        }
    }

    @Test func ecoNamesFollowTheLanguageWithFallback() {
        let opening = EcoOpening(
            eco: "B20", name: "Défense sicilienne", moves: [],
            nameEn: "Sicilian Defence", nameEs: "Defensa Siciliana", nameDe: "Sizilianische Verteidigung",
            nameIt: "Difesa Siciliana")
        #expect(opening.displayName("fr") == "Défense sicilienne")
        #expect(opening.displayName("en") == "Sicilian Defence")
        #expect(opening.displayName("es") == "Defensa Siciliana")
        #expect(opening.displayName("de") == "Sizilianische Verteidigung")
        #expect(opening.displayName("it") == "Difesa Siciliana")
        let bare = EcoOpening(eco: "", name: "Ouverture X", moves: [], nameEn: "X Opening")
        #expect(bare.displayName("es") == "X Opening")
        #expect(bare.displayName("de") == "X Opening")
        #expect(bare.displayName("it") == "X Opening")
    }
}
