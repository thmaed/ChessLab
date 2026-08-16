import Foundation
import Testing
@testable import ChessLab

/// Le nom d'un répertoire importé se lit dans le PGN.
///
/// Un répertoire exporté d'une étude Lichess arrive avec
/// `[Event "Nom de l'étude: Nom du chapitre"]` — c'est le nom que
/// l'utilisateur a lui-même donné. Le réclamer à la main revient à faire
/// ressaisir une information déjà présente dans le fichier.
struct OpeningNameFromPGNTests {

    @Test func studyNameIsTakenWithoutItsChapter() {
        let pgn = """
        [Event "Répertoire Scandinave: Chapitre 1 — 3…Da5"]
        [White "?"]

        1. e4 d5 *
        """
        // Un répertoire est l'étude ENTIÈRE, pas son premier chapitre.
        #expect(OpeningPGNImporter.suggestedName(fromPGN: pgn) == "Répertoire Scandinave")
    }

    @Test func openingTagWinsOverEvent() {
        let pgn = """
        [Event "Partie amicale"]
        [Opening "Défense sicilienne"]

        1. e4 c5 *
        """
        #expect(OpeningPGNImporter.suggestedName(fromPGN: pgn) == "Défense sicilienne")
    }

    @Test func eventWithoutChapterIsUsedWhole() {
        let pgn = "[Event \"Mon répertoire noir\"]\n\n1. e4 e5 *"
        #expect(OpeningPGNImporter.suggestedName(fromPGN: pgn) == "Mon répertoire noir")
    }

    /// « ? » est la valeur INCONNUE du format PGN, et « Event » un reste
    /// d'export paresseux : proposer l'un ou l'autre serait pire que rien,
    /// puisque l'app retombe alors sur le nom de fichier.
    @Test func placeholdersAreRefused() {
        #expect(OpeningPGNImporter.suggestedName(fromPGN: "[Event \"?\"]\n\n1. e4 *") == nil)
        #expect(OpeningPGNImporter.suggestedName(fromPGN: "[Event \"Event\"]\n\n1. e4 *") == nil)
        #expect(OpeningPGNImporter.suggestedName(fromPGN: "1. e4 e5 *") == nil)
    }
}
