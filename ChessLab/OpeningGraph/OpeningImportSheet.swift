import SwiftUI
import UniformTypeIdentifiers

/// Ajout d'un répertoire personnel : coller un PGN, ouvrir un `.pgn`, ou
/// recevoir le fichier d'un cours partagé par quelqu'un d'autre.
///
/// Le PGN est le format d'échange de fait des répertoires — une étude Lichess,
/// un chapitre de livre saisi, un export SCID. Comme `ChessKit` sait déjà lire
/// les variantes entre parenthèses, on récupère l'arbre complet et pas
/// seulement une ligne (voir ``OpeningPGNImporter``).
struct OpeningImportSheet: View {
    /// Appelé après un import réussi, avec l'entrée créée.
    let onImported: (OpeningCatalogEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    /// Vrai tant que l'utilisateur n'a pas touché au champ : on peut alors
    /// continuer à le remplir tout seul depuis le PGN. Dès qu'il écrit, on
    /// n'y touche plus — rien de plus agaçant qu'un champ qui se réécrit sous
    /// les doigts.
    @State private var nameEditedByUser = false
    @State private var side: OpeningSide = .white
    @State private var pgn = ""
    @State private var errorMessage: String?
    @State private var notice: String?
    @State private var showFileImporter = false

    private var pgnType: UTType { UTType(filenameExtension: "pgn") ?? .plainText }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    nameField
                    sideField
                    pgnField
                    if let errorMessage { message(errorMessage, tint: Theme.danger, icon: "exclamationmark.triangle.fill") }
                    if let notice { message(notice, tint: Theme.warning, icon: "info.circle.fill") }
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Ajouter un répertoire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importer", action: importPGN)
                        .disabled(pgn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("opening_import_confirm")
                }
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showFileImporter,
            // `.json` accepte AUSSI un cours exporté depuis l'app par un ami :
            // c'est exactement le même format qu'un cours embarqué, donc rien
            // de plus à écrire pour le recevoir.
            allowedContentTypes: [pgnType, .json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFile(result)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collez un PGN de répertoire (les variantes entre parenthèses sont conservées), ouvrez un fichier .pgn, ou recevez le répertoire qu'un ami vous a partagé.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                PasteButton(payloadType: String.self) { strings in
                    pgn = strings.first ?? ""
                }
                .buttonBorderShape(.capsule)
                .labelStyle(.titleAndIcon)

                Button {
                    showFileImporter = true
                } label: {
                    Label("Ouvrir un fichier", systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.surfaceElevated, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Nom")
            TextField("Nom du répertoire", text: $name)
                .onChange(of: name) { _, _ in nameEditedByUser = true }
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                .accessibilityIdentifier("opening_import_name")
        }
    }

    /// Le camp décide de quel côté l'entraînement interroge : c'est le seul
    /// choix qu'un PGN ne porte pas et qu'on ne peut pas deviner sans risque.
    private var sideField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Camp étudié")
            HStack(spacing: 8) {
                ChipButton(label: "Blancs", systemImage: nil, isSelected: side == .white) { side = .white }
                    .accessibilityIdentifier("opening_import_white")
                ChipButton(label: "Noirs", systemImage: nil, isSelected: side == .black) { side = .black }
                    .accessibilityIdentifier("opening_import_black")
            }
        }
    }

    private var pgnField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("PGN")
            TextEditor(text: $pgn)
                // Un PGN COLLÉ doit remplir le nom comme un fichier importé :
                // l'information est dans le texte, la réclamer serait la faire
                // ressaisir.
                .onChange(of: pgn) { _, newValue in
                    guard !nameEditedByUser else { return }
                    if let suggested = OpeningPGNImporter.suggestedName(fromPGN: newValue) {
                        name = suggested
                        nameEditedByUser = false
                    }
                }
                .font(.footnote.monospaced())
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200)
                .padding(8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                .accessibilityIdentifier("opening_import_pgn")
        }
    }

    private func fieldLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold)).foregroundStyle(Theme.textTertiary)
            .textCase(.uppercase).tracking(0.4)
    }

    private func message(_ text: String, tint: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(.footnote).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    // MARK: Actions

    private func importPGN() {
        errorMessage = nil
        notice = nil
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let result = try OpeningPGNImporter.course(
                fromPGN: pgn,
                name: title.isEmpty ? LocalizationController.string("Répertoire importé") : title,
                side: side,
                id: UserOpeningStore.newIdentifier()
            )
            let entry = try UserOpeningStore.shared.save(result.course)
            // On ne tait pas ce qui a été écarté : un répertoire amputé en
            // silence est pire qu'un import refusé.
            if result.skippedGames > 0 || result.skippedMoves > 0 {
                notice = LocalizationController.string(
                    "Importé, mais %d partie(s) et %d coup(s) illisibles ont été ignorés.",
                    result.skippedGames, result.skippedMoves
                )
            }
            onImported(entry)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleFile(_ result: Result<[URL], Error>) {
        errorMessage = nil
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
            return
        }

        // Un `.json` est un cours DÉJÀ construit (partagé par quelqu'un) : il
        // entre tel quel, sans repasser par le convertisseur ni par les champs
        // nom/camp, qu'il porte lui-même.
        if url.pathExtension.lowercased() == "json" {
            do {
                let entry = try UserOpeningStore.shared.importCourseFile(at: url)
                onImported(entry)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            errorMessage = LocalizationController.string("Fichier illisible.")
            return
        }
        pgn = text
        // Le nom vient du PGN quand il en porte un ; le nom de fichier n'est
        // qu'un dernier recours, souvent un identifiant illisible.
        if !nameEditedByUser || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let suggested = OpeningPGNImporter.suggestedName(fromPGN: text)
                ?? url.deletingPathExtension().lastPathComponent
            name = suggested
            // Renseigné par nous, pas par l'utilisateur : un PGN suivant peut
            // encore le remplacer.
            nameEditedByUser = false
        }
    }
}
