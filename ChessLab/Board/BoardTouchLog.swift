import ChessKit
import Foundation

/// Traçage TEMPORAIRE des touchers du plateau, pour un défaut qui ne se
/// reproduit que sur appareil réel en iOS 18 : aucune pièce ne répond, ni au
/// tap ni au glisser, sur tous les écrans.
///
/// Tout ce qu'on cherche à savoir tient en une question : **le geste part-il ?**
/// - des lignes `debut-geste-piece` → le toucher atteint bien la pièce, le
///   problème est en aval (résolution du coup, view model) ;
/// - des lignes `tap-case` seulement → la pièce ne reçoit rien, son
///   `allowsHitTesting` est en cause ;
/// - **aucune ligne** → le toucher n'atteint jamais le plateau, et la piste
///   est la hiérarchie de vues (une couche au-dessus, ou des limites de
///   parent dépassées).
///
/// Compilé UNIQUEMENT en Debug : rien de tout ceci n'existe dans une archive
/// de distribution. À retirer une fois la cause trouvée — voir `PROGRESS.md`.
enum BoardTouchLog {

    #if DEBUG
    /// Dernier couple (évènement, case) tracé, pour que `recordOnce` ne
    /// noie pas la console : `onChanged` d'un `DragGesture` se déclenche à
    /// chaque image.
    @MainActor private static var last: String?

    @MainActor
    static func record(_ event: String, square: Square, detail: String) {
        print("🧪 BOARD|\(event)|\(square.notation)|\(detail)")
    }

    /// Ne trace que si le couple (évènement, case) a changé depuis la
    /// dernière fois.
    @MainActor
    static func recordOnce(_ event: String, square: Square, detail: String) {
        let signature = "\(event)|\(square.notation)"
        guard signature != last else { return }
        last = signature
        record(event, square: square, detail: detail)
    }

    /// Remis à zéro quand un geste se termine, pour que le geste suivant sur
    /// la même case soit tracé lui aussi.
    @MainActor
    static func resetThrottle() { last = nil }
    #else
    @MainActor static func record(_ event: String, square: Square, detail: String) {}
    @MainActor static func recordOnce(_ event: String, square: Square, detail: String) {}
    @MainActor static func resetThrottle() {}
    #endif
}
