import SwiftUI

// ============================================================================
// La VISITE GUIDÉE en coach marks : un voile sombre percé d'un trou au-dessus
// d'un vrai contrôle, une flèche courbe qui pointe dedans, une carte qui dit
// à quoi il sert.
//
// Tout le système vit dans ce fichier ; les vues existantes ne portent que
// `.discoveryAnchor(_:)` (et `.discoveryAutoScroll(using:)` sur les contenus
// défilants). Les décisions de géométrie sont commentées avec leur raison :
// chacune est le contre-exemple d'un bug déjà payé — dans six mois, la raison
// est la seule chose qui empêchera de « simplifier » vers le bug d'origine.
// ============================================================================

// MARK: - Les cibles (le contrat entre les vues et les étapes)

/// Les contrôles qu'une étape peut viser. JAMAIS de coordonnées en dur : les
/// vues se taguent elles-mêmes, la racine résout. Un contrôle qui bouge
/// emmène son trou ; un contrôle absent de l'état courant perd simplement sa
/// flèche (carte centrée), sans code conditionnel dans les étapes.
enum DiscoverySpot: Hashable {
    case playTile        // tuile « Contre l'ordinateur » (accueil) + entrée latérale
    case strengthSlider  // section « Force du moteur » (réglages de partie)
    case aidToggles      // section « Aides » : indices + barre d'éval
    case analysisLibrary // carte « Bibliothèque » (entrée d'Analyser)
    case recentGames     // section « Parties récentes » (accueil)
    case variantsTile    // tuile « Variantes »
    case puzzlesTile     // tuile « Puzzles »
    case helpButton      // « Aide » — barre latérale iPad/Mac uniquement :
                         // le bouton iPhone vit dans un ToolbarItem UIKit,
                         // d'où les préférences d'ancrage ne remontent pas.
}

/// `[spot: ancre]`. Le `reduce` garde le PLUS PRIORITAIRE, et à priorité
/// égale le dernier écrivain : pendant une transition de navigation, un spot
/// brièvement présent en double se résout sur celui encore à l'écran. La
/// priorité règle le cas iPad où tuile ET entrée de barre latérale du même
/// mode coexistent légitimement — la tuile (priorité 1) gagne toujours,
/// déterministe au lieu de dépendre de l'ordre d'évaluation.
struct DiscoveryAnchorKey: PreferenceKey {
    struct Entry {
        let priority: Int
        let anchor: Anchor<CGRect>
    }
    static var defaultValue: [DiscoverySpot: Entry] { [:] }
    static func reduce(value: inout [DiscoverySpot: Entry], nextValue: () -> [DiscoverySpot: Entry]) {
        for (spot, entry) in nextValue() {
            if let existing = value[spot], existing.priority > entry.priority { continue }
            value[spot] = entry
        }
    }
}

extension View {
    /// Tague un contrôle comme cible possible de la visite. Écrit une
    /// `anchorPreference(.bounds)` et pose `.id(spot)` pour le défilement —
    /// aucun effet de layout.
    func discoveryAnchor(_ spot: DiscoverySpot, priority: Int = 0) -> some View {
        self
            .id(spot)
            .anchorPreference(key: DiscoveryAnchorKey.self, value: .bounds) {
                [spot: DiscoveryAnchorKey.Entry(priority: priority, anchor: $0)]
            }
    }

    /// À poser sur le contenu d'un `ScrollViewReader` : centre la cible de
    /// l'étape courante quand la visite avance (`scrollTo(_, anchor: .center)`).
    /// Les étapes des autres écrans ne défilent rien — `scrollTo` d'un id
    /// absent est un non-événement.
    func discoveryAutoScroll(using proxy: ScrollViewProxy) -> some View {
        modifier(DiscoveryAutoScroll(proxy: proxy))
    }

    /// Variante déclarative pour les composants partagés (sections de
    /// réglages, entrées de barre latérale) : `nil` = aucun effet.
    @ViewBuilder
    func discoveryAnchor(ifPresent spot: DiscoverySpot?, priority: Int = 0) -> some View {
        if let spot {
            discoveryAnchor(spot, priority: priority)
        } else {
            self
        }
    }
}

private struct DiscoveryAutoScroll: ViewModifier {
    let proxy: ScrollViewProxy
    @Environment(\.discoveryTour) private var tour

    func body(content: Content) -> some View {
        content.onChange(of: tour?.currentStepIndex) { _, _ in
            guard let spot = tour?.currentStep?.spot else { return }
            // Petit délai : la navigation de l'étape vient parfois d'être
            // appliquée, et l'écran cible n'a pas encore posé ses ids.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(spot, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Les étapes

/// Où une étape emmène la navigation. La visite PILOTE la navigation : le
/// changement d'écran qui se joue sous les yeux est l'explication — rien n'a
/// besoin de pointer un écran que l'utilisateur vient de voir s'ouvrir.
enum DiscoveryDestination {
    case home, newGame, analysisEntry, openings
}

struct DiscoveryChipItem: Identifiable {
    enum Icon {
        case system(String)
        case glyph(ModeGlyph)
    }
    let id = UUID()
    let icon: Icon
    let label: String
    let tint: Color
}

struct DiscoveryStep: Identifiable {
    let id: Int
    let section: LocalizedStringKey
    /// `nil` = carte centrée sans flèche : la présentation HONNÊTE de ce qui
    /// n'est pas (ou pas taguable) sur cet écran — pas une flèche manquante.
    let spot: DiscoverySpot?
    let destination: DiscoveryDestination
    let title: LocalizedStringKey
    let body: LocalizedStringKey
    var chips: [DiscoveryChipItem] = []
}

// MARK: - Le contrôleur

extension Notification.Name {
    /// Le rejeu depuis l'Aide passe par une notification, pas un singleton :
    /// l'Aide est poussée plus bas dans la pile, la demande doit REMONTER.
    static let replayDiscoveryTour = Notification.Name("ChessLab.replayDiscoveryTour")
}

@Observable
@MainActor
final class DiscoveryTourController {
    private(set) var isActive = false
    private(set) var currentStepIndex = 0

    let steps: [DiscoveryStep] = DiscoveryTourController.buildSteps()

    var currentStep: DiscoveryStep? {
        guard isActive, steps.indices.contains(currentStepIndex) else { return nil }
        return steps[currentStepIndex]
    }

    func start(at index: Int = 0) {
        currentStepIndex = min(max(0, index), steps.count - 1)
        isActive = true
    }

    func advance() {
        if currentStepIndex + 1 < steps.count {
            currentStepIndex += 1
        } else {
            finish()
        }
    }

    func goBack() {
        if currentStepIndex > 0 { currentStepIndex -= 1 }
    }

    /// Passer COMPTE comme vue (la visite reste disponible depuis l'Aide) :
    /// re-proposer une visite déjà refusée est la définition du harcèlement.
    func skip() { finish() }

    private func finish() {
        isActive = false
        DiscoveryTourMemory.markSeen()
    }

    private static func buildSteps() -> [DiscoveryStep] {
        // Les chips dessinent ce qui vit un écran plus loin avec les VRAIS
        // symboles et les VRAIS noms — en prose seule, le lecteur doit nous
        // croire sur parole ; dessinées, il les reconnaîtra en arrivant.
        let playControls: [DiscoveryChipItem] = [
            .init(icon: .system("lightbulb.fill"), label: LocalizationController.string("Indice"), tint: Theme.accent),
            .init(icon: .system("circle.righthalf.filled"), label: LocalizationController.string("Proposer nulle"), tint: Theme.info),
            .init(icon: .system("list.bullet"), label: LocalizationController.string("Coups joués"), tint: Theme.teal),
            .init(icon: .system("chevron.left"), label: LocalizationController.string("Revenir + « Reprendre ici »"), tint: Theme.violet),
            .init(icon: .system("flag.fill"), label: LocalizationController.string("Abandonner"), tint: Theme.warning),
        ]
        var variantChips: [DiscoveryChipItem] = [
            .init(icon: .system("die.face.5.fill"), label: "Chess960", tint: Theme.violet),
        ]
        variantChips += FairyVariant.all.map {
            .init(icon: .system($0.icon), label: $0.shortName, tint: $0.tint)
        }
        variantChips += EngineLegalityVariant.all.map {
            .init(icon: .system($0.icon), label: $0.shortName, tint: $0.tint)
        }
        variantChips.append(.init(
            icon: .system(StolenMoveVariant.shared.icon),
            label: StolenMoveVariant.shared.shortName, tint: StolenMoveVariant.shared.tint
        ))
        variantChips.append(.init(
            icon: .glyph(.duck), label: DuckChessVariant.shared.shortName,
            tint: DuckChessVariant.shared.tint
        ))
        let trainingChips: [DiscoveryChipItem] = [
            .init(icon: .system("puzzlepiece.fill"), label: LocalizationController.string("Puzzles"), tint: Theme.violet),
            .init(icon: .system("books.vertical.fill"), label: LocalizationController.string("Ouvertures"), tint: Theme.warning),
            .init(icon: .system("crown.fill"), label: LocalizationController.string("Finales"), tint: Theme.gold),
        ]

        return [
            // ---- JOUER : d'abord ce que l'utilisateur s'apprête à toucher.
            DiscoveryStep(
                id: 0, section: "Jouer", spot: .playTile, destination: .home,
                title: "Tout part d'ici",
                body: "Cette tuile lance une partie contre l'ordinateur. Les autres attendront la fin de la visite — deux minutes, promis."
            ),
            DiscoveryStep(
                id: 1, section: "Jouer", spot: .strengthSlider, destination: .newGame,
                title: "Réglez votre adversaire",
                body: "De débutant à maître, au curseur ou par préréglages. Le piège du premier soir : jouer sa première partie à pleine force."
            ),
            DiscoveryStep(
                id: 2, section: "Jouer", spot: .aidToggles, destination: .newGame,
                title: "Les aides se choisissent avant",
                body: "Les flèches d'indice et la barre d'évaluation s'activent ici, avant la partie. On les découvre souvent trop tard."
            ),
            // Sans cible : « Commencer » vit dans un ToolbarItem UIKit,
            // hors de portée des préférences d'ancrage — et les contrôles
            // décrits vivent de toute façon UN ÉCRAN PLUS LOIN : c'est le
            // cas d'usage exact des chips.
            DiscoveryStep(
                id: 3, section: "Jouer", spot: nil, destination: .newGame,
                title: "Pendant la partie",
                body: "La barre du bas de l'écran de jeu cache cinq gestes — les voici, pour les reconnaître :",
                chips: playControls
            ),
            // ---- COMPRENDRE : les affichages, ensuite.
            DiscoveryStep(
                id: 4, section: "Comprendre", spot: .analysisLibrary, destination: .analysisEntry,
                title: "Chaque partie s'analyse",
                body: "Courbe d'évaluation, précision, coups en capsules colorées — et la courbe comme les capsules se touchent pour naviguer dans la partie. La bibliothèque garde tout."
            ),
            DiscoveryStep(
                id: 5, section: "Comprendre", spot: .recentGames, destination: .home,
                title: "Le raccourci de l'accueil",
                body: "Vos dernières parties vivent aussi ici : un tap ouvre directement leur analyse, sans passer par la bibliothèque."
            ),
            DiscoveryStep(
                id: 6, section: "Comprendre", spot: nil, destination: .home,
                title: "Partez sans crainte",
                body: "La partie en cours se sauvegarde toute seule. À votre retour, « Reprendre la partie » vous attend en haut de l'accueil."
            ),
            // ---- EXPLORER : les autres écrans, puis le « ? » qui ramène tout.
            DiscoveryStep(
                id: 7, section: "Explorer", spot: nil, destination: .openings,
                title: "La recherche flotte",
                body: "Dans les Ouvertures, le champ de recherche flotte AU-DESSUS de l'arbre. Cherchez, puis fermez le clavier pour toucher les résultats en dessous."
            ),
            DiscoveryStep(
                id: 8, section: "Explorer", spot: .variantsTile, destination: .home,
                title: "Douze façons de jouer",
                body: "Chaque variante explique ses règles sur son écran de réglages — inutile de les connaître d'avance :",
                chips: variantChips
            ),
            DiscoveryStep(
                id: 9, section: "Explorer", spot: .puzzlesTile, destination: .home,
                title: "Trois salles d'entraînement",
                body: "La tactique, le répertoire, et les fins de partie prouvées :",
                chips: trainingChips
            ),
            DiscoveryStep(
                id: 10, section: "Explorer", spot: .helpButton, destination: .home,
                title: "Et pour y revenir",
                body: "Le « ? » en haut de l'accueil rassemble l'aide — et cette visite, à rejouer quand vous voulez."
            ),
        ]
    }
}

extension EnvironmentValues {
    @Entry var discoveryTour: DiscoveryTourController?
}

// MARK: - « Déjà vue » : l'empreinte de l'installation

/// PAS un booléen `hasSeenTour` : UserDefaults voyage dans les sauvegardes
/// iCloud/iTunes, et une restauration sur une app fraîchement installée
/// arriverait avec le drapeau déjà posé — la visite ne se lancerait jamais
/// sur un appareil qui ne l'a réellement jamais montrée.
///
/// On stocke l'EMPREINTE de l'installation : la date de création du conteneur
/// Documents, qu'iOS refait à chaque installation et ne touche plus jamais.
/// La promesse devient littérale : une nouvelle installation montre la
/// visite, à chaque fois ; une mise à jour, qui garde le conteneur, reste
/// silencieuse.
enum DiscoveryTourMemory {
    private static let key = "discoveryTourSeenInstallStamp"

    /// Interne, pas privée : le test qui garantit « l'empreinte existe »
    /// est la seule alarme si un futur conteneur ne la fournit plus.
    static var installStamp: TimeInterval? {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }
        // Le dossier Documents n'est créé qu'à la première ÉCRITURE : sur
        // une installation qui n'a encore rien enregistré — précisément le
        // public de la visite — il peut manquer. On le crée alors : sa date
        // de création devient l'empreinte, avec la même promesse (refaite à
        // chaque installation, plus jamais touchée).
        if !FileManager.default.fileExists(atPath: documents.path) {
            try? FileManager.default.createDirectory(
                at: documents, withIntermediateDirectories: true
            )
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: documents.path)
        return (attributes?[.creationDate] as? Date)?.timeIntervalSince1970
    }

    static var shouldOffer: Bool {
        guard let stamp = installStamp else { return false }
        return UserDefaults.standard.double(forKey: key) != stamp
    }

    static func markSeen() {
        guard let stamp = installStamp else { return }
        UserDefaults.standard.set(stamp, forKey: key)
    }
}

// MARK: - Le voile percé

/// UNE seule `Shape` : le rectangle plein écran + le trou arrondi, remplis en
/// `FillStyle(eoFill: true)`. Pas de `blendMode(.destinationOut)`, pas de
/// groupe de compositing — un seul chemin qui se compose correctement
/// par-dessus n'importe quel fond animé.
///
/// `animatableData` sur le trou est LA raison pour laquelle une suite de
/// marques se lit comme un geste continu plutôt que comme un diaporama :
/// le trou GLISSE d'un contrôle au suivant.
struct DiscoveryScrimShape: Shape {
    var hole: CGRect
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(hole.origin.x, hole.origin.y),
                AnimatablePair(hole.size.width, hole.size.height)
            )
        }
        set {
            hole = CGRect(
                x: newValue.first.first, y: newValue.first.second,
                width: newValue.second.first, height: newValue.second.second
            )
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(Path(roundedRect: hole, cornerRadius: cornerRadius))
        return path
    }
}

// MARK: - La flèche

/// Courbe de Bézier QUADRATIQUE, tête CALCULÉE : la tangente en t=1 vaut
/// (fin − point de contrôle), et les deux barbes sont cette direction tournée
/// de ±28°. Ne jamais supposer la direction : la tête décollerait de la
/// courbe dès que la flèche sort de la carte par un autre côté.
struct DiscoveryArrowShape: Shape {
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint

    func path(in _: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)

        let tangent = CGVector(dx: end.x - control.x, dy: end.y - control.y)
        let length = max(sqrt(tangent.dx * tangent.dx + tangent.dy * tangent.dy), 0.001)
        let direction = CGVector(dx: tangent.dx / length, dy: tangent.dy / length)
        let barbLength: CGFloat = 11
        for degrees in [CGFloat(28), -28] {
            let angle = degrees * .pi / 180
            let rotated = CGVector(
                dx: direction.dx * cos(angle) - direction.dy * sin(angle),
                dy: direction.dx * sin(angle) + direction.dy * cos(angle)
            )
            path.move(to: end)
            path.addLine(to: CGPoint(
                x: end.x - rotated.dx * barbLength,
                y: end.y - rotated.dy * barbLength
            ))
        }
        return path
    }
}

// MARK: - Les chips (Layout maison qui passe à la ligne)

/// Un défilement horizontal cacherait la moitié des options derrière un geste
/// que personne ne sait qu'il faut faire — donc un flux qui REPLIE.
struct DiscoveryChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                anchor: .topLeading, proposal: .unspecified
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct DiscoveryChipView: View {
    let item: DiscoveryChipItem

    var body: some View {
        HStack(spacing: 4) {
            switch item.icon {
            case let .system(name):
                Image(systemName: name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(item.tint)
            case let .glyph(glyph):
                item.tint
                    .frame(width: 13, height: 13)
                    .mask { glyph.view(outlined: false) }
            }
            Text(item.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Theme.surfaceElevated, in: Capsule())
        .overlay(Capsule().strokeBorder(item.tint.opacity(0.45), lineWidth: 1))
    }
}

// MARK: - La carte

private struct DiscoveryCardView: View {
    let step: DiscoveryStep
    let stepNumber: Int
    let stepCount: Int
    let onBack: () -> Void
    let onSkip: () -> Void
    let onNext: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Une BARRE, pas des points : seize points sur 330 pt sont
            // illisibles ; une barre dit la même chose à toute longueur, et
            // le nom de section dit OÙ l'on est — trois courtes visites
            // plutôt qu'une longue.
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(step.section)
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(Theme.accent)
                    Spacer(minLength: 8)
                    Text(verbatim: "\(stepNumber)/\(stepCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.textTertiary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surfaceElevated)
                        Capsule().fill(Theme.accentGradient)
                            .frame(width: geo.size.width * CGFloat(stepNumber) / CGFloat(stepCount))
                    }
                }
                .frame(height: 3)
            }

            Text(step.title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Dynamic Type : aux plus grandes tailles, quatre lignes en font
            // quinze et poussent « Suivant » hors de l'écran — le seul
            // contrôle qui ne doit JAMAIS devenir inatteignable. Un
            // ScrollView inconditionnel prendrait toute la hauteur offerte
            // (carte d'accueil de deux lignes devenue panneau plein écran),
            // et ViewThatFits mesure ici une proposition non bornée (cadre
            // maxHeight: .infinity), donc son choix n'aurait aucun sens. La
            // solution terne et correcte : tester `isAccessibilitySize`, et
            // n'envelopper qu'alors.
            if typeSize.isAccessibilitySize {
                ScrollView {
                    textAndChips
                }
                .frame(maxHeight: 190)
                .scrollBounceBehavior(.basedOnSize)
            } else {
                textAndChips
            }

            HStack(spacing: 10) {
                // Retour dès la deuxième étape.
                if stepNumber > 1 {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(Theme.surfaceElevated, in: Circle())
                    }
                    .accessibilityLabel("Étape précédente")
                }

                // Passer est DANS la carte (flotté au-dessus, il atterrirait
                // sur ce que l'app dessine dessous et se lirait comme un
                // élément de l'app, pas comme une porte de sortie). AMBRE :
                // gris à côté d'un dégradé vif, il se lirait comme une
                // légende ; en couleur d'accent, comme un second
                // « continuer ». La seule chose qu'une visite ne doit jamais
                // faire, c'est paraître inéluctable.
                Button("Passer", action: onSkip)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.warning)
                    .accessibilityIdentifier("discoverySkip")

                Spacer(minLength: 0)

                Button(action: onNext) {
                    Text(stepNumber == stepCount ? "Terminer" : "Suivant")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Theme.accentGradient, in: Capsule())
                }
                .accessibilityIdentifier("discoveryNext")
            }
        }
        .padding(16)
        .frame(maxWidth: 360)
        // Fond ÉMERAUDE sombre, pas la surface des cartes de l'app : sur un
        // écran fait des mêmes gris, la carte de visite se confondait avec
        // le contenu qu'elle commente (retour d'usage sur appareil). La
        // teinte et le liseré au dégradé d'accent la rattachent à l'anneau
        // du trou : tout ce qui est vert-menthe EST la visite.
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.098, green: 0.200, blue: 0.160),
                    Color(red: 0.078, green: 0.125, blue: 0.115),
                ],
                startPoint: .top, endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.accentGradient, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.55), radius: 24, y: 8)
    }

    private var textAndChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(step.body)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !step.chips.isEmpty {
                DiscoveryChipFlow {
                    ForEach(step.chips) { DiscoveryChipView(item: $0) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - L'overlay (monté à la RACINE, au-dessus des colonnes et des barres)

struct DiscoveryTourOverlay: View {
    let tour: DiscoveryTourController
    /// Les ancres RÉSOLUES par l'hôte : `overlayPreferenceValue` doit être
    /// posé sur l'arbre qui ÉCRIT les préférences (la racine de HomeView) —
    /// attaché à une vue de l'overlay lui-même, il lirait un dictionnaire
    /// éternellement vide. C'est l'hôte qui lit, l'overlay qui reçoit.
    let anchors: [DiscoverySpot: DiscoveryAnchorKey.Entry]
    /// Les zones sûres, mesurées par l'hôte AVANT `ignoresSafeArea` : le
    /// reader plein écran de l'overlay les voit à zéro, et la carte
    /// passerait sous la barre d'état (payé, contrainte n°5).
    let safeInsets: EdgeInsets

    /// L'anneau qui respire, piloté par un seul état booléen relancé à
    /// chaque étape : l'œil arrive sur la cible avant que la flèche ait
    /// fini de se dessiner.
    @State private var breathing = false
    @State private var arrowProgress: CGFloat = 0

    var body: some View {
        // Le reader résout les ancres en rectangles ÉCRAN. `.ignoresSafeArea()`
        // dessus : tout le monde partage un seul espace plein écran — ancres,
        // trou, flèche et carte parlent la même langue.
        GeometryReader { geo in
            if let step = tour.currentStep {
                content(
                    step: step,
                    hole: hole(for: step, in: geo),
                    screen: geo.size
                )
                .onChange(of: tour.currentStepIndex, initial: true) { _, _ in
                    arrowProgress = 0
                    withAnimation(.easeOut(duration: 0.55).delay(0.18)) {
                        arrowProgress = 1
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    /// Le rectangle du trou, ou `nil` (étape sans cible, ou cible absente de
    /// l'état courant — même repli honnête, sans code conditionnel).
    private func hole(for step: DiscoveryStep, in geo: GeometryProxy) -> CGRect? {
        guard let spot = step.spot, let entry = anchors[spot] else { return nil }
        return geo[entry.anchor].insetBy(dx: -6, dy: -6)
    }

    @ViewBuilder
    private func content(step: DiscoveryStep, hole: CGRect?, screen: CGSize) -> some View {
        // Étape sans trou : le trou animable file vers un point central de
        // taille nulle, pour que la TRANSITION reste un glissement continu
        // même quand une étape n'a pas de cible.
        let effectiveHole = hole ?? CGRect(
            x: screen.width / 2, y: screen.height / 2, width: 0, height: 0
        )

        ZStack {
            DiscoveryScrimShape(hole: effectiveHole, cornerRadius: 14)
                // 0,68 : assez sombre pour que l'app recule nettement
                // derrière la visite — à 0,62 elles se confondaient.
                .fill(Color.black.opacity(0.68), style: FillStyle(eoFill: true))
                .animation(.easeInOut(duration: 0.45), value: effectiveHole)
                // Le voile ENTIER avance la visite : c'est l'affordance que
                // les gens cherchent avant de trouver le bouton.
                .contentShape(Rectangle())
                .onTapGesture { tour.advance() }

            if let hole {
                rings(around: hole)
                if let geometry = arrowGeometry(hole: hole, screen: screen) {
                    DiscoveryArrowShape(
                        start: geometry.start, control: geometry.control, end: geometry.end
                    )
                    .trim(from: 0, to: arrowProgress)
                    .stroke(
                        Theme.accent,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                    .allowsHitTesting(false)
                }
            }

            card(step: step, hole: hole, screen: screen)
        }
        .onAppear { breathing = true }
    }

    private func rings(around hole: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.accentGradient, lineWidth: 2)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.accent, lineWidth: 2)
                .scaleEffect(breathing ? 1.09 : 1.0)
                .opacity(breathing ? 0 : 0.55)
                .animation(
                    .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                    value: breathing
                )
        }
        .frame(width: hole.width, height: hole.height)
        .position(x: hole.midX, y: hole.midY)
        .allowsHitTesting(false)
    }

    // MARK: Placement de la carte

    private func cardSide(hole: CGRect, screen: CGSize) -> DiscoveryGeometry.CardSide {
        DiscoveryGeometry.side(
            hole: hole, screen: screen,
            topInset: safeInsets.top, bottomInset: safeInsets.bottom
        )
    }

    private func effectiveGap(available: CGFloat) -> CGFloat {
        DiscoveryGeometry.effectiveGap(available: available)
    }

    @ViewBuilder
    private func card(step: DiscoveryStep, hole: CGRect?, screen: CGSize) -> some View {
        let side = hole.map { cardSide(hole: $0, screen: screen) } ?? .centered

        let cardView = DiscoveryCardView(
            step: step,
            stepNumber: tour.currentStepIndex + 1,
            stepCount: tour.steps.count,
            onBack: { tour.goBack() },
            onSkip: { tour.skip() },
            onNext: { tour.advance() }
        )
        // `.id(step.id)` : la carte se REJOUE à chaque étape — sans lui,
        // SwiftUI ne fait que rafraîchir le texte et la transition d'entrée
        // ne se produit qu'une fois.
        .id(step.id)
        // Transition asymétrique : entrée décalée du côté d'où l'on vient
        // (±14 pt) + opacité, sortie en opacité seule — l'entrée raconte le
        // mouvement, la sortie s'efface sans distraire.
        .transition(.asymmetric(
            insertion: .offset(y: side == .above ? -14 : 14).combined(with: .opacity),
            removal: .opacity
        ))

        // Posée avec du PADDING, pas `.position` : la carte reste aussi
        // haute que son texte l'exige — ce qui compte dès qu'il y a
        // plusieurs langues (et Dynamic Type). Le padding du côté OPPOSÉ est
        // un garde-fou d'inset : quoi que gonfle le texte, la carte ne mord
        // ni la barre d'état ni la barre d'accueil.
        switch side {
        case .below:
            let hole = hole!
            let gap = effectiveGap(available: screen.height - safeInsets.bottom - hole.maxY)
            cardView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, hole.maxY + gap)
                .padding(.bottom, safeInsets.bottom + 8)
                .padding(.horizontal, 20)
        case .above:
            let hole = hole!
            let gap = effectiveGap(available: hole.minY - safeInsets.top)
            cardView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, screen.height - hole.minY + gap)
                .padding(.top, safeInsets.top + 8)
                .padding(.horizontal, 20)
        case .centered:
            cardView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.top, safeInsets.top + 8)
                .padding(.bottom, safeInsets.bottom + 8)
                .padding(.horizontal, 20)
        }
    }

    // MARK: Géométrie de la flèche

    private struct ArrowGeometry {
        let start: CGPoint
        let control: CGPoint
        let end: CGPoint
    }

    private func arrowGeometry(hole: CGRect, screen: CGSize) -> ArrowGeometry? {
        let side = cardSide(hole: hole, screen: screen)
        guard side != .centered else { return nil } // carte par-dessus : rien à relier
        let below = side == .below
        let available = below
            ? screen.height - safeInsets.bottom - hole.maxY
            : hole.minY - safeInsets.top
        let gap = effectiveGap(available: available)
        guard gap > 30 else { return nil } // trop court pour se lire comme une flèche

        let bowSign = DiscoveryGeometry.bowSign(holeMidX: hole.midX, screenWidth: screen.width)

        let endY = below ? hole.maxY + 7 : hole.minY - 7
        let startY = below ? hole.maxY + gap - 8 : hole.minY - gap + 8
        let end = CGPoint(x: hole.midX + bowSign * 10, y: endY)
        let start = CGPoint(
            x: min(max(hole.midX + bowSign * 54, 24), screen.width - 24),
            y: startY
        )
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let control = CGPoint(x: mid.x + bowSign * 26, y: mid.y)
        return ArrowGeometry(start: start, control: control, end: end)
    }
}

// MARK: - Géométrie pure (testable)

/// Les deux règles de placement, en fonctions pures : chacune est le
/// contre-exemple d'un bug déjà payé, et un test unitaire est la seule
/// mémoire qui survive aux relectures.
enum DiscoveryGeometry {
    enum CardSide: Equatable {
        case below, above
        /// Aucun côté ne peut loger la carte (cible plus grande que l'écran
        /// moins la réserve) : carte CENTRÉE par-dessus, sans flèche — le
        /// seul rendu qui ne rogne rien et ne ment pas.
        case centered
    }

    /// Réserve de hauteur de carte : texte + chips + boutons aux tailles
    /// ordinaires.
    static let cardReserve: CGFloat = 250

    /// Le côté de la carte est celui qui a le PLUS de place, mesuré DES DEUX
    /// CÔTÉS et NET des zones sûres : `(bas sûr − trou.maxY)` contre
    /// `(trou.minY − haut sûr)`. Deux contre-exemples payés :
    /// - la règle naïve « le trou est-il dans la moitié haute ? » échoue sur
    ///   une cible HAUTE ET GRANDE — son bord bas dépasse le milieu, la carte
    ///   partirait au-dessus dans un vide minuscule ;
    /// - la place mesurée SANS les insets envoyait la carte sous la barre
    ///   d'état dès que la cible était haute (constaté sur la section
    ///   « Force du moteur », qui déborde même de l'écran).
    static func side(
        hole: CGRect, screen: CGSize, topInset: CGFloat, bottomInset: CGFloat
    ) -> CardSide {
        let below = screen.height - bottomInset - hole.maxY
        let above = hole.minY - topInset
        if max(below, above) < cardReserve { return .centered }
        return below >= above ? .below : .above
    }

    /// La flèche cède sa longueur AVANT que la carte cède sa hauteur : une
    /// carte rognée par le bord de l'écran est un bug, une flèche courte n'en
    /// est pas un. Plancher à 22 pt pour que la carte ne COLLE jamais au trou.
    static func effectiveGap(available: CGFloat) -> CGFloat {
        max(22, min(72, available - cardReserve))
    }

    /// Le bow s'incline à l'OPPOSÉ du bord d'écran le plus proche : une
    /// courbe qui sortirait de l'écran se lit comme un pli, pas comme une
    /// courbe. Le seuil est volontairement décentré (0,55) : une cible pile
    /// au centre penche à droite, où l'œil occidental attend la suite.
    static func bowSign(holeMidX: CGFloat, screenWidth: CGFloat) -> CGFloat {
        holeMidX > screenWidth * 0.55 ? -1 : 1
    }
}
