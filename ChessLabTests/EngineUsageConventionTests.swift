import Foundation
import Testing
@testable import ChessLab

/// La convention qui tient le « moteur fantôme » à distance.
///
/// Le 31/08/2026, le dernier échec intermittent de la suite complète (~1 par
/// run, toujours ~280 s, jamais reproductible isolément) s'est révélé être
/// ceci : des suites de logique pure construisaient un ``PlayViewModel``,
/// dont l'init démarre le VRAI Stockfish — et personne ne l'arrêtait. Le
/// moteur restait pris pendant ~280 s, et tout test Fairy croisant la
/// fenêtre mourait sur `acquireEngineProcess`, qui exige les DEUX moteurs
/// libres.
///
/// La règle, désormais : un test qui construit un view model de jeu (ou
/// démarre un contrôleur moteur) doit
///
/// - ou bien détenir le verrou d'intégration
///   (`EngineIntegrationGate.withExclusiveAccess`),
/// - ou bien couper le démarrage (`startsEngine: false` pour
///   ``PlayViewModel``, montage sans moteur pour les autres).
///
/// Ce test lit les SOURCES de la cible et échoue à la première construction
/// non conforme : la règle survit ainsi aux relectures — un nouveau fichier
/// de tests ne peut pas réintroduire le fantôme sans devenir rouge ici.
/// (Les fichiers de tests sont lus depuis le disque du Mac hôte via
/// `#filePath` : le simulateur partage son système de fichiers.)
@Suite struct EngineUsageConventionTests {

    /// Harnais OPT-IN (variable d'environnement ou sentinelle) : jamais
    /// exécutés en suite complète, ils ne peuvent pas affamer les autres
    /// tests. Tout ajout ici doit rester un choix conscient et justifié.
    private static let exemptFiles: Set<String> = [
        "EngineUsageConventionTests.swift",   // se lit lui-même
        "ClassificationDriftBenchmark.swift", // .enabled(if: isEnabled)
        "EloCalibrationHarness.swift",        // .enabled(if: CHESSLAB_CALIBRATION)
        "EngineOptionsTests.swift",           // .enabled(if: ENGINE_INTEGRATION)
        "EngineSearchBudgetBenchmark.swift",  // .enabled(if: isEnabled)
    ]

    /// Types dont `start()` (ou une requête) lance un moteur réel : les
    /// construire ET appeler `.start(` hors verrou est le motif interdit.
    private static let engineStartingTypes = [
        "Chess960PlayViewModel", "EngineLegalityPlayViewModel",
        "FairyVariantPlayViewModel", "StolenMovePlayViewModel",
        "VariantAnalysisViewModel", "Chess960AnalysisViewModel",
        "DuckChessAnalysisViewModel", "DuckChessEngine",
        "EngineController", "FairyEngineController", "AnalysisViewModel",
    ]

    private static var testSourcesDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    /// `needle` précédé d'un caractère d'identifiant est un AUTRE nom
    /// (`Chess960PlayViewModel(` contient `PlayViewModel(`) : on ancre à la
    /// main, `Regex` de Swift ne connaissant pas le regard-arrière.
    private static func wordAnchoredRanges(of needle: String, in text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var searchFrom = text.startIndex
        while let r = text.range(of: needle, range: searchFrom..<text.endIndex) {
            searchFrom = r.upperBound
            if r.lowerBound > text.startIndex {
                let before = text[text.index(before: r.lowerBound)]
                if before.isLetter || before.isNumber || before == "_" { continue }
            }
            result.append(r)
        }
        return result
    }

    /// Le texte des arguments d'un appel, parenthèses équilibrées — assez
    /// pour y chercher `startsEngine: false` sans parser Swift.
    private static func argumentText(after openParen: String.Index, in text: String) -> Substring {
        var depth = 1
        var i = openParen
        while depth > 0, i < text.endIndex {
            let c = text[i]
            if c == "(" { depth += 1 } else if c == ")" { depth -= 1 }
            i = text.index(after: i)
        }
        return text[openParen..<i]
    }

    @Test("Aucun test ne construit un moteur hors verrou sans le savoir")
    func noUngatedEngineConstruction() throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: Self.testSourcesDirectory, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "swift" && !Self.exemptFiles.contains($0.lastPathComponent) }
        #expect(files.count > 20, "le balayage doit voir la cible entière, pas un dossier vide")

        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let source = try String(contentsOf: file, encoding: .utf8)
            let gated = source.contains("withExclusiveAccess")
            let name = file.lastPathComponent

            for r in Self.wordAnchoredRanges(of: "PlayViewModel(", in: source) {
                let args = Self.argumentText(after: r.upperBound, in: source)
                #expect(
                    gated || args.contains("startsEngine: false"),
                    """
                    \(name) construit un PlayViewModel dont l'init démarre le VRAI \
                    Stockfish, sans verrou d'intégration ni `startsEngine: false`. \
                    Un moteur ainsi abandonné affame toute la suite (~280 s, 31/08/2026).
                    """
                )
            }

            guard source.contains(".start(") else { continue }
            for type in Self.engineStartingTypes
            where !Self.wordAnchoredRanges(of: type + "(", in: source).isEmpty {
                #expect(
                    gated,
                    """
                    \(name) construit \(type) et appelle `.start(` sans \
                    `EngineIntegrationGate.withExclusiveAccess`. Prendre le verrou, \
                    ou monter le test sans moteur réel.
                    """
                )
            }
            if source.contains("DuckChessViewModel(versusEngine: true") {
                #expect(gated, "\(name) monte un Duck Chess CONTRE moteur hors verrou.")
            }
        }
    }
}
