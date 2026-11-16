import SwiftUI

// Les morceaux d'interface de la synchronisation iCloud, partagés entre les Réglages et l'accueil.
//
// Le principe (refonte du 16/11/2026, après le retour d'un utilisateur dont les deux appareils
// restaient chacun dans leur état sans que rien ne le montre) : UN état en un mot, ce qu'il faut faire
// quand il y a quelque chose à faire, et la liste des appareils reliés pour vérifier d'un coup d'œil.

/// Vrai sur Mac (Catalyst ou app iPad sur Mac) : les gestes pour quitter l'app n'y sont pas les mêmes.
private var runsOnMac: Bool {
    ProcessInfo.processInfo.isMacCatalystApp || ProcessInfo.processInfo.isiOSAppOnMac
}

// MARK: - L'état, en une ligne

struct CloudSyncStatusRow: View {
    let state: CloudSyncState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            icon
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isWarning ? Theme.warning : Theme.textPrimary)
                detail
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("syncStatusRow")
    }

    private var isWarning: Bool {
        switch state {
        case .startsAfterRestart, .stopsAfterRestart, .noAccount, .accountUnavailable, .paused: true
        default: false
        }
    }

    @ViewBuilder private var icon: some View {
        switch state {
        case .off:
            Image(systemName: "icloud.slash").foregroundStyle(Theme.textTertiary)
        case .startsAfterRestart:
            Image(systemName: "arrow.clockwise.icloud").foregroundStyle(Theme.warning)
        case .stopsAfterRestart:
            Image(systemName: "icloud.slash").foregroundStyle(Theme.warning)
        case .checkingAccount:
            Image(systemName: "icloud").foregroundStyle(Theme.textTertiary)
        case .noAccount, .accountUnavailable, .paused:
            Image(systemName: "exclamationmark.icloud").foregroundStyle(Theme.warning)
        case .syncing:
            ProgressView().controlSize(.small).tint(Theme.accent)
        case .upToDate:
            Image(systemName: "checkmark.icloud.fill").foregroundStyle(Theme.accent)
        }
    }

    @ViewBuilder private var title: some View {
        switch state {
        case .off: Text("Désactivée")
        case .startsAfterRestart: Text("Dernière étape : relancer ChessLab")
        case .stopsAfterRestart: Text("Arrêt complet au prochain lancement")
        case .checkingAccount: Text("Vérification du compte iCloud…")
        case .noAccount: Text("Connectez-vous à iCloud")
        case .accountUnavailable: Text("iCloud indisponible")
        case .paused: Text("Synchronisation en pause")
        case .syncing: Text("Synchronisation en cours…")
        case .upToDate: Text("À jour")
        }
    }

    @ViewBuilder private var detail: some View {
        switch state {
        case .off:
            Text("Tout reste sur cet appareil.")
        case .startsAfterRestart:
            Text("Vos réglages et la partie en cours se synchronisent déjà. Le reste démarrera à la réouverture.")
        case .stopsAfterRestart:
            Text("Les réglages et la partie en cours ne sont plus partagés. Pour arrêter aussi le reste, fermez complètement ChessLab puis rouvrez-le.")
        case .checkingAccount:
            EmptyView()
        case .noAccount:
            if runsOnMac {
                Text("Dans Réglages Système, cliquez en haut à gauche pour vous connecter avec votre compte Apple. La synchronisation reprendra d'elle-même.")
            } else {
                Text("Dans les Réglages de l'appareil, touchez la ligne tout en haut et connectez-vous avec votre compte Apple. La synchronisation reprendra d'elle-même.")
            }
        case .accountUnavailable:
            Text("iCloud ne répond pas pour le moment. La synchronisation reprendra d'elle-même.")
        case let .paused(message):
            Text(verbatim: message)
        case .syncing:
            Text("Échange avec iCloud.")
        case let .upToDate(last?):
            Text("Dernier échange : \(Text(last, format: .relative(presentation: .named)))")
        case .upToDate(nil):
            Text("Premier échange en attente : iOS s'en charge dans les minutes qui viennent.")
        }
    }
}

// MARK: - Relancer : les gestes, pas une injonction

/// « Dernière étape » : comment fermer complètement ChessLab, pas à pas. Le relancement n'est nécessaire
/// qu'une fois, à l'activation — iOS ne permet pas à une app de se relancer elle-même.
struct CloudRestartSteps: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if runsOnMac {
                step(1, "command", Text("Quittez ChessLab (⌘Q)."))
                step(2, "arrow.clockwise", Text("Rouvrez ChessLab : la synchronisation démarre."))
            } else {
                step(1, "rectangle.stack", Text("Ouvrez le sélecteur d'apps : balayez vers le haut depuis le bas de l'écran et marquez une pause (ou appuyez deux fois sur le bouton principal)."))
                step(2, "hand.draw", Text("Faites glisser ChessLab vers le haut pour le fermer."))
                step(3, "arrow.clockwise", Text("Rouvrez ChessLab : la synchronisation démarre."))
            }
        }
        .padding(12)
        .background(Theme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.warning.opacity(0.30), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("syncRestartBanner")
    }

    private func step(_ number: Int, _ symbol: String, _ text: Text) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(Theme.warning.opacity(0.22))
                Text(verbatim: "\(number)").font(.caption.weight(.bold)).foregroundStyle(Theme.warning)
            }
            .frame(width: 22, height: 22)
            text
                .font(.caption)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: symbol).font(.caption).foregroundStyle(Theme.textTertiary)
        }
    }
}

/// La même chose en feuille, ouverte depuis l'accueil.
struct CloudRestartSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                IconBadge(systemImage: "arrow.clockwise.icloud", tint: Theme.warning, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dernière étape : relancer ChessLab")
                        .font(.headline).foregroundStyle(Theme.textPrimary)
                    Text("Une seule fois, pour brancher vos parties et votre progression sur iCloud.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            CloudRestartSteps()
            Text("Vos réglages et la partie en cours se synchronisent déjà. Le reste démarrera à la réouverture.")
                .font(.caption).foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Button { dismiss() } label: {
                Text("OK").font(.headline).foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Theme.accentGradient, in: Theme.cardShape)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("syncRestartSheetOK")
        }
        .padding(20)
        .frame(maxWidth: Theme.readableWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appBackground()
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Vos appareils

struct CloudDevicesList: View {
    let devices: [CloudDeviceRecord]
    let ownID: String
    let appVersion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vos appareils")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            ForEach(devices) { device in row(device) }
            Text(devices.contains { $0.id != ownID }
                 ? "Un appareil manque ? Vérifiez sur lui : même compte Apple, ChessLab à jour, synchronisation activée."
                 : "Aucun autre appareil relié pour l'instant. Sur l'autre appareil : même compte Apple, ChessLab à jour, synchronisation activée.")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("syncDevicesList")
    }

    private func row(_ device: CloudDeviceRecord) -> some View {
        let isOwn = device.id == ownID
        let outdated = !isOwn && device.isOlder(than: appVersion)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: device.symbol)
                .font(.body)
                .foregroundStyle(isOwn ? Theme.accent : Theme.textSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(verbatim: device.kind)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    if isOwn {
                        Text("Cet appareil")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Theme.accent.opacity(0.15), in: Capsule())
                    }
                }
                if !isOwn {
                    Text("Dernière activité : \(Text(device.lastSeen, format: .relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                if outdated {
                    Text("ChessLab \(device.appVersion) — à mettre à jour")
                        .font(.caption2)
                        .foregroundStyle(Theme.warning)
                } else {
                    Text(verbatim: "ChessLab \(device.appVersion)")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Accueil

/// « Votre iPad synchronise déjà ChessLab » : la proposition, sur un appareil où la synchro est éteinte.
struct CloudSyncInvitationCard: View {
    let device: CloudDeviceRecord
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                IconBadge(systemImage: "icloud", tint: Theme.info, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Votre \(device.kind) synchronise déjà ChessLab")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Activez iCloud ici aussi pour retrouver vos parties et votre progression.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Button(action: onAccept) {
                    Text("Activer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Theme.info, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("syncInvitationAccept")
                Button(action: onDismiss) {
                    Text("Pas maintenant")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("syncInvitationDismiss")
            }
        }
        .cardStyle()
        .overlay(Theme.cardShape.strokeBorder(Theme.info.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("syncInvitationCard")
    }
}

/// Synchro allumée, relancement pas encore fait : un rappel discret à l'accueil, qui ouvre les gestes.
struct CloudRestartReminderCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                IconBadge(systemImage: "arrow.clockwise.icloud", tint: Theme.warning, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dernière étape : relancer ChessLab")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Fermez ChessLab puis rouvrez-le pour que vos parties et votre progression suivent vos appareils.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .cardStyle()
            .overlay(Theme.cardShape.strokeBorder(Theme.warning.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("syncRestartReminder")
    }
}
