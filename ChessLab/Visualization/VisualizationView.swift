import ChessKit
import SwiftUI

/// L'écran Visualisation : les réglages (les marches, la série), la série, le bilan. Même langage que
/// « Nouvelle partie » refondue : des cartes aux lignes d'un seul style, UNE couleur d'accent.
struct VisualizationView: View {
    @Bindable var viewModel: VisualizationViewModel
    let onExit: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch viewModel.phase {
            case .setup: setup
            case .playing: playing
            case .finished: summary
            }
        }
        .appBackground()
        .navigationTitle("Visualisation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.resume() } else { viewModel.pause() }
        }
        .onDisappear { viewModel.stop() }
    }

    // MARK: Les réglages

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Voir l'échiquier dans sa tête : des exercices sans fin, des cases jusqu'au calcul. Vos erreurs reviennent jusqu'à ce qu'elles soient sues.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)

                sectionTitle("Les marches")
                card {
                    ForEach(Array(VisualizationStep.allCases.enumerated()), id: \.element) { index, step in
                        if index > 0 { rowDivider }
                        stepRow(step)
                    }
                }

                sectionTitle("Série")
                card {
                    settingRow("number", "Longueur") {
                        Menu {
                            ForEach(VisualizationSettings.Length.allCases) { length in
                                Button {
                                    viewModel.settings.length = length
                                } label: {
                                    if viewModel.settings.length == length {
                                        Label(LocalizedStringKey(length.title), systemImage: "checkmark")
                                    } else {
                                        Text(LocalizedStringKey(length.title))
                                    }
                                }
                            }
                        } label: {
                            menuValue(LocalizedStringKey(viewModel.settings.length.title))
                        }
                        .accessibilityIdentifier("visualizationLengthMenu")
                    }
                    rowDivider
                    settingRow("arrow.up.arrow.down", "Vu des Noirs") {
                        Toggle("", isOn: $viewModel.settings.fromBlack).labelsHidden().tint(Theme.accent)
                            .accessibilityIdentifier("visualizationFromBlack")
                    }
                    rowDivider
                    settingRow("timer", "Chrono par question") {
                        Menu {
                            Button { viewModel.settings.secondsPerQuestion = nil } label: {
                                if viewModel.settings.secondsPerQuestion == nil { Label("Sans", systemImage: "checkmark") }
                                else { Text("Sans") }
                            }
                            ForEach(VisualizationSettings.secondsChoices, id: \.self) { seconds in
                                Button { viewModel.settings.secondsPerQuestion = seconds } label: {
                                    if viewModel.settings.secondsPerQuestion == seconds {
                                        Label("\(seconds) s", systemImage: "checkmark")
                                    } else {
                                        Text("\(seconds) s")
                                    }
                                }
                            }
                        } label: {
                            if let seconds = viewModel.settings.secondsPerQuestion {
                                menuValue("\(seconds) s", highlighted: true)
                            } else {
                                menuValue("Sans")
                            }
                        }
                        .accessibilityIdentifier("visualizationTimerMenu")
                    }
                }

                if viewModel.reviewCount > 0 {
                    Label("\(viewModel.reviewCount) question(s) ratée(s) reviendront dans vos séries.",
                          systemImage: "arrow.counterclockwise")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 4)
                        .accessibilityIdentifier("visualizationReview")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(maxWidth: Theme.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .primaryActionBar("Commencer", identifier: "visualizationStart") { viewModel.start() }
    }

    private func stepRow(_ step: VisualizationStep) -> some View {
        let isOn = viewModel.settings.steps.contains(step)
        return Button {
            withAnimation(Theme.snappySpring) { viewModel.toggle(step) }
        } label: {
            HStack(spacing: 12) {
                Text(verbatim: "\(step.number)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(isOn ? Theme.background : Theme.accent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(isOn ? Theme.accent : Theme.accent.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(step.title))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(LocalizedStringKey(step.detail))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if let accuracy = viewModel.stats.accuracy(for: step) {
                    Text(verbatim: "\(accuracy) %")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Theme.accent : Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("visualizationStep_\(step.rawValue)")
    }

    // MARK: La série

    private var playing: some View {
        VStack(spacing: 18) {
            header
            if let question = viewModel.question {
                questionView(question)
                    .id(viewModel.answered.count)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .animation(Theme.gentle, value: viewModel.answered.count)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Arrêter") { viewModel.stop() }
                    .accessibilityIdentifier("visualizationStop")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                if let remaining = viewModel.seriesRemaining {
                    Label(Self.clock(remaining), systemImage: "timer")
                        .monospacedDigit()
                } else if let count = viewModel.settings.length.questionCount {
                    // Le numéro de la question EN COURS : pendant le retour sur une réponse, c'est encore elle.
                    let current = viewModel.feedback == nil ? viewModel.answered.count + 1 : viewModel.answered.count
                    Text(verbatim: "\(min(current, count)) / \(count)")
                        .monospacedDigit()
                        .accessibilityIdentifier("visualizationProgress")
                }
                Spacer()
                Label("\(viewModel.correctCount)", systemImage: "checkmark")
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("visualizationScore")
            }
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
            if let fraction = viewModel.questionTimeFraction {
                GeometryReader { geometry in
                    Capsule().fill(Color.white.opacity(0.1))
                        .overlay(alignment: .leading) {
                            Capsule().fill(fraction < 0.3 ? Theme.danger : Theme.accent)
                                .frame(width: geometry.size.width * fraction)
                        }
                }
                .frame(height: 5)
                .accessibilityHidden(true)
            }
        }
    }

    private func questionView(_ q: VisualizationQuestion) -> some View {
        VStack(spacing: 18) {
            Text(prompt(q))
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, q.kind.usesBoard ? 0 : 24)
                .accessibilityIdentifier("visualizationPrompt")

            if q.kind.usesBoard { board(q) }

            if !q.choices.isEmpty { choices(q) }

            feedbackLine(q)
                .frame(minHeight: 24)
        }
    }

    /// Un plateau vide, sans coordonnées — c'est l'exercice.
    private func board(_ q: VisualizationQuestion) -> some View {
        let target = q.squares[0]
        let showTarget = q.kind == .nameSquare || viewModel.feedback != nil
        return ChessBoardView(
            board: Self.emptyBoard,
            orientation: viewModel.settings.fromBlack ? .black : .white,
            theme: AppSettings.shared.boardTheme,
            selectedSquare: showTarget ? Square(target.notation) : nil,
            legalTargetSquares: [], lastMove: nil, hintMoves: [],
            interactionEnabled: q.kind == .findSquare && viewModel.feedback == nil,
            showCoordinates: false,
            onTapSquare: { square in
                guard let tapped = VisualizationSquare(square.notation) else { return }
                viewModel.answer(.square(tapped))
            },
            onDropPiece: { _, _ in }
        )
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 420)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("visualizationBoard")
    }

    @ViewBuilder
    private func choices(_ q: VisualizationQuestion) -> some View {
        let columns = q.choices.count == 6 ? 3 : 2
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(q.choices, id: \.self) { choice in
                choiceButton(choice, question: q)
            }
        }
    }

    private func choiceButton(_ choice: VisualizationAnswer, question q: VisualizationQuestion) -> some View {
        let feedback = viewModel.feedback
        let isAnswer = choice == q.answer
        let isGiven = feedback?.given == choice
        let tint: Color? = feedback == nil ? nil : (isAnswer ? Theme.accent : (isGiven ? Theme.danger : nil))
        return Button {
            viewModel.answer(choice)
        } label: {
            HStack(spacing: 8) {
                if choice == .light || choice == .dark {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(choice == .light ? AppSettings.shared.boardTheme.lightSquare : AppSettings.shared.boardTheme.darkSquare)
                        .frame(width: 18, height: 18)
                }
                Text(answerLabel(choice))
                    .font(.title3.weight(.semibold))
            }
            .foregroundStyle(tint ?? Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background((tint ?? Theme.surfaceElevated).opacity(tint == nil ? 1 : 0.16),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint ?? Theme.stroke, lineWidth: tint == nil ? 1 : 2))
        }
        .buttonStyle(.pressable)
        .disabled(feedback != nil)
        .accessibilityIdentifier("visualizationChoice_\(Self.identifier(choice))")
    }

    @ViewBuilder
    private func feedbackLine(_ q: VisualizationQuestion) -> some View {
        if let feedback = viewModel.feedback {
            Group {
                if feedback.isCorrect {
                    Label("Juste", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                } else if feedback.given == nil {
                    Label("Temps écoulé — la réponse : \(answerLabel(q.answer))", systemImage: "timer")
                        .foregroundStyle(Theme.danger)
                } else {
                    Label("Non — la réponse : \(answerLabel(q.answer))", systemImage: "xmark.circle.fill")
                        .foregroundStyle(Theme.danger)
                }
            }
            .font(.headline)
            .accessibilityIdentifier("visualizationFeedback")
        }
    }

    // MARK: Le bilan

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 6) {
                    Text(verbatim: "\(viewModel.correctCount) / \(viewModel.answered.count)")
                        .font(.system(size: 48, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityIdentifier("visualizationSummaryScore")
                    Text(viewModel.settings.length == .oneMinute ? "justes en une minute" : "justes")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

                if !viewModel.summaryByKind.isEmpty {
                    sectionTitle("Par exercice")
                    card {
                        ForEach(Array(viewModel.summaryByKind.enumerated()), id: \.offset) { index, row in
                            if index > 0 { rowDivider }
                            HStack {
                                Text(LocalizedStringKey(row.kind.title)).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(verbatim: "\(row.correct) / \(row.total)")
                                    .monospacedDigit()
                                    .foregroundStyle(row.correct == row.total ? Theme.accent : Theme.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 46)
                        }
                    }
                }

                if !viewModel.misses.isEmpty {
                    sectionTitle("À revoir")
                    card {
                        ForEach(Array(viewModel.misses.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { rowDivider }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(prompt(item.question))
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 12) {
                                    Text("Réponse : \(answerLabel(item.question.answer))")
                                        .foregroundStyle(Theme.accent)
                                    if let given = item.given {
                                        Text("Vous : \(answerLabel(given))").foregroundStyle(Theme.danger)
                                    } else {
                                        Text("Temps écoulé").foregroundStyle(Theme.danger)
                                    }
                                }
                                .font(.footnote.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                    Text("Ces questions reviendront dans vos prochaines séries.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .frame(maxWidth: Theme.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .primaryActionBar("Recommencer", systemImage: "arrow.counterclockwise", identifier: "visualizationRestart") {
            viewModel.start()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Réglages") { viewModel.backToSetup() }
                    .accessibilityIdentifier("visualizationSettings")
            }
        }
    }

    // MARK: Les mots

    private func prompt(_ q: VisualizationQuestion) -> String {
        let s = q.squares.map(\.notation)
        switch q.kind {
        case .squareColor:
            return LocalizationController.string("La case %@ est-elle claire ou foncée ?", s[0])
        case .findSquare:
            return LocalizationController.string("Touchez la case %@", s[0])
        case .nameSquare:
            return LocalizationController.string("Quelle est cette case ?")
        case .sameDiagonal:
            return LocalizationController.string("%@ et %@ sont-elles sur la même diagonale ?", s[0], s[1])
        case .lineIntersection:
            let diagonal = q.diagonal?.name ?? ""
            switch q.line {
            case let .file(f):
                return LocalizationController.string("Quelle case est à la fois sur la colonne %@ et sur la diagonale %@ ?",
                                                     VisualizationSquare.fileLetters[f], diagonal)
            case let .rank(r):
                return LocalizationController.string("Quelle case est à la fois sur la rangée %@ et sur la diagonale %@ ?",
                                                     "\(r + 1)", diagonal)
            case nil:
                return ""
            }
        case .knightDistance:
            return LocalizationController.string("En combien de coups un cavalier va-t-il de %@ à %@ ?", s[0], s[1])
        }
    }

    private func answerLabel(_ answer: VisualizationAnswer) -> String {
        switch answer {
        case .light: LocalizationController.string("Claire")
        case .dark: LocalizationController.string("Foncée")
        case .yes: LocalizationController.string("Oui")
        case .no: LocalizationController.string("Non")
        case let .square(s): s.notation
        case let .number(n): "\(n)"
        }
    }

    private static func identifier(_ answer: VisualizationAnswer) -> String {
        switch answer {
        case .light: "light"
        case .dark: "dark"
        case .yes: "yes"
        case .no: "no"
        case let .square(s): s.notation
        case let .number(n): "\(n)"
        }
    }

    static let emptyBoard = Board(position: Position(fen: "8/8/8/8/8/8/8/8 w - - 0 1") ?? .standard)

    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: Briques

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.leading, 4)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private var rowDivider: some View {
        Divider().overlay(Theme.stroke).padding(.leading, 52)
    }

    private func settingRow<Trailing: View>(_ symbol: String, _ title: LocalizedStringKey,
                                            @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            Text(title).font(.body).foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }

    private func menuValue(_ text: LocalizedStringKey, highlighted: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(highlighted ? Theme.accent : Theme.textSecondary)
        .lineLimit(1)
    }
}
