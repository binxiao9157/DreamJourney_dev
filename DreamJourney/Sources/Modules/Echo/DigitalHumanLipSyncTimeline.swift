import Foundation

enum DigitalHumanPlaybackSource: String, Codable {
    case avAudioPlayerMetering
    case sdkTTSPlaybackFallback
    case providerVisemeTimeline
}

struct DigitalHumanLipSyncFrame: Codable {
    let timeOffset: TimeInterval
    let mouthShape: String
    let intensity: Double

    init(timeOffset: TimeInterval, mouthShape: String, intensity: Double) {
        self.timeOffset = max(0, timeOffset)
        let trimmedShape = mouthShape.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mouthShape = trimmedShape.isEmpty ? "neutral" : trimmedShape
        self.intensity = max(0, min(1, intensity))
    }
}

struct DigitalHumanLipSyncTimeline: Codable {
    let source: DigitalHumanPlaybackSource
    let duration: TimeInterval
    let frames: [DigitalHumanLipSyncFrame]

    init(
        source: DigitalHumanPlaybackSource = .providerVisemeTimeline,
        duration: TimeInterval,
        frames: [DigitalHumanLipSyncFrame]
    ) {
        let sortedFrames = frames.sorted { $0.timeOffset < $1.timeOffset }
        self.source = source
        self.frames = sortedFrames
        let lastFrameTime = sortedFrames.last?.timeOffset ?? 0
        self.duration = max(duration, lastFrameTime + 0.12)
    }

    func javaScriptLiteral() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "DigitalHumanLipSyncTimeline", code: 1)
        }
        return json
    }

    static func makeUIQAMockProviderTimeline() -> DigitalHumanLipSyncTimeline {
        DigitalHumanLipSyncTimeline(
            source: .providerVisemeTimeline,
            duration: 2.4,
            frames: [
                DigitalHumanLipSyncFrame(timeOffset: 0.00, mouthShape: "neutral", intensity: 0.12),
                DigitalHumanLipSyncFrame(timeOffset: 0.12, mouthShape: "aa", intensity: 0.84),
                DigitalHumanLipSyncFrame(timeOffset: 0.32, mouthShape: "oh", intensity: 0.72),
                DigitalHumanLipSyncFrame(timeOffset: 0.52, mouthShape: "ee", intensity: 0.58),
                DigitalHumanLipSyncFrame(timeOffset: 0.76, mouthShape: "aa", intensity: 0.88),
                DigitalHumanLipSyncFrame(timeOffset: 1.04, mouthShape: "oh", intensity: 0.68),
                DigitalHumanLipSyncFrame(timeOffset: 1.32, mouthShape: "ee", intensity: 0.62),
                DigitalHumanLipSyncFrame(timeOffset: 1.62, mouthShape: "aa", intensity: 0.9),
                DigitalHumanLipSyncFrame(timeOffset: 1.92, mouthShape: "neutral", intensity: 0.18)
            ]
        )
    }
}

enum DigitalHumanPlaybackEvent {
    case audioLevel(level: Double, source: DigitalHumanPlaybackSource)
    case visemeTimeline(DigitalHumanLipSyncTimeline)
    case stopped
    case failed(reason: String)
}
