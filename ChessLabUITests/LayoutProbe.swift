import XCTest

/// Harnais de mesure de mise en page (Lot 0.2).
///
/// Trois outils, tous fondés sur les `frame` remontées par l'accessibilité —
/// **pas** sur des captures d'écran : en paysage, le simulateur produit une
/// image tournée à 90° dans un cadre resté portrait (piège documenté dans
/// `PROGRESS.md`), donc l'œil ne peut rien juger, alors que les `frame` sont
/// fiables dans les deux orientations.
///
/// 1. ``LayoutTraits`` — les classes de taille et la géométrie réelles de la
///    fenêtre, lues dans le marqueur `layoutTraits` posé par l'app.
/// 2. ``boardRect(in:)`` — le rectangle du plateau, déduit de l'union des
///    cases `square_a8` et `square_h1`, donc sans instrumenter le code
///    applicatif.
/// 3. ``horizontalOverflows(in:)`` — le détecteur générique de débordement
///    de largeur : c'est LUI qui doit attraper les régressions, pas l'œil.

// MARK: - Traits de la fenêtre

/// Relevé des traits de mise en page, tel qu'exposé par ``LayoutTraitsProbe``.
struct LayoutTraits {
    var horizontalSizeClass: String
    var verticalSizeClass: String
    /// Taille de la FENÊTRE (zone sûre + encoches).
    var size: CGSize
    /// Taille de la zone SÛRE, celle réellement offerte au contenu.
    var safeSize: CGSize
    var safeAreaTop: CGFloat
    var safeAreaLeading: CGFloat
    var safeAreaBottom: CGFloat
    var safeAreaTrailing: CGFloat
    var dynamicTypeSize: String
    var raw: String

    var isLandscape: Bool { size.width > size.height }

    /// Largeur réellement disponible au contenu (fenêtre moins les encoches
    /// latérales) — la référence pour juger un débordement.
    var usableWidth: CGFloat { safeSize.width }

    /// Ligne compacte pour le journal de test, récupérée ensuite dans la
    /// sortie `xcodebuild` pour construire le tableau de relevés.
    func logLine(device: String, orientation: String) -> String {
        "TRAITS|\(device)|\(orientation)|\(raw)"
    }
}

enum LayoutProbe {

    /// Lit le marqueur `layoutTraits` (voir ``LayoutTraitsProbe``).
    @MainActor
    static func traits(in app: XCUIApplication, timeout: TimeInterval = 10) throws -> LayoutTraits {
        let marker = app.descendants(matching: .any).matching(identifier: "layoutTraits").firstMatch
        guard marker.waitForExistence(timeout: timeout) else {
            throw LayoutProbeError.markerMissing("layoutTraits")
        }
        guard let raw = marker.value as? String, !raw.isEmpty else {
            throw LayoutProbeError.markerMissing("layoutTraits (valeur vide)")
        }
        return try parse(raw)
    }

    /// Relit le marqueur jusqu'à ce qu'il rapporte l'orientation attendue.
    /// Une rotation demandée à `XCUIDevice` n'est pas instantanée : sans cette
    /// attente, on mesurerait encore la fenêtre d'avant.
    @MainActor
    static func traits(
        in app: XCUIApplication, waitingForLandscape landscape: Bool, timeout: TimeInterval = 10
    ) throws -> LayoutTraits {
        let deadline = Date().addingTimeInterval(timeout)
        var last = try traits(in: app)
        while last.isLandscape != landscape, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            last = try traits(in: app)
        }
        return last
    }

    static func parse(_ raw: String) throws -> LayoutTraits {
        var fields: [String: String] = [:]
        for pair in raw.split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            fields[String(parts[0])] = String(parts[1])
        }
        func number(_ key: String) throws -> CGFloat {
            guard let text = fields[key], let value = Double(text) else {
                throw LayoutProbeError.unparsable(raw)
            }
            return CGFloat(value)
        }
        return LayoutTraits(
            horizontalSizeClass: fields["h"] ?? "?",
            verticalSizeClass: fields["v"] ?? "?",
            size: CGSize(width: try number("w"), height: try number("ht")),
            safeSize: CGSize(width: try number("sw"), height: try number("sh")),
            safeAreaTop: try number("top"),
            safeAreaLeading: try number("leading"),
            safeAreaBottom: try number("bottom"),
            safeAreaTrailing: try number("trailing"),
            dynamicTypeSize: fields["dts"] ?? "?",
            raw: raw
        )
    }

    // MARK: - Mesure du plateau

    /// Rectangle du plateau, sans toucher au code applicatif : l'union de la
    /// case en haut à gauche (`square_a8`) et de celle en bas à droite
    /// (`square_h1`) couvre exactement les 64 cases. Vaut `nil` si aucun
    /// plateau n'est à l'écran.
    ///
    /// Le plateau peut être retourné (côté Noirs) : on prend l'union, qui est
    /// la même dans les deux sens.
    @MainActor
    static func boardRect(in app: XCUIApplication, timeout: TimeInterval = 10) -> CGRect? {
        let first = app.otherElements["square_a8"]
        guard first.waitForExistence(timeout: timeout) else { return nil }
        let second = app.otherElements["square_h1"]
        guard second.exists else { return nil }
        let union = first.frame.union(second.frame)
        return union.isEmpty ? nil : union
    }

    /// Côté du plateau (il est carré : on prend la plus petite dimension de
    /// l'union, la plus grande pouvant inclure un demi-pixel d'arrondi).
    @MainActor
    static func boardSide(in app: XCUIApplication, timeout: TimeInterval = 10) -> CGFloat? {
        guard let rect = boardRect(in: app, timeout: timeout) else { return nil }
        return min(rect.width, rect.height)
    }

    // MARK: - Détecteur de débordement horizontal

    /// Un élément qui sort de la fenêtre par la gauche ou par la droite.
    struct Overflow: CustomStringConvertible {
        var kind: String
        var identifier: String
        var label: String
        var frame: CGRect
        var window: CGRect

        /// De combien de points l'élément dépasse (le pire des deux côtés).
        var amount: CGFloat {
            max(window.minX - frame.minX, frame.maxX - window.maxX)
        }

        var description: String {
            let name = identifier.isEmpty ? label : identifier
            return String(
                format: "%@ « %@ » x=[%.1f…%.1f] hors de [%.1f…%.1f] → %.1f pt dehors",
                kind, name.prefix(60).description,
                frame.minX, frame.maxX, window.minX, window.maxX, amount
            )
        }
    }

    /// Types parcourus par le détecteur. `.other` est volontairement EXCLU :
    /// ce sont les conteneurs (piles, fonds, `Color.clear` de marquage), dont
    /// la largeur ne dit rien de ce que l'utilisateur voit couper. Les cases
    /// du plateau, qui sont des `.other`, se mesurent par ``boardRect(in:)``.
    static let inspectedTypes: [XCUIElement.ElementType] = [
        .staticText, .button, .image, .textField, .secureTextField, .textView,
        .slider, .switch, .segmentedControl, .stepper, .progressIndicator,
        .pageIndicator, .checkBox, .radioButton, .toggle, .link, .picker, .pickerWheel,
    ]

    /// Parcourt les descendants de `app` et retourne ceux qui sortent de la
    /// fenêtre par un côté.
    ///
    /// Deux garde-fous contre les faux positifs :
    /// - tolérance de 0,5 pt (arrondis de rendu) ;
    /// - un élément ENTIÈREMENT hors cadre est ignoré : c'est le contenu
    ///   normal d'un `ScrollView(.horizontal)` (le bon patron, cf. Lot 3.7),
    ///   pas un débordement. Ce qu'on traque, c'est l'élément **coupé** :
    ///   partiellement visible et tranché par le bord de l'écran.
    @MainActor
    static func horizontalOverflows(
        in app: XCUIApplication, tolerance: CGFloat = 0.5, ignoring identifiers: Set<String> = []
    ) -> [Overflow] {
        let window = app.frame
        var found: [Overflow] = []
        for type in inspectedTypes {
            let elements = app.descendants(matching: type).allElementsBoundByAccessibilityElement
            for element in elements {
                let frame = element.frame
                guard frame.width > 0, frame.height > 0 else { continue }
                // Hors du cadre verticalement (au-dessus/au-dessous du pli,
                // ou dans un écran non affiché) : rien à juger.
                guard frame.maxY > window.minY, frame.minY < window.maxY else { continue }
                let overflowsLeft = frame.minX < window.minX - tolerance
                let overflowsRight = frame.maxX > window.maxX + tolerance
                guard overflowsLeft || overflowsRight else { continue }
                // Entièrement dehors → contenu défilable, pas un débordement.
                guard frame.maxX > window.minX, frame.minX < window.maxX else { continue }
                // L'exclusion porte sur l'identifiant OU le libellé : la
                // plupart des vues SwiftUI n'ont pas d'identifiant explicite,
                // et c'est alors leur libellé qui les nomme.
                let identifier = element.identifier
                guard !identifiers.contains(identifier),
                      !identifiers.contains(element.label)
                else { continue }
                found.append(
                    Overflow(
                        kind: String(describing: type), identifier: identifier,
                        label: element.label, frame: frame, window: window
                    )
                )
            }
        }
        return found.sorted { $0.amount > $1.amount }
    }

    /// Échoue le test en listant tout ce qui dépasse.
    @MainActor
    static func assertNoHorizontalOverflow(
        in app: XCUIApplication, context: String,
        ignoring identifiers: Set<String> = [],
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let overflows = horizontalOverflows(in: app, ignoring: identifiers)
        guard !overflows.isEmpty else { return }
        let detail = overflows.map { "  • \($0)" }.joined(separator: "\n")
        XCTFail("Débordement horizontal — \(context) :\n\(detail)", file: file, line: line)
    }
}

enum LayoutProbeError: Error, CustomStringConvertible {
    case markerMissing(String)
    case unparsable(String)

    var description: String {
        switch self {
        case let .markerMissing(name): "Marqueur introuvable : \(name)"
        case let .unparsable(raw): "Relevé illisible : \(raw)"
        }
    }
}
