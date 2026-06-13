import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

final class StubVoiceTrainer: MemoryArchiveVoiceTrainingClient {
    func trainVoice(
        audioURLs: [URL],
        speakerId: String,
        completion: @escaping (Result<String, MemoryArchiveVoiceProfileTrainingError>) -> Void
    ) {
        completion(.success("speaker_\(speakerId)"))
    }
}

private func makeVoiceSample(
    id: String,
    title: String,
    localPath: String,
    privacyMetadata: MemoryPrivacyMetadata
) -> MemoryArchiveItem {
    MemoryArchiveItem(
        id: id,
        kind: .voiceSample,
        title: title,
        note: "导入的长辈语音样本，用于后续声纹和语气参考。",
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

let defaults = UserDefaults(suiteName: "MemoryArchiveVoiceProfileSpeakerResolveVerify")!
defaults.removePersistentDomain(forName: "MemoryArchiveVoiceProfileSpeakerResolveVerify")
let store = MemoryArchiveVoiceProfileStore(
    defaults: defaults,
    storageKey: "voiceProfiles.speakerResolve.verify",
    requiredSampleCount: 3
)
store.reset()

let generationMetadata = MemoryPrivacyMetadata(scope: .generationAllowed)
let privateMetadata = MemoryPrivacyMetadata(scope: .localOnly)
let trainer = StubVoiceTrainer()

let linSamples = [
    makeVoiceSample(id: "lin-1", title: "林桂芳的第一段语音", localPath: "/tmp/lin-1.m4a", privacyMetadata: generationMetadata),
    makeVoiceSample(id: "lin-2", title: "林桂芳的第二段语音", localPath: "/tmp/lin-2.m4a", privacyMetadata: generationMetadata),
    makeVoiceSample(id: "lin-3", title: "林桂芳的第三段语音", localPath: "/tmp/lin-3.m4a", privacyMetadata: generationMetadata),
]
linSamples.forEach { _ = store.registerSample($0) }
guard let linProfile = store.profile(for: "林桂芳") else {
    fputs("FAIL: 林桂芳 voice profile should exist\n", stderr)
    exit(1)
}

let semaphore = DispatchSemaphore(value: 0)
var trainedSpeakerId: String?
store.startTraining(
    profileID: linProfile.id,
    sampleURLs: linSamples.map { URL(fileURLWithPath: $0.localPath ?? "") },
    trainer: trainer
) { result in
    if case .success(let profile) = result {
        trainedSpeakerId = profile.speakerId
    }
    semaphore.signal()
}
_ = semaphore.wait(timeout: .now() + 2)

assertCondition(trainedSpeakerId?.isEmpty == false, "trained profile should store a speaker id")
assertCondition(
    store.readySpeakerId(matching: "林桂芳年轻时在杭州西湖边开过照相馆。") == trainedSpeakerId,
    "digital-human TTS should resolve a ready person speaker id only when the reply names that person"
)
assertCondition(
    store.readySpeakerId(matching: "这段回忆和外婆有关，但没有明确姓名。") == nil,
    "generic kinship words should not select a concrete trained speaker"
)

let chenSamples = [
    makeVoiceSample(id: "chen-1", title: "陈建国的第一段语音", localPath: "/tmp/chen-1.m4a", privacyMetadata: privateMetadata),
    makeVoiceSample(id: "chen-2", title: "陈建国的第二段语音", localPath: "/tmp/chen-2.m4a", privacyMetadata: privateMetadata),
    makeVoiceSample(id: "chen-3", title: "陈建国的第三段语音", localPath: "/tmp/chen-3.m4a", privacyMetadata: privateMetadata),
]
chenSamples.forEach { _ = store.registerSample($0) }
assertCondition(
    store.readySpeakerId(matching: "陈建国的声音资料只在本机。") == nil,
    "local-only voice profiles should not be used for remote TTS speaker selection"
)

store.reset()
defaults.removePersistentDomain(forName: "MemoryArchiveVoiceProfileSpeakerResolveVerify")
print("MemoryArchiveVoiceProfileSpeakerResolve verification passed")
