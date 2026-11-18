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
        // D'une série ou d'un bilan, la flèche mène aux réglages de Visualisation, pas à l'accueil (retour de
        // l'utilisateur, 18/11/2026) ; ce qui a été répondu reste compté. Un second retour quitte le module.
        .navigationBarBackButtonHidden(viewModel.phase != .setup)
        .toolbar {
            if viewModel.phase != .setup {
                ToolbarItem(placement: .topBarLeading) {
                    Button { withAnimation(Theme.gentle) { viewModel.backToSetup() } } label: {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    }
                    .accessibilityLabel(Text("Retour"))
                    .accessibilityIdentifier("visualizationBack")
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.resume() } else { viewModel.pause() }
        }
        .onDisappear { viewModel.stop() }
    }

    // MARK: Les réglages

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Plus de couleur (retour de l'utilisateur, 18/11/2026) : un en-tête aux teintes des marches.
                HStack(spacing: 14) {
                    IconBadge(systemImage: "eye", tint: Theme.teal, size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voir l'échiquier dans sa tête")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Des exercices sans fin, des cases jusqu'au calcul. Vos erreurs reviennent jusqu'à ce qu'elles soient sues.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.teal.opacity(0.26), Theme.info.opacity(0.14), Theme.violet.opacity(0.10)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.teal.opacity(0.3), lineWidth: 1))

                // Retour de l'utilisateur (18/11/2026) : on ne voyait pas QUELLES marches la série jouerait — une ligne
                // décochée restait aussi vive qu'une cochée. Décochée = éteinte ; cochée = teintée ; et une phrase dit
                // ce que la série mélange.
                sectionTitle("Marches de la série")
                card {
                    ForEach(Array(VisualizationStep.allCases.enumerated()), id: \.element) { index, step in
                        if index > 0 { rowDivider }
                        stepRow(step)
                    }
                }
                Text(seriesMix)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("visualizationMix")

                sectionTitle("Série")
                // Des PASTILLES plutôt que des menus (retour de l'utilisateur, 18/11/2026 : « le sélecteur n'est pas
                // joli ») : toutes les options se voient, le choix est une pastille pleine.
                card {
                    pickerRow("hourglass", "Durée") {
                        SegmentedPills(
                            options: VisualizationSettings.Length.allCases.map { ($0, LocalizationController.string($0.title)) },
                            selection: $viewModel.settings.length, identifier: "visualizationLength"
                        )
                    }
                    rowDivider
                    settingRow("arrow.up.arrow.down", "Vu des Noirs") {
                        Toggle("", isOn: $viewModel.settings.fromBlack).labelsHidden().tint(Theme.accent)
                            .accessibilityIdentifier("visualizationFromBlack")
                    }
                    rowDivider
                    pickerRow("timer", "Chrono par question") {
                        VStack(alignment: .leading, spacing: 8) {
                            SegmentedPills(
                                options: [(Int?.none, LocalizationController.string("Sans"))]
                                    + VisualizationSettings.secondsChoices.map {
                                        (Int?.some($0), LocalizationController.string(VisualizationSettings.timerTitle($0)))
                                    },
                                selection: $viewModel.settings.secondsPerQuestion, identifier: "visualizationTimer"
                            )
                            if let base = viewModel.settings.secondsPerQuestion {
                                Text(LocalizationController.string(
                                    "Le chrono grandit avec la marche : %lld s pour une case, %lld s pour une position.",
                                    base * VisualizationStep.squares.number, base * VisualizationStep.position.number))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("visualizationTimerScale")
                            }
                        }
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

    /// « La série mélange : Les lignes, Suivre les pièces. »
    private var seriesMix: String {
        let names = VisualizationStep.allCases.filter { viewModel.settings.steps.contains($0) }
            .map { LocalizationController.string($0.title) }
        return LocalizationController.string("La série mélange : %@.", names.joined(separator: ", "))
    }

    private func stepRow(_ step: VisualizationStep) -> some View {
        let isOn = viewModel.settings.steps.contains(step)
        return Button {
            withAnimation(Theme.snappySpring) { viewModel.toggle(step) }
        } label: {
            HStack(spacing: 12) {
                Text(verbatim: "\(step.number)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(isOn ? Theme.background : Theme.textTertiary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(isOn ? step.tint : Color.white.opacity(0.06)))
                    .overlay(Circle().strokeBorder(isOn ? Color.clear : Theme.stroke, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(step.title))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isOn ? Theme.textPrimary : Theme.textTertiary)
                    Text(LocalizedStringKey(step.detail))
                        .font(.caption)
                        .foregroundStyle(isOn ? Theme.textSecondary : Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if let accuracy = viewModel.stats.accuracy(for: step) {
                    Text(verbatim: "\(accuracy) %")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(isOn ? Theme.textSecondary : Theme.textTertiary)
                }
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? step.tint : Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isOn ? step.tint.opacity(0.12) : Color.clear)
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
        VStack(spacing: 10) {
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
            progressDots
        }
    }

    /// Une pastille par question : verte juste, rouge ratée, blanche en cours, éteinte à venir.
    private var progressDots: some View {
        let answered = viewModel.answered
        let total = viewModel.settings.length.questionCount ?? (answered.count + 1)
        let shown = viewModel.settings.length.questionCount == nil ? Array(max(0, total - 20)..<total) : Array(0..<total)
        return HStack(spacing: 4) {
            ForEach(shown, id: \.self) { i in
                Capsule()
                    .fill(i < answered.count
                          ? (answered[i].isCorrect ? Theme.accent : Theme.danger)
                          : (i == answered.count ? Color.white.opacity(0.85) : Color.white.opacity(0.12)))
                    .frame(maxWidth: viewModel.settings.length.questionCount == nil ? 10 : .infinity)
                    .frame(height: 6)
            }
            if viewModel.settings.length.questionCount == nil { Spacer(minLength: 0) }
        }
        .animation(Theme.snappySpring, value: answered.count)
        .accessibilityHidden(true)
    }

    private func questionView(_ q: VisualizationQuestion) -> some View {
        let tint = q.kind.step.tint
        let frame: Color = viewModel.feedback.map { $0.isCorrect ? Theme.accent : Theme.danger } ?? tint.opacity(0.35)
        return VStack(spacing: 16) {
            VStack(spacing: 14) {
                Label(LocalizedStringKey(q.kind.title), systemImage: q.kind.step.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.16), in: Capsule())
                if !sceneRows(q).isEmpty { scene(q) }
                Text(prompt(q))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("visualizationPrompt")
                if let fraction = viewModel.questionTimeFraction {
                    GeometryReader { geometry in
                        Capsule().fill(Color.white.opacity(0.1))
                            .overlay(alignment: .leading) {
                                Capsule().fill(fraction < 0.3 ? Theme.danger : tint)
                                    .frame(width: geometry.size.width * fraction)
                            }
                    }
                    .frame(height: 5)
                    .accessibilityHidden(true)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.24), Theme.surfaceElevated],
                                         startPoint: .top, endPoint: .bottom))
            }
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(frame, lineWidth: viewModel.feedback == nil ? 1 : 2))
            .animation(Theme.snappySpring, value: viewModel.feedback)

            if q.kind.step == .calculation { calculationBoard(q) }
            else if q.kind.usesBoard { board(q) }

            if !q.choices.isEmpty { choices(q) }

            feedbackLine(q)
                .frame(minHeight: 24)
        }
    }

    /// Marche 5 : la position du puzzle, montrée le temps de la mémoriser ; puis le plateau CACHÉ, où l'on joue le coup
    /// en touchant départ et arrivée. Après la réponse, les pièces reviennent et la bonne réponse est fléchée.
    @ViewBuilder
    private func calculationBoard(_ q: VisualizationQuestion) -> some View {
        let memorizing = viewModel.isMemorizing
        let shown = memorizing ? VisualizationCalc.board(after: q, plies: 0) : VisualizationCalc.board(after: q)
        let side = VisualizationCalc.sideToFind(q)
        let revealed = viewModel.feedback != nil
        let hint: [HintMove] = {
            guard revealed, case let .move(lan) = q.answer, lan.count >= 4 else { return [] }
            return [HintMove(rank: 1, from: Square(String(lan.prefix(2))), to: Square(String(lan.dropFirst(2).prefix(2))), strength: 1)]
        }()
        VStack(spacing: 14) {
            ChessBoardView(
                board: shown ?? Self.emptyBoard,
                orientation: side,
                theme: AppSettings.shared.boardTheme,
                selectedSquare: viewModel.selectedFrom.map { Square($0.notation) },
                legalTargetSquares: [], lastMove: nil, hintMoves: hint,
                interactionEnabled: !memorizing && !revealed,
                showCoordinates: true,
                onTapSquare: { square in
                    guard let tapped = VisualizationSquare(square.notation) else { return }
                    viewModel.tapCalculationSquare(tapped)
                },
                onDropPiece: { _, _ in },
                pieceMask: memorizing || revealed ? .none : .hidden([.white, .black])
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 420)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            // Un conteneur porte l'identifiant : posé sur le plateau, il se recopiait sur ses 64 cases.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("visualizationBoard")

            if memorizing {
                Button { withAnimation(Theme.gentle) { viewModel.hidePosition() } } label: {
                    Label("J'ai mémorisé", systemImage: "eye.slash")
                        .font(.headline)
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(q.kind.step.tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("visualizationHide")
            }
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
        .accessibilityElement(children: .contain)
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
        let stepTint = q.kind.step.tint
        return Button {
            viewModel.answer(choice)
        } label: {
            HStack(spacing: 8) {
                if let piece = piece(for: choice, in: q) {
                    pieceImage(piece, size: 28)
                    if case .square = choice {
                        Text(verbatim: piece.square.notation).font(.title3.weight(.semibold))
                    }
                } else if choice == .light || choice == .dark {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(choice == .light ? AppSettings.shared.boardTheme.lightSquare : AppSettings.shared.boardTheme.darkSquare)
                        .frame(width: 18, height: 18)
                }
                if piece(for: choice, in: q) == nil {
                    Text(answerLabel(choice, in: q))
                        .font(.title3.weight(.semibold))
                }
            }
            .foregroundStyle(tint ?? Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceElevated)
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill((tint ?? stepTint).opacity(tint == nil ? 0.10 : 0.18))
            }
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint ?? stepTint.opacity(0.32), lineWidth: tint == nil ? 1 : 2))
        }
        .buttonStyle(.pressable)
        .disabled(feedback != nil)
        .accessibilityLabel(Text(verbatim: answerLabel(choice, in: q)))
        .accessibilityIdentifier("visualizationChoice_\(Self.identifier(choice))")
    }

    @ViewBuilder
    private func feedbackLine(_ q: VisualizationQuestion) -> some View {
        if let feedback = viewModel.feedback {
            Group {
                if feedback.isCorrect {
                    Label("Juste", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                } else if feedback.given == nil {
                    Label("Temps écoulé — la réponse : \(answerLabel(q.answer, in: q))", systemImage: "timer")
                        .foregroundStyle(Theme.danger)
                } else {
                    Label("Non — la réponse : \(answerLabel(q.answer, in: q))", systemImage: "xmark.circle.fill")
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
                scoreRing
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                if !viewModel.summaryByKind.isEmpty {
                    sectionTitle("Par exercice")
                    card {
                        ForEach(Array(viewModel.summaryByKind.enumerated()), id: \.offset) { index, row in
                            if index > 0 { rowDivider }
                            HStack(spacing: 10) {
                                Circle().fill(row.kind.step.tint).frame(width: 8, height: 8)
                                Text(LocalizedStringKey(row.kind.title)).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Capsule().fill(Color.white.opacity(0.1))
                                    .frame(width: 56, height: 6)
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(row.kind.step.tint)
                                            .frame(width: 56 * CGFloat(row.correct) / CGFloat(max(row.total, 1)), height: 6)
                                    }
                                Text(verbatim: "\(row.correct) / \(row.total)")
                                    .monospacedDigit()
                                    .foregroundStyle(row.correct == row.total ? Theme.accent : Theme.textSecondary)
                                    .frame(minWidth: 44, alignment: .trailing)
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
                                if !sceneRows(item.question).isEmpty { scene(item.question, compact: true) }
                                Text(prompt(item.question))
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 12) {
                                    HStack(spacing: 4) {
                                        Text("Réponse :")
                                        answerInline(item.question.answer, in: item.question)
                                    }
                                    .foregroundStyle(Theme.accent)
                                    if let given = item.given {
                                        HStack(spacing: 4) {
                                            Text("Vous :")
                                            answerInline(given, in: item.question)
                                        }
                                        .foregroundStyle(Theme.danger)
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

    /// Le score dans un anneau : la part de justes, en dégradé.
    private var scoreRing: some View {
        let total = viewModel.answered.count
        let ratio = total == 0 ? 0 : Double(viewModel.correctCount) / Double(total)
        return ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 12)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(AngularGradient(colors: [Theme.teal, Theme.accent, Theme.teal], center: .center),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(verbatim: "\(viewModel.correctCount) / \(total)")
                    .font(.system(size: 38, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("visualizationSummaryScore")
                Text(viewModel.settings.length == .oneMinute ? "justes en une minute"
                     : viewModel.settings.length == .twoMinutes ? "justes en deux minutes" : "justes")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 180, height: 180)
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
        case .pathCheck:
            return LocalizationController.string("Chacun de ces coups est-il possible ?")
        case .attackAfter:
            return LocalizationController.string("La pièce attaque-t-elle %@ ?", s[0])
        case .twoPieces:
            return LocalizationController.string("Quelle pièce attaque %@ ?", s[0])
        case .isCheck:
            return LocalizationController.string("Les Blancs font-ils échec au roi noir ?")
        case .hangingPiece:
            return LocalizationController.string("Quelle pièce noire est en prise ?")
        case .squareAttacked:
            return LocalizationController.string("La case %@ est-elle attaquée par les Blancs ?", s[0])
        case .memorizePlay, .calculateNext:
            if viewModel.isMemorizing && q == viewModel.question {
                return LocalizationController.string("Mémorisez la position, puis cachez-la.")
            }
            let white = VisualizationCalc.sideToFind(q) == .white
            if q.kind == .memorizePlay {
                return LocalizationController.string(white ? "Trait aux Blancs : jouez le meilleur coup, de mémoire."
                                                           : "Trait aux Noirs : jouez le meilleur coup, de mémoire.")
            }
            return LocalizationController.string("Après %@, jouez le coup suivant, de mémoire.", givenLine(q))
        }
    }

    /// « 1. Fxf7+ Rxf7 » : les coups donnés par l'énoncé, numérotés, dans la notation de l'utilisateur.
    private func givenLine(_ q: VisualizationQuestion) -> String {
        guard let position = Position(fen: q.puzzleFEN ?? "") else { return "" }
        let sans = SANFormatter.display(VisualizationCalc.givenSANs(q))
        var number = position.clock.fullmoves
        var white = position.sideToMove == .white
        var parts: [String] = []
        for (index, san) in sans.enumerated() {
            if white { parts.append("\(number). \(san)") }
            else if index == 0 { parts.append("\(number)… \(san)") }
            else { parts.append(san) }
            if !white { number += 1 }
            white.toggle()
        }
        return parts.joined(separator: " ")
    }

    /// Ce que l'exercice met en scène : un trajet, deux pièces et leurs coups, une position. Les pièces sont les
    /// IMAGES du jeu de pièces de l'app — les caractères ♘ sortaient minuscules dans la police système.
    private enum SceneRow: Hashable {
        case path(VisualizationPiece, [VisualizationSquare])
        case pieces(title: String, [VisualizationPiece])
    }

    private func sceneRows(_ q: VisualizationQuestion) -> [SceneRow] {
        switch q.kind {
        case .pathCheck, .attackAfter:
            guard let first = q.moves.first else { return [] }
            return [.path(first, q.moves.map(\.square))]
        case .twoPieces:
            return [.pieces(title: LocalizationController.string("Départ :"), q.pieces),
                    .pieces(title: LocalizationController.string("Coups :"), q.moves)]
        case .isCheck, .hangingPiece, .squareAttacked:
            return [.pieces(title: LocalizationController.string("Blancs :"), q.pieces.filter(\.isWhite)),
                    .pieces(title: LocalizationController.string("Noirs :"), q.pieces.filter { !$0.isWhite })]
        default:
            return []
        }
    }

    private func scene(_ q: VisualizationQuestion, compact: Bool = false) -> some View {
        let glyph: CGFloat = compact ? 20 : 30
        return VStack(alignment: .leading, spacing: compact ? 4 : 10) {
            ForEach(sceneRows(q), id: \.self) { row in
                switch row {
                case let .path(piece, squares):
                    HStack(spacing: 6) {
                        pieceImage(piece, size: glyph)
                        Text(verbatim: squares.map(\.notation).joined(separator: " → "))
                    }
                case let .pieces(title, pieces):
                    HStack(spacing: 10) {
                        Text(verbatim: title).foregroundStyle(Theme.textSecondary)
                        ForEach(pieces, id: \.self) { piece in
                            HStack(spacing: 1) {
                                pieceImage(piece, size: glyph)
                                Text(verbatim: piece.square.notation)
                            }
                        }
                    }
                }
            }
        }
        .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
        .foregroundStyle(Theme.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 0 : 14)
        .background(compact ? Color.clear : Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: sceneDescription(q)))
        .accessibilityIdentifier(compact ? "" : "visualizationScene")
    }

    /// Pour le lecteur d'écran : les figurines, qu'il sait nommer.
    private func sceneDescription(_ q: VisualizationQuestion) -> String {
        sceneRows(q).map { row in
            switch row {
            case let .path(piece, squares): piece.figurine + " " + squares.map(\.notation).joined(separator: ", ")
            case let .pieces(title, pieces): title + " " + pieces.map(\.label).joined(separator: ", ")
            }
        }.joined(separator: ". ")
    }

    private func pieceImage(_ piece: VisualizationPiece, size: CGFloat) -> some View {
        let kind: Piece.Kind = switch piece.kind {
        case .king: .king
        case .queen: .queen
        case .rook: .rook
        case .bishop: .bishop
        case .knight: .knight
        case .pawn: .pawn
        }
        return PieceGlyphView(piece: Piece(kind, color: piece.isWhite ? .white : .black, square: .a1),
                              outline: piece.isWhite ? nil : Color.white.opacity(0.85))
            .frame(width: size, height: size)
    }

    /// Une réponse dans une ligne de texte : la pièce en image, sinon le mot.
    @ViewBuilder
    private func answerInline(_ answer: VisualizationAnswer, in q: VisualizationQuestion) -> some View {
        if let piece = piece(for: answer, in: q) {
            HStack(spacing: 1) {
                pieceImage(piece, size: 18)
                if case .square = answer { Text(verbatim: piece.square.notation) }
            }
        } else {
            Text(verbatim: answerLabel(answer, in: q))
        }
    }

    /// La pièce que désigne une réponse (« ♞h6 », « le cavalier »), pour la montrer en image dans le bouton.
    private func piece(for answer: VisualizationAnswer, in q: VisualizationQuestion) -> VisualizationPiece? {
        switch answer {
        case let .square(s): q.pieces.first { $0.square == s }
        case .option("first"): q.pieces.first
        case .option("second"): q.pieces.dropFirst().first
        default: nil
        }
    }

    private func answerLabel(_ answer: VisualizationAnswer, in q: VisualizationQuestion) -> String {
        switch answer {
        case .light: return LocalizationController.string("Claire")
        case .dark: return LocalizationController.string("Foncée")
        case .yes: return LocalizationController.string("Oui")
        case .no: return LocalizationController.string("Non")
        case let .square(s):
            // Une pièce en prise se nomme par sa figurine et sa case.
            if let piece = q.pieces.first(where: { $0.square == s }) { return piece.label }
            return s.notation
        case let .number(n): return "\(n)"
        case let .move(lan):
            if let san = VisualizationCalc.san(of: lan, in: q) { return SANFormatter.display(san) }
            return "\(lan.prefix(2))–\(lan.dropFirst(2).prefix(2))"
        case let .option(name):
            switch name {
            case "first": return q.pieces.first.map(\.figurine) ?? ""
            case "second": return q.pieces.dropFirst().first.map(\.figurine) ?? ""
            case "both": return LocalizationController.string("Les deux")
            default: return LocalizationController.string("Aucune")
            }
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
        case let .option(name): name
        case let .move(lan): lan
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

    /// Un réglage à choix : son titre, et les pastilles dessous, sur toute la largeur.
    private func pickerRow<Control: View>(_ symbol: String, _ title: LocalizedStringKey,
                                          @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)
                Text(title).font(.body).foregroundStyle(Theme.textPrimary)
            }
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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

/// Un choix parmi quelques options, en pastilles : la choisie est pleine (accent), les autres en texte. Une seule
/// pastille glisse de l'une à l'autre.
struct SegmentedPills<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    let identifier: String
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isOn = option.0 == selection
                Button {
                    withAnimation(Theme.snappySpring) { selection = option.0 }
                } label: {
                    Text(verbatim: option.1)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(isOn ? Theme.background : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if isOn {
                                Capsule().fill(Theme.accent).matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: option.1))
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("\(identifier)_\(index)")
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.black.opacity(0.28)))
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

/// La couleur et le symbole d'une marche (18/11/2026 : « colore un peu mieux l'interface ») — une seule à l'écran
/// à la fois pendant la série.
extension VisualizationStep {
    var tint: Color {
        switch self {
        case .squares: Theme.teal
        case .lines: Theme.info
        case .pieces: Theme.violet
        case .position: Theme.gold
        case .calculation: Theme.rose
        }
    }

    var symbol: String {
        switch self {
        case .squares: "square.grid.3x3"
        case .lines: "line.diagonal"
        case .pieces: "point.topleft.down.to.point.bottomright.curvepath"
        case .position: "eye"
        case .calculation: "brain.head.profile"
        }
    }
}
