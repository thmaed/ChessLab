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

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameRecord.playedAt, order: .reverse) private var records: [GameRecord]

    /// Une seule zone de saisie pour le PGN ET la FEN : le format est
    /// reconnu tout seul (voir ``validate(text:)``). Deux entrées séparées
    /// obligeaient l'utilisateur à savoir NOMMER ce qu'il avait dans le
    /// presse-papiers avant de pouvoir le coller.
    @State private var importText = ""
    @State private var showTextSheet = false
    /// « Ajouter aussi à la bibliothèque » : l'analyse reste le geste par
    /// défaut — c'est l'écran Analyser — et le rangement devient une option
    /// qu'on coche, jamais une conséquence surprise.
    @State private var alsoImportToLibrary = false

    /// 🐛 Bug corrigé : il y avait DEUX `.fileImporter` sur cette vue, chacun
    /// avec son booléen. SwiftUI n'en présente qu'un — celui déclaré en
    /// dernier — et « Importer un fichier » ne s'ouvrait donc jamais. Un seul
    /// importeur, dont le MODE dit quoi faire du résultat.
    private enum FileImportMode { case analyse, library }
    /// 🐛 Bug corrigé : le mode vivait dans l'`Optional` qui pilotait aussi la
    /// présentation. À la fermeture du sélecteur, SwiftUI remet `isPresented`
    /// à `false`, ce qui EFFAÇAIT le mode — et le gestionnaire, appelé
    /// ensuite, lisait `nil` et retombait sur l'import simple. Un fichier
    /// destiné à la bibliothèque partait donc dans l'analyse, sans rien
    /// importer et sans rien dire. Deux états distincts : la présentation, et
    /// le mode, que la fermeture ne touche pas.
    @State private var fileImportMode: FileImportMode = .analyse
    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var showOtherSources = false
    @State private var libraryImportSummary: String?

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
                    entryCard(title: "Analyser PGN / FEN", subtitle: "Collez une partie ou une position — le format est reconnu tout seul", systemImage: "doc.on.clipboard", tint: Theme.info) {
                        importError = nil
                        importText = ""
                        showTextSheet = true
                    }
                    entryCard(title: "Importer un fichier", subtitle: "Fichier .pgn ou .fen", systemImage: "doc.badge.plus", tint: Theme.teal) {
                        importError = nil
                        fileImportMode = .analyse
                        showFileImporter = true
                    }
                    entryCard(title: "Importer des parties", subtitle: "Base .pgn (plusieurs parties) → bibliothèque", systemImage: "square.and.arrow.down.on.square", tint: Theme.warning) {
                        fileImportMode = .library
                        showFileImporter = true
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
        .sheet(isPresented: $showTextSheet) {
            TextImportSheet(
                title: "Analyser PGN / FEN", text: $importText, errorMessage: importError,
                placeholder: "1. e4 e5 2. Cf3 …\n\nou\n\nrnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
                confirmLabel: "Lancer l'analyse"
            ) {
                validate(text: importText)
            } accessory: {
                Toggle(isOn: $alsoImportToLibrary) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ajouter aussi à la bibliothèque")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Sans effet sur une position FEN — la bibliothèque range des parties.")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .tint(Theme.accent)
                .accessibilityIdentifier("alsoImportToLibrary")
            }
            .preferredColorScheme(.dark)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "pgn") ?? .plainText,
                UTType(filenameExtension: "fen") ?? .plainText,
                .plainText,
            ],
            allowsMultipleSelection: fileImportMode == .library
        ) { result in
            switch fileImportMode {
            case .library: handleLibraryImport(result)
            case .analyse: handleFileImport(result)
            }
        }
        .alert("Import terminé", isPresented: Binding(
            get: { libraryImportSummary != nil },
            set: { if !$0 { libraryImportSummary = nil } }
        )) {
            Button("OK", role: .cancel) { libraryImportSummary = nil }
        } message: {
            Text(libraryImportSummary ?? "")
        }
    }

    /// En-tête repliable des sources « à fournir ». Un bouton plutôt qu'un
    /// `DisclosureGroup` : celui-ci impose son propre chevron et ses marges,
    /// et jurerait avec les cartes qui l'entourent.
    /// En-tête de SECTION dépliante, et non carte de destination.
    ///
    /// Les cartes de cet écran mènent quelque part : elles portent une
    /// pastille d'icône et un fond, elles annoncent un départ. « Autres
    /// sources » ne mène nulle part — elle DÉPLIE le reste de la liste. Lui
    /// donner l'allure d'une destination promettait un écran qui n'existe pas.
    ///
    /// D'où la reprise du vocabulaire des en-têtes de section de l'app
    /// (`HomeView.sectionHeader`) : capsule d'accent, titre en petites
    /// capitales, filet de séparation. Le chevron pivote pour dire l'état, et
    /// le compte des options annonce ce qu'on va trouver.
    private var disclosureCard: some View {
        Button {
            showOtherSources.toggle()
        } label: {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Theme.accentGradient)
                    .frame(width: 18, height: 3)
                Text("Autres sources")
                    // Plus grand et plus clair que les en-têtes de section
                    // ordinaires : celui-ci est CLIQUABLE, il doit se
                    // distinguer d'un simple titre décoratif.
                    .font(.callout.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    // Le filet est élastique, pas le titre : sans cela il se
                    // coupait en deux lignes pour laisser de la place au trait.
                    .fixedSize(horizontal: true, vertical: false)
                Text("4")
                    .fixedSize()
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Theme.surface, in: Capsule())
                // Le filet occupe l'espace libre : il relie le titre au
                // chevron et marque la coupure avec ce qui précède.
                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(showOtherSources ? 0 : -90))
            }
            .padding(.top, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("analysisOtherSources")
        .accessibilityLabel(Text("Autres sources"))
        .accessibilityHint(Text(showOtherSources ? "Replier" : "Déplier quatre options"))
        .accessibilityAddTraits(.isButton)
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

    /// Reconnaît le format puis lance l'analyse.
    ///
    /// L'ordre n'est pas arbitraire : on essaie la FEN EN PREMIER parce que
    /// son validateur est strict — six champs, un placement de pièces
    /// cohérent — alors qu'un lecteur de PGN est permissif et accepterait une
    /// FEN comme un texte de coups vide. Dans l'autre sens, aucune ambiguïté :
    /// un PGN n'est jamais une FEN valide, et un PGN qui CONTIENT une balise
    /// `[FEN "…"]` échoue au validateur (le texte entier n'est pas une FEN) et
    /// part donc du bon côté.
    private func validate(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            importError = LocalizationController.string("Collez une partie (PGN) ou une position (FEN).")
            return
        }
        if FENValidator.errors(in: trimmed).isEmpty {
            importError = nil
            showTextSheet = false
            onSelect(.fen(trimmed))
            return
        }
        let games = PGNSanitizer.splitIntoGames(trimmed)
        let candidate = PGNSanitizer.sanitize(games.first ?? trimmed)
        if PGNLoader.game(from: candidate) != nil {
            // L'analyse ouvre la PREMIÈRE partie ; le rangement, lui, prend
            // TOUT le texte. Un fichier de neuf parties collé ici s'analyse
            // par la première et se range en entier — c'est ce qu'on attend
            // des deux gestes, et ils ne se contredisent pas.
            if alsoImportToLibrary {
                // En FOND : l'analyse s'ouvre tout de suite, le rangement
                // suit — sur une base de milliers de parties, il gelait
                // l'écran plusieurs secondes (bug18aout §7).
                let container = modelContext.container
                Task {
                    let outcome = await GameLibraryService.importPGNCollection(
                        text: trimmed, container: container
                    )
                    libraryImportSummary = summary(of: outcome)
                }
            }
            importError = nil
            showTextSheet = false
            onSelect(.pgn(candidate))
            return
        }
        // Le message nomme les DEUX formats : l'utilisateur ne sait pas
        // forcément lequel il a collé, et c'est justement le but de cet écran.
        // Si le texte RESSEMBLE à une FEN, on rend l'erreur précise du
        // validateur plutôt qu'un refus générique.
        if looksLikeFEN(trimmed), let detail = FENValidator.errors(in: trimmed).first {
            importError = detail
        } else {
            importError = LocalizationController.string("Ce texte n'a pu être lu ni comme une partie (PGN) ni comme une position (FEN).")
        }
    }

    /// Un texte d'une seule ligne dont le premier champ contient des « / » :
    /// c'est une FEN mal formée, pas un PGN. Sert uniquement à choisir le
    /// message d'erreur.
    private func looksLikeFEN(_ text: String) -> Bool {
        guard !text.contains("\n"), let first = text.split(separator: " ").first else { return false }
        return first.contains("/")
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        // L'échec était avalé en silence : l'écran ne bougeait pas et rien
        // n'expliquait pourquoi.
        if case let .failure(error) = result {
            importError = LocalizationController.string("Import impossible : %@", error.localizedDescription)
            return
        }
        guard case let .success(urls) = result, let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            importError = "Impossible de lire ce fichier."
            return
        }
        // Même détection que la saisie : un fichier contenant une FEN
        // s'analyse aussi bien qu'un .pgn.
        validate(text: text)
    }

    /// Importe UNE OU PLUSIEURS bases .pgn d'un coup dans la bibliothèque
    /// (toutes les parties de chaque fichier), puis annonce le total. À la
    /// différence de « Importer un fichier » (qui ouvre la première partie
    /// pour l'analyser), ceci range tout sans rien ouvrir.
    /// Compte rendu commun aux deux chemins d'import.
    private func summary(of outcome: GameLibraryService.ImportOutcome) -> String {
        var lines = ["\(outcome.imported) partie(s) ajoutée(s) à la bibliothèque."]
        if outcome.duplicates > 0 {
            lines.append("\(outcome.duplicates) déjà présente(s), non réimportée(s).")
        }
        if outcome.skipped > 0 { lines.append("\(outcome.skipped) bloc(s) PGN illisible(s).") }
        return lines.joined(separator: "\n")
    }

    private func handleLibraryImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, !urls.isEmpty else { return }
        var texts: [String] = []
        var unreadable = 0
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
                unreadable += 1
                continue
            }
            texts.append(text)
        }

        // PARSING en fond (bug18aout §7) : lecture des fichiers faite
        // ci-dessus, sous portée sécurité ; le reste ne gèle plus l'écran.
        let container = modelContext.container
        let failedFiles = unreadable
        Task {
            var imported = 0, skipped = 0, duplicates = 0
            for text in texts {
                let outcome = await GameLibraryService.importPGNCollection(
                    text: text, container: container
                )
                imported += outcome.imported
                skipped += outcome.skipped
                duplicates += outcome.duplicates
            }
            var lines = ["\(imported) partie(s) importée(s) dans la bibliothèque."]
            if duplicates > 0 {
                lines.append("\(duplicates) partie(s) déjà présente(s), non réimportée(s).")
            }
            if skipped > 0 { lines.append("\(skipped) bloc(s) PGN illisible(s) ignoré(s).") }
            if failedFiles > 0 { lines.append("\(failedFiles) fichier(s) illisible(s).") }
            libraryImportSummary = lines.joined(separator: "\n")
        }
    }
}
