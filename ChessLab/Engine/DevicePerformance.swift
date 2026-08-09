import Foundation

/// Capacités de l'appareil, pour dimensionner le moteur au plus juste :
///
///  • **Threads sur les cœurs PERFORMANCE** seulement. Les puces Apple sont
///    big.LITTLE ; lancer un thread par cœur logique en met sur les cœurs
///    « efficacité », lents, qui font chauffer l'appareil pour un gain nul
///    (c'était le cas sur iPhone 11 : 4 threads dont 2 sur des cœurs éco).
///  • **Budgets d'analyse par palier** : l'analyse va CHERCHER plus de
///    profondeur sur les appareils modernes (qui l'encaissent dans le temps
///    imparti), et reste sobre en bas de gamme.
///
/// Valeurs lues une fois (elles ne changent pas pendant la session).
enum DevicePerformance {

    /// Nombre de cœurs PERFORMANCE, via `hw.perflevel0` (niveau 0 = les gros
    /// cœurs). Repli sur la moitié des cœurs logiques si l'info manque.
    static let performanceCores: Int = {
        var count: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.perflevel0.physicalcpu", &count, &size, nil, 0) == 0, count > 0 {
            return Int(count)
        }
        return max(1, ProcessInfo.processInfo.activeProcessorCount / 2)
    }()

    /// Threads moteur recommandés : les cœurs performance, plafonnés à 4
    /// (au-delà, sur mobile, le gain part en chaleur ; `ThermalMonitor` rabote
    /// encore à 1 en surchauffe).
    static var recommendedThreads: Int { max(1, min(4, performanceCores)) }

    enum Tier { case low, mid, high }

    /// Palier de puissance, indexé sur la RAM (bon proxy de génération) :
    /// ≤4 Go = iPhone 11 / SE, ~6 Go = milieu de gamme récent, ≥8 Go = Pro
    /// récents et iPad M-series.
    static let tier: Tier = {
        let gigabytes = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        if gigabytes >= 7.5 { return .high }
        if gigabytes >= 5.5 { return .mid }
        return .low
    }()

    /// Budget de NŒUDS d'une position de classification (hors ouverture). Plus
    /// grand = analyse plus profonde. Le moteur recompilé (NEON) atteint ces
    /// budgets bien plus vite qu'avant, ce qui laisse la place à plus de
    /// profondeur sans exploser le temps total (cible ~30-60 s / partie).
    static var classificationNodeBudget: Int {
        switch tier {
        case .low: return 220_000
        case .mid: return 380_000
        case .high: return 550_000
        }
    }

    /// Plafond de TEMPS par position (filet de sécurité quand une position est
    /// dure et que le débit chute) : plus large sur appareil rapide pour ne pas
    /// écrêter le budget de nœuds plus ambitieux.
    static var classificationCapMs: Int {
        switch tier {
        case .low: return 1_600
        case .mid: return 2_200
        case .high: return 2_800
        }
    }

    /// Profondeur cible de l'analyse en continu (position affichée). Plus
    /// profonde sur appareil moderne : éval et flèches plus fiables sans que
    /// l'utilisateur attende.
    static var liveDepth: Int {
        switch tier {
        case .low: return 20
        case .mid: return 24
        case .high: return 26
        }
    }
}
