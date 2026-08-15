import CoreGraphics
import Foundation

/// Recalage de la grille 8×8 sur une image de plateau **déjà redressée**.
///
/// Raison d'être (défaut réel, trouvé en jouant le parcours complet) : la
/// détection automatique de Vision rend un quadrilatère **~3 % trop grand**
/// sur une capture pourtant parfaite. Après redressement, le plateau se
/// retrouve donc réduit et décalé d'environ 14 px dans une image de 800 —
/// soit ~0,14 case. Découper en huitièmes exacts fait alors mordre chaque
/// vignette sur sa voisine, et le template matching s'effondre : sur la
/// Sicilienne, il ne restait QUE les pions (petits et centrés, ils gardent du
/// jeu), les 24 autres pièces passaient à la trappe. Aucun cadrage manuel ne
/// sera jamais meilleur, et une vraie photo fera pire.
///
/// La correction : l'image redressée porte elle-même la vérité — les lignes du
/// damier. On retrouve leur **pas** et leur **phase**, et l'on découpe
/// là-dessus plutôt que sur une hypothèse.
///
/// Pur et sans état : testable directement.
enum BoardGridFinder {

    /// Bornes des 9 lignes de la grille, en pixels de l'image redressée.
    struct Grid: Equatable {
        /// 9 abscisses, de la bordure gauche à la droite.
        var columns: [Double]
        /// 9 ordonnées, du haut vers le bas.
        var rows: [Double]

        /// Grille naïve : huit parts égales. Le repli quand le recalage
        /// n'inspire pas confiance.
        static func uniform(width: Int, height: Int) -> Grid {
            Grid(
                columns: (0...8).map { Double($0) * Double(width) / 8 },
                rows: (0...8).map { Double($0) * Double(height) / 8 }
            )
        }
    }

    /// Tolérance de recherche autour du pas théorique (`côté / 8`) : au-delà,
    /// ce n'est plus un recalage mais un cadrage à refaire à la main.
    private static let periodTolerance = 0.12
    /// Décalage exploré, en fraction du pas.
    private static let phaseTolerance = 0.30
    /// Combien des 9 lignes doivent tomber DANS l'image pour qu'une grille
    /// candidate soit jugeable.
    ///
    /// Sept, et pas neuf : sur une capture cadrée au plus juste, le plateau
    /// commence AVANT l'image et finit APRÈS — les deux lignes extrêmes sont
    /// hors champ, et exiger qu'elles y soient revenait à interdire la bonne
    /// réponse (voir ``lines(from:scale:)``). Sept lignes équidistantes
    /// alignées sur des crêtes ne s'obtiennent pas par hasard.
    private static let minimumLinesInsideImage = 7

    /// Recale la grille sur les lignes du damier.
    ///
    /// - returns: la grille recalée, ou la grille uniforme si l'image ne
    ///   présente aucune structure périodique exploitable (plateau hors
    ///   cadre, photo floue) — on ne remplace jamais une hypothèse discutable
    ///   par une hypothèse pire.
    static func grid(in image: CGImage) -> Grid {
        let width = image.width
        let height = image.height
        let side = min(width, height, maximumAnalysisSide)
        guard side >= 64, let luminance = ImagePatch.grayscale(of: image, side: side)
        else { return .uniform(width: width, height: height) }

        let vertical = edgeProfile(luminance, side: side, alongColumns: true)
        let horizontal = edgeProfile(luminance, side: side, alongColumns: false)

        let uniform = Grid.uniform(width: width, height: height)
        let columns = lines(from: vertical, scale: Double(width) / Double(side))
        let rows = lines(from: horizontal, scale: Double(height) / Double(side))

        // Bornage : une grille qui déborde ferait rogner la découpe en
        // silence (`CGImage.cropping` rend l'intersection, sans rien dire) —
        // les vignettes des bords sortiraient plus petites ET décalées.
        return Grid(
            columns: clamped(columns ?? uniform.columns, to: width),
            rows: clamped(rows ?? uniform.rows, to: height)
        )
    }

    private static func clamped(_ lines: [Double], to size: Int) -> [Double] {
        lines.map { min(max($0, 0), Double(size)) }
    }

    /// L'analyse se fait à la résolution de l'image redressée (800 px), SANS
    /// la réduire.
    ///
    /// Une réduction paraissait gratuite — les lignes du damier sont des
    /// structures à basse fréquence. Elle introduisait en réalité un décalage
    /// d'un demi-pixel entre les deux grilles de pixels, soit 2,5 px une fois
    /// remis à l'échelle : de quoi désaxer chaque vignette et faire chuter la
    /// reconnaissance sur un plateau pourtant parfaitement cadré. Le plafond
    /// ne sert qu'à borner le coût d'une image inhabituellement grande.
    private static let maximumAnalysisSide = 1024

    // MARK: Profil de contours

    /// Force des contours le long d'une direction, mesurée par la **médiane**
    /// des gradients — pas leur moyenne.
    ///
    /// C'est la médiane qui fait tout le travail : une ligne du damier
    /// traverse l'image de part en part, donc la MOITIÉ AU MOINS des pixels de
    /// sa colonne portent une transition ; le bord d'une dame, lui, n'en
    /// touche qu'une poignée. Une moyenne les met sur le même plan, et les
    /// glyphes tirent la grille de côté (défaut mesuré : les rangées
    /// ressortaient décalées de 2,5 px, les colonnes — moins encombrées —
    /// tombaient juste).
    ///
    /// - parameter alongColumns: `true` pour un profil en x (lignes
    ///   verticales), `false` pour un profil en y.
    /// - note: **Les deux lignes extrêmes du profil restent à zéro**, et c'est
    ///   assumé après mesure (Lot 5.2 de `PROMPT-bugs.md`). La boucle va de 1 à
    ///   `side-2` : le score d'une grille somme 9 lignes dont les deux extrêmes
    ///   ne contribuent donc rien, et le couple (pas, phase) se choisit sur 7
    ///   lignes intérieures. Le diagnostic est exact — mais calculer une
    ///   dérivée décentrée aux bords a été essayé et **n'a rien changé** :
    ///   écarts identiques au centième près sur les trois cadrages mesurés
    ///   (parfait 0,00 ; large 1,71 ; serré 6,00 en colonnes et 14,52 en
    ///   lignes). Le correctif a donc été retiré : on ne remue pas un
    ///   algorithme calibré « au pixel près » pour un gain nul.
    ///
    ///   L'erreur du cadrage serré venait bien d'ailleurs, et elle est traitée
    ///   depuis le 15/08/2026 — mais pas ici : c'était le GARDE de
    ///   ``lines(from:scale:)``, qui interdisait à une grille de déborder de
    ///   l'image et mettait donc la bonne réponse hors concours. Voir
    ///   ``BoardGridEdgeBiasTests``, qui fige ces mesures.
    static func edgeProfile(_ luminance: [Double], side: Int, alongColumns: Bool) -> [Double] {
        var profile = [Double](repeating: 0, count: side)
        var gradients = [Double](repeating: 0, count: side)

        for index in 1..<(side - 1) {
            for other in 0..<side {
                let before = alongColumns
                    ? luminance[other * side + index - 1]
                    : luminance[(index - 1) * side + other]
                let after = alongColumns
                    ? luminance[other * side + index + 1]
                    : luminance[(index + 1) * side + other]
                gradients[other] = abs(after - before)
            }
            profile[index] = Sample.median(gradients)
        }
        return profile
    }

    // MARK: Recherche du pas et de la phase

    /// Cherche le couple (pas, phase) qui aligne 9 lignes équidistantes sur
    /// les crêtes du profil.
    ///
    /// Recherche exhaustive plutôt que détection de pics : un pic isolé se
    /// fait voler la vedette par le bord d'une dame, alors qu'une grille
    /// complète de 9 lignes ne peut s'aligner par hasard.
    ///
    /// ## Pourquoi la grille a le droit de déborder de l'image (15/08/2026)
    ///
    /// La version d'origine exigeait que les 9 lignes tiennent dans l'image :
    /// `phase >= -1` **et** `phase + period * 8 <= side + 1`. Sur une capture
    /// cadrée au plus juste, ces deux conditions sont **contradictoires**, et
    /// c'est là toute l'affaire du « cadrage serré » consigné dans
    /// `PROGRESS.md`.
    ///
    /// Le cas de référence (``BoardGridEdgeBiasTests``) : un plateau de 800 px
    /// rogné de 6 px sur chaque bord donne une image de 788 px dont la vraie
    /// grille a un pas de **100** et une phase de **−6**. Or `phase >= -1`
    /// impose `phase ≥ −1`, tandis que `phase + 800 <= 789` impose
    /// `phase ≤ −11`. Aucun pas de 100 n'était donc admissible : la recherche
    /// était rabattue sur `period ≤ 98,75`, soit 1,25 px d'erreur par case et
    /// une dizaine de pixels cumulés au bout de la grille. C'est exactement
    /// l'écart mesuré (6,00 en colonnes, 14,52 en lignes).
    ///
    /// **La bonne réponse n'était pas mal notée : elle était hors concours.**
    /// D'où le remplacement du garde par un simple quorum de lignes visibles.
    ///
    /// Le score reste une SOMME et non une moyenne, et c'est délibéré : une
    /// ligne hors champ rapporte zéro, donc déborder coûte des points. Passer
    /// à une moyenne rendrait le débordement gratuit, et une grille pourrait
    /// gagner en poussant dehors ses deux lignes les plus faibles.
    ///
    /// ## Et pourquoi la recherche s'affine ensuite (15/08/2026)
    ///
    /// Le garde levé, il restait **2,58 px** d'écart sur le cadrage serré, et
    /// cette fois c'était la **quantification** de la recherche : 25 pas
    /// couvrant ±12 % de `côté / 8` donnent une résolution de 0,985 px, et le
    /// vrai pas (100 pour un idéal de 98,5) tombe entre deux crans. L'erreur
    /// est petite par case, mais elle s'ACCUMULE sur sept cases.
    ///
    /// D'où deux passes d'affinage autour du meilleur couple, chacune divisant
    /// le pas par 12. Coût : trois grilles de 625 candidats au lieu d'une,
    /// c'est-à-dire ~17 000 interpolations là où le calcul du profil en fait
    /// déjà 600 000. Résolution finale sur le pas : 0,007 px.
    ///
    /// L'affinage part de l'optimum grossier et ne cherche QUE dans un cran
    /// autour de lui — il ne peut donc pas dériver vers un autre maximum,
    /// et la première passe reste seule juge de la bonne vallée.
    private static func lines(from profile: [Double], scale: Double) -> [Double]? {
        let side = Double(profile.count)
        let idealPeriod = side / 8

        // Passe grossière : toute la plage admissible.
        var periodRadius = idealPeriod * periodTolerance
        var phaseRadius = idealPeriod * phaseTolerance
        guard var best = search(
            profile, side: side, idealPeriod: idealPeriod,
            periodCenter: idealPeriod, periodRadius: periodRadius,
            phaseCenter: 0, phaseRadius: phaseRadius
        ) else { return nil }

        // Passes d'affinage : on rouvre la recherche sur UN cran de la passe
        // précédente, où se trouve forcément le vrai optimum si la passe
        // grossière a identifié la bonne vallée.
        for _ in 0..<refinementPasses {
            periodRadius /= Double(searchSteps)
            phaseRadius /= Double(searchSteps)
            guard let refined = search(
                profile, side: side, idealPeriod: idealPeriod,
                periodCenter: best.period, periodRadius: periodRadius,
                phaseCenter: best.phase, phaseRadius: phaseRadius
            ) else { break }
            // `refined` contient le couple courant (pas nul, phase nulle) :
            // le score ne peut donc que monter ou rester égal.
            best = refined
        }

        guard best.score > 0 else { return nil }
        return (0...8).map { (best.phase + Double($0) * best.period) * scale }
    }

    /// Le meilleur couple (pas, phase) d'une fenêtre de recherche.
    ///
    /// ## Les ex æquo se tranchent vers la grille la plus simple
    ///
    /// Une transition franche produit un plateau de **deux pixels** dans le
    /// profil : `edgeProfile` calcule `|L(x+1) − L(x−1)|`, si bien qu'un bord
    /// situé en `x` allume `x−1` **et** `x`. Toutes les phases du plateau
    /// marquent donc exactement le même score, et rien ne les départage.
    ///
    /// Tant que la recherche était grossière, cela ne se voyait pas. La passe
    /// d'affinage, elle, se pose n'importe où sur le plateau : mesuré, un
    /// plateau de 800 px parfaitement cadré ressortait décalé de 1,10 px, et
    /// ``BoardRectifier`` en tirait des vignettes de 97 px à un bout et 96 px à
    /// l'autre — alors que l'égalité de leurs tailles est un invariant.
    ///
    /// D'où la règle : **à score égal, on garde la grille la plus proche de
    /// l'hypothèse uniforme** (pas idéal, phase nulle). Quand l'image ne
    /// distingue pas deux grilles, on ne s'éloigne pas du découpage naïf sans
    /// raison — et quand elle les distingue, le score tranche seul, la
    /// simplicité n'entre jamais en jeu.
    private static func search(
        _ profile: [Double], side: Double, idealPeriod: Double,
        periodCenter: Double, periodRadius: Double,
        phaseCenter: Double, phaseRadius: Double
    ) -> (score: Double, period: Double, phase: Double)? {
        var best: (score: Double, period: Double, phase: Double)?
        var bestDistanceToUniform = Double.infinity

        for periodStep in -searchSteps...searchSteps {
            let period = periodCenter + Double(periodStep) / Double(searchSteps) * periodRadius
            guard period > 0 else { continue }

            for phaseStep in -searchSteps...searchSteps {
                let phase = phaseCenter + Double(phaseStep) / Double(searchSteps) * phaseRadius

                var score = 0.0
                var visibleLines = 0
                for line in 0...8 {
                    let position = phase + Double(line) * period
                    // `1` et `side - 2`, pas `0` et `side - 1` : les deux
                    // extrémités du profil valent structurellement zéro
                    // (`edgeProfile` calcule une dérivée CENTRÉE), et une ligne
                    // qui y tombe n'est pas une ligne sans contour — c'est une
                    // ligne qu'on ne sait pas observer. Même traitement que
                    // hors image : elle ne compte ni au score ni au quorum.
                    //
                    // Sans cette exclusion, l'affinage ci-dessus DÉCALE la
                    // grille pour tirer la ligne 0 hors de l'angle mort et y
                    // gagner quelques points : mesuré, le cadrage parfait
                    // passait de 0,00 à 1,10 px d'écart. C'est aussi pourquoi
                    // la dérivée décentrée « ne changeait rien » avant — la
                    // quantification de la recherche masquait le biais.
                    guard position >= 1, position <= side - 2 else { continue }
                    score += sample(profile, at: position)
                    visibleLines += 1
                }
                // Trop peu de lignes dans l'image : la grille n'est plus jugée,
                // elle est devinée.
                guard visibleLines >= minimumLinesInsideImage else { continue }

                let distanceToUniform = abs(period - idealPeriod) + abs(phase)
                guard let current = best else {
                    best = (score, period, phase)
                    bestDistanceToUniform = distanceToUniform
                    continue
                }
                // Tolérance RELATIVE : les scores sont des sommes de doubles,
                // et deux positions d'un même plateau donnent des valeurs
                // identiques au dernier bit près, pas forcément égales.
                let tolerance = current.score * scoreTieTolerance
                let isBetter = score > current.score + tolerance
                let isTied = abs(score - current.score) <= tolerance
                if isBetter || (isTied && distanceToUniform < bestDistanceToUniform) {
                    best = (score, period, phase)
                    bestDistanceToUniform = distanceToUniform
                }
            }
        }
        return best
    }

    /// Deux scores plus proches que ça sont tenus pour ex æquo.
    private static let scoreTieTolerance = 1e-9

    /// Nombre de crans de part et d'autre du centre, dans chaque passe.
    private static let searchSteps = 12
    /// Passes d'affinage après la passe grossière.
    private static let refinementPasses = 2

    /// Valeur du profil à une position fractionnaire, interpolée — sinon la
    /// recherche avancerait par sauts d'un pixel et raterait le vrai optimum.
    /// Hors bornes : 0, ce qui n'avantage aucune grille (le bord extérieur du
    /// plateau peut manquer, notamment sur une capture cadrée au plus juste).
    private static func sample(_ profile: [Double], at position: Double) -> Double {
        guard position >= 0, position <= Double(profile.count - 1) else { return 0 }
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, profile.count - 1)
        let fraction = position - Double(lower)
        return profile[lower] * (1 - fraction) + profile[upper] * fraction
    }
}
