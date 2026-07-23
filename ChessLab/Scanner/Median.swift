import Foundation

/// Médiane d'un échantillon.
///
/// Robuste aux valeurs aberrantes — reflet spéculaire, ombre portée — là où
/// une moyenne se laisse tirer par une seule valeur extrême. C'est ce qui la
/// rend juste sur des profils de pixels, où quelques points parasites sont la
/// règle plutôt que l'exception.
///
/// Vivait comme méthode statique de `RGBColor`, structure retirée avec le
/// scanner de plateau réel (20/07/2026) : de tout ce type, seule cette
/// fonction avait des appelants au-delà du classifieur supprimé — la
/// détection de damier et la recherche de grille s'en servent sur des
/// profils de luminance. La ressusciter entière n'aurait fait que remplacer
/// du code mort par du code mort.
enum Sample {
    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }
}
