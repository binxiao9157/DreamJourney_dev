import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

final class StubVoiceTrainer: MemoryArchiveVoiceTrainingClient {
    private(set) var requestedSpeakerIds: [String] = []
    private(set) var requestedAudioURLBatches: [[URL]] = []

    func trainVoice(
        audioURLs: [URL],
        speakerId: String,
        completion: @escaping (Result<String, MemoryArchiveVoiceProfileTrainingError>) -> Void
    ) {
        requestedAudioURLBatches.append(audioURLs)
        requestedSpeakerIds.append(speakerId)
        completion(.success("\(speakerId)_ready"))
    }
}

final class FailingVoiceTrainer: MemoryArchiveVoiceTrainingClient {
    func trainVoice(
        audioURLs: [URL],
        speakerId: String,
        completion: @escaping (Result<String, MemoryArchiveVoiceProfileTrainingError>) -> Void
    ) {
        completion(.failure(.service("invalid X-Api-App-Key: should_not_surface")))
    }
}

private func makeVoiceSample(
    id: String,
    title: String,
    note: String = "导入的长辈语音样本，用于后续声纹和语气参考。",
    localPath: String,
    privacyMetadata: MemoryPrivacyMetadata
) -> MemoryArchiveItem {
    MemoryArchiveItem(
        id: id,
        kind: .voiceSample,
        title: title,
        note: note,
        localPath: localPath,
        createdAt: Date(timeIntervalSince1970: 1_781_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_781_000_000),
        analysisStatus: .manual,
        analysisSummary: nil,
        detectedPeople: [],
        scene: nil,
        occasion: nil,
        mood: nil,
        estimatedDecade: nil,
        tags: ["语音样本"],
        isPrivate: false,
        privacyMetadata: privacyMetadata.appendingSourceRef(
            MemorySourceRef(kind: .memoryArchiveItem, id: id, title: title, capturedAt: nil)
        )
    )
}

let defaults = UserDefaults(suiteName: "MemoryArchiveVoiceProfileVerify")!
defaults.removePersistentDomain(forName: "MemoryArchiveVoiceProfileVerify")
let store = MemoryArchiveVoiceProfileStore(
    defaults: defaults,
    storageKey: "voiceProfiles.verify",
    requiredSampleCount: 3
)
store.reset()

let metadata = MemoryPrivacyMetadata(scope: .generationAllowed)
let sample1 = makeVoiceSample(
    id: "voice-1",
    title: "林桂芳的第一段语音",
    localPath: "/tmp/voice-1.m4a",
    privacyMetadata: metadata
)
let sample2 = makeVoiceSample(
    id: "voice-2",
    title: "林桂芳的第二段语音",
    localPath: "/tmp/voice-2.m4a",
    privacyMetadata: metadata
)
let sample3 = makeVoiceSample(
    id: "voice-3",
    title: "林桂芳的第三段语音",
    localPath: "/tmp/voice-3.m4a",
    privacyMetadata: metadata
)

guard let firstProfile = store.registerSample(sample1) else {
    fputs("FAIL: concrete person voice sample should create a voice profile\n", stderr)
    exit(1)
}
assertCondition(firstProfile.personName == "林桂芳", "voice profile should bind to concrete person name")
assertCondition(firstProfile.status == .collecting, "one sample should keep profile in collecting status")
assertCondition(firstProfile.sampleArchiveItemIds == ["voice-1"], "profile should keep first archive sample id")

_ = store.registerSample(sample2)
guard let readyProfile = store.registerSample(sample3) else {
    fputs("FAIL: third sample should update the same voice profile\n", stderr)
    exit(1)
}
assertCondition(readyProfile.id == firstProfile.id, "samples for same person should reuse one profile")
assertCondition(readyProfile.sampleArchiveItemIds == ["voice-1", "voice-2", "voice-3"], "profile should keep all sample ids in order")
assertCondition(readyProfile.remoteTrainingSampleArchiveItemIds == ["voice-1", "voice-2", "voice-3"], "profile should track remote-authorized training sample ids")
assertCondition(readyProfile.status == .readyForTraining, "third generation-allowed sample should make profile ready for training")
assertCondition(readyProfile.speakerId == nil, "profile should not invent speaker id before training")

let genericSample = makeVoiceSample(
    id: "voice-generic",
    title: "妈妈的语音样本",
    localPath: "/tmp/voice-generic.m4a",
    privacyMetadata: metadata
)
assertCondition(store.registerSample(genericSample) == nil, "generic kinship voice sample should not create a person profile")

let trainer = StubVoiceTrainer()
let semaphore = DispatchSemaphore(value: 0)
var trainedProfile: MemoryArchiveVoiceProfile?
var trainingError: MemoryArchiveVoiceProfileError?
store.startTraining(
    profileID: readyProfile.id,
    sampleURLs: [
        URL(fileURLWithPath: "/tmp/voice-1.m4a"),
        URL(fileURLWithPath: "/tmp/voice-2.m4a"),
        URL(fileURLWithPath: "/tmp/voice-3.m4a"),
    ],
    trainer: trainer
) { result in
    switch result {
    case .success(let profile):
        trainedProfile = profile
    case .failure(let error):
        trainingError = error
    }
    semaphore.signal()
}
_ = semaphore.wait(timeout: .now() + 2)

assertCondition(trainingError == nil, "voice profile training should succeed with stub trainer")
assertCondition(trainer.requestedSpeakerIds.count == 1, "training should request exactly one per-person speaker id")
assertCondition(trainer.requestedAudioURLBatches.count == 1, "training should pass one ordered batch of collected voice samples")
assertCondition(
    trainer.requestedAudioURLBatches.first?.map(\.path) == [
        "/tmp/voice-1.m4a",
        "/tmp/voice-2.m4a",
        "/tmp/voice-3.m4a",
    ],
    "voice profile training should use all collected sample URLs in archive order"
)
assertCondition(trainer.requestedSpeakerIds.first?.hasPrefix("DJ_") == true, "speaker id should be generated for the voice profile")
assertCondition(trainedProfile?.personName == "林桂芳", "trained profile should still bind to the same person")
assertCondition(trainedProfile?.status == .ready, "trained profile should be ready")
assertCondition(trainedProfile?.speakerId == "\(trainer.requestedSpeakerIds[0])_ready", "trained speaker id should be stored on the profile")
assertCondition(defaults.string(forKey: "dj.voiceclone.speakerId") == nil, "profile training must not write the legacy global speaker id")

let mixedPrivateSample = makeVoiceSample(
    id: "mixed-local-1",
    title: "吴梅芳的第一段语音",
    localPath: "/tmp/mixed-local-1.m4a",
    privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
)
let mixedGenerationSamples = [
    makeVoiceSample(id: "mixed-gen-1", title: "吴梅芳的第二段语音", localPath: "/tmp/mixed-gen-1.m4a", privacyMetadata: metadata),
    makeVoiceSample(id: "mixed-gen-2", title: "吴梅芳的第三段语音", localPath: "/tmp/mixed-gen-2.m4a", privacyMetadata: metadata),
    makeVoiceSample(id: "mixed-gen-3", title: "吴梅芳的第四段语音", localPath: "/tmp/mixed-gen-3.m4a", privacyMetadata: metadata),
]
_ = store.registerSample(mixedPrivateSample)
mixedGenerationSamples.dropLast().forEach { _ = store.registerSample($0) }
guard let mixedReadyProfile = store.registerSample(mixedGenerationSamples.last!) else {
    fputs("FAIL: mixed privacy concrete person should keep a voice profile\n", stderr)
    exit(1)
}
assertCondition(
    mixedReadyProfile.sampleArchiveItemIds == ["mixed-local-1", "mixed-gen-1", "mixed-gen-2", "mixed-gen-3"],
    "mixed privacy profile should keep every archive sample id for provenance"
)
assertCondition(
    mixedReadyProfile.remoteTrainingSampleArchiveItemIds == ["mixed-gen-1", "mixed-gen-2", "mixed-gen-3"],
    "mixed privacy profile should train only generation-allowed sample ids"
)
assertCondition(
    mixedReadyProfile.status == .readyForTraining,
    "three generation-allowed samples should make a mixed privacy profile trainable"
)

let failingTrainer = FailingVoiceTrainer()
let failingSemaphore = DispatchSemaphore(value: 0)
var failedTrainingProfile: MemoryArchiveVoiceProfile?
var failedTrainingError: MemoryArchiveVoiceProfileError?
store.startTraining(
    profileID: mixedReadyProfile.id,
    sampleURLs: [
        URL(fileURLWithPath: "/tmp/mixed-gen-1.m4a"),
        URL(fileURLWithPath: "/tmp/mixed-gen-2.m4a"),
        URL(fileURLWithPath: "/tmp/mixed-gen-3.m4a"),
    ],
    trainer: failingTrainer
) { result in
    switch result {
    case .success(let profile):
        failedTrainingProfile = profile
    case .failure(let error):
        failedTrainingError = error
    }
    failingSemaphore.signal()
}
_ = failingSemaphore.wait(timeout: .now() + 2)

let failedProfile = store.profiles().first(where: { $0.id == mixedReadyProfile.id })
assertCondition(failedTrainingProfile == nil, "failing trainer should not return a trained profile")
assertCondition(failedTrainingError != nil, "failing trainer should surface a retryable training error to the caller")
assertCondition(failedProfile?.status == .failed, "failed training should mark the profile failed")
assertCondition(
    failedProfile?.statusMessage == "吴梅芳声纹训练失败，可稍后重试",
    "failed voice profile should store friendly retry copy instead of raw service errors"
)
assertCondition(
    failedProfile?.statusMessage?.contains("should_not_surface") == false,
    "failed voice profile status must not persist raw service error details"
)

let secondPerson = makeVoiceSample(
    id: "voice-chen-1",
    title: "陈建国的语音",
    localPath: "/tmp/voice-chen-1.m4a",
    privacyMetadata: metadata
)
guard let chenProfile = store.registerSample(secondPerson) else {
    fputs("FAIL: second concrete person should create a separate voice profile\n", stderr)
    exit(1)
}
assertCondition(chenProfile.id != firstProfile.id, "different people should not share voice profiles")
assertCondition(store.profiles().count == 3, "store should contain three concrete person profiles")

store.reset()
defaults.removePersistentDomain(forName: "MemoryArchiveVoiceProfileVerify")
print("MemoryArchiveVoiceProfile verification passed")
