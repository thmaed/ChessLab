import Foundation

/// Ce que le filet Stockfish s'autorise à corriger derrière Maia, et à partir
/// de quel niveau affiché. `nil` = jamais pour ce personnage.
///
/// Les seuils par défaut sont ceux de l'étude du 05/09/2026 : un joueur de
/// club trouve un mat en deux et sait finir une finale simple ; Maia, qui ne
/// calcule pas, non. En dessous, rater un mat ou gâcher une finale fait
/// partie du personnage.
struct SafetyNetPolicy: Hashable, Sendable {
    /// Mat en un ou deux disponible : Stockfish le joue dès ce niveau.
    var mateFromLevel: Int? = 1400
    /// Finale à `endgamePieceLimit` pièces ou moins : Stockfish bridé au
    /// niveau du personnage prend le relais dès ce niveau.
    var endgameFromLevel: Int? = 1600
    var endgamePieceLimit: Int = 7
    /// Répétition ou cinquante coups imminents en position gagnée : le coup
    /// de Stockfish remplace celui de Maia (toujours actif — un humain qui
    /// gagne ne répète pas trois fois, quel que soit son niveau).
    var avoidsRepetitionWhenWinning: Bool = true
}

/// Tout ce qui n'est pas le choix du coup : rythme, abandon, nulle, et la
/// façon dont le personnage change quand la partie tourne.
struct Temperament: Hashable, Sendable {
    /// Multiplie le délai de rythme humain (0,5 = joue vite, 1,5 = lent).
    var pace: Double = 1.0
    /// Score (centipions, point de vue du personnage) sous lequel, tenu
    /// `resignPatience` coups d'affilée, il abandonne.
    var resignThresholdCp: Int = -800
    var resignPatience: Int = 3
    var offersDraws: Bool = true
    /// Il propose nulle quand le score reste dans ±cette valeur en finale.
    var drawOfferMaxCp: Int = 30
    /// Température quand il mène nettement (≥ +200) ou perd nettement
    /// (≤ −200) ; `nil` = inchangée.
    var temperatureWhenWinning: Double?
    var temperatureWhenLosing: Double?
    /// Poids de style ajoutés quand il mène ou quand il perd.
    var styleWhenWinning: [StyleTrait: Double] = [:]
    var styleWhenLosing: [StyleTrait: Double] = [:]

    static let winningThresholdCp = 200
}

/// Couleur d'identité d'un personnage : celle du disque de son
/// illustration, résolue par la vue.
enum OpponentTint: String, Hashable, Sendable {
    case maiaBlue, red, deepBlue, green, purple, orange, cyan, slate, yellow
}

/// Un adversaire du mode Jouer : un caractère posé sur Maia-3.
///
/// Le NIVEAU n'est pas ici : c'est le curseur de la partie
/// (`PlayGameSettings.eloSliderValue`), mémorisé par personnage
/// (``OpponentLevelStore``). Ce qui est ici ne change pas d'une partie à
/// l'autre : l'identité, la constance (température), le style, le
/// tempérament, le filet, le répertoire.
struct OpponentProfile: Identifiable, Hashable, Sendable {
    let id: String
    /// Prénom, jamais traduit.
    let firstName: String
    /// Surnom, clé de localisation (« Béton » → « Concrete »).
    let nickname: String
    /// Une phrase, clé de localisation.
    let tagline: String
    /// Deux ou trois étiquettes de style, clés de localisation.
    let tags: [String]
    /// Nom de l'illustration dans le catalogue d'images.
    let avatar: String
    let tint: OpponentTint
    /// Température de tirage : 0 = le coup le plus probable, 1 = fidèle aux
    /// humains, au-delà = plus erratique.
    let temperature: Double
    /// Seuil de nucleus (1 = désactivé).
    let topP: Double
    /// Plage de niveaux où le personnage est crédible (indicatif, le
    /// curseur reste libre).
    let recommendedLevels: ClosedRange<Int>
    let safetyNet: SafetyNetPolicy
    let style: StyleProfile
    let temperament: Temperament
    /// Répertoire d'ouvertures dans `opponent_books.json` ; `nil` = le livre
    /// général de l'app.
    let bookID: String?

    var displayNickname: String { LocalizationController.string(nickname) }

    /// La plage du curseur pour ce personnage : sa plage crédible, et rien
    /// d'autre — un Pablo à 2 400 n'est plus Pablo. L'adaptation entre
    /// parties et la mémoire par personnage s'y bornent aussi.
    var levelRange: ClosedRange<Double> {
        Double(recommendedLevels.lowerBound)...Double(recommendedLevels.upperBound)
    }

    /// Ramène un niveau (mémorisé, venu d'une autre version…) dans la plage.
    func clampedLevel(_ level: Double) -> Double {
        min(levelRange.upperBound, max(levelRange.lowerBound, level))
    }

    /// Niveau par défaut : le milieu de la plage conseillée, arrondi à 50.
    var defaultLevel: Double {
        let middle = Double(recommendedLevels.lowerBound + recommendedLevels.upperBound) / 2
        return (middle / 50).rounded() * 50
    }

    // MARK: Galerie

    static let lea = OpponentProfile(
        id: "lea", firstName: "Lena", nickname: "Tornade",
        tagline: "Roque du côté opposé et pions lancés : votre roi est une adresse de livraison. Simplifie mal, même avec deux pions d'avance.",
        tags: ["Attaque", "Sacrifices", "Rapide"],
        avatar: "avatar_lea", tint: .red,
        temperature: 1.0, topP: 1.0, recommendedLevels: 1000...2400,
        safetyNet: SafetyNetPolicy(),
        style: StyleProfile(weights: [
            .check: 0.3, .capture: 0.15, .towardKing: 0.45, .pawnStorm: 0.5, .sacrifice: 0.35,
            .tension: 0.3, .equalTrade: -0.4, .queenTrade: -0.7,
        ], strength: 1.2),
        temperament: Temperament(pace: 0.8, resignThresholdCp: -1100, resignPatience: 4,
                                 styleWhenWinning: [.equalTrade: 0.2], styleWhenLosing: [.sacrifice: 0.3, .tension: 0.3]),
        bookID: "lea"
    )

    static let marc = OpponentProfile(
        id: "marc", firstName: "Nils", nickname: "Béton",
        tagline: "Système London, roque au coup 6, zéro faiblesse. Il maîtrise très bien la théorie et n'a pas perdu depuis des mois. Il dort bien.",
        tags: ["Solide", "Théorie", "Patient"],
        avatar: "avatar_marc", tint: .deepBlue,
        temperature: 0.8, topP: 1.0, recommendedLevels: 1000...2500,
        safetyNet: SafetyNetPolicy(),
        style: StyleProfile(weights: [
            .castle: 0.6, .development: 0.3, .weakPawn: -0.6, .tension: -0.4, .sacrifice: -0.8,
            .towardKing: -0.2, .pawnStorm: -0.3, .mobility: 0.15,
        ], strength: 1.0),
        temperament: Temperament(pace: 1.2, resignThresholdCp: -900, resignPatience: 3,
                                 drawOfferMaxCp: 40, temperatureWhenWinning: 0.7),
        bookID: "marc"
    )

    static let theo = OpponentProfile(
        id: "theo", firstName: "Milo", nickname: "Gambit",
        tagline: "Offre un pion au deuxième coup, un deuxième au troisième, et cherche le mat avant d'avoir développé sa dame. Ses finales ressemblent à des accidents.",
        tags: ["Gambits", "Initiative", "Finales fragiles"],
        avatar: "avatar_theo", tint: .green,
        temperature: 1.1, topP: 1.0, recommendedLevels: 800...1800,
        safetyNet: SafetyNetPolicy(mateFromLevel: 1400, endgameFromLevel: nil),
        style: StyleProfile(weights: [
            .sacrifice: 0.7, .check: 0.3, .towardKing: 0.4, .capture: 0.1, .materialGain: -0.3,
            .equalTrade: -0.5, .queenTrade: -0.8, .tension: 0.3,
        ], strength: 1.2),
        temperament: Temperament(pace: 0.6, resignThresholdCp: -1200, resignPatience: 4, offersDraws: false,
                                 temperatureWhenLosing: 1.3),
        bookID: "theo"
    )

    static let nadia = OpponentProfile(
        id: "nadia", firstName: "Nadia", nickname: "Finale",
        tagline: "Échange les dames au coup 12, propose nulle au coup 30 si c'est égal, et vous mate au coup 65 si ce ne l'est pas. Aucune fantaisie.",
        tags: ["Échanges", "Finales", "Précise"],
        avatar: "avatar_nadia", tint: .purple,
        temperature: 0.8, topP: 1.0, recommendedLevels: 1400...2500,
        safetyNet: SafetyNetPolicy(mateFromLevel: 1400, endgameFromLevel: 1000, endgamePieceLimit: 9),
        style: StyleProfile(weights: [
            .equalTrade: 0.6, .queenTrade: 0.8, .castle: 0.4, .weakPawn: -0.4, .sacrifice: -0.7,
            .tension: -0.3, .development: 0.2,
        ], strength: 1.1),
        temperament: Temperament(pace: 1.4, resignThresholdCp: -600, resignPatience: 3,
                                 drawOfferMaxCp: 50, temperatureWhenWinning: 0.6),
        bookID: "nadia"
    )

    static let sacha = OpponentProfile(
        id: "sacha", firstName: "Sacha", nickname: "Traquenard",
        tagline: "Ses coups ont l'air faux. La moitié le sont vraiment, l'autre moitié coûte une pièce à qui le croit. Tombe lui-même dans les pièges des autres, par principe.",
        tags: ["Pièges", "Tactique", "Imprévisible"],
        avatar: "avatar_sacha", tint: .orange,
        temperature: 1.2, topP: 1.0, recommendedLevels: 800...1600,
        safetyNet: SafetyNetPolicy(mateFromLevel: 1200),
        style: StyleProfile(weights: [
            .tension: 0.8, .sacrifice: 0.4, .check: 0.35, .towardKing: 0.3, .weakPawn: 0.15,
            .castle: -0.3, .equalTrade: -0.3,
        ], strength: 1.1),
        temperament: Temperament(pace: 0.7, resignThresholdCp: -1000, resignPatience: 3, temperatureWhenLosing: 1.4),
        bookID: "sacha"
    )

    static let ines = OpponentProfile(
        id: "ines", firstName: "Ana", nickname: "Ressort",
        tagline: "Laisse venir, encaisse, sourit. Plus vous attaquez, plus elle est dangereuse ; sa meilleure position est légèrement inférieure.",
        tags: ["Défense", "Contre-attaque", "Sang-froid"],
        avatar: "avatar_ines", tint: .cyan,
        temperature: 0.9, topP: 1.0, recommendedLevels: 1200...2400,
        safetyNet: SafetyNetPolicy(),
        style: StyleProfile(weights: [
            .castle: 0.4, .development: 0.3, .weakPawn: -0.3, .tension: 0.3, .sacrifice: -0.3,
        ], strength: 0.9),
        temperament: Temperament(pace: 1.0, resignThresholdCp: -900, resignPatience: 4,
                                 temperatureWhenLosing: 0.8,
                                 styleWhenWinning: [.equalTrade: 0.3],
                                 styleWhenLosing: [.towardKing: 0.5, .check: 0.3, .tension: 0.4, .sacrifice: 0.5]),
        bookID: "ines"
    )

    static let yuri = OpponentProfile(
        id: "yuri", firstName: "Yuri", nickname: "Grippe-sou",
        tagline: "Un pion offert est un pion pris. Il accepte tous les gambits, défend pendant quarante coups sans se plaindre, puis vous rappelle qu'il a un pion de plus.",
        tags: ["Matériel", "Défense", "Tenace"],
        avatar: "avatar_yuri", tint: .slate,
        temperature: 0.9, topP: 1.0, recommendedLevels: 1000...2200,
        safetyNet: SafetyNetPolicy(),
        style: StyleProfile(weights: [
            .materialGain: 0.9, .capture: 0.3, .sacrifice: -1.0, .towardKing: -0.3, .pawnStorm: -0.3,
            .tension: -0.2, .equalTrade: 0.2,
        ], strength: 1.2),
        temperament: Temperament(pace: 1.1, resignThresholdCp: -700, resignPatience: 3, temperatureWhenWinning: 0.7),
        bookID: "yuri"
    )

    static let pablo = OpponentProfile(
        id: "pablo", firstName: "Pablo", nickname: "Yolo",
        tagline: "Brillant au coup 15, en prise au coup 16. Joue vite, attaque tout, oublie son roi. Le débutant humain que Stockfish ne sait pas imiter.",
        tags: ["Impulsif", "Attaque", "Gaffes"],
        avatar: "avatar_pablo", tint: .yellow,
        temperature: 1.5, topP: 1.0, recommendedLevels: 800...1400,
        safetyNet: SafetyNetPolicy(mateFromLevel: 1400, endgameFromLevel: nil),
        style: StyleProfile(weights: [
            .check: 0.4, .capture: 0.3, .towardKing: 0.3, .castle: -0.4, .development: -0.1,
        ], strength: 0.6),
        temperament: Temperament(pace: 0.4, resignThresholdCp: -1500, resignPatience: 5, offersDraws: false),
        bookID: "pablo"
    )

    /// L'étalon : le réseau Maia-3 tel quel, température 1, sans trait.
    /// Sert de référence au calibrage et de vitrine à l'humanité brute du
    /// modèle. En tête de la galerie, sous son propre nom.
    static let maia = OpponentProfile(
        id: "maia", firstName: "Maia", nickname: "Neutre",
        tagline: "Le modèle Maia-3 tel quel, sans aucune adaptation : joue comme un humain de ce niveau, sans style particulier.",
        tags: ["Maia-3", "Sans adaptation", "Étalon"],
        avatar: "avatar_maia", tint: .maiaBlue,
        temperature: 1.0, topP: 1.0, recommendedLevels: 800...2500,
        safetyNet: SafetyNetPolicy(),
        style: .none,
        temperament: Temperament(),
        bookID: nil
    )

    /// L'ordre de la galerie : Maia d'abord, puis les caractères.
    static let all: [OpponentProfile] = [.maia, .lea, .marc, .theo, .nadia, .sacha, .ines, .yuri, .pablo]

    static func named(_ id: String) -> OpponentProfile? {
        all.first { $0.id == id }
    }
}
