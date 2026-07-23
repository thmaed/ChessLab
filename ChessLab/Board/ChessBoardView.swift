import ChessKit
import SwiftUI

/// Échiquier interactif : drag & drop ET tap-tap, points des coups légaux,
/// surlignage du dernier coup, roi en échec en rouge, coordonnées,
/// orientation réversible.
struct ChessBoardView: View {
    let board: Board
    /// Couleur affichée en bas de l'échiquier.
    let orientation: Piece.Color
    let theme: BoardTheme
    let selectedSquare: Square?
    let legalTargetSquares: [Square]
    let lastMove: Move?
    let hintMoves: [HintMove]
    /// Pastille de qualité posée sur une case — la case d'ARRIVÉE du coup
    /// qui vient d'être joué, en mode Analyser. `nil` partout ailleurs.
    var qualityBadge: (square: Square, quality: MoveQuality)? = nil
    let interactionEnabled: Bool
    let showCoordinates: Bool
    /// Vrai si TOUTES les pièces (les deux couleurs) doivent s'afficher
    /// tournées à 180° — mode Table du jeu à deux, pendant le trait du
    /// joueur assis en face : contrairement à ``orientation``, rien ne
    /// bouge de case (le plateau reste géométriquement fixe), seuls les
    /// glyphes sont tournés pour rester lisibles à l'endroit pour QUI QUE
    /// CE SOIT ait le trait, indépendamment de la couleur des pièces —
    /// voir ``TwoPlayerGameView``. `false` partout ailleurs.
    var allPiecesRotated: Bool = false
    /// Seule couleur dont les pièces peuvent être GLISSÉES ; `nil` = les
    /// deux. Défense en profondeur contre le drag d'une pièce adverse : le
    /// vrai garde est côté view models (`attemptMove`/`attemptUserMove`),
    /// ChessKit ne consultant pas le trait dans `canMove`/`legalMoves`. Ne
    /// concerne QUE le glissement : taper une pièce non glissable reste
    /// transmis (le tap traverse jusqu'à la case sous-jacente, qui le relaie
    /// à `onTapSquare`), donc capturer une pièce adverse au tap-tap continue
    /// de fonctionner.
    var draggableColor: Piece.Color? = nil
    /// Coup FAUX à rejouer visuellement puis annuler (feedback d'un essai
    /// raté de puzzle) : la pièce glisse vers la case, un flash rouge la
    /// signale, puis elle revient toute seule — voir ``rejectedMove`` et
    /// `onRejectedAnimationEnd`. Le `board` réel n'est jamais muté (le VM
    /// ne joue pas le coup faux), toute l'animation vit ici. `nil` partout
    /// ailleurs.
    var rejectedMove: RejectedMove? = nil
    /// Appelé à la fin de l'aller-retour du coup rejeté — le VM décompte
    /// alors l'essai (et révèle la solution au 3e échec).
    var onRejectedAnimationEnd: () -> Void = {}
    let onTapSquare: (Square) -> Void
    let onDropPiece: (Square, Square) -> Void

    /// Un essai raté à signaler. Le `id` (nonce fourni par le VM) garantit
    /// que deux essais identiques (mêmes cases) redéclenchent l'animation.
    struct RejectedMove: Equatable {
        let id: Int
        let from: Square
        let to: Square
    }

    @State private var dragState: DragState?

    // MARK: Animation de rejet (essai raté)
    @State private var rejectAnim: RejectedMove?
    @State private var rejectArrived = false
    @State private var rejectFlash = false

    // MARK: Animation de glissement
    //
    // ChessKit ne conserve pas d'identité de pièce d'un coup à l'autre (une
    // pièce est identifiée par sa case), donc un `ForEach(id: \.square)` ne
    // peut PAS faire glisser une pièce : la case d'origine disparaît, la case
    // d'arrivée apparaît. On garde ce rendu statique, mais au changement de
    // `lastMove` on superpose un glyphe qui glisse de la case de départ à la
    // case d'arrivée (la pièce statique d'arrivée est masquée le temps du
    // glissement). Les coups joués au DRAG ne sont pas animés (la pièce a
    // déjà suivi le doigt) — voir `suppressNextSlide`.
    /// Réglage système « Réduire les animations » (Lot 4.B) : le glissement
    /// des pièces et le flash d'un coup rejeté sont du mouvement décoratif.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var slidingMove: Move?
    @State private var slideArrived = false
    @State private var slideToken = 0
    @State private var suppressNextSlide = false

    private struct DragState {
        let square: Square
        var location: CGPoint
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let squareSize = side / 8

            ZStack(alignment: .topLeading) {
                squaresGrid(squareSize: squareSize)
                highlightsLayer(squareSize: squareSize)

                if showCoordinates {
                    coordinatesLayer(squareSize: squareSize)
                }

                piecesLayer(squareSize: squareSize)
                qualityBadgeLayer(squareSize: squareSize)

                if let slidingMove, let piece = board.position.piece(at: slidingMove.end) {
                    PieceGlyphView(piece: piece)
                        .frame(width: squareSize, height: squareSize)
                        .rotationEffect(pieceRotation)
                        .position(
                            slideArrived
                                ? centerPoint(of: slidingMove.end, squareSize: squareSize)
                                : centerPoint(of: slidingMove.start, squareSize: squareSize)
                        )
                        .allowsHitTesting(false)
                }

                ForEach(hintMoves.sorted { $0.rank > $1.rank }) { hint in
                    ArrowShape(
                        from: centerPoint(of: hint.from, squareSize: squareSize),
                        to: centerPoint(of: hint.to, squareSize: squareSize),
                        widthScale: hint.widthScale
                    )
                    .fill(hint.color)
                    .shadow(color: hint.color.opacity(0.6), radius: hint.rank == 1 ? 4 : 0)
                    .allowsHitTesting(false)
                }

                if let rejectAnim, let piece = board.position.piece(at: rejectAnim.from) {
                    // Flash rouge sur la case d'arrivée du coup faux.
                    Rectangle()
                        .fill(Color.red.opacity(rejectFlash ? 0.45 : 0))
                        .frame(width: squareSize, height: squareSize)
                        .position(centerPoint(of: rejectAnim.to, squareSize: squareSize))
                        .allowsHitTesting(false)
                    // Glyphe fantôme qui glisse départ → arrivée puis revient.
                    PieceGlyphView(piece: piece)
                        .frame(width: squareSize, height: squareSize)
                        .rotationEffect(pieceRotation)
                        .position(
                            rejectArrived
                                ? centerPoint(of: rejectAnim.to, squareSize: squareSize)
                                : centerPoint(of: rejectAnim.from, squareSize: squareSize)
                        )
                        .allowsHitTesting(false)
                }

                if let dragState, let piece = board.position.piece(at: dragState.square) {
                    PieceGlyphView(piece: piece)
                        .frame(width: squareSize, height: squareSize)
                        .rotationEffect(pieceRotation)
                        .position(dragState.location)
                        .allowsHitTesting(false)
                        .shadow(radius: 6)
                }
            }
            .frame(width: side, height: side)
            // Fin liseré sombre + ombre portée douce : détache le plateau
            // du fond et lui donne du relief, sans toucher à sa géométrie
            // (pas de coins arrondis qui rogneraient une pièce en cours de
            // glissement près du bord).
            .overlay(Rectangle().strokeBorder(Color.black.opacity(0.28), lineWidth: 1))
            .shadow(color: .black.opacity(0.38), radius: 16, x: 0, y: 8)
            .coordinateSpace(name: "board")
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        // Clé start→end (et non `Move`) : robuste aux reprises (deux coups
        // consécutifs finissant sur la même case ont des départs différents)
        // sans dépendre de la conformité `Equatable` de `Move`.
        .onChange(of: lastMove.map { "\($0.start.notation)-\($0.end.notation)" }) { _, _ in
            startSlideAnimation()
        }
        .onChange(of: rejectedMove) { _, new in
            if let new { runRejectAnimation(new) }
        }
    }

    /// Fait glisser le coup faux vers sa case (0,22 s), le signale d'un
    /// flash rouge, puis le ramène à sa case d'origine avant de prévenir le
    /// VM (`onRejectedAnimationEnd`) — qui décompte alors l'essai.
    private func runRejectAnimation(_ move: RejectedMove) {
        rejectAnim = move
        rejectArrived = false
        rejectFlash = false
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                rejectArrived = true
            } completion: {
                withAnimation(.easeOut(duration: 0.12)) { rejectFlash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        rejectArrived = false
                        rejectFlash = false
                    } completion: {
                        rejectAnim = nil
                        onRejectedAnimationEnd()
                    }
                }
            }
        }
    }

    /// Déclenche le glissement du dernier coup joué (sauf s'il vient d'un
    /// drag, déjà visuellement déplacé).
    private func startSlideAnimation() {
        guard let move = lastMove else {
            slidingMove = nil
            return
        }
        if suppressNextSlide {
            suppressNextSlide = false
            return
        }
        // « Réduire les animations » (Lot 4.B) : la pièce est POSÉE sur sa
        // case d'arrivée, sans glisser. `slidingMove` reste nil, donc la
        // couche d'animation ne s'en mêle pas et le plateau se redessine
        // simplement à son nouvel état.
        if reduceMotion {
            slidingMove = nil
            return
        }
        slideToken += 1
        let token = slideToken
        slidingMove = move
        slideArrived = false
        // Prochain tick : laisse le glyphe se dessiner à la case de départ
        // avant d'animer vers la case d'arrivée.
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                slideArrived = true
            } completion: {
                if token == slideToken { slidingMove = nil }
            }
        }
    }

    // MARK: Grille

    @ViewBuilder
    private func squaresGrid(squareSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { col in
                        let sq = square(row: row, col: col)
                        Rectangle()
                            .fill(sq.color == .light ? theme.lightSquare : theme.darkSquare)
                            .frame(width: squareSize, height: squareSize)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard interactionEnabled else { return }
                                onTapSquare(sq)
                            }
                            .accessibilityIdentifier("square_\(sq.notation)")
                            .accessibilityLabel(accessibilityLabel(for: sq))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func highlightsLayer(squareSize: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            if let lastMove {
                squareOverlay(lastMove.start, squareSize: squareSize, isLast: true)
                squareOverlay(lastMove.end, squareSize: squareSize, isLast: true)
            }

            if let selectedSquare {
                squareOverlay(selectedSquare, squareSize: squareSize, isLast: false)
            }

            if let checkSquare = kingInCheckSquare {
                Rectangle()
                    .fill(theme.checkColor)
                    .frame(width: squareSize, height: squareSize)
                    .position(centerPoint(of: checkSquare, squareSize: squareSize))
            }

            ForEach(legalTargetSquares, id: \.self) { target in
                legalDot(target, squareSize: squareSize)
            }
        }
        .allowsHitTesting(false)
    }

    private func squareOverlay(_ sq: Square, squareSize: CGFloat, isLast: Bool) -> some View {
        let color: Color = isLast
            ? (sq.color == .light ? theme.lastMoveLight : theme.lastMoveDark)
            : theme.selectedColor
        return Rectangle()
            .fill(color)
            .frame(width: squareSize, height: squareSize)
            .position(centerPoint(of: sq, squareSize: squareSize))
    }

    private func legalDot(_ sq: Square, squareSize: CGFloat) -> some View {
        let isCapture = board.position.piece(at: sq) != nil
        return Group {
            if isCapture {
                Circle()
                    .strokeBorder(theme.legalDotColor, lineWidth: squareSize * 0.08)
                    .frame(width: squareSize * 0.86, height: squareSize * 0.86)
            } else {
                Circle()
                    .fill(theme.legalDotColor)
                    .frame(width: squareSize * 0.32, height: squareSize * 0.32)
            }
        }
        .position(centerPoint(of: sq, squareSize: squareSize))
    }

    @ViewBuilder
    private func coordinatesLayer(squareSize: CGFloat) -> some View {
        let files: [Square.File] = orientation == .white
            ? [.a, .b, .c, .d, .e, .f, .g, .h]
            : [.h, .g, .f, .e, .d, .c, .b, .a]
        let ranks: [Int] = orientation == .white ? Array((1...8).reversed()) : Array(1...8)

        VStack(spacing: 0) {
            ForEach(Array(ranks.enumerated()), id: \.offset) { rowIndex, rank in
                HStack(spacing: 0) {
                    ForEach(Array(files.enumerated()), id: \.offset) { colIndex, file in
                        ZStack(alignment: .bottomTrailing) {
                            Color.clear
                            if colIndex == 0 {
                                Text("\(rank)")
                                    .font(.system(size: squareSize * 0.2, weight: .semibold))
                                    .foregroundStyle(theme.coordinateColor)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .padding(3)
                            }
                            if rowIndex == 7 {
                                Text(file.rawValue)
                                    .font(.system(size: squareSize * 0.2, weight: .semibold))
                                    .foregroundStyle(theme.coordinateColor)
                                    .padding(3)
                            }
                        }
                        .frame(width: squareSize, height: squareSize)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func piecesLayer(squareSize: CGFloat) -> some View {
        ForEach(board.position.pieces, id: \.square) { piece in
            PieceGlyphView(piece: piece)
                .frame(width: squareSize, height: squareSize)
                .rotationEffect(pieceRotation)
                .animation(.easeInOut(duration: 0.35), value: allPiecesRotated)
                .position(centerPoint(of: piece.square, squareSize: squareSize))
                .opacity((dragState?.square == piece.square || slidingMove?.end == piece.square || rejectAnim?.from == piece.square) ? 0 : 1)
                .gesture(isDraggable(piece) ? dragGesture(for: piece.square, squareSize: squareSize) : nil)
                // Une pièce SANS geste doit être transparente au toucher.
                // Sinon son glyphe, dessiné au-dessus de la grille, avale le
                // tap : la grille est un FRÈRE dans le ZStack, pas un ancêtre,
                // donc le tap n'est pas transmis, il est perdu.
                //
                // 🐛 Bug corrigé : taper une pièce ADVERSE ne faisait rien.
                // Sélectionner sa pièce marchait (elle, a un geste), mais la
                // seconde frappe sur la case à CAPTURER était avalée. La
                // sélection restait affichée, plus aucun tap ne répondait, et
                // seul le glisser fonctionnait — il part d'une pièce à soi.
                // Invisible sur un déplacement vers une case vide.
                .allowsHitTesting(isDraggable(piece))
        }
    }

    /// Au-dessus des pièces (une pastille sous un glyphe ne se verrait pas)
    /// et hors du test tactile : c'est un indicateur, pas un contrôle.
    @ViewBuilder
    private func qualityBadgeLayer(squareSize: CGFloat) -> some View {
        if let qualityBadge {
            let center = centerPoint(of: qualityBadge.square, squareSize: squareSize)
            MoveQualityBadgeView(quality: qualityBadge.quality, squareSize: squareSize)
                .position(x: center.x + squareSize * 0.30, y: center.y - squareSize * 0.30)
                .allowsHitTesting(false)
                .transition(.scale.combined(with: .opacity))
                .id(qualityBadge.square.notation + qualityBadge.quality.rawValue)
        }
    }

    private func isDraggable(_ piece: Piece) -> Bool {
        guard interactionEnabled else { return false }
        guard let draggableColor else { return true }
        return piece.color == draggableColor
    }

    /// Rotation appliquée au glyphe de CHAQUE pièce — voir
    /// ``allPiecesRotated``. Ne porte que sur le rendu (pas la zone de
    /// détection tactile) : le joueur continue de taper/glisser depuis la
    /// même case physique, seule l'image tournée change.
    private var pieceRotation: Angle {
        allPiecesRotated ? .degrees(180) : .zero
    }

    /// Tolérance de tap, alignée sur celle d'iOS (`allowableMovement` ≈ 10 pt)
    /// plutôt que sur les 8 px d'origine. En dessous, le geste reste un tap
    /// même s'il change de case — un doigt qui glisse de 11 pt voulait taper,
    /// pas jouer.
    private static let tapSlop: CGFloat = 12

    private func dragGesture(for square: Square, squareSize: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
            .onChanged { value in
                dragState = DragState(square: square, location: value.location)
            }
            .onEnded { value in
                defer { dragState = nil }

                let distance = hypot(value.translation.width, value.translation.height)
                let target = self.square(at: value.location, squareSize: squareSize)

                // Un relâchement sur la case de DÉPART est un tap, quelle que
                // soit la distance parcourue : aucun coup ne va d'une case à
                // elle-même.
                //
                // 🐛 Bug corrigé : le seul critère était `distance < 8`, plus
                // serré que la tolérance de tap d'iOS (~10 pt). Un tap un peu
                // tremblé — le cas courant, pouce en main, en marchant —
                // partait donc en « glissement » et se soldait par un
                // `onDropPiece(e2, e2)` : coup illégal, rejeté en silence, et
                // SURTOUT aucune sélection. La pièce ne répondait pas au
                // tap-tap et il fallait la glisser. Aléatoire par nature (ça
                // dépendait du tremblement), donc invisible en test : XCUITest
                // tape au pixel près.
                if target == square || distance < Self.tapSlop {
                    onTapSquare(square)
                } else {
                    // Coup joué au drag : la pièce a déjà suivi le doigt,
                    // pas d'animation de glissement. Le drapeau est consommé
                    // au prochain changement de `lastMove` ; réinitialisé à
                    // retardement au cas où le drop serait illégal (aucun coup).
                    suppressNextSlide = true
                    onDropPiece(square, target)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        suppressNextSlide = false
                    }
                }
            }
    }

    // MARK: Coordonnées <-> géométrie

    private func square(row: Int, col: Int) -> Square {
        let file: Int
        let rank: Int
        if orientation == .white {
            file = col
            rank = 7 - row
        } else {
            file = 7 - col
            rank = row
        }
        return Square(rawValue: rank * 8 + file) ?? .a1
    }

    private func square(at point: CGPoint, squareSize: CGFloat) -> Square {
        let col = min(7, max(0, Int(point.x / squareSize)))
        let row = min(7, max(0, Int(point.y / squareSize)))
        return square(row: row, col: col)
    }

    private func gridPosition(of sq: Square) -> (row: Int, col: Int) {
        let file = sq.file.number - 1
        let rank = sq.rank.value - 1
        if orientation == .white {
            return (row: 7 - rank, col: file)
        } else {
            return (row: rank, col: 7 - file)
        }
    }

    private func centerPoint(of sq: Square, squareSize: CGFloat) -> CGPoint {
        let (row, col) = gridPosition(of: sq)
        return CGPoint(
            x: CGFloat(col) * squareSize + squareSize / 2,
            y: CGFloat(row) * squareSize + squareSize / 2
        )
    }

    private func accessibilityLabel(for sq: Square) -> String {
        guard let piece = board.position.piece(at: sq) else {
            return "Case \(sq.notation), vide"
        }
        let colorLabel = piece.color == .white ? "blanc" : "noir"
        let kindLabel: String
        switch piece.kind {
        case .pawn: kindLabel = "pion"
        case .knight: kindLabel = "cavalier"
        case .bishop: kindLabel = "fou"
        case .rook: kindLabel = "tour"
        case .queen: kindLabel = "dame"
        case .king: kindLabel = "roi"
        }
        return "Case \(sq.notation), \(kindLabel) \(colorLabel)"
    }

    private var kingInCheckSquare: Square? {
        let checkedColor: Piece.Color?
        switch board.state {
        case let .check(color): checkedColor = color
        case let .checkmate(color): checkedColor = color
        default: checkedColor = nil
        }

        guard let checkedColor else { return nil }
        return board.position.pieces.first { $0.kind == .king && $0.color == checkedColor }?.square
    }
}

/// Couleur et épaisseur d'une flèche d'indice selon sa force (``HintMove/strength``,
/// 1 = aussi bon que le meilleur coup) : plus un coup se rapproche du
/// meilleur, plus sa flèche est foncée et large.
extension HintMove {
    var color: Color {
        // La MENACE est rouge translucide (Lot 5.G) : elle ne se confond pas
        // avec les flèches de coups à jouer, qui restent en niveaux de gris.
        // C'est ce que l'adversaire ferait si on lui laissait la main — pas
        // une suggestion.
        switch kind {
        case .threat:
            // Ce que l'ADVERSAIRE ferait si on lui laissait la main.
            return Theme.danger.opacity(0.55)
        case .better:
            // « Il fallait jouer ça » : la seule flèche qui porte sur la
            // position PRÉCÉDENTE. Vive et pleinement opaque — c'est
            // l'information la plus utile de l'écran quand elle apparaît.
            return Theme.accent.opacity(0.9)
        case .reviewBest:
            // Meilleur coup en revue de partie : vert, opacité graduée par la
            // force (deux coups équivalents => deux verts de teinte voisine).
            return Theme.accent.opacity(0.5 + strength * 0.45)
        case .best:
            break
        }
        let shade = 0.12 + (1 - strength) * 0.5
        let opacity = 0.6 + strength * 0.32
        return Color(white: shade).opacity(opacity)
    }

    var widthScale: CGFloat {
        0.7 + CGFloat(strength) * 0.65
    }
}

/// Flèche simple (ligne + pointe triangulaire) utilisée pour l'indice
/// et, plus tard, les annotations dessinées par l'utilisateur.
private struct ArrowShape: Shape {
    let from: CGPoint
    let to: CGPoint
    var widthScale: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let angle = atan2(to.y - from.y, to.x - from.x)
        let headLength: CGFloat = 20 * widthScale
        let headWidth: CGFloat = 15 * widthScale
        let shaftWidth: CGFloat = 9 * widthScale

        let shaftEnd = CGPoint(
            x: to.x - cos(angle) * headLength,
            y: to.y - sin(angle) * headLength
        )

        let perpendicular = angle + .pi / 2
        let dx = cos(perpendicular) * shaftWidth / 2
        let dy = sin(perpendicular) * shaftWidth / 2

        // Hampe (rectangle fin)
        path.move(to: CGPoint(x: from.x + dx, y: from.y + dy))
        path.addLine(to: CGPoint(x: shaftEnd.x + dx, y: shaftEnd.y + dy))
        path.addLine(to: CGPoint(x: shaftEnd.x - dx, y: shaftEnd.y - dy))
        path.addLine(to: CGPoint(x: from.x - dx, y: from.y - dy))
        path.closeSubpath()

        // Pointe (triangle)
        let base1 = CGPoint(
            x: shaftEnd.x + cos(perpendicular) * headWidth,
            y: shaftEnd.y + sin(perpendicular) * headWidth
        )
        let base2 = CGPoint(
            x: shaftEnd.x - cos(perpendicular) * headWidth,
            y: shaftEnd.y - sin(perpendicular) * headWidth
        )

        path.move(to: base1)
        path.addLine(to: to)
        path.addLine(to: base2)
        path.closeSubpath()

        return path
    }
}
