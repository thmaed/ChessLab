import ChessKit
import CoreGraphics
import Foundation
import UIKit

/// Injection d'une image de test dans le scanner, via l'argument de
/// lancement `-scanTestImage <nom>`.
///
/// Raison d'être : les sélecteurs système (photothèque, appareil photo) sont
/// des processus SÉPARÉS, hors de portée de XCUITest. Sans cette porte
/// dérobée, le parcours « image → position jouée » — critère d'acceptation
/// de l'étape 7 — ne serait testable que manuellement.
///
/// Trois formes de `<nom>` :
/// - `fen:<FEN>` (ou `synthetic`) : diagramme numérique rendu à la volée,
///   sans aucun fichier — la vérité attendue est dans le nom même ;
/// - tout autre nom : image du bundle de l'app (fixture réelle, p. ex. une
///   capture Lichess déposée dans les assets).
///
/// `-scanSource <ScanSource>` choisit en plus le type de source, que
/// l'utilisateur désignerait d'un chip au premier écran.
enum ScanTestImage {

    private static let argument = "-scanTestImage"
    private static let sourceArgument = "-scanSource"

    /// Position de démonstration : après 1. e4 c5 (Sicilienne). Une position
    /// où toutes les cases ne sont pas symétriques, contrairement à la
    /// position initiale — un décalage de lecture s'y verrait.
    static let syntheticFEN = "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2"

    /// Position de démonstration du plateau réel : une finale, où compléter
    /// les types se fait en trois taps. Sur une position complète, ce serait
    /// 32 taps — un test long sans rien prouver de plus.

    /// Nom demandé au lancement, s'il y en a un.
    static var requestedName: String? {
        value(after: argument)
    }

    /// Type de source demandé, s'il y en a un.
    static var requestedSource: ScanSource? {
        value(after: sourceArgument).flatMap(ScanSource.init(rawValue:))
    }

    private static func value(after flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// Image correspondante, ou `nil` si l'argument est absent/illisible.
    @MainActor
    static func image() -> UIImage? {
        guard let name = requestedName else { return nil }

        if name == "synthetic" { return render(fen: syntheticFEN) }
        if name == "realistic" { return renderRealisticScreenshot(fen: syntheticFEN) }
        if name.hasPrefix("fen:") { return render(fen: String(name.dropFirst(4))) }
        return UIImage(named: name)
    }

    /// Capture d'écran RÉALISTE d'une app d'échecs sur téléphone : PORTRAIT,
    /// plateau pleine largeur qui touche les deux bords, interface chargée
    /// au-dessus et en dessous (liste de coups, joueurs, pièces capturées,
    /// barre d'icônes), coordonnées incrustées dans les cases du bord.
    ///
    /// C'est le cas qui a mis en défaut la première détection automatique,
    /// validée seulement sur des images carrées à large marge — la vraie
    /// capture chess.com de l'utilisateur ne ressemble à rien de tout ça.
    @MainActor
    static func renderRealisticScreenshot(fen: String) -> UIImage? {
        guard let position = Position(fen: fen),
              let board = BoardImageRenderer.renderBoard(position: position, theme: .classic, side: 1206)
        else { return nil }

        let width = 1206.0
        let height = 2622.0
        let boardTop = 700.0
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor(white: 0.13, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            func draw(_ text: String, at point: CGPoint, size: CGFloat, color: UIColor) {
                (text as NSString).draw(at: point, withAttributes: [
                    .font: UIFont.systemFont(ofSize: size, weight: .semibold),
                    .foregroundColor: color
                ])
            }

            // Du TEXTE et des aplats clairs autour du plateau : la détection
            // doit prouver qu'elle ne se laisse pas distraire par l'interface.
            UIColor(white: 0.20, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 240, width: width, height: 90))
            draw("43. gxf4 Be3 44. f5 gxf5 45. exf5 Rf8 46. a7 Kg8",
                 at: CGPoint(x: 20, y: 262), size: 38, color: UIColor(white: 0.85, alpha: 1))
            UIColor(white: 0.35, alpha: 1).setFill()
            context.fill(CGRect(x: 40, y: 420, width: 110, height: 110))
            draw("ChainsawAdv (1148)", at: CGPoint(x: 180, y: 430), size: 40, color: .white)
            // Les pièces capturées : des MINI-glyphes d'échecs hors plateau,
            // le piège le plus vicieux pour un détecteur de damier.
            draw("♟♟♟♟♟ ♞ ♝♝ ♜ ♛ +2", at: CGPoint(x: 180, y: 490), size: 34,
                 color: UIColor(white: 0.8, alpha: 1))

            UIImage(cgImage: board).draw(in: CGRect(x: 0, y: boardTop, width: width, height: width))

            // Coordonnées incrustées dans les cases (comme chess.com ou
            // Lichess) : elles rendent les cases du bord NON plates, ce que le
            // classifieur doit savoir ignorer.
            let square = width / 8
            let light = UIColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 1)
            let dark = UIColor(red: 0.46, green: 0.59, blue: 0.34, alpha: 1)
            for row in 0..<8 {
                draw("\(8 - row)", at: CGPoint(x: 8, y: boardTop + Double(row) * square + 6),
                     size: 30, color: row % 2 == 0 ? dark : light)
            }
            for column in 0..<8 {
                let letter = String(UnicodeScalar(UInt8(97 + column)))
                draw(letter, at: CGPoint(x: Double(column) * square + square - 28, y: boardTop + width - 42),
                     size: 30, color: column % 2 == 0 ? light : dark)
            }

            UIColor(white: 0.35, alpha: 1).setFill()
            context.fill(CGRect(x: 40, y: 2000, width: 110, height: 110))
            draw("madfly7 (1211)", at: CGPoint(x: 180, y: 2010), size: 40, color: .white)
            UIColor(white: 0.22, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 2380, width: width, height: 160))
            for index in 0..<5 {
                UIColor(white: 0.5, alpha: 1).setFill()
                context.fill(CGRect(x: 80 + Double(index) * 230, y: 2420, width: 80, height: 80))
            }
        }
    }

    /// Le plateau est posé sur un fond avec une MARGE, comme dans une vraie
    /// capture d'écran (où il y a toujours une interface autour). Sans elle,
    /// le plateau touche les bords de l'image, Vision n'a aucun bord franc à
    /// détecter et la détection automatique échoue — vérifié à la capture.
    @MainActor
    static func render(fen: String) -> UIImage? {
        guard let position = Position(fen: fen),
              let board = BoardImageRenderer.renderBoard(position: position, theme: .classic, side: 800)
        else { return nil }

        let margin = 100.0
        let canvas = 800.0 + margin * 2
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: CGSize(width: canvas, height: canvas), format: format).image { context in
            UIColor(white: 0.11, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
            UIImage(cgImage: board).draw(in: CGRect(x: margin, y: margin, width: 800, height: 800))
        }
    }
}
