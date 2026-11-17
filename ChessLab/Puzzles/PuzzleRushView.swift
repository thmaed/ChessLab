import ChessKit
import SwiftUI

/// « Contre la montre » (17/11/2026). Lisibilité d'abord : la règle en une phrase avant de commencer, un
/// seul élément en gros pendant la série (le chrono), un seul chiffre au bilan.
struct PuzzleRushView: View {
    @Bindable var viewModel: PuzzleRushViewModel
    let onExit: () -> Void
    /// Un raté du bilan, ouvert dans l'Analyse.
    var onAnalyze: (String) -> Void = { _ in }

    @State private var appSettings = AppSettings.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            switch viewModel.phase {
            case .intro:
                intro
            case .finished:
                summary
            case .countdown, .playing, .paused:
                if horizontalSizeClass == .regular {
                    GeometryReader { geo in
                        if geo.size.width > geo.size.height { wideRun } else { narrowRun }
                    }
                } else {
                    narrowRun
                }
            }
        }
        .appBackground()
        .navigationTitle("Contre la montre")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay { promotionOverlay }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.pause() }
        }
        .onDisappear { viewModel.pause() }
    }

    // MARK: Avant

    private var intro: some View {
        ScrollView {
            VStack(spacing: 22) {
                IconBadge(systemImage: "stopwatch.fill", tint: Theme.rose, size: 64)
                    .padding(.top, 24)
                Text("Contre la montre")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("3 minutes. Chaque puzzle trouvé compte un point. Trois erreurs et c'est fini.")
                    .font(.title3)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("rushRule")
                Text("Les puzzles deviennent plus difficiles à chaque réussite. Pas d'indice, un seul essai par puzzle.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if viewModel.previousBest > 0 {
                    Text("Votre record : \(viewModel.previousBest)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }
                if viewModel.isUnavailable {
                    Text("La bibliothèque de puzzles n'est pas encore prête.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.warning)
                        .multilineTextAlignment(.center)
                } else {
                    primaryButton("Commencer", identifier: "rushStart") { viewModel.begin() }
                }
            }
            .padding(24)
            .frame(maxWidth: Theme.readableWidth)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Pendant

    private var narrowRun: some View {
        VStack(spacing: 14) {
            hud
                .padding(.horizontal, 20)
            boardArea
                .padding(.horizontal, 16)
            sideToMove
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private var wideRun: some View {
        HStack(spacing: 0) {
            boardArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
            VStack(spacing: 22) {
                hud
                sideToMove
            }
            .padding(24)
            .frame(minWidth: 280, maxWidth: 360)
        }
    }

    /// Le chrono en gros, le score, les trois erreurs possibles.
    private var hud: some View {
        HStack(alignment: .center) {
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                let remaining = viewModel.phase == .countdown(3) || viewModel.phase == .countdown(2)
                    || viewModel.phase == .countdown(1) ? viewModel.run.duration : viewModel.remaining()
                Text(Self.clock(remaining))
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(remaining <= 10 ? Theme.rose : Theme.textPrimary)
                    .contentTransition(.numericText())
                    .accessibilityLabel(Text("Temps restant"))
                    .accessibilityValue(Text(Self.spokenClock(remaining)))
                    .accessibilityIdentifier("rushClock")
            }
            Spacer()
            VStack(spacing: 0) {
                Text("\(viewModel.score)")
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                    .animation(Theme.spring, value: viewModel.score)
                Text("trouvés")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
            }
            .overlay(alignment: .top) { flashBadge }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("rushScore")
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<PuzzleRushRun.maxErrors, id: \.self) { index in
                    Image(systemName: index < viewModel.errors ? "xmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(index < viewModel.errors ? Theme.rose : Theme.textTertiary)
                }
            }
            .animation(Theme.spring, value: viewModel.errors)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Erreurs : \(viewModel.errors) sur \(PuzzleRushRun.maxErrors)"))
            .accessibilityIdentifier("rushErrors")
        }
    }

    /// « +1 » qui monte et s'efface, ou rien : la croix rouge suffit pour une erreur.
    @ViewBuilder private var flashBadge: some View {
        if let flash = viewModel.flash, flash.solved {
            FlashUp(id: flash.id)
        }
    }

    @ViewBuilder private var boardArea: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                switch viewModel.phase {
                case let .countdown(value):
                    RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceElevated)
                    Text("\(value)")
                        .font(.system(size: 120, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .id(value)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityIdentifier("rushCountdown")
                case .paused:
                    RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceElevated)
                    VStack(spacing: 16) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(Theme.textSecondary)
                        Text("En pause")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Le temps est arrêté et le plateau masqué.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                        primaryButton("Reprendre", identifier: "rushResume") { viewModel.resume() }
                            .frame(maxWidth: 240)
                    }
                    .padding(24)
                default:
                    board
                }
            }
            .animation(.spring(duration: 0.3), value: viewModel.phase)
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var board: some View {
        ChessBoardView(
            board: viewModel.board,
            orientation: viewModel.orientation,
            theme: appSettings.boardTheme,
            selectedSquare: viewModel.selectedSquare,
            legalTargetSquares: viewModel.legalTargetSquares,
            lastMove: viewModel.lastMove,
            hintMoves: viewModel.hintMoves,
            interactionEnabled: viewModel.acceptsInput,
            showCoordinates: true,
            draggableColor: viewModel.board.position.sideToMove,
            rejectedMove: viewModel.rejectedMove,
            onRejectedAnimationEnd: { viewModel.finishRejectedAttempt() },
            onTapSquare: { viewModel.selectSquare($0) },
            onDropPiece: { viewModel.attemptMove(from: $0, to: $1) }
        )
        .accessibilityIdentifier("rushBoard")
    }

    @ViewBuilder private var sideToMove: some View {
        if viewModel.phase == .playing {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.orientation == .white ? Color.white : Color.black)
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                    .frame(width: 14, height: 14)
                Text(viewModel.orientation == .white ? "Trait aux blancs" : "Trait aux noirs")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Après

    private var summary: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("\(viewModel.score)")
                    .font(.system(size: 96, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 20)
                    .accessibilityIdentifier("rushFinalScore")
                Text(LocalizationController.isSingular(viewModel.score) ? "puzzle trouvé" : "puzzles trouvés")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, -14)
                if viewModel.isNewRecord {
                    Label(viewModel.previousBest > 0
                          ? LocalizationController.string("Nouveau record ! (avant : %lld)", viewModel.previousBest)
                          : LocalizationController.string("Premier record !"),
                          systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.gold)
                        .accessibilityIdentifier("rushNewRecord")
                } else if viewModel.previousBest > 0 {
                    Text("Votre record : \(viewModel.previousBest)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                if let highest = viewModel.run.highestSolvedRating {
                    Text("Plus difficile trouvé : \(highest)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.textTertiary)
                }
                HStack(spacing: 12) {
                    secondaryButton("Terminer", identifier: "rushDone", action: onExit)
                    primaryButton("Rejouer", identifier: "rushAgain") { viewModel.begin() }
                }
                .padding(.top, 6)
                if !viewModel.missed.isEmpty { missedSection }
            }
            .padding(24)
            .frame(maxWidth: Theme.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .overlay { if viewModel.isNewRecord { CelebrationView() } }
    }

    /// Les ratés, avec leur solution : on apprend ici, pas pendant la course.
    private var missedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.missed.count == 1 ? "Votre raté" : "Vos ratés")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)
            ForEach(viewModel.missed) { item in
                Button { onAnalyze(item.fen) } label: {
                    HStack(spacing: 14) {
                        MiniBoardView(fen: item.fen, flipped: !item.whiteToMove)
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.whiteToMove ? "Trait aux blancs" : "Trait aux noirs")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                            Text(verbatim: item.solution)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Analyser")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(padding: 12)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("rushMissed")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    // MARK: Pièces

    private func primaryButton(_ title: LocalizedStringKey, identifier: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.accentGradient, in: Theme.cardShape)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(identifier)
    }

    private func secondaryButton(_ title: LocalizedStringKey, identifier: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.surfaceElevated, in: Theme.cardShape)
                .overlay(Theme.cardShape.strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var promotionOverlay: some View {
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

    /// « 2:41 ».
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// « 2 min 41 s », pour VoiceOver.
    static func spokenClock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .short
        formatter.calendar?.locale = Locale(identifier: LocalizationController.activeLanguageCode)
        return formatter.string(from: TimeInterval(total)) ?? "\(total)"
    }
}

/// « +1 » qui monte de quelques points et s'efface.
private struct FlashUp: View {
    let id: Int
    @State private var shown = false

    var body: some View {
        Text(verbatim: "+1")
            .font(.headline.weight(.heavy))
            .foregroundStyle(Theme.accent)
            .offset(y: shown ? -34 : -10)
            .opacity(shown ? 0 : 1)
            .id(id)
            .onAppear {
                shown = false
                withAnimation(.easeOut(duration: 0.7)) { shown = true }
            }
            .onChange(of: id) { _, _ in
                shown = false
                withAnimation(.easeOut(duration: 0.7)) { shown = true }
            }
            .accessibilityHidden(true)
    }
}
