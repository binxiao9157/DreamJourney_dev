import Foundation

enum DJFeature: String, CaseIterable {
    case echoTextInput
    case echoImageInput
    case timeLetters
    case profileSettings
    case personaSettings
    case archiveAudioUpload
    case archiveVideoUpload
    case archiveRemoteFetch
    case archiveLocalAnalysis
    case familyManagement
    case familySpace
    case legalCenter
    case accountDeletion
    case accountPasswordChange
    case careDashboard
    case careDoctorContact
    case voiceCloneShell
    case digitalHumanLivePanel
}

final class FeatureFlagService {
    static let shared = FeatureFlagService()

    private static let storageKey = "dj.featureFlags.enabled"
    private static let storageVersionKey = "dj.featureFlags.schemaVersion"
    private static let currentStorageVersion = 7
    private static let defaultEnabled: Set<DJFeature> = [
        .careDashboard,
        .familyManagement,
        .familySpace,
        .personaSettings,
        .profileSettings,
        .legalCenter,
        .timeLetters,
        .voiceCloneShell,
        .accountDeletion,
    ]

    private var enabled: Set<DJFeature>

    private init() {
        let storedVersion = UserDefaults.standard.integer(forKey: Self.storageVersionKey)
        if storedVersion == Self.currentStorageVersion,
           let rawValues = UserDefaults.standard.array(forKey: Self.storageKey) as? [String] {
            self.enabled = Set(rawValues.compactMap(DJFeature.init(rawValue:)))
        } else {
            self.enabled = Self.defaultEnabled
            persist()
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
        UserDefaults.standard.set(Self.currentStorageVersion, forKey: Self.storageVersionKey)
    }
}
