import SwiftUI

/// Écran de configuration d'une partie "deux humains sur le même appareil".
struct TwoPlayerSetupView: View {
    let onStart: (TwoPlayerGameSettings) -> Void
    /// Reprendre la partie à deux laissée en cours — fournie par l'accueil.
    private let onResume: (TwoPlayerGameAutosave) -> Void
    /// Position de départ imposée — reprise depuis un autre mode (lecteur
    /// d'ouverture/finale, partie contre le moteur) via le sélecteur rapide.
    /// `nil` : partie neuve, position standard, comme avant.
    private let initialFEN: String?
    private let navigationTitleKey: LocalizedStringKey

    @State private var whiteName: String
    @State private var blackName: String
    @State private var rotationMode: TwoPlayerGameSettings.RotationMode
    @State private var timeLimit: TimeLimitSelection
    /// La partie en cours, relue à l'ouverture de l'écran : « Commencer » l'EFFACERAIT, l'écran le dit
    /// d'abord (il ne le faisait pas, même sur un seul appareil — relevé le 16/11/2026, comme sur Android).
    @State private var resumable: TwoPlayerGameAutosave?
    @State private var resumableOrigin: String?
    @State private var confirmReplace = false

    init(initialFEN: String? = nil,
         onResume: @escaping (TwoPlayerGameAutosave) -> Void = { _ in },
         onStart: @escaping (TwoPlayerGameSettings) -> Void) {
        self.onStart = onStart
        self.onResume = onResume
        self.initialFEN = initialFEN
        self.navigationTitleKey = initialFEN == nil ? "Deux joueurs" : "Continuer la partie"
        // Pas de réglages sauvegardés (tout premier lancement) : le défaut du
        // modèle est câblé en français ("Blancs"/"Noirs") — on le traduit
        // dans la langue active plutôt que de le montrer tel quel à un
        // utilisateur anglophone. Un nom déjà sauvegardé, lui, reste
        // intouché : c'est ce que la personne a réellement tapé (ou choisi
        // de garder) une fois.
        let stored = TwoPlayerSettingsStore.load()
        let saved = stored ?? .default

        _whiteName = State(initialValue: stored == nil
            ? PlayerName.white : PlayerName.display(saved.whiteName, fallback: PlayerName.white))
        _blackName = State(initialValue: stored == nil
            ? PlayerName.black : PlayerName.display(saved.blackName, fallback: PlayerName.black))
        _rotationMode = State(initialValue: saved.rotationMode)
        _timeLimit = State(initialValue: TimeLimitSelection(
            savedID: saved.timeControlID, customMinutes: saved.customMinutes,
            customIncrement: saved.customIncrementSeconds, memoryKey: "twoPlayer"))
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
                    // Des rangées d'option, pas des chips : le choix engage
                    // toute la partie et les libellés en parenthèses
                    // (« Table (icônes retournées) ») n'expliquaient rien.
                    // Ici chaque option dit ce qu'elle fait.
                    VStack(spacing: 8) {
                        OptionRow(
                            title: "Face à face",
                            caption: "Le plateau pivote vers le joueur au trait — on se passe l'appareil.",
                            systemImage: "arrow.triangle.2.circlepath",
                            isSelected: rotationMode == .faceToFace,
                            tint: Theme.violet
                        ) {
                            rotationMode = .faceToFace
                        }
                        OptionRow(
                            title: "Côte à côte",
                            caption: "Le plateau ne bouge pas — vous regardez du même côté.",
                            systemImage: "person.2.fill",
                            isSelected: rotationMode == .fixed,
                            tint: Theme.violet
                        ) {
                            rotationMode = .fixed
                        }
                        OptionRow(
                            title: "Autour d'une table",
                            caption: "Appareil posé à plat : nom, pendule et boutons d'en face sont retournés.",
                            systemImage: "table.furniture",
                            isSelected: rotationMode == .tabletop,
                            tint: Theme.violet
                        ) {
                            rotationMode = .tabletop
                        }
                    }
                }

                TimeLimitSection(selection: $timeLimit, tint: Theme.warning)
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .appBackground()
        .navigationTitle(navigationTitleKey)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .primaryActionBar("Commencer", tint: Theme.info) { start() }
        .onAppear {
            resumable = AutosaveStore.loadTwoPlayer()
            resumableOrigin = resumable == nil ? nil
                : SyncedAutosave.twoPlayer.origin().map { DeviceModelName.display($0) }
        }
        .replaceGameAlert(isPresented: $confirmReplace, moveCount: resumable?.moveLANs.count ?? 0,
                          origin: resumableOrigin, onResume: {
            if let resumable { onResume(resumable) }
        }, onReplace: { launch() })
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

    private var effectiveTimeControl: TimeControl { timeLimit.effective }
    private var customMinutes: Int { timeLimit.customMinutes }
    private var customIncrement: Int { timeLimit.customIncrement }

    /// Garde-fou : une partie en cours serait effacée par la nouvelle.
    private func start() {
        if resumable != nil {
            confirmReplace = true
        } else {
            launch()
        }
    }

    private func launch() {
        let settings = TwoPlayerGameSettings(
            whiteName: whiteName.trimmingCharacters(in: .whitespaces).isEmpty ? LocalizationController.string("Blancs") : whiteName,
            blackName: blackName.trimmingCharacters(in: .whitespaces).isEmpty ? LocalizationController.string("Noirs") : blackName,
            rotationMode: rotationMode,
            timeControlID: effectiveTimeControl.id,
            customMinutes: customMinutes,
            customIncrementSeconds: customIncrement,
            startFEN: initialFEN
        )
        timeLimit.remember(memoryKey: "twoPlayer")
        TwoPlayerSettingsStore.save(settings)
        onStart(settings)
    }
}
