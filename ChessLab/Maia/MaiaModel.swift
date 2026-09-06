import CoreML
import Foundation

/// Sortie brute d'une inférence Maia-3.
struct MaiaPrediction: Sendable {
    /// 4 352 logits, dans l'ordre de ``MaiaMoveTable``.
    let moveLogits: [Float]
    /// Probabilités d'issue HUMAINE du point de vue du camp au trait.
    let win: Double
    let draw: Double
    let loss: Double
}

/// Le réseau Maia-3 (23M) en Core ML : « quel coup jouerait un humain de tel
/// niveau, contre un adversaire de tel niveau, dans cette position ? »
///
/// Chargé par URL depuis le bundle, comme le modèle du scanner
/// (`YOLOBoardClassifier`) : un modèle absent rend `nil`, et l'appelant se
/// replie sur Stockfish bridé. Appel direct à `MLModel.prediction`, sans
/// Vision : l'entrée n'est pas une image mais un tenseur `1 × 64 × 97`
/// (voir ``MaiaEncoder``).
///
/// Acteur : `MLModel` est réentrant, mais sérialiser les prédictions garde le
/// contrat simple et le coût est nul — une inférence dure quelques
/// millisecondes.
actor MaiaModel {
    /// Maia3-23M depuis le 06/09/2026 (le 5M a servi au spike et aux
    /// premières mesures) : 22,9 M de paramètres, 43 Mo en fp16, 56,6 % de
    /// coups humains prédits contre 55,4 %, 3 ms par coup sur CPU M2.
    static let modelResourceName = "Maia3_23M"
    /// Bornes du conditionnement : le modèle interpole linéairement entre un
    /// embedding « 0 » et un embedding « 5 000 ».
    static let eloRange: ClosedRange<Double> = 0...5000

    private let model: MLModel

    init?(bundle: Bundle = .main) {
        let candidates = [
            bundle.url(forResource: Self.modelResourceName, withExtension: "mlmodelc"),
            bundle.url(forResource: Self.modelResourceName, withExtension: "mlpackage"),
        ].compactMap { $0 }
        guard let url = candidates.first else { return nil }
        let configuration = MLModelConfiguration()
        // CPU SEUL, mesuré et non supposé (05/09/2026) : sur le simulateur,
        // le même modèle fp16 rend des logits de coups TOUS NULS (la tête
        // valeur, elle, reste juste) dès que le GPU participe (`.all`,
        // `.cpuAndGPU`) ; en CPU seul, ou en fp32 quelle que soit l'unité,
        // les sorties sont celles de la référence. Une inférence CPU dure
        // ~1,4 ms sur M2 — le Neural Engine n'apporterait rien d'utile ici,
        // et le CPU est l'unité dont le comportement est prouvé par
        // `MaiaFixtureTests` sur toutes les fixtures.
        configuration.computeUnits = .cpuOnly
        guard let model = try? MLModel(contentsOf: url, configuration: configuration) else { return nil }
        self.model = model
    }

    /// - parameter tokens: tenseur de ``MaiaEncoder/tokens(history:)``.
    /// - parameter selfElo: niveau du camp au trait (celui qui joue).
    /// - parameter oppoElo: niveau de son adversaire.
    func predict(tokens: [Float], selfElo: Double, oppoElo: Double) throws -> MaiaPrediction {
        precondition(tokens.count == MaiaEncoder.squareCount * MaiaEncoder.featuresPerSquare)
        let input = try MLMultiArray(
            shape: [1, NSNumber(value: MaiaEncoder.squareCount), NSNumber(value: MaiaEncoder.featuresPerSquare)],
            dataType: .float32
        )
        input.withUnsafeMutableBytes { raw, _ in
            let destination = raw.bindMemory(to: Float.self)
            for (offset, value) in tokens.enumerated() { destination[offset] = value }
        }
        let selfArray = try MLMultiArray(shape: [1], dataType: .float32)
        selfArray[0] = NSNumber(value: Float(selfElo.clamped(to: Self.eloRange)))
        let oppoArray = try MLMultiArray(shape: [1], dataType: .float32)
        oppoArray[0] = NSNumber(value: Float(oppoElo.clamped(to: Self.eloRange)))

        let features = try MLDictionaryFeatureProvider(dictionary: [
            "tokens": MLFeatureValue(multiArray: input),
            "self_elo": MLFeatureValue(multiArray: selfArray),
            "oppo_elo": MLFeatureValue(multiArray: oppoArray),
        ])
        let output = try model.prediction(from: features)
        guard let logits = output.featureValue(for: "move_logits")?.multiArrayValue,
              let value = output.featureValue(for: "value_logits")?.multiArrayValue
        else { throw MaiaModelError.missingOutput }

        let moveLogits = Self.floats(of: logits, count: MaiaMoveTable.vocabularySize)
        let valueLogits = Self.floats(of: value, count: 3)
        // Ordre des étiquettes de la tête valeur : [défaite, nulle, gain].
        let probabilities = MaiaPolicy.softmax(valueLogits.map(Double.init))
        return MaiaPrediction(
            moveLogits: moveLogits, win: probabilities[2], draw: probabilities[1], loss: probabilities[0]
        )
    }

    private static func floats(of array: MLMultiArray, count: Int) -> [Float] {
        precondition(array.count >= count)
        switch array.dataType {
        case .float32:
            return array.withUnsafeBytes { raw in
                Array(raw.bindMemory(to: Float.self).prefix(count))
            }
        default:
            return (0..<count).map { array[$0].floatValue }
        }
    }
}

enum MaiaModelError: Error {
    case missingOutput
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
