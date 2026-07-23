import SwiftUI

/// Destinations atteignables depuis la barre de menus macOS.
///
/// La barre de menus vit dans la `Scene`, la navigation dans ``HomeView`` :
/// les deux ne peuvent pas se parler directement. Ce relais porte la seule
/// chose à transmettre — « on veut aller là » — que ``HomeView`` consomme puis
/// remet à `nil`. Volontairement pauvre : pas de pile de navigation partagée,
/// pas d'état dupliqué, juste une intention.
enum MenuDestination: Hashable {
    case newGame
    case twoPlayer
    case analysis
    case puzzles
    case openings
    case laboratory
    case settings
    case help
}

@MainActor
@Observable
final class MenuCommands {
    static let shared = MenuCommands()

    /// Destination demandée, consommée par ``HomeView``.
    var requested: MenuDestination?

    private init() {}

    func request(_ destination: MenuDestination) {
        requested = destination
    }
}

/// Menus macOS de l'app.
///
/// N'expose QUE ce qui est vrai partout : ouvrir un mode depuis l'accueil,
/// les réglages, l'aide. Les commandes qui dépendent de l'écran affiché —
/// coup précédent/suivant, annuler — restent des raccourcis attachés à leurs
/// boutons : les remonter ici demanderait un état global de navigation, et un
/// menu grisé la moitié du temps vaut moins qu'un raccourci qui marche.
struct ChessLabCommands: Commands {
    var body: some Commands {
        // Remplace « Nouveau document », qui n'a aucun sens ici.
        CommandGroup(replacing: .newItem) {
            Button("Nouvelle partie") { MenuCommands.shared.request(.newGame) }
                .keyboardShortcut("n", modifiers: .command)
            Button("Partie à deux joueurs") { MenuCommands.shared.request(.twoPlayer) }
                .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Analyser…") { MenuCommands.shared.request(.analysis) }
                .keyboardShortcut("o", modifiers: .command)
            Button("Puzzles") { MenuCommands.shared.request(.puzzles) }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Ouvertures") { MenuCommands.shared.request(.openings) }
            Button("Laboratoire") { MenuCommands.shared.request(.laboratory) }
        }

        // ⌘, — la convention Mac, absente jusqu'ici.
        CommandGroup(replacing: .appSettings) {
            Button("Réglages…") { MenuCommands.shared.request(.settings) }
                .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button("Aide ChessLab") { MenuCommands.shared.request(.help) }
        }
    }
}

#if targetEnvironment(macCatalyst)
/// Élague la barre de menus que Catalyst construit d'office.
///
/// Catalyst suppose une app à DOCUMENTS et ajoute « Dupliquer », « Déplacer »,
/// « Renommer… », « Exporter sous… », plus un menu Format et une barre
/// d'outils. ChessLab n'a pas de document : ces entrées ne mènent nulle part
/// et donnent l'impression d'une app portée à la va-vite.
///
/// `CommandGroup(replacing: .saveItem)` ne suffit pas — ces éléments viennent
/// du menu système, pas des `Commands` SwiftUI, et ne se retirent qu'ici.
final class MacMenuDelegate: UIResponder, UIApplicationDelegate {

    static let minimumWindowSize = CGSize(width: 820, height: 680)

    /// Plancher de fenêtre. Posé à l'ACTIVATION de la scène et pas depuis une
    /// vue : au premier `onAppear` de la racine, la `UIWindowScene` n'est pas
    /// encore attachée et `sizeRestrictions` est ignoré — la fenêtre se
    /// laissait alors réduire à 632×524, où les mises en page compactes
    /// (pensées pour un iPhone en main) se replient mal.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification, object: nil, queue: .main
        ) { notification in
            guard let scene = notification.object as? UIWindowScene else { return }
            MainActor.assumeIsolated {
                scene.sizeRestrictions?.minimumSize = Self.minimumWindowSize
            }
            // Le système reconfigure la scène juste APRÈS son activation et
            // écrase ce qu'on vient de poser : on repasse une fois.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                scene.sizeRestrictions?.minimumSize = Self.minimumWindowSize
            }
        }
        return true
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        for menu in [UIMenu.Identifier.document, .format, .toolbar] {
            builder.remove(menu: menu)
        }
    }
}
#endif
