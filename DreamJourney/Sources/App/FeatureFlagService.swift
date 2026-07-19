import Foundation

/// Centralizes launch-argument access for Debug and simulator UIQA only.
///
/// Production artifacts intentionally receive an empty configuration so a
/// stale command-line argument can never enable a seed, smoke flow, or hidden
/// feature. Keep scenario orchestration outside of this type; it is the
/// fail-closed boundary between process arguments and the app runtime.
struct QALaunchConfiguration {
    static let shared = QALaunchConfiguration()

    private let arguments: [String]

    private init() {
        #if DEBUG || UI_QA_SIMULATOR
        arguments = ProcessInfo.processInfo.arguments
        #else
        arguments = []
        #endif
    }

    func contains(_ argument: String) -> Bool {
        arguments.contains(argument)
    }

    func contains(prefix: String) -> Bool {
        arguments.contains { $0.hasPrefix(prefix) }
    }

    func value(forPrefix prefix: String) -> String? {
        arguments
            .first(where: { $0.hasPrefix(prefix) })
            .map { String($0.dropFirst(prefix.count)) }
            .flatMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
    }
}

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
    private static let currentStorageVersion = 11
    private static let defaultEnabled: Set<DJFeature> = [
        .echoTextInput,
        .profileSettings,
        .legalCenter,
        .accountDeletion,
    ]
    private static let nonPersistentFeatures: Set<DJFeature> = [
        .echoImageInput,
        .timeLetters,
        .personaSettings,
        .archiveAudioUpload,
        .archiveVideoUpload,
        .archiveRemoteFetch,
        .archiveLocalAnalysis,
        .familyManagement,
        .familySpace,
        .accountPasswordChange,
        .careDashboard,
        .careDoctorContact,
        .voiceCloneShell,
        .digitalHumanLivePanel,
    ]

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
            #if DEBUG || UI_QA_SIMULATOR
            if isEnabled {
                transientEnabled.insert(feature)
            } else {
                transientEnabled.remove(feature)
            }
            #else
            transientEnabled.remove(feature)
            #endif
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

    #if DEBUG || UI_QA_SIMULATOR
    func enableForCurrentLaunch(_ feature: DJFeature) {
        transientEnabled.insert(feature)
    }
    #endif

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
