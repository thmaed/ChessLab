import Testing
@testable import ChessLab

/// Vérifie que les cours d'ouvertures EMBARQUÉS (générés par
/// `tools/opening-generator`, un fichier par ouverture) se décodent
/// directement avec le modèle Swift et passent le validateur d'intégrité.
///
/// Ce test câble le vrai chemin de chargement (`OpeningCourseLoader` sur le
/// bundle `.main`) et couvrira AUTOMATIQUEMENT les fichiers approfondis quand
/// le run réseau du générateur les remplacera. Pilote actuel : Scandinave,
/// Italienne, anti-siciliennes (lignes d'entrée + noms ECO réels ; profondeur
/// complète ajoutée au run réseau du jalon J5).
struct OpeningBundleTests {

    @Test func catalogDecodesFromBundle() {
        let catalog = OpeningCourseLoader.catalog
        #expect(catalog.count >= 3)
        #expect(catalog.contains { $0.id == "scandinavian" })
        #expect(catalog.contains { $0.id == "italian-game" })
        #expect(catalog.contains { $0.id == "anti-sicilians" })
    }

    @Test func everyBundledCourseDecodesAndPassesIntegrity() throws {
        let catalog = OpeningCourseLoader.catalog
        #expect(!catalog.isEmpty)

        for entry in catalog {
            let course = try #require(
                OpeningCourseLoader.course(id: entry.id),
                "cours embarqué introuvable/illisible: \(entry.id)"
            )
            #expect(course.id == entry.id)
            #expect(course.positions.count == entry.positionCount)

            let issues = OpeningCourseValidator.validate(course)
            #expect(issues.isEmpty, "intégrité \(entry.id): \(issues)")

            // La racine est une clé normalisée présente dans le graphe.
            #expect(course.positions[course.rootFEN] != nil)
            #expect(OpeningFENKey.normalize(course.rootFEN) == course.rootFEN)
        }
    }

    /// Le drapeau de fonctionnalité est faux par défaut mais des cours SONT
    /// embarqués : l'activation deviendra donc effective (``isActive``) sans
    /// dépendre d'un catalogue vide.
    @Test func featureIsGatedButCoursesAreBundled() {
        #expect(OpeningsGraphFeature.hasBundledCourses)
    }

    /// Le contenu rédigé à la main porte des commentaires BILINGUES : au moins
    /// une arête validée a un texte français distinct de l'anglais, et les deux
    /// se résolvent — preuve du bout en bout (bundle → décodage → résolution).
    @Test func bundledCommentsResolveInBothLanguages() throws {
        let course = try #require(OpeningCourseLoader.course(id: "scandinavian"))
        let edges = course.positions.values.flatMap(\.moves)
        let bilingual = edges.first { edge in
            guard let fr = edge.displayableComment("fr"), let en = edge.displayableComment("en") else { return false }
            return fr != en
        }
        #expect(bilingual != nil, "au moins un commentaire validé avec fr ≠ en")
    }
}
