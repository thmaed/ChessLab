import AVFoundation
import ChessKit
import Foundation

/// Partie À L'AVEUGLE contre l'ordinateur (17/11/2026). Les quatre niveaux du mail aux testeurs (plus les disques
/// GRIS, ajoutés le 18/11), du plus
/// facile au plus dur ; décisions de l'utilisateur : les quatre, disques À LA COULEUR au niveau
/// « Cases occupées », coup d'œil en MAINTENANT le doigt (chaque appui compte), voix éteinte par défaut.
///
/// Ce que le mode coupe, à tous les niveaux : points de coups légaux (ceux d'une tour s'arrêtent devant une
/// pièce cachée), indice, alerte de gaffe, barre d'évaluation. La liste des coups reste.
enum BlindfoldLevel: String, Codable, CaseIterable, Hashable, Identifiable {
    case off
    /// Un disque blanc ou noir à la place de chaque pièce.
    case occupiedSquares
    /// Un disque GRIS à la place de chaque pièce : ni à qui, ni laquelle (demande de l'utilisateur, 18/11/2026).
    case occupiedSquaresGrey
    /// On voit ses pièces, pas celles de l'adversaire.
    case opponentHidden
    /// On voit celles de l'adversaire, pas les siennes.
    case ownHidden
    /// Plateau vide.
    case allHidden

    var id: String { rawValue }

    /// Les niveaux proposés, dans l'ordre de difficulté.
    static let levels: [BlindfoldLevel] = [.occupiedSquares, .occupiedSquaresGrey, .opponentHidden, .ownHidden, .allHidden]

    /// Clé française (localisée par l'appelant).
    var title: String {
        switch self {
        case .off: "Non"
        case .occupiedSquares: "Cases occupées"
        case .occupiedSquaresGrey: "Cases occupées en gris"
        case .opponentHidden: "Pièces adverses cachées"
        case .ownHidden: "Vos pièces cachées"
        case .allHidden: "Tout caché"
        }
    }

    /// Une phrase sous le titre.
    var detail: String {
        switch self {
        case .off: "Les pièces se voient."
        case .occupiedSquares: "Un disque blanc ou noir à la place de chaque pièce : on sait à qui elle est, pas laquelle c'est."
        case .occupiedSquaresGrey: "Un disque gris à la place de chaque pièce : on sait qu'une case est occupée, ni par qui ni par quoi."
        case .opponentHidden: "Vous voyez vos pièces, pas celles de l'adversaire."
        case .ownHidden: "Vous voyez celles de l'adversaire, pas les vôtres."
        case .allHidden: "Le plateau est vide : tout se joue de mémoire."
        }
    }

    /// Ce que le plateau montre, vu du camp `user`.
    func mask(user: Piece.Color) -> PieceMask {
        switch self {
        case .off: .none
        case .occupiedSquares: .discs
        case .occupiedSquaresGrey: .greyDiscs
        case .opponentHidden: .hidden([user.opposite])
        case .ownHidden: .hidden([user])
        case .allHidden: .hidden([.white, .black])
        }
    }

    /// On ne fait glisser que les pièces qu'on VOIT : à l'aveugle, sinon, on joue en touchant départ et arrivée.
    func canDrag(user: Piece.Color) -> Bool {
        mask(user: user).display(Piece(.king, color: user, square: .a1)) == .glyph
    }
}

/// Les coups de l'adversaire lus à voix haute — synthèse vocale de l'appareil, qui ne sort pas sur le réseau.
/// Les phrases sont celles de VoiceOver (``MoveNarration``), dans la langue de l'app.
///
/// La session audio de l'app est AMBIANTE (``SoundPlayer``) : le mode Silencieux de l'iPhone la coupe, ce qui va aux
/// petits sons du plateau mais rendait la voix muette (19/11/2026, « je n'entends pas la voix » sur iPhone3). La voix,
/// demandée expressément, passe donc en LECTURE de paroles le temps de parler, puis la session redevient ambiante.
///
/// La voix se CHOISIT (19/11/2026, « on peut avoir d'autres voix comme une voix féminine ? ») parmi celles installées
/// sur l'iPhone pour la langue de l'app ; d'autres se téléchargent dans Réglages › Accessibilité › Contenu énoncé. Le
/// choix est propre à l'appareil (les identifiants de voix n'existent pas ailleurs) : il vit dans les préférences
/// locales, jamais dans iCloud. Vide = la voix du système pour la langue, comme avant.
@MainActor
final class BlindfoldVoice: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = BlindfoldVoice()
    /// Clé des préférences locales : l'identifiant de la voix choisie, vide pour celle du système.
    static let voiceKey = "blindfold.voiceIdentifier"
    private let synthesizer = AVSpeechSynthesizer()

    /// Une voix proposée : son nom, et ce qui la distingue (féminine ou masculine, région, qualité).
    struct Option: Identifiable, Hashable {
        let id: String
        let name: String
        let gender: AVSpeechSynthesisVoiceGender
        let region: String?
        let quality: AVSpeechSynthesisVoiceQuality
    }

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Les voix installées pour `language` (« fr », « en »…), sans les voix fantaisie ni la voix personnelle ;
    /// la région n'est dite que si la langue en a plusieurs. Les meilleures d'abord, puis par nom.
    static func options(language: String = LocalizationController.activeLanguageCode) -> [Option] {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            Locale(identifier: voice.language).language.languageCode?.identifier == language
                && !voice.voiceTraits.contains(.isNoveltyVoice)
                && !voice.voiceTraits.contains(.isPersonalVoice)
        }
        let regions = Set(voices.map { Locale(identifier: $0.language).region?.identifier })
        let names = Locale(identifier: language)
        return voices
            .map { voice in
                let region = Locale(identifier: voice.language).region?.identifier
                return Option(id: voice.identifier, name: voice.name, gender: voice.gender,
                              region: regions.count > 1 ? region.flatMap { names.localizedString(forRegionCode: $0) } : nil,
                              quality: voice.quality)
            }
            .sorted { ($0.quality.rawValue, $1.name) > ($1.quality.rawValue, $0.name) }
    }

    /// La voix qui parlera : celle choisie si elle est encore installée et dans la langue de l'app, sinon celle du système.
    static func voice(identifier: String?, language: String = LocalizationController.activeLanguageCode) -> AVSpeechSynthesisVoice? {
        if let identifier, !identifier.isEmpty, let chosen = AVSpeechSynthesisVoice(identifier: identifier),
           Locale(identifier: chosen.language).language.languageCode?.identifier == language {
            return chosen
        }
        return AVSpeechSynthesisVoice(language: language)
    }

    /// Fait entendre une voix sur un coup d'exemple, au moment où on la choisit.
    func preview(identifier: String?) {
        speak(MoveNarration.describe(san: "Nf3"), voice: Self.voice(identifier: identifier))
    }

    /// `interrupting: false` met la phrase À LA SUITE de celle en cours : le coup de l'ordinateur ne coupe plus la
    /// répétition du coup qu'on vient de dicter (19/11/2026).
    func say(_ text: String, interrupting: Bool = true) {
        speak(text, voice: Self.voice(identifier: UserDefaults.standard.string(forKey: Self.voiceKey)),
              interrupting: interrupting)
    }

    private func speak(_ text: String, voice: AVSpeechSynthesisVoice?, interrupting: Bool = true) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        if interrupting { synthesizer.stopSpeaking(at: .immediate) }
        // Micro ouvert (coups à la voix) : la session « lecture et enregistrement » joue déjà en mode Silencieux, et
        // la changer couperait le micro.
        if !VoiceMoveListener.isCapturing {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try? session.setActive(true)
        }
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        backToAmbient()
    }

    /// La session redevient celle des sons du plateau, sauf si une nouvelle phrase a pris la suite.
    /// L'app parle : l'écoute des coups à la voix se met en retrait pour ne pas s'entendre elle-même.
    var isSpeaking: Bool { synthesizer.isSpeaking }

    private func backToAmbient() {
        guard !synthesizer.isSpeaking, !VoiceMoveListener.isCapturing else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.backToAmbient() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.backToAmbient() }
    }
}
