import Foundation
import Testing
@testable import ChessLab

/// Garde de veille du Laboratoire (Lot 2.D du final-1407).
///
/// Ce qui est vraiment en jeu : `isIdleTimerDisabled` est un réglage GLOBAL du
/// système. Le laisser à `true` par mégarde, c'est un appareil qui ne s'endort
/// plus longtemps après qu'on a quitté l'écran — un bug qu'on attribue à
/// autre chose et qui vide une batterie. Ces tests portent donc surtout sur
/// l'extinction, pas sur l'allumage.
@MainActor
struct IdleTimerGuardTests {

    /// Espionne les écritures au lieu de toucher `UIApplication.shared` : un
    /// test ne doit pas laisser le simulateur éveillé derrière lui.
    private final class Spy {
        var writes: [Bool] = []
        var last: Bool? { writes.last }
    }

    private func makeGuard() -> (IdleTimerGuard, Spy) {
        let spy = Spy()
        let sut = IdleTimerGuard { spy.writes.append($0) }
        return (sut, spy)
    }

    @Test func enablingDisablesTheIdleTimer() {
        let (sut, spy) = makeGuard()

        sut.enable()

        #expect(sut.isActive)
        #expect(spy.writes == [true])
    }

    @Test func disablingRestoresTheIdleTimer() {
        let (sut, spy) = makeGuard()

        sut.enable()
        sut.disable()

        #expect(!sut.isActive)
        #expect(spy.writes == [true, false])
        #expect(spy.last == false, "l'appareil doit pouvoir s'endormir de nouveau")
    }

    /// Les appels en double sont la norme ici : la série éteint le garde à
    /// l'annulation, à la fin de boucle ET à la disparition de l'écran. Aucun
    /// de ces chemins ne doit écrire deux fois.
    @Test func repeatedCallsWriteOnlyOnTransitions() {
        let (sut, spy) = makeGuard()

        sut.enable()
        sut.enable()
        sut.disable()
        sut.disable()

        #expect(spy.writes == [true, false])
    }

    @Test func disablingWithoutEnablingNeverTouchesTheSystem() {
        let (sut, spy) = makeGuard()

        sut.disable()

        #expect(spy.writes.isEmpty, "ne jamais rendre l'appareil endormable au nom de quelqu'un d'autre")
    }

    /// Le filet : même si un chemin d'annulation oubliait le garde, sa
    /// libération doit rendre l'appareil endormable. On ne confie pas une
    /// ressource globale à la discipline des appelants.
    @Test func theGuardCannotLeakWhenItIsDeallocated() {
        let spy = Spy()
        do {
            let sut = IdleTimerGuard { spy.writes.append($0) }
            sut.enable()
        }

        #expect(spy.writes == [true, false])
    }
}

/// Réglage « empêcher la mise en veille » (Lot 2.D).
struct LabKeepAwakeSettingTests {

    /// Défaut lié à la longueur de la série : une série courte se termine
    /// avant que l'appareil ne s'endorme, et on ne prend pas la main sur un
    /// réglage système sans raison.
    @Test func aLongSeriesKeepsTheDeviceAwakeByDefault() {
        var settings = LabGameSettings.default
        settings.gameCount = 50

        #expect(settings.keepAwake)
    }

    @Test func aShortSeriesLeavesTheSystemAlone() {
        var settings = LabGameSettings.default
        settings.gameCount = 5

        #expect(!settings.keepAwake)
    }

    @Test func anExplicitChoiceAlwaysWinsOverTheDefault() {
        var settings = LabGameSettings.default
        settings.gameCount = 500
        settings.keepAwakeSetting = false
        #expect(!settings.keepAwake)

        settings.gameCount = 2
        settings.keepAwakeSetting = true
        #expect(settings.keepAwake)
    }

    /// Une série sauvegardée AVANT ce lot n'a pas le champ : elle doit encore
    /// se décoder, sinon la reprise serait perdue par la mise à jour.
    @Test func aSeriesSavedBeforeThisLotStillDecodes() throws {
        let json = """
        {"sideAEloSlider":2200,"sideBEloSlider":2000,"movetimeMs":150,
         "sideABookEnabled":true,"sideBBookEnabled":true,"bookWidth":"includeSidelines",
         "gameCount":30,"alternateColors":true,"resignationEnabled":true,
         "drawAgreementEnabled":true,"liveVisualization":true}
        """
        let decoded = try JSONDecoder().decode(LabGameSettings.self, from: Data(json.utf8))

        #expect(decoded.keepAwakeSetting == nil)
        #expect(decoded.keepAwake, "30 parties : le défaut s'applique")
    }
}
