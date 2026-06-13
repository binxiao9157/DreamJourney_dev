import Foundation

enum MemoryArchiveVoiceProfileStatus: String, Codable, Equatable {
    case collecting
    case readyForTraining
    case training
    case ready
    case failed
    case disabled
}

enum MemoryArchiveVoiceProfileTrainingError: Error, Equatable {
    case service(String)
}

enum MemoryArchiveVoiceProfileError: Error, Equatable {
    case profileNotFound
    case profileNotReady
    case trainingFailed(String)
}

protocol MemoryArchiveVoiceTrainingClient {
    func trainVoice(
        audioURL: URL,
        speakerId: String,
        completion: @escaping (Result<String, MemoryArchiveVoiceProfileTrainingError>) -> Void
    )
}

struct MemoryArchiveVoiceProfile: Codable, Identifiable, Equatable, MemoryPrivacyScoped {
    let id: String
    var personName: String
    var personId: String?
    var sampleArchiveItemIds: [String]
    var requiredSampleCount: Int
    var speakerId: String?
    var status: MemoryArchiveVoiceProfileStatus
    var statusMessage: String?
    var privacyMetadata: MemoryPrivacyMetadata
    var createdAt: Date
    var updatedAt: Date
    var trainedAt: Date?

    var sampleCount: Int {
        sampleArchiveItemIds.count
    }
}

final class MemoryArchiveVoiceProfileStore {
    static let shared = MemoryArchiveVoiceProfileStore()

    private let defaults: UserDefaults
    private let storageKey: String
    private let requiredSampleCount: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "dreamjourney.memoryArchive.voiceProfiles",
        requiredSampleCount: Int = 3
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.requiredSampleCount = requiredSampleCount
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func profiles() -> [MemoryArchiveVoiceProfile] {
        load().sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func profile(for personName: String) -> MemoryArchiveVoiceProfile? {
        let normalizedName = Self.normalized(personName)
        guard !normalizedName.isEmpty else { return nil }
        return load().first { $0.personName == normalizedName }
    }

    @discardableResult
    func registerSample(
        _ item: MemoryArchiveItem,
        targetPersonName: String? = nil,
        targetPersonId: String? = nil,
        now: Date = Date()
    ) -> MemoryArchiveVoiceProfile? {
        guard item.kind == .voiceSample else { return nil }
        let personName = Self.inferConcretePersonName(
            explicitName: targetPersonName,
            title: item.title,
            note: item.note
        )
        guard let personName else { return nil }

        var all = load()
        if let index = all.firstIndex(where: { $0.personName == personName }) {
            var profile = all[index]
            if !profile.sampleArchiveItemIds.contains(item.id) {
                profile.sampleArchiveItemIds.append(item.id)
            }
            if profile.personId == nil {
                profile.personId = targetPersonId
            }
            profile.privacyMetadata = Self.mergedPrivacy(existing: profile.privacyMetadata, incoming: item.privacyMetadata)
            profile.status = Self.nextStatus(for: profile, requiredSampleCount: requiredSampleCount)
            profile.statusMessage = Self.statusMessage(for: profile)
            profile.updatedAt = now
            all[index] = profile
            save(all)
            return profile
        }

        var profile = MemoryArchiveVoiceProfile(
            id: "voice_profile_\(UUID().uuidString)",
            personName: personName,
            personId: targetPersonId,
            sampleArchiveItemIds: [item.id],
            requiredSampleCount: requiredSampleCount,
            speakerId: nil,
            status: .collecting,
            statusMessage: nil,
            privacyMetadata: item.privacyMetadata,
            createdAt: now,
            updatedAt: now,
            trainedAt: nil
        )
        profile.status = Self.nextStatus(for: profile, requiredSampleCount: requiredSampleCount)
        profile.statusMessage = Self.statusMessage(for: profile)
        all.append(profile)
        save(all)
        return profile
    }

    func startTraining(
        profileID: String,
        sampleURL: URL,
        trainer: MemoryArchiveVoiceTrainingClient,
        completion: @escaping (Result<MemoryArchiveVoiceProfile, MemoryArchiveVoiceProfileError>) -> Void
    ) {
        var all = load()
        guard let index = all.firstIndex(where: { $0.id == profileID }) else {
            completion(.failure(.profileNotFound))
            return
        }
        var profile = all[index]
        guard profile.status == .readyForTraining || profile.status == .failed else {
            completion(.failure(.profileNotReady))
            return
        }

        let requestedSpeakerId = profile.speakerId ?? Self.proposedSpeakerId(for: profile)
        profile.status = .training
        profile.statusMessage = "正在训练\(profile.personName)的声纹音色"
        profile.updatedAt = Date()
        all[index] = profile
        save(all)

        trainer.trainVoice(audioURL: sampleURL, speakerId: requestedSpeakerId) { [weak self] result in
            guard let self else { return }
            var latest = self.load()
            guard let latestIndex = latest.firstIndex(where: { $0.id == profileID }) else {
                completion(.failure(.profileNotFound))
                return
            }
            var updated = latest[latestIndex]
            switch result {
            case .success(let speakerId):
                updated.speakerId = speakerId
                updated.status = .ready
                updated.statusMessage = "\(updated.personName)的声纹音色已就绪"
                updated.trainedAt = Date()
                updated.updatedAt = Date()
                latest[latestIndex] = updated
                self.save(latest)
                completion(.success(updated))
            case .failure(let error):
                updated.status = .failed
                updated.statusMessage = "声纹训练失败：\(error.localizedDescription)"
                updated.updatedAt = Date()
                latest[latestIndex] = updated
                self.save(latest)
                completion(.failure(.trainingFailed(error.localizedDescription)))
            }
        }
    }

    func reset() {
        defaults.removeObject(forKey: storageKey)
    }

    private func load() -> [MemoryArchiveVoiceProfile] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? decoder.decode([MemoryArchiveVoiceProfile].self, from: data)) ?? []
    }

    private func save(_ profiles: [MemoryArchiveVoiceProfile]) {
        guard let data = try? encoder.encode(profiles) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func nextStatus(
        for profile: MemoryArchiveVoiceProfile,
        requiredSampleCount: Int
    ) -> MemoryArchiveVoiceProfileStatus {
        if profile.speakerId != nil {
            return .ready
        }
        guard PrivacyScopePolicy.canUse(metadata: profile.privacyMetadata, surface: .remoteExtraction) else {
            return profile.sampleCount >= requiredSampleCount ? .disabled : .collecting
        }
        return profile.sampleCount >= requiredSampleCount ? .readyForTraining : .collecting
    }

    private static func statusMessage(for profile: MemoryArchiveVoiceProfile) -> String {
        switch profile.status {
        case .collecting:
            return "\(profile.personName)声纹样本 \(profile.sampleCount)/\(profile.requiredSampleCount)"
        case .readyForTraining:
            return "\(profile.personName)已收集 \(profile.sampleCount) 段语音，可开始训练音色"
        case .training:
            return "正在训练\(profile.personName)的声纹音色"
        case .ready:
            return "\(profile.personName)的声纹音色已就绪"
        case .failed:
            return "\(profile.personName)声纹训练失败，可稍后重试"
        case .disabled:
            return "\(profile.personName)语音样本未授权远端训练，仅保留本机档案"
        }
    }

    private static func proposedSpeakerId(for profile: MemoryArchiveVoiceProfile) -> String {
        let suffix = profile.id
            .replacingOccurrences(of: "voice_profile_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .prefix(24)
        return "DJ_\(suffix)"
    }

    private static func mergedPrivacy(
        existing: MemoryPrivacyMetadata,
        incoming: MemoryPrivacyMetadata
    ) -> MemoryPrivacyMetadata {
        let scope = moreRestrictiveScope(existing.scope, incoming.scope)
        let base = MemoryPrivacyMetadata(
            scope: scope,
            sourceRefs: existing.sourceRefs,
            createdBySurface: existing.createdBySurface,
            createdAt: existing.createdAt,
            familyVisibility: existing.familyVisibility
        )
        return base.mergingSourceRefs(from: incoming)
    }

    private static func moreRestrictiveScope(
        _ lhs: MemoryPrivacyScope,
        _ rhs: MemoryPrivacyScope
    ) -> MemoryPrivacyScope {
        rank(lhs) <= rank(rhs) ? lhs : rhs
    }

    private static func rank(_ scope: MemoryPrivacyScope) -> Int {
        switch scope {
        case .privateOnly: return 0
        case .localOnly: return 1
        case .familyCircle: return 2
        case .generationAllowed: return 3
        }
    }

    private static func inferConcretePersonName(
        explicitName: String?,
        title: String,
        note: String
    ) -> String? {
        if let explicitName = concreteChineseName(from: explicitName) {
            return explicitName
        }

        let normalizedTitle = normalized(title)
        if let possessiveRange = normalizedTitle.range(of: "的") {
            let prefix = String(normalizedTitle[..<possessiveRange.lowerBound])
            if let name = concreteChineseName(from: prefix) {
                return name
            }
        }

        if let name = firstConcreteChineseName(in: normalizedTitle) {
            return name
        }
        return firstConcreteChineseName(in: normalized(note))
    }

    private static func firstConcreteChineseName(in value: String) -> String? {
        let separators = CharacterSet(charactersIn: " _-—·，。！？；、,.!?;:：()（）[]【】0123456789")
        return value
            .components(separatedBy: separators)
            .compactMap { concreteChineseName(from: $0) }
            .first
    }

    private static func concreteChineseName(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        var value = normalized(rawValue)
        let suffixes = [
            "的第一段语音", "的第二段语音", "的第三段语音", "的第四段语音", "的第五段语音",
            "第一段语音", "第二段语音", "第三段语音", "第四段语音", "第五段语音",
            "的语音样本", "语音样本", "的语音", "语音", "的录音", "录音", "声音", "声纹"
        ]
        for suffix in suffixes where value.hasSuffix(suffix) {
            value.removeLast(suffix.count)
            break
        }
        value = normalized(value)
        guard value.count >= 2, value.count <= 4 else { return nil }
        guard isChineseOnly(value) else { return nil }
        guard !genericKinshipNames.contains(value) else { return nil }
        guard !blockedVoiceProfileWords.contains(value) else { return nil }
        return value
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "关于", with: "")
    }

    private static func isChineseOnly(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { scalar in
            scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
        }
    }

    private static let genericKinshipNames: Set<String> = [
        "爸爸", "父亲", "妈妈", "母亲", "爷爷", "奶奶", "外公", "外婆",
        "姥姥", "姥爷", "叔叔", "阿姨", "伯伯", "伯父", "姑姑", "舅舅",
        "妻子", "丈夫", "老伴", "长辈", "老人"
    ]

    private static let blockedVoiceProfileWords: Set<String> = [
        "导入", "样本", "语音", "录音", "长辈", "素材", "声音", "声纹",
        "第一段", "第二段", "第三段", "第四段", "第五段"
    ]
}

#if !MEMORY_PRIVACY_INTEGRATION_VERIFY
final class VoiceCloneServiceProfileTrainer: MemoryArchiveVoiceTrainingClient {
    static let shared = VoiceCloneServiceProfileTrainer()

    func trainVoice(
        audioURL: URL,
        speakerId: String,
        completion: @escaping (Result<String, MemoryArchiveVoiceProfileTrainingError>) -> Void
    ) {
        VoiceCloneService.shared.trainVoice(
            audioURL: audioURL,
            speakerId: speakerId,
            persistAsCurrent: false
        ) { result in
            switch result {
            case .success(let speakerId):
                completion(.success(speakerId))
            case .failure(let error):
                completion(.failure(.service(error.localizedDescription)))
            }
        }
    }
}
#endif
