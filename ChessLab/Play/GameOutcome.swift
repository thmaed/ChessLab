import ChessKit

/// Résultat final d'une partie du mode Jouer.
struct GameOutcome: Equatable {
    enum Reason: Equatable {
        case checkmate
        case draw(Board.State.DrawReason)
        case resignation
        case timeout
        case drawByAgreement
    }

    /// `nil` si la partie est nulle.
    let winner: Piece.Color?
    let reason: Reason

    /// Texte de résultat façon PGN ("1-0", "0-1", "1/2-1/2").
    var pgnResult: String {
        switch winner {
        case .white: "1-0"
        case .black: "0-1"
        case nil: "1/2-1/2"
        }
    }

    /// Libellé de raison LOCALISÉ — via `LocalizationController.string`
    /// et non `String(localized:)`, qui suivrait la langue de l'OS au lieu
    /// du choix in-app (piège documenté du projet). Ces textes étaient
    /// français en dur : le panneau de fin de partie — l'écran le plus
    /// regardé de l'app — restait français pour un utilisateur anglophone.
    private var reasonText: String {
        switch reason {
        case .checkmate: LocalizationController.string("échec et mat")
        case let .draw(drawReason): drawReason.displayLabel
        case .resignation: LocalizationController.string("abandon")
        case .timeout: LocalizationController.string("temps écoulé")
        case .drawByAgreement: LocalizationController.string("accord mutuel")
        }
    }

    func summary(userColor: Piece.Color) -> String {
        guard let winner else {
            return "\(LocalizationController.string("Partie nulle")) (\(reasonText))"
        }

        return winner == userColor
            ? "\(LocalizationController.string("Vous avez gagné")) (\(reasonText))"
            : "\(LocalizationController.string("Vous avez perdu")) (\(reasonText))"
    }

    /// Variante sans "utilisateur" unique, pour le mode Deux humains.
    /// « X a gagné » se compose mot à mot — l'ordre nom-verbe tient dans
    /// les deux langues (« Alice won »).
    func summary(whiteName: String, blackName: String) -> String {
        guard let winner else {
            return "\(LocalizationController.string("Partie nulle")) (\(reasonText))"
        }
        let winnerName = winner == .white ? whiteName : blackName
        return "\(winnerName) \(LocalizationController.string("a gagné")) (\(reasonText))"
    }

    /// Détecte une fin de partie à partir du seul état de l'échiquier
    /// (échec et mat / nulle) — sans dépendance au moteur ni à un
    /// quelconque "utilisateur", réutilisable par tout mode de jeu.
    static func fromBoardState(_ state: Board.State) -> GameOutcome? {
        switch state {
        case let .checkmate(color):
            GameOutcome(winner: color.opposite, reason: .checkmate)
        case let .draw(reason):
            GameOutcome(winner: nil, reason: .draw(reason))
        default:
            nil
        }
    }

    /// Fin de partie d'une position de DÉPART (aucun coup joué encore).
    ///
    /// ``fromBoardState(_:)`` ne suffit pas dans ce cas : à l'init d'un
    /// `Board`, ChessKit n'appelle `checkState(for:)` qu'avec le camp au
    /// trait, or cette fonction inspecte l'ADVERSAIRE de la couleur qu'on lui
    /// passe (`Board.updateState`). Un mat ou un pat du camp AU trait laisse
    /// donc `state == .active` — le moteur recevait alors un `go` sur une
    /// position terminée, répondait `bestmove (none)`, et l'écran de jeu
    /// restait mort. Cas réels : « Nouvelle partie » sur un FEN de position
    /// finale, et surtout « Jouer à partir d'ici » depuis la position finale
    /// d'une partie décisive.
    ///
    /// La position MIROIR (même échiquier, trait inversé) contourne la
    /// limite : son état porte précisément sur le camp au trait réel.
    static func ofStartingPosition(_ position: Position) -> GameOutcome? {
        // Fins indépendantes du trait (matériel insuffisant, 50 coups) :
        // ChessKit les voit déjà correctement dès l'init.
        if let outcome = fromBoardState(Board(position: position).state) {
            return outcome
        }

        guard let mirrored = position.withSideToMoveFlipped else { return nil }
        switch Board(position: mirrored).state {
        case let .checkmate(color):
            return GameOutcome(winner: color.opposite, reason: .checkmate)
        case .draw(.stalemate):
            return GameOutcome(winner: nil, reason: .draw(.stalemate))
        default:
            return nil
        }
    }
}

private extension Position {
    /// Même échiquier, trait inversé — sonde permettant d'interroger ChessKit
    /// sur le camp AU trait (voir ``GameOutcome/ofStartingPosition(_:)``).
    /// Passe par le FEN, `sideToMove` étant en lecture seule ; le champ « en
    /// passant » est conservé tel quel, le parseur déduisant le pion
    /// capturable de la rangée de la case, pas du trait.
    var withSideToMoveFlipped: Position? {
        var fields = fen.split(separator: " ").map(String.init)
        guard fields.count == 6 else { return nil }
        fields[1] = sideToMove == .white ? "b" : "w"
        return Position(fen: fields.joined(separator: " "))
    }
}

extension GameOutcome.Reason {
    /// Étiquette stable utilisée pour la persistance (SwiftData) — à ne
    /// pas confondre avec `displayLabel`/le texte affiché, qui peut changer
    /// sans casser les enregistrements déjà sauvegardés.
    var storageLabel: String {
        switch self {
        case .checkmate: "checkmate"
        case .draw: "draw"
        case .resignation: "resignation"
        case .timeout: "timeout"
        case .drawByAgreement: "drawByAgreement"
        }
    }
}

extension Board.State.DrawReason {
    /// Libellé localisé (anciennement `frenchLabel`, français en dur).
    var displayLabel: String {
        switch self {
        case .agreement: LocalizationController.string("accord mutuel")
        case .fiftyMoves: LocalizationController.string("règle des 50 coups")
        case .insufficientMaterial: LocalizationController.string("matériel insuffisant")
        case .repetition: LocalizationController.string("répétition de position")
        case .stalemate: LocalizationController.string("pat")
        }
    }
}
