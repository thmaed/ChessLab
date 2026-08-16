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

    /// Une CHAÎNE de modificateurs : la ligne d'ancrage et les lignes
    /// suivantes qui commencent par « . ». Commentaires et lignes vides ne
    /// l'interrompent pas.
    private static func chains(in contents: String) -> [(line: Int, body: [String])] {
        let lines = contents.components(separatedBy: .newlines)
        var result: [(Int, [String])] = []
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//"), !trimmed.isEmpty, !trimmed.hasPrefix(".") else {
                index += 1
                continue
            }
            var body = [trimmed]
            var cursor = index + 1
            while cursor < lines.count {
                let next = lines[cursor].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || next.hasPrefix("//") { cursor += 1; continue }
                guard next.hasPrefix(".") else { break }
                body.append(next)
                cursor += 1
            }
            if body.count > 1 { result.append((index + 1, body)) }
            index = max(cursor, index + 1)
        }
        return result
    }

    /// L'invariant n'est pas un ORDRE mais un USAGE : une vue qui doit recevoir
    /// le toucher ne se place pas avec `.position`, quel que soit l'endroit où
    /// le geste est accroché.
    ///
    /// Déplacer simplement le geste avant `.position` ne corrige rien — essayé
    /// sur l'appareil, sans effet : le conteneur pleine surface existe toujours
    /// et c'est lui qui intercepte. `.offset` est la forme correcte.
    @Test func noInteractiveViewIsPlacedWithPosition() throws {
        let files = Self.swiftFiles()
        #expect(!files.isEmpty, "les sources doivent être trouvables depuis #filePath")

        var offenders: [String] = []
        for file in files {
            guard let contents = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for chain in Self.chains(in: contents) {
                let positions = chain.body.filter { $0.hasPrefix(".position(") }
                guard !positions.isEmpty else { continue }
                guard chain.body.contains(where: { line in
                    Self.interactive.contains(where: line.hasPrefix)
                }) else { continue }
                offenders.append("\(file.lastPathComponent):\(chain.line)")
            }
        }

        #expect(
            offenders.isEmpty,
            """
            Vue interactive placée avec `.position(…)` : le conteneur qu'il \
            fabrique occupe toute la surface et intercepte le toucher en \
            iOS 18. Utiliser `.offset(…)`, qui laisse la vue à sa taille.
            \(offenders.joined(separator: "\n"))
            """
        )
    }
}
