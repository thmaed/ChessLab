import Foundation

/// Type de source d'image du scanner.
///
/// Les deux cas sont des « diagrammes numériques » (glyphes 2D) et se
/// DÉDUISENT de l'image, sans rien demander à l'utilisateur : un damier net et
/// aligné sur les axes est une capture, sinon l'image a été photographiée.
///
/// Le scanner de plateau RÉEL (`physicalTopDown` + `PhysicalOccupancyClassifier`)
/// a été retiré le 20/07/2026 : il ne rendait que l'occupation et la couleur —
/// obligeant l'utilisateur à nommer chaque pièce à la main — et n'avait jamais
/// été validé sur une seule photo réelle (aucune fixture). Le scanner ne
/// traite plus que les échiquiers à l'écran, lus par le modèle YOLO.
enum ScanSource: String, CaseIterable, Identifiable, Hashable {
    /// Capture d'écran d'une app ou d'un site (Lichess…) : glyphes 2D nets,
    /// aucune déformation. Cible n°1 du prompt.
    case screenshot
    /// Photo d'un écran affichant un plateau : mêmes glyphes, mais moiré,
    /// reflets et perspective. Cible n°2 du prompt.
    case screenPhoto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .screenshot: "Capture d'écran"
        case .screenPhoto: "Photo d'un écran"
        }
    }

    var systemImage: String {
        switch self {
        case .screenshot: "rectangle.on.rectangle"
        case .screenPhoto: "camera.viewfinder"
        }
    }

    /// Consigne de prise de vue affichée sous le choix de la source.
    var instructions: String {
        switch self {
        case .screenshot:
            "Choisissez une capture d'écran d'échiquier dans votre photothèque. Le plateau doit être entièrement visible."
        case .screenPhoto:
            "Photographiez l'écran bien en face, sans reflet. Cadrez le plateau au plus près."
        }
    }
}
