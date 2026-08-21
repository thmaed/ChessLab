import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Le bilan chiffré d'une partie analysée : agrégation pure, puis persistance.
///
/// Ces chiffres n'ont d'intérêt que s'ils sont COMPARABLES d'une partie à
/// l'autre — c'est toute la raison de la perte moyenne brute à côté de la
/// précision, et de l'exclusion de la théorie. Les tests portent donc autant
/// sur ce qui est compté que sur ce qui ne l'est pas.
struct GameAnalysisMetricsTests {

    private func move(_ mover: Piece.Color, _ loss: Double, book: Bool = false) -> GameAnalysisMetrics.Move {
        GameAnalysisMetrics.Move(mover: mover, loss: loss, isBook: book)
    }

    // MARK: Agrégation

    @Test("La perte moyenne est la moyenne BRUTE, sans pondération")
    func averageLossIsUnweighted() {
        let metrics = GameAnalysisMetrics.compute(
            moves: [move(.white, 0), move(.white, 10), move(.white, 20)],
            accuracyByColor: [:]
        )

        #expect(metrics.white.averageLoss == 10)
        #expect(metrics.white.classifiedCount == 3)
    }

    @Test("Les coups de théorie sont exclus de la moyenne et du compte")
    func bookMovesAreExcluded() {
        // Réciter dix coups de théorie ne dit rien du niveau : la perte y est
        // nulle par construction et gonflerait artificiellement la moyenne.
        let metrics = GameAnalysisMetrics.compute(
            moves: [move(.white, 0, book: true), move(.white, 0, book: true), move(.white, 12)],
            accuracyByColor: [:]
        )

        #expect(metrics.white.classifiedCount == 1)
        #expect(metrics.white.bookCount == 2)
        #expect(metrics.white.averageLoss == 12, "seul le coup hors théorie compte")
    }

    @Test("Chaque camp est mesuré séparément")
    func colorsAreMeasuredApart() {
        let metrics = GameAnalysisMetrics.compute(
            moves: [move(.white, 2), move(.black, 30), move(.white, 4), move(.black, 10)],
            accuracyByColor: [.white: 92, .black: 61]
        )

        #expect(metrics.white.averageLoss == 3)
        #expect(metrics.black.averageLoss == 20)
        #expect(metrics.white.accuracy == 92)
        #expect(metrics.black.accuracy == 61)
    }

    @Test("Une partie entièrement théorique ne produit aucune moyenne")
    func allBookYieldsNoAverage() {
        // Mieux vaut pas de chiffre qu'un chiffre faux : une partie qui n'a
        // jamais quitté la théorie ne permet d'estimer personne.
        let metrics = GameAnalysisMetrics.compute(
            moves: [move(.white, 0, book: true), move(.black, 0, book: true)],
            accuracyByColor: [:]
        )

        #expect(metrics.white.averageLoss == nil)
        #expect(metrics.black.averageLoss == nil)
        #expect(metrics.white.bookCount == 1)
    }

    @Test("Un camp qui n'a pas joué reste vide plutôt que nul")
    func missingSideIsNilNotZero() {
        let metrics = GameAnalysisMetrics.compute(moves: [move(.white, 5)], accuracyByColor: [:])

        #expect(metrics.black.averageLoss == nil, "zéro voudrait dire « parfait », pas « rien »")
        #expect(metrics.black.classifiedCount == 0)
    }

    @Test("Une perte négative ne crédite personne")
    func negativeLossesAreClamped() {
        // L'affinage peut rendre une évaluation légèrement meilleure après le
        // coup qu'avant : ce n'est pas un gain de probabilité offert au joueur.
        let metrics = GameAnalysisMetrics.compute(
            moves: [move(.white, -4), move(.white, 8)], accuracyByColor: [:]
        )

        #expect(metrics.white.averageLoss == 4)
    }

    @Test("Le bilan porte la version du barème")
    func metricsCarryTheVersion() {
        let metrics = GameAnalysisMetrics.compute(moves: [move(.white, 1)], accuracyByColor: [:])

        #expect(metrics.version == GameAnalysisMetrics.currentVersion)
    }

    // MARK: Persistance

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: GameRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test @MainActor
    func metricsAreWrittenOntoTheRecord() throws {
        let context = try makeContext()
        let record = GameRecord()
        context.insert(record)

        let metrics = GameAnalysisMetrics.compute(
            moves: [move(.white, 2), move(.black, 18), move(.white, 4, book: true)],
            accuracyByColor: [.white: 95, .black: 70]
        )
        #expect(record.apply(metrics, key: "abc"))

        #expect(record.analysisKey == "abc")
        #expect(record.analysisVersion == GameAnalysisMetrics.currentVersion)
        #expect(record.whiteAccuracy == 95)
        #expect(record.blackAverageLoss == 18)
        #expect(record.whiteClassifiedCount == 1)
        #expect(record.whiteBookCount == 1)
    }

    @Test("Réécrire le même bilan ne marque rien comme modifié")
    @MainActor
    func reapplyingIsANoOp() throws {
        let context = try makeContext()
        let record = GameRecord()
        context.insert(record)
        let metrics = GameAnalysisMetrics.compute(moves: [move(.white, 3)], accuracyByColor: [:])

        #expect(record.apply(metrics, key: "k"))
        #expect(record.apply(metrics, key: "k") == false, "pas d'écriture inutile en base synchronisée")
    }

    @Test("Un bilan d'un barème périmé n'est pas relu")
    @MainActor
    func staleVersionIsIgnoredOnRead() throws {
        let context = try makeContext()
        let record = GameRecord()
        context.insert(record)
        record.apply(GameAnalysisMetrics.compute(moves: [move(.white, 3)], accuracyByColor: [:]), key: "k")

        record.analysisVersion = GameAnalysisMetrics.currentVersion - 1

        #expect(record.analysisMetrics == nil,
                "mélanger deux barèmes produirait une moyenne qui ne veut rien dire")
    }

    @Test("Une partie jamais analysée n'a pas de bilan")
    @MainActor
    func unanalysedGameHasNoMetrics() throws {
        let context = try makeContext()
        let record = GameRecord()
        context.insert(record)

        #expect(record.analysisMetrics == nil)
        #expect(record.analysisKey == nil)
    }

    @Test("Le bilan relu est identique à celui écrit")
    @MainActor
    func metricsRoundTrip() throws {
        let context = try makeContext()
        let record = GameRecord()
        context.insert(record)
        let metrics = GameAnalysisMetrics.compute(
            moves: [move(.white, 2), move(.black, 18), move(.black, 0, book: true)],
            accuracyByColor: [.white: 95, .black: 70]
        )

        record.apply(metrics, key: "k")

        #expect(record.analysisMetrics == metrics)
    }
}
