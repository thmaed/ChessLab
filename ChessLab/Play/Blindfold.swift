import AVFoundation
import ChessKit
import Foundation

/// Partie À L'AVEUGLE contre l'ordinateur (17/11/2026). Les quatre niveaux du mail aux testeurs, du plus
/// facile au plus dur ; décisions de l'utilisateur : les quatre, disques À LA COULEUR au niveau
/// « Cases occupées », coup d'œil en MAINTENANT le doigt (chaque appui compte), voix éteinte par défaut.
///
/// Ce que le mode coupe, à tous les niveaux : points de coups légaux (ceux d'une tour s'arrêtent devant une
/// pièce cachée), indice, alerte de gaffe, barre d'évaluation. La liste des coups reste.
enum BlindfoldLevel: String, Codable, CaseIterable, Hashable, Identifiable {
    case off
    /// Un disque blanc ou noir à la place de chaque pièce.
    case occupiedSquares
    /// On voit ses pièces, pas celles de l'adversaire.
    case opponentHidden
    /// On voit celles de l'adversaire, pas les siennes.
    case ownHidden
    /// Plateau vide.
    case allHidden

    var id: String { rawValue }

    /// Les niveaux proposés, dans l'ordre de difficulté.
    static let levels: [BlindfoldLevel] = [.occupiedSquares, .opponentHidden, .ownHidden, .allHidden]

    /// Clé française (localisée par l'appelant).
    var title: String {
        switch self {
        case .off: "Non"
        case .occupiedSquares: "Cases occupées"
        case .opponentHidden: "Pièces adverses cachées"
        case .ownHidden: "Vos pièces cachées"
        case .allHidden: "Tout caché"
        }
    }

    /// Une phrase sous le titre.
    var detail: String {
        switch self {
        case .off: "Les pièces se voient."
        case .occupiedSquares: "Un disque blanc ou noir à la place de chaque pièce : on sait à qui elle est, pas laquelle c'est."
        case .opponentHidden: "Vous voyez vos pièces, pas celles de l'adversaire."
        case .ownHidden: "Vous voyez celles de l'adversaire, pas les vôtres."
        case .allHidden: "Le plateau est vide : tout se joue de mémoire."
        }
    }

    /// Ce que le plateau montre, vu du camp `user`.
    func mask(user: Piece.Color) -> PieceMask {
        switch self {
        case .off: .none
        case .occupiedSquares: .discs
        case .opponentHidden: .hidden([user.opposite])
        case .ownHidden: .hidden([user])
        case .allHidden: .hidden([.white, .black])
        }
    }

    /// On ne fait glisser que les pièces qu'on VOIT : à l'aveugle, sinon, on joue en touchant départ et arrivée.
    func canDrag(user: Piece.Color) -> Bool {
        mask(user: user).display(Piece(.king, color: user, square: .a1)) == .glyph
    }
}

/// Les coups de l'adversaire lus à voix haute — synthèse vocale de l'appareil, qui ne sort pas sur le réseau.
/// Les phrases sont celles de VoiceOver (``MoveNarration``), dans la langue de l'app.
@MainActor
final class BlindfoldVoice {
    static let shared = BlindfoldVoice()
    private let synthesizer = AVSpeechSynthesizer()

    func say(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: LocalizationController.activeLanguageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}
