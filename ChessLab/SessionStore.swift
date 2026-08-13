import SwiftUI

/// Coffre des view models de session, détenu par ``HomeView`` — donc **au-dessus**
/// du `if/else` qui choisit l'ossature.
///
/// ## Le problème qu'il résout
///
/// `HomeView` choisit son ossature par
/// `if horizontalSizeClass == .regular { splitBody } else { stackBody }`.
/// Dans un `ViewBuilder`, cette forme produit un `_ConditionalContent` :
/// changer de branche ne reconfigure pas l'arbre, il le **détruit et le
/// reconstruit**, emportant les `@State` de tous les descendants — dont les
/// view models des douze hôtes (partie en cours, analyse, puzzle,
/// laboratoire, ouvertures…). Comme `path`, lui, survit (c'est un `@State` de
/// `HomeView`), la route est ré-instanciée, un hôte neuf apparaît, et un view
/// model neuf est construit : échiquier revenu à la position initiale,
/// nouveau Stockfish, puzzle différent, analyse au coup 0.
///
/// Mesuré au Lot 0 : les iPhone **Plus et Pro Max** passent en
/// `horizontalSizeClass == .regular` en paysage. Une simple rotation suffit
/// donc à déclencher la destruction — ce n'est pas un cas iPad exotique.
///
/// ## Le remède
///
/// Les view models sont détenus ICI, dans un objet dont la durée de vie est
/// celle de `HomeView`, que la bascule d'ossature n'atteint pas. Les hôtes
/// gardent un `@State` local, mais seulement comme **miroir de rendu** : il
/// est détruit avec l'arbre puis re-rempli depuis le coffre, avec la MÊME
/// instance. La partie continue.
///
/// ## Durée de vie
///
/// Le coffre est vidé quand la pile de navigation redevient vide (retour à
/// l'accueil) : sans ça un `PlayViewModel` survivrait à son écran, et avec
/// lui un Stockfish qui cherche derrière l'interface — exactement ce que
/// surveille `EngineLeakUITests` via le marqueur `engineInstances`.
@MainActor
final class SessionStore {
    /// `nonisolated` pour que la valeur de repli de la clé d'environnement
    /// puisse être construite hors du `MainActor` (exigence de conformité à
    /// ``EnvironmentKey`` en concurrence stricte). Le coffre lui-même reste
    /// isolé : seule sa création ne l'est pas.
    nonisolated init() {}

    private var storage: [String: AnyObject] = [:]

    /// Le view model déjà ouvert pour cette clé, ou celui que `make`
    /// construit — appelé **une seule fois** par clé.
    ///
    /// - important: à n'appeler que depuis un effet (`onAppear`), jamais
    /// depuis un `body` : construire un `PlayViewModel` démarre un process
    /// Stockfish, et `body` est réévalué à volonté par SwiftUI.
    func value<T: AnyObject>(for key: String, make: () -> T?) -> T? {
        if let existing = storage[key] as? T { return existing }
        guard let created = make() else { return nil }
        storage[key] = created
        return created
    }

    /// Vide le coffre — retour à l'accueil.
    func clear() {
        storage.removeAll()
    }

    /// Oublie une session précise.
    ///
    /// Nécessaire pour la revanche : elle peut avoir **exactement** les mêmes
    /// réglages que la partie qu'on quitte, donc la même clé. Sans cet oubli
    /// ciblé, le coffre rendrait l'ancien view model et la « nouvelle »
    /// partie s'ouvrirait sur la position de l'ancienne.
    func remove(_ key: String) {
        storage[key] = nil
    }
}

private struct SessionStoreKey: EnvironmentKey {
    /// Valeur de repli pour les aperçus Xcode et les vues montées hors de
    /// ``HomeView`` ; en usage réel, `HomeView` injecte toujours le sien.
    static let defaultValue = SessionStore()
}

extension EnvironmentValues {
    /// Coffre de session ambiant — voir ``SessionStore``.
    var sessionStore: SessionStore {
        get { self[SessionStoreKey.self] }
        set { self[SessionStoreKey.self] = newValue }
    }
}
