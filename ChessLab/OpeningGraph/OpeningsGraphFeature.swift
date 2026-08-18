import Foundation

/// Disponibilité du module d'ouvertures en graphe (Explorer / Apprendre /
/// Entraîner).
///
/// Historiquement gardé par un drapeau d'aperçu (off par défaut), il est
/// désormais VISIBLE PAR DÉFAUT (décision du 10/08/2026) : le bouton
/// « Explorateur » apparaît dans l'onglet Ouvertures dès que des cours sont
/// embarqués. La bibliothèque linéaire (149 familles, ``OpeningTheoryEntry``)
/// reste l'expérience par défaut de l'onglet ; le module graphe s'y ajoute.
enum OpeningsGraphFeature {
    /// Des cours sont-ils embarqués (catalogue non vide) ?
    static var hasBundledCourses: Bool { !OpeningCourseLoader.catalog.isEmpty }

    /// Le module graphe doit-il être proposé dans l'UI ?
    static var isActive: Bool { hasBundledCourses }
}
