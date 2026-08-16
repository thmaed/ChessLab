import SwiftData
import SwiftUI

@main
struct ChessLabApp: App {
    private let modelContainer: ModelContainer = Self.makeModelContainer()
    @State private var settings = AppSettings.shared
    #if targetEnvironment(macCatalyst)
    /// Uniquement pour élaguer la barre de menus — voir ``MacMenuDelegate``.
    @UIApplicationDelegateAdaptor(MacMenuDelegate.self) private var menuDelegate
    #endif

    init() {
        // Ignorer SIGPIPE, par précaution. Le moteur vendorisé
        // (``CStockfishKit``) ne communique plus par un tuyau POSIX — il pousse
        // les commandes dans une file en mémoire et redirige les `streambuf`
        // C++, donc il ne peut plus lever SIGPIPE (contrairement à
        // ChessKitEngine, dont le `write()` brut sur pipe tuait l'app par
        // « signal 13 » à l'arrêt d'un moteur). On garde la garde : elle est
        // sans coût et protège tout futur code faisant de l'I/O sur pipe.
        signal(SIGPIPE, SIG_IGN)

        // Toucher le singleton AVANT tout rendu : son init applique la langue
        // choisie (``LocalizationController``), pour que le tout premier écran
        // s'affiche déjà dans la bonne langue.
        _ = AppSettings.shared

        // Utilisé par les tests UI pour repartir de réglages vierges,
        // indépendamment des parties précédentes sur le simulateur.
        if CommandLine.arguments.contains("-resetPlaySettings") {
            PlaySettingsStore.clear()
            AutosaveStore.clearPlay()
            AutosaveStore.clearTwoPlayer()
            // Repartir sur la langue du SYSTÈME : sans ça, un choix de langue
            // laissé par un test précédent (le simulateur ne se réinitialise
            // pas entre les runs) rendrait les libellés imprévisibles.
            UserDefaults.standard.removeObject(forKey: "settings.appLanguage")
        }

        // Pré-chauffe le moteur audio (session + synthèse des buffers) et
        // les générateurs haptiques hors du premier coup : sans ça, jouer le
        // tout premier coup subit un à-coup (init de SoundPlayer sur le
        // MainActor) et une latence haptique.
        Task { @MainActor in
            _ = SoundPlayer.shared
            Haptics.prepare()
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()

                .task {

                    // Répertoires personnels : la base remplace les fichiers, et

                    // reprend au passage ceux des versions précédentes.

                    UserOpeningStore.shared.attach(context: modelContainer.mainContext)

                }
                // Traits réels de la fenêtre (classes de taille, taille,
                // encoches) exposés aux tests de mise en page — et affichés
                // à l'écran avec `-showTraits`. Voir ``LayoutTraitsProbe``.
                //
                // Posée AVANT la bascule d'ossature, donc à l'intérieur : la
                // sonde rapporte ainsi la classe effectivement vue par
                // `HomeView`, surcharge de test comprise.
                .layoutTraitsProbe()
                // Bascule d'ossature à la demande (`-skeletonToggle`), pour
                // tester la survie de la partie — voir ``SkeletonOverride``.
                .skeletonOverride()
                .preferredColorScheme(.dark)
                // `Text` dépend de la locale de l'environnement : la changer
                // force SwiftUI à re-rendre chaque `Text`, qui re-résout alors
                // sa clé via le bundle détourné (langue in-app). On NE force
                // PAS un `.id()` sur toute la racine : cela reconstruirait la
                // `NavigationStack` et renverrait l'utilisateur à l'accueil au
                // moindre changement de langue.
                .environment(\.locale, settings.locale)
        }
        .modelContainer(modelContainer)
        // Barre de menus macOS. Sur iOS/iPadOS, `commands` alimente le menu
        // matériel du clavier (⌘ maintenu) — utile là aussi, donc pas de
        // garde de plateforme.
        .commands { ChessLabCommands() }
    }

    /// Conteneur SwiftData local par défaut. Les modèles (``GameRecord``,
    /// ``Puzzle``) sont écrits dès maintenant pour être compatibles
    /// CloudKit, mais la synchronisation réelle reste désactivée tant que
    /// ``CloudSyncSettingsStore/isEnabled`` n'est pas activé — ce qui
    /// nécessite au préalable un ajout MANUEL, une seule fois, de la
    /// capacité iCloud dans Xcode (Signing & Capabilities), une étape
    /// interactive/réseau qu'on ne peut pas fiabiliser via `xcodebuild` seul
    /// dans cet environnement. Voir PROGRESS.md.
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            GameRecord.self, Puzzle.self, PuzzleProgress.self,
            OpeningPositionProgress.self, OpeningReviewLog.self, RepertoireMembership.self, UserOpeningRecord.self,])

        // Deux stores SÉPARÉS, et non un seul :
        // - « Games » (parties de l'utilisateur + PROGRESSION puzzles) :
        //   synchronisable via iCloud. `PuzzleProgress` est petit (quelques
        //   centaines d'entrées personnelles) et voyage donc sans souci.
        // - « Puzzles » (bibliothèque Lichess EMBARQUÉE) : local-only, JAMAIS
        //   synchronisé. Dans un store commun, activer CloudKit poussait les
        //   ~100 000 puzzles embarqués — identiques sur chaque appareil — vers
        //   l'iCloud de l'utilisateur (CKError 429, throttling, quota gaspillé).
        //   Les modèles sont indépendants (aucune relation croisée), la
        //   séparation est valide. La bibliothèque se re-seed depuis le bundle
        //   si le store est neuf ; ``PuzzleProgressSync`` réinjecte la
        //   progression synchronisée dans les `Puzzle` locaux.
        // Progression des ouvertures (``OpeningPositionProgress`` /
        // ``OpeningReviewLog`` / ``RepertoireMembership``) : même store « Games »
        // synchronisé que les parties et la progression puzzle — on ÉTEND la
        // pile existante plutôt que d'en créer une seconde. Indexée par FEN
        // normalisée, granulaire (une entrée par position) pour éviter les
        // conflits d'écriture massifs. Ajout ADDITIF (nouveaux types, aucune
        // propriété requise) : migration SwiftData légère et sans risque.
        let gamesConfig = ModelConfiguration(
            "Games",
            schema: Schema([
                GameRecord.self, PuzzleProgress.self,
                OpeningPositionProgress.self, OpeningReviewLog.self, RepertoireMembership.self,
                // Répertoires personnels : ajout ADDITIF au store synchronisé.
                // Ils vivaient en fichiers locaux et ne suivaient donc aucun
                // appareil — ce que l'aide devait avouer à l'utilisateur.
                UserOpeningRecord.self,
            ]),
            isStoredInMemoryOnly: false,
            cloudKitDatabase: CloudSyncSettingsStore.isEnabled ? .automatic : .none
        )
        let puzzlesConfig = ModelConfiguration(
            "Puzzles",
            schema: Schema([Puzzle.self]),
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        let configurations = [gamesConfig, puzzlesConfig]

        // 1) Tentative normale.
        if let container = try? ModelContainer(for: schema, configurations: configurations) {
            return container
        }
        // 2) Store local illisible (migration interrompue, corruption, disque
        //    plein) : plutôt qu'une boucle de crash définitive au lancement,
        //    on détruit et on recrée les stores locaux. Les données critiques
        //    (parties en cours) vivent dans les autosaves JSON ; la
        //    bibliothèque de puzzles se re-seed ; seuls GameRecord /
        //    répertoires / progression SRS seraient perdus.
        destroyLocalStore()
        if let container = try? ModelContainer(for: schema, configurations: configurations) {
            return container
        }
        // 3) Dernier recours : conteneur en mémoire — session dégradée
        //    (rien n'est persisté) mais pas de crash.
        // `cloudKitDatabase: .none` : session dégradée PUREMENT locale — avec
        // l'entitlement iCloud, un défaut `.automatic` tenterait CloudKit sur
        // un store en mémoire et crasherait ce dernier recours.
        let memoryConfiguration = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [memoryConfiguration])
        } catch {
            fatalError("Impossible de créer même un conteneur en mémoire : \(error)")
        }
    }

    /// Supprime les fichiers des stores SwiftData locaux (les deux stores
    /// nommés « Games »/« Puzzles », plus leurs journaux WAL/SHM). L'ancien
    /// store combiné « default » est aussi purgé : orphelin depuis la
    /// séparation, il ne sert plus à rien.
    private static func destroyLocalStore() {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return }
        for base in ["Games.store", "Puzzles.store", "default.store"] {
            for suffix in ["", "-shm", "-wal"] {
                try? fileManager.removeItem(at: appSupport.appendingPathComponent(base + suffix))
            }
        }
    }
}
