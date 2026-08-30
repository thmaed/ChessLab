import XCTest

/// Les tests qui ne VÉRIFIENT rien, et qui ne doivent donc pas courir avec
/// les autres.
///
/// Quatre fichiers de ce dépôt ne sont pas des tests de non-régression mais
/// des OUTILS : ils déposent des captures d'écran ou des vidéos pour qu'on les
/// regarde. Leur en-tête le dit déjà — « à lancer à la demande » — mais rien
/// ne l'imposait, si bien qu'ils tournaient dans la suite d'interface
/// ordinaire. Deux conséquences, toutes deux constatées :
///
/// - **du temps pour rien** : la tournée petits écrans coûte deux minutes,
///   les captures App Store et les vidéos bien davantage ;
/// - **des faux échecs** : la tournée petits écrans passe en 127 s sur un
///   iPhone SE, son appareil de destination, et échoue au bout de 364 s sur
///   un iPhone 16 Pro — sur un délai de capture, pas sur un défaut de l'app.
///   Une suite qui rougit pour ça apprend à ignorer le rouge.
///
/// Ils s'exécutent donc seulement si on les demande, en POSANT UN TÉMOIN :
///
///     touch /tmp/cl-captures && xcodebuild test-without-building … && rm /tmp/cl-captures
///
/// Un fichier plutôt qu'une variable d'environnement, et ce n'est pas un
/// caprice : une variable posée dans le shell n'atteint pas le processus de
/// test, et le préfixe `TEST_RUNNER_` qui le permettrait est figé dans le
/// `.xctestrun` au moment du `build-for-testing` — il faudrait donc
/// recompiler pour changer d'avis. Le témoin se pose et s'enlève sans rien
/// reconstruire, quelle que soit la façon dont la suite est lancée.
/// `CHESSLAB_CAPTURES` reste reconnue pour qui passe par le schéma Xcode.
enum CaptureToolGate {

    /// Chemin du témoin. Dans `/tmp` : ces outils tournent sur le simulateur
    /// de la machine de développement, jamais sur un appareil.
    static let sentinelPath = "/tmp/cl-captures"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["CHESSLAB_CAPTURES"] != nil
            || FileManager.default.fileExists(atPath: sentinelPath)
    }

    /// À appeler en tête d'un outil de capture.
    static func requireEnabled() throws {
        try XCTSkipUnless(
            isEnabled,
            """
            Outil de capture, pas test de non-régression : poser le témoin \
            (`touch \(sentinelPath)`) pour le lancer.
            """
        )
    }
}
