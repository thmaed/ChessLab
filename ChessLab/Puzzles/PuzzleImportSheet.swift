import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Importer des puzzles depuis un fichier PGN : un ou plusieurs fichiers à la
/// fois, chacun devient une collection (voir ``PuzzleCollectionStore``). On peut
/// aussi coller le texte. Pendant : `PuzzleImportScreen` (Android).
///
/// Le bilan reste affiché après l'import : combien de puzzles, combien de
/// parties écartées et POURQUOI — un fichier de mille puzzles dont douze sont
/// refusés ne doit pas se contenter de « 988 importés ».
struct PuzzleImportSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showsFileImporter = false
    @State private var pastedName = ""
    @State private var pastedText = Self.initialPastedText
    @State private var isWorking = false
    @State private var reports: [PuzzleCollectionStore.ImportReport] = []
    @State private var unreadable: [String] = []

    /// Outil de test (DEBUG seulement) : de quoi remplir la zone de collage sans
    /// la taper au clavier logiciel, qui « corrige » les guillemets d'un
    /// en-tête PGN. `|` y tient lieu de saut de ligne.
    private static var initialPastedText: String {
        #if DEBUG
        // L'argument SUIVANT le drapeau, lu tel quel : `UserDefaults` tenterait de
        // l'interpréter comme une liste de propriétés et l'écarterait.
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "-uiTestPuzzleImportText"), flag + 1 < arguments.count {
            return arguments[flag + 1].replacingOccurrences(of: "|", with: "\n")
        }
        #endif
        return ""
    }

    private var pgnTypes: [UTType] {
        [UTType(filenameExtension: "pgn") ?? .plainText, .plainText]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Un fichier PGN dont chaque partie est un puzzle : l'en-tête FEN donne la position, la ligne principale donne la solution (le premier coup est celui à trouver). Chaque fichier devient une collection, rangée à part de la bibliothèque.")
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button { showsFileImporter = true } label: {
                        Label("Ouvrir des fichiers PGN", systemImage: "doc.badge.plus")
                            .font(.headline)
                            .foregroundStyle(Theme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .disabled(isWorking)
                    .accessibilityIdentifier("puzzleImportFiles")

                    pasteSection

                    if isWorking {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Lecture en cours…")
                                .font(.callout)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    ForEach(unreadable, id: \.self) { name in
                        message(
                            LocalizationController.string("Impossible de lire « %@ ».", name),
                            tint: Theme.danger, icon: "exclamationmark.triangle.fill"
                        )
                    }
                    ForEach(reports.indices, id: \.self) { index in
                        reportCard(reports[index])
                    }
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Importer des puzzles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                        .accessibilityIdentifier("puzzleImportClose")
                }
            }
            .fileImporter(
                isPresented: $showsFileImporter, allowedContentTypes: pgnTypes, allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                importFiles(urls)
            }
        }
        .presentationDetents([.large])
    }

    private var pasteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ou coller du texte PGN")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.4)
            TextField("Nom de la collection", text: $pastedName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("puzzleImportName")
            TextEditor(text: $pastedText)
                .font(.system(.footnote, design: .monospaced))
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("puzzleImportText")
            Button("Importer le texte") { importPasted() }
                .buttonStyle(.bordered)
                .disabled(isWorking || pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("puzzleImportPasted")
        }
    }

    // MARK: Import

    private func importFiles(_ urls: [URL]) {
        isWorking = true
        Task {
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard let text = Self.readText(at: url) else {
                    unreadable.append(url.lastPathComponent)
                    continue
                }
                await importText(text, named: PuzzleCollectionStore.suggestedName(fromFile: url))
            }
            isWorking = false
        }
    }

    private func importPasted() {
        let text = pastedText
        let name = pastedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? LocalizationController.string("Collection importée") : pastedName
        isWorking = true
        Task {
            await importText(text, named: name)
            isWorking = false
            pastedText = ""
        }
    }

    /// La lecture se fait HORS du fil principal (mille parties, un SAN à
    /// résoudre par coup) ; l'écriture en base, elle, reste sur lui.
    private func importText(_ text: String, named name: String) async {
        let parsed = await Task.detached(priority: .userInitiated) {
            PuzzleCollectionImporter.parse(text)
        }.value
        reports.append(PuzzleCollectionStore.add(parsed, toCollection: name, in: modelContext))
    }

    /// UTF-8, à défaut Latin-1 : les fichiers venus de Windows ou d'un vieux
    /// logiciel d'échecs ne sont pas toujours en UTF-8.
    private static func readText(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    // MARK: Bilan

    private func reportCard(_ report: PuzzleCollectionStore.ImportReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: report.added > 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(report.added > 0 ? Theme.accent : Theme.warning)
                Text(report.collection)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }
            Text(Self.summary(of: report))
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(report.parsed.skipped.prefix(Self.skippedShown)), id: \.gameNumber) { skip in
                Text("• " + Self.describe(skip))
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if report.parsed.skipped.count > Self.skippedShown {
                Text(LocalizationController.string(
                    "… et %lld autres parties écartées.", report.parsed.skipped.count - Self.skippedShown
                ))
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("puzzleImportReport")
    }

    private func message(_ text: String, tint: Color, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.callout)
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Combien de parties écartées on détaille ; le reste est résumé.
    static let skippedShown = 5

    /// « 947 puzzles ajoutés · 12 parties écartées », sur une ligne.
    static func summary(of report: PuzzleCollectionStore.ImportReport) -> String {
        if report.parsed.gameCount == 0 || (report.added == 0 && report.alreadyThere == 0 && report.parsed.skipped.isEmpty) {
            return LocalizationController.string("Aucun puzzle trouvé dans ce fichier.")
        }
        var parts = [LocalizationController.string("%lld puzzles ajoutés", report.added)]
        if report.alreadyThere > 0 {
            parts.append(LocalizationController.string("%lld déjà présents", report.alreadyThere))
        }
        if report.parsed.duplicates > 0 {
            parts.append(LocalizationController.string("%lld en double dans le fichier", report.parsed.duplicates))
        }
        if !report.parsed.skipped.isEmpty {
            parts.append(LocalizationController.string("%lld parties écartées", report.parsed.skipped.count))
        }
        return parts.joined(separator: " · ")
    }

    static func describe(_ skip: PuzzleCollectionImporter.Skip) -> String {
        let number = skip.gameNumber
        switch skip.reason {
        case .missingFEN:
            return LocalizationController.string("Partie %lld : pas de position de départ (FEN).", number)
        case .invalidFEN:
            return LocalizationController.string("Partie %lld : position de départ (FEN) illisible.", number)
        case .noMoves:
            return LocalizationController.string("Partie %lld : aucun coup.", number)
        case .illegalMove(let san):
            return LocalizationController.string("Partie %lld : le coup %@ ne se joue pas.", number, san)
        }
    }
}
