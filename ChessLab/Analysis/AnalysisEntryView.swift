import ChessKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Écran de choix de la source pour le mode Analyser : dernière partie,
/// PGN collé/saisi, fichier importé, position FEN, ou bibliothèque.
struct AnalysisEntryView: View {
    let onSelect: (AnalysisSource) -> Void
    let onOpenLibrary: () -> Void
    let onOpenPositionEditor: () -> Void
    let onOpenScanner: () -> Void

    @Query(sort: \GameRecord.playedAt, order: .reverse) private var records: [GameRecord]

    @State private var pastedPGN = ""
    @State private var showPasteSheet = false
    @State private var fenText = ""
    @State private var showFENSheet = false
    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var showOtherSources = false

    private var lastGamePGN: String? {
        guard let pgn = records.first?.pgn, !pgn.isEmpty else { return nil }
        return pgn
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Les trois chemins courts d'abord : scanner une position sous
                // les yeux, rouvrir une partie rangée, reprendre la dernière.
                // Les quatre autres demandent de FOURNIR un texte ou de
                // composer une position — un travail, pas un raccourci — et
                // sont donc repliés.
                entryCard(
                    title: "Scanner une position", subtitle: "Capture d'écran, photo ou plateau réel",
                    systemImage: "camera.viewfinder", tint: Theme.accent
                ) {
                    onOpenScanner()
                }
                entryCard(
                    title: "Bibliothèque", subtitle: "\(records.count) partie(s) enregistrée(s)",
                    systemImage: "books.vertical", tint: Theme.warning, isEnabled: !records.isEmpty
                ) {
                    onOpenLibrary()
                }
                if let lastGamePGN {
                    entryCard(
                        title: "Dernière partie", subtitle: "Reprendre l'analyse là où elle s'est arrêtée",
                        systemImage: "clock.arrow.circlepath", tint: Theme.info
                    ) {
                        onSelect(.pgn(lastGamePGN))
                    }
                }

                disclosureCard

                if showOtherSources {
                    entryCard(title: "Coller un PGN", subtitle: "Depuis le presse-papiers ou saisi", systemImage: "doc.on.clipboard", tint: Theme.info) {
                        importError = nil
                        pastedPGN = ""
                        showPasteSheet = true
                    }
                    entryCard(title: "Importer un fichier", subtitle: "Fichier .pgn", systemImage: "doc.badge.plus", tint: Theme.teal) {
                        showFileImporter = true
                    }
                    entryCard(title: "Position FEN", subtitle: "Analyser depuis une position donnée", systemImage: "square.grid.3x3", tint: Theme.violet) {
                        importError = nil
                        fenText = ""
                        showFENSheet = true
                    }
                    entryCard(
                        title: "Éditeur de position", subtitle: "Composer une position sur le plateau",
                        systemImage: "square.and.pencil", tint: Theme.rose
                    ) {
                        onOpenPositionEditor()
                    }
                }
            }
            .padding(20)
            .animation(Theme.gentle, value: showOtherSources)
        }
        .appBackground()
        .navigationTitle("Analyser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showPasteSheet) {
            TextImportSheet(
                title: "Coller un PGN", text: $pastedPGN, errorMessage: importError,
                placeholder: "1. e4 e5 2. Nf3 …", confirmLabel: "Lancer l'analyse"
            ) {
                validate(pgn: pastedPGN)
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showFENSheet) {
            TextImportSheet(
                title: "Position FEN", text: $fenText, errorMessage: importError,
                placeholder: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", confirmLabel: "Lancer l'analyse"
            ) {
                validate(fen: fenText)
            }
            .preferredColorScheme(.dark)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "pgn") ?? .plainText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    /// En-tête repliable des sources « à fournir ». Un bouton plutôt qu'un
    /// `DisclosureGroup` : celui-ci impose son propre chevron et ses marges,
    /// et jurerait avec les cartes qui l'entourent.
    private var disclosureCard: some View {
        Button {
            showOtherSources.toggle()
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemImage: "square.and.pencil", tint: Theme.teal, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Autres sources")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("PGN, position FEN, éditeur")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(showOtherSources ? 0 : -90))
            }
            .cardStyle()
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("analysisOtherSources")
        .accessibilityLabel(Text("Autres sources"))
    }

    private func entryCard(
        title: LocalizedStringKey, subtitle: LocalizedStringKey, systemImage: String, tint: Color = Theme.accent,
        isEnabled: Bool = true, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconBadge(systemImage: systemImage, tint: tint, size: 44, isEnabled: isEnabled)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isEnabled ? Theme.textPrimary : Theme.textTertiary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if isEnabled {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .cardStyle()
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    private func validate(pgn: String) {
        let trimmed = pgn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            importError = "Collez ou saisissez un PGN."
            return
        }
        // Assainit (lignes vides multiples, commentaire d'intro) et, pour un
        // texte multi-parties (base .pgn, export multi-chapitres), retient la
        // première partie plutôt que d'échouer en bloc — voir §A5.
        let games = PGNSanitizer.splitIntoGames(trimmed)
        let candidate = PGNSanitizer.sanitize(games.first ?? trimmed)
        guard (try? Game(pgn: candidate)) != nil else {
            importError = "Ce PGN n'a pas pu être lu — vérifiez sa syntaxe."
            return
        }
        importError = nil
        showPasteSheet = false
        onSelect(.pgn(candidate))
    }

    private func validate(fen: String) {
        let trimmed = fen.trimmingCharacters(in: .whitespacesAndNewlines)
        let errors = FENValidator.errors(in: trimmed)
        guard errors.isEmpty else {
            importError = errors.first
            return
        }
        importError = nil
        showFENSheet = false
        onSelect(.fen(trimmed))
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            importError = "Impossible de lire ce fichier."
            return
        }
        validate(pgn: text)
    }
}
