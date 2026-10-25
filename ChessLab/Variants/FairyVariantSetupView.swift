import ChessKit
import SwiftUI

/// Réglages d'une partie dans une variante Fairy-Stockfish — même grammaire
/// que ``Chess960SetupView``, sans la section position (fixée par la
/// variante). Un seul écran pour les SIX variantes des deux lots (voir
/// ``PlayableVariant``) : paramétré par le protocole, pas par un type concret.
struct FairyVariantSetupView: View {
    let variant: any PlayableVariant
    let onStart: (FairyVariantSettings) -> Void

    @State private var colorChoice: PlayerColorChoice
    @State private var eloSlider: Double
    @State private var timeLimit: TimeLimitSelection
    @State private var showEvalBar: Bool
    @State private var hintsEnabled: Bool
    @State private var blunderAlertEnabled: Bool
    @State private var stolenMoveTokenInterval: Int
    @State private var twoPlayers: Bool

    private var isStolenMove: Bool { variant.id == StolenMoveVariant.shared.id }

    /// Face à personne, il n'y a ni force à régler, ni couleur à choisir, ni
    /// aide à demander : ces trois sections disparaissent au lieu de proposer
    /// des réglages sans effet.
    private var hidesEngineSettings: Bool { variant.supportsTwoPlayers && twoPlayers }

    init(variant: any PlayableVariant, onStart: @escaping (FairyVariantSettings) -> Void) {
        self.variant = variant
        self.onStart = onStart
        let saved = FairyVariantSettingsStore.load(for: variant.id) ?? FairyVariantSettings()
        _colorChoice = State(initialValue: saved.resolvedColorChoice)
        _eloSlider = State(initialValue: min(
            max(saved.eloSliderValue, EngineStrength.playSliderRange.lowerBound),
            EngineStrength.playSliderRange.upperBound
        ))
        _timeLimit = State(initialValue: TimeLimitSelection(
            savedID: saved.timeControlID, customMinutes: saved.customMinutes,
            customIncrement: saved.customIncrementSeconds, memoryKey: "fairy.\(variant.id)"))
        _showEvalBar = State(initialValue: saved.showEvalBar)
        _hintsEnabled = State(initialValue: saved.hintsEnabled)
        _blunderAlertEnabled = State(initialValue: saved.blunderAlertEnabled)
        _stolenMoveTokenInterval = State(initialValue: min(
            max(saved.stolenMoveTokenInterval, StolenMoveVariant.tokenIntervalRange.lowerBound),
            StolenMoveVariant.tokenIntervalRange.upperBound
        ))
        _twoPlayers = State(initialValue: variant.supportsTwoPlayers && saved.twoPlayers)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ruleSummary

                if variant.supportsTwoPlayers {
                    SettingsSection(title: "Adversaire", systemImage: "person.2.fill", tint: variant.tint) {
                        VStack(alignment: .leading, spacing: 10) {
                            ToggleRow(label: "Deux joueurs sur cet appareil", isOn: $twoPlayers)
                            Text("Chacun son tour sur le même écran, sans ordinateur.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityIdentifier("fairyVariant_twoPlayers")
                }

                if !hidesEngineSettings {
                SettingsSection(title: "Couleur", systemImage: "circle.lefthalf.filled", tint: variant.tint) {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(PlayerColorChoice.allCases) { choice in
                            ChipButton(
                                label: LocalizedStringKey(choice.label),
                                systemImage: choice.symbolName,
                                isSelected: colorChoice == choice
                            ) {
                                colorChoice = choice
                            }
                        }
                    }
                }

                SettingsSection(title: "Force du moteur", systemImage: "gauge.with.needle", tint: variant.tint) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(EngineStrength(sliderValue: eloSlider).displayLabel)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Slider(value: $eloSlider, in: EngineStrength.playSliderRange, step: 50)
                            .tint(variant.tint)
                        // Coup Volé joue avec Stockfish STANDARD (aucune
                        // option UCI de variante n'existe pour son tour
                        // double) : le réseau NNUE habituel s'applique tel
                        // quel, contrairement aux six autres variantes.
                        if !isStolenMove {
                            Text("Les Elo sont calibrés pour la partie classique : sans réseau de neurones dédié à cette variante, le niveau réel peut différer.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                }

                TimeLimitSection(selection: $timeLimit, tint: variant.tint)

                if isStolenMove {
                    stolenMoveSection
                }

                if !hidesEngineSettings {
                    SettingsSection(title: "Aides", systemImage: "lifepreserver", tint: variant.tint) {
                        VStack(alignment: .leading, spacing: 10) {
                            ToggleRow(label: "Barre d'évaluation", isOn: $showEvalBar)
                            ToggleRow(label: "Indice (flèches des meilleurs coups)", isOn: $hintsEnabled)
                            ToggleRow(label: "Alerte en cas de coup risqué", isOn: $blunderAlertEnabled)
                        }
                    }
                }
            }
            .animation(Theme.gentle, value: twoPlayers)
            .padding(20)
        }
        .appBackground()
        .navigationTitle(Text(variant.displayName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .primaryActionBar("Commencer", tint: variant.tint, identifier: "fairyVariant_start") { start() }
    }

    private var ruleSummary: some View {
        SettingsSection(title: "Règle", systemImage: variant.icon, tint: variant.tint) {
            Text(variant.rules)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Coup Volé — cadence des jetons

    private var stolenMoveSection: some View {
        SettingsSection(title: "Jetons", systemImage: "bolt.badge.clock.fill", tint: variant.tint) {
            VStack(alignment: .leading, spacing: 10) {
                Stepper(
                    LocalizationController.string("Un jeton tous les %lld coups", stolenMoveTokenInterval),
                    value: $stolenMoveTokenInterval, in: StolenMoveVariant.tokenIntervalRange
                )
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                Text("Plus l'intervalle est court, plus les tours doubles reviennent souvent.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Départ

    private func start() {
        var settings = FairyVariantSettings()
        settings.colorChoice = colorChoice.rawValue
        settings.eloSliderValue = eloSlider
        settings.timeControlID = timeLimit.effective.id
        settings.customMinutes = timeLimit.customMinutes
        settings.customIncrementSeconds = timeLimit.customIncrement
        timeLimit.remember(memoryKey: "fairy.\(variant.id)")
        settings.showEvalBar = showEvalBar
        settings.hintsEnabled = hintsEnabled
        settings.blunderAlertEnabled = blunderAlertEnabled
        settings.stolenMoveTokenInterval = stolenMoveTokenInterval
        settings.twoPlayers = variant.supportsTwoPlayers && twoPlayers
        FairyVariantSettingsStore.save(settings, for: variant.id)
        onStart(settings)
    }
}
