import Foundation
import Testing
@testable import ChessLab

/// Le catalogue des FINALES : le contrat que l'écran « Finales » suppose.
///
/// Ces tests gardent la frontière entre les deux modules qui partagent la
/// même infrastructure : une finale qui fuirait dans la liste des ouvertures
/// (ou l'inverse) ne casserait aucun décodage — seulement l'expérience.
@MainActor
struct EndgameCatalogTests {

    private var endgames: [OpeningCatalogEntry] { OpeningCatalog.all.filter(\.isEndgame) }

    @Test func theCatalogShipsEndgameCourses() {
        #expect(endgames.count >= 11, "le module Finales embarque au moins ses onze cours fondateurs")
    }

    /// L'écran groupe par famille : une famille inconnue rendrait ses cours
    /// INVISIBLES (aucune section ne les afficherait). C'est le test qui
    /// transforme cet oubli silencieux en échec bruyant.
    @Test func everyEndgameFamilyHasAKnownSection() {
        let known: Set<String> = ["pawns", "rooks", "bishops", "knights", "queens", "mates", "practical"]
        for entry in endgames {
            #expect(entry.family.map(known.contains) == true,
                    "famille inconnue de l'écran Finales : \(entry.family ?? "nil") (\(entry.id))")
        }
    }

    /// Les ouvertures livrées ne portent JAMAIS le champ kind : c'est ce qui
    /// garantit que les 58 cours existants n'ont pas changé de module.
    @Test func bundledOpeningsCarryNoKind() {
        let openings = OpeningCatalog.all.filter { !$0.isEndgame }
        #expect(openings.count >= 58)
        for entry in openings {
            #expect(entry.kind == nil, "\(entry.id) porte un kind inattendu")
        }
    }

    /// Chaque cours de finale part d'une position ARBITRAIRE (jamais la
    /// position initiale) et son graphe la contient : le contrat du lecteur.
    @Test func endgameCoursesStartFromTheirOwnPosition() throws {
        let standard = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"
        for entry in endgames {
            let course = try #require(OpeningCatalog.course(id: entry.id),
                                      "cours introuvable : \(entry.id)")
            #expect(course.rootFEN != standard, "\(entry.id) part de la position initiale ?")
            #expect(course.positions[course.rootFEN] != nil,
                    "\(entry.id) : la racine n'est pas dans le graphe")
            #expect(course.isEndgame)
        }
    }
}
