import Foundation

func assertEqual(_ lhs: String?, _ rhs: String, _ message: String) {
    guard lhs == rhs else {
        fatalError("\(message): expected \(rhs), got \(lhs ?? "nil")")
    }
}

func assertContains(_ values: [String], _ expected: String, _ message: String) {
    guard values.contains(expected) else {
        fatalError("\(message): expected \(values) to contain \(expected)")
    }
}

let textItem = MemoryArchiveItemFactory.makeTextItem(note: "hello archive")
assertEqual(textItem.metadata["source"], "manual_text", "text source")
assertEqual(textItem.metadata["contentKind"], "text", "text content kind")
assertEqual(textItem.metadata["characterCount"], "13", "text character count")

let timeLetter = MemoryArchiveItemFactory.makeTimeLetter(note: "future letter")
assertEqual(timeLetter.metadata["source"], "manual_text", "time letter source")
assertEqual(timeLetter.metadata["contentKind"], "time_letter", "time letter content kind")

let photoItem = MemoryArchiveItemFactory.makePhotoItem(localPath: "/tmp/archive-photo.jpg")
assertEqual(photoItem.metadata["source"], "photo_library", "photo source")
assertEqual(photoItem.metadata["fileType"], "jpg", "photo file type")

let audioItem = MemoryArchiveItemFactory.makeAudioItem(
    localPath: "/tmp/archive-audio.m4a",
    duration: 7.2,
    note: ""
)
assertEqual(audioItem.metadata["source"], "manual_audio", "audio source")
assertEqual(audioItem.metadata["durationText"], "00:07", "audio duration text")
assertEqual(audioItem.metadata["durationSeconds"], "7", "audio duration seconds")
assertEqual(textItem.archiveDetailFeatureTitle, "文字内容", "text detail feature title")
assertEqual(timeLetter.archiveDetailFeatureTitle, "写给未来的信", "time letter detail feature title")
assertEqual(photoItem.archiveDetailFeatureTitle, "照片影像", "photo detail feature title")
assertEqual(audioItem.archiveDetailFeatureTitle, "声音片段", "audio detail feature title")
assertEqual(timeLetter.archiveDetailFeatureIconName, "envelope.open", "time letter detail feature icon")
assertEqual(photoItem.archivePresentation.previewTitle, photoItem.archiveDetailFeatureTitle, "photo presentation title matches detail")
assertEqual(photoItem.archivePresentation.previewIconName, "photo.on.rectangle", "photo presentation icon")
assertEqual(audioItem.archivePresentation.previewTitle, audioItem.archiveDetailFeatureTitle, "audio presentation title matches detail")
assertEqual(audioItem.archivePresentation.previewSubtitle, audioItem.archiveDetailFeatureSubtitle, "audio presentation subtitle matches detail")
assertEqual(timeLetter.archivePresentation.previewIconName, "envelope.open", "time letter presentation icon")
assertEqual(timeLetter.archivePresentation.accessibilityLabel, "时间信件，写给未来的信，已归档", "time letter presentation accessibility")

let legacyJSON = """
{
  "id": "legacy",
  "kind": "text",
  "title": "Legacy",
  "note": "old item",
  "createdAt": 0,
  "updatedAt": 0,
  "analysisStatus": "manual",
  "detectedPeople": [],
  "tags": []
}
""".data(using: .utf8)!
let legacyItem = try JSONDecoder().decode(MemoryArchiveItem.self, from: legacyJSON)
if !legacyItem.metadata.isEmpty {
    fatalError("legacy metadata should default to empty dictionary")
}

let legacyAudioItem = MemoryArchiveItem(
    kind: .audio,
    title: "Legacy Audio",
    note: "old audio",
    localPath: "/tmp/archive-audio.m4a",
    analysisStatus: .manual,
    tags: ["语音档案", "00:07"]
)
assertEqual(legacyAudioItem.archiveListMetadataSummary, "00:07 · 本地已保存", "legacy audio list duration fallback")
let legacyAudioDurationRow = legacyAudioItem.archiveDetailMetadataRows.first { $0.title == "语音时长" }?.value
assertEqual(legacyAudioDurationRow, "00:07", "legacy audio detail duration fallback")

var analyzedTextItem = MemoryArchiveItemFactory.makeTextItem(note: "奶奶在老家的院子里晒太阳")
analyzedTextItem.applyLocalAnalysisResult(now: Date(timeIntervalSince1970: 1_800_000_000))
assertEqual(analyzedTextItem.analysisStatus.rawValue, "analyzed", "local analysis status")
assertContains(analyzedTextItem.tags, "文字线索", "local analysis text tag")
assertContains(analyzedTextItem.detectedPeople, "奶奶", "local analysis relationship hint")
assertEqual(analyzedTextItem.metadata["analysisSource"], "local_rule", "local analysis source")
assertEqual(analyzedTextItem.metadata["analysisUpdatedAt"], "1800000000", "local analysis timestamp")

var analyzedPhotoItem = MemoryArchiveItemFactory.makePhotoItem(localPath: "/tmp/archive-photo.jpg")
analyzedPhotoItem.applyLocalAnalysisResult(now: Date(timeIntervalSince1970: 1_800_000_001))
assertEqual(analyzedPhotoItem.analysisStatus.rawValue, "analyzed", "photo local analysis status")
assertContains(analyzedPhotoItem.tags, "场景线索", "photo local analysis scene tag")
assertEqual(analyzedPhotoItem.metadata["analysisSource"], "local_rule", "photo local analysis source")
