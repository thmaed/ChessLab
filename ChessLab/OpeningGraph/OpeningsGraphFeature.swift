import Foundation

/// Drapeau de fonctionnalité LOCAL du nouveau module d'ouvertures en graphe.
///
/// Permet de livrer le modèle, la donnée et la synchro (J2-J5) AVANT l'UI
/// complète (Explorer / Apprendre / Entraîner, J6-J8) : tant qu'il est faux,
/// l'onglet « Ouvertures » garde EXACTEMENT la bibliothèque linéaire existante
/// (149 familles ``OpeningLibraryEntry``) — aucune régression, coexistence
/// additive. Faux par défaut ; bascule via `UserDefaults`. Aucune UI ne
/// l'expose encore : c'est un interrupteur de développement / déploiement
/// progressif, pas un réglage utilisateur.
///
/// - important: même activé, le module ne doit s'afficher que si des cours sont
///   réellement embarqués et décodables (``isActive``) — sinon on retombe
///   silencieusement sur la bibliothèque linéaire.
enum OpeningsGraphFeature {
    private static let key = "openingsGraphEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// Des cours sont-ils embarqués (catalogue non vide) ?
    static var hasBundledCourses: Bool { !OpeningCourseLoader.catalog.isEmpty }

    /// Le module graphe doit-il être proposé dans l'UI ?
    static var isActive: Bool { isEnabled && hasBundledCourses }
}
