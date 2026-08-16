// swift-tools-version: 6.0
import PackageDescription

// Stockfish 17.1 vendorisé et compilé DANS le projet, avec les bons paramètres
// d'optimisation — ce que le package tiers ne permettait pas de régler :
//
//  • USE_NEON / USE_POPCNT : chemins SIMD ARM de l'inférence NNUE. Sans eux,
//    Stockfish tombait sur le chemin SCALAIRE générique (2–4× plus lent sur
//    A13+). NEON est la baseline de tout arm64 → sûr sur tous les iPhone
//    supportés (on N'active PAS dotprod, qui planterait les A10/A11).
//  • -O3 : Stockfish le met dans son Makefile ; SPM ne l'ajoute pas. Via
//    unsafeFlags → appliqué MÊME en build Debug de l'app, pour ne pas
//    débuguer avec un moteur bridé.
//  • NNUE_EMBEDDING_OFF : les réseaux ne sont pas dans le binaire ; l'app les
//    livre en ressources et Stockfish les charge depuis le bundle.
//  • NO_PEXT : PEXT est x86 uniquement.
//  • lc0/Leela : NON vendorisé (le package tiers en compilait 25 Mo pour rien).
//
// Paquet LOCAL → unsafeFlags autorisés.
let package = Package(
    name: "CStockfish",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "CStockfishKit", targets: ["CStockfishKit"])
    ],
    targets: [
        .target(
            name: "CStockfish",
            path: "Sources/CStockfish",
            cxxSettings: [
                .headerSearchPath("stockfish"),
                .define("NNUE_EMBEDDING_OFF"),
                .define("NO_PEXT"),
                .define("USE_POPCNT"),
                .define("USE_NEON", to: "8"),
                // -O3 : Stockfish le met, pas SPM. -DNDEBUG : coupe les asserts
                // internes de SF (hot-path), y compris en build Debug de l'app.
                .unsafeFlags(["-O3", "-DNDEBUG"])
            ]
        ),
        .target(
            name: "CStockfishKit",
            dependencies: ["CStockfish"],
            path: "Sources/CStockfishKit"
        ),
        .testTarget(
            name: "CStockfishKitTests",
            dependencies: ["CStockfishKit"],
            path: "Tests/CStockfishKitTests"
        )
    ],
    cxxLanguageStandard: .gnucxx17
)
