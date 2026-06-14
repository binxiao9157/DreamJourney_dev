import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func temporaryURL(_ name: String) -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("dreamjourney_voice_validation_\(UUID().uuidString)_\(name)")
}

private func appendASCII(_ value: String, to data: inout Data) {
    data.append(value.data(using: .ascii)!)
}

private func appendUInt16LE(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
}

private func appendUInt32LE(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 24) & 0xff))
}

private func makeWAV(durationSeconds: Double, url: URL) throws {
    let sampleRate = 8_000
    let channels = 1
    let bitsPerSample = 16
    let bytesPerSample = bitsPerSample / 8
    let frameCount = max(1, Int(Double(sampleRate) * durationSeconds))
    let dataSize = frameCount * channels * bytesPerSample

    var data = Data()
    appendASCII("RIFF", to: &data)
    appendUInt32LE(UInt32(36 + dataSize), to: &data)
    appendASCII("WAVE", to: &data)
    appendASCII("fmt ", to: &data)
    appendUInt32LE(16, to: &data)
    appendUInt16LE(1, to: &data)
    appendUInt16LE(UInt16(channels), to: &data)
    appendUInt32LE(UInt32(sampleRate), to: &data)
    appendUInt32LE(UInt32(sampleRate * channels * bytesPerSample), to: &data)
    appendUInt16LE(UInt16(channels * bytesPerSample), to: &data)
    appendUInt16LE(UInt16(bitsPerSample), to: &data)
    appendASCII("data", to: &data)
    appendUInt32LE(UInt32(dataSize), to: &data)
    data.append(Data(repeating: 0, count: dataSize))
    try data.write(to: url)
}

let validator = MemoryArchiveVoiceSampleValidator(
    maxFileSizeBytes: 30_000,
    minimumDurationSeconds: 1.0
)

let emptyURL = temporaryURL("empty.m4a")
try Data().write(to: emptyURL)
do {
    _ = try validator.validate(url: emptyURL)
    assertCondition(false, "empty audio should be rejected")
} catch MemoryArchiveVoiceSampleValidationError.fileEmpty {
    assertCondition(true, "empty audio rejected")
}

let randomM4AURL = temporaryURL("random.m4a")
try Data([1, 2, 3, 4, 5]).write(to: randomM4AURL)
do {
    _ = try validator.validate(url: randomM4AURL)
    assertCondition(false, "random m4a without audio track should be rejected")
} catch MemoryArchiveVoiceSampleValidationError.noAudioTrack {
    assertCondition(true, "random m4a rejected")
}

let shortWAVURL = temporaryURL("short.wav")
try makeWAV(durationSeconds: 0.25, url: shortWAVURL)
do {
    _ = try validator.validate(url: shortWAVURL)
    assertCondition(false, "short audio should be rejected")
} catch MemoryArchiveVoiceSampleValidationError.audioTooShort {
    assertCondition(true, "short audio rejected")
}

let validWAVURL = temporaryURL("valid.wav")
try makeWAV(durationSeconds: 1.2, url: validWAVURL)
let validAudio = try validator.validate(url: validWAVURL)
assertCondition(validAudio.fileSizeBytes > 0, "valid audio should report file size")
assertCondition(validAudio.durationSeconds >= 1.0, "valid audio should report duration")
assertCondition(validAudio.format == "wav", "valid audio should preserve format")

let oversizedURL = temporaryURL("oversized.wav")
try makeWAV(durationSeconds: 1.2, url: oversizedURL)
let oversizedHandle = try FileHandle(forWritingTo: oversizedURL)
try oversizedHandle.truncate(atOffset: 30_001)
try oversizedHandle.close()
do {
    _ = try validator.validate(url: oversizedURL)
    assertCondition(false, "oversized audio should be rejected before archive import")
} catch MemoryArchiveVoiceSampleValidationError.fileTooLarge {
    assertCondition(true, "oversized audio rejected")
}

let viewSource = try String(
    contentsOfFile: "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift",
    encoding: .utf8
)
let voiceProfileSource = try String(
    contentsOfFile: "DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveVoiceProfileStore.swift",
    encoding: .utf8
)
let metadataLoaderSource = voiceProfileSource
    .components(separatedBy: "private enum MemoryArchiveVoiceSampleMetadataLoader")
    .dropFirst()
    .first?
    .components(separatedBy: "enum MemoryArchiveVoiceProfileStatus")
    .first ?? ""
assertCondition(
    viewSource.contains("MemoryArchiveVoiceSampleValidator().validate(url: fileURL)"),
    "voice import should validate the copied archive file before presenting privacy choices"
)
assertCondition(
    metadataLoaderSource.contains("AVAudioFile(forReading: url)") &&
        !metadataLoaderSource.contains("tracks(withMediaType: .audio)") &&
        !metadataLoaderSource.contains("loadValuesAsynchronously"),
    "voice import validation should use non-deprecated local audio metadata loading"
)
assertCondition(
    viewSource.contains("FileManager.default.removeItem(at: fileURL)"),
    "invalid copied voice files should be removed instead of left in archive storage"
)
assertCondition(
    viewSource.contains("语音素材不符合要求"),
    "voice import validation failure should be user-facing"
)

print("MemoryArchiveVoiceImportAudioValidation verification passed")
