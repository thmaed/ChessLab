import ChessKitEngine

/// Lecture du score d'une ligne `info` du moteur (Lot 6.B).
///
/// Le parsing brut des lignes UCI vit dans ChessKitEngine (choix documenté :
/// on délègue). Ce qui NOUS appartient — et qui n'était testé nulle part —
/// c'est comment on INTERPRÈTE le score : un mat vaut ±10 000 centipions, le
/// `mate` prime sur le `cp` (Stockfish envoie l'un OU l'autre), et une ligne
/// `info` de simple progression (profondeur, nps, sans score) ne dit rien.
///
/// Cette même logique était recopiée à l'identique dans quatre boucles de
/// consommation (coup du moteur, barre d'éval, vérification de gaffe) ; elle
/// est désormais ici, et couverte par `EngineScoreTests`.
enum EngineScore {
    /// Valeur en centipions attribuée à un mat forcé (le point de vue rend le
    /// signe : positif = le camp au trait mate).
    static let mateCentipawns = 10_000

    /// Score en centipions du **point de vue du camp au trait**, ou `nil` si
    /// la ligne ne porte pas de score.
    static func moverCentipawns(_ info: EngineResponse.Info) -> Int? {
        if let mate = info.score?.mate {
            return mate > 0 ? mateCentipawns : -mateCentipawns
        }
        if let cp = info.score?.cp {
            return Int(cp)
        }
        return nil
    }

    /// Nombre de coups avant le mat (signé), ou `nil` si la position n'est pas
    /// un mat forcé. Séparé du score en centipions : la barre d'éval affiche
    /// « M3 » et non « +100.0 ».
    static func mateInMoves(_ info: EngineResponse.Info) -> Int? {
        guard let mate = info.score?.mate else { return nil }
        return Int(mate)
    }
}
