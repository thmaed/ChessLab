import Testing
@testable import ChessLab

/// Le score de précision, et **ce qui ne doit plus le gonfler**.
///
/// Signalé en usage le 14/08/2026 : « j'arrive régulièrement à 92-94 % alors
/// que je devrais être autour de 80 % », puis « les coups de fin de partie ont
/// aussi tendance à augmenter artificiellement le score ».
///
/// Ces tests n'ont besoin d'AUCUN moteur : ils portent sur l'agrégation, seule
/// pièce que le chantier modifie. Les pertes sont données à la main, ce qui
/// rend chaque chiffre reproductible à la calculette — c'est précisément ce
/// qui manquait pour trancher.
///
/// - important: la courbe de probabilité de gain est **dérivée des pertes**,
/// jamais inventée à côté. Un premier jeu d'essai les avait découplées : la
/// pondération de volatilité n'avait alors rien à mesurer, et les tests
/// « passaient » sans rien prouver. Une gaffe DOIT se voir dans la courbe,
/// c'est même la définition d'une gaffe.
struct AccuracyScoreTests {

    /// Profil d'une partie de club : une gaffe, deux erreurs, trois
    /// imprécisions, le reste sain.
    private static func clubGameLosses(quietMoves: Int = 34) -> [Double] {
        [25] + [12, 12] + [7, 7, 7] + Array(repeating: 1, count: quietMoves)
    }

    /// Courbe de probabilité de gain POV joueur, **cohérente** avec les
    /// pertes : chaque perte y creuse un trou de sa taille, après quoi
    /// l'adversaire rend une partie du terrain — sans cette restitution, une
    /// partie de soixante coups collerait au plancher et la volatilité
    /// s'éteindrait pour de mauvaises raisons.
    private static func curve(losses: [Double], from start: Double = 50) -> [Double] {
        var current = start
        var series = [current]
        for loss in losses {
            current = min(97, max(3, current - loss))
            series.append(current)
            current = min(97, max(3, current + loss * 0.8 + 1))
        }
        return series
    }

    /// Traîne de fin de partie : position pliée, l'aiguille ne bouge plus.
    private static func deadWonTail(_ length: Int) -> [Double] {
        Array(repeating: 99, count: length)
    }

    private static func score(losses: [Double], curve: [Double]) throws -> Double {
        let weights = AccuracyScore.moveWeights(whiteWinPercents: curve)
        return try #require(AccuracyScore.accuracy(winPercentLosses: losses, weights: weights))
    }

    // MARK: La courbe — inchangée

    @Test func aFlawlessGameScoresFullMarks() {
        #expect(AccuracyScore.accuracy(averageWinPercentLoss: 0) == 100)
    }

    @Test func theBiggerTheLossTheLowerTheScore() {
        let small = AccuracyScore.accuracy(averageWinPercentLoss: 2)
        let large = AccuracyScore.accuracy(averageWinPercentLoss: 20)
        #expect(small > large)
        #expect(large >= 0 && small <= 100)
    }

    // MARK: Le poids d'un coup

    /// Une partie pliée pèse **vingt fois moins** qu'une partie ouverte : un
    /// coup y est calme ET n'engage plus rien. C'est tout le mécanisme.
    @Test func aFrozenWonPositionWeighsFarLessThanALivelyOne() {
        let dead = AccuracyScore.moveWeights(whiteWinPercents: [99] + Self.deadWonTail(20))
        let alive = AccuracyScore.moveWeights(
            whiteWinPercents: Self.curve(losses: Self.clubGameLosses(quietMoves: 14))
        )

        #expect(
            dead.allSatisfy { $0 == AccuracyScore.decidedStake },
            "une partie pliée doit tomber au coefficient d'enjeu, pas seulement au calme"
        )
        #expect(
            alive.reduce(0, +) > dead.reduce(0, +) * 10,
            "vivant \(alive.reduce(0, +)) / mort \(dead.reduce(0, +))"
        )
    }

    /// Une position ENCORE ouverte garde un poids plein même quand elle est
    /// calme : c'est ce qui évite que le score ne note que les pires moments.
    @Test func aQuietButOpenPositionKeepsFullWeight() {
        let calmAndOpen = Array(repeating: 52.0, count: 12)
        for weight in AccuracyScore.moveWeights(whiteWinPercents: calmAndOpen) {
            #expect(weight == 1, "un coup tranquille dans une partie ouverte compte pour un")
        }
    }

    /// Le coup qui FAIT basculer la partie compte plein : il était décisif,
    /// même si la position d'arrivée, elle, ne l'est plus.
    @Test func theMoveThatDecidesTheGameStillCountsFully() {
        let breakthrough = [50.0, 95.0, 96.0]
        let weights = AccuracyScore.moveWeights(whiteWinPercents: breakthrough)
        #expect(weights[0] > AccuracyScore.decidedStake, "poids \(weights[0])")
        #expect(weights[1] == AccuracyScore.decidedStake, "le coup SUIVANT, lui, n'engage plus rien")
    }

    @Test func weightsStayWithinTheirBounds() {
        let brutal = [0.0, 100.0, 0.0, 100.0, 0.0, 100.0, 0.0, 100.0]
        for weight in AccuracyScore.moveWeights(whiteWinPercents: brutal) {
            #expect(weight >= AccuracyScore.decidedStake && weight <= 3)
        }
    }

    @Test func aGameWithoutMovesHasNoWeights() {
        #expect(AccuracyScore.moveWeights(whiteWinPercents: [50]).isEmpty)
        #expect(AccuracyScore.moveWeights(whiteWinPercents: []).isEmpty)
    }

    // MARK: Le symptôme rapporté

    /// **Le cœur du rapport.** Vingt coups de finition dans une position déjà
    /// gagnée ne doivent plus faire monter le score.
    ///
    /// Chiffres de l'ancienne méthode (moyenne simple, puis courbe) :
    /// 40 coups → 89,0 % ; les mêmes 40 coups suivis de 20 coups morts →
    /// **92,5 %**. Rien n'a été mieux joué : le dénominateur a grossi de vingt
    /// coups qui ne pouvaient rien perdre.
    @Test func aDeadWonEndgameNoLongerInflatesTheScore() throws {
        let losses = Self.clubGameLosses()
        let withoutTail = try Self.score(losses: losses, curve: Self.curve(losses: losses))

        let tailLength = 20
        let withTail = try Self.score(
            losses: losses + Array(repeating: 0, count: tailLength),
            curve: Self.curve(losses: losses) + Self.deadWonTail(tailLength)
        )

        print(String(format: "ACCURACY|sans traîne=%.2f|avec traîne=%.2f", withoutTail, withTail))
        #expect(
            withTail - withoutTail < 1,
            "la traîne de fin de partie gonfle encore le score : \(withoutTail) → \(withTail)"
        )
    }

    /// Et le score de cette partie doit tomber **nettement** sous les 92,5 %
    /// que rendait l'ancienne méthode — c'est le chiffre exact que
    /// l'utilisateur trouvait trop généreux.
    @Test func aClubGameWithABlunderScoresWellBelowTheOldMethod() throws {
        let losses = Self.clubGameLosses() + Array(repeating: 0.0, count: 20)
        let curve = Self.curve(losses: Self.clubGameLosses()) + Self.deadWonTail(20)
        let score = try Self.score(losses: losses, curve: curve)

        print(String(format: "ACCURACY|partie de club=%.2f (ancienne méthode : 92,50)", score))
        #expect(score < 89, "une partie avec une gaffe et deux erreurs ne peut pas valoir \(score) %")
    }

    /// La pondération doit **empêcher qu'une gaffe soit noyée**. Même perte
    /// totale, même longueur : celle qui la concentre en un coup doit être
    /// moins bien notée, parce qu'une gaffe fait bouger la courbe — donc pèse.
    ///
    /// L'ancienne moyenne simple ne pouvait PAS les distinguer : même somme,
    /// même nombre de coups, même score au point près.
    @Test func oneBlunderHurtsMoreThanTheSameLossSpreadOut() throws {
        let concentrated = [40.0] + Array(repeating: 0.0, count: 39)
        let spread = Array(repeating: 1.0, count: 40)

        let concentratedScore = try Self.score(losses: concentrated, curve: Self.curve(losses: concentrated))
        let spreadScore = try Self.score(losses: spread, curve: Self.curve(losses: spread))

        print(String(format: "ACCURACY|gaffe unique=%.2f|perte étalée=%.2f", concentratedScore, spreadScore))
        #expect(
            concentratedScore < spreadScore,
            "une gaffe unique (\(concentratedScore)) doit coûter plus cher que la même perte étalée (\(spreadScore))"
        )
        // L'ancienne méthode donnait EXACTEMENT le même score aux deux.
        let oldMethod = AccuracyScore.accuracy(averageWinPercentLoss: 1)
        #expect(abs(oldMethod - 95.6) < 0.1, "témoin de l'ancienne méthode")
    }

    // MARK: Bornes

    /// Une partie sans le moindre relâchement vaut toujours 100.
    @Test func aPerfectGameStillScoresOneHundred() throws {
        let losses = Array(repeating: 0.0, count: 30)
        let score = try Self.score(losses: losses, curve: Self.curve(losses: losses))
        #expect(score == 100)
    }

    /// Une partie entièrement catastrophique reste dans les bornes.
    @Test func aCatastrophicGameStaysInRange() throws {
        let losses = Array(repeating: 40.0, count: 20)
        let score = try Self.score(losses: losses, curve: Self.curve(losses: losses))
        #expect(score >= 0 && score < 25, "score \(score)")
    }

    @Test func mismatchedInputsYieldNoScore() {
        #expect(AccuracyScore.accuracy(winPercentLosses: [], weights: []) == nil)
        #expect(AccuracyScore.accuracy(winPercentLosses: [5], weights: []) == nil)
    }
}
