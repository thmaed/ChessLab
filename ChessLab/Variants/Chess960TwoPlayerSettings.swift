import ChessKit
import Foundation

/// Réglages d'une partie de Chess960 à deux humains — même sous-ensemble que
/// ``TwoPlayerGameSettings`` (noms, rotation, cadence), plus la position de
/// départ : une FEN explicite, jamais un numéro de Scharnagl. Ce mode
/// n'existe QUE par débranchement depuis « Contre l'ordinateur » (25/08) —
/// la position affichée peut donc être n'importe quelle position ATTEINTE en
/// cours de partie, pas seulement l'un des 960 départs canoniques.
struct Chess960TwoPlayerSettings: Codable, Equatable, Hashable {
    var whiteName: String = "Blancs"
    var blackName: String = "Noirs"
    var rotationMode: TwoPlayerGameSettings.RotationMode = .faceToFace
    var timeControlID: String = TimeControl.none.id
    var customMinutes: Int = 15
    var customIncrementSeconds: Int = 0
    /// FEN Shredder de départ — jamais optionnelle : sans position d'origine,
    /// ce mode n'a pas de raison d'exister (voir le commentaire de tête).
    var startFEN: String

    var timeControl: TimeControl {
        if timeControlID == "custom" {
            return .custom(minutes: customMinutes, incrementSeconds: customIncrementSeconds)
        }
        return TimeControl.presets.first { $0.id == timeControlID } ?? .none
    }
}
