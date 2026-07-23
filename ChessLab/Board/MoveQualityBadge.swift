import ChessKit
import SwiftUI

/// Qualité d'un coup, telle qu'on la POSE SUR LE PLATEAU.
///
/// L'échelle complète façon chess.com : CHAQUE coup reçoit une catégorie,
/// pas seulement les fautes. `Move.Assessment` de ChessKit reste le type
/// d'EXPORT (notation NAG du PGN) — il ne connaît ni « meilleur coup », ni
/// « théorie », ni « occasion manquée », d'où ce type maison comme contrat
/// unique entre la classification et tout ce qui l'affiche.
///
/// L'ordre des cas est l'ordre d'affichage du bilan : du plus glorieux au
/// plus douloureux.
enum MoveQuality: String, CaseIterable, Hashable {
    case brilliant   // !! — sacrifice correct et nettement supérieur
    case great       // !  — le seul bon coup de la position
    case best        // ★  — le premier choix du moteur
    case excellent   //    — quasi sans perte
    case good        //    — perte modeste, coup sain
    case book        // 📖 — encore dans la théorie connue
    case inaccuracy  // ?!
    case mistake     // ?
    case miss        // ✕  — occasion manquée : la victoire était là
    case blunder     // ??

    /// Ce que la pastille dessine : un symbole texte (les NAG se
    /// reconnaissent au premier regard) ou un glyphe SF Symbol quand la
    /// notation d'échecs n'a pas de signe pour la catégorie.
    enum Icon: Equatable {
        case text(String)
        case symbol(String)
    }

    var icon: Icon {
        switch self {
        case .brilliant: .text("!!")
        case .great: .text("!")
        case .best: .symbol("star.fill")
        case .excellent: .symbol("hand.thumbsup.fill")
        case .good: .symbol("checkmark")
        case .book: .symbol("book.fill")
        case .inaccuracy: .text("?!")
        case .mistake: .text("?")
        case .miss: .symbol("xmark")
        case .blunder: .text("??")
        }
    }

    /// Le regard doit trancher bon/mauvais AVANT de lire le symbole :
    /// famille verte/teal pour les bons coups, sable pour la théorie,
    /// jaune → rouge pour la descente aux enfers.
    var tint: Color {
        switch self {
        case .brilliant: Color(red: 0.10, green: 0.72, blue: 0.65)
        case .great: Color(red: 0.35, green: 0.56, blue: 0.90)
        case .best: Color(red: 0.42, green: 0.72, blue: 0.30)
        case .excellent: Color(red: 0.51, green: 0.71, blue: 0.36)
        case .good: Color(red: 0.46, green: 0.60, blue: 0.44)
        case .book: Color(red: 0.66, green: 0.60, blue: 0.48)
        case .inaccuracy: Color(red: 0.94, green: 0.78, blue: 0.31)
        case .mistake: Color(red: 0.95, green: 0.55, blue: 0.25)
        case .miss: Color(red: 0.93, green: 0.45, blue: 0.40)
        case .blunder: Color(red: 0.85, green: 0.25, blue: 0.25)
        }
    }

    /// Libellé parlé et affiché en clair — « ?? » ne se prononce pas.
    var label: String {
        switch self {
        case .brilliant: String(localized: "Brillant")
        case .great: String(localized: "Grand coup")
        case .best: String(localized: "Le meilleur")
        case .excellent: String(localized: "Excellent")
        case .good: String(localized: "Bon coup")
        case .book: String(localized: "Théorie")
        case .inaccuracy: String(localized: "Imprécision")
        case .mistake: String(localized: "Erreur")
        case .miss: String(localized: "Occasion manquée")
        case .blunder: String(localized: "Gaffe")
        }
    }

    /// Les catégories qui appellent une correction : la flèche
    /// rétrospective « il fallait jouer ça » et les puzzles n'ont de sens
    /// que pour elles.
    var isFault: Bool {
        switch self {
        case .inaccuracy, .mistake, .miss, .blunder: true
        default: false
        }
    }

    /// Symbole dans le ruban de coups : seulement les catégories
    /// REMARQUABLES. Un symbole sur chaque chip (la moitié des coups sont
    /// « meilleur » ou « bon ») noierait précisément ce qu'on veut voir en
    /// balayant la partie : les moments où elle a basculé.
    var showsInMoveList: Bool {
        switch self {
        case .brilliant, .great, .miss, .inaccuracy, .mistake, .blunder: true
        case .best, .excellent, .good, .book: false
        }
    }

    /// Notation NAG pour l'export PGN. Les catégories que la notation
    /// d'échecs ne connaît pas (meilleur, excellent, bon, théorie) partent
    /// sans annotation — un PGN constellé de signes inventés ne serait lu
    /// par aucun autre logiciel.
    var pgnAssessment: Move.Assessment? {
        switch self {
        case .brilliant: .brilliant
        case .great: .good
        case .inaccuracy: .dubious
        case .mistake, .miss: .mistake
        case .blunder: .blunder
        case .best, .excellent, .good, .book: nil
        }
    }

    /// Lecture inverse, pour les PGN IMPORTÉS déjà annotés (avant que
    /// notre propre classification ne passe) : on affiche leurs NAG avec
    /// nos couleurs plutôt que rien.
    init?(_ assessment: Move.Assessment) {
        switch assessment {
        case .brilliant: self = .brilliant
        case .good: self = .great
        case .interesting: self = .good
        case .dubious: self = .inaccuracy
        case .mistake: self = .mistake
        case .blunder: self = .blunder
        default: return nil
        }
    }
}

/// Pastille posée sur la case d'ARRIVÉE du coup joué, débordant vers le haut
/// à droite — comme chess.com, parce que c'est là que l'œil va après avoir vu
/// la pièce bouger, et que ça ne recouvre pas le glyphe.
struct MoveQualityBadgeView: View {
    let quality: MoveQuality
    let squareSize: CGFloat

    var body: some View {
        iconView
            .foregroundStyle(.white)
            .frame(width: squareSize * 0.42, height: squareSize * 0.42)
            .background(quality.tint, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: squareSize * 0.02))
            .shadow(color: .black.opacity(0.35), radius: squareSize * 0.03, y: squareSize * 0.01)
            .accessibilityLabel(Text(quality.label))
    }

    @ViewBuilder
    private var iconView: some View {
        switch quality.icon {
        case let .text(text):
            Text(text)
                .font(.system(size: squareSize * 0.30, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        case let .symbol(name):
            Image(systemName: name)
                .font(.system(size: squareSize * 0.20, weight: .bold))
        }
    }
}
