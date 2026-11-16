import Foundation

/// Branche ou débranche, À CHAUD, ce qui passe par le magasin clé-valeur iCloud : les réglages
/// (``SettingsCloudSync``) et les parties en cours (``AutosaveCloud``).
///
/// Ces deux-là, contrairement aux données SwiftData, ne dépendent pas du `ModelContainer` : leur code lit
/// l'interrupteur en direct. Seule l'ÉCOUTE des changements venus d'ailleurs était posée au lancement ;
/// d'où un « fermez et rouvrez » inutile pour eux (16/11/2026). On la pose et on la retire maintenant à
/// chaque bascule de l'interrupteur.
///
/// Idempotent : appelée au lancement, à chaque bascule et par « Synchroniser maintenant ».
///
/// Ce qui reste lié au lancement : le conteneur SwiftData (parties enregistrées, ouvertures, puzzles,
/// Woodpecker) — voir ``CloudSyncSettingsStore/activeAtLaunch``.
@MainActor
enum KeyValueSyncSwitch {
    static func apply() {
        if CloudSyncSettingsStore.isEnabled {
            SettingsCloudSync.shared.start {
                AppSettings.shared.reloadSyncedValuesFromDefaults()
            }
            AutosaveCloud.start()
        } else {
            // Éteint : plus aucune écriture ni lecture, tout de suite — pas seulement au prochain lancement.
            SettingsCloudSync.shared.stop()
            AutosaveCloud.stop()
        }
        // « Vos appareils » : la fiche de cet appareil suit l'interrupteur (déposée allumé, retirée éteint) ;
        // l'écoute, elle, est en LECTURE et reste branchée — c'est elle qui permet de proposer la synchro.
        let registry = CloudDeviceRegistry.live
        if CloudSyncSettingsStore.isEnabled { registry.checkIn() } else { registry.checkOut() }
        CloudDevices.startObserving()
        NotificationCenter.default.post(name: CloudDevices.didChange, object: nil)
    }

    /// Retour au premier plan : rafraîchir la fiche (au plus toutes les 10 minutes).
    static func appBecameActive() {
        CloudDeviceRegistry.live.checkIn()
    }
}
