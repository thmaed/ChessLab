package com.chesslab.maia

/**
 * Les neuf personnages, GÉNÉRÉS depuis `ChessLab/Maia/OpponentProfile.swift`
 * par `tools/maia-profiles/generate_profiles.py` — ne pas éditer à la main.
 *
 * Ce sont des données : neuf profils, une dizaine de poids de style chacun,
 * et un tempérament. Les recopier garantirait une divergence silencieuse le
 * jour où un poids change côté iOS.
 */
object OpponentGallery {

    val lea = OpponentProfile(
        id = "lea",
        firstName = "Lena",
        nickname = "Tornade",
        tagline = "Roque du côté opposé et pions lancés : votre roi est une adresse de livraison. Simplifie mal, même avec deux pions d'avance.",
        tags = listOf("Attaque", "Sacrifices", "Rapide"),
        tint = OpponentTint.red,
        temperature = 1.0,
        topP = 1.0,
        recommendedLevels = 1000..2400,
        safetyNet = SafetyNetPolicy(),
        style = StyleProfile(mapOf(StyleTrait.check to 0.3, StyleTrait.capture to 0.15, StyleTrait.towardKing to 0.45, StyleTrait.pawnStorm to 0.5, StyleTrait.sacrifice to 0.35, StyleTrait.tension to 0.3, StyleTrait.equalTrade to -0.4, StyleTrait.queenTrade to -0.7), strength = 1.2),
        temperament = Temperament(pace = 0.8, resignThresholdCp = -1100, resignPatience = 4, styleWhenWinning = mapOf(StyleTrait.equalTrade to 0.2), styleWhenLosing = mapOf(StyleTrait.sacrifice to 0.3, StyleTrait.tension to 0.3)),
        bookId = "lea",
    )

    val marc = OpponentProfile(
        id = "marc",
        firstName = "Nils",
        nickname = "Béton",
        tagline = "Système London, roque au coup 6, zéro faiblesse. Il maîtrise très bien la théorie et n'a pas perdu depuis des mois. Il dort bien.",
        tags = listOf("Solide", "Théorie", "Patient"),
        tint = OpponentTint.deepBlue,
        temperature = 0.8,
        topP = 1.0,
        recommendedLevels = 1000..2500,
        safetyNet = SafetyNetPolicy(),
        style = StyleProfile(mapOf(StyleTrait.castle to 0.6, StyleTrait.development to 0.3, StyleTrait.weakPawn to -0.6, StyleTrait.tension to -0.4, StyleTrait.sacrifice to -0.8, StyleTrait.towardKing to -0.2, StyleTrait.pawnStorm to -0.3, StyleTrait.mobility to 0.15), strength = 1.0),
        temperament = Temperament(pace = 1.2, resignThresholdCp = -900, resignPatience = 3, drawOfferMaxCp = 40, temperatureWhenWinning = 0.7),
        bookId = "marc",
    )

    val theo = OpponentProfile(
        id = "theo",
        firstName = "Milo",
        nickname = "Gambit",
        tagline = "Offre un pion au deuxième coup, un deuxième au troisième, et cherche le mat avant d'avoir développé sa dame. Ses finales ressemblent à des accidents.",
        tags = listOf("Gambits", "Initiative", "Finales fragiles"),
        tint = OpponentTint.green,
        temperature = 1.1,
        topP = 1.0,
        recommendedLevels = 800..1800,
        safetyNet = SafetyNetPolicy(mateFromLevel = 1400, endgameFromLevel = null),
        style = StyleProfile(mapOf(StyleTrait.sacrifice to 0.7, StyleTrait.check to 0.3, StyleTrait.towardKing to 0.4, StyleTrait.capture to 0.1, StyleTrait.materialGain to -0.3, StyleTrait.equalTrade to -0.5, StyleTrait.queenTrade to -0.8, StyleTrait.tension to 0.3), strength = 1.2),
        temperament = Temperament(pace = 0.6, resignThresholdCp = -1200, resignPatience = 4, offersDraws = false, temperatureWhenLosing = 1.3),
        bookId = "theo",
    )

    val nadia = OpponentProfile(
        id = "nadia",
        firstName = "Nadia",
        nickname = "Finale",
        tagline = "Échange les dames au coup 12, propose nulle au coup 30 si c'est égal, et vous mate au coup 65 si ce ne l'est pas. Aucune fantaisie.",
        tags = listOf("Échanges", "Finales", "Précise"),
        tint = OpponentTint.purple,
        temperature = 0.8,
        topP = 1.0,
        recommendedLevels = 1400..2500,
        safetyNet = SafetyNetPolicy(mateFromLevel = 1400, endgameFromLevel = 1000, endgamePieceLimit = 9),
        style = StyleProfile(mapOf(StyleTrait.equalTrade to 0.6, StyleTrait.queenTrade to 0.8, StyleTrait.castle to 0.4, StyleTrait.weakPawn to -0.4, StyleTrait.sacrifice to -0.7, StyleTrait.tension to -0.3, StyleTrait.development to 0.2), strength = 1.1),
        temperament = Temperament(pace = 1.4, resignThresholdCp = -600, resignPatience = 3, drawOfferMaxCp = 50, temperatureWhenWinning = 0.6),
        bookId = "nadia",
    )

    val sacha = OpponentProfile(
        id = "sacha",
        firstName = "Sacha",
        nickname = "Traquenard",
        tagline = "Ses coups ont l'air faux. La moitié le sont vraiment, l'autre moitié coûte une pièce à qui le croit. Tombe lui-même dans les pièges des autres, par principe.",
        tags = listOf("Pièges", "Tactique", "Imprévisible"),
        tint = OpponentTint.orange,
        temperature = 1.2,
        topP = 1.0,
        recommendedLevels = 800..1600,
        safetyNet = SafetyNetPolicy(mateFromLevel = 1200),
        style = StyleProfile(mapOf(StyleTrait.tension to 0.8, StyleTrait.sacrifice to 0.4, StyleTrait.check to 0.35, StyleTrait.towardKing to 0.3, StyleTrait.weakPawn to 0.15, StyleTrait.castle to -0.3, StyleTrait.equalTrade to -0.3), strength = 1.1),
        temperament = Temperament(pace = 0.7, resignThresholdCp = -1000, resignPatience = 3, temperatureWhenLosing = 1.4),
        bookId = "sacha",
    )

    val ines = OpponentProfile(
        id = "ines",
        firstName = "Ana",
        nickname = "Ressort",
        tagline = "Laisse venir, encaisse, sourit. Plus vous attaquez, plus elle est dangereuse ; sa meilleure position est légèrement inférieure.",
        tags = listOf("Défense", "Contre-attaque", "Sang-froid"),
        tint = OpponentTint.cyan,
        temperature = 0.9,
        topP = 1.0,
        recommendedLevels = 1200..2400,
        safetyNet = SafetyNetPolicy(),
        style = StyleProfile(mapOf(StyleTrait.castle to 0.4, StyleTrait.development to 0.3, StyleTrait.weakPawn to -0.3, StyleTrait.tension to 0.3, StyleTrait.sacrifice to -0.3), strength = 0.9),
        temperament = Temperament(pace = 1.0, resignThresholdCp = -900, resignPatience = 4, temperatureWhenLosing = 0.8, styleWhenWinning = mapOf(StyleTrait.equalTrade to 0.3), styleWhenLosing = mapOf(StyleTrait.towardKing to 0.5, StyleTrait.check to 0.3, StyleTrait.tension to 0.4, StyleTrait.sacrifice to 0.5)),
        bookId = "ines",
    )

    val yuri = OpponentProfile(
        id = "yuri",
        firstName = "Yuri",
        nickname = "Grippe-sou",
        tagline = "Un pion offert est un pion pris. Il accepte tous les gambits, défend pendant quarante coups sans se plaindre, puis vous rappelle qu'il a un pion de plus.",
        tags = listOf("Matériel", "Défense", "Tenace"),
        tint = OpponentTint.slate,
        temperature = 0.9,
        topP = 1.0,
        recommendedLevels = 1000..2200,
        safetyNet = SafetyNetPolicy(),
        style = StyleProfile(mapOf(StyleTrait.materialGain to 0.9, StyleTrait.capture to 0.3, StyleTrait.sacrifice to -1.0, StyleTrait.towardKing to -0.3, StyleTrait.pawnStorm to -0.3, StyleTrait.tension to -0.2, StyleTrait.equalTrade to 0.2), strength = 1.2),
        temperament = Temperament(pace = 1.1, resignThresholdCp = -700, resignPatience = 3, temperatureWhenWinning = 0.7),
        bookId = "yuri",
    )

    val pablo = OpponentProfile(
        id = "pablo",
        firstName = "Pablo",
        nickname = "Yolo",
        tagline = "Brillant au coup 15, en prise au coup 16. Joue vite, attaque tout, oublie son roi. Le débutant humain que Stockfish ne sait pas imiter.",
        tags = listOf("Impulsif", "Attaque", "Gaffes"),
        tint = OpponentTint.yellow,
        temperature = 1.5,
        topP = 1.0,
        recommendedLevels = 800..1400,
        safetyNet = SafetyNetPolicy(mateFromLevel = 1400, endgameFromLevel = null),
        style = StyleProfile(mapOf(StyleTrait.check to 0.4, StyleTrait.capture to 0.3, StyleTrait.towardKing to 0.3, StyleTrait.castle to -0.4, StyleTrait.development to -0.1), strength = 0.6),
        temperament = Temperament(pace = 0.4, resignThresholdCp = -1500, resignPatience = 5, offersDraws = false),
        bookId = "pablo",
    )

    val maia = OpponentProfile(
        id = "maia",
        firstName = "Maia",
        nickname = "Neutre",
        tagline = "Le modèle Maia-3 tel quel, sans aucune adaptation : joue comme un humain de ce niveau, sans style particulier.",
        tags = listOf("Maia-3", "Sans adaptation", "Étalon"),
        tint = OpponentTint.maiaBlue,
        temperature = 1.0,
        topP = 1.0,
        recommendedLevels = 800..2500,
        safetyNet = SafetyNetPolicy(),
        style = StyleProfile(mapOf(), strength = 0.0),
        temperament = Temperament(),
        bookId = null,
    )

    /** Dans l'ordre de la galerie iOS. */
    val all = listOf(lea, marc, theo, nadia, sacha, ines, yuri, pablo, maia)

    fun byId(id: String): OpponentProfile? = all.firstOrNull { it.id == id }
}
