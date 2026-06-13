import Foundation

// MARK: - Digital Human Playback Evidence Store

/// Persists only structured playback lifecycle markers for roadshow evidence.
/// Do not write transcript text, API keys, voice ids, request headers, or raw service errors here.
final class DigitalHumanPlaybackEvidenceStore {
    static let shared = DigitalHumanPlaybackEvidenceStore()

    static let relativeLogPath = "diagnostics/digital_human_playback.log"

    private let queue = DispatchQueue(label: "com.dreamjourney.digital-human-playback-evidence")
    private let dateFormatter = ISO8601DateFormatter()
    private let fileManager: FileManager
    private let logURL: URL?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.logURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.relativeLogPath)
    }

    func appendEvent(_ event: String) {
        let sanitized = Self.sanitize(event)
        guard !sanitized.isEmpty, let logURL else { return }
        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp) [DigitalHumanSpeech] \(sanitized)\n"

        queue.async { [fileManager] in
            let directoryURL = logURL.deletingLastPathComponent()
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            guard let data = line.data(using: .utf8) else { return }
            if fileManager.fileExists(atPath: logURL.path),
               let handle = try? FileHandle(forWritingTo: logURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                _ = try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: logURL, options: .atomic)
            }
        }
    }

    static func sanitize(_ event: String) -> String {
        let forbiddenFragments = [
            "api_key",
            "apikey",
            "x-api-key",
            "token",
            "secret",
            "authorization",
            "voiceType=",
            "voice_type"
        ]
        let lowercased = event.lowercased()
        guard !forbiddenFragments.contains(where: { lowercased.contains($0.lowercased()) }) else {
            return "redacted_private_event"
        }

        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-=:. ,/()[]")
        return event
            .unicodeScalars
            .map { allowedCharacters.contains($0) ? Character($0) : " " }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
