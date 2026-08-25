// swift-tools-version: 6.0
import PackageDescription

// Fairy-Stockfish 14 vendorisé et compilé DANS le projet, sur le MÊME
// modèle que `Vendor/CStockfish` (mêmes réglages d'optimisation, mêmes
// raisons — voir son Package.swift). Deux différences propres à ce paquet :
//
//  • Espace de noms C++ RENOMMÉ (Stockfish → FairyEngine) dans TOUT
//    `Sources/CFairyStockfish/fairystockfish/` : Fairy-Stockfish est un
//    fork qui garde le même `namespace Stockfish`, ce qui produit des
//    symboles dupliqués à l'édition de liens dès qu'il est lié dans le
//    même binaire que `CStockfish` (vérifié : `ld: duplicate symbol
//    'Stockfish::...'`). Seule la syntaxe C++ (déclarations `namespace`,
//    accès qualifiés `Stockfish::`) a été touchée — jamais les commentaires
//    ni les mentions de copyright GPL, laissées intactes.
//  • Point d'entrée renommé `main` → `_fairy_main` (voir `_fairymain.cpp`),
//    et symboles C publics préfixés `cfairystockfish_` (voir `shim.cpp`) —
//    pour la même raison : deux moteurs, un seul binaire d'app.
//
// Paquet LOCAL → unsafeFlags autorisés.
let package = Package(
    name: "CFairyStockfish",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "CFairyStockfishKit", targets: ["CFairyStockfishKit"])
    ],
    targets: [
        .target(
            name: "CFairyStockfish",
            path: "Sources/CFairyStockfish",
            cxxSettings: [
                .headerSearchPath("fairystockfish"),
                .define("NNUE_EMBEDDING_OFF"),
                .define("NO_PEXT"),
                .define("USE_POPCNT"),
                .define("USE_NEON", to: "8"),
                .unsafeFlags(["-O3", "-DNDEBUG"])
            ]
        ),
        .target(
            name: "CFairyStockfishKit",
            dependencies: ["CFairyStockfish"],
            path: "Sources/CFairyStockfishKit"
        )
    ],
    cxxLanguageStandard: .gnucxx17
)
