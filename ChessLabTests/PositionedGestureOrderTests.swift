import Foundation
import Testing

/// Garde-fou de FORME : un geste ne doit jamais être posé APRÈS `.position(…)`.
///
/// ## Le défaut que ce test empêche
///
/// `.position()` rend une vue qui occupe **tout l'espace offert** et y place
/// l'enfant. Tout modificateur posé après s'applique donc au conteneur entier,
/// pas à l'élément qu'on croit viser. Un `.gesture()` dans cette position
/// couvre toute la surface ; quand plusieurs vues positionnées cohabitent dans
/// un `ForEach`, elles s'empilent et **la dernière répond partout**.
///
/// Constaté sur iPhone XS Max en iOS 18 : le plateau était injouable, seule la
/// colonne H répondait — h2 étant la dernière pièce blanche de
/// `position.pieces`. Le même défaut dormait dans les poignées de recadrage du
/// scanner.
///
/// ## Pourquoi un test sur les SOURCES
///
/// iOS 26 ne laisse plus la zone vide d'une vue positionnée capter le toucher :
/// le défaut y est totalement invisible, et nos simulateurs n'ont que ce
/// runtime. Un test d'interface ne peut donc pas l'attraper ici — seul l'ordre
/// des modificateurs est vérifiable, et il est vrai sur toutes les versions.
struct PositionedGestureOrderTests {

    /// Racine des sources de l'app, déduite de l'emplacement de CE fichier.
    /// Pas de chemin en dur : le dépôt a déjà déménagé une fois.
    private static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)          // …/ChessLabTests/CeFichier.swift
            .deletingLastPathComponent()          // …/ChessLabTests
            .deletingLastPathComponent()          // …/ChessLab (dépôt)
            .appending(path: "ChessLab")          // …/ChessLab/ChessLab (sources)
    }

    private static func swiftFiles() -> [URL] {
        guard let walker = FileManager.default.enumerator(
            at: sourceRoot, includingPropertiesForKeys: nil
        ) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Modificateurs qui n'ont de sens que bornés à l'élément lui-même.
    private static let interactive = [".gesture(", ".onTapGesture", ".simultaneousGesture(", ".highPriorityGesture("]

    @Test func noGestureIsAttachedAfterPosition() throws {
        let files = Self.swiftFiles()
        #expect(!files.isEmpty, "les sources doivent être trouvables depuis #filePath")

        var offenders: [String] = []
        for file in files {
            guard let contents = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let lines = contents.components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() {
                // Un COMMENTAIRE qui parle de `.position()` n'est pas un appel —
                // et ce fichier-ci, comme celui du plateau, en contient
                // justement pour documenter le piège.
                let anchor = line.trimmingCharacters(in: .whitespaces)
                guard !anchor.hasPrefix("//"), anchor.contains(".position(") else { continue }
                // On regarde la suite IMMÉDIATE de la chaîne de modificateurs :
                // une ligne qui commence par « . » la poursuit. Un commentaire
                // ou une ligne vide ne l'interrompt pas ; autre chose, si.
                for next in lines.dropFirst(index + 1) {
                    let trimmed = next.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty || trimmed.hasPrefix("//") { continue }
                    guard trimmed.hasPrefix(".") else { break }
                    if Self.interactive.contains(where: trimmed.hasPrefix) {
                        offenders.append(
                            "\(file.lastPathComponent):\(index + 1) — \(trimmed.prefix(60))"
                        )
                        break
                    }
                }
            }
        }

        #expect(
            offenders.isEmpty,
            """
            Geste posé après `.position(…)` — il couvrira tout le conteneur, \
            pas l'élément visé (plateau injouable en iOS 18) :
            \(offenders.joined(separator: "\n"))
            """
        )
    }
}
