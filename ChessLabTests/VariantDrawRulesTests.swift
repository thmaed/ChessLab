import ChessKit
import Testing
@testable import ChessLab

/// Les deux façons dont une partie de variante peut finir à égalité : la
/// nulle PROPOSÉE, et la nulle CONSTATÉE faute de matériel.
///
/// La seconde est celle qui demande de la prudence : « plus assez pour
/// mater » suppose que gagner, c'est mater — faux dans la moitié du hub.
@Suite
struct VariantDrawRulesTests {

    // MARK: Nulle proposée

    @Test("L'ordinateur accepte une nulle quand il ne se voit pas mieux")
    func engineAcceptsNearEquality() {
        #expect(VariantDrawRules.engineAcceptsDraw(lastEngineEvalCp: 0))
        #expect(VariantDrawRules.engineAcceptsDraw(lastEngineEvalCp: 50))
        #expect(VariantDrawRules.engineAcceptsDraw(lastEngineEvalCp: -50))
    }

    @Test("Il refuse dès qu'il se voit mieux — ou qu'il n'a pas encore d'avis")
    func engineDeclinesWhenBetterOrSilent() {
        #expect(!VariantDrawRules.engineAcceptsDraw(lastEngineEvalCp: 51))
        #expect(!VariantDrawRules.engineAcceptsDraw(lastEngineEvalCp: -300))
        #expect(!VariantDrawRules.engineAcceptsDraw(lastEngineEvalCp: nil),
                "sans évaluation, il n'a pas d'avis : il continue")
    }

    // MARK: Matériel insuffisant, variante par variante

    @Test(
        "Les variantes qui se gagnent PAR LE MAT déclarent le matériel insuffisant",
        arguments: ["barricades", "randombarricades", "crazyhouse", "stolenmove", "chess960"]
    )
    func matingVariantsDeclareIt(id: String) {
        #expect(VariantDrawRules.declaresInsufficientMaterial(variantID: id))
    }

    /// Chacune gagne AUTREMENT que par le mat, et roi + fou y suffit encore.
    @Test(
        "Les autres s'y refusent, et pour de bonnes raisons",
        arguments: [
            "atomic",        // une explosion tue le roi sans le mater
            "antichess",     // le but est inversé
            "racingkings",   // on gagne en atteignant la 8e rangée
            "kingofthehill", // on gagne en atteignant le centre
            "threecheck",    // trois échecs suffisent, un fou seul les donne
            "horde",         // deux camps, deux matériels, deux buts
            "duck",          // on CAPTURE le roi : un fou seul le prend
        ]
    )
    func nonMatingVariantsRefuseIt(id: String) {
        #expect(!VariantDrawRules.declaresInsufficientMaterial(variantID: id))
    }

    // MARK: Sur des positions réelles

    private let kingAndBishopVsKing = "4k3/8/8/8/8/8/8/3BK3 w - - 0 1"
    private let kingAndRookVsKing = "4k3/8/8/8/8/8/8/3RK3 w - - 0 1"

    @Test("Roi + fou contre roi est nul en Barricades")
    func bishopEndingIsDrawnInBarricades() {
        #expect(VariantDrawRules.isInsufficientMaterial(
            fen: kingAndBishopVsKing, variantID: "barricades", pocketIsEmpty: true
        ))
    }

    @Test("Roi + tour contre roi ne l'est pas : cette finale se gagne")
    func rookEndingIsNotDrawn() {
        #expect(!VariantDrawRules.isInsufficientMaterial(
            fen: kingAndRookVsKing, variantID: "barricades", pocketIsEmpty: true
        ))
    }

    @Test("Les murs ne comptent pas comme du matériel")
    func wallsAreNotMaterial() {
        // Même finale, avec trois murs sur le plateau : toujours nulle.
        let withWalls = "4k3/8/1W6/4W3/3W4/8/8/3BK3 w - - 0 1"
        #expect(VariantDrawRules.isInsufficientMaterial(
            fen: withWalls, variantID: "randombarricades", pocketIsEmpty: true
        ), "un mur n'est pas une pièce, il ne mate personne")
    }

    @Test("Une réserve GARNIE interdit la nulle par matériel en Crazyhouse")
    func crazyhousePocketBlocksTheDraw() {
        let fen = "4k3/8/8/8/8/8/8/3BK3[Q] w - - 0 1"
        #expect(!VariantDrawRules.isInsufficientMaterial(
            fen: fen, variantID: "crazyhouse", pocketIsEmpty: false
        ), "une dame en main se repose et mate")
        #expect(VariantDrawRules.isInsufficientMaterial(
            fen: kingAndBishopVsKing, variantID: "crazyhouse", pocketIsEmpty: true
        ), "les deux mains vides, la finale est bien nulle")
    }

    @Test("L'Atomique ne déclare RIEN : roi + fou y gagne encore")
    func atomicNeverDeclaresIt() {
        #expect(!VariantDrawRules.isInsufficientMaterial(
            fen: kingAndBishopVsKing, variantID: "atomic", pocketIsEmpty: true
        ))
    }

    // MARK: Le raccord avec la fin de partie des variantes

    @Test("Barricades conclut la nulle sur une finale roi + fou")
    func barricadesEndsOnInsufficientMaterial() throws {
        let outcome = try #require(EngineLegalityVariant.barricades.outcome(
            afterFEN: kingAndBishopVsKing, legalMovesForNextMover: ["e8d7"], inCheck: false
        ), "la partie doit s'arrêter même s'il reste des coups à jouer")
        #expect(outcome.winner == nil)
    }

    @Test("L'Atomique laisse la partie continuer sur la même finale")
    func atomicKeepsPlaying() {
        #expect(EngineLegalityVariant.atomic.outcome(
            afterFEN: kingAndBishopVsKing, legalMovesForNextMover: ["e8d7"], inCheck: false
        ) == nil)
    }
}
