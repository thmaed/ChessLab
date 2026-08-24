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

    /// Les chaînes françaises livrées, telles que le bundle les contient.
    private static func shippedFrenchStrings() throws -> [String: String] {
        let url = try #require(
            Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                            subdirectory: nil, localization: "fr"),
            "les chaînes françaises compilées sont introuvables dans le bundle"
        )
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
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
}
