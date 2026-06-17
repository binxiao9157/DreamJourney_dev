import Foundation

enum MemoryArchiveItemFactory {
    enum PhotoSource: String {
        case photoLibrary = "photo_library"
        case samplePhoto = "sample_photo"
    }

    static func makeTextItem(note: String) -> MemoryArchiveItem {
        MemoryArchiveItem(
            kind: .text,
            title: "文字记忆",
            note: note,
            analysisStatus: .manual,
            analysisSummary: "这是一段手动封存的文字片段，可作为后续回响生成的语义线索。",
            tags: ["文字片段"],
            metadata: textMetadata(contentKind: "text", note: note)
        )
    }

    static func makeTimeLetter(note: String) -> MemoryArchiveItem {
        MemoryArchiveItem(
            kind: .timeLetter,
            title: "时间信件",
            note: note,
            analysisStatus: .manual,
            analysisSummary: "这封信会作为未来回看与生成回响时的情感线索。",
            tags: ["时间信件"],
            metadata: textMetadata(contentKind: "time_letter", note: note).merging([
                "deliveryState": "sealed",
            ]) { current, _ in current }
        )
    }

    static func makePhotoItem(localPath: String, source: PhotoSource = .photoLibrary) -> MemoryArchiveItem {
        MemoryArchiveItem(
            kind: .photo,
            title: "相册影像",
            note: "从相册封存的一张照片",
            localPath: localPath,
            analysisStatus: .pending,
            analysisSummary: "照片已保存，等待后续图像分析提取人物、地点与场景线索。",
            tags: ["相册影像"],
            metadata: [
                "source": source.rawValue,
                "contentKind": "photo",
                "fileType": fileExtension(from: localPath),
                "storage": "local_file",
            ]
        )
    }

    static func makeAudioItem(localPath: String, duration: TimeInterval, note: String) -> MemoryArchiveItem {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationText = formatDuration(duration)
        let durationSeconds = max(1, Int(duration.rounded()))
        return MemoryArchiveItem(
            kind: .audio,
            title: "语音档案",
            note: trimmedNote.isEmpty ? "录入了一段 \(durationText) 的声音记忆。" : trimmedNote,
            localPath: localPath,
            analysisStatus: .manual,
            analysisSummary: "这段声音已封存，可作为之后回响生成时的语气、称呼与情绪线索。",
            tags: ["语音档案", durationText],
            metadata: [
                "source": "manual_audio",
                "contentKind": "audio",
                "durationText": durationText,
                "durationSeconds": "\(durationSeconds)",
                "fileType": fileExtension(from: localPath),
                "storage": "local_file",
            ]
        )
    }

    private static func textMetadata(contentKind: String, note: String) -> [String: String] {
        [
            "source": "manual_text",
            "contentKind": contentKind,
            "characterCount": "\(note.count)",
            "storage": "local_user_defaults",
        ]
    }

    private static func fileExtension(from localPath: String) -> String {
        let fileExtension = URL(fileURLWithPath: localPath).pathExtension.lowercased()
        return fileExtension.isEmpty ? "unknown" : fileExtension
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(1, Int(duration.rounded()))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
