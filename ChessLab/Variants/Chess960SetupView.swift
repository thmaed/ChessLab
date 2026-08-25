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
    /// La rangée AFFICHÉE — reflète `positionNumber` la plupart du temps,
    /// mais peut s'en écarter momentanément pendant une composition manuelle
    /// invalide (deux fous de même couleur, etc.) : `positionNumber` n'est
    /// alors PAS mis à jour, pour ne jamais pointer vers une position que la
    /// rangée à l'écran ne montre plus.
    @State private var editableRank: [Character]
    /// Première case touchée d'un échange en cours — la seconde déclenche
    /// l'échange. Geste tap-tap, pas de glisser : même convention que le
    /// plateau lui-même.
    @State private var selectedFileForEdit: Int?

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
        _editableRank = State(initialValue: Chess960Position.backRank(number: saved.positionNumber) ?? Array("RNBQKBNR"))
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
                    .disabled(Chess960Position.number(forBackRank: editableRank) == nil)
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
                                setNumber(value, updatesField: false)
                            }
                        }
                        .accessibilityLabel("Numéro de position")
                        .accessibilityIdentifier("chess960_numberField")
                }

                // La rangée sert D'APERÇU et D'ÉDITEUR : toucher une case la
                // sélectionne, en toucher une seconde échange les deux — un
                // échange préserve TOUJOURS le jeu de pièces (2 tours, 2
                // cavaliers, 2 fous, 1 dame, 1 roi), il n'y a donc jamais de
                // pièce à choisir dans un sélecteur séparé. Seules deux
                // règles du Chess960 peuvent encore être violées en cours de
                // route — roi hors de l'intervalle des tours, fous de même
                // couleur — d'où l'avertissement ci-dessous quand ça arrive.
                HStack(spacing: 2) {
                    ForEach(Array(editableRank.enumerated()), id: \.offset) { file, letter in
                        rankSquare(file: file, letter: letter)
                    }
                }
                .frame(height: 44)
                .padding(4)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .animation(Theme.gentle, value: editableRank)

                if let editableNumber = Chess960Position.number(forBackRank: editableRank) {
                    Text(editableNumber == 518
                        ? "La 518 est la position de la partie classique."
                        : "Position \(editableNumber) sur 960 — la numérotation standard, la même que Lichess.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Label(invalidArrangementReason, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                        .accessibilityIdentifier("chess960_invalidArrangement")
                }
            }
        }
    }

    /// Case de la rangée éditable : le glyphe de la pièce, ou un repère de
    /// colonne vide si `editableRank` (composé à la main) ne contient
    /// momentanément aucune lettre reconnue — ne devrait pas arriver via les
    /// seuls échanges, mais une case qui reste MUETTE plutôt que de planter
    /// est le choix le plus sûr pour un état qu'on n'a pas prévu.
    private func rankSquare(file: Int, letter: Character) -> some View {
        let isSelected = selectedFileForEdit == file
        return Button {
            selectSquareForEdit(file)
        } label: {
            Group {
                if let kind = Piece.Kind(rawValue: String(letter)),
                   let square = Square("\(Character(UnicodeScalar(UInt8(97 + file))))1") as Square? {
                    PieceGlyphView(piece: Piece(kind, color: .white, square: square))
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? Theme.violet.opacity(0.28) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? Theme.violet : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chess960_rankSquare_\(file)")
        .accessibilityLabel(Text(pieceAccessibilityName(letter)))
    }

    private func pieceAccessibilityName(_ letter: Character) -> String {
        switch letter {
        case "R": LocalizationController.string("Tour")
        case "N": LocalizationController.string("Cavalier")
        case "B": LocalizationController.string("Fou")
        case "Q": LocalizationController.string("Dame")
        case "K": LocalizationController.string("Roi")
        default: ""
        }
    }

    private func selectSquareForEdit(_ file: Int) {
        guard let previous = selectedFileForEdit else {
            selectedFileForEdit = file
            return
        }
        selectedFileForEdit = nil
        guard previous != file else { return }
        editableRank.swapAt(previous, file)
        // Se resynchronise avec le numéro SEULEMENT si l'échange retombe sur
        // un arrangement légal — sinon `positionNumber` continuerait de
        // pointer vers l'ancien état, invisible à l'écran.
        if let number = Chess960Position.number(forBackRank: editableRank) {
            positionNumber = number
            numberField = String(number)
        }
    }

    /// Pourquoi `editableRank`, tel quel, n'a pas de numéro — pour que
    /// l'avertissement dise QUOI corriger, pas seulement QU'il faut corriger.
    private var invalidArrangementReason: LocalizedStringKey {
        guard let kingFile = editableRank.firstIndex(of: "K") else { return "Il manque un roi." }
        let rookFiles = editableRank.indices.filter { editableRank[$0] == "R" }
        if rookFiles.count == 2, !(rookFiles[0] < kingFile && kingFile < rookFiles[1]) {
            return "Le roi doit rester entre les deux tours."
        }
        let bishopFiles = editableRank.indices.filter { editableRank[$0] == "B" }
        if bishopFiles.count == 2, bishopFiles[0].isMultiple(of: 2) == bishopFiles[1].isMultiple(of: 2) {
            return "Les deux fous doivent être sur des cases de couleurs différentes."
        }
        return "Cette composition n'est pas une position Chess960 valide."
    }

    private var fieldIsValid: Bool {
        if let value = Int(numberField), (0...959).contains(value) { return true }
        return false
    }

    private func setNumber(_ value: Int, updatesField: Bool = true) {
        positionNumber = value
        if updatesField { numberField = String(value) }
        editableRank = Chess960Position.backRank(number: value) ?? editableRank
        selectedFileForEdit = nil
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
