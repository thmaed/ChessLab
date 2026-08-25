import ChessKit
import SwiftUI

/// Réglages d'une partie de Chess960 — la grammaire visuelle de
/// ``NewGameSetupView`` (sections, chips, curseur de force, familles de
/// cadence), plus la section propre à la variante : le choix de la position
/// parmi les 960, par tirage ou par numéro.
struct Chess960SetupView: View {
    let onStart: (Chess960Settings) -> Void

    @State private var colorChoice: PlayerColorChoice
    @State private var eloSlider: Double
    @State private var timeControl: TimeControl
    @State private var isCustomTimeControlSelected: Bool
    @State private var timeCategory: TimeControlCategory
    @State private var customMinutes: Int
    @State private var customIncrement: Int
    @State private var showEvalBar: Bool
    @State private var positionNumber: Int
    @State private var numberField: String

    init(onStart: @escaping (Chess960Settings) -> Void) {
        self.onStart = onStart
        let saved = Chess960SettingsStore.load() ?? Chess960Settings()
        _colorChoice = State(initialValue: saved.resolvedColorChoice)
        _eloSlider = State(initialValue: min(
            max(saved.eloSliderValue, EngineStrength.playSliderRange.lowerBound),
            EngineStrength.playSliderRange.upperBound
        ))
        _isCustomTimeControlSelected = State(initialValue: saved.timeControlID == "custom")
        _timeControl = State(initialValue: TimeControl.presets.first { $0.id == saved.timeControlID } ?? .none)
        _timeCategory = State(initialValue: saved.timeControlID == "custom"
            ? .custom
            : (TimeControl.presets.first { $0.id == saved.timeControlID }?.category ?? TimeControlCategory.none))
        _customMinutes = State(initialValue: saved.customMinutes)
        _customIncrement = State(initialValue: saved.customIncrementSeconds)
        _showEvalBar = State(initialValue: saved.showEvalBar)
        _positionNumber = State(initialValue: saved.positionNumber)
        _numberField = State(initialValue: String(saved.positionNumber))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                positionSection

                SettingsSection(title: "Couleur", systemImage: "circle.lefthalf.filled", tint: Theme.accent) {
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

                SettingsSection(title: "Force du moteur", systemImage: "gauge.with.needle", tint: Theme.accent) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(EngineStrength(sliderValue: eloSlider).displayLabel)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Slider(value: $eloSlider, in: EngineStrength.playSliderRange, step: 50)
                            .tint(Theme.accent)
                        Text("Les Elo de Stockfish sont calibrés pour la partie classique : en 960, sans théorie à réciter, le niveau réel peut différer légèrement.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                cadenceSection

                SettingsSection(title: "Aides", systemImage: "lifepreserver", tint: Theme.accent) {
                    VStack(alignment: .leading, spacing: 10) {
                        ToggleRow(label: "Barre d'évaluation", isOn: $showEvalBar)
                        Text("L'indice et l'alerte gaffe arriveront dans une prochaine version du mode.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Chess960")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Commencer") { start() }
                    .fontWeight(.semibold)
                    .tint(Theme.accent)
                    .accessibilityIdentifier("chess960_start")
            }
        }
    }

    // MARK: Position

    private var positionSection: some View {
        SettingsSection(title: "Position de départ", systemImage: "die.face.5.fill", tint: Theme.violet) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ChipButton(label: "Aléatoire", systemImage: "die.face.5", isSelected: false) {
                        setNumber(Int.random(in: 0...959))
                    }
                    .accessibilityIdentifier("chess960_random")
                    Spacer(minLength: 0)
                    Text("n°")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    TextField("0-959", text: $numberField)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 76)
                        .padding(.vertical, 6)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(fieldIsValid ? Theme.stroke : Theme.danger, lineWidth: 1))
                        .onChange(of: numberField) { _, raw in
                            if let value = Int(raw), (0...959).contains(value) {
                                positionNumber = value
                            }
                        }
                        .accessibilityLabel("Numéro de position")
                }

                // L'aperçu : la rangée blanche de la position choisie. C'est
                // le numéro qui fait foi (partageable — « essaie la 356 ») ;
                // la rangée le rend concret d'un coup d'œil.
                HStack(spacing: 0) {
                    ForEach(Array(backRankPieces.enumerated()), id: \.offset) { _, piece in
                        PieceGlyphView(piece: piece)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .frame(height: 38)
                .padding(.vertical, 4)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(positionNumber == 518
                    ? "La 518 est la position de la partie classique."
                    : "Position \(positionNumber) sur 960 — la numérotation standard, la même que Lichess.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var fieldIsValid: Bool {
        if let value = Int(numberField), (0...959).contains(value) { return true }
        return false
    }

    private var backRankPieces: [Piece] {
        guard let rank = Chess960Position.backRank(number: positionNumber) else { return [] }
        return rank.enumerated().compactMap { index, letter in
            guard let kind = Piece.Kind(rawValue: String(letter)),
                  let square = Square("\(Character(UnicodeScalar(UInt8(97 + index))))1") as Square?
            else { return nil }
            return Piece(kind, color: .white, square: square)
        }
    }

    private func setNumber(_ value: Int) {
        positionNumber = value
        numberField = String(value)
    }

    // MARK: Cadence — même double niveau que « Contre l'ordinateur »

    private var cadenceSection: some View {
        SettingsSection(title: "Cadence", systemImage: "timer", tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 12) {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(TimeControlCategory.allCases, id: \.self) { category in
                        ChipButton(
                            label: LocalizedStringKey(category.label),
                            systemImage: category.symbolName,
                            isSelected: timeCategory == category
                        ) {
                            select(category)
                        }
                    }
                }
                switch timeCategory {
                case .none:
                    Text("Aucune pendule : les deux camps jouent sans contrainte de temps.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .custom:
                    HStack(spacing: 16) {
                        Stepper("\(customMinutes) min", value: $customMinutes, in: 1...120)
                        Stepper("+\(customIncrement) s", value: $customIncrement, in: 0...60)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                default:
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(TimeControl.presets.filter { $0.category == timeCategory }) { control in
                            ChipButton(
                                label: LocalizedStringKey(control.label),
                                systemImage: nil,
                                isSelected: !isCustomTimeControlSelected && timeControl == control
                            ) {
                                isCustomTimeControlSelected = false
                                timeControl = control
                            }
                        }
                    }
                }
            }
            .animation(Theme.gentle, value: timeCategory)
        }
    }

    private func select(_ category: TimeControlCategory) {
        timeCategory = category
        switch category {
        case .custom:
            isCustomTimeControlSelected = true
        case .none:
            isCustomTimeControlSelected = false
            timeControl = .none
        default:
            isCustomTimeControlSelected = false
            if let first = TimeControl.presets.first(where: { $0.category == category }) {
                timeControl = first
            }
        }
    }

    // MARK: Départ

    private func start() {
        var settings = Chess960Settings()
        settings.colorChoice = colorChoice.rawValue
        settings.eloSliderValue = eloSlider
        settings.timeControlID = isCustomTimeControlSelected ? "custom" : timeControl.id
        settings.customMinutes = customMinutes
        settings.customIncrementSeconds = customIncrement
        settings.showEvalBar = showEvalBar
        settings.positionNumber = positionNumber
        Chess960SettingsStore.save(settings)
        onStart(settings)
    }
}
