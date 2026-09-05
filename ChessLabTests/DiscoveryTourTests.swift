import SwiftUI
import Testing
@testable import ChessLab

/// La géométrie de la visite guidée — chaque règle ici est le contre-exemple
/// d'un bug déjà payé, et ces tests sont la seule mémoire qui survive aux
/// relectures « simplificatrices ».
@Suite struct DiscoveryTourGeometryTests {

    private let screen = CGSize(width: 390, height: 844)

    @Test("Le côté choisi est celui qui a le plus de place, pas la moitié du trou")
    func sideMeasuresBothSides() {
        // Cible HAUTE et GRANDE : son bord bas (560) dépasse le milieu de
        // l'écran (422). La règle naïve « trou dans la moitié haute ? »
        // répondrait non (midY = 330 < 422 → haute… selon la variante) ou
        // enverrait la carte au-dessus dans 100 pt de vide. La mesure des
        // deux côtés envoie la carte EN DESSOUS (284 pt nets contre 41).
        let tallHigh = CGRect(x: 20, y: 100, width: 350, height: 460)
        #expect(DiscoveryGeometry.side(
            hole: tallHigh, screen: screen, topInset: 59, bottomInset: 34
        ) == .below)

        // Symétrique : cible basse et grande → au-dessus. (Assez de place
        // nette en haut — 321 pt — pour ne pas tomber dans le repli centré.)
        let tallLow = CGRect(x: 20, y: 380, width: 350, height: 380)
        #expect(DiscoveryGeometry.side(
            hole: tallLow, screen: screen, topInset: 59, bottomInset: 34
        ) == .above)
    }

    @Test("Une cible plus grande que l'écran moins la réserve centre la carte")
    func oversizedTargetCentersTheCard() {
        // La section « Force du moteur » déborde de l'écran : aucun côté ne
        // peut loger les 250 pt de carte — le seul rendu qui ne rogne rien
        // est la carte centrée par-dessus (constaté en capture, étape 2).
        let oversized = CGRect(x: 20, y: 240, width: 350, height: 700)
        #expect(DiscoveryGeometry.side(
            hole: oversized, screen: screen, topInset: 59, bottomInset: 34
        ) == .centered)
    }

    @Test("Les insets comptent : une cible haute ne pousse plus la carte sous la barre d'état")
    func insetsShrinkTheUsableRoom() {
        // 260 pt bruts au-dessus, mais 201 nets : sous la réserve de 250.
        // Sans les insets, side() aurait dit « au-dessus » et la carte
        // mordait l'heure (payé, capture étape 2 v1).
        let high = CGRect(x: 20, y: 260, width: 350, height: 420)
        #expect(DiscoveryGeometry.side(
            hole: high, screen: screen, topInset: 59, bottomInset: 34
        ) != .above)
    }

    @Test("La flèche cède sa longueur avant que la carte cède sa hauteur")
    func gapYieldsBeforeCardHeight() {
        // Beaucoup de place : le gap plafonne (la flèche n'a pas besoin
        // d'être un boulevard).
        #expect(DiscoveryGeometry.effectiveGap(available: 600) == 72)
        // Place comptée : le gap fond jusqu'au plancher de 22 pt — une
        // flèche courte n'est pas un bug, une carte rognée en est un.
        #expect(DiscoveryGeometry.effectiveGap(available: 260) == 22)
        #expect(DiscoveryGeometry.effectiveGap(available: 0) == 22)
        // Entre les deux : exactement la place moins la réserve de carte.
        #expect(DiscoveryGeometry.effectiveGap(available: 300) == 50)
    }

    @Test("Le bow s'incline à l'opposé du bord le plus proche")
    func bowLeansAwayFromNearestEdge() {
        #expect(DiscoveryGeometry.bowSign(holeMidX: 350, screenWidth: 390) == -1)
        #expect(DiscoveryGeometry.bowSign(holeMidX: 60, screenWidth: 390) == 1)
        // Pile au centre : penche à droite (seuil volontairement à 0,55).
        #expect(DiscoveryGeometry.bowSign(holeMidX: 195, screenWidth: 390) == 1)
    }

    @Test("Le trou du voile est animable — c'est lui qui glisse d'une étape à l'autre")
    func scrimHoleIsAnimatable() {
        var shape = DiscoveryScrimShape(
            hole: CGRect(x: 10, y: 20, width: 100, height: 50), cornerRadius: 14
        )
        let data = shape.animatableData
        #expect(data.first.first == 10 && data.first.second == 20)
        #expect(data.second.first == 100 && data.second.second == 50)
        // L'aller-retour est exact : sans lui, l'interpolation de SwiftUI
        // n'aurait aucune prise et la suite de marques redeviendrait un
        // diaporama.
        shape.animatableData = AnimatablePair(
            AnimatablePair(30, 40), AnimatablePair(200, 80)
        )
        #expect(shape.hole == CGRect(x: 30, y: 40, width: 200, height: 80))
    }
}

// `.serialized` : deux tests de cette suite touchent la MÊME clé
// UserDefaults (l'empreinte « vue ») — en parallèle, le nettoyage de l'un
// tombait entre le markSeen et le shouldOffer de l'autre.
@Suite(.serialized) struct DiscoveryTourStepsTests {

    @Test("Les étapes forment trois sections ordonnées, ids croissants")
    @MainActor func stepsAreWellFormed() {
        let tour = DiscoveryTourController()
        #expect(tour.steps.count == 11)
        #expect(tour.steps.map(\.id) == Array(0..<11))
        // L'ordre du contrat : ce qu'on s'apprête à toucher, puis les
        // affichages, puis les autres écrans, et le « ? » qui ramène tout.
        #expect(tour.steps.first?.spot == .playTile)
        #expect(tour.steps.last?.spot == .helpButton)
        // Les étapes sans cible sont VOULUES (contrôles UIKit non taguables,
        // reprise absente d'une installation neuve) — pas plus de trois.
        #expect(tour.steps.filter { $0.spot == nil }.count == 3)
    }

    @Test("Avancer au bout termine ; Passer compte comme vue")
    @MainActor func lifecycle() {
        let tour = DiscoveryTourController()
        tour.start()
        #expect(tour.isActive)
        for _ in tour.steps { tour.advance() }
        #expect(!tour.isActive)

        tour.start(at: 5)
        #expect(tour.currentStepIndex == 5)
        tour.skip()
        #expect(!tour.isActive)
        // Nettoyage : ces deux fins ont posé l'empreinte « vue » dans les
        // UserDefaults du processus de test.
        UserDefaults.standard.removeObject(forKey: "discoveryTourSeenInstallStamp")
    }

    @Test("L'empreinte d'installation, pas un booléen : vue ↔ plus proposée")
    func installFingerprint() {
        // L'invariant premier : l'empreinte EXISTE. Sans elle, la visite ne
        // se proposerait jamais — silencieusement.
        #expect(DiscoveryTourMemory.installStamp != nil, "conteneur Documents sans date de création")
        UserDefaults.standard.removeObject(forKey: "discoveryTourSeenInstallStamp")
        #expect(DiscoveryTourMemory.shouldOffer, "conteneur jamais estampillé → proposer")
        DiscoveryTourMemory.markSeen()
        #expect(!DiscoveryTourMemory.shouldOffer, "même conteneur → silence")
        UserDefaults.standard.removeObject(forKey: "discoveryTourSeenInstallStamp")
    }
}
