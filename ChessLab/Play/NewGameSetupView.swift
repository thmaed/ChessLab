import ChessKit
import SwiftUI

/// Écran de configuration d'une nouvelle partie contre Stockfish.
///
/// Réutilisé tel quel pour « Continuer contre Stockfish » depuis une ligne
/// d'ouverture ou un répertoire : on passe alors la position atteinte en
/// `initialFEN`, ce qui pré-remplit le départ et attribue à l'utilisateur le
/// camp au trait — mais on garde l'écran ENTIER, pour qu'il choisisse d'abord
/// l'Elo (et puisse ajuster cadence et aides) au lieu de repartir en silence
/// aux derniers réglages.
struct NewGameSetupView: View {
    let onStart: (PlayGameSettings) -> Void
    /// Titre de barre : « Nouvelle partie » par défaut, « Continuer la partie »
    /// quand on prolonge une position existante.
    private let navigationTitleKey: LocalizedStringKey

    @State private var colorChoice: PlayerColorChoice
    @State private var eloSlider: Double
    @State private var timeControl: TimeControl
    @State private var isCustomTimeControlSelected: Bool
    @State private var customMinutes: Int
    @State private var customIncrement: Int
    @State private var hintsEnabled: Bool
    @State private var blunderAlertEnabled: Bool
    @State private var showEvalBar: Bool
    @State private var engineResignationEnabled: Bool
    @State private var multiMoveTakebackEnabled: Bool
    @State private var bookEnabled: Bool
    @State private var bookWidth: OpeningBookWidth
    @State private var useCustomFEN = false
    /// Famille de cadence affichée. Dérivée des réglages mémorisés à
    /// l'ouverture, puis pilotée par les chips.
    @State private var timeCategory: TimeControlCategory
    @State private var fenText = ""
    @State private var fenError = false
    @State private var showPositionEditor = false
    @State private var showScanner = false

    /// Préremplit tous les champs avec les derniers réglages utilisés
    /// (ou les défauts à la première partie). Pas d'effet de bord ici :
    /// uniquement des valeurs.
    ///
    /// - Parameter initialFEN: position de départ imposée (« Continuer contre
    ///   Stockfish »). Quand elle est fournie, la case « Position personnalisée »
    ///   est cochée, le champ FEN pré-rempli, et le camp au trait dans la FEN
    ///   devient celui de l'utilisateur — l'autre est joué par le moteur.
    init(initialFEN: String? = nil, onStart: @escaping (PlayGameSettings) -> Void) {
        self.onStart = onStart
        self.navigationTitleKey = initialFEN == nil ? "Nouvelle partie" : "Continuer la partie"
        let saved = PlaySettingsStore.load() ?? .default

        let incomingPosition = initialFEN.flatMap(Position.init(fen:))
        _colorChoice = State(initialValue: incomingPosition.map {
            $0.sideToMove == .white ? PlayerColorChoice.white : .black
        } ?? saved.resolvedColorChoice)
        _useCustomFEN = State(initialValue: initialFEN != nil)
        _fenText = State(initialValue: initialFEN ?? "")
        // Bornage : un réglage mémorisé par une version antérieure peut valoir
        // 2800 ou 3190, désormais hors plage. Un `Slider` avec une valeur hors
        // bornes se colle à la butée sans le dire, et l'utilisateur lancerait
        // une partie à une force qu'il ne voit nulle part.
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
        _hintsEnabled = State(initialValue: saved.hintsEnabled)
        _blunderAlertEnabled = State(initialValue: saved.blunderAlertEnabled)
        _showEvalBar = State(initialValue: saved.showEvalBar)
        _engineResignationEnabled = State(initialValue: saved.engineResignationEnabled)
        _multiMoveTakebackEnabled = State(initialValue: saved.multiMoveTakebackEnabled)
        _bookEnabled = State(initialValue: saved.bookEnabled)
        _bookWidth = State(initialValue: saved.bookWidth)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(title: "Couleur", systemImage: "circle.lefthalf.filled", tint: Theme.accent) {
                    HStack(spacing: 8) {
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
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(EngineStrength(sliderValue: eloSlider).displayLabel)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                        }

                        Slider(value: $eloSlider, in: EngineStrength.playSliderRange, step: 10)
                            .tint(Theme.accent)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(Array(EnginePreset.all.enumerated()), id: \.element.id) { index, preset in
                                EngineLevelCard(
                                    preset: preset,
                                    tier: engineLevelTier(forIndex: index, total: EnginePreset.all.count),
                                    isSelected: abs(preset.strength.sliderValue - eloSlider) < 1
                                ) {
                                    eloSlider = preset.strength.sliderValue
                                }
                            }
                        }
                    }
                }

                SettingsSection(title: "Livre d'ouvertures", systemImage: "book.closed.fill", tint: Theme.accent) {
                    VStack(alignment: .leading, spacing: 12) {
                        ToggleRow(label: "Le moteur pioche dans un livre d'ouvertures", isOn: $bookEnabled.animation())

                        if bookEnabled {
                            HStack(spacing: 8) {
                                ChipButton(
                                    label: "Lignes principales",
                                    systemImage: nil,
                                    isSelected: bookWidth == .mainLinesOnly
                                ) {
                                    bookWidth = .mainLinesOnly
                                }
                                ChipButton(
                                    label: "Avec variantes",
                                    systemImage: nil,
                                    isSelected: bookWidth == .includeSidelines
                                ) {
                                    bookWidth = .includeSidelines
                                }
                            }
                        }
                    }
                }

                SettingsSection(title: "Cadence", systemImage: "timer", tint: Theme.accent) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Deux niveaux plutôt qu'un empilement. Avant : un chip
                        // isolé, puis QUATRE blocs « en-tête + flot de chips »,
                        // puis le bloc perso — cinq en-têtes et une vingtaine
                        // de chips déroulés en permanence, pour un réglage dont
                        // une seule valeur compte. On choisit la famille, puis
                        // la cadence DANS cette famille : deux lignes, et le
                        // vocabulaire des sites d'échecs.
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

                SettingsSection(title: "Départ", systemImage: "flag.fill", tint: Theme.accent) {
                    VStack(alignment: .leading, spacing: 12) {
                        ToggleRow(label: "Position personnalisée (FEN)", isOn: $useCustomFEN.animation())
                            .accessibilityIdentifier("useCustomFEN")

                        if useCustomFEN {
                            TextField("Position de départ (FEN)", text: $fenText, prompt: Text("rnbqkbnr/pppppppp/…").foregroundStyle(Theme.textTertiary))
                                .labelsHidden()
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Theme.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: fenText) { fenError = false }
                                .accessibilityIdentifier("customFENField")
                                .padding(10)
                                .background(Theme.surfaceElevated, in: Theme.controlShape)
                                .overlay(Theme.controlShape.strokeBorder(fenError ? Theme.danger : Theme.stroke, lineWidth: 1))

                            if fenError {
                                Label("FEN invalide", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Theme.danger)
                                    .font(.caption)
                            }

                            HStack(spacing: 8) {
                                ChipButton(label: "Ouvrir l'éditeur", systemImage: "square.and.pencil", isSelected: false) {
                                    showPositionEditor = true
                                }
                                ChipButton(label: "Scanner", systemImage: "camera.viewfinder", isSelected: false) {
                                    showScanner = true
                                }
                                .accessibilityIdentifier("scanStartPosition")
                            }
                        }
                    }
                }

                SettingsSection(title: "Aides", systemImage: "lightbulb.fill", tint: Theme.accent) {
                    VStack(spacing: 12) {
                        ToggleRow(label: "Indice (flèches des meilleurs coups)", isOn: $hintsEnabled)
                        ToggleRow(label: "Alerte en cas de coup risqué", isOn: $blunderAlertEnabled)
                        ToggleRow(label: "Barre d'évaluation", isOn: $showEvalBar)
                        ToggleRow(label: "Stockfish peut abandonner s'il est perdu", isOn: $engineResignationEnabled)
                        Text(effectiveTimeControl.hasClock ? "Reprise de coup indisponible avec pendule." : "Parcourez la partie avec la barre sous le plateau ; sans pendule, « Reprendre ici » relance depuis le coup consulté.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .appBackground()
        .navigationTitle(navigationTitleKey)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Commencer") { start() }
                    .fontWeight(.semibold)
                    .tint(Theme.accent)
            }
        }
        .sheet(isPresented: $showPositionEditor) {
            positionEditorSheet
        }
        .sheet(isPresented: $showScanner) {
            scannerSheet
        }
    }

    /// L'éditeur est présenté en FEUILLE (et non poussé comme une route) :
    /// il RAPPORTE sa position dans le champ ci-dessus, et les réglages déjà
    /// choisis à l'écran — couleur, force, cadence — survivent au détour.
    private var positionEditorSheet: some View {
        NavigationStack {
            PositionEditorView(
                initialFEN: FENValidator.isLegal(trimmedFENText) ? trimmedFENText : nil,
                exit: .picker(label: "Utiliser cette position") { fen in
                    setStartFEN(fen)
                    showPositionEditor = false
                }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showPositionEditor = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Même feuille, même contrat de sortie : le scanner finit sur l'écran de
    /// confirmation, qui EST l'éditeur pré-rempli.
    private var scannerSheet: some View {
        NavigationStack {
            ScannerView(
                exit: .picker(label: "Utiliser cette position") { fen in
                    setStartFEN(fen)
                    showScanner = false
                }
            )
            .toolbar {
                // À DROITE : le scanner occupe déjà le bouton de gauche à
                // chaque étape (« Changer », « Recadrer »). Deux
                // `cancellationAction` s'afficheraient côte à côte.
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Annuler") { showScanner = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func setStartFEN(_ fen: String) {
        fenText = fen
        fenError = false
    }

    private var trimmedFENText: String {
        fenText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Change de famille en gardant TOUJOURS une cadence valide : sans ça,
    /// passer sur « Blitz » n'aurait rien sélectionné et « Commencer » aurait
    /// lancé la cadence de la famille précédente, invisible à l'écran.
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

    private var effectiveTimeControl: TimeControl {
        isCustomTimeControlSelected ? .custom(minutes: customMinutes, incrementSeconds: customIncrement) : timeControl
    }

    /// Répartit `total` préréglages sur 5 paliers de jauge (1...5), en
    /// ordre croissant, pour donner un repère visuel rapide de la force
    /// relative sans avoir à mémoriser les valeurs Elo.
    private func engineLevelTier(forIndex index: Int, total: Int) -> Int {
        guard total > 1 else { return 1 }
        let t = Double(index) / Double(total - 1)
        return 1 + Int((t * 4).rounded())
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

    private func start() {
        // Trimé AVANT stockage et pas seulement pour la validation :
        // `FENValidator` trime en interne, mais `PlayGameSettings.startingPosition`
        // parse le FEN stocké tel quel — un FEN collé avec un retour à la
        // ligne passait donc la validation puis échouait silencieusement au
        // parsing, et la partie démarrait en position standard.
        let trimmedFEN = trimmedFENText
        if useCustomFEN {
            guard FENValidator.isLegal(trimmedFEN) else {
                fenError = true
                return
            }
        }

        let settings = PlayGameSettings(
            colorChoice: colorChoice.rawValue,
            eloSliderValue: eloSlider,
            timeControlID: effectiveTimeControl.id,
            customMinutes: customMinutes,
            customIncrementSeconds: customIncrement,
            startFEN: useCustomFEN ? trimmedFEN : nil,
            hintsEnabled: hintsEnabled,
            blunderAlertEnabled: blunderAlertEnabled,
            showEvalBar: showEvalBar,
            multiMoveTakebackEnabled: multiMoveTakebackEnabled,
            bookEnabled: bookEnabled,
            bookWidth: bookWidth,
            engineResignationEnabled: engineResignationEnabled
        )
        PlaySettingsStore.save(settings)
        onStart(settings)
    }
}

// MARK: - Composants de réglage réutilisables

struct CategoryHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textTertiary)
            .textCase(.uppercase)
            .tracking(0.3)
            .padding(.top, 4)
    }
}

/// Section d'écran d'options : en-tête + contenu en carte.
///
/// `systemImage`/`tint` optionnels : une petite tuile d'icône dans la
/// teinte de la SECTION (façon Réglages iOS) rend chaque bloc identifiable
/// d'un coup d'œil — la teinte reprend celle du mode parent (émeraude pour
/// Jouer, bleu pour Deux joueurs, rose pour le Labo…), prolongeant le code
/// couleur des cartes de l'accueil jusque dans les écrans de réglage. Sans
/// icône, l'en-tête garde le tiret dégradé des sections de l'accueil.
struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil
    var tint: Color = Theme.accent
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let systemImage {
                    // Teinte pâle + icône colorée (le langage « au repos »
                    // des chips), et non la tuile pleine d'``IconBadge`` :
                    // à cette taille un dégradé plein serait brouillon, et
                    // un en-tête n'est pas un élément actif.
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 22, height: 22)
                        .background(
                            tint.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .accessibilityHidden(true)
                } else {
                    Capsule()
                        .fill(Theme.accentGradient)
                        .frame(width: 18, height: 3)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }

            content
                .cardStyle()
        }
    }
}

private struct EngineLevelCard: View {
    let preset: EnginePreset
    let tier: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                StrengthGauge(filledBars: tier, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(preset.label))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.background : Theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Theme.background.opacity(0.7) : Theme.textTertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accentGradient)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceElevated)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isSelected ? Color.clear : Theme.stroke, lineWidth: 1))
            .glow(Theme.accent, radius: 8, isActive: isSelected)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var caption: String {
        preset.strength == .maximum ? "Pleine puissance" : "Elo \(Int(preset.strength.sliderValue))"
    }
}

/// Jauge à 5 barres façon "signal" indiquant la force relative d'un
/// préréglage, pour repérer le niveau d'un coup d'œil sans lire l'Elo.
private struct StrengthGauge: View {
    let filledBars: Int
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < filledBars ? barColor : barColor.opacity(0.25))
                    .frame(width: 3, height: 6 + CGFloat(i) * 4)
            }
        }
        .frame(width: 26, height: 22, alignment: .bottom)
    }

    private var barColor: Color {
        isSelected ? Theme.background : Theme.accent
    }
}

struct ChipButton: View {
    let label: LocalizedStringKey
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(label)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? Theme.background : Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule().fill(Theme.accentGradient)
                } else {
                    Capsule().fill(Theme.surfaceElevated)
                }
            }
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Theme.stroke, lineWidth: 1))
            .glow(Theme.accent, radius: 7, isActive: isSelected)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}


struct ToggleRow: View {
    let label: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .foregroundStyle(Theme.textPrimary)
        }
        .tint(Theme.accent)
    }
}
