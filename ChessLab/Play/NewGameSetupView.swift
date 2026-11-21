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
    /// L'appareil où son dernier coup a été joué, s'il ne s'agit pas de celui-ci (« iPhone 11 »).
    @State private var resumableOrigin: String?
    @State private var confirmReplace = false
    /// Titre de barre : « Nouvelle partie » par défaut, « Continuer la partie »
    /// quand on prolonge une position existante.
    private let navigationTitleKey: LocalizedStringKey

    @State private var colorChoice: PlayerColorChoice
    @State private var eloSlider: Double
    /// La force de Stockfish, gardée pendant qu'on regarde les personnages (voir `init`).
    @State private var stockfishElo: Double
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
    /// La cadence « Personnalisé… » s'ouvre en feuille (minutes, incrément).
    @State private var showCustomClock = false
    /// La phrase du personnage, dans une bulle.
    @State private var showTagline = false
    /// Partie à l'aveugle (17/11/2026).
    @State private var blindfold: BlindfoldLevel
    @State private var blindfoldVoice: Bool
    /// Coups à la voix (19/11/2026) ; ce que l'appareil sait reconnaître dans la langue de l'app ; un refus d'autorisation.
    @State private var voiceMoves: Bool
    @State private var voiceAvailability: VoiceRecognizers.Availability?
    @State private var voicePermissionDenied = false
    /// Propre à l'appareil, hors iCloud : voir ``BlindfoldVoice``.
    @AppStorage(BlindfoldVoice.voiceKey) private var voiceIdentifier = ""

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
        // La force de Stockfish, mémorisée à part : toucher Stockfish la retrouve, au lieu de garder le niveau du
        // personnage (échelle humaine) affiché juste avant. Bornage : un réglage mémorisé par une version
        // antérieure peut valoir 2800 ou 3190, désormais hors plage — un `Slider` hors bornes se colle à la butée
        // sans le dire. Si la dernière partie était contre un personnage, `eloSliderValue` est SON niveau : on
        // repart alors de la force par défaut.
        let stockfishSource = saved.opponentProfileID == nil ? saved.eloSliderValue : PlayGameSettings.default.eloSliderValue
        _stockfishElo = State(initialValue: min(max(stockfishSource, EngineStrength.playSliderRange.lowerBound),
                           EngineStrength.playSliderRange.upperBound))
        // Maia, TOUJOURS, à l'ouverture (demande du 17/11/2026) : Stockfish est à un toucher, tout à gauche.
        _opponentMode = State(initialValue: .profile)
        // Maia est TOUJOURS la sélection de départ en mode Personnage : on
        // ouvre sur l'étalon, pas sur le dernier personnage affronté (le
        // niveau, lui, reste mémorisé par personnage).
        _opponentProfileID = State(initialValue: OpponentProfile.maia.id)
        let maia = OpponentProfile.maia
        _eloSlider = State(initialValue: maia.clampedLevel(OpponentLevelStore.level(for: maia.id) ?? maia.defaultLevel))
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
        // L'aveugle ne se RETIENT pas d'une partie à l'autre : « Nouvelle partie » ne doit jamais ouvrir sur un
        // plateau vide sans qu'on l'ait demandé.
        _blindfold = State(initialValue: .off)
        _blindfoldVoice = State(initialValue: saved.blindfoldVoice)
        // Les coups à la voix non plus (19/11/2026, demande de l'utilisateur) : le micro ne s'ouvre jamais sur une
        // partie qu'on n'a pas demandée à la voix — on rallume l'interrupteur exprès.
        _voiceMoves = State(initialValue: false)
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

    // MARK: Présentation (refonte du 17/11/2026 : « plus joli, plus compact, moins old style »)
    //
    // Trois blocs au lieu de sept sections : l'ADVERSAIRE en vedette (une bande de portraits, le choisi en grand,
    // sa phrase, son niveau), une carte PARTIE aux lignes toutes du même style (chacune montre son choix et
    // s'ouvre en menu), les AIDES en quatre pastilles. Une seule couleur d'accent ; la couleur du personnage ne
    // vit que sur son portrait. Plus d'interrupteur à phrase.

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let resumable { resumeCard(resumable) }
                opponentHero
                    .discoveryAnchor(.strengthSlider)
                gameCard
                aidsCard
                    .discoveryAnchor(.aidToggles)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 20)
            .frame(maxWidth: Theme.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showCustomClock) {
            NavigationStack {
                ScrollView {
                    TimeLimitSection(selection: $timeLimit, tint: Theme.accent)
                        .padding(20)
                }
                .appBackground()
                .navigationTitle("Cadence")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("OK") { showCustomClock = false } }
                }
            }
            .preferredColorScheme(.dark)
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            resumable = AutosaveStore.loadPlay()
            resumableOrigin = resumable == nil ? nil : SyncedAutosave.play.origin().map { DeviceModelName.display($0) }
        }
        .replaceGameAlert(isPresented: $confirmReplace, moveCount: resumable?.moveLANs.count ?? 0,
                          origin: resumableOrigin, onResume: {
            if let resumable { onResume(resumable) }
        }, onReplace: { launch() })
        .appBackground()
        .navigationTitle(navigationTitleKey)
        .navigationBarTitleDisplayMode(.inline)
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
                    if let resumableOrigin {
                        Label("Dernier coup joué sur votre \(resumableOrigin)", systemImage: "icloud")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
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

    // MARK: L'adversaire en vedette

    private var selectedProfile: OpponentProfile? {
        opponentMode == .profile ? (OpponentProfile.named(opponentProfileID) ?? .maia) : nil
    }

    private var heroTint: Color {
        selectedProfile.map { OpponentTintResolver.color($0.tint) } ?? Theme.accent
    }

    /// La teinte du personnage, éclaircie pour être lue sur fond sombre : jauges et surnom.
    private var heroVivid: Color {
        selectedProfile.map { OpponentTintResolver.vivid($0.tint) } ?? Theme.accent
    }

    private func chooseProfile(_ profile: OpponentProfile) {
        withAnimation(Theme.snappySpring) {
            if opponentMode == .elo { stockfishElo = eloSlider }
            opponentMode = .profile
            opponentProfileID = profile.id
            eloSlider = profile.clampedLevel(OpponentLevelStore.level(for: profile.id) ?? profile.defaultLevel)
        }
        Haptics.move()
    }

    private func chooseStockfish() {
        withAnimation(Theme.snappySpring) {
            opponentMode = .elo
            eloSlider = stockfishElo
        }
        Haptics.move()
    }

    private var opponentHero: some View {
        VStack(spacing: 14) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    // Stockfish à GAUCHE, puis les personnages, Maia en tête (demande du 17/11/2026).
                    HStack(spacing: 10) {
                        stockfishPortrait.id("stockfish")
                        ForEach(OpponentProfile.all) { profile in
                            portrait(profile).id(profile.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .onAppear {
                    proxy.scrollTo(opponentMode == .profile ? opponentProfileID : "stockfish", anchor: .center)
                }
            }

            VStack(spacing: 4) {
                if let profile = selectedProfile {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(verbatim: profile.firstName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("« \(LocalizationController.string(profile.nickname)) »")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(heroVivid)
                        // La phrase du personnage — son charme — reste à un toucher.
                        Button { showTagline = true } label: {
                            Image(systemName: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("À propos de \(profile.firstName)"))
                        .accessibilityIdentifier("opponentInfo")
                        .popover(isPresented: $showTagline) {
                            Text(LocalizedStringKey(profile.tagline))
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: 280)
                                .padding(16)
                                .presentationCompactAdaptation(.popover)
                                .preferredColorScheme(.dark)
                        }
                    }
                    traitGauges(OpponentTraits(profile))
                        .padding(.top, 6)
                } else {
                    Text(verbatim: "Stockfish")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Le moteur, bridé à la force que vous choisissez.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 12)
            .id(selectedProfile?.id ?? "stockfish")
            .transition(.opacity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("opponentCard_\(selectedProfile?.id ?? "stockfish")")

            levelRow
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surfaceElevated)
                .overlay(alignment: .top) {
                    // Un halo discret de la couleur du personnage, en haut seulement.
                    RadialGradient(colors: [heroTint.opacity(0.28), .clear], center: .top, startRadius: 0, endRadius: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .allowsHitTesting(false)
                }
        }
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .animation(Theme.snappySpring, value: opponentProfileID)
        .animation(Theme.snappySpring, value: opponentMode)
    }

    private func portrait(_ profile: OpponentProfile) -> some View {
        let selected = opponentMode == .profile && profile.id == opponentProfileID
        let tint = OpponentTintResolver.color(profile.tint)
        return Button { chooseProfile(profile) } label: {
            OpponentAvatar(profile: profile, size: selected ? 64 : 48)
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? tint : .clear, lineWidth: 2.5))
                .opacity(selected ? 1 : 0.75)
                .frame(width: 72, height: 72)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text("\(profile.firstName) « \(LocalizationController.string(profile.nickname)) »"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("opponentTile_\(profile.id)")
    }

    private var stockfishPortrait: some View {
        let selected = opponentMode == .elo
        return Button { chooseStockfish() } label: {
            Image(systemName: "cpu")
                .font(.system(size: selected ? 26 : 20, weight: .semibold))
                .foregroundStyle(selected ? Theme.background : Theme.accent)
                .frame(width: selected ? 64 : 48, height: selected ? 64 : 48)
                .background(Circle().fill(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.accent.opacity(0.15))))
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2.5))
                .opacity(selected ? 1 : 0.75)
                .frame(width: 72, height: 72)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(verbatim: "Stockfish"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("opponentTile_stockfish")
    }

    /// Quatre jauges de cinq points : Attaque, Solidité, Échanges, Imprévisible — calculées des réglages du
    /// personnage (``OpponentTraits``), donc comparables d'un personnage à l'autre. Voir ``OpponentGaugesView`` :
    /// elles se partagent la largeur (un affichage « Zoomé » de 320 pt débordait avec la grille à largeurs fixes).
    private func traitGauges(_ traits: OpponentTraits) -> some View {
        OpponentGaugesView(traits: traits, tint: heroVivid)
    }

    /// Le niveau, sur une ligne : le mot, le curseur, le chiffre.
    private var levelRow: some View {
        let profile = selectedProfile
        let range = profile?.levelRange ?? EngineStrength.playSliderRange
        return HStack(spacing: 12) {
            Text("Niveau")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Slider(value: $eloSlider, in: range, step: 50)
                .tint(Theme.accent)
            Group {
                if profile != nil {
                    Text("\(Int(eloSlider))")
                } else {
                    Text(verbatim: EngineStrength(sliderValue: eloSlider).displayLabel)
                }
            }
            .font(.headline.monospacedDigit())
            .foregroundStyle(Theme.textPrimary)
            .frame(minWidth: 52, alignment: .trailing)
            .contentTransition(.numericText())
        }
        .animation(Theme.snappySpring, value: eloSlider)
    }

    // MARK: La carte « Partie »

    private var gameCard: some View {
        VStack(spacing: 0) {
            settingRow("circle.lefthalf.filled", "Couleur") { colorPicker }
            rowDivider
            settingRow("timer", "Cadence") { clockMenu }
                .discoveryAnchor(.timeLimit)
            rowDivider
            settingRow("eye.slash", "À l'aveugle") { blindfoldMenu }
            if blindfold != .off {
                rowDivider
                settingRow("speaker.wave.2", "Voix") {
                    HStack(spacing: 10) {
                        if blindfoldVoice { voiceMenu }
                        Toggle("", isOn: $blindfoldVoice).labelsHidden().tint(Theme.accent)
                            .accessibilityIdentifier("blindfoldVoice")
                    }
                }
            }
            rowDivider
            settingRow("mic", "Coups à la voix") {
                Toggle("", isOn: $voiceMoves).labelsHidden().tint(Theme.accent)
                    .disabled(voiceAvailability == .unavailable)
                    .accessibilityIdentifier("voiceMoves")
            }
            if let note = voiceMovesNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(voicePermissionDenied ? Theme.warning : Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 52)
                    .padding(.trailing, 14)
                    .padding(.bottom, 10)
                    .accessibilityIdentifier("voiceMovesNote")
            }
            // Sans le transcripteur d'iOS 26 — iOS 18 à 25, ou un iPhone ANCIEN sous iOS 26 (iPhone 11 : `isAvailable` faux ; la colonne e se confond avec c ou a), le dire EN
            // ORANGE au moment d'allumer, avec le geste qui aide : des coups courts (demande du 20/11/2026).
            if voiceMoves, Self.warnsAboutAccuracy(voiceAvailability) {
                Text("Sur cet appareil, la reconnaissance peut ne pas être optimale (surtout les colonnes e, c et a). Dites des coups courts : « e quatre ».")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 52)
                    .padding(.trailing, 14)
                    .padding(.bottom, 10)
                    .accessibilityIdentifier("voiceMovesAccuracyWarning")
            }
            rowDivider
            settingRow("flag", "Départ") { startMenu }
            if useCustomFEN { fenField.padding(.horizontal, 14).padding(.bottom, 12) }
            if opponentMode == .elo {
                rowDivider
                settingRow("book.closed", "Livre") { bookMenu }
            }
        }
        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .animation(Theme.gentle, value: blindfold)
        .animation(Theme.gentle, value: voiceMoves)
        .task {
            let availability = await VoiceRecognizers.availability(language: LocalizationController.activeLanguageCode)
            voiceAvailability = availability
            if availability == .unavailable { voiceMoves = false }
        }
        // Les autorisations se demandent en allumant, pas au premier coup de la partie.
        .onChange(of: voiceMoves) { _, on in
            guard on else { return }
            voicePermissionDenied = false
            Task {
                if !(await VoiceMoveListener.requestPermissions()) {
                    voiceMoves = false
                    voicePermissionDenied = true
                    return
                }
                // Revérifiée ICI, autorisation donnée : la dictée coupée dans les Réglages ne se voit qu'en essayant
                // de reconnaître — et l'utilisateur vient peut-être de l'activer.
                let availability = await VoiceRecognizers.availability(language: LocalizationController.activeLanguageCode)
                voiceAvailability = availability
                if availability == .dictationOff || availability == .unavailable { voiceMoves = false }
            }
        }
        .animation(Theme.gentle, value: useCustomFEN)
        .animation(Theme.gentle, value: opponentMode)
    }

    /// Vrai quand la reconnaissance est la classique (iOS 18 à 25, ou appareil qui ne sait pas le transcripteur d'iOS 26) : moins fiable sur les lettres (voir la ligne orange).
    static func warnsAboutAccuracy(_ availability: VoiceRecognizers.Availability?) -> Bool {
        availability == .available(precise: false)
    }

    /// Sous « Coups à la voix » : comment ça marche, et ce que l'appareil permet (décision du 19/11/2026 : sous
    /// iOS 18 à 25, la même fonction, avec cette note).
    private var voiceMovesNote: LocalizedStringKey? {
        if voicePermissionDenied {
            return "Micro ou reconnaissance vocale refusés : autorisez-les dans Réglages."
        }
        if voiceAvailability == .unavailable {
            return "Indisponible pour l'instant : la reconnaissance doit se faire sur l'appareil, sans réseau, et le modèle de cette langue n'est peut-être pas téléchargé. Dictez une phrase avec le micro du clavier (Notes, en Wi-Fi), puis revenez ici."
        }
        if voiceAvailability == .dictationOff {
            return "La dictée est désactivée sur cet iPhone : activez-la dans Réglages › Général › Clavier (« Activer la dictée »), puis rallumez « Coups à la voix »."
        }
        guard voiceMoves else { return nil }
        return "Dites votre coup quand c'est à vous : il est joué dès qu'il est compris ; « annule » le reprend."
    }

    private var rowDivider: some View {
        Divider().overlay(Theme.stroke).padding(.leading, 52)
    }

    private func settingRow<Trailing: View>(_ symbol: String, _ title: LocalizedStringKey,
                                            @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            Text(title)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }

    /// La valeur à droite d'une ligne : le choix, puis la petite flèche des menus.
    private func menuValue(_ text: LocalizedStringKey, highlighted: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(highlighted ? Theme.accent : Theme.textSecondary)
        .lineLimit(1)
    }

    private var colorPicker: some View {
        HStack(spacing: 10) {
            ForEach(PlayerColorChoice.allCases) { choice in
                let selected = colorChoice == choice
                Button {
                    withAnimation(Theme.snappySpring) { colorChoice = choice }
                } label: {
                    ZStack {
                        if let disc = choice.disc {
                            Circle().fill(disc)
                        } else {
                            Circle().fill(Theme.background)
                            Image(systemName: "shuffle").font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                    .padding(3)
                    .overlay(Circle().strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(LocalizedStringKey(choice.label)))
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private var clockMenu: some View {
        Menu {
            Button {
                timeLimit.isEnabled = false
            } label: {
                Label("Sans limite", systemImage: timeLimit.isEnabled ? "infinity" : "checkmark")
            }
            ForEach([TimeControlCategory.bullet, .blitz, .rapid, .classical], id: \.self) { category in
                Section(LocalizedStringKey(category.label)) {
                    ForEach(TimeControl.presets.filter { $0.category == category }) { control in
                        Button {
                            timeLimit.isEnabled = true
                            timeLimit.select(category)
                            timeLimit.select(control)
                        } label: {
                            if timeLimit.isEnabled, !timeLimit.isCustom, timeLimit.preset == control {
                                Label(LocalizedStringKey(control.label), systemImage: "checkmark")
                            } else {
                                Text(LocalizedStringKey(control.label))
                            }
                        }
                    }
                }
            }
            Button {
                timeLimit.isEnabled = true
                timeLimit.select(.custom)
                showCustomClock = true
            } label: {
                Label("Personnalisé…", systemImage: "slider.horizontal.3")
            }
        } label: {
            if timeLimit.isEnabled {
                menuValue(LocalizedStringKey(effectiveTimeControl.label), highlighted: true)
            } else {
                menuValue("Sans limite")
            }
        }
        .accessibilityIdentifier("cadenceMenu")
    }

    private var blindfoldMenu: some View {
        Menu {
            ForEach([BlindfoldLevel.off] + BlindfoldLevel.levels) { level in
                Button {
                    withAnimation(Theme.gentle) { blindfold = level }
                } label: {
                    if blindfold == level {
                        Label(LocalizedStringKey(level.title), systemImage: "checkmark")
                    } else {
                        Text(LocalizedStringKey(level.title))
                    }
                }
            }
        } label: {
            menuValue(LocalizedStringKey(blindfold.title), highlighted: blindfold != .off)
        }
        .accessibilityIdentifier("blindfoldMenu")
    }

    /// Le choix de la voix (19/11/2026) : celles de l'iPhone dans la langue de l'app ; la choisir la fait entendre.
    private var voiceMenu: some View {
        let options = BlindfoldVoice.options()
        let chosen = options.first { $0.id == voiceIdentifier }
        return Menu {
            Button {
                voiceIdentifier = ""
                BlindfoldVoice.shared.preview(identifier: nil)
            } label: {
                if chosen == nil { Label("Voix du système", systemImage: "checkmark") } else { Text("Voix du système") }
            }
            Divider()
            ForEach(options) { option in
                Button {
                    voiceIdentifier = option.id
                    BlindfoldVoice.shared.preview(identifier: option.id)
                } label: {
                    if chosen == option {
                        Label { voiceLabel(option) } icon: { Image(systemName: "checkmark") }
                    } else {
                        voiceLabel(option)
                    }
                }
            }
        } label: {
            if let chosen { menuValue(LocalizedStringKey(stringLiteral: chosen.name)) } else { menuValue("Système") }
        }
        .accessibilityIdentifier("blindfoldVoiceChoice")
    }

    /// Le nom de la voix, et dessous ce qui la distingue : « Féminine · Canada · Améliorée ».
    @ViewBuilder
    private func voiceLabel(_ option: BlindfoldVoice.Option) -> some View {
        Text(verbatim: option.name)
        let gender: String? = switch option.gender {
        case .female: LocalizationController.string("Féminine")
        case .male: LocalizationController.string("Masculine")
        default: nil
        }
        let quality: String? = switch option.quality {
        case .enhanced: LocalizationController.string("Améliorée")
        case .premium: LocalizationController.string("Premium")
        default: nil
        }
        let details = [gender, option.region, quality].compactMap { $0 }
        if !details.isEmpty { Text(verbatim: details.joined(separator: " · ")) }
    }

    private var startMenu: some View {
        Menu {
            Button {
                withAnimation(Theme.gentle) { useCustomFEN = false }
            } label: {
                if useCustomFEN { Text("Position initiale") } else { Label("Position initiale", systemImage: "checkmark") }
            }
            Button {
                withAnimation(Theme.gentle) { useCustomFEN = true }
            } label: {
                Label("Saisir une FEN", systemImage: "text.cursor")
            }
            Button {
                useCustomFEN = true
                showPositionEditor = true
            } label: {
                Label("Ouvrir l'éditeur", systemImage: "square.and.pencil")
            }
            Button {
                useCustomFEN = true
                showScanner = true
            } label: {
                Label("Scanner", systemImage: "camera.viewfinder")
            }
        } label: {
            menuValue(useCustomFEN ? "Personnalisée" : "Initiale", highlighted: useCustomFEN)
        }
        .accessibilityIdentifier("startMenu")
    }

    private var fenField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Position de départ (FEN)", text: $fenText,
                      prompt: Text("rnbqkbnr/pppppppp/…").foregroundStyle(Theme.textTertiary))
                .labelsHidden()
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: fenText) { fenError = false }
                .accessibilityIdentifier("customFENField")
                .padding(10)
                .background(Theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(fenError ? Theme.danger : Theme.stroke, lineWidth: 1))
            if fenError {
                Label("FEN invalide", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.danger)
                    .font(.caption)
            }
        }
    }

    private var bookMenu: some View {
        Menu {
            Button { bookEnabled = false } label: {
                if bookEnabled { Text("Aucun") } else { Label("Aucun", systemImage: "checkmark") }
            }
            Button { bookEnabled = true; bookWidth = .mainLinesOnly } label: {
                if bookEnabled, bookWidth == .mainLinesOnly { Label("Lignes principales", systemImage: "checkmark") }
                else { Text("Lignes principales") }
            }
            Button { bookEnabled = true; bookWidth = .includeSidelines } label: {
                if bookEnabled, bookWidth == .includeSidelines { Label("Avec variantes", systemImage: "checkmark") }
                else { Text("Avec variantes") }
            }
        } label: {
            menuValue(!bookEnabled ? "Aucun" : (bookWidth == .mainLinesOnly ? "Lignes principales" : "Avec variantes"))
        }
    }

    // MARK: Les aides

    /// Quatre pastilles d'une seule couleur ; à l'aveugle, les trois qui montreraient la position s'éteignent.
    private var aidsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aides")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 4)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                aidChip("lightbulb", "Indice", isOn: $hintsEnabled, blinded: blindfold != .off,
                        fullLabel: "Indice (flèches des meilleurs coups)")
                aidChip("exclamationmark.triangle", "Alerte de gaffe", isOn: $blunderAlertEnabled, blinded: blindfold != .off,
                        fullLabel: "Alerte en cas de coup risqué")
                aidChip("chart.bar", "Barre d'évaluation", isOn: $showEvalBar, blinded: blindfold != .off,
                        fullLabel: "Barre d'évaluation")
                aidChip("flag", "Il peut abandonner", isOn: $engineResignationEnabled, blinded: false,
                        fullLabel: "L'ordinateur peut abandonner s'il est perdu")
            }
        }
    }

    private func aidChip(_ symbol: String, _ title: LocalizedStringKey, isOn: Binding<Bool>, blinded: Bool,
                         fullLabel: LocalizedStringKey) -> some View {
        let lit = isOn.wrappedValue && !blinded
        return Button {
            withAnimation(Theme.snappySpring) { isOn.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: lit ? symbol + ".fill" : symbol)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .foregroundStyle(lit ? Theme.accent : Theme.textSecondary)
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background((lit ? Theme.accent.opacity(0.14) : Theme.surfaceElevated),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(lit ? Theme.accent.opacity(0.55) : Theme.stroke, lineWidth: 1))
            .opacity(blinded ? 0.4 : 1)
        }
        .buttonStyle(.pressable)
        .disabled(blinded)
        .accessibilityLabel(Text(fullLabel))
        .accessibilityValue(Text(lit ? "Activé" : "Désactivé"))
        .accessibilityAddTraits(lit ? [.isButton, .isSelected] : .isButton)
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
            opponentProfileID: opponentMode == .profile ? opponentProfileID : nil,
            blindfold: blindfold,
            blindfoldVoice: blindfoldVoice,
            voiceMoves: voiceMoves && voiceAvailability != .unavailable && voiceAvailability != .dictationOff
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
    /// Remplissage horizontal resserré (10 pt au lieu de 14) et texte sur une ligne : pour une rangée qui doit tenir.
    var compact: Bool = false
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
                Text(label).lineLimit(compact ? 1 : nil).fixedSize(horizontal: compact, vertical: false)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? Theme.background : Theme.textPrimary)
            .padding(.horizontal, compact ? 10 : 14)
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
