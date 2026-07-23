import SwiftUI

/// Écran de réglages transversaux : thème de plateau **global et
/// persistant** (auparavant redéfini localement dans chaque écran de jeu),
/// sons et haptiques. Voir instructions.md §G8.
struct SettingsView: View {
    /// Ouvre l'aide (description des modules).
    var onOpenHelp: () -> Void = {}
    /// Ouvre les licences des composants tiers.
    var onOpenLicenses: () -> Void = {}

    @Bindable private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                languageSection
                boardThemeSection
                notationSection
                feedbackSection
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

    private var boardThemeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Thème du plateau")
            VStack(spacing: 10) {
                ForEach(BoardTheme.all) { theme in
                    Button {
                        settings.boardThemeID = theme.id
                    } label: {
                        HStack(spacing: 12) {
                            themeSwatch(theme)
                            Text(LocalizedStringKey(theme.label))
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if settings.boardThemeID == theme.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardStyle()
        }
    }

    private func themeSwatch(_ theme: BoardTheme) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                Rectangle().fill(i.isMultiple(of: 2) ? theme.lightSquare : theme.darkSquare)
            }
        }
        .frame(width: 44, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.stroke, lineWidth: 1))
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
