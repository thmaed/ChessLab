import Charts
import SwiftUI

/// Un point de la courbe d'évaluation.
///
/// Générique sur son identifiant : l'analyse du mode « Jouer » situe ses
/// positions par un index d'arbre de coups (les variations y existent), les
/// analyses de variantes par un simple numéro de demi-coup (leur ligne est
/// unique). Le dessin, lui, est le même.
struct EvalCurvePoint<ID: Hashable>: Identifiable {
    let id: ID
    let ply: Int
    /// POV Blancs, bornée ±10 (un mat vaut ±10).
    let pawns: Double
    /// Qualité du coup menant à ce point — `nil` tant que la classification
    /// n'est pas passée. La courbe en tire ses pastilles de moments critiques.
    var quality: MoveQuality?

    /// Depuis une évaluation en centipions, POV Blancs.
    init(id: ID, ply: Int, centipawnsWhite: Int, quality: MoveQuality? = nil) {
        self.id = id
        self.ply = ply
        self.pawns = min(10, max(-10, Double(centipawnsWhite) / 100))
        self.quality = quality
    }

    init(id: ID, ply: Int, pawns: Double, quality: MoveQuality? = nil) {
        self.id = id
        self.ply = ply
        self.pawns = pawns
        self.quality = quality
    }
}

/// Courbe d'évaluation, bornée ±10 pions, cliquable pour naviguer au coup
/// correspondant.
///
/// Extraite d'``AnalysisView`` le 29/08 : le mode « Jouer » l'avait, les
/// écrans d'analyse des VARIANTES ne l'avaient pas, et une partie s'y
/// relisait sans qu'on voie où elle avait basculé. Une seule implémentation
/// pour les quatre écrans — Jouer, Chess960, variantes, Duck Chess.
struct EvalCurveView<ID: Hashable>: View {
    let points: [EvalCurvePoint<ID>]
    let currentPly: Int?
    let onSelect: (ID) -> Void

    /// 64 pt et non 100 : la courbe sert à REPÉRER les décrochages et à y
    /// sauter, pas à lire une valeur — trois fois moins haute, elle laisse la
    /// place aux coups tout en restant parfaitement lisible.
    var height: CGFloat = 64

    /// L'échelle verticale S'ADAPTE à la partie, au lieu d'être figée à
    /// ±10 pions.
    ///
    /// Figée, elle écrasait tout : une partie normale tient dans ±2, donc la
    /// courbe occupait un dixième de la hauteur et ressemblait à un trait
    /// plat — le décrochage qu'elle est censée montrer devenait invisible.
    /// Elle reste SYMÉTRIQUE, pour que le milieu soit toujours l'égalité, et
    /// bornée des deux côtés : un plancher à ±1,5 pion pour ne pas
    /// transformer trois centipions d'écart en montagne russe, un plafond à
    /// ±10 pour qu'un mat annoncé n'aplatisse pas le reste.
    private var verticalBound: Double {
        let peak = points.map { abs($0.pawns) }.max() ?? 0
        return min(10, max(1.5, peak * 1.15))
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                // Aire signée depuis la ligne d'équilibre : le regard voit
                // TOUT DE SUITE qui est devant, sans lire d'axe. Une courbe
                // toujours verte, quel que soit le camp qui mène, ne disait
                // rien de tel.
                AreaMark(
                    x: .value("Coup", point.ply),
                    yStart: .value("Éval", 0),
                    yEnd: .value("Éval", point.pawns)
                )
                .foregroundStyle(point.pawns >= 0 ? Theme.accent.opacity(0.28) : Theme.info.opacity(0.28))
                .interpolationMethod(.monotone)

                LineMark(x: .value("Coup", point.ply), y: .value("Éval", point.pawns))
                    .foregroundStyle(Theme.textPrimary.opacity(0.75))
                    .lineStyle(StrokeStyle(lineWidth: 1.6))
                    .interpolationMethod(.monotone)
            }

            // Les MOMENTS CRITIQUES, épinglés sur la courbe : brillant, grand
            // coup, occasion manquée, erreur, gaffe. Petites pastilles
            // volontairement — elles disent OÙ regarder, la liste de coups dit
            // quoi. Le halo sombre les détache de l'aire colorée.
            ForEach(points.filter { $0.quality?.marksCriticalPhase == true }) { point in
                PointMark(x: .value("Coup", point.ply), y: .value("Éval", point.pawns))
                    .foregroundStyle(Theme.background)
                    .symbolSize(64)
                PointMark(x: .value("Coup", point.ply), y: .value("Éval", point.pawns))
                    .foregroundStyle(point.quality?.tint ?? Theme.textSecondary)
                    .symbolSize(30)
            }

            // Ligne d'équilibre, discrète mais présente : sans elle, une aire
            // signée n'a pas de repère.
            RuleMark(y: .value("Équilibre", 0))
                .foregroundStyle(Theme.stroke)
                .lineStyle(StrokeStyle(lineWidth: 1))

            // Où l'on se trouve dans la partie.
            if let currentPly {
                RuleMark(x: .value("Position", currentPly))
                    .foregroundStyle(Theme.accent.opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .chartYScale(domain: -verticalBound...verticalBound)
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .frame(height: height)
        .padding(.vertical, 2)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let origin = geometry[plotFrame].origin
                                let x = value.location.x - origin.x
                                guard let tappedPly: Int = proxy.value(atX: x) else { return }
                                if let closest = points.min(by: { abs($0.ply - tappedPly) < abs($1.ply - tappedPly) }) {
                                    onSelect(closest.id)
                                }
                            }
                    )
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Courbe d'évaluation")
        .accessibilityIdentifier("evalCurve")
    }
}
