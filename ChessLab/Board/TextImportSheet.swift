import SwiftUI

/// Feuille de saisie/collage générique (PGN ou FEN), avec message
/// d'erreur inline — réutilisée par tout import textuel (Analyser,
/// Ouvertures…). Extraite d'`AnalysisEntryView` à sa deuxième
/// utilisation.
struct TextImportSheet<Accessory: View>: View {
    // `LocalizedStringKey` pour tout ce qui est ÉCRIT ICI une fois pour
    // toutes : `Text`, `navigationTitle` et `Button` ne traduisent pas un
    // `String`, et un littéral typé `String` n'est même pas vu par
    // l'extraction du catalogue. `errorMessage` reste un `String` parce
    // qu'il se compose à l'exécution — c'est à sa source de le traduire.
    let title: LocalizedStringKey
    @Binding var text: String
    let errorMessage: String?
    let placeholder: LocalizedStringKey
    let confirmLabel: LocalizedStringKey
    let onConfirm: () -> Void
    /// Contenu OPTIONNEL glissé sous la zone de texte — une option propre à
    /// l'appelant (ajouter à la bibliothèque, choisir un camp…). Vide par
    /// défaut, pour que les usages existants ne changent pas.
    @ViewBuilder let accessory: Accessory

    @Environment(\.dismiss) private var dismiss

    init(
        title: LocalizedStringKey, text: Binding<String>, errorMessage: String?,
        placeholder: LocalizedStringKey,
        confirmLabel: LocalizedStringKey = "Importer", onConfirm: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        _text = text
        self.errorMessage = errorMessage
        self.placeholder = placeholder
        self.confirmLabel = confirmLabel
        self.onConfirm = onConfirm
        self.accessory = accessory()
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                // `PasteButton` (plutôt qu'une lecture directe de
                // `UIPasteboard.general` au tap de la carte d'entrée) :
                // seule cette API système évite l'invite de confirmation
                // "Coller depuis [Autre app] ?" qui, sans interaction
                // humaine pour y répondre, bloque le fil principal
                // indéfiniment — piège découvert via un test UI qui
                // gelait sans jamais planter (voir PROGRESS.md).
                PasteButton(payloadType: String.self) { strings in
                    text = strings.first ?? ""
                }
                .buttonBorderShape(.capsule)
                .labelStyle(.titleAndIcon)

                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Theme.surfaceElevated, in: Theme.controlShape)
                    .overlay(Theme.controlShape.strokeBorder(Theme.stroke, lineWidth: 1))
                    .frame(minHeight: 160)

                if text.isEmpty {
                    Text(placeholder)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }

                accessory

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmLabel, action: onConfirm)
                        .fontWeight(.semibold)
                        .tint(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
