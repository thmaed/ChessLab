import Foundation

/// Disponibilité du module « Ouvertures — Labs ».
///
/// Aperçu OPT-IN : la tuile n'apparaît sur l'accueil que si l'utilisateur a
/// allumé l'interrupteur dans les réglages (« Ouvertures — Labs », section
/// Aperçus). C'est délibéré : le module d'ouvertures en production reste
/// l'expérience par défaut, Labs s'y ajoute pour qui veut l'essayer, et
/// personne ne découvre deux tuiles « Ouvertures » sans l'avoir demandé.
///
/// Deux conditions, pas une : l'interrupteur ET la présence effective de la
/// donnée. Un réglage allumé sur une build sans sidecars ouvrirait un module
/// à moitié vide.
@MainActor
enum OpeningLabsFeature {
    /// Des cours d'ouverture sont-ils embarqués ?
    static var hasCourses: Bool {
        OpeningCourseLoader.catalog.contains { !$0.isEndgame }
    }

    /// Le module doit-il être proposé ?
    static var isActive: Bool { AppSettings.shared.openingsLabsEnabled && hasCourses }

    /// Les ouvertures que Labs présente : les cours livrés et ceux qu'a
    /// importés l'utilisateur, les FINALES exclues.
    ///
    /// Une finale n'a ni index de lignes (pas de chapitres pédagogiques en
    /// variantes), ni statistiques de maîtres (une position de finale théorique
    /// n'a jamais été jouée telle quelle en tournoi). L'y faire figurer
    /// donnerait un écran dont les trois quarts diraient « aucune donnée ».
    static var catalog: [OpeningCatalogEntry] {
        OpeningCatalog.all.filter { !$0.isEndgame }
    }
}
