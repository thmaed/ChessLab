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
        // Ignorer SIGPIPE au tout début, avant qu'un moteur ne démarre.
        //
        // ChessKitEngine parle à Stockfish par un `write()` BRUT sur un tuyau
        // (`EngineMessenger.sendCommand:`), sans `F_SETNOSIGPIPE`. Quand le
        // process Stockfish a quitté (tout arrêt de moteur envoie `quit`, qui
        // ferme le tuyau) et qu'un envoi tardif ou concurrent le frappe encore
        // — la lib ferme le tuyau sous un verrou DIFFÉRENT de celui des envois,
        // ils ne s'excluent pas — `write()` lève SIGPIPE, dont l'action par
        // défaut TUE le process : « Terminated due to signal 13 » en quittant
        // l'Analyse. En l'ignorant, `write()` échoue proprement (`EPIPE`) au
        // lieu de tuer l'app — la commande perdue est sans conséquence, le
        // moteur étant de toute façon en train de s'arrêter. Correctif standard
        // pour tout code faisant de l'I/O sur pipe qu'on ne peut pas modifier.
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
        let schema = Schema([GameRecord.self, Puzzle.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: CloudSyncSettingsStore.isEnabled ? .automatic : .none
        )

        // 1) Tentative normale.
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }
        // 2) Store local illisible (migration interrompue, corruption, disque
        //    plein) : plutôt qu'une boucle de crash définitive au lancement,
        //    on détruit et on recrée le store local. Les données critiques
        //    (parties en cours) vivent dans les autosaves JSON ; la
        //    bibliothèque de puzzles se re-seed ; seuls GameRecord /
        //    répertoires / progression SRS seraient perdus.
        destroyLocalStore()
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }
        // 3) Dernier recours : conteneur en mémoire — session dégradée
        //    (rien n'est persisté) mais pas de crash.
        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [memoryConfiguration])
        } catch {
            fatalError("Impossible de créer même un conteneur en mémoire : \(error)")
        }
    }

    /// Supprime les fichiers du store SwiftData local (le nom par défaut est
    /// `default.store`, plus ses journaux WAL/SHM).
    private static func destroyLocalStore() {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return }
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            try? fileManager.removeItem(at: appSupport.appendingPathComponent(name))
        }
    }
}
