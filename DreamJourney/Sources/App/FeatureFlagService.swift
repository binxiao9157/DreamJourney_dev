import Foundation

enum DJFeature: String, CaseIterable {
    case echoTextInput
    case echoImageInput
    case timeLetters
    case personaSettings
    case archiveAudioUpload
    case familyManagement
    case familySpace
    case legalCenter
    case accountDeletion
    case careDashboard
}

final class FeatureFlagService {
    static let shared = FeatureFlagService()

    private static let storageKey = "dj.featureFlags.enabled"
    private static let defaultEnabled: Set<DJFeature> = [
        .familyManagement,
        .legalCenter,
        .careDashboard,
    ]

    private var enabled: Set<DJFeature>

    private init() {
        if let rawValues = UserDefaults.standard.array(forKey: Self.storageKey) as? [String] {
            self.enabled = Set(rawValues.compactMap(DJFeature.init(rawValue:)))
        } else {
            self.enabled = Self.defaultEnabled
        }
    }

    func isEnabled(_ feature: DJFeature) -> Bool {
        enabled.contains(feature)
    }

    func set(_ feature: DJFeature, enabled isEnabled: Bool) {
        if isEnabled {
            enabled.insert(feature)
        } else {
            enabled.remove(feature)
        }
        persist()
    }

    func resetToDefaults() {
        enabled = Self.defaultEnabled
        persist()
    }

    private func persist() {
        let rawValues = enabled.map(\.rawValue).sorted()
        UserDefaults.standard.set(rawValues, forKey: Self.storageKey)
    }
}
