import SwiftUI

/// Feuille d'édition des étiquettes d'une partie : ajout au clavier, retrait
/// d'un tap, et rappel en un geste des étiquettes déjà utilisées ailleurs
/// dans la bibliothèque (pour rester cohérent plutôt que ressaisir).
///
/// Découplée de SwiftData : elle travaille sur une copie locale et remonte le
/// résultat par ``onSave`` — l'appelant écrit dans le ``GameRecord`` et
/// sauvegarde. Un même libellé n'est jamais dupliqué (comparaison insensible
/// à la casse).
struct GameTagsEditorSheet: View {
    let suggestions: [String]
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tags: [String]
    @State private var draft = ""

    init(initialTags: [String], suggestions: [String], onSave: @escaping ([String]) -> Void) {
        self.suggestions = suggestions
        self.onSave = onSave
        _tags = State(initialValue: initialTags)
    }

    /// Suggestions encore non posées sur cette partie.
    private var availableSuggestions: [String] {
        let used = Set(tags.map { $0.lowercased() })
        return suggestions.filter { !used.contains($0.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    addField

                    if tags.isEmpty {
                        Text("Aucune étiquette. Ajoutez-en pour retrouver et regrouper vos parties (ex. « ouverture », « à revoir »).")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        section(title: "Sur cette partie") {
                            flow(tags) { tag in
                                chip(tag, systemImage: "xmark.circle.fill", tint: Theme.accent) {
                                    tags.removeAll { $0 == tag }
                                }
                            }
                        }
                    }

                    if !availableSuggestions.isEmpty {
                        section(title: "Déjà utilisées") {
                            flow(availableSuggestions) { tag in
                                chip(tag, systemImage: "plus.circle.fill", tint: Theme.info) {
                                    add(tag)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Étiquettes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(tags)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var addField: some View {
        HStack(spacing: 10) {
            Image(systemName: "tag.fill").foregroundStyle(Theme.textTertiary)
            TextField("Nouvelle étiquette", text: $draft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { add(draft) }
                .accessibilityIdentifier("tagInput")
            if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    add(draft)
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(14)
        .background(Theme.surfaceElevated.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func add(_ raw: String) {
        let tag = raw.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return }
        if !tags.contains(where: { $0.lowercased() == tag.lowercased() }) {
            tags.append(tag)
        }
        draft = ""
    }

    @ViewBuilder
    private func section<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    /// Disposition en lignes qui reviennent à la ligne (les étiquettes sont de
    /// largeur variable) via un `WrapLayout` maison — pas de dépendance.
    private func flow<Content: View>(_ items: [String], @ViewBuilder chip: @escaping (String) -> Content) -> some View {
        WrapLayout(spacing: 8, lineSpacing: 8) {
            ForEach(items, id: \.self) { chip($0) }
        }
    }

    private func chip(_ tag: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(tag)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Image(systemName: systemImage)
                    .font(.caption2)
                    .foregroundStyle(tint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.surfaceElevated))
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// `WrapLayout` vivait ici, dupliqué à l'identique de ``FlowLayout`` et
// porteur des deux mêmes défauts de largeur (Lot 3.4). C'est désormais un
// alias de `FlowLayout` (voir `Theme.swift`) : une seule implémentation.
