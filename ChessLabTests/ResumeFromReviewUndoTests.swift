import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// « Reprendre ici » efface la fin de la partie. C'était jusqu'ici précédé
/// d'une feuille de confirmation : un TROISIÈME geste, après « choisir le
/// coup » et « reprendre ici », pour une action parfaitement défaisable.
///
/// La confirmation a été remplacée par une annulation (HIG, *Confirming
/// actions* : quand l'action est réversible, agir puis offrir d'annuler). Ces
/// tests portent sur la seule chose qui rend ce choix légitime — les coups
/// écartés doivent revenir À L'IDENTIQUE. Sans cela, on aurait simplement
/// supprimé le garde-fou.
@MainActor
struct ResumeFromReviewUndoTests {

    private static func inMemoryContext() throws -> ModelContext {
        let schema = Schema([GameRecord.self, Puzzle.self])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    /// Italienne jusqu'au 4e coup blanc : 7 demi-coups, donc une reprise au
    /// demi-coup 3 en écarte 4.
    private static let opening = ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "c2c3"]

    private static func sans(_ moves: [Move]) -> [String] { moves.map(\.san) }

    // MARK: Mode Deux joueurs

    /// Ce mode n'a pas de moteur : tout y est synchrone, donc mesurable sans
    /// la moindre attente. C'est le banc d'essai de la mécanique.
    private func twoPlayerGame() throws -> TwoPlayerViewModel {
        let vm = TwoPlayerViewModel(settings: .default, modelContext: try Self.inMemoryContext())
        for lan in Self.opening {
            vm.attemptUserMove(from: Square(String(lan.prefix(2))), to: Square(String(lan.dropFirst(2).prefix(2))))
        }
        return vm
    }

    @Test("Deux joueurs : la reprise agit sans confirmation")
    func twoPlayerResumeActsImmediately() throws {
        let vm = try twoPlayerGame()
        #expect(vm.totalPlies == 7)

        vm.review(toPly: 3)
        vm.resumeFromReview()

        #expect(vm.totalPlies == 3, "la partie doit être raccourcie tout de suite")
        #expect(vm.isReviewing == false)
    }

    @Test("Deux joueurs : les coups écartés reviennent à l'identique")
    func twoPlayerUndoRestoresTheExactMoves() throws {
        let vm = try twoPlayerGame()
        let before = Self.sans(vm.moveLog)
        let fenBefore = vm.board.position.fen

        vm.review(toPly: 3)
        vm.resumeFromReview()
        #expect(vm.resumeUndo?.discardedCount == 4)

        vm.cancelResumeFromReview()

        #expect(Self.sans(vm.moveLog) == before, "l'annulation doit rendre la partie EXACTEMENT telle qu'elle était")
        #expect(vm.board.position.fen == fenBefore, "et la position avec elle")
        #expect(vm.resumeUndo == nil, "l'offre ne vaut qu'une fois")
    }

    /// Aucune offre ne doit apparaître quand rien n'a été écarté — sinon la
    /// barre porterait une pastille « Annuler » sans objet. Consulter la
    /// position vive ramène au direct : il n'y a alors rien à reprendre.
    @Test("Deux joueurs : sans coup écarté, aucune offre d'annulation")
    func twoPlayerNoOfferWithoutDiscardedMoves() throws {
        let vm = try twoPlayerGame()
        vm.review(toPly: 7)
        #expect(vm.canResumeFromReview == false)
        vm.resumeFromReview()
        #expect(vm.resumeUndo == nil)
        #expect(vm.totalPlies == 7)

        // Un seul coup écarté suffit en revanche à ouvrir l'offre.
        vm.review(toPly: 6)
        vm.resumeFromReview()
        #expect(vm.totalPlies == 6)
        #expect(vm.resumeUndo?.discardedCount == 1)
    }

    /// Jouer, c'est accepter la ligne reprise. L'offre doit disparaître, sinon
    /// « Annuler » ressusciterait des coups qui ne suivent plus la partie.
    @Test("Deux joueurs : jouer un coup referme l'offre d'annulation")
    func twoPlayerPlayingAMoveClosesTheOffer() throws {
        let vm = try twoPlayerGame()
        vm.review(toPly: 3)
        vm.resumeFromReview()
        #expect(vm.resumeUndo != nil)

        // Après 1.e4 e5 2.Cf3 le trait est aux NOIRS : 2...d6, la Philidor.
        vm.attemptUserMove(from: Square("d7"), to: Square("d6"))
        #expect(vm.moveLog.last?.san == "d6")
        #expect(vm.resumeUndo == nil, "la ligne reprise est engagée : l'annulation n'a plus de sens")
    }

    /// Une reprise de coup ordinaire raccourcit la partie une seconde fois :
    /// les coups mis de côté ne lui correspondraient plus.
    @Test("Deux joueurs : une seconde troncature invalide l'offre")
    func twoPlayerASecondTruncationInvalidatesTheOffer() throws {
        let vm = try twoPlayerGame()
        vm.review(toPly: 5)
        vm.resumeFromReview()
        #expect(vm.resumeUndo?.discardedCount == 2)

        vm.review(toPly: 2)
        vm.resumeFromReview()
        #expect(vm.resumeUndo?.discardedCount == 3, "l'offre porte sur la DERNIÈRE reprise, pas sur l'avant-dernière")

        vm.cancelResumeFromReview()
        #expect(vm.totalPlies == 5, "on remonte d'un cran, pas jusqu'à la partie d'origine")
    }

    // MARK: Mode Jouer

    /// Partie reconstruite depuis une autosauvegarde : c'est le seul moyen de
    /// poser une suite de coups des DEUX couleurs sans faire tourner le
    /// moteur, dont les réponses asynchrones rendraient la mesure incertaine.
    private func playGame() throws -> PlayViewModel {
        let autosave = PlayGameAutosave(
            settings: PlayGameSettings(),
            resolvedUserColorRaw: Piece.Color.white.rawValue,
            moveLANs: Self.opening,
            whiteRemaining: nil,
            blackRemaining: nil,
            savedAt: Date(timeIntervalSince1970: 0)
        )
        return try #require(PlayViewModel(resuming: autosave, modelContext: try Self.inMemoryContext(), startsEngine: false))
    }

    @Test("Jouer : la reprise agit sans confirmation et reste défaisable")
    func playResumeIsImmediateAndUndoable() throws {
        let vm = try playGame()
        #expect(vm.totalPlies == 7)
        let before = Self.sans(vm.moveLog)

        // Demi-coup 3 : c'est de nouveau au joueur (blanc) de jouer, donc le
        // moteur ne s'invite pas dans la mesure.
        vm.review(toPly: 3)
        vm.resumeFromReview()

        #expect(vm.totalPlies == 3)
        #expect(vm.isReviewing == false)
        #expect(vm.resumeUndo?.discardedCount == 4)

        vm.cancelResumeFromReview()
        #expect(Self.sans(vm.moveLog) == before)
        #expect(vm.resumeUndo == nil)
    }

    /// Revue du 24/08 : « Annuler la reprise » pouvait RESSUSCITER une partie
    /// terminée. Un abandon ne se lit pas sur l'échiquier, et `rebuild`
    /// recalcule `outcome` depuis la seule position : sans garde, annuler
    /// après l'abandon effaçait le résultat enregistré.
    @Test("Jouer : annuler la reprise ne ressuscite pas une partie abandonnée")
    func playCancelDoesNotResurrectAResignedGame() throws {
        let vm = try playGame()
        vm.review(toPly: 3)
        vm.resumeFromReview()
        #expect(vm.resumeUndo != nil)

        vm.userResigns()
        #expect(vm.outcome != nil)

        vm.cancelResumeFromReview()
        #expect(vm.outcome != nil, "l'abandon doit survivre à l'annulation")
        #expect(vm.totalPlies == 3, "la partie ne doit pas être reconstruite")
    }

    /// Même trou en Deux joueurs, avec la nulle par accord — elle non plus ne
    /// se lit pas sur l'échiquier, et la partie finie est déjà ENREGISTRÉE :
    /// la faire revivre l'inscrirait une seconde fois à la bibliothèque.
    @Test("Deux joueurs : annuler la reprise ne rouvre pas une nulle convenue")
    func twoPlayerCancelDoesNotReopenAnAgreedDraw() throws {
        let vm = try twoPlayerGame()
        vm.review(toPly: 3)
        vm.resumeFromReview()
        #expect(vm.resumeUndo != nil)

        vm.agreeToDraw()
        #expect(vm.outcome != nil)

        vm.cancelResumeFromReview()
        #expect(vm.outcome != nil, "la nulle convenue doit survivre à l'annulation")
        #expect(vm.totalPlies == 3)
    }

    /// Le garde-fou n'a pas sauté : la reprise reste refusée là où elle
    /// l'était déjà (avec pendule, partie finie, position vive).
    @Test("Jouer : les conditions de reprise sont inchangées")
    func playTheGuardsAreUnchanged() throws {
        let vm = try playGame()
        #expect(vm.canResumeFromReview == false, "sur la position vive, rien à reprendre")

        vm.review(toPly: 3)
        #expect(vm.canResumeFromReview)

        vm.resumeFromReview()
        #expect(vm.canResumeFromReview == false, "après reprise on est revenu au direct")
    }
}
