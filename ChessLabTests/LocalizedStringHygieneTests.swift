import Foundation
import Testing
@testable import ChessLab

/// Contrôle d'hygiène sur les chaînes RÉELLEMENT livrées (celles compilées
/// dans le bundle, pas le catalogue source).
///
/// Motif : une explication du Laboratoire écrite en chaîne multiligne Swift a
/// vu ses lignes se recoller EN GARDANT leur indentation, et est partie dans
/// le catalogue avec des « la part verte         est ce que ». La compilation
/// était verte, l'app s'affichait — seul le texte était abîmé, et rien ne
/// regardait le texte. Ce contrôle regarde.
@MainActor
struct LocalizedStringHygieneTests {

    /// Les chaînes livrées pour une langue, telles que le bundle les contient.
    private static func shippedStrings(_ localization: String) throws -> [String: String] {
        let url = try #require(
            Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                            subdirectory: nil, localization: localization),
            "les chaînes « \(localization) » compilées sont introuvables dans le bundle"
        )
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    private static func shippedFrenchStrings() throws -> [String: String] {
        try shippedStrings("fr")
    }

    /// Aucune chaîne ne doit contenir deux espaces d'affilée. Mesuré sur le
    /// catalogue du 24/08 : 0 sur 1 104. C'est donc un invariant, pas une
    /// tolérance — et c'est exactement la trace que laisse une continuation de
    /// ligne mal écrite.
    @Test("Aucune chaîne livrée ne porte d'espaces en double")
    func noShippedStringHasDoubledSpaces() throws {
        let strings = try Self.shippedFrenchStrings()
        try #require(strings.count > 900, "catalogue anormalement petit : \(strings.count)")

        let offenders = strings.filter { $0.value.contains("  ") }
        #expect(
            offenders.isEmpty,
            "espaces en double dans : \(offenders.keys.sorted().prefix(3).joined(separator: " | "))"
        )
    }

    /// Le nom d'un cours reste en ANGLAIS dans `opening_catalog.json` — c'est
    /// `Localizable.xcstrings` qui le traduit. Un cours ajouté sans sa
    /// traduction s'affiche donc en anglais au milieu de 135 titres français,
    /// sans que rien ne le signale : le catalogue est valide, l'app démarre,
    /// le cours fonctionne.
    ///
    /// C'est exactement ce qui est arrivé à « Electric Pawns », resté anglais
    /// depuis son ajout le 24/08 jusqu'à ce qu'un lecteur le remarque.
    @Test("Chaque nom de cours a sa traduction française")
    func everyCourseNameIsTranslated() throws {
        let strings = try Self.shippedFrenchStrings()
        let names = OpeningCourseLoader.catalog.map(\.name)
        try #require(names.count > 100, "catalogue anormalement petit : \(names.count)")

        let untranslated = names.filter { strings[$0] == nil }
        #expect(
            untranslated.isEmpty,
            "sans traduction, donc affiché en anglais : \(untranslated.sorted().joined(separator: " | "))"
        )
    }

    /// Ni espace juste avant un saut de ligne : même origine, même symptôme.
    ///
    /// Volontairement limité au saut de ligne. L'espace FINAL, lui, est un
    /// usage légitime ici : cinq chaînes sont des préfixes destinés à être
    /// collés à une valeur (« Verdict à tenir : », « Le meilleur était »).
    /// Les interdire aurait obligé à une liste d'exceptions, c'est-à-dire à un
    /// contrôle qui ne contrôle plus rien.
    @Test("Aucune chaîne livrée ne porte d'espace avant un saut de ligne")
    func noShippedStringHasSpaceBeforeNewline() throws {
        let strings = try Self.shippedFrenchStrings()
        let offenders = strings.filter { $0.value.contains(" \n") }
        #expect(
            offenders.isEmpty,
            "espace avant saut de ligne dans : \(offenders.keys.sorted().prefix(3).joined(separator: " | "))"
        )
    }

    // MARK: L'anglais existe vraiment

    /// Toute clé française livrée doit avoir sa contrepartie ANGLAISE.
    ///
    /// Une clé absente de la table anglaise ne casse rien de visible côté
    /// développement : l'app démarre, l'écran s'affiche — en français, au
    /// milieu d'une interface anglaise. C'est passé inaperçu longtemps, et
    /// ce n'est visible que pour qui lance l'app en anglais.
    @Test("Chaque chaîne française livrée a sa version anglaise")
    func everyFrenchStringHasAnEnglishCounterpart() throws {
        let fr = try Self.shippedFrenchStrings()
        let en = try Self.shippedStrings("en")
        try #require(fr.count > 900, "catalogue anormalement petit : \(fr.count)")

        let missing = fr.keys.filter { en[$0] == nil }.sorted()
        #expect(
            missing.isEmpty,
            "\(missing.count) chaîne(s) sans anglais, dont : \(missing.prefix(5).joined(separator: " | "))"
        )
    }

    /// Les textes qui n'atteignent l'écran QUE par
    /// ``LocalizationController/string(_:)``.
    ///
    /// Ceux-là ne sont pas extraits automatiquement dans le catalogue : rien,
    /// à la compilation, ne signale une clé oubliée — `string(_:)` rend alors
    /// la clé elle-même, c'est-à-dire du français, et l'app a l'air de
    /// marcher. C'est exactement ce qui était arrivé aux messages du
    /// validateur de FEN, du scanner, de l'éditeur de position, de l'alerte
    /// gaffe et de l'import PGN/FEN : tous français en anglais.
    ///
    /// Un échantillon plutôt qu'une liste exhaustive — un par FAMILLE, pour
    /// que la disparition d'une famille entière se voie.
    @Test("Les textes composés à l'exécution sont bien traduits", arguments: [
        "FEN mal formé : 6 champs attendus (position, trait, roques, en passant, demi-coups, coups).",
        "Ce coup laisse passer un mat forcé.",
        "Ce coup fait perdre environ %lld pion(s) d'évaluation.",
        "Tapez une pièce pour la retirer.",
        "%@, case vide",
        "Cette image n'a pas pu être lue.",
        "Les coins se croisent : replacez-les dans l'ordre autour du plateau.",
        "Collez une partie (PGN) ou une position (FEN).",
        "Ni un FEN ni un PGN reconnaissable.",
        "Cette position n'est pas dans le répertoire.",
        "Résultat inconnu",
        "L'ordinateur n'a pas démarré : il ne jouera pas.",
        "%lld %@ en réserve",
    ])
    func runtimeComposedStringsAreTranslated(key: String) throws {
        let en = try Self.shippedStrings("en")
        let translation = try #require(en[key], "clé absente du catalogue : elle sortira en français")
        #expect(translation != key, "traduction anglaise identique au français")
    }
}
