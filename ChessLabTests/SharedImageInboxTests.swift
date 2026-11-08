import Foundation
import Testing
@testable import ChessLab

/// « Partager › ChessLab » (07/11/2026) : la boîte aux lettres entre l'extension
/// de partage et l'app. Pendant de `ScannerShareTest` (Android).
///
/// Chaque test travaille dans un dossier temporaire : le conteneur de groupe
/// n'existe pas dans un binaire de test non signé, et ne doit de toute façon pas
/// être touché par une suite.
struct SharedImageInboxTests {

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func source(_ bytes: [UInt8], in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("source-\(UUID().uuidString).png")
        try Data(bytes).write(to: url)
        return url
    }

    /// Une photo PRISE IL Y A UN MOIS, partagée aujourd'hui, ne doit pas être jugée « trop vieille »
    /// (revue du 08/11/2026 : constat qui ne se reproduit pas sur iOS, test gardé comme filet).
    @Test func anOldPhotoSharedTodayIsNotTakenForForgotten() throws {
        let inbox = try makeDirectory()
        let photo = try source([9, 9, 9], in: inbox)
        let lastMonth = Date.now.addingTimeInterval(-30 * 24 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: lastMonth], ofItemAtPath: photo.path)

        try SharedImageInbox.deposit(contentsOf: photo, in: inbox)

        #expect(SharedImageInbox.hasPending(in: inbox), "l'image vient d'être partagée")
        #expect(SharedImageInbox.take(in: inbox) == Data([9, 9, 9]))
    }

    @Test func anEmptyInboxHoldsNothing() throws {
        let inbox = try makeDirectory()
        #expect(!SharedImageInbox.hasPending(in: inbox))
        #expect(SharedImageInbox.take(in: inbox) == nil)
    }

    @Test func aDepositedImageIsTakenOnceAndTheInboxEmptied() throws {
        let inbox = try makeDirectory()
        try SharedImageInbox.deposit(contentsOf: source([1, 2, 3], in: inbox), in: inbox)

        #expect(SharedImageInbox.hasPending(in: inbox))
        #expect(SharedImageInbox.take(in: inbox) == Data([1, 2, 3]))
        #expect(!SharedImageInbox.hasPending(in: inbox), "une image ne se lit qu'une fois")
        #expect(SharedImageInbox.take(in: inbox) == nil)
    }

    /// Lire sans vider : l'image survit à un écran qui disparaît avant de l'avoir chargée.
    @Test func peekingLeavesTheImageUntilItIsDiscarded() throws {
        let inbox = try makeDirectory()
        try SharedImageInbox.deposit(contentsOf: source([4, 5], in: inbox), in: inbox)

        #expect(SharedImageInbox.peek(in: inbox) == Data([4, 5]))
        #expect(SharedImageInbox.peek(in: inbox) == Data([4, 5]), "lue deux fois, toujours là")
        #expect(SharedImageInbox.hasPending(in: inbox))
        SharedImageInbox.discard(in: inbox)
        #expect(SharedImageInbox.peek(in: inbox) == nil)
    }

    @Test func aSecondShareReplacesTheFirst() throws {
        let inbox = try makeDirectory()
        try SharedImageInbox.deposit(contentsOf: source([1], in: inbox), in: inbox)
        try SharedImageInbox.deposit(contentsOf: source([2, 2], in: inbox), in: inbox)
        #expect(SharedImageInbox.take(in: inbox) == Data([2, 2]))
    }

    @Test func noTemporaryFileIsLeftBehind() throws {
        let inbox = try makeDirectory()
        try SharedImageInbox.deposit(contentsOf: source([9], in: inbox), in: inbox)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: inbox.path).filter { $0.hasSuffix(".tmp") }
        #expect(leftovers.isEmpty)
    }

    /// Une image oubliée ne doit pas surgir des jours plus tard dans le scanner.
    @Test func anImageOlderThanADayIsForgottenAndRemoved() throws {
        let inbox = try makeDirectory()
        try SharedImageInbox.deposit(contentsOf: source([7], in: inbox), in: inbox)
        let later = Date.now.addingTimeInterval(SharedImageInbox.maximumAge + 60)

        #expect(!SharedImageInbox.hasPending(in: inbox, now: later))
        #expect(SharedImageInbox.take(in: inbox) == nil, "supprimée au passage, pas seulement ignorée")
    }

    @Test func anImageJustUnderADayOldIsStillTaken() throws {
        let inbox = try makeDirectory()
        try SharedImageInbox.deposit(contentsOf: source([7], in: inbox), in: inbox)
        let later = Date.now.addingTimeInterval(SharedImageInbox.maximumAge - 60)
        #expect(SharedImageInbox.take(in: inbox, now: later) == Data([7]))
    }

    /// Sans droit de groupe (binaire non signé), la boîte est inerte — jamais une erreur au réveil.
    @Test func withoutAGroupContainerTheInboxIsInert() throws {
        #expect(!SharedImageInbox.hasPending(in: nil))
        #expect(SharedImageInbox.take(in: nil) == nil)
        let inbox = try makeDirectory()
        #expect(throws: (any Error).self) {
            try SharedImageInbox.deposit(contentsOf: source([1], in: inbox), in: nil)
        }
    }
}
