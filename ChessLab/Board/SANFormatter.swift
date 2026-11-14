import Foundation

/// Notation des pièces à l'AFFICHAGE.
///
/// Le prompt exige la notation française par défaut (R D T F C), l'anglaise en
/// option ; l'espagnole et l'italienne (R D T A C) et l'allemande (K D T L S) suivent les
/// usages de leur langue. Ce réglage ne concerne QUE ce que l'utilisateur lit : le PGN
/// stocké, exporté et comparé reste en lettres anglaises — c'est le standard,
/// et un PGN francisé ne serait relisible par personne, pas même par nous.
enum PieceNotation: String, CaseIterable, Identifiable, Sendable {
    case french
    case english
    case spanish
    case german
    case italian

    var id: String { rawValue }

    var label: String {
        switch self {
        case .french: "Française"
        case .english: "Anglaise"
        case .spanish: "Espagnole"
        case .german: "Allemande"
        case .italian: "Italienne"
        }
    }

    /// La notation que l'usage de la langue appelle : espagnole pour `es`,
    /// allemande pour `de`, italienne pour `it`, française sinon (le défaut historique de l'app).
    /// Ne sert qu'à choisir la valeur d'un réglage JAMAIS touché : un choix
    /// explicite de l'utilisateur l'emporte toujours.
    static func defaultFor(languageCode: String) -> PieceNotation {
        switch languageCode {
        case "es": .spanish
        case "de": .german
        case "it": .italian
        default: .french
        }
    }

    /// Exemple montré sous les chips : « Cf3 » vaut mieux qu'une explication.
    var example: String {
        switch self {
        case .french: "Cf3, Dxd5, O-O"
        case .english: "Nf3, Qxd5, O-O"
        case .spanish: "Cf3, Dxd5, O-O"
        case .german: "Sf3, Dxd5, O-O"
        case .italian: "Cf3, Dxd5, O-O"
        }
    }
}

/// Traduit un SAN anglais pour l'affichage.
///
/// ⚠️ **Transformation d'AFFICHAGE, et rien d'autre.** Ne jamais l'appliquer à
/// ce qui est stocké, comparé ou exporté (PGN, `pathKey`, `expectedSANs`) : le
/// standard PGN est en lettres anglaises.
enum SANFormatter {

    /// Lettres de pièce, majuscules UNIQUEMENT : les minuscules sont des
    /// colonnes (a–h), et un `b` de colonne n'a rien à voir avec le fou.
    private static let frenchLetters: [Character: Character] = [
        "K": "R",  // King → Roi
        "Q": "D",  // Queen → Dame
        "R": "T",  // Rook → Tour
        "B": "F",  // Bishop → Fou
        "N": "C",  // Knight → Cavalier
    ]

    /// Espagnol : Rey, Dama, Torre, Alfil, Caballo.
    private static let spanishLetters: [Character: Character] = [
        "K": "R", "Q": "D", "R": "T", "B": "A", "N": "C",
    ]

    /// Allemand : König, Dame, Turm, Läufer, Springer.
    private static let germanLetters: [Character: Character] = [
        "K": "K", "Q": "D", "R": "T", "B": "L", "N": "S",
    ]

    /// Italien : Re, Donna, Torre, Alfiere, Cavallo (mêmes lettres que l'espagnol).
    private static let italianLetters: [Character: Character] = [
        "K": "R", "Q": "D", "R": "T", "B": "A", "N": "C",
    ]

    /// La table de la notation, `nil` pour l'anglaise (rien à traduire).
    private static func letters(for notation: PieceNotation) -> [Character: Character]? {
        switch notation {
        case .english: nil
        case .french: frenchLetters
        case .spanish: spanishLetters
        case .german: germanLetters
        case .italian: italianLetters
        }
    }

    /// - important: conversion **caractère par caractère, en une seule
    ///   passe**. Des `replace` successifs seraient faux : « R → T » puis
    ///   « K → R » retraduirait les T fraîchement écrits, et un roi
    ///   deviendrait une tour. Ce piège est la raison d'être de cette table.
    static func display(_ san: String, notation: PieceNotation) -> String {
        guard let table = letters(for: notation) else { return san }
        // `O-O`, `x`, `+`, `#`, les chiffres et les colonnes minuscules ne
        // sont dans aucune table : ils traversent intacts. `=Q` devient `=D`
        // par la même passe, et c'est voulu.
        return String(san.map { table[$0] ?? $0 })
    }

    /// Version qui suit le réglage de l'utilisateur — l'usage courant côté vue.
    @MainActor
    static func display(_ san: String) -> String {
        display(san, notation: AppSettings.shared.pieceNotation)
    }

    /// Suite de coups (liste, chemin de répertoire).
    static func display(_ sans: [String], notation: PieceNotation) -> [String] {
        guard notation != .english else { return sans }
        return sans.map { display($0, notation: notation) }
    }

    @MainActor
    static func display(_ sans: [String]) -> [String] {
        display(sans, notation: AppSettings.shared.pieceNotation)
    }
}
