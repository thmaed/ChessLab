import ChessKit
import Foundation
import Observation

/// Double pendule pour une partie. `nil` si la partie est jouée sans
/// cadence (``TimeControl/none``).
@Observable
@MainActor
final class GameClock {

    // Valeurs PUBLIÉES (observées) : ne changent qu'au pas d'affichage
    // (voir `publishStep`), pas à chaque tick de 100 ms — sinon 10
    // mutations `@Observable`/s invalident des vues pour un affichage qui
    // ne bouge qu'à la seconde. Voir instructions.md §B3.
    private(set) var whiteRemaining: TimeInterval
    private(set) var blackRemaining: TimeInterval
    private(set) var isRunning = false
    private(set) var flaggedColor: Piece.Color?

    // Temps PRÉCIS (non observés) : source de vérité pour le décompte et le
    // flag, décrémentés à chaque tick sans invalider de vue.
    @ObservationIgnored private var whitePrecise: TimeInterval
    @ObservationIgnored private var blackPrecise: TimeInterval

    let control: TimeControl
    /// Appelé lorsqu'un camp arrive au bout de son temps.
    var onFlagFall: ((Piece.Color) -> Void)?

    private var activeColor: Piece.Color?
    private var tickTask: Task<Void, Never>?
    private var lastTick: Date?

    init(control: TimeControl) {
        self.control = control
        let initial = TimeInterval(control.initialSeconds)
        whiteRemaining = initial
        blackRemaining = initial
        whitePrecise = initial
        blackPrecise = initial
    }

    /// Restaure des temps restants sauvegardés (reprise après fermeture
    /// de l'app).
    func restore(white: TimeInterval, black: TimeInterval) {
        whitePrecise = white
        blackPrecise = black
        whiteRemaining = white
        blackRemaining = black
    }

    /// Pas d'affichage d'un temps : dixièmes sous 10 s (bullet), secondes
    /// entières au-delà. Sert à ne republier que quand l'affichage change.
    private func publishStep(_ t: TimeInterval) -> Int {
        t < 10 ? Int(t * 10) : Int(t) * 10
    }

    /// Temps restant PRÉCIS — pour la logique seule (budget moteur,
    /// autosauvegarde). À NE PAS lire depuis une vue : `whitePrecise` /
    /// `blackPrecise` sont `@ObservationIgnored`, donc leur lecture
    /// n'abonne à rien et l'affichage resterait figé entre deux coups.
    /// Les vues lisent ``displayRemaining(for:)``.
    func remaining(for color: Piece.Color) -> TimeInterval {
        color == .white ? whitePrecise : blackPrecise
    }

    /// Temps restant à AFFICHER : lit les propriétés publiées (donc
    /// observées), republiées à chaque pas d'affichage par ``tick()``.
    /// C'est ce qui fait réellement égrener la pendule à l'écran.
    func displayRemaining(for color: Piece.Color) -> TimeInterval {
        color == .white ? whiteRemaining : blackRemaining
    }

    /// Démarre (ou reprend) le décompte pour `color`, en créditant
    /// l'incrément à la couleur qui vient de jouer (`previousMover`).
    func startTurn(for color: Piece.Color, previousMover: Piece.Color? = nil) {
        guard control.hasClock, flaggedColor == nil else { return }

        if let previousMover, control.incrementSeconds > 0 {
            add(TimeInterval(control.incrementSeconds), to: previousMover)
        }

        activeColor = color
        lastTick = Date()
        isRunning = true

        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                self.tick()
            }
        }
    }

    func pause() {
        isRunning = false
        tickTask?.cancel()
        tickTask = nil
        activeColor = nil
    }

    private func add(_ seconds: TimeInterval, to color: Piece.Color) {
        if color == .white {
            whitePrecise += seconds
            whiteRemaining = whitePrecise
        } else {
            blackPrecise += seconds
            blackRemaining = blackPrecise
        }
    }

    private func tick() {
        guard isRunning, let activeColor, let lastTick else { return }
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        self.lastTick = now

        if activeColor == .white {
            whitePrecise = max(0, whitePrecise - elapsed)
            // Ne republie (donc n'invalide les vues) que si l'affichage change.
            if publishStep(whitePrecise) != publishStep(whiteRemaining) {
                whiteRemaining = whitePrecise
            }
            if whitePrecise == 0 { whiteRemaining = 0; flag(.white) }
        } else {
            blackPrecise = max(0, blackPrecise - elapsed)
            if publishStep(blackPrecise) != publishStep(blackRemaining) {
                blackRemaining = blackPrecise
            }
            if blackPrecise == 0 { blackRemaining = 0; flag(.black) }
        }
    }

    private func flag(_ color: Piece.Color) {
        flaggedColor = color
        pause()
        onFlagFall?(color)
    }
}
