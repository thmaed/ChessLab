import SwiftData
import SwiftUI

/// Écran de réglages transversaux : thème de plateau **global et
/// persistant** (auparavant redéfini localement dans chaque écran de jeu),
/// sons et haptiques. Voir instructions.md §G8.
struct SettingsView: View {
    /// Ouvre l'aide (description des modules).
    var onOpenHelp: () -> Void = {}
    /// Ouvre les licences des composants tiers.
    var onOpenLicenses: () -> Void = {}
    /// Ouvre l'écran « Sources » des ouvertures.
    var onOpenSources: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Bindable private var settings = AppSettings.shared
    /// Lie le toggle à la MÊME clé UserDefaults que ``CloudSyncSettingsStore``
    /// (`cloudKitSyncEnabled`), que ``ChessLabApp`` relit au lancement pour
    /// construire le `ModelContainer` en `.automatic` (iCloud) ou `.none`.
    @AppStorage("cloudKitSyncEnabled") private var cloudSyncEnabled = false
    /// Les VRAIS échanges avec iCloud (voir ``CloudSyncMonitor``).
    private let monitor = CloudSyncMonitor.shared
    /// « Vos appareils » (voir ``CloudDeviceRegistry``), relu à l'apparition et à chaque changement.
    @State private var syncDevices: [CloudDeviceRecord] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                languageSection
                playerNameSection
                boardThemeSection
                pieceSetSection
                notationSection
                puzzleSection
                feedbackSection
                syncSection
                if OpeningsGraphFeature.hasBundledCourses { previewSection }
                helpSection
                licensesSection
                versionFooter
            }
            .padding(20)
            .frame(maxWidth: Theme.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .appBackground()
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Langue de l'interface. « Système » suit la langue de l'appareil
    /// (français si l'OS est en français, y compris suisse ou canadien ;
    /// anglais sinon).
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Langue")
            // Des pastilles qui se replient, plutôt que six rangées : le choix tient en deux lignes
            // (2.3 : cinq langues + « système »).
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(AppLanguage.allCases) { language in
                    ChipButton(
                        label: language.settingsLabel,
                        systemImage: language == .system ? "globe" : nil,
                        isSelected: settings.appLanguage == language
                    ) {
                        settings.appLanguage = language
                    }
                    .accessibilityIdentifier("language_\(language.rawValue)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    /// Le nom sous lequel on joue. Vide = « Vous », le défaut.
    ///
    /// Un testeur anglophone a cherché en vain comment s'y substituer un nom
    /// (27/09/2026) : on ne joue pas contre son ordinateur sous son état civil,
    /// mais un PGN partagé au club signé « You » ne vaut pas grand-chose.
    private var playerNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Votre nom")
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    "Vous", text: $settings.playerName,
                    prompt: Text("Vous").foregroundStyle(Theme.textTertiary)
                )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .foregroundStyle(Theme.textPrimary)
                .padding(10)
                .background(Theme.surfaceElevated, in: Theme.controlShape)
                .overlay(Theme.controlShape.strokeBorder(Theme.stroke, lineWidth: 1))
                .accessibilityIdentifier("playerNameField")
                Text("Il s'affiche sur votre plaque de joueur, dans la bibliothèque et dans les balises PGN des parties exportées. Laissez vide pour « Vous ».")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    /// Chaque thème est prévisualisé avec les pièces RÉELLES du jeu courant, sur
    /// ses propres couleurs de cases : on voit le couple plateau + pièces, pas
    /// juste une pastille de couleur.
    private var boardThemeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Thème du plateau")
            // Des VIGNETTES côte à côte (2.3) au lieu d'une liste : quatre lignes pleine largeur repoussaient
            // la notation et la synchronisation loin sous le pli. La grille adaptative donne 2 colonnes sur
            // iPhone, toutes les vignettes sur une rangée sur iPad, Mac et l'écran intérieur du Duo.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 10)], spacing: 10) {
                ForEach(BoardTheme.all, id: \.id) { theme in
                    Button { settings.boardThemeID = theme.id } label: {
                        selectableTile(
                            preview: piecePreview(theme: theme, setPrefix: settings.pieceSet.assetPrefix,
                                                  samples: ["wK", "bQ", "wN", "bK"]),
                            label: theme.label,
                            isSelected: settings.boardThemeID == theme.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("boardTheme_\(theme.id)")
                }
            }
            .cardStyle()
        }
    }

    /// Chaque jeu de pièces est prévisualisé avec ses pièces réelles, posées
    /// sur le thème de plateau COURANT — trois styles curés (classique,
    /// moderne, contrasté), tous sous licence libre (voir Licences).
    private var pieceSetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Jeu de pièces")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                ForEach(PieceSet.all, id: \.id) { set in
                    Button { settings.pieceSetID = set.id } label: {
                        selectableTile(
                            preview: piecePreview(theme: settings.boardTheme, setPrefix: set.assetPrefix,
                                                  samples: ["wK", "bQ", "wN"]),
                            label: set.label,
                            isSelected: settings.pieceSetID == set.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pieceSet_\(set.id)")
                }
            }
            .cardStyle()
        }
    }

    /// Vignette commune aux deux sélecteurs : aperçu, libellé dessous, contour et coche quand elle est choisie.
    private func selectableTile(preview: some View, label: String, isSelected: Bool) -> some View {
        VStack(spacing: 6) {
            preview
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
                Text(LocalizedStringKey(label))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(isSelected ? Theme.accent.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(isSelected ? Theme.accent.opacity(0.6) : Theme.stroke, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Bandeau d'aperçu : quelques pièces réelles (`<prefix>_wK`…) posées sur
    /// des cases alternées aux couleurs du thème. Charge directement les assets
    /// (pas de `Piece` à construire) et sert plateau ET jeu de pièces.
    private func piecePreview(theme: BoardTheme, setPrefix: String, samples: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(samples.enumerated()), id: \.offset) { i, name in
                ZStack {
                    Rectangle().fill(i.isMultiple(of: 2) ? theme.lightSquare : theme.darkSquare)
                    Image("\(setPrefix)_\(name)")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(3)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                }
                .frame(width: 30, height: 30)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Sons et vibrations")
            VStack(spacing: 4) {
                Toggle("Sons du plateau", isOn: $settings.soundsEnabled)
                Divider().overlay(Theme.stroke)
                Toggle("Retour haptique", isOn: $settings.hapticsEnabled)
            }
            .tint(Theme.accent)
            .foregroundStyle(Theme.textPrimary)
            .cardStyle()
        }
    }

    /// Synchronisation iCloud (optionnelle, désactivée par défaut).
    ///
    /// Refonte du 16/11/2026 (un utilisateur, deux appareils, chacun dans son état sans que rien ne le
    /// montre) : UN état en clair (``CloudSyncState``), les gestes quand il y a quelque chose à faire, et
    /// « Vos appareils » pour vérifier d'un coup d'œil que l'autre est relié.
    ///
    /// L'interrupteur (`cloudKitSyncEnabled`) commande À CHAUD les réglages et la partie en cours
    /// (``KeyValueSyncSwitch``) ; le conteneur SwiftData, lui, est choisi au lancement — d'où la « dernière
    /// étape » de relancement, une seule fois. Utilise l'iCloud PRIVÉ de l'utilisateur (aucun serveur
    /// ChessLab, aucun compte à créer) ; l'app reste entièrement fonctionnelle hors ligne.
    private var syncSection: some View {
        let state = monitor.state(enabled: cloudSyncEnabled)
        let registry = CloudDeviceRegistry.live
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Synchronisation")
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Synchroniser via iCloud", isOn: $cloudSyncEnabled)
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("syncToggle")
                Text("Vos parties, votre progression d'entraînement et la partie en cours suivent tous vos appareils via votre iCloud privé. Désactivée par défaut ; l'app fonctionne entièrement hors ligne.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(Theme.stroke)
                CloudSyncStatusRow(state: state)

                if state == .startsAfterRestart { CloudRestartSteps() }

                if !cloudSyncEnabled, let other = syncDevices.first(where: { $0.id != registry.identity.id }) {
                    // Synchro éteinte ici, allumée ailleurs : le dire, c'est la moitié de l'explication.
                    Text("Votre \(other.displayName) synchronise déjà ChessLab. Activez l'interrupteur pour le rejoindre.")
                        .font(.caption)
                        .foregroundStyle(Theme.info)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if cloudSyncEnabled, !syncDevices.isEmpty {
                    Divider().overlay(Theme.stroke)
                    CloudDevicesList(devices: syncDevices, ownID: registry.identity.id, appVersion: registry.appVersion) { name in
                        CloudDeviceName.custom = name
                        // Tout de suite dans la fiche : les autres appareils le verront au prochain échange.
                        CloudDeviceRegistry.live.checkIn(force: true)
                        refreshSyncDevices()
                    }
                }

                if showsManualSync(state) {
                    Divider().overlay(Theme.stroke)
                    manualSyncButton
                    manualSyncResult
                    syncDetails
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        // Les réglages et les parties en cours suivent l'interrupteur tout de suite ; la base SwiftData,
        // elle, est remplacée sans quitter l'app (écran de passage, puis retour ici — voir StoreHost). Si
        // quelque chose la retient, elle reste telle quelle et la carte dit « fermez et rouvrez ».
        .onChange(of: cloudSyncEnabled) { _, _ in
            monitor.clearManualResult()
            KeyValueSyncSwitch.apply()
            refreshSyncDevices()
            // Tâche NON structurée : elle survit à cet écran, que l'échange démonte.
            Task { await StoreHost.shared.followSyncSwitch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: CloudDevices.didChange)) { _ in refreshSyncDevices() }
        .task {
            refreshSyncDevices()
            await monitor.refreshAccount()
        }
    }

    private func refreshSyncDevices() {
        syncDevices = CloudDeviceRegistry.live.devices()
    }

    /// Le bouton n'a de sens que quand CloudKit tourne et qu'un compte est là.
    private func showsManualSync(_ state: CloudSyncState) -> Bool {
        switch state {
        case .syncing, .upToDate, .paused: true
        default: false
        }
    }

    /// Pour l'assistance : les deux sens, séparément. Replié par défaut — l'état du dessus suffit.
    private var syncDetails: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 2) {
                if monitor.lastSendAt == nil, monitor.lastReceiveAt == nil {
                    Text("Aucun échange avec iCloud pour l'instant")
                } else {
                    if let sent = monitor.lastSendAt {
                        Text("Dernier envoi vers iCloud : \(Text(sent, format: .relative(presentation: .named)))")
                    }
                    if let received = monitor.lastReceiveAt {
                        Text("Dernière réception depuis iCloud : \(Text(received, format: .relative(presentation: .named)))")
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        } label: {
            Text("Détails").font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .tint(Theme.textSecondary)
    }

    private var manualSyncButton: some View {
        Button {
            Task {
                await monitor.syncNow(context: modelContext)
                refreshSyncDevices()
                Haptics.move()
            }
        } label: {
            HStack(spacing: 6) {
                if monitor.isManualSyncRunning {
                    ProgressView().controlSize(.small)
                    Text("Synchronisation en cours…")
                } else {
                    Label("Synchroniser maintenant", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
        }
        .buttonStyle(.pressable)
        .disabled(monitor.isManualSyncRunning)
        .accessibilityIdentifier("syncNowButton")
    }

    /// Ce que le bouton a VU — sans promettre ce qu'iOS décide.
    @ViewBuilder private var manualSyncResult: some View {
        switch monitor.manualResult {
        case .exchanged:
            Text("Échange réussi avec iCloud.").font(.caption2).foregroundStyle(Theme.accent)
        case .nothingSeen:
            Text("Rien de nouveau : tout est à jour, ou iCloud choisira lui-même le moment.")
                .font(.caption2).foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        case .restartNeeded:
            Text("Réglages et partie en cours à jour. Le reste attend que vous fermiez et rouvriez ChessLab.")
                .font(.caption2).foregroundStyle(Theme.warning)
                .fixedSize(horizontal: false, vertical: true)
        case let .failed(message):
            Text(verbatim: message).font(.caption2).foregroundStyle(Theme.warning)
                .fixedSize(horizontal: false, vertical: true)
        case nil:
            EmptyView()
        }
    }

    /// Le numéro de version, là où on le cherche (retour d'un utilisateur,
    /// 28/10/2026 : il n'apparaissait que dans le titre des nouveautés de l'Aide).
    /// Lu dans le BUNDLE, comme ``HelpView`` : un numéro écrit en dur périme.
    private var versionFooter: some View {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return Text("Version \(version) (\(build))")
            .font(.footnote.monospacedDigit())
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
            .textSelection(.enabled)
            .accessibilityIdentifier("settingsVersion")
    }

    /// Module d'ouvertures en graphe : accessible via le bouton « Explorateur »
    /// (boussole) de l'onglet Ouvertures. Cette section explique et crédite les
    /// sources des données.
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Ouvertures")
            VStack(alignment: .leading, spacing: 8) {
                Text("Explore, apprends et entraîne tes ouvertures depuis l'onglet Ouvertures : lecteur pas à pas, rappel actif et répétition espacée. Le contenu s'enrichit au fil des mises à jour.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onOpenSources) {
                    HStack(spacing: 6) {
                        Label("Sources des données", systemImage: "text.book.closed")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.info)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                }
                .buttonStyle(.pressable)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    /// Notation des pièces (Lot 3.A). Française par défaut, comme l'exige le
    /// prompt ; l'app affichait jusqu'ici les lettres anglaises partout.
    private var notationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Notation des coups")
            VStack(alignment: .leading, spacing: 8) {
                // Quatre notations (2.3) : « Französisch » ne tient plus sur
                // une ligne à quatre de front — la rangée se replie.
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    // « Automatique » d'abord, et par défaut : la notation suit la langue de l'app.
                    ChipButton(
                        label: LocalizedStringKey("Automatique"), systemImage: nil,
                        isSelected: settings.pieceNotationChoice == nil
                    ) {
                        settings.pieceNotationChoice = nil
                    }
                    .accessibilityIdentifier("notation_auto")
                    ForEach(PieceNotation.allCases) { notation in
                        ChipButton(
                            label: LocalizedStringKey(notation.label), systemImage: nil,
                            isSelected: settings.pieceNotationChoice == notation
                        ) {
                            settings.pieceNotationChoice = notation
                        }
                        .accessibilityIdentifier("notation_\(notation.rawValue)")
                    }
                }
                Text(settings.pieceNotation.example)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                // Le PGN reste en lettres anglaises, et il faut le dire : un
                // export qui ne suit pas l'affichage a l'air d'un bug tant
                // qu'on n'a pas expliqué que c'est le standard.
                Text("Le PGN exporté reste en notation anglaise — c'est le standard, lisible par tous les autres logiciels.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    /// Essais par puzzle. Un seul par défaut : trois essais poussaient à
    /// « tenter un coup pour voir », alors qu'un puzzle s'entraîne en calculant
    /// la variante jusqu'au bout avant de poser la pièce.
    private var puzzleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Puzzles")
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(AppSettings.puzzleAttemptChoices, id: \.self) { count in
                        ChipButton(
                            label: count == 1 ? "1 essai" : "3 essais", systemImage: nil,
                            isSelected: settings.puzzleAttempts == count
                        ) {
                            settings.puzzleAttempts = count
                        }
                        .accessibilityIdentifier("puzzle_attempts_\(count)")
                    }
                }
                Text("Avec un seul essai, on calcule la variante jusqu'au bout avant de jouer — c'est tout l'intérêt de l'exercice. Trois essais laissent chercher en tâtonnant.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(Theme.stroke)
                Toggle("Afficher le thème du puzzle", isOn: $settings.showPuzzleTheme)
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("puzzle_show_theme")
                Text("Mat, fourchette, clouage… Masquez-le pour chercher l'idée sans indice.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    /// Aide : description succincte de chaque module.
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Aide")
            Button(action: onOpenHelp) {
                HStack(spacing: 12) {
                    IconBadge(systemImage: "questionmark.circle.fill", tint: Theme.accent, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Comment ça marche")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Ce que fait chaque mode.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openHelp")
            .cardStyle()
        }
    }

    /// Licences des composants tiers (Stockfish GPLv3, cburnett CC BY-SA…).
    private var licensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("À propos")
            Button(action: onOpenLicenses) {
                HStack(spacing: 12) {
                    IconBadge(systemImage: "doc.text.magnifyingglass", tint: Theme.textSecondary, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Licences")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Stockfish, ChessKit, pièces, puzzles.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openLicenses")
            .cardStyle()
        }
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
