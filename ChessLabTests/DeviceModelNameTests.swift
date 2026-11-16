import Testing
@testable import ChessLab

/// Le nom commercial des appareils, pour « Vos appareils » et « Dernier coup joué sur votre … ».
struct DeviceModelNameTests {

    @Test func theThreeTestIPhones() {
        #expect(DeviceModelName.name(for: "iPhone12,1", language: "fr") == "iPhone 11")
        #expect(DeviceModelName.name(for: "iPhone11,6", language: "fr") == "iPhone XS Max")
        #expect(DeviceModelName.name(for: "iPhone19,4", language: "fr") == "iPhone Duo")
    }

    @Test func sizesAndGenerations_followTheLanguage() {
        #expect(DeviceModelName.name(for: "iPad13,10", language: "fr") == "iPad Pro 12,9″ (5ᵉ génération)")
        #expect(DeviceModelName.name(for: "iPad13,10", language: "en") == "iPad Pro 12.9″ (5th generation)")
        #expect(DeviceModelName.name(for: "iPad13,10", language: "es") == "iPad Pro 12,9″ (5.ª generación)")
        #expect(DeviceModelName.name(for: "iPad13,10", language: "de") == "iPad Pro 12,9″ (5. Generation)")
        #expect(DeviceModelName.name(for: "iPad13,10", language: "it") == "iPad Pro 12,9″ (5ª generazione)")
        #expect(DeviceModelName.name(for: "iPad8,1", language: "fr") == "iPad Pro 11″ (1ʳᵉ génération)")
        #expect(DeviceModelName.name(for: "iPad16,6", language: "en") == "iPad Pro 13″ (M4)")
        #expect(DeviceModelName.name(for: "iPad15,7", language: "fr") == "iPad (A16)")
        #expect(DeviceModelName.name(for: "iPhone14,6", language: "en") == "iPhone SE (3rd generation)")
    }

    @Test func englishOrdinals() {
        let expected = [1: "1st", 2: "2nd", 3: "3rd", 4: "4th", 10: "10th", 11: "11th", 12: "12th", 13: "13th", 21: "21st"]
        for (n, ordinal) in expected {
            #expect(DeviceModelName.generation(n, language: "en") == "\(ordinal) generation")
        }
    }

    @Test func unknownModels_fallBackToTheFamily_andPlainKindsPassThrough() {
        #expect(DeviceModelName.name(for: "iPhone99,1", language: "fr") == nil)
        #expect(DeviceModelName.display("iPhone99,1", language: "fr") == "iPhone")
        #expect(DeviceModelName.display("iPad99,1", language: "fr") == "iPad")
        // Ce qu'écrivaient les premières versions : le type seul.
        #expect(DeviceModelName.display("iPad", language: "fr") == "iPad")
        #expect(DeviceModelName.display("Mac", language: "fr") == "Mac")
        // Un nom donné par l'utilisateur passe tel quel, même s'il commence comme un modèle.
        #expect(DeviceModelName.display("iPad du salon", language: "fr") == "iPad du salon")
        #expect(DeviceModelName.display("iPhone, le vieux", language: "fr") == "iPhone, le vieux")
    }

    /// Chaque appareil que Xcode 27.1 sait simuler ET qu'iOS 18 fait tourner (relevé des `modelIdentifier`
    /// de ses profils, 16/11/2026) a un nom.
    @Test func everyXcodeDeviceRunningIOS18_isNamed() {
        let xcode = [
            "iPhone11,2", "iPhone11,4", "iPhone11,8", "iPhone12,1", "iPhone12,3", "iPhone12,5", "iPhone12,8",
            "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4", "iPhone14,2", "iPhone14,3", "iPhone14,4",
            "iPhone14,5", "iPhone14,6", "iPhone14,7", "iPhone14,8", "iPhone15,2", "iPhone15,3", "iPhone15,4",
            "iPhone15,5", "iPhone16,1", "iPhone16,2", "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4",
            "iPhone17,5", "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4", "iPhone18,5", "iPhone19,2",
            "iPhone19,3", "iPhone19,4",
            "iPad7,12", "iPad8,1", "iPad8,5", "iPad8,9", "iPad8,12", "iPad11,1", "iPad11,3", "iPad11,7",
            "iPad12,2", "iPad13,2", "iPad13,5", "iPad13,10", "iPad13,17", "iPad13,18", "iPad14,1", "iPad14,3",
            "iPad14,4", "iPad14,5", "iPad14,9", "iPad14,11", "iPad15,3", "iPad15,5", "iPad15,7", "iPad16,2",
            "iPad16,4", "iPad16,6", "iPad16,9", "iPad16,11", "iPad17,2", "iPad17,4",
        ]
        let unnamed = xcode.filter { DeviceModelName.name(for: $0, language: "fr") == nil }
        #expect(unnamed.isEmpty, "sans nom : \(unnamed)")
    }
}
