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
    /// Optionnel : taper une flèche de MEILLEUR coup (`.best`) la joue —
    /// utilisé par l'Analyse pour explorer un candidat d'un geste. `nil`
    /// ailleurs : les flèches restent alors décoratives (pas de capture de tap,
    /// le plateau reste entièrement jouable au tap-tap).
    var onTapArrow: ((HintMove) -> Void)? = nil
    /// Case occupée par le canard du Duck Chess — `nil` partout ailleurs.
    ///
    /// Dessiné ICI plutôt qu'en surcouche depuis l'écran de jeu : lui seul
    /// connaît la taille d'une case et l'orientation du plateau, et le canard
    /// doit suivre les deux. Il se pose AU-DESSUS des pièces, puisqu'il occupe
    /// une case que rien d'autre ne peut occuper — jamais de superposition à
    /// arbitrer.
    var duckSquare: Square? = nil

    /// Un essai raté à signaler. Le `id` (nonce fourni par le VM) garantit
    /// que deux essais identiques (mêmes cases) redéclenchent l'animation.
    struct RejectedMove: Equatable {
        let id: Int
        let from: Square
        let to: Square
    }

    @State private var dragState: DragState?


    // MARK: Survol (pointeur/trackpad — iPad & Mac)
    /// Case sous le pointeur. Reste `nil` au doigt : `onHover` ne se déclenche
    /// qu'avec un pointeur (souris/trackpad). Purement visuel.
    @State private var hoveredSquare: Square?

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
        /// Cibles légales de la pièce tirée, calculées **une seule fois** au
        /// début du geste. Le résolveur est appelé à chaque image du
        /// glissement : régénérer les coups légaux à 60-120 Hz serait gaspillé
        /// pour un ensemble constant — la pièce tirée ne change pas.
        ///
        /// Vient de `board.legalMoves(forPieceAt:)`, **jamais** de
        /// ``legalTargetSquares`` : ce dernier suit la SÉLECTION, or un
        /// glissement ne sélectionne rien.
        let legalTargets: [Square]
        var location: CGPoint
        /// Case que le relâchement jouerait, telle qu'annoncée au joueur par
        /// ``dropTargetLayer(squareSize:)``.
        ///
        /// Rangée ICI plutôt que dans un second `@State` : `location` change
        /// déjà à chaque image, donc le plateau se redessine de toute façon.
        /// Un `@State` séparé doublerait les invalidations SwiftUI — et
        /// réécrire une valeur identique dans un `@State` réévalue quand même
        /// le `body`, ce qui se paie sur une vue à 64 cases et 6 couches.
        var resolvedTarget: Square?
    }


    /// Géométrie courante — voir ``BoardGeometry``.
    private func geometry(squareSize: CGFloat) -> BoardGeometry {
        BoardGeometry(squareSize: squareSize, orientation: orientation)
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let squareSize = side / 8

            ZStack(alignment: .topLeading) {
                squaresGrid(squareSize: squareSize)
                highlightsLayer(squareSize: squareSize)
                hoverLayer(squareSize: squareSize)

                if showCoordinates {
                    coordinatesLayer(squareSize: squareSize)
                }

                piecesLayer(squareSize: squareSize)
                duckLayer(squareSize: squareSize)
                // Au-DESSUS des pièces : sur une case occupée (capture), un
                // marqueur placé dessous serait masqué par la pièce adverse.
                dropTargetLayer(squareSize: squareSize)
                // Au-dessus des FLÈCHES aussi (`zIndex`), et pas seulement des
                // pièces : en analyse, la flèche du meilleur coup part de la
                // case qui vient d'être jouée et passait donc pile sur la
                // pastille, qui n'était plus lisible là où elle compte le plus
                // — sur une gaffe ou un coup brillant. L'ordre du ZStack ne
                // suffit pas : la pastille doit rester COLLÉE au-dessus des
                // pièces (c'est la même contrainte que `dropTargetLayer`),
                // donc c'est le rang d'empilement qui la fait remonter.
                qualityBadgeLayer(squareSize: squareSize)
                    .zIndex(1)

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
                    // Seules les flèches de MEILLEUR coup sont cliquables, et
                    // seulement si un handler est fourni : la menace (rouge) et
                    // la flèche rétrospective restent décoratives, et partout
                    // ailleurs le plateau garde son tap-tap intact.
                    let tappable = onTapArrow != nil && hint.kind == .best
                    ArrowShape(
                        from: centerPoint(of: hint.from, squareSize: squareSize),
                        to: centerPoint(of: hint.to, squareSize: squareSize),
                        widthScale: hint.widthScale,
                        squareSize: squareSize
                    )
                    .fill(hint.color)
                    .shadow(color: hint.color.opacity(0.6), radius: hint.rank == 1 ? 4 : 0)
                    .allowsHitTesting(tappable)
                    .onTapGesture { onTapArrow?(hint) }
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
                    // Fantôme SOULEVÉ : agrandi et décalé hors de la zone de
                    // contact, sinon le doigt le masque entièrement — c'est
                    // toute la pièce qu'on ne voit plus au moment où l'on vise.
                    //
                    // ⚠️ Le décalage suit ``pieceRotation`` : en mode Table du
                    // jeu à deux, `allPiecesRotated` tourne les glyphes de 180°
                    // sans bouger la géométrie. Un « vers le haut » codé en dur
                    // partirait vers le BAS pour le joueur assis en face.
                    //
                    // La RÉSOLUTION, elle, reste fondée sur le doigt et non sur
                    // le centre du fantôme décalé (comme chess.com) : la teinte
                    // de cible est la vérité affichée, on ne mélange pas les
                    // deux références.
                    PieceGlyphView(piece: piece)
                        .frame(width: squareSize, height: squareSize)
                        .rotationEffect(pieceRotation)
                        .scaleEffect(Self.dragLiftScale)
                        .position(
                            x: dragState.location.x,
                            y: dragState.location.y
                                + Self.dragLiftOffset(squareSize: squareSize, rotated: allPiecesRotated)
                        )
                        .allowsHitTesting(false)
                        // Ombre INCHANGÉE : l'agrandissement est gratuit, une
                        // ombre ou un halo de plus serait du GPU redessiné à
                        // chaque image.
                        .shadow(radius: 6)
                        // Au-dessus de TOUT, pastille comprise : la pièce
                        // soulevée suit le doigt, rien ne doit passer devant.
                        .zIndex(2)
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
                            // `SpatialTapGesture` et non `onTapGesture` : il
                            // faut le POINT touché, pas seulement la case, pour
                            // appliquer au tap-tap le même rattrapage qu'au
                            // glisser. Un geste de tap ne capte pas le
                            // défilement, contrairement à un `DragGesture` —
                            // le plateau est dans un `ScrollView` sur l'écran
                            // d'analyse iPhone.
                            .gesture(
                                SpatialTapGesture(coordinateSpace: .named("board"))
                                    .onEnded { value in
                                        guard interactionEnabled else { return }
                                        onTapSquare(
                                            tappedSquare(
                                                at: value.location, fallback: sq, squareSize: squareSize
                                            )
                                        )
                                    }
                            )
                            .accessibilityIdentifier("square_\(sq.notation)")
                            .accessibilityLabel(accessibilityLabel(for: sq))
                            .onHover { hovering in
                                guard interactionEnabled else { return }
                                if hovering { hoveredSquare = sq }
                                else if hoveredSquare == sq { hoveredSquare = nil }
                            }
                    }
                }
            }
        }
    }

    /// Case réellement visée par un tap, rattrapage compris.
    ///
    /// 🐛 Signalé en usage réel : « ça coince des fois, j'ai de la peine à
    /// cliquer sur la case d'arrivée — le déplacement fonctionne bien ». Le
    /// rattrapage vers la cible légale la plus proche n'avait été branché que
    /// sur le GLISSER : le tap-tap, lui, restait au point près. Mesuré : le
    /// même relâchement à 0,6 case du centre de e4 jouait e2-e4 en glissant et
    /// **rien du tout** en tapant. Le tap-tap était donc devenu le geste le
    /// plus exigeant des deux, ce qui est exactement l'inverse de ce qu'on
    /// attend du geste « lent et posé ».
    ///
    /// Mesuré aussi, et écarté : la dérive du doigt n'était PAS en cause — un
    /// tap qui glisse de 0,3 case sur la case d'arrivée jouait déjà le coup,
    /// la tolérance de `SpatialTapGesture` suffisant largement.
    ///
    /// Le rattrapage ne s'applique qu'aux cases qui, sans lui, **ne feraient
    /// rien d'utile** :
    /// - une cible légale tapée directement est jouée telle quelle ;
    /// - la case sélectionnée reste le geste de désélection ;
    /// - une pièce à soi intercepte le tap avant la grille (elle porte son
    ///   propre geste), donc changer de sélection n'est jamais concerné.
    ///
    /// Reste le cas d'une case morte pendant qu'une pièce est sélectionnée,
    /// qui ne provoquait qu'une désélection : c'est là, et là seulement, que
    /// l'on regarde s'il y avait une cible légale tout près.
    private func tappedSquare(at location: CGPoint, fallback sq: Square, squareSize: CGFloat) -> Square {
        guard let selectedSquare, sq != selectedSquare,
              !legalTargetSquares.contains(sq),
              let snapped = geometry(squareSize: squareSize)
                  .resolve(point: location, legalTargets: legalTargetSquares)
        else { return sq }
        return snapped
    }

    /// Anneau discret sous le pointeur (iPad avec trackpad/souris, Mac
    /// Catalyst). La couleur s'adapte à la case pour rester visible sur tous
    /// les thèmes de plateau : sombre sur case claire, clair sur case foncée.
    /// Masqué pendant un glissement (le pointeur porte alors la pièce).
    @ViewBuilder
    private func hoverLayer(squareSize: CGFloat) -> some View {
        if interactionEnabled, let hoveredSquare, dragState == nil {
            let onLight = hoveredSquare.color == .light
            Rectangle()
                .strokeBorder(
                    onLight ? Color.black.opacity(0.35) : Color.white.opacity(0.55),
                    lineWidth: max(2, squareSize * 0.045)
                )
                .frame(width: squareSize, height: squareSize)
                .position(centerPoint(of: hoveredSquare, squareSize: squareSize))
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.12), value: hoveredSquare)
        }
    }

    /// Case que le relâchement jouerait, pendant un glissement au doigt.
    ///
    /// C'est le **garde-fou du rattrapage** : celui-ci choisit une case à la
    /// place du joueur, ceci lui permet de voir ce choix et de se corriger
    /// AVANT de relâcher. L'un ne va pas sans l'autre.
    ///
    /// Un **remplissage**, pas un liseré fin : le liseré de ``hoverLayer``
    /// (~2 pt) a été dessiné pour un pointeur sur iPad/Mac, où rien n'occulte
    /// l'écran. Sous un doigt — et la main masque tout ce qui est sous le point
    /// de contact, en particulier sur les deux premières rangées — 2 pt sont à
    /// la limite du perceptible.
    ///
    /// Teinte : ``BoardTheme/selectedColor``, déjà présente dans les quatre
    /// thèmes et déjà validée pour le contraste (thème `contrast` compris).
    /// Aucune couleur nouvelle, donc rien à revalider côté daltonisme. La
    /// cible reçoit le remplissage **ET** un liseré de la même teinte, pour se
    /// distinguer de la case de départ sélectionnée, qui n'a que le
    /// remplissage.
    ///
    /// Couche dédiée plutôt que de lever la condition `dragState == nil` de
    /// ``hoverLayer`` : celle-ci sert le pointeur iPad/Mac, la contourner
    /// risquerait un double marqueur.
    @ViewBuilder
    private func dropTargetLayer(squareSize: CGFloat) -> some View {
        if let dragState, let target = dragState.resolvedTarget {
            Rectangle()
                .fill(theme.selectedColor)
                .overlay(
                    Rectangle().strokeBorder(theme.selectedColor, lineWidth: max(3, squareSize * 0.08))
                )
                .frame(width: squareSize, height: squareSize)
                .position(centerPoint(of: target, squareSize: squareSize))
                .allowsHitTesting(false)
                // Animation sur le CHANGEMENT DE CASE seulement, jamais sur la
                // position du doigt : un ressort par image empilerait du
                // travail d'animation pour rien.
                .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: target)
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

            // Pendant un glissement, les pastilles suivent la pièce TIRÉE, pas
            // la sélection : glisser une pièce non sélectionnée n'affichait
            // sinon aucune pastille (`legalTargetSquares` suit la sélection),
            // et le joueur ne voyait que sa pièce.
            //
            // Une seule source à la fois : si la pièce glissée était aussi la
            // case sélectionnée, les deux ensembles seraient identiques et les
            // pastilles se dessineraient deux fois.
            //
            // Bénéfice décisif au-delà du confort : ça rend LISIBLE chaque
            // annulation silencieuse. Zéro pastille = cette pièce ne peut pas
            // bouger ; aucune pastille près du doigt = relâcher ici ne fera
            // rien. Sans ça, l'annulation peut passer pour un bug.
            ForEach(dragState?.legalTargets ?? legalTargetSquares, id: \.self) { target in
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
                .opacity((dragState?.square == piece.square || slidingMove?.end == piece.square || rejectAnim?.from == piece.square) ? 0 : 1)
                // ⚠️ `.offset` et NON `.position` — la distinction porte tout
                // le comportement tactile de cette couche.
                //
                // 🐛 Bug corrigé (iPhone XS Max / iOS 18) : le plateau était
                // injouable, seule la colonne H répondait — en réalité une
                // seule pièce, h2, la dernière de `position.pieces`, puis h4
                // une fois le pion avancé.
                //
                // `.position()` est un modificateur de MISE EN PAGE : il rend
                // une vue qui occupe tout l'espace offert et y place l'enfant.
                // Chaque pièce fabriquait donc un conteneur de la taille du
                // plateau entier, et ces 32 conteneurs s'empilaient. Déplacer
                // simplement le geste avant `.position` ne suffit pas — essayé,
                // sans effet : le conteneur reste, et c'est LUI qui intercepte
                // en iOS 18.
                //
                // `.offset` est un modificateur de RENDU : la vue garde sa
                // taille d'une case, et le hit-testing suit le décalage. Plus
                // aucun conteneur pleine surface, donc plus rien à intercepter.
                //
                // Invisible en iOS 26, qui ne laisse plus la zone vide d'une
                // vue positionnée capter le toucher — et invisible en test, nos
                // simulateurs n'ayant que ce runtime.
                .contentShape(Rectangle())
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
                .offset(originOffset(of: piece.square, squareSize: squareSize))
                .animation(.easeInOut(duration: 0.35), value: allPiecesRotated)
                // Une pièce glissable est au-dessus de sa case et capterait le
                // survol : on relaie le hover depuis le glyphe pour que
                // l'anneau apparaisse aussi sous ses propres pièces.
                .onHover { hovering in
                    guard interactionEnabled, isDraggable(piece) else { return }
                    if hovering { hoveredSquare = piece.square }
                    else if hoveredSquare == piece.square { hoveredSquare = nil }
                }
        }
    }

    /// Au-dessus des pièces (une pastille sous un glyphe ne se verrait pas)
    /// ET des flèches (voir le `zIndex` posé à l'appel), hors du test tactile :
    /// c'est un indicateur, pas un contrôle.
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

    /// Grossissement et hauteur de levée du fantôme de glissement, en fraction
    /// de case. Purement visuel : la case visée reste celle du doigt.
    private static let dragLiftScale: CGFloat = 1.2
    private static let dragLiftRatio: CGFloat = 0.4

    /// Décalage vertical du fantôme, en points d'écran.
    ///
    /// Extrait de la vue **uniquement pour être testable** : le signe dépend de
    /// ``allPiecesRotated``, et une inversion collerait le fantôme SOUS le
    /// doigt du joueur d'en face (mode Table du jeu à deux) — c'est-à-dire
    /// exactement le défaut que la levée corrige, mais pour un seul des deux
    /// joueurs. Une capture d'écran de test ne le dirait pas : elle est prise
    /// hors glissement.
    static func dragLiftOffset(squareSize: CGFloat, rotated: Bool) -> CGFloat {
        // Rotated : les glyphes sont tournés de 180°, le « haut » du joueur est
        // le BAS de l'écran. Le fantôme doit donc descendre pour s'éloigner de
        // sa main.
        rotated ? squareSize * dragLiftRatio : -squareSize * dragLiftRatio
    }

    private func dragGesture(for square: Square, squareSize: CGFloat) -> some Gesture {
        let geometry = geometry(squareSize: squareSize)
        return DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
            .onChanged { value in
                // `minimumDistance: 0` fait entrer ici dès le toucher : la
                // transition `nil` → non-nil est donc le vrai début du geste,
                // et le seul endroit où calculer les coups légaux.
                // Le cache n'est réutilisé que s'il appartient bien à CETTE
                // pièce : un second doigt posé sur une autre case pendant le
                // geste hériterait sinon des cibles de la première.
                let cached = dragState?.square == square ? dragState?.legalTargets : nil
                let targets = cached ?? board.legalMoves(forPieceAt: square)
                dragState = DragState(
                    square: square,
                    legalTargets: targets,
                    location: value.location,
                    // Ce que le relâchement jouerait, annoncé en direct.
                    resolvedTarget: geometry.resolve(point: value.location, legalTargets: targets)
                )
            }
            .onEnded { value in
                defer { dragState = nil }

                let distance = hypot(value.translation.width, value.translation.height)
                // Case GÉOMÉTRIQUE, pas résolue : voir le piège ci-dessous.
                let geometricTarget = geometry.geometricSquare(at: value.location)

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
                //
                // ⚠️ La comparaison porte sur la case GÉOMÉTRIQUE, jamais sur
                // la sortie du résolveur. Sinon le geste de renoncement
                // jouerait un coup : relâcher sur le bord haut de e2 donne
                // géométriquement e2, qui n'est pas une cible légale (aucun
                // coup ne va d'une case à elle-même), donc le rattrapage
                // s'activerait et le centre de e3 n'est qu'à 0,5 case — dans
                // le rayon. Snap sur e3, coup joué, alors que le joueur
                // renonçait. Voir `BoardGeometryTests`.
                if geometricTarget == square || distance < Self.tapSlop {
                    onTapSquare(square)
                } else if let target = geometry.resolve(
                    point: value.location,
                    legalTargets: dragState?.square == square
                        ? (dragState?.legalTargets ?? [])
                        : board.legalMoves(forPieceAt: square)
                ) {
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
                // Résolveur à `nil` : **annulation silencieuse**. On ne joue
                // rien, on ne prévient de rien, et surtout on ne touche pas à
                // la sélection — renoncer doit rester gratuit. C'est aussi ce
                // qui supprime le `Haptics.illegal()` qui punissait un raté de
                // 2 pt : la vue n'émet plus de coup illégal par cette voie.
                // L'absence de teinte de cible avait déjà dit au joueur que
                // relâcher ici ne ferait rien.
            }
    }

    // MARK: Coordonnées <-> géométrie

    // La géométrie vit dans ``BoardGeometry`` — type valeur testable, alors
    // que ces méthodes, privées d'une `View`, ne l'étaient pas. On délègue au
    // lieu d'en garder une seconde copie : deux implémentations de la même
    // grille finiraient par diverger.
    //
    // `square(at:squareSize:)` a DISPARU : il bornait les coordonnées
    // (`min(7, max(0, …))`), si bien qu'un relâchement loin du plateau
    // résolvait sur la case de bord la plus proche et pouvait jouer un coup
    // jamais visé. Son remplaçant, `BoardGeometry.geometricSquare(at:)`, rend
    // `nil` au-delà d'une marge de grâce d'une demi-case.

    /// Le canard 🦆 du Duck Chess, posé sur sa case.
    ///
    /// Un emoji plutôt qu'un glyphe vectoriel : c'est LE signe distinctif de
    /// la variante, il doit se reconnaître d'un coup d'œil, et aucun symbole
    /// SF ne dit « canard ». Il ne tourne pas avec le plateau (contrairement
    /// aux pièces en mode table) — un canard à l'envers ne veut rien dire.
    @ViewBuilder
    private func duckLayer(squareSize: CGFloat) -> some View {
        if let duckSquare {
            Text(verbatim: "🦆")
                .font(.system(size: squareSize * 0.62))
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .frame(width: squareSize, height: squareSize)
                .position(centerPoint(of: duckSquare, squareSize: squareSize))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func square(row: Int, col: Int) -> Square {
        geometry(squareSize: 1).square(row: row, col: col)
    }

    private func centerPoint(of sq: Square, squareSize: CGFloat) -> CGPoint {
        geometry(squareSize: squareSize).centerPoint(of: sq)
    }

    /// Décalage du coin HAUT-GAUCHE d'une case depuis l'origine du plateau.
    ///
    /// Permet de placer une vue déjà dimensionnée à la case avec `.offset`
    /// plutôt qu'avec `.position` : le `ZStack` étant aligné `.topLeading`, une
    /// vue non décalée se trouve déjà sur a8 (ou h1 si le plateau est
    /// retourné). Voir le commentaire de ``piecesLayer(squareSize:)`` pour ce
    /// que cette différence change au toucher.
    private func originOffset(of sq: Square, squareSize: CGFloat) -> CGSize {
        let center = centerPoint(of: sq, squareSize: squareSize)
        return CGSize(width: center.x - squareSize / 2, height: center.y - squareSize / 2)
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
        // Teinte explicite (lecteur d'ouvertures : une couleur par coup) : elle
        // prime sur la couleur dérivée de `kind`/`strength`.
        if let tint { return tint }
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
    /// Côté d'une case — l'unité à laquelle la flèche se mesure.
    ///
    /// Les proportions étaient auparavant en points ABSOLUS (20, 15, 9),
    /// calibrées sur une case d'environ 50 pt : la flèche écrasait donc la
    /// position sur un iPhone SE (case de 47 pt, plateau de 375) et
    /// devenait un trait de crayon sur une fenêtre Mac en plein écran
    /// (case de ~190 pt). Elle garde maintenant la même allure partout.
    var squareSize: CGFloat = 50

    /// Proportions d'origine, rapportées à la case de 50 pt sur laquelle
    /// elles avaient été réglées : 20/50, 15/50 et 9/50.
    private static let headLengthRatio: CGFloat = 0.40
    private static let headWidthRatio: CGFloat = 0.30
    private static let shaftWidthRatio: CGFloat = 0.18

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let angle = atan2(to.y - from.y, to.x - from.x)
        let headLength = Self.headLengthRatio * squareSize * widthScale
        let headWidth = Self.headWidthRatio * squareSize * widthScale
        let shaftWidth = Self.shaftWidthRatio * squareSize * widthScale

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
