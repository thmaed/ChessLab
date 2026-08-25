import ChessKit
import CryptoKit
import Foundation

/// Persistance LOCALE des analyses de parties : ce que le moteur a calculé
/// une fois ne se recalcule plus.
///
/// ## Ce qui est conservé, et pourquoi ça suffit
///
/// Pour chaque position de la LIGNE PRINCIPALE : l'évaluation complète
/// (probabilité de gain, pions, meilleur coup, écart au 2e choix, réfutation) ;
/// pour chaque coup : son verdict (qualité + explication). C'est exactement ce
/// que `AnalysisViewModel` tient en mémoire — rechargée, la partie s'affiche
/// classifiée à l'identique, sans une seule requête moteur. Seule l'analyse
/// EN CONTINU de la position affichée repart, comme pour une position neuve.
///
/// ## La clé : la partie, pas son texte
///
/// SHA-256 de la FEN de départ et de la séquence LAN de la ligne principale.
/// Deux PGN cosmétiquement différents (autres en-têtes, autres commentaires,
/// CRLF…) de la MÊME partie partagent donc leur analyse — c'est le pendant de
/// la signature anti-doublons de la bibliothèque.
///
/// ## Invalidation
///
/// Le fichier embarque un profil (moteur + budgets + seuils). Changer de
/// Stockfish ou de barème invalide TOUT — mieux vaut réanalyser que mélanger
/// deux vérités. Local uniquement : pas d'iCloud pour un cache reproductible.
enum AnalysisEvalStore {

    static let currentSchema = 1
    /// À INCRÉMENTER à chaque changement de moteur, de budget ou de seuils.
    static let engineProfile = "SF17.1/300k+3Mx2/2-5-10-20"
    /// Profil de ``Chess960AnalysisViewModel`` : passe de base SEULE (pas
    /// d'affinage ×10, pas de livre d'ouvertures) — un profil distinct pour
    /// que le fichier reste auto-descriptif, même si la clé (qui inclut déjà
    /// la FEN de départ) ne permettrait de toute façon aucune collision avec
    /// une partie standard.
    static let chess960Profile = "SF17.1-Chess960/300k×1"
    /// Profil de ``VariantAnalysisViewModel`` — les six variantes Fairy-
    /// Stockfish (lots A et B) partagent un seul profil : la clé inclut déjà
    /// la FEN de départ ET l'identifiant UCI de la variante n'a pas besoin
    /// d'y figurer séparément, deux parties de variantes différentes ne
    /// peuvent de toute façon jamais partager le même journal de coups.
    static let variantsProfile = "Fairy14-Variants/300k×1"
    /// Nombre de parties conservées (LRU par date de modification).
    static let maxSnapshots = 300

    // MARK: Modèle sur disque

    struct Snapshot: Codable {
        var schema: Int = AnalysisEvalStore.currentSchema
        var profile: String = AnalysisEvalStore.engineProfile
        /// Éval par demi-coup (0 = position de départ).
        var evals: [Int: PositionEval] = [:]
        /// Verdict par demi-coup (1 = premier coup joué).
        var verdicts: [Int: MoveVerdict] = [:]
    }

    struct PositionEval: Codable {
        var winPercent: Double
        var pawns: Double
        var bestLan: String?
        var gapToSecondBest: Double?
        var secondBestLan: String?
        var pv: [String] = []
        /// Éval issue de la recherche d'affinage — rechargée, elle garde son
        /// statut et ne sera jamais réapprofondie.
        var isRefined: Bool? = nil
    }

    struct MoveVerdict: Codable {
        var winPercentAfterMover: Double
        /// `MoveQuality.rawValue` — une valeur inconnue (app plus ancienne)
        /// invalide le verdict, pas le fichier.
        var quality: String
        var explanation: Explanation?
    }

    struct Explanation: Codable {
        var motif: Motif?
        var materialLoss: Int?
        var refutationSAN: String
    }

    /// ``TacticalMotif`` aplati en champs primitifs : on ne dépend pas des
    /// conformances Codable de ChessKit, qui ne nous appartiennent pas.
    struct Motif: Codable {
        var kind: String
        var intValue: Int?
        var boolValue: Bool?
        var pieceA: String?
        var pieceB: String?
        var square: String?
        var targets: [String]?
    }

    // MARK: Clé d'une partie

    /// Clé stable d'une partie : position de départ + ligne principale (LAN).
    static func key(for game: Game) -> String? {
        guard let start = game.positions[game.startingIndex] else { return nil }
        var lans: [String] = []
        var idx = game.startingIndex
        while game.moves.hasIndex(after: idx) {
            idx = game.moves.index(after: idx)
            guard let move = game.moves[idx] else { break }
            lans.append(move.lan)
        }
        return key(startFEN: start.fen, lans: lans)
    }

    /// Même clé, pour un appelant qui n'a pas de ``Game`` ChessKit — le
    /// Chess960 rejoue sa ligne principale en UCI, pas via `MoveTree`.
    ///
    /// `variantID` : QUATRE des six variantes (Roi de la colline, Trois
    /// échecs, Atomique, Antéchecs) partagent la position de départ
    /// STANDARD — sans cet identifiant dans le matériau haché, deux parties
    /// « 1.e4 e5 » de variantes DIFFÉRENTES produiraient la MÊME clé et
    /// partageraient à tort classification/éval en cache.
    static func key(startFEN: String, lans: [String], variantID: String? = nil) -> String? {
        guard !lans.isEmpty else { return nil }
        var material = startFEN + "|" + lans.joined(separator: " ")
        if let variantID { material = variantID + "|" + material }
        let digest = SHA256.hash(data: Data(material.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Lecture / écriture

    static func load(key: String, profile: String = engineProfile) -> Snapshot? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.schema == currentSchema,
              snapshot.profile == profile
        else { return nil }
        // LRU : consulter un instantané le rajeunit.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return snapshot
    }

    static func save(_ snapshot: Snapshot, key: String) {
        guard !snapshot.evals.isEmpty else { return }
        let directory = cacheDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL(for: key), options: .atomic)
        prune()
    }

    /// Garde les ``maxSnapshots`` plus récents — un cache n'est pas une base.
    static func prune() {
        let directory = cacheDirectory()
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        ), urls.count > maxSnapshots else { return }
        let dated = urls.map { url -> (URL, Date) in
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return (url, date)
        }
        for (url, _) in dated.sorted(by: { $0.1 > $1.1 }).dropFirst(maxSnapshots) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func fileURL(for key: String) -> URL {
        cacheDirectory().appendingPathComponent("\(key).json")
    }

    private static func cacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("AnalysisCache", isDirectory: true)
    }

    // MARK: Pont ``TacticalMotif`` ⇄ DTO

    static func motifDTO(_ motif: TacticalMotif?) -> Motif? {
        switch motif {
        case nil:
            return nil
        case let .checkmate(inMoves, isBackRank):
            return Motif(kind: "checkmate", intValue: inMoves, boolValue: isBackRank)
        case let .hangingPiece(kind, square):
            return Motif(kind: "hangingPiece", pieceA: kind.rawValue, square: "\(square)")
        case let .fork(by, on, targets):
            return Motif(kind: "fork", pieceA: by.rawValue, square: "\(on)",
                         targets: targets.map(\.rawValue))
        case let .discoveredCheck(by):
            return Motif(kind: "discoveredCheck", pieceA: by.rawValue)
        case let .pin(victim, behind):
            return Motif(kind: "pin", pieceA: victim.rawValue, pieceB: behind.rawValue)
        }
    }

    static func motif(from dto: Motif?) -> TacticalMotif? {
        guard let dto else { return nil }
        switch dto.kind {
        case "checkmate":
            guard let inMoves = dto.intValue, let backRank = dto.boolValue else { return nil }
            return .checkmate(inMoves: inMoves, isBackRank: backRank)
        case "hangingPiece":
            guard let raw = dto.pieceA, let kind = Piece.Kind(rawValue: raw),
                  let name = dto.square else { return nil }
            return .hangingPiece(kind: kind, on: Square(name))
        case "fork":
            guard let raw = dto.pieceA, let kind = Piece.Kind(rawValue: raw),
                  let name = dto.square, let targets = dto.targets else { return nil }
            return .fork(by: kind, on: Square(name),
                         targets: targets.compactMap(Piece.Kind.init(rawValue:)))
        case "discoveredCheck":
            guard let raw = dto.pieceA, let kind = Piece.Kind(rawValue: raw) else { return nil }
            return .discoveredCheck(by: kind)
        case "pin":
            guard let rawA = dto.pieceA, let victim = Piece.Kind(rawValue: rawA),
                  let rawB = dto.pieceB, let behind = Piece.Kind(rawValue: rawB) else { return nil }
            return .pin(victim: victim, behind: behind)
        default:
            return nil
        }
    }
}
