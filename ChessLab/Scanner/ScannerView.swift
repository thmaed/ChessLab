import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Scanner d'échiquier : choix de la source → image → cadrage →
/// classification → confirmation obligatoire.
///
/// Le routage reste dans ``HomeView`` : cet écran ne remonte que des
/// résultats par callback. Il partage la sortie de l'éditeur
/// (``PositionEditorExit``) parce qu'il finit dans le même écran : la
/// confirmation EST l'éditeur, pré-rempli.
struct ScannerView: View {
    let exit: PositionEditorExit

    @State private var vm = ScannerViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showFileImporter = false

    var body: some View {
        Group {
            switch vm.stage {
            case .chooseSource:
                sourceStage
            case .adjustCrop:
                cropStage
            case .rectified:
                confirmationStage
            }
        }
        .appBackground()
        .navigationTitle(vm.stage == .rectified ? Text("Vérifier la position") : Text("Scanner une position"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .animation(Theme.gentle, value: vm.stage)
        // Le traitement de l'image (détection, redressement, reconnaissance)
        // prend quelques secondes : un voile + indicateur d'activité dit que
        // ça travaille, plutôt qu'un écran figé qu'on croit planté. Le calcul
        // tourne HORS fil principal (voir ``ScannerViewModel``), donc
        // l'indicateur s'anime vraiment.
        .overlay { processingOverlay }
        .onAppear {
            // Porte dérobée des tests UI : les sélecteurs système sont hors
            // process, donc intestables. Sans l'argument de lancement, rien
            // ne se produit ici.
            //
            // La source AVANT l'image : c'est elle qui choisit le classifieur,
            // et `load` détecte déjà le plateau en s'appuyant dessus.
            if let testSource = ScanTestImage.requestedSource { vm.forcedSource = testSource }
            if let testImage = ScanTestImage.image(), vm.image == nil {
                Task { await vm.load(testImage) }
            }
        }
    }

    // MARK: Étape 1 — source

    private var sourceStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Plus de choix « Que scannez-vous ? » : le scanner ne traite
                // QUE les échiquiers à l'écran (capture ou photo d'écran), lus
                // par le modèle YOLO. La distinction capture / photo se déduit
                // de l'image elle-même — il n'y a donc plus rien à demander.
                SettingsSection(title: "Image", systemImage: "photo.fill", tint: Theme.teal) {
                    VStack(spacing: 10) {
                        // Libellé inline (pas ``ScannerEntryLabel``) : le
                        // contenu d'un `PhotosPicker` est un contexte non isolé
                        // au `MainActor`, et y construire une vue à l'init isolé
                        // déclenche un avertissement de concurrence. Les vues de
                        // base (IconBadge, Text) s'y construisent sans souci.
                        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                            HStack(spacing: 14) {
                                IconBadge(systemImage: "photo.on.rectangle", tint: Theme.info, size: 40)
                                Text("Photothèque")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("scanPickPhoto")

                        if CameraPicker.isAvailable {
                            Button { showCamera = true } label: {
                                ScannerEntryLabel(title: "Appareil photo", systemImage: "camera.fill", tint: Theme.accent)
                            }
                            .buttonStyle(.pressable)
                        }

                        // Sur Mac, une capture d'écran atterrit sur le BUREAU,
                        // pas dans la photothèque : le sélecteur de fichiers y
                        // est le geste naturel, alors qu'il ne servait à rien
                        // sur iOS (d'où son retrait le 18/07/2026). Le même
                        // raisonnement donne deux réponses opposées selon la
                        // plateforme, donc il est conditionnel.
                        #if targetEnvironment(macCatalyst)
                        Button { showFileImporter = true } label: {
                            ScannerEntryLabel(title: "Importer un fichier", systemImage: "doc.badge.plus", tint: Theme.teal)
                        }
                        .buttonStyle(.pressable)
                        #endif

                        // Coller une image du presse-papiers (4e source).
                        // Bouton ORDINAIRE et non `PasteButton` : seul un
                        // bouton dont on maîtrise le libellé peut porter le
                        // même `ScannerEntryLabel` que les entrées ci-dessus.
                        // Le compromis (invite de collage d'iOS possible) est
                        // documenté dans ``ScannerViewModel/loadFromPasteboard()``.
                        Button { Task { await vm.loadFromPasteboard() } } label: {
                            ScannerEntryLabel(
                                title: "Coller", systemImage: "doc.on.clipboard.fill",
                                tint: Theme.violet
                            )
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("scanPasteImage")
                    }
                }

                if let errorMessage = vm.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Sur iPad, vous pouvez aussi déposer une image directement sur cet écran.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(20)
        }
        // Glisser-déposer iPad : accepté sur tout l'écran plutôt que sur une
        // cible étroite qu'il faudrait viser.
        .dropDestination(for: Data.self) { items, _ in
            guard let data = items.first else { return false }
            Task { await vm.loadFromDropped(data: data) }
            return true
        }
        .photosPickerAccessoryVisibility(.hidden, edges: .bottom)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await vm.loadFromDropped(data: data)
                }
                photoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in Task { await vm.load(image) } }
                .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            Task { await vm.loadFromFile(result) }
        }
    }

    @ViewBuilder
    private var processingOverlay: some View {
        if vm.isProcessing {
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.accent)
                    Text("Traitement de l'image…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(28)
                .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .transition(.opacity)
            .accessibilityIdentifier("scanProcessing")
            .accessibilityLabel(Text("Traitement de l'image en cours"))
        }
    }

    // MARK: Étape 2 — cadrage

    @ViewBuilder
    private var cropStage: some View {
        if let image = vm.image {
            VStack(spacing: 0) {
                BoardCropView(
                    image: image,
                    quad: Binding(get: { vm.quad }, set: { vm.quad = $0 }),
                    wasDetectedAutomatically: vm.wasDetectedAutomatically
                ) {
                    Task { await vm.confirmCrop() }
                }

                if let errorMessage = vm.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
            }
            .toolbar {
                // Libellé court : « Changer d'image » tronquait le titre de
                // l'écran sur iPhone (vu à la capture).
                ToolbarItem(placement: .cancellationAction) {
                    Button("Changer") { vm.backToSource() }
                        .accessibilityLabel("Changer d'image")
                }
            }
        }
    }

    // MARK: Étape 3 — confirmation (obligatoire)

    /// Le prompt interdit toute action directe image → moteur : rien ne sort
    /// du scanner sans être passé par cet écran.
    @ViewBuilder
    private var confirmationStage: some View {
        if let reading = vm.reading {
            ScanConfirmationView(
                reading: reading,
                rotation: Binding(get: { vm.rotation }, set: { vm.rotation = $0 }),
                exit: exit,
                onBackToCrop: { vm.backToCrop() }
            )
        }
    }
}

/// Libellé d'une entrée d'image.
///
/// Type à part plutôt que méthode de ``ScannerView`` : le label d'un
/// `PhotosPicker` est évalué dans un contexte NON isolé, où une vue rendue
/// par une méthode isolée au `MainActor` ne peut pas être retournée.
struct ScannerEntryLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(systemImage: systemImage, tint: tint, size: 40)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(title))
    }
}
