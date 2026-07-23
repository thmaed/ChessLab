import Foundation

/// Notation des pièces à l'AFFICHAGE.
///
/// Le prompt exige la notation française par défaut (R D T F C), l'anglaise en
/// option. Ce réglage ne concerne QUE ce que l'utilisateur lit : le PGN
/// stocké, exporté et comparé reste en lettres anglaises — c'est le standard,
/// et un PGN francisé ne serait relisible par personne, pas même par nous.
enum PieceNotation: String, CaseIterable, Identifiable, Sendable {
    case french
    case english

    var id: String { rawValue }

    var label: String {
        switch self {
        case .french: "Française"
        case .english: "Anglaise"
        }
    }

    /// Exemple montré sous les chips : « Cf3 » vaut mieux qu'une explication.
    var example: String {
        switch self {
        case .french: "Cf3, Dxd5, O-O"
        case .english: "Nf3, Qxd5, O-O"
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

    /// - important: conversion **caractère par caractère, en une seule
    ///   passe**. Des `replace` successifs seraient faux : « R → T » puis
    ///   « K → R » retraduirait les T fraîchement écrits, et un roi
    ///   deviendrait une tour. Ce piège est la raison d'être de cette table.
    static func display(_ san: String, notation: PieceNotation) -> String {
        guard notation == .french else { return san }
        // `O-O`, `x`, `+`, `#`, les chiffres et les colonnes minuscules ne
        // sont dans aucune table : ils traversent intacts. `=Q` devient `=D`
        // par la même passe, et c'est voulu.
        return String(san.map { frenchLetters[$0] ?? $0 })
    }

    /// Version qui suit le réglage de l'utilisateur — l'usage courant côté vue.
    @MainActor
    static func display(_ san: String) -> String {
        display(san, notation: AppSettings.shared.pieceNotation)
    }

    /// Suite de coups (liste, chemin de répertoire).
    static func display(_ sans: [String], notation: PieceNotation) -> [String] {
        guard notation == .french else { return sans }
        return sans.map { display($0, notation: notation) }
    }

    @MainActor
    static func display(_ sans: [String]) -> [String] {
        display(sans, notation: AppSettings.shared.pieceNotation)
    }
}
