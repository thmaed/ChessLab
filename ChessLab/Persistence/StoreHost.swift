import SwiftData
import SwiftUI
import UIKit

/// La base SwiftData de l'app, REMPLAÇABLE en cours de session : allumer ou éteindre la synchronisation
/// iCloud ne demande plus de fermer puis rouvrir ChessLab (16/11/2026).
///
/// ## Pourquoi il le fallait
///
/// Une base est branchée sur CloudKit — ou non — à sa construction, et ne se rebranche pas. Jusqu'ici,
/// l'interrupteur ne prenait donc effet qu'au lancement suivant, et l'app devait expliquer les gestes pour
/// la fermer. On en construit désormais une autre, sur les MÊMES fichiers, sans quitter l'app.
///
/// ## Comment
///
/// 1. Tout enregistrer ; détacher les deux services qui gardent un accès à la base (répertoires, fusion de
///    ce qui arrive d'iCloud).
/// 2. Remplacer l'interface par un écran de passage : les écrans, leurs modèles de vue (et leurs moteurs),
///    leurs requêtes disparaissent avec elle.
/// 3. Attendre que l'ancienne base soit réellement LIBÉRÉE — une référence faible le dit.
/// 4. Ouvrir la nouvelle, rebrancher, rendre l'interface, qui revient sur les Réglages.
///
/// ## Le filet
///
/// Si quelque chose retient encore l'ancienne base (un import de PGN, une partie ouverte dans une autre
/// fenêtre…), on N'OUVRE PAS la seconde : deux piles sur les mêmes fichiers, c'est le risque qu'on refuse.
/// On reprend l'ancienne, intacte, et l'écran dit comme avant « fermez et rouvrez ChessLab ». Au pire, donc,
/// le comportement d'avant — jamais pire.
@MainActor @Observable
final class StoreHost {
    /// L'instance de l'app, posée par ``ChessLabApp`` avec la base du lancement.
    static let shared = StoreHost()

    private(set) var container: ModelContainer?
    /// Pendant l'échange, l'écran de passage remplace l'interface. `true` : vers iCloud, `false` : hors d'iCloud.
    private(set) var switching: Bool?
    /// Après un échange (réussi ou non), l'accueil rouvre les Réglages : c'est de là qu'on venait, et c'est
    /// là que se lit le résultat.
    var reopensSettings = false

    /// Ouvre la base selon l'interrupteur (voir ``ChessLabApp/openModelContainer()``).
    @ObservationIgnored var open: () -> ModelContainer = { fatalError("StoreHost sans fabrique") }
    /// Lâcher, puis reprendre, ce qui garde un accès à la base hors de l'interface.
    @ObservationIgnored var willRelease: () -> Void = {}
    @ObservationIgnored var didOpen: (ModelContainer) -> Void = { _ in }

    init() {}

    /// Branche la base du lancement.
    func install(_ container: ModelContainer, open: @escaping () -> ModelContainer) {
        self.container = container
        self.open = open
    }

    /// Fait suivre la base à l'interrupteur iCloud, sans relancer l'app. Rend `true` si c'est fait ; `false`
    /// s'il n'y avait rien à faire, ou si quelque chose retenait l'ancienne base (gardée telle quelle).
    @discardableResult
    func followSyncSwitch() async -> Bool {
        let wanted = CloudSyncSettingsStore.isEnabled
        guard switching == nil, container != nil,
              wanted != CloudSyncSettingsStore.activeAtLaunch,
              // Session dégradée : une base en mémoire, rien à rebrancher (le prochain lancement réessaie).
              !SessionDegradation.isInMemory,
              // Le chargement de la bibliothèque de puzzles écrit par sa propre file : on ne le coupe pas.
              !PuzzleSeedingState.shared.isSeeding else { return false }
        let reopened = await reopen(towardCloud: wanted)
        reopensSettings = true
        if reopened, CloudSyncSettingsStore.activeAtLaunch {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return reopened
    }

    /// Le cœur de l'échange : fermer, attendre la libération, rouvrir — ou reprendre l'ancienne base.
    func reopen(towardCloud: Bool, releaseTimeout: Duration = .seconds(4)) async -> Bool {
        guard container != nil else { return false }
        switching = towardCloud
        defer { switching = nil }

        try? container?.mainContext.save()
        willRelease()
        weak var old = container
        container = nil
        // L'interface s'efface (écran de passage) : on lui laisse le temps de lâcher ses écrans.
        let deadline = ContinuousClock.now + releaseTimeout
        while old != nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        if let still = old {
            container = still
            didOpen(still)
            return false
        }
        let fresh = open()
        container = fresh
        didOpen(fresh)
        return true
    }
}

/// L'interface — ou, le temps de changer de base, l'écran de passage.
struct StoreGate<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        let host = StoreHost.shared
        if let container = host.container, host.switching == nil {
            content().modelContainer(container)
        } else {
            StoreSwitchingView(towardCloud: host.switching ?? true)
        }
    }
}

/// « Branchement à iCloud… » : une seconde ou deux, à la place de « fermez et rouvrez l'app ».
struct StoreSwitchingView: View {
    let towardCloud: Bool

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.info)
            Group {
                if towardCloud { Text("Branchement à iCloud…") } else { Text("Débranchement d'iCloud…") }
            }
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
            Text("Un instant, ChessLab se relance de lui-même.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storeSwitching")
    }
}
