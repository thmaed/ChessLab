import SwiftUI

/// Le choix de cadence d'un écran de réglage, avec son interrupteur
/// « Limite de temps » : éteint par défaut, et les cadences ne s'affichent
/// que lorsqu'il est allumé. Partagé par les quatre écrans (ordinateur, deux
/// joueurs, Chess960, variantes) et identique sur Android.
///
/// Les réglages enregistrés ne changent pas : `timeControlID` vaut `"none"`
/// quand la limite est éteinte. La DERNIÈRE cadence choisie est gardée à part
/// (clé propre à chaque écran), pour qu'éteindre puis rallumer l'interrupteur
/// la retrouve — et que l'app se souvienne de la préférence entre deux parties.
struct TimeLimitSelection: Equatable {
    var isEnabled: Bool
    /// Jamais `.none` : c'est l'interrupteur qui dit « sans limite ».
    var category: TimeControlCategory
    var preset: TimeControl
    var customMinutes: Int
    var customIncrement: Int

    /// Cadence proposée la première fois qu'on allume l'interrupteur.
    static let fallbackPreset = TimeControl.rapid10_0

    /// - Parameters:
    ///   - savedID: `timeControlID` des derniers réglages (`"none"`, `"custom"`
    ///     ou l'identifiant d'un préréglage).
    ///   - memoryKey: l'écran, pour retrouver la dernière cadence quand la
    ///     limite était éteinte.
    init(savedID: String, customMinutes: Int, customIncrement: Int, memoryKey: String, defaults: UserDefaults = .standard) {
        self.customMinutes = customMinutes
        self.customIncrement = customIncrement
        let enabled = savedID != TimeControl.none.id
        isEnabled = enabled
        let id = enabled ? savedID : (defaults.string(forKey: Self.storageKey(memoryKey)) ?? "")
        if id == "custom" {
            category = .custom
            preset = Self.fallbackPreset
        } else if let found = TimeControl.presets.first(where: { $0.id == id && $0.category != .none }) {
            category = found.category
            preset = found
        } else {
            category = Self.fallbackPreset.category
            preset = Self.fallbackPreset
        }
    }

    var isCustom: Bool { category == .custom }

    /// La cadence de la partie : `.none` tant que la limite est éteinte.
    var effective: TimeControl {
        guard isEnabled else { return .none }
        return remembered
    }

    /// La cadence choisie, même éteinte — ce qu'on rallumera.
    var remembered: TimeControl {
        isCustom ? .custom(minutes: customMinutes, incrementSeconds: customIncrement) : preset
    }

    /// Change de famille en gardant TOUJOURS une cadence valide : passer sur
    /// « Blitz » sans rien sélectionner lancerait la cadence de la famille
    /// précédente, invisible à l'écran.
    mutating func select(_ newCategory: TimeControlCategory) {
        guard newCategory != .none else { return }
        category = newCategory
        if newCategory != .custom, preset.category != newCategory {
            preset = TimeControl.presets.first { $0.category == newCategory } ?? Self.fallbackPreset
        }
    }

    mutating func select(_ control: TimeControl) {
        category = control.category
        preset = control
    }

    /// À appeler au lancement : garde la cadence choisie pour la prochaine fois.
    func remember(memoryKey: String, defaults: UserDefaults = .standard) {
        defaults.set(remembered.id, forKey: Self.storageKey(memoryKey))
    }

    private static func storageKey(_ memoryKey: String) -> String { "timeLimit.\(memoryKey)" }
}

extension TimeControlCategory {
    /// Les familles proposées une fois la limite allumée.
    static let limited: [TimeControlCategory] = [.bullet, .blitz, .rapid, .classical, .custom]

    /// Une teinte par famille, du plus nerveux au plus posé.
    var tint: Color {
        switch self {
        case .none: Theme.textSecondary
        case .bullet: Theme.rose
        case .blitz: Theme.warning
        case .rapid: Theme.accent
        case .classical: Theme.info
        case .custom: Theme.violet
        }
    }
}

/// La section « Limite de temps » : un interrupteur, puis — allumé seulement —
/// les familles de cadence et leurs préréglages, chacune dans sa couleur.
struct TimeLimitSection: View {
    @Binding var selection: TimeLimitSelection
    var tint: Color = Theme.accent

    var body: some View {
        SettingsSection(title: "Limite de temps", systemImage: "timer", tint: tint, discoverySpot: .timeLimit) {
            VStack(alignment: .leading, spacing: 12) {
                ToggleRow(label: "Limite de temps", isOn: $selection.isEnabled.animation(Theme.gentle), tint: tint)
                    .accessibilityIdentifier("timeLimitToggle")

                if selection.isEnabled {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(TimeControlCategory.limited, id: \.self) { category in
                            ChipButton(
                                label: LocalizedStringKey(category.label),
                                systemImage: category.symbolName,
                                isSelected: selection.category == category,
                                tint: category.tint
                            ) {
                                selection.select(category)
                            }
                        }
                    }

                    // Ce que la pendule coûte, dit là où on la choisit (28/10/2026) : la
                    // note vivait sous « Aides », hors de vue, et un utilisateur l'a
                    // découvert en cherchant comment revenir sur un coup.
                    Text("Avec une pendule, pas de retour en arrière : « Reprendre ici » n'est pas proposé.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("clockNoTakeback")

                    if selection.isCustom {
                        customEditor
                    } else {
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(TimeControl.presets.filter { $0.category == selection.category }) { control in
                                ChipButton(
                                    label: LocalizedStringKey(control.label),
                                    systemImage: nil,
                                    isSelected: selection.preset == control,
                                    tint: control.category.tint
                                ) {
                                    selection.select(control)
                                }
                            }
                        }
                    }
                } else {
                    Text("Aucune pendule : les deux camps jouent sans contrainte de temps, et l'on peut revenir sur un coup (‹ sous le plateau, puis « Reprendre ici »).")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .animation(Theme.gentle, value: selection.category)
        }
    }

    private var customEditor: some View {
        VStack(spacing: 10) {
            Stepper(value: $selection.customMinutes, in: 1...180) {
                HStack {
                    Text("Minutes par joueur").foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(selection.customMinutes)").foregroundStyle(Theme.textSecondary).monospacedDigit()
                }
            }
            Stepper(value: $selection.customIncrement, in: 0...60) {
                HStack {
                    Text("Incrément par coup (s)").foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(selection.customIncrement)").foregroundStyle(Theme.textSecondary).monospacedDigit()
                }
            }
        }
        .tint(TimeControlCategory.custom.tint)
        .padding(12)
        .background(Theme.surfaceElevated, in: Theme.controlShape)
        .overlay(Theme.controlShape.strokeBorder(Theme.stroke, lineWidth: 1))
    }
}
