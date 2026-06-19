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
            ownerUserId: currentUploaderUserId,
            analysisStatus: .manual,
            analysisSummary: "这是一段手动封存的文字片段，可作为后续回响生成的语义线索。",
            tags: ["文字片段"],
            metadata: textMetadata(contentKind: "text", note: note)
        )
    }

    static func makeTimeLetterDraft(note: String) -> MemoryArchiveItem {
        MemoryArchiveItem(
            kind: .timeLetter,
            title: "时间信件草稿",
            note: note,
            ownerUserId: currentUploaderUserId,
            analysisStatus: .manual,
            analysisSummary: "这封信暂存为草稿，不会触发真实通知或投递。",
            tags: ["时间信件", "草稿"],
            metadata: timeLetterMetadata(note: note, deliveryState: "draft", timeLetterStatus: "draft")
        )
    }

    static func makeTimeLetter(note: String) -> MemoryArchiveItem {
        MemoryArchiveItem(
            kind: .timeLetter,
            title: "时间信件",
            note: note,
            ownerUserId: currentUploaderUserId,
            analysisStatus: .manual,
            analysisSummary: "这封信会作为未来回看与生成回响时的情感线索。",
            tags: ["时间信件"],
            metadata: timeLetterMetadata(note: note, deliveryState: "sealed", timeLetterStatus: "sealed")
        )
    }

    static func makePhotoItem(localPath: String, source: PhotoSource = .photoLibrary) -> MemoryArchiveItem {
        MemoryArchiveItem(
            kind: .photo,
            title: "相册影像",
            note: "从相册封存的一张照片",
            localPath: localPath,
            ownerUserId: currentUploaderUserId,
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

    static func makeAudioItem(
        localPath: String,
        duration: TimeInterval,
        note: String,
        transcriptText: String? = nil,
        transcriptionStatus: ArchiveMediaTranscriptionStatus = .notRequested,
        analysisStatus: MemoryArchiveAnalysisStatus = .manual,
        uploadStatus: ArchiveMediaUploadStatus = .localOnly
    ) -> MemoryArchiveItem {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranscript = transcriptText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let durationText = formatDuration(duration)
        let durationSeconds = max(1, Int(duration.rounded()))
        let resolvedTranscriptionStatus = transcriptionStatus == .notRequested && !trimmedTranscript.isEmpty
            ? ArchiveMediaTranscriptionStatus.completed
            : transcriptionStatus
        var metadata: [String: String] = [
            "source": "manual_audio",
            "contentKind": "audio",
            "durationText": durationText,
            "durationSeconds": "\(durationSeconds)",
            "fileType": fileExtension(from: localPath),
            "storage": "local_file",
            MemoryArchiveItem.mediaUploadStatusMetadataKey: uploadStatus.rawValue,
            MemoryArchiveItem.mediaTranscriptionStatusMetadataKey: resolvedTranscriptionStatus.rawValue,
            MemoryArchiveItem.mediaFileSizeLimitMBMetadataKey: "\(MemoryArchiveMediaReleaseReadiness.audioFileSizeLimitMB)",
            "backendStorageContract": MemoryArchiveMediaReleaseReadiness.backendMediaStorageContract,
            "transcriptLanguage": "zh-CN",
        ]
        if let fileSizeBytes = localFileSizeBytes(at: localPath) {
            metadata[MemoryArchiveItem.mediaFileSizeBytesMetadataKey] = "\(fileSizeBytes)"
        }
        if !trimmedTranscript.isEmpty {
            metadata[MemoryArchiveItem.mediaTranscriptTextMetadataKey] = trimmedTranscript
        }

        return MemoryArchiveItem(
            kind: .audio,
            title: "语音档案",
            note: trimmedNote.isEmpty ? "录入了一段 \(durationText) 的声音记忆。" : trimmedNote,
            localPath: localPath,
            ownerUserId: currentUploaderUserId,
            analysisStatus: analysisStatus,
            analysisSummary: "这段声音已封存，可作为之后回响生成时的语气、称呼与情绪线索。",
            tags: ["语音档案", durationText],
            metadata: metadata
        )
    }

    static func makeVideoItem(
        localPath: String,
        thumbnailPath: String? = nil,
        fileSizeBytes: Int64? = nil,
        note: String = "",
        analysisStatus: MemoryArchiveAnalysisStatus = .pending,
        uploadStatus: ArchiveMediaUploadStatus = .localOnly
    ) -> MemoryArchiveItem {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var metadata: [String: String] = [
            "source": "manual_video",
            "contentKind": "video",
            "fileType": fileExtension(from: localPath),
            "storage": "local_file",
            MemoryArchiveItem.mediaUploadStatusMetadataKey: uploadStatus.rawValue,
            MemoryArchiveItem.mediaFileSizeLimitMBMetadataKey: "\(MemoryArchiveMediaReleaseReadiness.videoFileSizeLimitMB)",
            "backendStorageContract": MemoryArchiveMediaReleaseReadiness.backendMediaStorageContract,
        ]
        if let fileSizeBytes {
            metadata[MemoryArchiveItem.mediaFileSizeBytesMetadataKey] = "\(fileSizeBytes)"
        }
        if let thumbnailPath, !thumbnailPath.isEmpty {
            metadata[MemoryArchiveItem.mediaThumbnailPathMetadataKey] = thumbnailPath
            metadata["thumbnailFileType"] = fileExtension(from: thumbnailPath)
            metadata["thumbnailStorage"] = "local_file"
            metadata["thumbnailStatus"] = "generated"
        } else {
            metadata["thumbnailStatus"] = "pending"
        }

        return MemoryArchiveItem(
            kind: .video,
            title: "视频片段",
            note: trimmedNote.isEmpty ? "封存了一段等待分析的视频片段。" : trimmedNote,
            localPath: localPath,
            ownerUserId: currentUploaderUserId,
            analysisStatus: analysisStatus,
            analysisSummary: "视频已保存，等待后续提取动态场景、人物与时间线索。",
            tags: ["视频片段"],
            metadata: metadata
        )
    }

    private static var currentUploaderUserId: String {
        UserManager.shared.currentUser?.id ?? MemoryArchiveItem.legacyOwnerUserId
    }

    private static func textMetadata(contentKind: String, note: String) -> [String: String] {
        [
            "source": "manual_text",
            "contentKind": contentKind,
            "characterCount": "\(note.count)",
            "storage": "local_user_defaults",
        ]
    }

    private static func timeLetterMetadata(
        note: String,
        deliveryState: String,
        timeLetterStatus: String
    ) -> [String: String] {
        textMetadata(contentKind: "time_letter", note: note).merging([
            "deliveryState": deliveryState,
            "timeLetterStatus": timeLetterStatus,
            "deliveryPolicy": "pending_product_decision",
            "deliveryDecisionRequired": "true",
            "deliveryExecutionState": "not_delivering",
            "deliveryDecisionState": "waiting_product_decision",
            "deliveryScheduleState": "not_scheduled",
            "deliveryProviderState": "disabled_until_product_decision",
            "deliveryNotificationScheduled": "false",
        ]) { current, _ in current }
    }

    private static func fileExtension(from localPath: String) -> String {
        let fileExtension = URL(fileURLWithPath: localPath).pathExtension.lowercased()
        return fileExtension.isEmpty ? "unknown" : fileExtension
    }

    private static func localFileSizeBytes(at localPath: String) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: localPath),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(1, Int(duration.rounded()))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
