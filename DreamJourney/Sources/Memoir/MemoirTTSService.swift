import Foundation
import AVFoundation
import CryptoKit
import CocoaLumberjack

// MARK: - 回忆录 TTS 朗读服务

/// 使用后端代理的火山引擎大模型 TTS V3 + 声音复刻音色，将回忆录散文合成为语音
///
/// 流程：
/// 1. 检查 speaker_id 是否就绪
/// 2. 调用 DreamJourney 后端 `/voice/synthesis`，传入 speaker_id + 文本
/// 3. 后端代理火山 TTS V3 并返回 base64 音频
/// 4. 保存到当前账号 generation 隔离的 Application Support 缓存目录

struct MemoirTTSCacheIdentity: Codable, Equatable {
    let memoirId: String
    let personaOwnerId: String
    let roleKey: String
    let voiceProfileId: String
    let textHash: String
    let audioFormat: String
    let providerMode: String

    init?(
        memoirId: String,
        personaOwnerId: String,
        roleKey: String,
        voiceProfileId: String,
        textHash: String,
        audioFormat: String,
        providerMode: String
    ) {
        let memoirId = MemoirTTSCacheStoragePolicy.normalized(memoirId)
        let personaOwnerId = MemoirTTSCacheStoragePolicy.normalized(personaOwnerId)
        let roleKey = MemoirTTSCacheStoragePolicy.normalized(roleKey)
        let voiceProfileId = MemoirTTSCacheStoragePolicy.normalized(voiceProfileId)
        let textHash = MemoirTTSCacheStoragePolicy.normalized(textHash)
        let audioFormat = MemoirTTSCacheStoragePolicy.normalized(audioFormat).lowercased()
        let providerMode = MemoirTTSCacheStoragePolicy.normalized(providerMode).lowercased()
        guard !memoirId.isEmpty,
              !personaOwnerId.isEmpty,
              !roleKey.isEmpty,
              !voiceProfileId.isEmpty,
              !textHash.isEmpty,
              !audioFormat.isEmpty,
              !providerMode.isEmpty else {
            return nil
        }
        self.memoirId = memoirId
        self.personaOwnerId = personaOwnerId
        self.roleKey = roleKey
        self.voiceProfileId = voiceProfileId
        self.textHash = textHash
        self.audioFormat = audioFormat
        self.providerMode = providerMode
    }

    var cacheDigest: String {
        MemoirTTSCacheStoragePolicy.digest(
            "memoir-tts-cache-identity-v1|\(memoirId)|\(personaOwnerId)|\(roleKey)|\(voiceProfileId)|\(textHash)|\(audioFormat)|\(providerMode)"
        )
    }
}

struct MemoirTTSCacheEntry: Codable {
    let memoirId: String
    let audioFileURL: URL
    let voiceProfileId: String
    let textHash: String
    let audioFormat: String
    let visemeTimeline: DigitalHumanLipSyncTimeline?
    let createdAt: Date
    let providerMode: String
    let cacheIdentity: MemoirTTSCacheIdentity
}

struct MemoirTTSCacheResult {
    let audioFileURL: URL
    let cacheEntry: MemoirTTSCacheEntry

    var visemeTimeline: DigitalHumanLipSyncTimeline? {
        cacheEntry.visemeTimeline
    }
}

private enum MemoirTTSCacheStoragePolicy {
    static let schemaVersion = 3

    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private struct MemoirTTSCacheScope: Codable, Equatable {
    let subjectId: String
    let vaultId: String
    let generation: UInt64
    let generationId: UUID

    init?(accountLease: AccountLease) {
        let subjectId = MemoirTTSCacheStoragePolicy.normalized(accountLease.subjectId)
        let vaultId = MemoirTTSCacheStoragePolicy.normalized(accountLease.vaultId)
        guard !subjectId.isEmpty, !vaultId.isEmpty else {
            return nil
        }
        self.subjectId = subjectId
        self.vaultId = vaultId
        generation = accountLease.generation
        generationId = accountLease.generationId
    }

    var scopeDigest: String {
        MemoirTTSCacheStoragePolicy.digest(
            "memoir-tts-cache-v2|\(subjectId)|\(vaultId)|\(generation)|\(generationId.uuidString.lowercased())"
        )
    }

    func matches(_ accountLease: AccountLease) -> Bool {
        guard let other = MemoirTTSCacheScope(accountLease: accountLease) else {
            return false
        }
        return self == other
    }
}

private struct MemoirTTSCacheEnvelope: Codable {
    let schemaVersion: Int
    let scope: MemoirTTSCacheScope
    let entry: MemoirTTSCacheEntry
}

private struct MemoirTTSScopedAccess {
    let accountLease: AccountLease
    let scope: MemoirTTSCacheScope
}

private struct MemoirTTSCacheLookup {
    let memoirId: String
    let personaOwnerId: String
    let roleKey: String
    let voiceProfileId: String?
    let textHash: String?

    init?(
        memoirId: String,
        personaOwnerId: String,
        roleKey: String,
        voiceProfileId: String? = nil,
        textHash: String? = nil
    ) {
        let memoirId = MemoirTTSCacheStoragePolicy.normalized(memoirId)
        let personaOwnerId = MemoirTTSCacheStoragePolicy.normalized(personaOwnerId)
        let roleKey = MemoirTTSCacheStoragePolicy.normalized(roleKey)
        let voiceProfileId = voiceProfileId.map(MemoirTTSCacheStoragePolicy.normalized)
        let textHash = textHash.map(MemoirTTSCacheStoragePolicy.normalized)
        guard !memoirId.isEmpty,
              !personaOwnerId.isEmpty,
              !roleKey.isEmpty,
              voiceProfileId?.isEmpty != true,
              textHash?.isEmpty != true else {
            return nil
        }
        self.memoirId = memoirId
        self.personaOwnerId = personaOwnerId
        self.roleKey = roleKey
        self.voiceProfileId = voiceProfileId
        self.textHash = textHash
    }

    func matches(_ identity: MemoirTTSCacheIdentity) -> Bool {
        guard identity.memoirId == memoirId,
              identity.personaOwnerId == personaOwnerId,
              identity.roleKey == roleKey else {
            return false
        }
        if let voiceProfileId, identity.voiceProfileId != voiceProfileId {
            return false
        }
        if let textHash, identity.textHash != textHash {
            return false
        }
        return true
    }
}

private struct MemoirTTSLegacyQuarantineReceipt: Codable {
    let schemaVersion: Int
    let sourcePath: String
    let quarantinePath: String
    let reason: String
    let quarantinedAt: Date
}

private enum MemoirTTSCacheLifecycleDisposition: Equatable {
    case absent
    case retained
    case removed
    case failed

    var remainingLocalData: Bool {
        switch self {
        case .retained, .failed:
            return true
        case .absent, .removed:
            return false
        }
    }
}

final class MemoirTTSService {

    static let shared = MemoirTTSService()

    private struct SynthesisOperation: Equatable {
        let id: UUID
        let accountLease: AccountLease
    }

    // MARK: - 配置

    /// 账号 generation 隔离的音频与元数据根目录。
    private let scopedAudioRootDirectory: URL
    private let scopedCacheRootDirectory: URL
    /// 旧版本全局缓存仅用于隔离，禁止作为当前账号缓存读取。
    private let legacyAudioDirectory: URL
    private let legacyCacheDirectory: URL
    private let legacyQuarantineDirectory: URL
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let voiceCloneSynthesisClient: VoiceCloneSynthesisClientPort

    // MARK: - 合成状态

    private let stateLock = NSLock()
    private let storageLock = NSRecursiveLock()
    private var activeSynthesisOperation: SynthesisOperation?
    private var legacyRetirementAttempted = false

    // MARK: - Init

    private init(
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        voiceCloneSynthesisClient: VoiceCloneSynthesisClientPort = DreamJourneyBackendClient.shared
    ) {
        self.accountLeaseRuntime = accountLeaseRuntime
        self.voiceCloneSynthesisClient = voiceCloneSynthesisClient
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        scopedAudioRootDirectory = appSupport.appendingPathComponent("memoir_audio_scoped_v2", isDirectory: true)
        scopedCacheRootDirectory = appSupport.appendingPathComponent("memoir_tts_cache_scoped_v2", isDirectory: true)
        legacyAudioDirectory = appSupport.appendingPathComponent("memoir_audio", isDirectory: true)
        legacyCacheDirectory = appSupport.appendingPathComponent("memoir_tts_cache", isDirectory: true)
        legacyQuarantineDirectory = appSupport.appendingPathComponent("memoir_tts_quarantine", isDirectory: true)
        try? FileManager.default.createDirectory(at: scopedAudioRootDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: scopedCacheRootDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: legacyQuarantineDirectory, withIntermediateDirectories: true)
    }

    // MARK: - 公开 API

    /// 将回忆录散文合成为语音
    /// - Parameters:
    ///   - memoir: 回忆录模型
    ///   - speed: 语速（-50~100，默认 -10 稍慢适合老人听）
    ///   - volume: 音量（-50~100，默认 10 稍大声适合老人听）
    ///   - completion: 结果回调，成功返回本地音频文件 URL
    func synthesize(memoir: MemoirModel,
                    speed: Int = -10,
                    volume: Int = 10,
                    completion: @escaping (Result<URL, TTSError>) -> Void) {

        guard voiceCloneSynthesisClient.isVoiceCloneSynthesisConfigured else {
            completion(.failure(.apiKeyMissing))
            return
        }

        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: memoir.authorId),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            completion(.failure(.accountSessionChanged))
            return
        }

        guard let speakerId = memoir.speakerId ?? VoiceCloneService.shared.currentUsableSpeakerId,
              !speakerId.isEmpty else {
            completion(.failure(.noSpeakerId))
            return
        }

        guard !memoir.prose.isEmpty else {
            completion(.failure(.emptyText))
            return
        }

        guard let operation = beginSynthesis(accountLease: accountLease) else {
            completion(.failure(.alreadySynthesizing))
            return
        }

        // 先检查音色是否就绪
        VoiceCloneService.shared.isVoiceReady(
            speakerId: speakerId,
            accountLease: accountLease
        ) { [weak self] ready in
            guard let self,
                  self.isCurrent(operation),
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                self?.finishSynthesis(operation)
                return
            }
            if !ready {
                self.finishSynthesis(operation)
                self.deliver(
                    .failure(.voiceNotReady),
                    accountLease: accountLease,
                    completion: completion
                )
                return
            }
            self.performSynthesis(
                memoir: memoir,
                speakerId: speakerId,
                speed: speed,
                volume: volume,
                operation: operation,
                completion: completion
            )
        }
    }

    /// 获取与回忆录当前 owner、音色和文本完全匹配的已合成音频文件 URL。
    func getAudioURL(for memoir: MemoirModel) -> URL? {
        getCachedSynthesis(for: memoir)?.audioFileURL
    }

    /// 获取与回忆录当前 owner、音色和文本完全匹配的缓存结果。
    func getCachedSynthesis(for memoir: MemoirModel) -> MemoirTTSCacheResult? {
        guard let access = captureScopedAccess(forSubjectId: memoir.authorId, at: .request),
              let voiceProfileId = resolvedVoiceProfileId(for: memoir),
              let lookup = MemoirTTSCacheLookup(
                  memoirId: memoir.id,
                  personaOwnerId: memoir.authorId,
                  roleKey: "memoir",
                  voiceProfileId: voiceProfileId,
                  textHash: Self.textHash(for: memoir.prose)
              ),
              let result = getCachedSynthesis(matching: lookup, access: access) else {
            return nil
        }
        return result
    }

    /// 获取与当前文本匹配的口型时间线。Echo 的数字人优先使用真实 TTS timeline，
    /// 找不到同文本缓存时再降级到播放器音量/SDK fallback。
    func getCachedLipSyncTimeline(forText text: String) -> DigitalHumanLipSyncTimeline? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty,
              let access = captureScopedAccess(forSubjectId: nil, at: .request) else {
            return nil
        }

        storageLock.lock()
        defer { storageLock.unlock() }
        retireLegacyGlobalCacheIfNeeded()
        ensureScopeDirectories(for: access.scope)
        let expectedTextHash = Self.textHash(for: text)
        guard let cacheFiles = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory(for: access.scope),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let matchingEntries = cacheFiles.compactMap { fileURL -> MemoirTTSCacheEntry? in
            guard let entry = loadCacheEntry(from: fileURL, scope: access.scope),
                  entry.textHash == expectedTextHash,
                  entry.cacheIdentity.roleKey == "memoir",
                  entry.visemeTimeline?.frames.isEmpty == false,
                  FileManager.default.fileExists(atPath: entry.audioFileURL.path) else {
                return nil
            }
            return entry
        }
        let voiceProfileIds = Set(matchingEntries.map(\.cacheIdentity.voiceProfileId))
        let timeline = voiceProfileIds.count == 1
            ? matchingEntries.sorted { $0.createdAt > $1.createdAt }.first?.visemeTimeline
            : nil
        guard accountLeaseRuntime.validate(access.accountLease, at: .runtime).allowed else {
            return nil
        }
        return timeline
    }

    /// 删除当前 owner 的回忆录缓存变体。文本编辑后不保留旧音色或旧 Provider 的音频。
    func deleteAudio(for memoir: MemoirModel) {
        guard let access = captureScopedAccess(forSubjectId: memoir.authorId, at: .request),
              let lookup = MemoirTTSCacheLookup(
                  memoirId: memoir.id,
                  personaOwnerId: memoir.authorId,
                  roleKey: "memoir"
              ) else {
            return
        }
        retireLegacyGlobalCacheIfNeeded()
        ensureScopeDirectories(for: access.scope)

        storageLock.lock()
        defer { storageLock.unlock() }
        let scopedURLs = cachedEntries(
            matching: lookup,
            scope: access.scope,
            requiresAudioFile: false
        ).flatMap { entry in
            [entry.audioFileURL, cacheFileURL(for: entry.cacheIdentity, scope: access.scope)]
        }
        let previousFiles = Dictionary(uniqueKeysWithValues: scopedURLs.compactMap { url in
            (try? Data(contentsOf: url)).map { (url, $0) }
        })
        scopedURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        guard accountLeaseRuntime.validate(access.accountLease, at: .commit).allowed else {
            previousFiles.forEach { url, data in restore(data, at: url) }
            return
        }
    }

    func handleAccountLifecycle(
        _ context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        guard requestedOutcome != .failed else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "memoirTTSLifecycleRequestedFailure"
            )
        }
        guard let oldAccountLease = context.oldAccountLease,
              oldAccountLease.generation == context.oldGeneration,
              let oldScope = MemoirTTSCacheScope(accountLease: oldAccountLease) else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "memoirTTSLifecycleOldScopeMissing"
            )
        }

        cancelSynthesisRuntime(for: oldScope)
        let purge = context.event == .accountDeletion
            || requestedOutcome == .cleared
            || requestedOutcome == .purged
        let disposition = handleScopedCacheLifecycle(scope: oldScope, purge: purge)
        guard disposition != .failed else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "memoirTTSLifecycleScopeRemovalFailed"
            )
        }

        return .completed(
            requestedOutcome,
            remainingLocalData: disposition.remainingLocalData,
            detailCode: memoirTTSLifecycleDetailCode(for: requestedOutcome)
        )
    }

    // MARK: - 内部实现

    private func performSynthesis(memoir: MemoirModel,
                                   speakerId: String,
                                   speed: Int,
                                   volume: Int,
                                   operation: SynthesisOperation,
                                   completion: @escaping (Result<URL, TTSError>) -> Void) {

        let accountLease = operation.accountLease
        guard isCurrent(operation),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            finishSynthesis(operation)
            return
        }

        guard let scope = VoiceDigitalHumanOperationScope(
            accountLease: accountLease,
            personaOwnerId: memoir.authorId,
            roleKey: "memoir",
            runtimeGeneration: accountLease.generation
        ), let request = VoiceCloneSynthesisRequest(
            scope: scope,
            voiceProfileId: speakerId,
            text: memoir.prose,
            audioFormat: "mp3",
            sampleRate: 24000,
            speechRate: speed,
            loudnessRate: volume
        ) else {
            finishSynthesis(operation)
            deliver(
                .failure(.accountSessionChanged),
                accountLease: accountLease,
                completion: completion
            )
            return
        }

        DDLogInfo("[MemoirTTS] 通过后端合成: memoirId=\(memoir.id), speakerId=\(speakerId), 文本长度=\(memoir.prose.count)")
        voiceCloneSynthesisClient.requestVoiceCloneSynthesis(request) { [weak self] result in
            guard let self,
                  self.isCurrent(operation),
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                self?.finishSynthesis(operation)
                return
            }
            switch result {
            case .success(let synthesis):
                guard let audioData = synthesis.audioData, !audioData.isEmpty else {
                    self.finishSynthesis(operation)
                    DDLogError("[MemoirTTS] 后端合成音频为空或无法解码")
                    self.deliver(
                        .failure(.synthesisFailed("合成音频解码失败")),
                        accountLease: accountLease,
                        completion: completion
                    )
                    return
                }
                let audioFormat = Self.normalizedAudioFormat(synthesis.audioFormat)
                let returnedVoiceProfileId = MemoirTTSCacheStoragePolicy.normalized(synthesis.voiceProfileId)
                guard returnedVoiceProfileId == request.voiceProfileId else {
                    self.finishSynthesis(operation)
                    DDLogError("[MemoirTTS] 后端返回的音色与请求不一致: requested=\(request.voiceProfileId), returned=\(returnedVoiceProfileId)")
                    self.deliver(
                        .failure(.synthesisFailed("合成音色与请求不一致")),
                        accountLease: accountLease,
                        completion: completion
                    )
                    return
                }
                guard let cacheScope = MemoirTTSCacheScope(accountLease: accountLease),
                      let cacheIdentity = MemoirTTSCacheIdentity(
                          memoirId: memoir.id,
                          personaOwnerId: scope.personaOwnerId,
                          roleKey: scope.roleKey,
                          voiceProfileId: returnedVoiceProfileId,
                          textHash: Self.textHash(for: memoir.prose),
                          audioFormat: audioFormat,
                          providerMode: synthesis.providerMode
                      ) else {
                    self.finishSynthesis(operation)
                    self.deliver(
                        .failure(.synthesisFailed("合成响应缺少缓存身份字段")),
                        accountLease: accountLease,
                        completion: completion
                    )
                    return
                }
                let outputPath = self.audioFileURL(
                    for: cacheIdentity,
                    scope: cacheScope
                )
                let cacheEntry = MemoirTTSCacheEntry(
                    memoirId: memoir.id,
                    audioFileURL: outputPath,
                    voiceProfileId: returnedVoiceProfileId,
                    textHash: Self.textHash(for: memoir.prose),
                    audioFormat: audioFormat,
                    visemeTimeline: synthesis.visemeTimeline,
                    createdAt: Date(),
                    providerMode: cacheIdentity.providerMode,
                    cacheIdentity: cacheIdentity
                )
                do {
                    try self.commitSynthesisArtifacts(
                        audioData: audioData,
                        cacheEntry: cacheEntry,
                        operation: operation
                    )
                    self.finishSynthesis(operation)
                    DDLogInfo("[MemoirTTS] 合成完成: \(outputPath.path), 大小=\(audioData.count) bytes, timeline=\(synthesis.visemeTimeline?.frames.count ?? 0)")
                    self.deliver(
                        .success(outputPath),
                        accountLease: accountLease,
                        completion: completion
                    )
                } catch {
                    self.finishSynthesis(operation)
                    DDLogError("[MemoirTTS] 写入文件失败: \(error.localizedDescription)")
                    if self.accountLeaseRuntime.validate(accountLease, at: .ui).allowed {
                        completion(.failure(.synthesisFailed("文件写入失败")))
                    }
                }
            case .failure(let error):
                self.finishSynthesis(operation)
                DDLogError("[MemoirTTS] 后端合成请求失败: \(error.localizedDescription)")
                self.deliver(
                    .failure(.networkError(error.localizedDescription)),
                    accountLease: accountLease,
                    completion: completion
                )
            }
        }
    }

    private func beginSynthesis(accountLease: AccountLease) -> SynthesisOperation? {
        stateLock.lock()
        defer { stateLock.unlock() }
        if let activeSynthesisOperation,
           accountLeaseRuntime.validate(activeSynthesisOperation.accountLease, at: .runtime).allowed {
            return nil
        }
        let operation = SynthesisOperation(id: UUID(), accountLease: accountLease)
        activeSynthesisOperation = operation
        return operation
    }

    private func isCurrent(_ operation: SynthesisOperation) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return activeSynthesisOperation == operation
    }

    private func finishSynthesis(_ operation: SynthesisOperation) {
        stateLock.lock()
        if activeSynthesisOperation == operation {
            activeSynthesisOperation = nil
        }
        stateLock.unlock()
    }

    private func cancelSynthesisRuntime(for oldScope: MemoirTTSCacheScope) {
        stateLock.lock()
        if let activeSynthesisOperation,
           MemoirTTSCacheScope(accountLease: activeSynthesisOperation.accountLease) == oldScope {
            self.activeSynthesisOperation = nil
        }
        stateLock.unlock()
    }

    private func handleScopedCacheLifecycle(
        scope: MemoirTTSCacheScope,
        purge: Bool
    ) -> MemoirTTSCacheLifecycleDisposition {
        let scopedAudioDirectory = audioDirectory(for: scope)
        let scopedMetadataDirectory = cacheDirectory(for: scope)
        guard isExpectedLifecycleDirectory(
            scopedAudioDirectory,
            root: scopedAudioRootDirectory,
            scope: scope
        ), isExpectedLifecycleDirectory(
            scopedMetadataDirectory,
            root: scopedCacheRootDirectory,
            scope: scope
        ) else {
            return .failed
        }

        storageLock.lock()
        defer { storageLock.unlock() }
        let hasPayload = directoryHasPayload(scopedAudioDirectory)
            || directoryHasPayload(scopedMetadataDirectory)
        guard purge else {
            return hasPayload ? .retained : .absent
        }

        do {
            if FileManager.default.fileExists(atPath: scopedAudioDirectory.path) {
                try FileManager.default.removeItem(at: scopedAudioDirectory)
            }
            if FileManager.default.fileExists(atPath: scopedMetadataDirectory.path) {
                try FileManager.default.removeItem(at: scopedMetadataDirectory)
            }
        } catch {
            return .failed
        }
        guard !FileManager.default.fileExists(atPath: scopedAudioDirectory.path),
              !FileManager.default.fileExists(atPath: scopedMetadataDirectory.path) else {
            return .failed
        }
        return hasPayload ? .removed : .absent
    }

    private func isExpectedLifecycleDirectory(
        _ directory: URL,
        root: URL,
        scope: MemoirTTSCacheScope
    ) -> Bool {
        let expected = root.appendingPathComponent(scope.scopeDigest, isDirectory: true)
        return directory.standardizedFileURL == expected.standardizedFileURL
            && directory.deletingLastPathComponent().standardizedFileURL
                == root.standardizedFileURL
    }

    private func directoryHasPayload(_ directory: URL) -> Bool {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        ) else {
            return false
        }
        return !entries.isEmpty
    }

    private func memoirTTSLifecycleDetailCode(
        for outcome: AccountLifecycleModuleOutcome
    ) -> String {
        switch outcome {
        case .retainedLocked:
            return "memoirTTSLifecycleRetainedLocked"
        case .unmounted:
            return "memoirTTSLifecycleUnmounted"
        case .cancelled:
            return "memoirTTSLifecycleCancelled"
        case .cleared:
            return "memoirTTSLifecycleCleared"
        case .purged:
            return "memoirTTSLifecyclePurged"
        case .skipped:
            return "memoirTTSLifecycleSkipped"
        case .failed:
            return "memoirTTSLifecycleRequestedFailure"
        }
    }

    private func deliver<T>(
        _ result: Result<T, TTSError>,
        accountLease: AccountLease,
        completion: @escaping (Result<T, TTSError>) -> Void
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .ui).allowed else { return }
        completion(result)
    }

    private func stagingFileURL(
        for finalURL: URL,
        operation: SynthesisOperation
    ) -> URL {
        finalURL.deletingLastPathComponent().appendingPathComponent(
            ".\(finalURL.lastPathComponent).\(operation.id.uuidString).staging"
        )
    }

    private func commitSynthesisArtifacts(
        audioData: Data,
        cacheEntry: MemoirTTSCacheEntry,
        operation: SynthesisOperation
    ) throws {
        let accountLease = operation.accountLease
        guard isCurrent(operation),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
              let cacheScope = MemoirTTSCacheScope(accountLease: accountLease),
              cacheScope.matches(accountLease) else {
            throw TTSError.accountSessionChanged
        }

        retireLegacyGlobalCacheIfNeeded()
        ensureScopeDirectories(for: cacheScope)
        let audioURL = cacheEntry.audioFileURL
        guard isExpectedAudioURL(audioURL, for: cacheEntry, scope: cacheScope) else {
            throw TTSError.accountSessionChanged
        }
        let metadataURL = cacheFileURL(for: cacheEntry.cacheIdentity, scope: cacheScope)
        guard isExpectedMetadataURL(metadataURL, for: cacheEntry, scope: cacheScope) else {
            throw TTSError.accountSessionChanged
        }
        let stagedAudioURL = stagingFileURL(for: audioURL, operation: operation)
        let stagedMetadataURL = stagingFileURL(for: metadataURL, operation: operation)
        defer {
            try? FileManager.default.removeItem(at: stagedAudioURL)
            try? FileManager.default.removeItem(at: stagedMetadataURL)
        }

        try audioData.write(to: stagedAudioURL, options: .atomic)
        try saveCacheEnvelope(
            MemoirTTSCacheEnvelope(
                schemaVersion: MemoirTTSCacheStoragePolicy.schemaVersion,
                scope: cacheScope,
                entry: cacheEntry
            ),
            to: stagedMetadataURL
        )
        guard isCurrent(operation),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
              let stagedMetadata = try? Data(contentsOf: stagedMetadataURL) else {
            throw TTSError.accountSessionChanged
        }

        storageLock.lock()
        defer { storageLock.unlock() }
        guard isCurrent(operation),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            throw TTSError.accountSessionChanged
        }

        let previousAudio = try? Data(contentsOf: audioURL)
        let previousMetadata = try? Data(contentsOf: metadataURL)
        do {
            try audioData.write(to: audioURL, options: .atomic)
            try stagedMetadata.write(to: metadataURL, options: .atomic)
            guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                restore(previousAudio, at: audioURL)
                restore(previousMetadata, at: metadataURL)
                throw TTSError.accountSessionChanged
            }
        } catch {
            restore(previousAudio, at: audioURL)
            restore(previousMetadata, at: metadataURL)
            throw error
        }
    }

    private func restore(_ data: Data?, at url: URL) {
        if let data {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func captureScopedAccess(
        forSubjectId subjectId: String?,
        at checkpoint: AccountLeaseCheckpoint
    ) -> MemoirTTSScopedAccess? {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: subjectId),
              accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed,
              let scope = MemoirTTSCacheScope(accountLease: accountLease) else {
            return nil
        }
        return MemoirTTSScopedAccess(accountLease: accountLease, scope: scope)
    }

    private func getCachedSynthesis(
        matching lookup: MemoirTTSCacheLookup,
        access: MemoirTTSScopedAccess
    ) -> MemoirTTSCacheResult? {
        storageLock.lock()
        defer { storageLock.unlock() }
        retireLegacyGlobalCacheIfNeeded()
        ensureScopeDirectories(for: access.scope)
        guard let entry = cachedEntries(matching: lookup, scope: access.scope)
              .sorted(by: { $0.createdAt > $1.createdAt })
              .first,
              accountLeaseRuntime.validate(access.accountLease, at: .runtime).allowed else {
            return nil
        }
        return MemoirTTSCacheResult(audioFileURL: entry.audioFileURL, cacheEntry: entry)
    }

    private func audioDirectory(for scope: MemoirTTSCacheScope) -> URL {
        scopedAudioRootDirectory.appendingPathComponent(scope.scopeDigest, isDirectory: true)
    }

    private func cacheDirectory(for scope: MemoirTTSCacheScope) -> URL {
        scopedCacheRootDirectory.appendingPathComponent(scope.scopeDigest, isDirectory: true)
    }

    private func ensureScopeDirectories(for scope: MemoirTTSCacheScope) {
        try? FileManager.default.createDirectory(
            at: audioDirectory(for: scope),
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: cacheDirectory(for: scope),
            withIntermediateDirectories: true
        )
    }

    private func audioFileURL(
        for identity: MemoirTTSCacheIdentity,
        scope: MemoirTTSCacheScope
    ) -> URL {
        audioDirectory(for: scope).appendingPathComponent(
            "\(identity.cacheDigest).\(identity.audioFormat)"
        )
    }

    private func cacheFileURL(for identity: MemoirTTSCacheIdentity, scope: MemoirTTSCacheScope) -> URL {
        cacheDirectory(for: scope).appendingPathComponent(
            "\(identity.cacheDigest).json"
        )
    }

    private func saveCacheEnvelope(_ envelope: MemoirTTSCacheEnvelope, to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        try data.write(to: fileURL, options: .atomic)
    }

    private func cachedEntries(
        matching lookup: MemoirTTSCacheLookup,
        scope: MemoirTTSCacheScope,
        requiresAudioFile: Bool = true
    ) -> [MemoirTTSCacheEntry] {
        guard let cacheFiles = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory(for: scope),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return cacheFiles.compactMap { fileURL in
            guard let entry = loadCacheEntry(from: fileURL, scope: scope),
                  lookup.matches(entry.cacheIdentity),
                  !requiresAudioFile || FileManager.default.fileExists(atPath: entry.audioFileURL.path) else {
                return nil
            }
            return entry
        }
    }

    private func loadCacheEntry(
        from fileURL: URL,
        scope: MemoirTTSCacheScope
    ) -> MemoirTTSCacheEntry? {
        guard fileURL.pathExtension == "json",
              fileURL.deletingLastPathComponent().standardizedFileURL
                == cacheDirectory(for: scope).standardizedFileURL else {
            return nil
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let envelope = try? decoder.decode(MemoirTTSCacheEnvelope.self, from: data),
              envelope.schemaVersion == MemoirTTSCacheStoragePolicy.schemaVersion,
              envelope.scope == scope,
              isIdentityConsistent(envelope.entry),
              isExpectedMetadataURL(fileURL, for: envelope.entry, scope: scope),
              isExpectedAudioURL(envelope.entry.audioFileURL, for: envelope.entry, scope: scope) else {
            return nil
        }
        return envelope.entry
    }

    private func isExpectedAudioURL(
        _ audioURL: URL,
        for entry: MemoirTTSCacheEntry,
        scope: MemoirTTSCacheScope
    ) -> Bool {
        guard isIdentityConsistent(entry) else {
            return false
        }
        return audioURL.standardizedFileURL == audioFileURL(
            for: entry.cacheIdentity,
            scope: scope
        ).standardizedFileURL
    }

    private func isExpectedMetadataURL(
        _ metadataURL: URL,
        for entry: MemoirTTSCacheEntry,
        scope: MemoirTTSCacheScope
    ) -> Bool {
        guard isIdentityConsistent(entry) else {
            return false
        }
        return metadataURL.standardizedFileURL == cacheFileURL(
            for: entry.cacheIdentity,
            scope: scope
        ).standardizedFileURL
    }

    private func isIdentityConsistent(_ entry: MemoirTTSCacheEntry) -> Bool {
        entry.memoirId == entry.cacheIdentity.memoirId
            && entry.voiceProfileId == entry.cacheIdentity.voiceProfileId
            && entry.textHash == entry.cacheIdentity.textHash
            && Self.normalizedAudioFormat(entry.audioFormat) == entry.cacheIdentity.audioFormat
            && MemoirTTSCacheStoragePolicy.normalized(entry.providerMode).lowercased()
                == entry.cacheIdentity.providerMode
    }

    private func resolvedVoiceProfileId(for memoir: MemoirModel) -> String? {
        let candidate = memoir.speakerId ?? VoiceCloneService.shared.currentUsableSpeakerId
        let normalized = MemoirTTSCacheStoragePolicy.normalized(candidate ?? "")
        return normalized.isEmpty ? nil : normalized
    }

    private func retireLegacyGlobalCacheIfNeeded() {
        storageLock.lock()
        defer { storageLock.unlock() }
        guard !legacyRetirementAttempted else { return }
        let audioRetired = quarantineLegacyFiles(in: legacyAudioDirectory, surface: "audio")
        let metadataRetired = quarantineLegacyFiles(in: legacyCacheDirectory, surface: "metadata")
        legacyRetirementAttempted = audioRetired && metadataRetired
    }

    private func quarantineLegacyFiles(in sourceDirectory: URL, surface: String) -> Bool {
        guard let sourceFiles = try? FileManager.default.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else {
            return true
        }
        let surfaceDirectory = legacyQuarantineDirectory.appendingPathComponent(surface, isDirectory: true)
        try? FileManager.default.createDirectory(at: surfaceDirectory, withIntermediateDirectories: true)
        var allFilesRetired = true

        for sourceURL in sourceFiles {
            guard (try? sourceURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            let quarantineName = "\(UUID().uuidString.lowercased())-\(sourceURL.lastPathComponent)"
            let quarantineURL = surfaceDirectory.appendingPathComponent(quarantineName)
            do {
                try FileManager.default.moveItem(at: sourceURL, to: quarantineURL)
                let receipt = MemoirTTSLegacyQuarantineReceipt(
                    schemaVersion: MemoirTTSCacheStoragePolicy.schemaVersion,
                    sourcePath: sourceURL.path,
                    quarantinePath: quarantineURL.path,
                    reason: "legacyGlobalCacheHasNoAccountGenerationEvidence",
                    quarantinedAt: Date()
                )
                let receiptURL = surfaceDirectory.appendingPathComponent("\(quarantineName).receipt.json")
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                do {
                    try encoder.encode(receipt).write(to: receiptURL, options: .atomic)
                } catch {
                    DDLogWarn("[MemoirTTS] 旧全局缓存已隔离，但回执写入失败: \(quarantineURL.path)")
                }
            } catch {
                allFilesRetired = false
                DDLogWarn("[MemoirTTS] 旧全局缓存隔离失败，继续拒绝读取: \(sourceURL.path)")
            }
        }
        return allFilesRetired
    }

    private static func normalizedAudioFormat(_ value: String) -> String {
        let format = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch format {
        case "m4a", "aac", "wav":
            return format
        default:
            return "mp3"
        }
    }

    private static func textHash(for text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    // MARK: - 降级方案：系统 TTS

    /// 当声音复刻不可用时，使用系统 TTS 作为降级
    /// iOS 原生 AVSpeechSynthesizer，不需要网络，但音色不是老人的
    func synthesizeWithSystemTTS(memoir: MemoirModel,
                                  completion: @escaping (Result<URL, TTSError>) -> Void) {
        guard !memoir.prose.isEmpty else {
            completion(.failure(.emptyText))
            return
        }

        let utterance = AVSpeechUtterance(string: memoir.prose)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceMinimumSpeechRate + 0.1  // 稍慢
        utterance.pitchMultiplier = 0.85  // 低沉一些，模拟老人声音
        utterance.volume = 1.0

        // 系统TTS无法直接导出文件，这里用占位逻辑
        // 实际使用时建议直接用 AVSpeechSynthesizer 播放，不保存文件
        DDLogInfo("[MemoirTTS] 使用系统TTS降级播放（无法导出文件）")
        completion(.failure(.systemTTSNoExport))
    }
}

// MARK: - 错误类型

enum TTSError: LocalizedError {
    case apiKeyMissing
    case accountSessionChanged
    case noSpeakerId
    case voiceNotReady         // 音色未训练完成
    case emptyText
    case alreadySynthesizing   // 正在合成中
    case networkError(String)
    case synthesisFailed(String)
    case systemTTSNoExport     // 系统 TTS 不支持导出

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "声音复刻合成后端未配置"
        case .accountSessionChanged:
            return "账号状态已变化，请重新进入后再合成"
        case .noSpeakerId:
            return "未找到声音复刻音色，请先完成声音复刻训练"
        case .voiceNotReady:
            return "声音复刻训练尚未完成，请稍后再试"
        case .emptyText:
            return "回忆录内容为空"
        case .alreadySynthesizing:
            return "正在合成中，请稍候"
        case .networkError(let msg):
            return "网络错误: \(msg)"
        case .synthesisFailed(let msg):
            return "语音合成失败: \(msg)"
        case .systemTTSNoExport:
            return "系统 TTS 仅支持在线播放"
        }
    }
}
