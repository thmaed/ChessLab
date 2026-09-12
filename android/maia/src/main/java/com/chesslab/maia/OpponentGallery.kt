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
        nicknameRes = R.string.opponent_lea_nickname,
        taglineRes = R.string.opponent_lea_tagline,
        tagRes = listOf(R.string.opponent_lea_tag1, R.string.opponent_lea_tag2, R.string.opponent_lea_tag3),
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
        nicknameRes = R.string.opponent_marc_nickname,
        taglineRes = R.string.opponent_marc_tagline,
        tagRes = listOf(R.string.opponent_marc_tag1, R.string.opponent_marc_tag2, R.string.opponent_marc_tag3),
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
        nicknameRes = R.string.opponent_theo_nickname,
        taglineRes = R.string.opponent_theo_tagline,
        tagRes = listOf(R.string.opponent_theo_tag1, R.string.opponent_theo_tag2, R.string.opponent_theo_tag3),
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
        nicknameRes = R.string.opponent_nadia_nickname,
        taglineRes = R.string.opponent_nadia_tagline,
        tagRes = listOf(R.string.opponent_nadia_tag1, R.string.opponent_nadia_tag2, R.string.opponent_nadia_tag3),
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
        nicknameRes = R.string.opponent_sacha_nickname,
        taglineRes = R.string.opponent_sacha_tagline,
        tagRes = listOf(R.string.opponent_sacha_tag1, R.string.opponent_sacha_tag2, R.string.opponent_sacha_tag3),
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
        nicknameRes = R.string.opponent_ines_nickname,
        taglineRes = R.string.opponent_ines_tagline,
        tagRes = listOf(R.string.opponent_ines_tag1, R.string.opponent_ines_tag2, R.string.opponent_ines_tag3),
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
        nicknameRes = R.string.opponent_yuri_nickname,
        taglineRes = R.string.opponent_yuri_tagline,
        tagRes = listOf(R.string.opponent_yuri_tag1, R.string.opponent_yuri_tag2, R.string.opponent_yuri_tag3),
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
        nicknameRes = R.string.opponent_pablo_nickname,
        taglineRes = R.string.opponent_pablo_tagline,
        tagRes = listOf(R.string.opponent_pablo_tag1, R.string.opponent_pablo_tag2, R.string.opponent_pablo_tag3),
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
        nicknameRes = R.string.opponent_maia_nickname,
        taglineRes = R.string.opponent_maia_tagline,
        tagRes = listOf(R.string.opponent_maia_tag1, R.string.opponent_maia_tag2, R.string.opponent_maia_tag3),
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
    val all = listOf(maia, lea, marc, theo, nadia, sacha, ines, yuri, pablo)

    fun byId(id: String): OpponentProfile? = all.firstOrNull { it.id == id }
}
