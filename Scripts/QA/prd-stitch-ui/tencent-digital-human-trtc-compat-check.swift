import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("tencent-digital-human-trtc-compat-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let podfile = try read("Podfile")
let podfileLock = try read("Podfile.lock")

let tencentTRTCPodspec = "TXLiteAVSDK_TRTC_shuziren_13.0.20262.podspec"
require(podfile.contains(tencentTRTCPodspec), "Podfile must use Tencent digital-human dedicated TRTC podspec")
require(podfileLock.contains("TXLiteAVSDK_TRTC (13.0.20262)"), "Podfile.lock must pin TXLiteAVSDK_TRTC 13.0.20262")
require(podfileLock.contains(tencentTRTCPodspec), "Podfile.lock must record Tencent dedicated TRTC podspec source")
require(podfile.contains("SpeechEngineToB"), "Volcengine SpeechEngineToB dependency must remain configured")
require(podfileLock.contains("SpeechEngineToB (0.0.14.6.1-bugfix)"), "SpeechEngineToB lock entry must remain unchanged")
require(!podfile.contains("pod 'TXLiteAVSDK_TRTC'") || podfile.contains("customer/TXLiteAVSDK_TRTC_shuziren_13.0.20262.podspec"), "Tencent TRTC dependency must not use the generic pod")

print("tencent-digital-human-trtc-compat-check passed")
