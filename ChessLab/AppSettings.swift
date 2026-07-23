import Foundation
import Observation

/// Réglages transversaux de l'app, persistés dans `UserDefaults` et
/// partagés par tous les écrans (singleton observable).
///
/// Auparavant, le thème de plateau était un `@State` local DUPLIQUÉ dans
/// six écrans de jeu : il se réinitialisait à chaque partie et le menu de
/// sélection était recopié partout. Centralisé ici, il devient **global et
/// persistant** (Fable 3.5 / instructions.md §G8). Idem sons et haptiques.
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let analysisArrowMode = "settings.analysisArrowMode"
        static let boardThemeID = "settings.boardThemeID"
        static let soundsEnabled = "settings.soundsEnabled"
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let pieceNotation = "settings.pieceNotation"
        static let appLanguage = "settings.appLanguage"
    }

    /// Valeurs proposées par les réglages avancés (prompt : « Threads 2 (max 4
    /// selon appareil) », Hash 64 ou 128 Mo).
    ///
    /// `nonisolated` : constantes pures, que les tests paramétrés doivent
    /// pouvoir lire — `@Test(arguments:)` évalue ses arguments EN DEHORS de
    /// l'acteur (même piège que `scannerTestPositions`).
    /// Ce que les flèches du mode Analyser montrent. Persisté : c'est une
    /// préférence de lecture, qui n'a pas à se redemander à chaque partie.
    var analysisArrowMode: ArrowMode {
        didSet { UserDefaults.standard.set(analysisArrowMode.rawValue, forKey: Keys.analysisArrowMode) }
    }

    /// Threads de recherche, DÉDUITS de l'appareil au lieu d'être demandés.
    ///
    /// C'était un réglage, avec le choix entre 1, 2, 3 et 4. Personne ne peut
    /// répondre à cette question : la bonne valeur dépend du nombre de cœurs,
    /// et une valeur figée serait fausse de l'autre côté — 4 threads étouffent
    /// un appareil à deux cœurs, 2 threads brident un iPhone récent. On garde
    /// deux cœurs à l'interface et au système, et on plafonne à 4 : au-delà,
    /// sur mobile, le gain de force est mangé par la chaleur et la batterie.
    /// ``ThermalMonitor/threads(preferred:)`` rabote encore quand ça chauffe.
    nonisolated static var recommendedEngineThreads: Int {
        max(1, min(4, ProcessInfo.processInfo.activeProcessorCount - 2))
    }

    /// Table de transposition des moteurs interactifs (analyse live, mode
    /// Jouer), DIMENSIONNÉE selon la RAM. Le `NavigationStack` garde la VM
    /// parente vivante : « Jouer à partir d'ici » fait cohabiter deux instances
    /// → à 128 Mo chacune, zone jetsam sur appareil modeste. 128 Mo là où il y
    /// a de la marge, réduit ailleurs (gain d'une grosse table marginal aux
    /// temps d'une app mobile).
    nonisolated static var engineHashMB: Int {
        let gigabytes = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        if gigabytes >= 6 { return 128 }
        if gigabytes >= 4 { return 64 }
        return 32
    }

    /// Profondeur cible de l'analyse en continu. `go infinite` ne s'arrêtait
    /// jamais tout seul (cœurs à 100 % tant que la position restait affichée).
    /// Au-delà de ~22, l'éval et les flèches ne bougent plus à l'œil : on borne,
    /// le moteur passe en idle, la navigation relance une recherche neuve.
    nonisolated static let liveAnalysisDepth = 22

    var boardThemeID: String {
        didSet { UserDefaults.standard.set(boardThemeID, forKey: Keys.boardThemeID) }
    }

    var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: Keys.soundsEnabled) }
    }

    var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    /// Notation des pièces AFFICHÉE. Française par défaut (le prompt).
    /// N'affecte jamais le PGN stocké ou exporté — voir ``SANFormatter``.
    var pieceNotation: PieceNotation {
        didSet { UserDefaults.standard.set(pieceNotation.rawValue, forKey: Keys.pieceNotation) }
    }

    /// Langue de l'interface (français / anglais / système). Appliquée
    /// immédiatement à toute l'app via ``LocalizationController``.
    var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            LocalizationController.apply(languageCode: appLanguage.resolvedCode)
        }
    }

    /// Locale correspondant à la langue active — pour l'environnement SwiftUI
    /// (`Text` la suit ; complète le détournement de bundle pour le formatage
    /// des nombres et des dates).
    var locale: Locale { Locale(identifier: appLanguage.resolvedCode) }

    private init() {
        let defaults = UserDefaults.standard
        boardThemeID = defaults.string(forKey: Keys.boardThemeID) ?? BoardTheme.classic.id
        // `object(forKey:)` distingue « absent » (→ activé par défaut) de
        // « explicitement false ».
        soundsEnabled = (defaults.object(forKey: Keys.soundsEnabled) as? Bool) ?? true
        hapticsEnabled = (defaults.object(forKey: Keys.hapticsEnabled) as? Bool) ?? true

        analysisArrowMode = defaults.string(forKey: Keys.analysisArrowMode)
            .flatMap(ArrowMode.init(rawValue:)) ?? .best

        pieceNotation = defaults.string(forKey: Keys.pieceNotation)
            .flatMap(PieceNotation.init(rawValue:)) ?? .french

        appLanguage = defaults.string(forKey: Keys.appLanguage)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
        // Appliquer DÈS l'init du singleton : le tout premier écran doit
        // déjà s'afficher dans la bonne langue.
        LocalizationController.apply(languageCode: appLanguage.resolvedCode)
    }

    /// Thème de plateau résolu (retombe sur classique si l'id stocké est
    /// inconnu, ex. thème retiré dans une future version).
    var boardTheme: BoardTheme {
        BoardTheme.all.first { $0.id == boardThemeID } ?? .classic
    }
}
