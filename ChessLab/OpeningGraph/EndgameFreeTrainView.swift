import ChessKit
import SwiftUI

/// Écran d'entraînement LIBRE d'une finale : plateau + verdict à tenir en
/// bandeau, correction quand un coup lâche le verdict, bilan honnête à la
/// fin (nombre de coups repris). Voir ``EndgameFreeTrainViewModel`` pour la
/// mécanique d'arbitrage.
struct EndgameFreeTrainView: View {
    @Bindable var viewModel: EndgameFreeTrainViewModel
    let onExit: () -> Void
    /// « Réessayer » de la bannière moteur : l'hôte relance l'instance.
    var onRetryEngine: () -> Void = {}

    @State private var appSettings = AppSettings.shared
    private var boardTheme: BoardTheme { appSettings.boardTheme }

    var body: some View {
        VStack(spacing: 14) {
            header
            boardSquare
                .padding(.horizontal, 16)
            statusPanel
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .appBackground()
        .navigationTitle(LocalizedStringKey(viewModel.course.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay { promotionOverlay }
    }

    // MARK: Bandeau d'objectif

    /// Le contrat du mode, en une ligne : le verdict à tenir, et la source
    /// de l'arbitrage — VÉRIFIÉ moteur, pas prouvé ; la nuance est
    /// l'honnêteté maison, elle reste visible.
    private var header: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.userColor == .white ? Color.white : Color.black)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                if let verdict = viewModel.baselineVerdict {
                    Text("Verdict à tenir : ")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    + Text(verdict.displayLabel)
                        .font(.headline)
                        .foregroundStyle(tint(for: verdict))
                } else {
                    Text("Entraînement libre")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            Text("Tout coup qui préserve le verdict est accepté — arbitrage vérifié moteur.")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }

    private func tint(for verdict: EndgameVerdict) -> Color {
        switch verdict {
        case .win: Theme.accent
        case .draw: Theme.info
        case .loss: Theme.danger
        }
    }

    // MARK: Plateau

    private var boardSquare: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ChessBoardView(
                board: viewModel.board,
                orientation: viewModel.orientation,
                theme: boardTheme,
                selectedSquare: viewModel.selectedSquare,
                legalTargetSquares: viewModel.legalTargetSquares,
                lastMove: viewModel.lastMove,
                hintMoves: viewModel.hintMoves,
                interactionEnabled: viewModel.isUserTurn,
                showCoordinates: true,
                draggableColor: viewModel.orientation,
                onTapSquare: { viewModel.selectSquare($0) },
                onDropPiece: { viewModel.attemptMove(from: $0, to: $1) }
            )
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Panneau d'état

    @ViewBuilder
    private var statusPanel: some View {
        switch viewModel.phase {
        case .preparing, .arbitrating:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Theme.textSecondary)
                Text("Arbitrage…")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        case .opponentMoving:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Theme.textSecondary)
                Text("La défense réfléchit…")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        case .awaiting:
            // Rien : le bandeau du haut dit déjà tout, l'écran reste calme.
            EmptyView()
        case .slipped:
            slipCard
        case .finished:
            finishedCard
        case .unavailable:
            EngineUnavailableBanner(
                message: "L'arbitre et la défense reposent sur le moteur — relancez-le pour continuer.",
                isRetrying: false,
                onRetry: onRetryEngine
            )
            .padding(.horizontal, 16)
        }
    }

    /// Correction après un coup qui lâche : les deux verdicts en toutes
    /// lettres, puis le choix — réessayer soi-même, ou voir le meilleur coup.
    private var slipCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.warning)
                if let from = viewModel.slipFrom, let to = viewModel.slipTo {
                    (Text("Ce coup lâche le verdict : ")
                        + Text(from.displayLabel).bold()
                        + Text(" → ")
                        + Text(to.displayLabel).bold())
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Button {
                    viewModel.retryAfterSlip()
                } label: {
                    Text("Réessayer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.accentGradient, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("freeTrain_retry")

                Button {
                    viewModel.playBestAfterSlip()
                } label: {
                    Text("Jouer le meilleur coup")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(16)
        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.warning.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var finishedCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: finishedIsSuccess ? "checkmark.circle.fill" : "flag.checkered")
                    .font(.title2)
                    .foregroundStyle(finishedIsSuccess ? Theme.accent : Theme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    if let outcome = viewModel.outcome {
                        Text(outcome.summary(userColor: viewModel.userColor))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    // Le bilan HONNÊTE : convertir en trois reprises n'est pas
                    // convertir du premier coup — le chiffre le dit sans juger.
                    if viewModel.slipCount > 0 {
                        Text("Coups repris en route : \(viewModel.slipCount)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("Aucun coup repris — conversion propre.")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Button(action: onExit) {
                    Text("Retour")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)

                Button {
                    viewModel.restart()
                } label: {
                    Text("Rejouer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.accentGradient, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(16)
        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.strokeStrong, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// « Réussi » = l'utilisateur a fait AU MOINS aussi bien que le verdict
    /// de départ du cours : gagné quand c'était gagnant, au moins nul quand
    /// c'était nul.
    private var finishedIsSuccess: Bool {
        guard let outcome = viewModel.outcome else { return false }
        switch outcome.winner {
        case viewModel.userColor: return true
        case nil: return viewModel.baselineVerdict != .win
        default: return false
        }
    }

    @ViewBuilder
    private var promotionOverlay: some View {
        if let pending = viewModel.pendingPromotion {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { viewModel.cancelPromotion() }
                .overlay {
                    PromotionPickerView(color: pending.move.piece.color) { kind in
                        viewModel.completePromotion(to: kind)
                    }
                }
        }
    }
}

/// Héberge le moteur (arbitre + défense) et le view model, construits une
/// seule fois — même discipline paresseuse que les autres hôtes, même effet
/// de bord process moteur à maîtriser (``EngineInstanceCounter``).
struct EndgameFreeTrainHost: View {
    let courseID: String
    /// Identité de session — voir ``SessionStore``.
    let sessionKey: String
    let onExit: () -> Void
    @Environment(\.sessionStore) private var sessionStore
    @State private var viewModel: EndgameFreeTrainViewModel?
    @State private var engine: EngineController?

    var body: some View {
        Group {
            if let viewModel {
                EndgameFreeTrainView(viewModel: viewModel, onExit: onExit) {
                    Task { await startEngineAndSession() }
                }
            } else {
                ProgressView().appBackground()
            }
        }
        .task {
            guard viewModel == nil else { return }
            await startEngineAndSession()
        }
        .onDisappear {
            // Le moteur est un PROCESS : il ne survit pas à l'écran (même
            // règle que Jouer/Labo — un moteur oublié chauffe et vide la
            // batterie jusqu'au kill de l'app).
            let engine = engine
            Task { await engine?.stop() }
            self.engine = nil
        }
    }

    private func startEngineAndSession() async {
        guard let course = OpeningCatalog.course(id: courseID) else { return }

        if engine == nil {
            let controller = EngineController()
            guard await controller.start(
                threads: ThermalMonitor.shared.threads(preferred: AppSettings.recommendedEngineThreads),
                hashMB: AppSettings.engineHashMB, multipv: 1
            ) else {
                // Démarrage raté (réseau NNUE absent, mémoire…) : un VM
                // branché sur l'instance morte affichera la bannière
                // « Moteur indisponible », dont le Réessayer repasse ici.
                await controller.stop()
                let driver = EngineEndgameDriver(engine: controller)
                guard let vm = sessionStore.value(for: sessionKey, make: {
                    EndgameFreeTrainViewModel(course: course, judge: driver, opponent: driver)
                }) else { return }
                vm.replaceProviders(judge: driver, opponent: driver)
                viewModel = vm
                await vm.start()
                return
            }
            await controller.send(.ucinewgame)
            engine = controller
        }

        guard let engine else { return }
        let driver = EngineEndgameDriver(engine: engine)
        guard let vm = sessionStore.value(for: sessionKey, make: {
            EndgameFreeTrainViewModel(course: course, judge: driver, opponent: driver)
        }) else { return }
        // Le VM peut survivre à un moteur mort (retour sur l'écran, ou
        // « Réessayer ») : toujours le rebrancher sur l'instance vivante.
        vm.replaceProviders(judge: driver, opponent: driver)
        viewModel = vm
        if vm.phase == .preparing || vm.phase == .unavailable {
            await vm.start()
        }
    }
}
