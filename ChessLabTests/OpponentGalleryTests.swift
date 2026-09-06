import ChessKit
import Foundation
import Testing
import UIKit
@testable import ChessLab

/// La galerie : neuf personnages cohérents, chacun avec son illustration, son
/// niveau par défaut dans sa plage, et un répertoire dont chaque ligne est
/// LÉGALE depuis la position de départ.
@Suite struct OpponentGalleryTests {

    @Test func theGalleryHasNineDistinctCharacters() {
        #expect(OpponentProfile.all.count == 9)
        #expect(Set(OpponentProfile.all.map(\.id)).count == 9)
        #expect(Set(OpponentProfile.all.map(\.firstName)).count == 9)
        #expect(OpponentProfile.all.last == .camille, "l'étalon ferme la galerie")
    }

    @Test func everyCharacterHasItsIllustration() {
        for profile in OpponentProfile.all {
            #expect(UIImage(named: profile.avatar) != nil, "illustration manquante : \(profile.avatar)")
        }
    }

    @Test func defaultLevelsSitInsideTheRecommendedRange() {
        for profile in OpponentProfile.all {
            let level = Int(profile.defaultLevel)
            #expect(profile.recommendedLevels.contains(level), "\(profile.id)")
            #expect(level % 50 == 0, "\(profile.id)")
        }
    }

    @Test func temperaturesAndStylesAreSane() {
        for profile in OpponentProfile.all {
            #expect(profile.temperature > 0 && profile.temperature <= 2, "\(profile.id)")
            #expect(profile.style.strength >= 0 && profile.style.strength <= 1.5, "\(profile.id)")
            #expect(profile.temperament.pace > 0, "\(profile.id)")
        }
        #expect(OpponentProfile.camille.style.isNeutral)
        #expect(!OpponentProfile.lea.style.isNeutral)
    }

    @Test func everyRepertoireLoadsAndIsLegalFromTheStart() throws {
        for profile in OpponentProfile.all {
            guard let bookID = profile.bookID else { continue }
            let book = try #require(OpponentBooks.book(for: profile), "répertoire absent : \(bookID)")
            #expect(!book.roots.isEmpty, "\(bookID)")
            var walked = 0
            func walk(_ nodes: [OpeningBookNode], board: Board, path: [String]) throws {
                for node in nodes {
                    var next = board
                    let move = try #require(Move(san: node.san, position: next.position),
                                            "\(bookID) : \(path.joined(separator: " ")) \(node.san) illisible")
                    let attempted = next.move(pieceAt: move.start, to: move.end)
                    let made = try #require(attempted, "\(bookID) : \(path.joined(separator: " ")) \(node.san) illégal")
                    if case .promotion = next.state {
                        next.completePromotion(of: made, to: move.promotedPiece?.kind ?? .queen)
                    }
                    #expect(node.weight > 0, "\(bookID)")
                    walked += 1
                    try walk(node.children, board: next, path: path + [node.san])
                }
            }
            try walk(book.roots, board: Board(position: .standard), path: [])
            #expect(walked >= 100, "\(bookID) : \(walked) nœuds seulement")
        }
        #expect(OpponentBooks.book(for: .camille) == nil, "Camille joue le livre général")
    }

    @Test func aRepertoireAnswersItsOwnFirstMoves() {
        // Théo a des coups après 1. e4 e5 (2. f4 surtout, 2. d4, 2. Cf3), et
        // une réponse après 1. d4 (…d5 puis le contre-gambit Albin, ou …Cf6
        // puis Budapest).
        let theo = OpponentBooks.book(for: .theo)!
        let second = OpeningBookEngine.pickNextMove(book: theo, sanPath: ["e4", "e5"], width: .includeSidelines)
        #expect(["f4", "d4", "Nf3"].contains(second ?? ""))
        let reply = OpeningBookEngine.pickNextMove(book: theo, sanPath: ["d4"], width: .includeSidelines)
        #expect(reply == "d5" || reply == "Nf6")
        // Hors répertoire : Maia prend le relais.
        #expect(OpeningBookEngine.pickNextMove(book: theo, sanPath: ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "d3"], width: .includeSidelines) == nil)
    }
}
