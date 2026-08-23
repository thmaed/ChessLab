import ChessKit
import Foundation

/// Le COUP tel que l'index des lignes le manipule : de quoi l'afficher, de
/// quoi le juger, et de quoi y sauter.
///
/// L'arbre lui-même est construit par ``OpeningLineTree`` ; ce type est le
/// grain dont il est fait, isolé ici parce qu'il sert aussi au lecteur.
enum OpeningLineIndex {

    /// Un coup de l'index.
    struct IndexedMove: Hashable, Sendable, Identifiable {
        /// Demi-coup depuis la racine du cours (1 = premier coup blanc).
        /// Décide du numéro affiché et de qui joue.
        let ply: Int
        let san: String
        let uci: String
        /// Clé FEN de la position ATTEINTE — la destination du saut.
        let toFEN: String
        /// Clé FEN de la position de DÉPART — de quoi juger le coup (voir
        /// ``OpeningMoveQuality``) sans rejouer la ligne.
        let fromFEN: String
        let role: MoveRole
        /// Nom de variante atteint par ce coup, s'il y en a un.
        let ecoName: String?
        let isCritical: Bool
        let hasComment: Bool
        /// Chemin COMPLET en UCI depuis la racine du cours, ce coup inclus.
        ///
        /// C'est l'instruction de saut : rejouer ces coups depuis la racine
        /// reconstruit exactement la position ET le fil des coups. Stocker la
        /// seule FEN d'arrivée ne suffirait pas — le lecteur affiche le chemin
        /// parcouru, et une position atteinte par transposition a plusieurs
        /// chemins possibles ; on veut CELUI de cette branche.
        let path: [String]
        /// Verdict du moteur, quand il mérite d'être montré : gaffe, erreur,
        /// imprécision, occasion manquée, coup brillant. `nil` partout
        /// ailleurs — voir ``OpeningMoveQuality/displayed``.
        var quality: MoveQuality?

        /// Identité = le CHEMIN COMPLET, pas (demi-coup, coup).
        ///
        /// 🐛 Deux coups différents peuvent partager leur demi-coup ET leur
        /// notation : dans la scandinave, deux branches partent toutes deux de
        /// « 4…♞f6 » et ne divergent qu'au coup blanc suivant (5.d4 / 5.♗c4).
        /// Avec une identité (demi-coup, coup), `ForEach` voyait deux fois la
        /// même chose : il affichait la première branche DEUX FOIS et la
        /// variante 5.♗c4 disparaissait de l'index, en silence.
        var id: String { path.joined(separator: ".") }

        /// Camp qui joue ce coup (demi-coups impairs = blancs).
        var color: Piece.Color { ply % 2 == 1 ? .white : .black }

        /// Numéro de coup entier (« 4 » pour 4.Fc4 comme pour 4…Fc5).
        var moveNumber: Int { (ply + 1) / 2 }

        /// Préfixe de notation : « 4. » pour un coup blanc, « 4… » pour un
        /// coup noir qui OUVRE une rangée (sinon rien : dans « 4.Fc4 Fc5 », le
        /// coup noir se lit sans numéro).
        func numberPrefix(isFirstOfLine: Bool) -> String? {
            if color == .white { return "\(moveNumber)." }
            return isFirstOfLine ? "\(moveNumber)…" : nil
        }
    }
}
