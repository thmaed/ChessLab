import CloudKit
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
    /// Drapeau LOCAL du nouvel explorateur d'ouvertures en graphe (aperçu),
    /// même clé que ``OpeningsGraphFeature`` — off par défaut.
    @AppStorage("openingsGraphEnabled") private var openingsGraphEnabled = false
    /// Horodatage de la dernière vérification/fusion locale (pour l'affichage).
    @AppStorage("openingsLastReconcileAt") private var lastReconcileAt = 0.0
    /// État du compte iCloud (chargé à l'apparition).
    @State private var iCloudStatus: CKAccountStatus?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                languageSection
                boardThemeSection
                pieceSetSection
                notationSection
                feedbackSection
                syncSection
                if OpeningsGraphFeature.hasBundledCourses { previewSection }
                helpSection
                licensesSection
            }
            .padding(20)
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
            VStack(spacing: 4) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        settings.appLanguage = language
                    } label: {
                        HStack(spacing: 12) {
                            Text(language.settingsLabel)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if settings.appLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("language_\(language.rawValue)")
                    if language != AppLanguage.allCases.last {
                        Divider().overlay(Theme.stroke)
                    }
                }
            }
            .cardStyle()
        }
    }

    /// Chaque thème est prévisualisé avec les pièces RÉELLES du jeu courant, sur
    /// ses propres couleurs de cases : on voit le couple plateau + pièces, pas
    /// juste une pastille de couleur.
    private var boardThemeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Thème du plateau")
            VStack(spacing: 8) {
                ForEach(Array(BoardTheme.all.enumerated()), id: \.element.id) { index, theme in
                    Button { settings.boardThemeID = theme.id } label: {
                        selectableRow(
                            preview: piecePreview(theme: theme, setPrefix: settings.pieceSet.assetPrefix),
                            label: theme.label,
                            isSelected: settings.boardThemeID == theme.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("boardTheme_\(theme.id)")
                    if index != BoardTheme.all.count - 1 { Divider().overlay(Theme.stroke) }
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
            VStack(spacing: 8) {
                ForEach(Array(PieceSet.all.enumerated()), id: \.element.id) { index, set in
                    Button { settings.pieceSetID = set.id } label: {
                        selectableRow(
                            preview: piecePreview(theme: settings.boardTheme, setPrefix: set.assetPrefix),
                            label: set.label,
                            isSelected: settings.pieceSetID == set.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pieceSet_\(set.id)")
                    if index != PieceSet.all.count - 1 { Divider().overlay(Theme.stroke) }
                }
            }
            .cardStyle()
        }
    }

    /// Ligne commune aux deux sélecteurs : aperçu à gauche, libellé, coche.
    private func selectableRow(preview: some View, label: String, isSelected: Bool) -> some View {
        HStack(spacing: 14) {
            preview
            Text(LocalizedStringKey(label))
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    /// Bandeau d'aperçu : quelques pièces réelles (`<prefix>_wK`…) posées sur
    /// des cases alternées aux couleurs du thème. Charge directement les assets
    /// (pas de `Piece` à construire) et sert plateau ET jeu de pièces.
    private func piecePreview(theme: BoardTheme, setPrefix: String) -> some View {
        let samples = ["wK", "wQ", "wN", "bK", "bQ", "bN"]
        return HStack(spacing: 0) {
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
    /// Bascule la clé `cloudKitSyncEnabled` que ``ChessLabApp`` lit au
    /// lancement : le `ModelContainer` ne peut pas changer de base à chaud,
    /// d'où la mention « au prochain lancement ». Utilise l'iCloud PRIVÉ de
    /// l'utilisateur (aucun serveur ChessLab, aucun compte à créer) ; l'app
    /// reste entièrement fonctionnelle hors ligne, la synchro n'est qu'une
    /// couche en plus.
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Synchronisation")
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Synchroniser via iCloud", isOn: $cloudSyncEnabled)
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.textPrimary)
                Text("Vos parties suivent tous vos appareils via votre iCloud privé. Désactivée par défaut ; l'app fonctionne entièrement hors ligne. La modification prend effet au prochain lancement.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Votre progression d'entraînement (puzzles et ouvertures) est synchronisée de la même façon.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if cloudSyncEnabled {
                    Divider().overlay(Theme.stroke)
                    syncStatusRow
                    if lastReconcileAt > 0 {
                        Text("Dernière vérification : \(Date(timeIntervalSince1970: lastReconcileAt).formatted(.relative(presentation: .named)))")
                            .font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                    Button(action: forceSync) {
                        Label("Synchroniser maintenant", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.pressable)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .task {
            iCloudStatus = try? await CKContainer(identifier: "iCloud.com.chesslab.ChessLab").accountStatus()
        }
    }

    /// État du compte iCloud, message clair si l'utilisateur n'est pas connecté.
    private var syncStatusRow: some View {
        let connected = iCloudStatus == .available
        let (icon, tint, text): (String, Color, LocalizedStringKey) = switch iCloudStatus {
        case .available: ("checkmark.icloud", Theme.accent, "Compte iCloud connecté")
        case nil: ("icloud", Theme.textTertiary, "Vérification du compte iCloud…")
        default: ("exclamationmark.icloud", Theme.warning, "Non connecté à iCloud — la synchro est en pause")
        }
        return HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(.caption).foregroundStyle(connected ? Theme.textSecondary : Theme.warning)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// Réconcilie localement (fusionne l'état synchronisé arrivé des autres
    /// appareils et pousse les changements en attente via la sauvegarde). La
    /// synchro CloudKit elle-même reste automatique et opaque.
    private func forceSync() {
        PuzzleProgressSync.reconcile(in: modelContext)
        OpeningProgressSync.reconcile(in: modelContext)
        lastReconcileAt = Date().timeIntervalSince1970
        Haptics.move()
    }

    /// Aperçu (déploiement progressif) : le nouvel explorateur d'ouvertures en
    /// graphe. Off par défaut ; l'onglet Ouvertures garde la bibliothèque
    /// existante tant que ce n'est pas activé. Un bouton « Explorateur »
    /// apparaît alors dans l'onglet Ouvertures.
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Aperçu")
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Explorateur d'ouvertures", isOn: $openingsGraphEnabled)
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.textPrimary)
                Text("Fonctionnalité en cours de développement : explore librement les variantes d'une ouverture, avec statistiques par coup. Le contenu s'enrichira au fil des mises à jour.")
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
                HStack(spacing: 8) {
                    ForEach(PieceNotation.allCases) { notation in
                        ChipButton(
                            label: LocalizedStringKey(notation.label), systemImage: nil,
                            isSelected: settings.pieceNotation == notation
                        ) {
                            settings.pieceNotation = notation
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

    private func settingRow<Choices: View>(
        label: String, help: String, @ViewBuilder choices: () -> Choices
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 8) { choices() }
            Text(help)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
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
