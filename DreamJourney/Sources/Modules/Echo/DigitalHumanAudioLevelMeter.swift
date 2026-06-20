import AVFoundation
import Foundation

enum DigitalHumanAudioLevelSource: String {
    case idle
    case avAudioPlayerMetering
    case sdkTTSPlaybackFallback
    case providerVisemeTimeline
    case unavailable
}

final class DigitalHumanAudioLevelMeter: NSObject {
    private weak var panelView: DigitalHumanLivePanelView?
    private var timer: Timer?
    private var player: AVAudioPlayer?
    private var ownsPlayer = false
    private var fallbackPhase: Double = 0
    private var playbackFinished: (() -> Void)?

    private(set) var latestSource: DigitalHumanAudioLevelSource = .idle
    private(set) var latestLevel: Double = 0
    private(set) var meteringSampleCount = 0

    init(panelView: DigitalHumanLivePanelView?) {
        self.panelView = panelView
        super.init()
    }

    deinit {
        stop()
    }

    func updatePanelView(_ panelView: DigitalHumanLivePanelView?) {
        self.panelView = panelView
    }

    func startMetering(
        player: AVAudioPlayer,
        ownsPlayer: Bool = false,
        onFinished: (() -> Void)? = nil
    ) {
        stop(resetLevel: false)
        self.player = player
        self.ownsPlayer = ownsPlayer
        playbackFinished = onFinished
        latestSource = .avAudioPlayerMetering
        latestLevel = 0
        meteringSampleCount = 0

        player.delegate = self
        player.isMeteringEnabled = true
        player.prepareToPlay()
        if !player.isPlaying {
            player.play()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.samplePlayerLevel()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func startUIQAMeteredPlayback() throws {
        let url = try Self.makeUIQAMeteringProbeAudioURL()
        let player = try AVAudioPlayer(contentsOf: url)
        startMetering(player: player, ownsPlayer: true)
    }

    func startSDKTTSPlaybackFallback() {
        stop(resetLevel: false)
        latestSource = .sdkTTSPlaybackFallback
        latestLevel = 0
        meteringSampleCount = 0
        fallbackPhase = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.fallbackPhase += 0.42
            let wave = (sin(self.fallbackPhase) + 1) / 2
            self.apply(level: 0.12 + wave * 0.38, source: .sdkTTSPlaybackFallback)
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop(resetLevel: Bool = true) {
        timer?.invalidate()
        timer = nil
        if ownsPlayer {
            player?.stop()
        }
        player?.delegate = nil
        player = nil
        ownsPlayer = false
        playbackFinished = nil
        fallbackPhase = 0
        if resetLevel {
            apply(level: 0, source: .idle)
        }
    }

    static func makeUIQAMeteringProbeAudioURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("digital-human-metering-probe.caf")
        try? FileManager.default.removeItem(at: url)

        let sampleRate = 44_100.0
        let duration = 1.8
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else {
            throw NSError(domain: "DigitalHumanAudioLevelMeter", code: 1)
        }

        buffer.frameLength = frameCount
        let toneFrequency = 220.0
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let carrier = sin(2 * .pi * toneFrequency * time)
            let envelope = 0.24 + 0.66 * ((sin(2 * .pi * 2.4 * time) + 1) / 2)
            channel[frame] = Float(carrier * envelope * 0.72)
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    private func samplePlayerLevel() {
        guard let player else {
            stop()
            return
        }
        guard player.isPlaying else {
            samplePlayerLevelOnce(player)
            let callback = playbackFinished
            stop()
            callback?()
            return
        }
        samplePlayerLevelOnce(player)
    }

    private func samplePlayerLevelOnce(_ player: AVAudioPlayer) {
        player.updateMeters()
        let channelCount = max(1, player.numberOfChannels)
        var total: Double = 0
        for channel in 0..<channelCount {
            total += Double(player.averagePower(forChannel: channel))
        }
        let averagePower = total / Double(channelCount)
        let clampedPower = max(-60, min(0, averagePower))
        let normalized = pow(10, clampedPower / 20)
        let shaped = min(1, max(0, normalized * 1.35))
        apply(level: shaped, source: .avAudioPlayerMetering)
    }

    private func apply(level: Double, source: DigitalHumanAudioLevelSource) {
        latestLevel = max(0, min(1, level))
        latestSource = source
        if source == .avAudioPlayerMetering {
            meteringSampleCount += 1
        }
        panelView?.setAudioLevel(latestLevel, source: source)
    }
}

extension DigitalHumanAudioLevelMeter: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        samplePlayerLevelOnce(player)
        let callback = playbackFinished
        stop()
        callback?()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        latestSource = .unavailable
        stop()
    }
}
