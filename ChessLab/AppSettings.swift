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
        static let pieceSetID = "settings.pieceSetID"
        static let soundsEnabled = "settings.soundsEnabled"
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let pieceNotation = "settings.pieceNotation"
        static let appLanguage = "settings.appLanguage"
        static let puzzleAttempts = "settings.puzzleAttempts"
    }

    /// Essais accordés par puzzle, avant que la solution ne soit fléchée.
    ///
    /// UN SEUL par défaut. Trois invitaient à tenter un coup « pour voir »,
    /// exactement l'inverse de ce qu'un puzzle entraîne : on doit calculer la
    /// variante jusqu'au bout AVANT de poser la pièce (retour d'un testeur
    /// classé, 15/08/2026). Le filet à trois essais reste disponible dans les
    /// réglages pour qui débute et préfère chercher en tâtonnant.
    var puzzleAttempts: Int {
        didSet { UserDefaults.standard.set(puzzleAttempts, forKey: Keys.puzzleAttempts) }
    }

    /// Les deux régimes proposés — un essai (par défaut) ou trois.
    nonisolated static let puzzleAttemptChoices = [1, 3]

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
    /// Sur les seuls cœurs PERFORMANCE (voir ``DevicePerformance``). L'ancienne
    /// formule `cœurs − 2` mettait des threads sur les cœurs « efficacité »
    /// (p. ex. 4 threads sur iPhone 11, dont 2 sur des cœurs lents) : chaleur
    /// et throttling pour rien.
    nonisolated static var recommendedEngineThreads: Int {
        DevicePerformance.recommendedThreads
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
    /// jamais tout seul (cœurs à 100 % tant que la position restait affichée) :
    /// on borne, le moteur passe en idle, la navigation relance une recherche
    /// neuve. Adaptée à l'appareil (``DevicePerformance/liveDepth``) : plus
    /// profonde sur matériel moderne, plus sobre en bas de gamme.
    nonisolated static var liveAnalysisDepth: Int { DevicePerformance.liveDepth }

    var boardThemeID: String {
        didSet { UserDefaults.standard.set(boardThemeID, forKey: Keys.boardThemeID) }
    }

    /// Jeu de pièces affiché — global et persistant, comme le thème de plateau.
    var pieceSetID: String {
        didSet { UserDefaults.standard.set(pieceSetID, forKey: Keys.pieceSetID) }
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
        pieceSetID = defaults.string(forKey: Keys.pieceSetID) ?? PieceSet.classic.id
        // `object(forKey:)` distingue « absent » (→ activé par défaut) de
        // « explicitement false ».
        soundsEnabled = (defaults.object(forKey: Keys.soundsEnabled) as? Bool) ?? true
        hapticsEnabled = (defaults.object(forKey: Keys.hapticsEnabled) as? Bool) ?? true

        // Borné : une valeur hors liste (fichier de préférences trafiqué,
        // réglage retiré dans une future version) ne doit pas rendre un puzzle
        // insoluble ou infini.
        let storedAttempts = (defaults.object(forKey: Keys.puzzleAttempts) as? Int) ?? 1
        puzzleAttempts = Self.puzzleAttemptChoices.contains(storedAttempts) ? storedAttempts : 1

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

    /// Relit les préférences depuis `UserDefaults` — appelé quand la synchro
    /// iCloud vient d'y déposer des valeurs venues d'un autre appareil.
    ///
    /// N'assigne que ce qui a réellement CHANGÉ. Chaque `didSet` réécrit dans
    /// `UserDefaults` (bénin), mais réassigner à l'identique ferait clignoter
    /// l'interface pour rien. La langue et les sons ne sont volontairement pas
    /// relus : ils ne voyagent pas (voir ``SettingsCloudSync``).
    func reloadSyncedValuesFromDefaults() {
        let defaults = UserDefaults.standard

        let theme = defaults.string(forKey: Keys.boardThemeID) ?? BoardTheme.classic.id
        if theme != boardThemeID { boardThemeID = theme }

        let pieces = defaults.string(forKey: Keys.pieceSetID) ?? PieceSet.classic.id
        if pieces != pieceSetID { pieceSetID = pieces }

        let haptics = (defaults.object(forKey: Keys.hapticsEnabled) as? Bool) ?? true
        if haptics != hapticsEnabled { hapticsEnabled = haptics }

        let storedAttempts = (defaults.object(forKey: Keys.puzzleAttempts) as? Int) ?? 1
        let attempts = Self.puzzleAttemptChoices.contains(storedAttempts) ? storedAttempts : 1
        if attempts != puzzleAttempts { puzzleAttempts = attempts }

        let arrows = defaults.string(forKey: Keys.analysisArrowMode)
            .flatMap(ArrowMode.init(rawValue:)) ?? .best
        if arrows != analysisArrowMode { analysisArrowMode = arrows }

        let notation = defaults.string(forKey: Keys.pieceNotation)
            .flatMap(PieceNotation.init(rawValue:)) ?? .french
        if notation != pieceNotation { pieceNotation = notation }
    }

    /// Thème de plateau résolu (retombe sur classique si l'id stocké est
    /// inconnu, ex. thème retiré dans une future version).
    var boardTheme: BoardTheme {
        BoardTheme.all.first { $0.id == boardThemeID } ?? .classic
    }

    /// Jeu de pièces résolu (retombe sur le jeu classique si l'id est inconnu).
    var pieceSet: PieceSet {
        PieceSet.all.first { $0.id == pieceSetID } ?? .classic
    }
}
