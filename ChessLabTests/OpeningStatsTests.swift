import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Le sidecar Labs : décodage DÉFENSIF, pourcentages honnêtes, et cohérence
/// des fichiers réellement embarqués avec les cours qu'ils accompagnent.
struct OpeningStatsTests {

    private func decode(_ json: String) throws -> OpeningStatsSidecar {
        try OpeningStatsLoader.decode(from: Data(json.utf8))
    }

    // MARK: Décodage

    @Test("Un sidecar complet se décode")
    func aCompleteSidecarDecodes() throws {
        let sidecar = try decode("""
        {"schemaVersion":1,"id":"x","engineDepth":20,"positions":{
          "k1":{"masters":{"w":10,"d":6,"b":4,"moves":[
                 {"san":"e4","uci":"e2e4","g":12,"w":6,"d":4,"b":2,"elo":2400,"eco":"B00","name":"King's Pawn"},
                 {"san":"d4","uci":"d2d4","g":8,"w":4,"d":2,"b":2}]},
                "engine":[{"san":"e4","uci":"e2e4","cp":33},{"san":"d4","uci":"d2d4","cp":25}]}}}
        """)

        let entry = try #require(sidecar.data(at: "k1"))
        let masters = try #require(entry.masters)
        #expect(sidecar.engineDepth == 20)
        #expect(masters.totalGames == 20)
        #expect(masters.moves.count == 2)
        #expect(masters.moves[0].name == "King's Pawn")
        #expect(masters.moves[0].averageRating == 2400)
        #expect(entry.engine.map(\.cp) == [33, 25])
    }

    /// Le fichier peut être partiel : une position sans maîtres, une autre
    /// sans moteur. C'est le cas NORMAL en profondeur — pas une erreur.
    @Test("Les deux blocs sont indépendamment facultatifs")
    func bothBlocksAreOptional() throws {
        let sidecar = try decode("""
        {"id":"x","positions":{
          "sans-maitres":{"engine":[{"san":"e4","uci":"e2e4","cp":10}]},
          "sans-moteur":{"masters":{"w":1,"d":0,"b":0,"moves":[{"san":"e4","uci":"e2e4","g":1,"w":1,"d":0,"b":0}]}},
          "vide":{}}}
        """)

        #expect(sidecar.data(at: "sans-maitres")?.masters == nil)
        #expect(sidecar.data(at: "sans-maitres")?.engine.count == 1)
        #expect(sidecar.data(at: "sans-moteur")?.engine.isEmpty == true)
        #expect(sidecar.data(at: "vide")?.isEmpty == true)
        #expect(sidecar.data(at: "inconnue") == nil)
    }

    /// Un champ absent ne doit JAMAIS faire échouer le décodage du fichier
    /// entier — même discipline que ``MoveEdge`` et ``GameRecord``.
    @Test("Des champs manquants ne cassent pas le décodage")
    func missingFieldsDoNotBreakDecoding() throws {
        let sidecar = try decode("""
        {"id":"x","positions":{"k":{"masters":{"moves":[{"san":"e4","uci":"e2e4"}]}}}}
        """)

        let masters = try #require(sidecar.data(at: "k")?.masters)
        #expect(masters.totalGames == 0)
        #expect(masters.moves[0].games == 0)
        #expect(masters.moves[0].whiteScore == nil, "aucun score inventé sans partie")
        #expect(sidecar.schemaVersion == nil)
    }

    /// Le prompt dit « maximum 3 » : la borne tient même si le fichier en
    /// contient plus (version future, fichier bricolé).
    @Test("Le moteur est borné à trois coups, même si le fichier en dit plus")
    func engineIsCappedAtThree() throws {
        let lines = (1...6).map { "{\"san\":\"m\($0)\",\"uci\":\"a\($0)a\($0)\",\"cp\":\($0)}" }
        let sidecar = try decode("""
        {"id":"x","positions":{"k":{"engine":[\(lines.joined(separator: ","))]}}}
        """)

        #expect(sidecar.data(at: "k")?.engine.count == 3)
    }

    @Test("Un mat se décode comme mat, pas comme centipions")
    func mateDecodesAsMate() throws {
        let sidecar = try decode("""
        {"id":"x","positions":{"k":{"engine":[{"san":"Qh7#","uci":"d3h7","mate":1}]}}}
        """)
        let line = try #require(sidecar.data(at: "k")?.engine.first)
        #expect(line.mate == 1)
        #expect(line.cp == nil)
    }

    // MARK: Pourcentages

    /// Les parts sont rapportées au TOTAL de la position, pas à la somme des
    /// coups retenus : le générateur écarte la queue statistique, et
    /// renormaliser afficherait 100 % là où il manque des parties.
    @Test("Les parts se rapportent au total de la position")
    func sharesUseThePositionTotal() {
        let stats = OpeningMasterStats(
            white: 50, draws: 30, black: 20,
            moves: [
                OpeningMasterMove(san: "e4", uci: "e2e4", games: 60, white: 30, draws: 20, black: 10),
                OpeningMasterMove(san: "d4", uci: "d2d4", games: 30, white: 15, draws: 8, black: 7),
            ]
        )

        #expect(stats.totalGames == 100)
        #expect(abs(stats.share(of: stats.moves[0]) - 0.60) < 0.0001)
        #expect(abs(stats.share(of: stats.moves[1]) - 0.30) < 0.0001)
        let sum = stats.moves.map { stats.share(of: $0) }.reduce(0, +)
        #expect(sum < 1.0, "la queue écartée manque, et c'est voulu")
    }

    @Test("Le score des blancs compte la nulle pour une demi-partie")
    func whiteScoreCountsDrawsAsHalf() {
        let move = OpeningMasterMove(san: "e4", uci: "e2e4", games: 10, white: 4, draws: 2, black: 4)
        #expect(abs((move.whiteScore ?? 0) - 0.5) < 0.0001)
    }

    @Test("Une position sans partie ne produit aucune part")
    func anEmptyPositionYieldsNoShare() {
        let stats = OpeningMasterStats(white: 0, draws: 0, black: 0, moves: [])
        #expect(stats.totalGames == 0)
        #expect(stats.share(of: OpeningMasterMove(san: "e4", uci: "e2e4", games: 5, white: 5, draws: 0, black: 0)) == 0)
    }

    // MARK: Les fichiers RÉELLEMENT embarqués

    /// Le contrat du module : toute position d'un sidecar existe dans le cours
    /// qu'il accompagne. Une clé orpheline serait de la donnée qu'on n'affiche
    /// jamais — et le signe que les deux fichiers ont divergé.
    @MainActor
    @Test("Chaque position de sidecar existe dans son cours")
    func everySidecarPositionExistsInItsCourse() throws {
        let entries = OpeningCourseLoader.catalog.filter { !$0.isEndgame }
        try #require(!entries.isEmpty, "aucune ouverture embarquée")

        var covered = 0
        var inspected = 0
        for entry in entries {
            let sidecar = OpeningStatsLoader.sidecar(id: entry.id)
            OpeningStatsLoader.flush()
            guard !sidecar.positions.isEmpty else { continue }
            inspected += 1
            let course = try #require(OpeningCourseLoader.course(id: entry.id))
            for key in sidecar.positions.keys {
                #expect(course.node(at: key) != nil, "\(entry.id) : position orpheline \(key)")
            }
            covered += sidecar.positions.count
        }
        #expect(inspected > 0, "aucun sidecar Labs embarqué — la génération n'a pas été copiée")
        #expect(covered > 0)
    }

    /// Les coups annoncés par le moteur doivent être LÉGAUX dans leur
    /// position : c'est le contrôle qui attraperait une clé décalée d'un coup
    /// entre le générateur et l'app.
    @MainActor
    @Test("Les coups du moteur sont légaux dans leur position")
    func engineMovesAreLegal() throws {
        // La PREMIÈRE ouverture qui a un sidecar, pas la première du
        // catalogue : la génération peut n'en avoir écrit qu'une partie, et le
        // test doit vérifier la donnée présente, pas échouer sur son absence
        // (ce que contrôle déjà `everySidecarPositionExistsInItsCourse`).
        var found: (entry: OpeningCatalogEntry, sidecar: OpeningStatsSidecar)?
        for candidate in OpeningCourseLoader.catalog where !candidate.isEndgame {
            let sidecar = OpeningStatsLoader.sidecar(id: candidate.id)
            OpeningStatsLoader.flush()
            if !sidecar.positions.isEmpty {
                found = (candidate, sidecar)
                break
            }
        }
        let (entry, sidecar) = try #require(found, "aucun sidecar Labs embarqué")

        var checked = 0
        for (key, data) in sidecar.positions.prefix(80) {
            guard let position = OpeningFENKey.position(from: key) else { continue }
            let board = Board(position: position)
            for line in data.engine {
                let start = Square(String(line.uci.prefix(2)))
                let end = Square(String(line.uci.dropFirst(2).prefix(2)))
                #expect(board.legalMoves(forPieceAt: start).contains(end),
                        "\(entry.id) : \(line.san) (\(line.uci)) illégal en \(key)")
                checked += 1
            }
        }
        #expect(checked > 0)
    }
}
