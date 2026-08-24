import SwiftUI

/// Ce qu'une tuile de statistique du Laboratoire raconte quand on la touche.
///
/// « LOS », « écart Elo ± 42 » : ces libellés viennent du vocabulaire des
/// tournois de moteurs. Ils sont exacts et compacts — et parfaitement
/// hermétiques à qui ne l'a jamais croisé. Plutôt que de les allonger (ils ne
/// tiendraient plus dans la tuile) ou de les diluer, chaque tuile porte son
/// explication et la donne sur demande.
struct LabStatExplanation {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
}

/// `@MainActor` parce que `LocalizedStringKey` n'est pas `Sendable` : ces
/// constantes ne sont lues que depuis des vues, qui y sont déjà.
@MainActor
extension LabStatExplanation {

    static let score = LabStatExplanation(
        title: "Score de A",
        detail: """
        Les points marqués par le camp A, en pourcentage du maximum possible : \
        un gain vaut 1 point, une nulle ½, une défaite 0.

        50 % veut dire que les deux réglages font jeu égal. C'est la mesure \
        d'où tout le reste est déduit, écart Elo compris.
        """
    )

    static let winDrawLoss = LabStatExplanation(
        title: "Victoires · Nulles · Défaites",
        detail: """
        Le détail des résultats, toujours du point de vue de A.

        Les nulles comptent pour une demi-victoire dans le score, mais elles \
        sont ignorées par le LOS : elles ne disent rien sur qui est le plus fort.
        """
    )

    static let elo = LabStatExplanation(
        title: "Écart Elo",
        detail: """
        La différence de force entre A et B, convertie du score en points Elo. \
        Positive si A est devant.

        Le « ± » est la marge de l'intervalle de confiance à 95 % : la vraie \
        valeur a 19 chances sur 20 de s'y trouver. Cette marge se resserre à \
        mesure que les parties s'accumulent — c'est elle, et non l'écart \
        lui-même, qui dit si la série a assez tourné.
        """
    )

    static let likelihoodOfSuperiority = LabStatExplanation(
        title: "LOS — Likelihood of Superiority",
        detail: """
        La probabilité que A soit RÉELLEMENT plus fort que B, et non que \
        l'écart observé vienne du hasard.

        Elle ne se calcule que sur les parties décisives : les nulles n'y \
        entrent pas. En dessous de 95 %, la série n'a pas encore tranché, même \
        si l'écart Elo paraît net. À 50 %, les deux camps sont indiscernables.
        """
    )

    static let movesPerGame = LabStatExplanation(
        title: "Coups par partie",
        detail: """
        La longueur moyenne des parties terminées, en coups complets (un coup \
        = un demi-coup blanc plus un demi-coup noir).

        Des parties courtes vont souvent avec des gains nets ; des parties \
        longues, avec des positions équilibrées ou des finales disputées.
        """
    )

    static let distribution = LabStatExplanation(
        title: "Répartition",
        detail: """
        La même chose que « V · N · D », vue comme une barre : la part verte \
        est ce que A a gagné, la grise les nulles, la rouge ce que B a gagné.

        Une bande grise très large signale des réglages trop proches pour se \
        départager — ou un temps de réflexion trop court pour que la \
        différence s'exprime.
        """
    )

    static let progression = LabStatExplanation(
        title: "Progression de A",
        detail: """
        Le score de A recalculé après chaque partie, et non partie par partie : \
        la courbe part donc de très haut ou de très bas, puis se calme.

        La zone claire autour d'elle est l'intervalle de confiance à 95 %. \
        Tant qu'elle chevauche la ligne des 50 %, la série n'a pas tranché. \
        C'est le rétrécissement de cette bande qui dit quand s'arrêter.
        """
    )

    static let gamesPlayed = LabStatExplanation(
        title: "Parties jouées",
        detail: """
        Le nombre de parties terminées, sur le total demandé au lancement de \
        la série.

        Les statistiques ci-dessus se recalculent après chacune : elles sont \
        volatiles au début et se stabilisent ensuite.
        """
    )
}

/// Une tuile de statistique du Laboratoire. Se touche pour obtenir son
/// explication, dans une bulle ancrée SUR la tuile — c'est ce qui permet de
/// garder la valeur sous les yeux pendant qu'on lit ce qu'elle veut dire.
struct LabStatTile: View {
    let value: String
    let label: LocalizedStringKey
    let icon: String
    let tint: Color
    let explanation: LabStatExplanation

    @State private var showsExplanation = false
    @State private var openedByHold = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        tile
            .contentShape(Rectangle())
            .explanationBubble(
                explanation: explanation,
                isPresented: $showsExplanation,
                openedByHold: $openedByHold,
                dynamicTypeSize: dynamicTypeSize
            )
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Touchez pour savoir ce que mesure cette statistique")
    }

    private var tile: some View {
        Group {
            HStack(spacing: 12) {
                IconBadge(systemImage: icon, tint: tint, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        // La VALEUR avait déjà son facteur de réduction, pas le
                        // libellé : il se coupait net dans une tuile de 89 pt
                        // (62 en Display Zoom) — Lot 3.5.
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.cardGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
            // INCRUSTÉ dans le coin, et non posé dans la rangée : placé en
            // ligne, ce picto coûtait 26 pt de large et coupait les SIX
            // libellés sur un iPhone en Zoom d'affichage — mesuré, la tuile
            // n'y offre que 62 pt au libellé et « parties jouées » en réclame
            // 74. En incrustation il ne prend aucune largeur, et la géométrie
            // reste celle d'avant.
            .overlay(alignment: .topTrailing) {
                Image(systemName: "questionmark.circle")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(7)
            }
        }
    }
}

/// Contenu de la bulle, partagé par les tuiles et les en-têtes de section.
struct LabExplanationCard: View {
    let explanation: LabStatExplanation
    let dynamicTypeSize: DynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(explanation.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(explanation.detail)
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // La bulle ne se dimensionne pas toute seule à son contenu : sans
        // largeur imposée elle s'étale, et sans hauteur elle se coupe aux
        // très grands corps de texte.
        .frame(width: 300)
        .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? 460 : 320)
        .background(Theme.surface)
        .presentationBackground(Theme.surface)
    }
}

/// En-tête de section du Laboratoire, avec la même bulle d'explication que
/// les tuiles : « Progression de A » se comprend, mais la bande claire qui
/// entoure la courbe n'est légendée nulle part.
struct LabSectionHeader: View {
    let title: LocalizedStringKey
    let explanation: LabStatExplanation

    @State private var showsExplanation = false
    @State private var openedByHold = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        header
            .contentShape(Rectangle())
            .explanationBubble(
                explanation: explanation,
                isPresented: $showsExplanation,
                openedByHold: $openedByHold,
                dynamicTypeSize: dynamicTypeSize
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Touchez pour savoir ce que montre cette section")
    }

    private var header: some View {
        Group {
            HStack(spacing: 6) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Image(systemName: "questionmark.circle")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            // Cible tactile : le texte d'un en-tête fait moins de 20 pt de
            // haut, très en dessous des 44 pt du minimum HIG.
            .frame(minHeight: 30, alignment: .leading)
        }
    }
}


// MARK: Ouverture et fermeture de la bulle

private extension View {

    /// Une bulle d'explication qui ne s'installe JAMAIS : c'est une aide de
    /// passage, pas un panneau à refermer. Elle part de trois façons, selon la
    /// manière dont elle est venue.
    ///
    /// - Un **appui maintenu** la montre tant que le doigt reste posé : lever
    ///   le doigt la referme. C'est le geste « je jette un œil » — il ne coûte
    ///   pas de fermeture.
    /// - Un **toucher simple** la laisse ouverte, mais pas indéfiniment : elle
    ///   s'efface d'elle-même au bout de ``bubbleLifetime``.
    /// - Un **toucher suivant**, où que ce soit, la referme immédiatement —
    ///   c'est le comportement natif de la bulle, son voile capte le geste.
    func explanationBubble(
        explanation: LabStatExplanation,
        isPresented: Binding<Bool>,
        openedByHold: Binding<Bool>,
        dynamicTypeSize: DynamicTypeSize
    ) -> some View {
        modifier(ExplanationBubbleModifier(
            explanation: explanation,
            isPresented: isPresented,
            openedByHold: openedByHold,
            dynamicTypeSize: dynamicTypeSize
        ))
    }
}

private struct ExplanationBubbleModifier: ViewModifier {
    let explanation: LabStatExplanation
    @Binding var isPresented: Bool
    @Binding var openedByHold: Bool
    let dynamicTypeSize: DynamicTypeSize

    /// Le temps que la bulle reste seule à l'écran après un toucher simple.
    ///
    /// Ces textes font deux courts paragraphes : dix secondes suffisent à les
    /// parcourir sans les apprendre par cœur. Une durée plus courte
    /// arracherait la bulle en pleine lecture ; plus longue, elle cesserait
    /// d'être « de passage ». Qui veut relire retouche la tuile.
    private static let lifetime: Duration = .seconds(10)

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                openedByHold = false
                isPresented = true
            }
            // `minimumDuration` fixe le moment où l'appui devient un MAINTIEN.
            // En deçà, c'est un toucher, et `onTapGesture` s'en charge : les
            // deux gestes ne se recouvrent pas.
            .onLongPressGesture(minimumDuration: 0.3) {
                openedByHold = true
                isPresented = true
            } onPressingChanged: { isPressing in
                // Doigt levé : on ne referme QUE ce que le maintien a ouvert,
                // sinon le relâchement d'un toucher simple fermerait la bulle
                // dans la foulée de son ouverture.
                if !isPressing, openedByHold {
                    isPresented = false
                    openedByHold = false
                }
            }
            .popover(isPresented: $isPresented) {
                LabExplanationCard(explanation: explanation, dynamicTypeSize: dynamicTypeSize)
                    // Sans cette adaptation, iOS transforme la bulle en feuille
                    // plein écran sur iPhone : la valeur qu'on cherche à
                    // comprendre disparaît alors de l'écran.
                    .presentationCompactAdaptation(.popover)
                    .task {
                        // Le maintien a sa propre fin — le doigt qui se lève.
                        guard !openedByHold else { return }
                        try? await Task.sleep(for: Self.lifetime)
                        guard !Task.isCancelled else { return }
                        isPresented = false
                    }
            }
    }
}
