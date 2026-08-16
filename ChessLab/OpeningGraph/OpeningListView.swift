import SwiftData
import SwiftUI

/// Écran « Ouvertures » simplifié : une liste claire des ouvertures, groupées
/// par camp. Taper une ouverture ouvre le LECTEUR (avancer coup par coup avec
/// les explications). Un bouton « Réviser » discret en tête si des positions
/// sont dues. Remplace l'ancienne bibliothèque linéaire des 149 familles.
struct OpeningListView: View {
    /// Ouvre le lecteur d'une ouverture.
    let onSelect: (String) -> Void
    /// Lance la révision espacée du jour.
    var onReview: () -> Void = {}
    /// Ouvre l'ÉDITEUR d'arbre — répertoires personnels seulement.
    var onEdit: (String) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @State private var dueCount = 0
    /// Observé : la liste se rafraîchit d'elle-même après un import.
    @State private var store = UserOpeningStore.shared

    /// Les répertoires personnels tels que la BASE les voit.
    ///
    /// 🐛 Sans cette requête, l'écran ne voyait jamais arriver les répertoires
    /// créés sur un autre appareil : `store.catalog` est un tableau mis en
    /// cache, recalculé par `reload()` seulement, et CloudKit ne prévient
    /// personne. On synchronisait donc pour rien.
    ///
    /// `@Query` fait le lien : SwiftData réévalue la vue quand des
    /// enregistrements arrivent, et on relit le catalogue à ce moment-là.
    @Query private var userRecords: [UserOpeningRecord]
    @State private var showImport = false
    @State private var pendingDeletion: OpeningCatalogEntry?

    private var entries: [OpeningCatalogEntry] { OpeningCatalog.all }

    /// Empreinte de ce que contient la base : identifiants et dates de
    /// modification.
    private var recordsSignature: String {
        userRecords
            .map { "\($0.id)@\(Int($0.updatedAt.timeIntervalSince1970))" }
            .sorted()
            .joined(separator: "|")
    }
    /// Les répertoires de l'utilisateur ont leur SECTION, en tête.
    ///
    /// Rangés alphabétiquement au milieu des cinquante-huit ouvertures
    /// livrées, ils étaient introuvables : après un import, on retombait sur
    /// une liste identique à la précédente et rien ne disait que ça avait
    /// marché. Ce qu'on a apporté soi-même se trouve d'abord.
    private var mine: [OpeningCatalogEntry] {
        sortedByName(entries.filter { UserOpeningStore.isUserCourse(id: $0.id) })
    }
    private var bundled: [OpeningCatalogEntry] {
        entries.filter { !UserOpeningStore.isUserCourse(id: $0.id) }
    }
    private var white: [OpeningCatalogEntry] { sortedByName(bundled.filter { $0.side == .white }) }
    private var black: [OpeningCatalogEntry] { sortedByName(bundled.filter { $0.side == .black }) }
    private var languageCode: String { AppSettings.shared.appLanguage.resolvedCode }

    /// Nom affiché (traduit dans la langue de l'app via le bundle redirigé).
    private func displayName(_ entry: OpeningCatalogEntry) -> String {
        Bundle.main.localizedString(forKey: entry.name, value: entry.name, table: nil)
    }

    /// Tri alphabétique par nom affiché (accents pris en compte).
    private func sortedByName(_ items: [OpeningCatalogEntry]) -> [OpeningCatalogEntry] {
        items.sorted { displayName($0).localizedStandardCompare(displayName($1)) == .orderedAscending }
    }

    var body: some View {
        List {
            if dueCount > 0 { reviewSection }
            if !mine.isEmpty { section("Mes répertoires", mine) }
            if !white.isEmpty { section("Répertoire blanc", white) }
            if !black.isEmpty { section("Répertoire noir", black) }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Ouvertures")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showImport = true } label: {
                    Label("Ajouter un répertoire", systemImage: "plus")
                }
                .tint(Theme.accent)
                .accessibilityIdentifier("opening_add")
            }
        }
        .sheet(isPresented: $showImport) {
            OpeningImportSheet { _ in }
        }
        .confirmationDialog(
            "Supprimer ce répertoire ?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let pendingDeletion { store.delete(id: pendingDeletion.id) }
                pendingDeletion = nil
            }
            Button("Annuler", role: .cancel) { pendingDeletion = nil }
        } message: {
            // Dire ce qui SURVIT évite l'hésitation : ce qu'on a mémorisé est
            // attaché aux positions, pas au fichier.
            Text("Le fichier est supprimé de cet appareil. Votre progression sur ces positions est conservée.")
        }
        .onAppear {
            UserOpeningSeeder.seedIfRequested()
            refresh()
        }
        // La signature couvre l'ARRIVÉE d'un répertoire comme sa modification
        // (renommage, variante ajoutée sur l'autre appareil) : un simple
        // compte manquerait les secondes.
        .onChange(of: recordsSignature) { _, _ in store.reload() }
    }

    private func refresh() {
        OpeningProgressSync.reconcile(in: modelContext)
        let now = Date()
        let snapshots = OpeningTrainViewModel.snapshots(in: modelContext)
        dueCount = snapshots.values.filter { $0.reps > 0 && ($0.dueDate ?? .distantFuture) <= now }.count
    }

    private var reviewSection: some View {
        Section {
            Button(action: onReview) {
                HStack(spacing: 12) {
                    Image(systemName: "checklist").foregroundStyle(Theme.accent).frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Réviser aujourd'hui").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Text("\(dueCount) position(s) à revoir").font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Text("\(dueCount)").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.16), in: Capsule())
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(Theme.surface)
        }
    }

    private func section(_ title: LocalizedStringKey, _ items: [OpeningCatalogEntry]) -> some View {
        Section {
            ForEach(items, id: \.id) { entry in
                // Le bouton d'ouverture et le menu d'actions sont FRÈRES, pas
                // imbriqués : un `Menu` posé dans le label d'un `Button` ne
                // reçoit jamais ses propres taps, le bouton extérieur les
                // avale.
                HStack(spacing: 4) {
                    Button { onSelect(entry.id) } label: { row(entry) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("opening_\(entry.id)")
                    if UserOpeningStore.isUserCourse(id: entry.id) {
                        actionsMenu(entry)
                    }
                }
                .listRowBackground(Theme.surface)
                // Le balayage reste, en RACCOURCI pour qui le connaît. Il ne
                // peut plus être le seul chemin : sur une ligne qui est
                // elle-même un bouton, le geste entre en concurrence avec le
                // tap et se déclenche mal — d'autant qu'il faut aller chercher
                // trois actions.
                .swipeActions(edge: .trailing) { swipeActions(entry) }
            }
        } header: {
            Text(title).foregroundStyle(Theme.textSecondary)
        }
    }

    /// Actions d'un répertoire personnel, TOUJOURS VISIBLES.
    ///
    /// Une fonctionnalité qui demande de deviner qu'il faut balayer une ligne
    /// n'existe pas vraiment : c'est ce qui rendait l'éditeur d'arbre
    /// introuvable.
    @ViewBuilder
    private func actionsMenu(_ entry: OpeningCatalogEntry) -> some View {
        Menu {
            Button {
                onEdit(entry.id)
            } label: {
                Label("Modifier le répertoire", systemImage: "pencil")
            }
            if let url = store.exportFileURL(for: entry.id) {
                ShareLink(item: url) { Label("Partager", systemImage: "square.and.arrow.up") }
            }
            Divider()
            Button(role: .destructive) {
                pendingDeletion = entry
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Actions du répertoire")
        .accessibilityIdentifier("openingActions_\(entry.id)")
    }

    /// Partager et supprimer — sur les répertoires PERSONNELS seulement : les
    /// cours livrés avec l'app ne s'effacent pas, et les partager reviendrait à
    /// redistribuer le contenu de l'app.
    @ViewBuilder
    private func swipeActions(_ entry: OpeningCatalogEntry) -> some View {
        if UserOpeningStore.isUserCourse(id: entry.id) {
            Button(role: .destructive) {
                pendingDeletion = entry
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
            if let url = store.exportFileURL(for: entry.id) {
                ShareLink(item: url) { Label("Partager", systemImage: "square.and.arrow.up") }
                    .tint(Theme.accent)
            }
            // Réservé aux répertoires PERSONNELS : les cours embarqués sont
            // livrés avec l'app et se remplaceraient à la mise à jour suivante.
            Button {
                onEdit(entry.id)
            } label: {
                Label("Modifier", systemImage: "pencil")
            }
            .tint(Theme.info)
        }
    }

    private func row(_ entry: OpeningCatalogEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(entry.name))
                        .font(.body.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    if UserOpeningStore.isUserCourse(id: entry.id) {
                        Text("Perso")
                            .font(.caption2.weight(.bold)).foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.16), in: Capsule())
                    }
                }
                if let summary = entry.summary?.resolved(languageCode) {
                    Text(summary).font(.caption).foregroundStyle(Theme.textTertiary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
