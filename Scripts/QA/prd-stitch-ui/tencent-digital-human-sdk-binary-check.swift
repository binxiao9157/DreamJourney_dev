import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

func exists(_ relativePath: String) -> Bool {
    FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(relativePath).path)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("tencent-digital-human-sdk-binary-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let project = try read("DreamJourney.xcodeproj/project.pbxproj")
let podfile = try read("Podfile")
let podfileLock = try read("Podfile.lock")

require(exists("Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework"), "SDK xcframework must exist in the ignored local vendor path")
require(podfile.contains("TXLiteAVSDK_TRTC_shuziren_13.0.20262.podspec"), "Podfile must use Tencent digital-human TRTC podspec")
require(podfileLock.contains("TXLiteAVSDK_TRTC (13.0.20262)"), "Podfile.lock must pin Tencent digital-human TRTC pod")
require(project.contains("VirtualmanStreamSDK.xcframework"), "Xcode project must reference VirtualmanStreamSDK.xcframework")
require(project.contains("VirtualmanStreamSDK.xcframework in Frameworks"), "SDK xcframework must be linked in Frameworks")
require(project.contains("VirtualmanStreamSDK.xcframework in Embed Frameworks"), "SDK xcframework must be embedded for runtime loading")
require(project.contains("CodeSignOnCopy"), "Embedded SDK xcframework must be configured for CodeSignOnCopy")
require(project.contains("Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework"), "Project reference must point at the ignored local vendor path")

print("tencent-digital-human-sdk-binary-check passed")
