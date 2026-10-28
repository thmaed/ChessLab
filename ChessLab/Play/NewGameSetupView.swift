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
    /// Reprendre la partie contre l'ordinateur laissée en cours — fournie par l'accueil.
    private let onResume: (PlayGameAutosave) -> Void
    /// La partie en cours, relue à l'ouverture de l'écran. Lancer une nouvelle partie
    /// l'EFFACE : l'écran le dit, au lieu de le laisser découvrir (retour d'un joueur,
    /// 27/10/2026 : la flèche de retour mène ici, et « Commencer » perdait sa partie).
    @State private var resumable: PlayGameAutosave?
    @State private var confirmReplace = false
    /// Titre de barre : « Nouvelle partie » par défaut, « Continuer la partie »
    /// quand on prolonge une position existante.
    private let navigationTitleKey: LocalizedStringKey

    @State private var colorChoice: PlayerColorChoice
    @State private var eloSlider: Double
    @State private var opponentMode: OpponentMode
    @State private var opponentProfileID: String
    @State private var timeLimit: TimeLimitSelection
    @State private var hintsEnabled: Bool
    @State private var blunderAlertEnabled: Bool
    @State private var showEvalBar: Bool
    @State private var engineResignationEnabled: Bool
    @State private var multiMoveTakebackEnabled: Bool
    @State private var bookEnabled: Bool
    @State private var bookWidth: OpeningBookWidth
    @State private var useCustomFEN = false
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
    init(
        initialFEN: String? = nil,
        onResume: @escaping (PlayGameAutosave) -> Void = { _ in },
        onStart: @escaping (PlayGameSettings) -> Void
    ) {
        self.onStart = onStart
        self.onResume = onResume
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
        _opponentMode = State(initialValue: saved.opponentProfileID == nil ? .elo : .profile)
        // Maia est TOUJOURS la sélection de départ en mode Personnage : on
        // ouvre sur l'étalon, pas sur le dernier personnage affronté (le
        // niveau, lui, reste mémorisé par personnage).
        _opponentProfileID = State(initialValue: OpponentProfile.maia.id)
        if saved.opponentProfileID != nil {
            let maia = OpponentProfile.maia
            _eloSlider = State(initialValue: maia.clampedLevel(OpponentLevelStore.level(for: maia.id) ?? saved.eloSliderValue))
        }
        _timeLimit = State(initialValue: TimeLimitSelection(
            savedID: saved.timeControlID, customMinutes: saved.customMinutes,
            customIncrement: saved.customIncrementSeconds, memoryKey: "play"))
        _hintsEnabled = State(initialValue: saved.hintsEnabled)
        _blunderAlertEnabled = State(initialValue: saved.blunderAlertEnabled)
        _showEvalBar = State(initialValue: saved.showEvalBar)
        _engineResignationEnabled = State(initialValue: saved.engineResignationEnabled)
        _multiMoveTakebackEnabled = State(initialValue: saved.multiMoveTakebackEnabled)
        _bookEnabled = State(initialValue: saved.bookEnabled)
        _bookWidth = State(initialValue: saved.bookWidth)
    }

    var body: some View {
        // Le lecteur ENGLOBE le ScrollView (un lecteur posé dedans ne
        // trouverait aucun défilable « en lui » et ses scrollTo seraient
        // muets) : chaque étape de la visite centre ainsi sa section.
        ScrollViewReader { discoveryProxy in
            scrollBody
                .discoveryAutoScroll(using: discoveryProxy)
        }
    }

    private var scrollBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let resumable { resumeCard(resumable) }

                SettingsSection(title: "Couleur", systemImage: "circle.lefthalf.filled", tint: Theme.warning) {
                    // FlowLayout et non HStack : en français les trois
                    // puces réclament ~323 pt pour 303 disponibles à 375, et
                    // 248 en Display Zoom. Elles passent maintenant à la ligne
                    // au lieu d'être comprimées (Lot 3.5).
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(PlayerColorChoice.allCases) { choice in
                            ChipButton(
                                label: LocalizedStringKey(choice.label),
                                systemImage: choice.symbolName,
                                isSelected: colorChoice == choice,
                                disc: choice.disc,
                                tint: Theme.warning
                            ) {
                                colorChoice = choice
                            }
                        }
                    }
                }

                SettingsSection(title: "Adversaire", systemImage: "person.crop.circle", tint: Theme.accent, discoverySpot: .strengthSlider) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Deux façons de choisir l'adversaire : un personnage
                        // joué par Maia-3 (le plus humain, en premier et par
                        // défaut), ou Stockfish bridé à un Elo.
                        Picker("Adversaire", selection: $opponentMode.animation()) {
                            Text("Personnage").tag(OpponentMode.profile)
                            Text("Stockfish").tag(OpponentMode.elo)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: opponentMode) { _, mode in
                            guard mode == .profile, let profile = OpponentProfile.named(opponentProfileID) else { return }
                            eloSlider = profile.clampedLevel(OpponentLevelStore.level(for: profile.id) ?? profile.defaultLevel)
                        }

                        if opponentMode == .profile {
                            OpponentGalleryView(selectedID: $opponentProfileID) { profile in
                                // Chaque personnage garde SON niveau, dans SA plage.
                                eloSlider = profile.clampedLevel(OpponentLevelStore.level(for: profile.id) ?? profile.defaultLevel)
                            }
                            OpponentLevelSlider(
                                profile: OpponentProfile.named(opponentProfileID) ?? .maia,
                                level: $eloSlider
                            )
                        } else {
                            // Le chiffre, le curseur, et juste dessous le nom
                            // du palier où l'on est (« Débutant confirmé ») :
                            // la grille des huit cartes disait la même chose
                            // en huit fois plus de place.
                            HStack(alignment: .firstTextBaseline) {
                                Text(EngineStrength(sliderValue: eloSlider).displayLabel)
                                    .font(.title2.weight(.bold).monospacedDigit())
                                    .foregroundStyle(Theme.textPrimary)
                                    .contentTransition(.numericText())
                                Spacer()
                                if let preset = EnginePreset.nearest(toSliderValue: eloSlider) {
                                    Text(LocalizedStringKey(preset.label))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.accent)
                                        .contentTransition(.opacity)
                                }
                            }
                            .animation(Theme.snappySpring, value: eloSlider)

                            Slider(value: $eloSlider, in: EngineStrength.playSliderRange, step: 50)
                                .tint(Theme.accent)
                            HStack {
                                Text("\(Int(EngineStrength.playSliderRange.lowerBound))")
                                Spacer()
                                Text("Maximum")
                            }
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }

                // Un personnage joue son propre répertoire : le livre général
                // ne concerne que le mode Niveau Elo.
                if opponentMode == .elo {
                SettingsSection(title: "Livre d'ouvertures", systemImage: "book.closed.fill", tint: Theme.gold) {
                    VStack(alignment: .leading, spacing: 12) {
                        ToggleRow(label: "Le moteur pioche dans un livre d'ouvertures", isOn: $bookEnabled.animation(), tint: Theme.gold)

                        if bookEnabled {
                            HStack(spacing: 8) {
                                ChipButton(
                                    label: "Lignes principales",
                                    systemImage: nil,
                                    isSelected: bookWidth == .mainLinesOnly,
                                    tint: Theme.gold
                                ) {
                                    bookWidth = .mainLinesOnly
                                }
                                ChipButton(
                                    label: "Avec variantes",
                                    systemImage: nil,
                                    isSelected: bookWidth == .includeSidelines,
                                    tint: Theme.gold
                                ) {
                                    bookWidth = .includeSidelines
                                }
                            }
                        }
                    }
                }
                }

                TimeLimitSection(selection: $timeLimit, tint: Theme.info)

                SettingsSection(title: "Départ", systemImage: "flag.fill", tint: Theme.violet) {
                    VStack(alignment: .leading, spacing: 12) {
                        ToggleRow(label: "Position personnalisée (FEN)", isOn: $useCustomFEN.animation(), tint: Theme.violet)
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
                                ChipButton(label: "Ouvrir l'éditeur", systemImage: "square.and.pencil", isSelected: false, tint: Theme.violet) {
                                    showPositionEditor = true
                                }
                                ChipButton(label: "Scanner", systemImage: "camera.viewfinder", isSelected: false, tint: Theme.violet) {
                                    showScanner = true
                                }
                                .accessibilityIdentifier("scanStartPosition")
                            }
                        }
                    }
                }

                SettingsSection(title: "Aides", systemImage: "lightbulb.fill", tint: Theme.rose, discoverySpot: .aidToggles) {
                    VStack(spacing: 12) {
                        ToggleRow(label: "Indice (flèches des meilleurs coups)", isOn: $hintsEnabled, tint: Theme.rose)
                        ToggleRow(label: "Alerte en cas de coup risqué", isOn: $blunderAlertEnabled, tint: Theme.rose)
                        ToggleRow(label: "Barre d'évaluation", isOn: $showEvalBar, tint: Theme.rose)
                        ToggleRow(label: "L'ordinateur peut abandonner s'il est perdu", isOn: $engineResignationEnabled, tint: Theme.rose)
                        // La note sur la reprise de coup a rejoint « Limite de temps » (28/10/2026) :
                        // c'est la pendule qui décide, c'est là qu'on doit le lire.
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .onAppear { resumable = AutosaveStore.loadPlay() }
        .alert("Une partie est en cours", isPresented: $confirmReplace) {
            Button("Reprendre la partie en cours") {
                if let resumable { onResume(resumable) }
            }
            Button("Remplacer par une nouvelle partie", role: .destructive) { launch() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Commencer une nouvelle partie effacera la partie en cours (\(resumable?.moveLANs.count ?? 0) coup(s) joué(s)).")
        }
        .appBackground()
        .navigationTitle(navigationTitleKey)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .primaryActionBar("Commencer") { start() }
        // `.page` et non la taille par défaut : sur iPad, une feuille sans
        // consigne s'ouvre en FORM SHEET (~540×620), et c'est trop petit pour
        // les deux écrans ci-dessous — le recadrage à quatre poignées du
        // scanner y perd la précision qui fait tout son intérêt, et l'éditeur
        // de position, dont le plateau est plafonné à 460 pt, y cachait son
        // bouton de validation sous le pli. Sans effet sur iPhone, où
        // `presentationSizing` ne s'applique pas : le geste de fermeture par
        // glissement est préservé, contrairement à un `fullScreenCover`.
        .sheet(isPresented: $showPositionEditor) {
            positionEditorSheet.presentationSizing(.page)
        }
        .sheet(isPresented: $showScanner) {
            scannerSheet.presentationSizing(.page)
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

    private var effectiveTimeControl: TimeControl { timeLimit.effective }
    private var customMinutes: Int { timeLimit.customMinutes }
    private var customIncrement: Int { timeLimit.customIncrement }

    /// Garde-fou : une partie en cours serait effacée par la nouvelle.
    private func start() {
        let trimmed = trimmedFENText
        if useCustomFEN, !FENValidator.isLegal(trimmed) {
            fenError = true
            return
        }
        if resumable != nil {
            confirmReplace = true
        } else {
            launch()
        }
    }

    /// La carte « Reprendre » : c'est ici qu'on atterrit en quittant une partie par la flèche.
    private func resumeCard(_ autosave: PlayGameAutosave) -> some View {
        Button {
            onResume(autosave)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reprendre la partie en cours")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Votre partie vous attend : \(autosave.moveLANs.count) coup(s) joué(s).")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.14), in: Theme.cardShape)
            .overlay(Theme.cardShape.strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("setupResumeGame")
    }

    private func launch() {
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
            engineResignationEnabled: engineResignationEnabled,
            opponentProfileID: opponentMode == .profile ? opponentProfileID : nil
        )
        if opponentMode == .profile {
            OpponentLevelStore.save(level: eloSlider, for: opponentProfileID)
        }
        timeLimit.remember(memoryKey: "play")
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
    /// Cible éventuelle de la visite guidée — le trou couvre la section
    /// ENTIÈRE (en-tête compris), pas un contrôle isolé dedans.
    var discoverySpot: DiscoverySpot? = nil
    @ViewBuilder let content: Content

    var body: some View {
        sectionBody
            .discoveryAnchor(ifPresent: discoverySpot)
    }

    private var sectionBody: some View {
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


struct ChipButton: View {
    let label: LocalizedStringKey
    let systemImage: String?
    let isSelected: Bool
    /// Une pastille pleine (blanche ou noire) à la place de l'icône : un disque
    /// plein ou un anneau, selon la sélection, se lisait à l'envers (Blancs avait
    /// le disque NOIR). Sert aux puces de couleur.
    var disc: Color? = nil
    /// La teinte de la puce : celle de sa section ou de sa famille, au repos
    /// (icône colorée, liseré pâle) comme sélectionnée (dégradé plein).
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let disc {
                    Circle().fill(disc).frame(width: 13, height: 13)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                } else if let systemImage {
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
                    Capsule().fill(LinearGradient(colors: [tint, tint.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    Capsule().fill(tint.opacity(0.10))
                }
            }
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : tint.opacity(0.28), lineWidth: 1))
            .glow(tint, radius: 7, isActive: isSelected)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}


struct ToggleRow: View {
    let label: LocalizedStringKey
    @Binding var isOn: Bool
    var tint: Color = Theme.accent

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .foregroundStyle(Theme.textPrimary)
        }
        .tint(tint)
    }
}

/// Rangée d'option EXCLUSIVE : icône, titre, description, coche.
///
/// Pour les choix « un parmi n » dont une capsule ne dit pas assez — un chip
/// n'a pas la place d'expliquer ce que le choix implique, et finissait en
/// parenthèses télégraphiques (« Table (icônes retournées) »). Ici le titre
/// nomme, la légende explique, et le choix courant se voit à la coche ET au
/// liseré, sans inverser les couleurs de toute la rangée.
struct OptionRow: View {
    let title: LocalizedStringKey
    let caption: LocalizedStringKey
    let systemImage: String
    let isSelected: Bool
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? tint : Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(
                        isSelected ? tint.opacity(0.16) : Theme.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? tint : Theme.textTertiary.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected ? tint.opacity(0.07) : Theme.surfaceElevated.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? tint.opacity(0.5) : Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Adversaire : niveau Elo ou personnage

/// Contre qui l'on joue : Stockfish bridé à un Elo, ou un personnage joué
/// par Maia-3 (voir ``OpponentProfile``).
enum OpponentMode: Hashable {
    case elo
    case profile
}
