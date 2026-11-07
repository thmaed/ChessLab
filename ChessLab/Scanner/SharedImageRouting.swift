import Foundation

/// Qui ouvre le scanner pour une image reçue par « Partager › ChessLab » ?
///
/// ``HomeView`` pousse l'écran quand une image attend dans ``SharedImageInbox``
/// — sauf si ``ScannerView`` est déjà ouvert : celui-ci la prend alors lui-même,
/// sans empiler un second scanner par-dessus le premier.
@MainActor
enum SharedImageRouting {
    /// Vrai tant qu'un ``ScannerView`` est à l'écran.
    static var scannerIsOpen = false
}
