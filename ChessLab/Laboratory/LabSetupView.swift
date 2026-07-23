import SwiftUI

/// Configuration d'une série Laboratoire (Stockfish contre Stockfish).
/// Propose de reprendre une série interrompue si une sauvegarde existe.
struct LabSetupView: View {
    let onStart: (LabGameSettings) -> Void
    let onResume: (LabSeriesState) -> Void

    @State private var settings: LabGameSettings
    @State private var resumable: LabSeriesState?
    @State private var useCustomFEN: Bool
    @State private var fenText: String
    @State private var fenError = false
    @State private var showPositionEditor = false
    @State private var showScanner = false

    /// - parameter startFEN: position imposée à l'ouverture (venue de
    ///   l'éditeur ou du scanner) ; sinon on reprend celle des réglages
    ///   mémorisés.
    init(
        startFEN: String? = nil,
        onStart: @escaping (LabGameSettings) -> Void,
        onResume: @escaping (LabSeriesState) -> Void
    ) {
        self.onStart = onStart
        self.onResume = onResume
        let saved = LabSettingsStore.load() ?? .default
        // PAS de `saved.startFEN` : une position de départ est un choix
        // ponctuel, pas une préférence. La mémoriser faisait rouvrir le
        // Laboratoire sur la position d'une série précédente, sans que rien
        // ne l'annonce — alors que la force des moteurs ou le nombre de
        // parties, eux, méritent d'être retenus. Le Laboratoire repart donc
        // du début de partie, sauf position explicitement transmise par
        // l'éditeur ou le scanner.
        let initialFEN = startFEN
        _settings = State(initialValue: saved)
        _useCustomFEN = State(initialValue: initialFEN != nil)
        _fenText = State(initialValue: initialFEN ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let resumable, !resumable.isComplete {
                    resumeBanner(resumable)
                }

                // Les deux moteurs dans UNE carte : un match A/B se règle en
                // comparant les deux forces, or deux sections séparées les
                // éloignaient d'un en-tête et d'une marge, obligeant à faire
                // l'aller-retour de mémoire.
                SettingsSection(title: "Moteurs", systemImage: "cpu.fill", tint: Theme.rose) {
                    VStack(spacing: 14) {
                        strengthEditor(
                            name: "Moteur A", elo: $settings.sideAEloSlider,
                            bookOn: $settings.sideABookEnabled, tint: Theme.accent
                        )
                        Divider().overlay(Theme.stroke)
                        strengthEditor(
                            name: "Moteur B", elo: $settings.sideBEloSlider,
                            bookOn: $settings.sideBBookEnabled, tint: Theme.info
                        )
                    }
                }

                SettingsSection(title: "Série", systemImage: "chart.bar.fill", tint: Theme.rose) {
                    VStack(alignment: .leading, spacing: 16) {
                        gameCountEditor
                        ToggleRow(label: "Alterner les couleurs à chaque partie", isOn: $settings.alternateColors)
                        ToggleRow(label: "Abandon autorisé (camp perdant)", isOn: $settings.resignationEnabled)
                        ToggleRow(label: "Nul par accord autorisé", isOn: $settings.drawAgreementEnabled)
                        Text("Les nulles selon les règles (pat, matériel insuffisant, 50 coups, répétition) sont toujours déclarées.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                        ToggleRow(label: "Animer le plateau (sinon mode rapide)", isOn: $settings.liveVisualization)
                    }
                }

                // `LabGameSettings.startFEN` existait dans le modèle et était
                // déjà consommé par `startingPosition`, mais AUCUNE UI ne le
                // réglait : la fonctionnalité était inatteignable.
                SettingsSection(title: "Départ", systemImage: "flag.fill", tint: Theme.rose) {
                    VStack(alignment: .leading, spacing: 12) {
                        ToggleRow(label: "Position personnalisée (FEN)", isOn: $useCustomFEN.animation())

                        if useCustomFEN {
                            TextField("Position de départ (FEN)", text: $fenText, prompt: Text("rnbqkbnr/pppppppp/…").foregroundStyle(Theme.textTertiary))
                                .labelsHidden()
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Theme.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: fenText) { fenError = false }
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
                                .accessibilityIdentifier("scanLabStartPosition")
                            }

                            Text("Toutes les parties de la série partiront de cette position.")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }

                SettingsSection(title: "Réglages avancés", systemImage: "slider.horizontal.3", tint: Theme.rose) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Réflexion par coup")
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(movetimeLabel(settings.movetimeMs))
                                    .foregroundStyle(Theme.textSecondary)
                                    .monospacedDigit()
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(settings.movetimeMs) },
                                    set: { settings.movetimeMs = Int($0) }
                                ),
                                in: 50...5000, step: 50
                            )
                            .tint(Theme.accent)
                            Text("Jusqu'à 5 s/coup — utile pour laisser respirer le moteur à Elo élevé.")
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            CategoryHeader("Livre d'ouvertures")
                            HStack(spacing: 8) {
                                ChipButton(label: "Lignes principales", systemImage: nil, isSelected: settings.bookWidth == .mainLinesOnly) {
                                    settings.bookWidth = .mainLinesOnly
                                }
                                ChipButton(label: "Avec variantes", systemImage: nil, isSelected: settings.bookWidth == .includeSidelines) {
                                    settings.bookWidth = .includeSidelines
                                }
                            }
                        }

                        // Lot 2.D. Le défaut suit la longueur de la série
                        // (`LabGameSettings.keepAwake`) : c'est le `?? ` du
                        // binding, qui n'écrit le réglage que si l'utilisateur
                        // y touche.
                        VStack(alignment: .leading, spacing: 6) {
                            ToggleRow(
                                label: "Empêcher la mise en veille",
                                isOn: Binding(
                                    get: { settings.keepAwake },
                                    set: { settings.keepAwakeSetting = $0 }
                                )
                            )
                            Text("Une série tourne plusieurs minutes sans qu'on touche l'écran : sans ça, l'appareil s'endort et la série s'arrête.")
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .appBackground()
        .navigationTitle("Laboratoire")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lancer") { start() }
                    .fontWeight(.semibold)
                    .tint(Theme.accent)
            }
        }
        .onAppear { resumable = LabAutosaveStore.load() }
        .sheet(isPresented: $showPositionEditor) {
            positionEditorSheet
        }
        .sheet(isPresented: $showScanner) {
            scannerSheet
        }
    }

    /// Même garde que l'écran Jouer : un FEN illégal ne doit JAMAIS atteindre
    /// le moteur — a fortiori ici, où il servirait de départ à toute une série.
    private func start() {
        let trimmedFEN = fenText.trimmingCharacters(in: .whitespacesAndNewlines)
        if useCustomFEN {
            guard FENValidator.isLegal(trimmedFEN) else {
                fenError = true
                return
            }
        }

        var launched = settings
        launched.startFEN = useCustomFEN ? trimmedFEN : nil

        // On mémorise tout SAUF la position : voir l'init.
        var persisted = launched
        persisted.startFEN = nil
        LabSettingsStore.save(persisted)
        LabAutosaveStore.clear()
        onStart(launched)
    }

    /// Éditeur/scanner en FEUILLE, qui RAPPORTE sa position dans le champ :
    /// les réglages de série déjà choisis survivent au détour.
    private var positionEditorSheet: some View {
        let trimmed = fenText.trimmingCharacters(in: .whitespacesAndNewlines)

        return NavigationStack {
            PositionEditorView(
                initialFEN: FENValidator.isLegal(trimmed) ? trimmed : nil,
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
                // chaque étape (« Changer », « Recadrer »).
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

    // MARK: Sous-vues

    /// « 850 ms » sous 1 s, « 2,5 s » au-delà.
    private func movetimeLabel(_ ms: Int) -> String {
        ms < 1000 ? "\(ms) ms" : String(format: "%.1f s", Double(ms) / 1000)
    }

    /// Un moteur sur trois lignes serrées : identité + force sur la même
    /// ligne (le `title2` d'avant mangeait une ligne entière pour un mot),
    /// curseur, puis le livre en chip plutôt qu'en interrupteur pleine
    /// largeur — c'est un réglage binaire secondaire, pas un titre.
    private func strengthEditor(
        name: LocalizedStringKey, elo: Binding<Double>, bookOn: Binding<Bool>, tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 10, height: 10).glow(tint, radius: 5)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(EngineStrength(sliderValue: elo.wrappedValue).displayLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Slider(value: elo, in: EngineStrength.sliderRange, step: 10)
                .tint(tint)
            ChipButton(label: "Livre d'ouvertures", systemImage: "book.closed", isSelected: bookOn.wrappedValue) {
                bookOn.wrappedValue.toggle()
            }
        }
    }

    private var gameCountEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Nombre de parties")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(settings.gameCount)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
            Slider(
                value: Binding(get: { Double(settings.gameCount) }, set: { settings.gameCount = Int($0) }),
                in: 1...500, step: 1
            )
            .tint(Theme.accent)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach([10, 20, 50, 100, 200], id: \.self) { n in
                    ChipButton(label: "\(n)", systemImage: nil, isSelected: settings.gameCount == n) {
                        settings.gameCount = n
                    }
                }
            }
        }
    }

    private func resumeBanner(_ state: LabSeriesState) -> some View {
        Button {
            onResume(state)
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemImage: "arrow.clockwise", tint: Theme.warning, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reprendre la série")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(state.completed.count) / \(state.settings.gameCount) parties jouées")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .cardStyle()
            .overlay(Theme.cardShape.strokeBorder(Theme.warning.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.pressable)
    }
}
