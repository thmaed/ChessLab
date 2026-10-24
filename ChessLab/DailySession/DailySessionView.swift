import SwiftData
import SwiftUI

/// La séance du jour (A5) : les étapes à faire aujourd'hui, dans l'ordre, et
/// la série de jours. Chaque étape ouvre l'écran existant ; en revenant, le
/// plan est relu — une étape est faite quand il n'y a plus rien à y revoir.
struct DailySessionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var plan: DailySessionPlan?

    var onOpenOpenings: () -> Void
    var onOpenPuzzles: (PuzzleSessionFilter) -> Void
    var onOpenEndgame: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let plan {
                    header(plan)
                    ForEach(plan.steps) { step in stepRow(step, plan: plan) }
                }
            }
            .padding(20)
            .frame(maxWidth: Theme.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .appBackground()
        .navigationTitle("Séance du jour")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear(perform: reload)
        .accessibilityIdentifier("dailySessionScreen")
    }

    private func reload() {
        plan = DailySessionBuilder.load(in: modelContext)
    }

    @ViewBuilder
    private func header(_ plan: DailySessionPlan) -> some View {
        HStack(spacing: 14) {
            Image(systemName: plan.isComplete ? "checkmark.seal.fill" : "flame.fill")
                .font(.system(size: 34))
                .foregroundStyle(plan.isComplete ? Theme.accent : Theme.warning)
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.isComplete ? "Séance terminée" : "À faire aujourd'hui")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(Self.streakText(plan.streak))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityIdentifier("dailySessionStreak")
            }
            Spacer()
        }
        .padding(16)
        .cardStyle()
    }

    static func streakText(_ days: Int) -> String {
        switch days {
        case 0: LocalizationController.string("Pas encore de série — commencez aujourd'hui.")
        case 1: LocalizationController.string("1 jour de suite")
        default: LocalizationController.string("%lld jours de suite", days)
        }
    }

    private func stepRow(_ step: DailySessionStep, plan: DailySessionPlan) -> some View {
        let info = Self.info(for: step)
        return Button {
            start(step)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: step.isDone ? "checkmark.circle.fill" : info.icon)
                    .font(.title2)
                    .foregroundStyle(step.isDone ? Theme.accent : info.tint)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(info.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(step.isDone ? info.doneText : info.todoText(step.remaining))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if !step.isDone {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(16)
            .background(info.tint.opacity(step.isDone ? 0.06 : 0.14), in: Theme.cardShape)
            .overlay(Theme.cardShape.strokeBorder(info.tint.opacity(step.isDone ? 0.15 : 0.35), lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .disabled(step.isDone)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dailyStep_\(step.kind.rawValue)")
    }

    private func start(_ step: DailySessionStep) {
        switch step.kind {
        case .openings: onOpenOpenings()
        case .missedPuzzles: onOpenPuzzles(PuzzleSessionFilter(source: nil, missedOnly: true))
        case .ownPuzzles: onOpenPuzzles(PuzzleSessionFilter(source: .ownGames))
        case .endgame:
            guard let id = step.courseID else { return }
            TrainingDays.markEndgameOpened()
            onOpenEndgame(id)
        }
    }

    struct StepInfo {
        let title: String
        let icon: String
        let tint: Color
        let doneText: String
        let todoText: (Int) -> String
    }

    static func info(for step: DailySessionStep) -> StepInfo {
        switch step.kind {
        case .openings:
            StepInfo(
                title: LocalizationController.string("Ouvertures à revoir"), icon: "books.vertical.fill",
                tint: Theme.warning, doneText: LocalizationController.string("Rien à revoir aujourd'hui."),
                todoText: { LocalizationController.string("Positions dues : %lld", $0) })
        case .missedPuzzles:
            StepInfo(
                title: LocalizationController.string("Puzzles à retenter"), icon: "arrow.counterclockwise.circle.fill",
                tint: Theme.violet, doneText: LocalizationController.string("Aucun puzzle raté en attente."),
                todoText: { LocalizationController.string("Puzzles ratés à rejouer : %lld", $0) })
        case .ownPuzzles:
            StepInfo(
                title: LocalizationController.string("Puzzles de vos parties"), icon: "puzzlepiece.extension.fill",
                tint: Theme.accent, doneText: LocalizationController.string("Aucun puzzle de vos parties en attente."),
                todoText: { LocalizationController.string("Puzzles tirés de vos erreurs : %lld", $0) })
        case .endgame:
            StepInfo(
                title: LocalizationController.string("Une finale"), icon: "crown.fill",
                tint: Theme.rose, doneText: LocalizationController.string("Finale du jour ouverte."),
                todoText: { _ in LocalizationController.string("La finale du jour vous attend.") })
        }
    }
}

/// C7 / A5 (2.0) : la « Séance du jour » en tête de l'accueil — ce qu'il reste
/// à faire aujourd'hui et la série de jours. Un tap ouvre la séance. Le plan
/// est lu à l'apparition de l'écran, pas à chaque dessin : il interroge les
/// bases de progression.
struct DailySessionCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var plan: DailySessionPlan?
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Image(systemName: plan?.isComplete == true ? "checkmark.seal.fill" : "flame.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(plan?.isComplete == true ? Theme.accent : Theme.warning)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Séance du jour")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(plan.map(Self.summary) ?? " ")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .accessibilityIdentifier("dailySessionSummary")
                }
                Spacer()
                if let streak = plan?.streak, streak > 0 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.warning)
                        .accessibilityLabel(DailySessionView.streakText(streak))
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(16)
            .background(Theme.warning.opacity(0.14), in: Theme.cardShape)
            .overlay(Theme.cardShape.strokeBorder(Theme.warning.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("dailySessionCard")
        .onAppear { plan = DailySessionBuilder.load(in: modelContext) }
    }

    /// « 12 positions à revoir · 3 puzzles à retenter · une finale », ou le
    /// constat que tout est fait.
    static func summary(_ plan: DailySessionPlan) -> String {
        let parts: [String] = plan.pending.map { step in
            switch step.kind {
            case .openings: LocalizationController.string("Ouvertures : %lld", step.remaining)
            case .missedPuzzles: LocalizationController.string("Puzzles ratés : %lld", step.remaining)
            case .ownPuzzles: LocalizationController.string("Puzzles de vos parties : %lld", step.remaining)
            case .endgame: LocalizationController.string("une finale")
            }
        }
        if parts.isEmpty { return LocalizationController.string("Tout est fait pour aujourd'hui.") }
        let line = parts.joined(separator: " · ")
        return line.prefix(1).uppercased() + line.dropFirst()
    }
}
