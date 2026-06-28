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
    private static let currentStorageVersion = 10
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
        .digitalHumanLivePanel,
    ]
    private static let nonPersistentFeatures: Set<DJFeature> = []

    private var enabled: Set<DJFeature>
    private var transientEnabled: Set<DJFeature> = []

    private init() {
        let storedVersion = UserDefaults.standard.integer(forKey: Self.storageVersionKey)
        if storedVersion == Self.currentStorageVersion,
           let rawValues = UserDefaults.standard.array(forKey: Self.storageKey) as? [String] {
            self.enabled = Set(rawValues.compactMap(DJFeature.init(rawValue:))).subtracting(Self.nonPersistentFeatures)
            persist()
        } else {
            self.enabled = Self.defaultEnabled
            persist()
        }
    }

    func isEnabled(_ feature: DJFeature) -> Bool {
        enabled.contains(feature) || transientEnabled.contains(feature)
    }

    func set(_ feature: DJFeature, enabled isEnabled: Bool) {
        if Self.nonPersistentFeatures.contains(feature) {
            enabled.remove(feature)
            if isEnabled {
                transientEnabled.insert(feature)
            } else {
                transientEnabled.remove(feature)
            }
            persist()
            return
        }

        if isEnabled {
            enabled.insert(feature)
        } else {
            enabled.remove(feature)
        }
        persist()
    }

    func enableForCurrentLaunch(_ feature: DJFeature) {
        transientEnabled.insert(feature)
    }

    func resetToDefaults() {
        enabled = Self.defaultEnabled
        transientEnabled.removeAll()
        persist()
    }

    private func persist() {
        let rawValues = enabled.map(\.rawValue).sorted()
        UserDefaults.standard.set(rawValues, forKey: Self.storageKey)
        UserDefaults.standard.set(Self.currentStorageVersion, forKey: Self.storageVersionKey)
    }
}
