import SwiftUI

/// Écran de configuration d'une partie "deux humains sur le même appareil".
struct TwoPlayerSetupView: View {
    let onStart: (TwoPlayerGameSettings) -> Void

    @State private var whiteName: String
    @State private var blackName: String
    @State private var rotationMode: TwoPlayerGameSettings.RotationMode
    @State private var timeControl: TimeControl
    @State private var isCustomTimeControlSelected: Bool
    @State private var customMinutes: Int
    @State private var customIncrement: Int
    /// Famille de cadence affichée — voir `NewGameSetupView`.
    @State private var timeCategory: TimeControlCategory

    init(onStart: @escaping (TwoPlayerGameSettings) -> Void) {
        self.onStart = onStart
        let saved = TwoPlayerSettingsStore.load() ?? .default

        _whiteName = State(initialValue: saved.whiteName)
        _blackName = State(initialValue: saved.blackName)
        _rotationMode = State(initialValue: saved.rotationMode)
        _isCustomTimeControlSelected = State(initialValue: saved.timeControlID == "custom")
        _timeControl = State(initialValue: TimeControl.presets.first { $0.id == saved.timeControlID } ?? .none)
        _timeCategory = State(initialValue: saved.timeControlID == "custom"
            ? .custom
            : (TimeControl.presets.first { $0.id == saved.timeControlID }?.category ?? TimeControlCategory.none))
        _customMinutes = State(initialValue: saved.customMinutes)
        _customIncrement = State(initialValue: saved.customIncrementSeconds)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(title: "Joueurs", systemImage: "person.2.fill", tint: Theme.info) {
                    VStack(alignment: .leading, spacing: 12) {
                        nameField(label: "Blancs", text: $whiteName)
                        nameField(label: "Noirs", text: $blackName)

                        Button {
                            swap(&whiteName, &blackName)
                        } label: {
                            Label("Inverser les couleurs", systemImage: "arrow.left.arrow.right")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }

                SettingsSection(title: "Orientation du plateau", systemImage: "rectangle.portrait.rotate", tint: Theme.info) {
                    FlowLayout(spacing: 8) {
                        ChipButton(
                            label: "Face à face (pivote)",
                            systemImage: "arrow.triangle.2.circlepath",
                            isSelected: rotationMode == .faceToFace
                        ) {
                            rotationMode = .faceToFace
                        }
                        ChipButton(
                            label: "Côte à côte (fixe)",
                            systemImage: nil,
                            isSelected: rotationMode == .fixed
                        ) {
                            rotationMode = .fixed
                        }
                        ChipButton(
                            label: "Table (icônes retournées)",
                            systemImage: nil,
                            isSelected: rotationMode == .tabletop
                        ) {
                            rotationMode = .tabletop
                        }
                    }
                }

                SettingsSection(title: "Cadence", systemImage: "timer", tint: Theme.info) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Même modèle à deux niveaux que « Nouvelle partie » :
                        // famille, puis cadence dans la famille.
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
                            customTimeControlEditor

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
            .padding(20)
            .padding(.bottom, 20)
        }
        .appBackground()
        .navigationTitle("Deux joueurs")
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Commencer") { start() }
                    .fontWeight(.semibold)
                    .tint(Theme.accent)
            }
        }
    }

    private func nameField(label: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
            TextField(label, text: text, prompt: Text(label).foregroundStyle(Theme.textTertiary))
                .labelsHidden()
                .foregroundStyle(Theme.textPrimary)
                .padding(10)
                .background(Theme.surfaceElevated, in: Theme.controlShape)
                .overlay(Theme.controlShape.strokeBorder(Theme.stroke, lineWidth: 1))
        }
    }

    /// Change de famille en gardant toujours une cadence valide.
    private func select(_ category: TimeControlCategory) {
        timeCategory = category
        switch category {
        case .none:
            isCustomTimeControlSelected = false
            timeControl = .none
        case .custom:
            isCustomTimeControlSelected = true
        default:
            isCustomTimeControlSelected = false
            if timeControl.category != category {
                timeControl = TimeControl.presets.first { $0.category == category } ?? .none
            }
        }
    }

    private var customTimeControlEditor: some View {
        VStack(spacing: 10) {
            Stepper(value: $customMinutes, in: 1...180) {
                HStack {
                    Text("Minutes par joueur")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(customMinutes)")
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                }
            }
            Stepper(value: $customIncrement, in: 0...60) {
                HStack {
                    Text("Incrément par coup (s)")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(customIncrement)")
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                }
            }
        }
        .tint(Theme.accent)
        .padding(12)
        .background(Theme.surfaceElevated, in: Theme.controlShape)
        .overlay(Theme.controlShape.strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private var effectiveTimeControl: TimeControl {
        isCustomTimeControlSelected ? .custom(minutes: customMinutes, incrementSeconds: customIncrement) : timeControl
    }

    private func start() {
        let settings = TwoPlayerGameSettings(
            whiteName: whiteName.trimmingCharacters(in: .whitespaces).isEmpty ? "Blancs" : whiteName,
            blackName: blackName.trimmingCharacters(in: .whitespaces).isEmpty ? "Noirs" : blackName,
            rotationMode: rotationMode,
            timeControlID: effectiveTimeControl.id,
            customMinutes: customMinutes,
            customIncrementSeconds: customIncrement
        )
        TwoPlayerSettingsStore.save(settings)
        onStart(settings)
    }
}
