import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let service = read("DreamJourney/Sources/Memoir/MemoirTTSService.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let packageCheck = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

assertContains(service, "struct MemoirTTSCacheEntry: Codable", "Memoir TTS cache should define a Codable metadata entry")
for requiredField in [
    "audioFileURL",
    "voiceProfileId",
    "textHash",
    "audioFormat",
    "visemeTimeline",
    "createdAt",
    "providerMode",
] {
    assertContains(service, requiredField, "Memoir TTS cache entry should include \(requiredField)")
}

assertContains(service, "struct MemoirTTSCacheResult", "Memoir TTS cache should expose an audio + metadata read result")
assertContains(service, "memoir_tts_cache", "Memoir TTS metadata should use an explicit cache directory")
assertContains(service, "commitSynthesisArtifacts", "Memoir TTS should atomically commit audio and metadata after synthesis")
assertContains(service, "saveCacheEnvelope", "Memoir TTS should persist scoped cache metadata")
assertContains(service, "cachedEntries", "Memoir TTS should load scoped cache metadata")
assertContains(service, "getCachedSynthesis", "Memoir TTS should expose cache reads with audio and timeline metadata")
assertContains(service, "synthesis.visemeTimeline", "Memoir TTS should persist provider viseme timelines")
assertContains(service, "synthesis.providerMode", "Memoir TTS should persist provider mode")
assertContains(service, "synthesis.audioFormat", "Memoir TTS should persist audio format")

assertContains(releaseRegression, "memoir-tts-cache-contract-check.swift", "release regression should run Memoir TTS cache guard")
assertContains(packageCheck, "memoir-tts-cache-contract-check.swift", "release QA package should require Memoir TTS cache guard")

let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("dreamjourney-memoir-tts-cache-contract-\(UUID().uuidString)", isDirectory: true)
let audioFileURL = tempRoot.appendingPathComponent("memoir-audio.mp3")
let metadataFileURL = tempRoot.appendingPathComponent("memoir-cache.json")
try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
try Data([0x49, 0x44, 0x33, 0x04]).write(to: audioFileURL)

let fixture: [String: Any] = [
    "memoirId": "memoir-cache-uiqa",
    "audioFileURL": audioFileURL.absoluteString,
    "voiceProfileId": "voice-profile-uiqa",
    "textHash": "mock-text-hash",
    "audioFormat": "mp3",
    "createdAt": "2026-06-20T00:00:00Z",
    "providerMode": "mockProvider",
    "visemeTimeline": [
        "source": "providerVisemeTimeline",
        "duration": 0.48,
        "frames": [
            ["timeOffset": 0.00, "mouthShape": "neutral", "intensity": 0.1],
            ["timeOffset": 0.12, "mouthShape": "aa", "intensity": 0.82],
            ["timeOffset": 0.32, "mouthShape": "oh", "intensity": 0.66],
        ],
    ],
]

let fixtureData = try JSONSerialization.data(withJSONObject: fixture, options: [.prettyPrinted, .sortedKeys])
try fixtureData.write(to: metadataFileURL, options: .atomic)

guard let reloadedData = try? Data(contentsOf: metadataFileURL),
      let reloaded = try? JSONSerialization.jsonObject(with: reloadedData) as? [String: Any],
      let reloadedAudioURLString = reloaded["audioFileURL"] as? String,
      let reloadedAudioURL = URL(string: reloadedAudioURLString),
      FileManager.default.fileExists(atPath: reloadedAudioURL.path),
      let timeline = reloaded["visemeTimeline"] as? [String: Any],
      let frames = timeline["frames"] as? [[String: Any]],
      frames.count == 3 else {
    fatalError("Memoir TTS cache fixture should roundtrip audioFileURL and visemeTimeline.frames")
}

print("Memoir TTS cache contract verified.")
