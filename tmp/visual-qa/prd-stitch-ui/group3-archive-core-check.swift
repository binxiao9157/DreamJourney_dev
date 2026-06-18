import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let path = "\(root)/\(relativePath)"
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("Unable to read \(path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

func assertOrder(_ haystack: String, _ first: String, _ second: String, _ message: String) {
    guard let firstRange = haystack.range(of: first),
          let secondRange = haystack.range(of: second),
          firstRange.lowerBound < secondRange.lowerBound else {
        fatalError("\(message): expected \(first) before \(second)")
    }
}

let options = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let readiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let factory = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let textEntry = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift")
let photoEntry = read("DreamJourney/Sources/Modules/Archive/MemoryArchivePhotoEntryViewController.swift")
let audioEntry = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let infoPlist = read("DreamJourney/Resources/Info.plist")

assertContains(options, "var options: [MemoryArchiveCreationOption] = [\n            .text,\n            .photo,\n        ]", "archive creation should default to text/photo only")
assertContains(options, "if isAudioUploadEnabled {\n            options.append(.audio)\n        }", "audio branch should require an explicit option flag")
assertContains(options, "if isTimeLettersEnabled {\n            options.append(.timeLetter)\n        }", "time-letter branch should require an explicit option flag")

assertContains(readiness, "DJEnableArchiveHiddenBranches", "archive hidden branches need explicit UIQA launch argument")
assertContains(archive, "MemoryArchiveMediaReleaseReadiness.hiddenBranchesLaunchArgument", "archive screen must use shared hidden branch launch argument")
assertContains(archive, "MemoryArchiveMediaReleaseReadiness.isCreationVisible", "archive screen must use media release readiness contract")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.archiveAudioUpload)", "audio creation must be release gated")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.archiveRemoteFetch)", "remote archive fetch must be release gated")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.timeLetters)", "time-letter creation must be release gated")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.personaSettings)", "persona settings must be release gated")
assertNotContains(archive, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)\n        return true", "UIQA simulator must not expose hidden archive branches by default")
assertContains(archive, "var inputs = [\"文字\", \"图片\"]", "archive CTA subtitle should start from public text/photo inputs")
assertContains(archive, "let secondaryTiles = makeSecondaryFeatureTiles()", "secondary archive tiles should be release-filtered")
assertContains(archive, "guard !secondaryTiles.isEmpty else", "public archive grid should work without hidden secondary tiles")
assertContains(archive, "case .audio:\n            guard isArchiveAudioCreationEnabled", "audio sheet route should be guarded")
assertContains(archive, "case .timeLetter:\n            guard isTimeLetterCreationEnabled", "time-letter sheet route should be guarded")
assertContains(archive, "case .video:\n            showToast(MemoryArchiveMediaReleaseReadiness.unavailableCopy(for: .video)", "video route should stay unavailable")

assertContains(factory, "static func makeTextItem(note: String)", "text item factory")
assertContains(factory, "static func makeTimeLetter(note: String)", "time-letter item factory")
assertContains(factory, "static func makePhotoItem(localPath: String, source: PhotoSource = .photoLibrary)", "photo item factory")
assertContains(factory, "static func makeAudioItem(localPath: String, duration: TimeInterval, note: String)", "audio item factory")
assertContains(factory, "analysisStatus: .manual", "manual entries should be immediately available for context")
assertContains(factory, "analysisStatus: .pending", "photo entries should wait for analysis before prompt context")
assertContains(factory, "textMetadata(contentKind: \"time_letter\", note: note)", "time-letter metadata should identify hidden branch content")

assertContains(item, "mutating func applyLocalAnalysisResult", "archive items should support local analysis")
assertContains(item, "init?(remoteJSON object: [String: Any])", "archive items should parse backend JSON")
assertContains(item, "metadata[\"analysisSource\"] = \"local_rule\"", "local analysis should be identifiable")
assertContains(item, "metadata[\"analysisUpdatedAt\"]", "local analysis should carry update timestamp")

assertContains(repository, "case .analyzed, .manual:\n            return true", "archive context should include analyzed/manual items")
assertContains(repository, "case .pending, .failed:\n            return false", "archive context should exclude pending/failed items")
assertContains(repository, "MemoryArchiveContextSnapshot", "archive context snapshot type")
assertContains(repository, "promptSection", "archive context should expose prompt section")
assertContains(repository, "【记忆档案馆素材线索】", "archive prompt marker")
assertContains(repository, "func add(_ item: MemoryArchiveItem, syncToBackend shouldSyncToBackend: Bool = true)", "archive add should keep backend sync default")
assertContains(repository, "func update(_ item: MemoryArchiveItem, syncToBackend shouldSyncToBackend: Bool = true) -> Bool", "archive update should keep backend sync default")
assertContains(repository, "func refreshFromBackend(", "archive repository should expose gated backend fetch")
assertContains(repository, "mergeRemoteItems(remoteItems)", "archive repository should merge remote backend items")
assertOrder(repository, "save(items)", "if shouldSyncToBackend {", "archive should persist locally before optional backend sync")

assertContains(detail, "hidesBottomBarWhenPushed = true", "archive detail should hide floating tabbar")
assertContains(detail, "shouldShowLocalAnalysisAction", "detail should gate local analysis entry")
assertContains(detail, "FeatureFlagService.shared.isEnabled(.archiveLocalAnalysis)", "release local analysis should be feature gated")
assertContains(detail, "item.applyLocalAnalysisResult()", "detail analysis should update archive item")
assertContains(detail, "repository.update(item, syncToBackend: shouldSyncArchiveUpdateToBackend)", "detail analysis should respect backend sync policy")

assertContains(textEntry, "final class MemoryArchiveTextEntryViewController", "text/time-letter entry sheet")
assertContains(textEntry, "kind == .timeLetter", "text sheet should support hidden time-letter mode")
assertContains(textEntry, "saveButton.isEnabled = hasText", "text save should require content")

assertContains(photoEntry, "final class MemoryArchivePhotoEntryViewController", "photo entry sheet")
assertContains(photoEntry, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)", "sample photo should stay UIQA-only")
assertContains(photoEntry, "从相册选择", "photo sheet should expose public picker action")
assertContains(archive, "UIImagePickerController.isSourceTypeAvailable(.photoLibrary)", "photo branch should check photo-library availability")
assertContains(archive, "saveImageToArchive(_ image: UIImage) throws -> URL", "photo branch should persist selected image locally")
assertContains(archive, "archive-images", "photo branch should isolate local image files")

assertContains(audioEntry, "final class MemoryArchiveAudioRecorderViewController", "audio recorder sheet")
assertContains(audioEntry, "MicrophonePermissionManager.shared.requestPermission", "audio recorder should request microphone permission")
assertContains(audioEntry, "hasRecording", "audio save should require a recording")
assertContains(audioEntry, "AVAudioRecorder", "audio branch should use the platform recorder")
assertContains(audioEntry, "archive-audio", "audio branch should isolate local audio files")

assertContains(infoPlist, "NSPhotoLibraryUsageDescription", "photo archive branch requires photo library privacy text")
assertContains(infoPlist, "寻梦环游需要访问相册以选择回忆照片", "photo library privacy text should match product wording")
assertContains(infoPlist, "NSMicrophoneUsageDescription", "audio archive branch requires microphone privacy text")
assertContains(infoPlist, "寻梦环游需要使用麦克风来记录您的语音回忆", "microphone privacy text should match product wording")

assertContains(project, "MemoryArchiveTextEntryViewController.swift in Sources", "text entry file should be in target")
assertContains(project, "MemoryArchivePhotoEntryViewController.swift in Sources", "photo entry file should be in target")
assertContains(project, "MemoryArchiveAudioRecorderViewController.swift in Sources", "audio recorder file should be in target")
assertContains(project, "MemoryArchiveMediaReleaseReadiness.swift in Sources", "media readiness file should be in target")
