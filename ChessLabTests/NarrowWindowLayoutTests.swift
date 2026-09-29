import SwiftUI
import Testing
@testable import ChessLab

/// La règle qui décide de l'ossature : deux colonnes ou une.
///
/// Motif : un testeur sur iPad Pro 13" a fini par isoler ce qu'il voyait
/// (28/09/2026) — ni la barre latérale ni le paysage, mais la fenêtre
/// RÉDUITE pour partager l'écran. Or iPadOS garde la classe `regular` bien
/// en dessous de la largeur d'un écran d'iPad, et l'app y montrait encore
/// deux colonnes : barre latérale de 290 pt, et au plateau moins de place
/// que sur un iPhone.
@MainActor
struct NarrowWindowLayoutTests {

    /// Le seuil est la largeur en portrait de l'iPad mini — le plus étroit
    /// des iPad. Écrit noir sur blanc : c'est CE nombre qui fait que rien ne
    /// change sur un iPad en plein écran.
    @Test func theThresholdIsTheNarrowestIPadScreen() {
        #expect(NarrowWindowLayout.regularMinimumWidth == 744)
    }

    /// Toutes les fenêtres d'iPad en plein écran gardent la disposition à deux
    /// colonnes — y compris la plus étroite, l'iPad mini en portrait, mesurée
    /// à 744 pt.
    @Test(arguments: [744.0, 834.0, 1024.0, 1133.0, 1376.0])
    func aFullScreenIPadKeepsItsTwoColumns(width: CGFloat) {
        #expect(NarrowWindowLayout.effectiveSizeClass(actual: .regular, width: width) == .regular)
    }

    /// Les largeurs relevées sur les captures du testeur — une fenêtre
    /// partagée sur un 13 pouces — passent à la disposition iPhone.
    @Test(arguments: [591.0, 678.0, 722.0, 743.0])
    func aWindowNarrowerThanAnyIPadGetsThePhoneLayout(width: CGFloat) {
        #expect(NarrowWindowLayout.effectiveSizeClass(actual: .regular, width: width) == .compact)
    }

    /// On ne touche JAMAIS à une classe déjà compacte : un iPhone reste un
    /// iPhone, et une fenêtre étroite qu'iPadOS a déjà déclarée compacte n'a
    /// pas besoin de nous.
    @Test func acompactClassIsLeftAlone() {
        #expect(NarrowWindowLayout.effectiveSizeClass(actual: .compact, width: 320) == .compact)
        #expect(NarrowWindowLayout.effectiveSizeClass(actual: .compact, width: 1376) == .compact)
    }

    /// Avant toute mesure — le tout premier rendu — on s'en remet au système.
    /// Décider sur une largeur inconnue ferait clignoter l'ossature au
    /// lancement, ce qui coûte bien plus cher que d'attendre une image.
    @Test func withoutAMeasurementTheSystemDecides() {
        #expect(NarrowWindowLayout.effectiveSizeClass(actual: .regular, width: nil) == .regular)
        #expect(NarrowWindowLayout.effectiveSizeClass(actual: .regular, width: 0) == .regular)
        #expect(NarrowWindowLayout.effectiveSizeClass(actual: nil, width: 500) == nil)
    }
}
