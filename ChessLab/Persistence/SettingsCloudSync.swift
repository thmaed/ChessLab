import Foundation

/// Ce que la synchronisation attend d'un magasin clé-valeur iCloud, réduit à
/// quatre gestes. L'intérêt n'est pas l'abstraction pour elle-même : c'est que
/// la FUSION soit testable sans iCloud, sans appareil et sans réseau — la
/// validation de bout en bout, elle, demande deux vrais appareils (checklist
/// manuelle dans `docs/`).
protocol KeyValueStoring: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    var storedKeys: [String] { get }
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: KeyValueStoring {
    var storedKeys: [String] { Array(dictionaryRepresentation.keys) }
}

/// Synchronisation des RÉGLAGES entre les appareils, via
/// `NSUbiquitousKeyValueStore` — une couche fine posée au-dessus des stores
/// `UserDefaults` existants, qui restent la source de vérité lue par l'app.
///
/// ## Ce qui est synchronisé, et pourquoi pas le reste
///
/// La liste est une **liste blanche** (``syncedKeys``), jamais une liste noire :
/// une clé nouvellement introduite ailleurs dans l'app ne part pas dans le nuage
/// par accident. Deux préférences en sont exclues par décision produit du
/// 20/08/2026 — la **langue** et les **sons** restent propres à chaque appareil
/// (on ne veut pas qu'un iPad muet impose le silence à l'iPhone, ni qu'une
/// langue choisie sur l'un rebascule l'interface de l'autre en pleine session ;
/// le `didSet` de la langue reconstruit tout le bundle de localisation).
///
/// En sont exclus aussi, par construction, les **états de machine** qui n'ont
/// aucun sens ailleurs que sur l'appareil qui les tient : marqueurs de migration
/// et d'amorçage, compteur d'échecs d'ouverture du conteneur, horodatage de
/// dernière réconciliation. Le drapeau `cloudKitSyncEnabled` lui-même reste
/// local : synchroniser l'interrupteur de la synchro, c'est se couper le canal
/// qui propage l'information au moment où on l'éteint quelque part.
///
/// ## La règle de fusion
///
/// Celle du magasin : **dernière écriture gagne**, clé par clé. C'est assumé —
/// il s'agit de scalaires de préférence, pas de données. Les trois réglages de
/// mode (Jouer, Laboratoire, Deux joueurs) voyagent en revanche comme des blocs
/// JSON entiers : le dernier appareil qui touche à l'un d'eux impose SON bloc
/// complet, pas seulement le champ modifié. Un plafond existe (1 Mo, 1024 clés) ;
/// on en est à neuf clés de scalaires et trois petits blocs.
///
/// ## Au démarrage
///
/// Le nuage l'emporte sur les clés qu'il possède déjà, l'appareil pousse celles
/// qui lui manquent. C'est ce qui rend le premier appareil « fondateur » sans
/// écraser les réglages d'un appareil qui rejoint plus tard un compte déjà
/// garni — et c'est le seul moment où l'ordre compte.
@MainActor
final class SettingsCloudSync {
    static let shared = SettingsCloudSync()

    /// Les seules clés qui voyagent. Toute addition ici est une décision
    /// produit : relire l'en-tête avant d'en ajouter une.
    static let syncedKeys: [String] = [
        // Préférences transversales (`AppSettings`).
        "settings.puzzleAttempts",
        "settings.analysisArrowMode",
        "settings.boardThemeID",
        "settings.pieceSetID",
        "settings.hapticsEnabled",
        "settings.pieceNotation",
        // Réglages de mode, sérialisés en un bloc JSON chacun.
        "lastPlayGameSettings",
        "labGameSettings.v1",
        "lastTwoPlayerGameSettings",
        // Niveau mémorisé par personnage (mode Contre l'ordinateur).
        "opponentLevels.v1",
    ]

    /// Exclusions explicitement DÉCIDÉES (par opposition à celles qui découlent
    /// de la liste blanche). Déclarées pour que les tests puissent vérifier
    /// qu'elles ne dérivent jamais dans ``syncedKeys``, et pour que la
    /// prochaine lecture du code trouve la raison à côté de la règle.
    static let deliberatelyLocalKeys: [String] = [
        "settings.appLanguage",     // rebasculerait l'interface en pleine session
        "settings.soundsEnabled",   // un appareil muet ne doit pas faire taire l'autre
    ]

    private let store: KeyValueStoring
    private let defaults: UserDefaults
    /// Garde-fou anti-boucle : écrire dans `UserDefaults` déclenche la
    /// notification de changement local, qui repousserait vers le nuage ce
    /// qu'on vient d'en tirer.
    private var isApplyingRemoteChange = false
    private var observers: [NSObjectProtocol] = []

    init(store: KeyValueStoring = NSUbiquitousKeyValueStore.default,
         defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    /// Débranche les deux observateurs. Le singleton vit aussi longtemps que
    /// l'app — c'est pour les tests, qui montent des instances jetables.
    func stop() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
    }

    // MARK: Cycle de vie

    /// Branche la synchro : réconciliation initiale, puis écoute des deux sens.
    /// Sans effet si l'utilisateur a coupé la synchro iCloud — le même
    /// interrupteur commande les données et les réglages.
    func start(onRemoteChange: @escaping @MainActor () -> Void) {
        guard CloudSyncSettingsStore.isEnabled, observers.isEmpty else { return }

        store.synchronize()
        reconcileAtLaunch()
        onRemoteChange()

        observers.append(NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store, queue: .main
        ) { [weak self] notification in
            let changed = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.applyRemote(keys: changed ?? Self.syncedKeys) { onRemoteChange() }
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.pushLocalChanges()
            }
        })
    }

    // MARK: Fusion (le cœur testable)

    /// Réconciliation de démarrage : le nuage gagne là où il a déjà une valeur,
    /// l'appareil comble les manques.
    @discardableResult
    func reconcileAtLaunch() -> (pulled: [String], pushed: [String]) {
        let remoteKeys = Set(store.storedKeys)
        var pulled: [String] = [], pushed: [String] = []
        for key in Self.syncedKeys {
            if remoteKeys.contains(key) {
                if copyToDefaults(key: key) { pulled.append(key) }
            } else if let local = defaults.object(forKey: key) {
                store.set(local, forKey: key)
                pushed.append(key)
            }
        }
        if !pushed.isEmpty { store.synchronize() }
        return (pulled, pushed)
    }

    /// Applique les clés qu'un autre appareil vient de modifier. Rend `true`
    /// si quelque chose a bougé localement — donc s'il faut rafraîchir l'UI.
    @discardableResult
    func applyRemote(keys: [String]) -> Bool {
        var touched = false
        for key in keys where Self.syncedKeys.contains(key) {
            if copyToDefaults(key: key) { touched = true }
        }
        return touched
    }

    /// Pousse vers le nuage les préférences locales qui en diffèrent.
    @discardableResult
    func pushLocalChanges() -> [String] {
        guard !isApplyingRemoteChange else { return [] }
        var pushed: [String] = []
        for key in Self.syncedKeys {
            let local = defaults.object(forKey: key)
            guard !valuesMatch(local, store.object(forKey: key)) else { continue }
            store.set(local, forKey: key)
            pushed.append(key)
        }
        if !pushed.isEmpty { store.synchronize() }
        return pushed
    }

    // MARK: Détail

    /// Recopie une valeur du nuage vers `UserDefaults`. Rend `true` seulement
    /// si la valeur locale a réellement changé : sans cette comparaison, chaque
    /// notification externe redéclencherait un rafraîchissement d'interface.
    private func copyToDefaults(key: String) -> Bool {
        let remote = store.object(forKey: key)
        guard !valuesMatch(remote, defaults.object(forKey: key)) else { return false }
        isApplyingRemoteChange = true
        defer { isApplyingRemoteChange = false }
        defaults.set(remote, forKey: key)
        return true
    }

    /// Égalité de deux valeurs de préférence. `NSObject.isEqual` couvre les
    /// types qu'un magasin clé-valeur accepte (nombres, chaînes, données) ;
    /// deux absences sont égales.
    private func valuesMatch(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (l as NSObject, r as NSObject): return l.isEqual(r)
        default: return false
        }
    }
}
