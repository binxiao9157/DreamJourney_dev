import Foundation

struct MemoryArchiveItemPresentation {
    let title: String
    let note: String
    let kindLabel: String
    let statusLabel: String
    let previewTitle: String
    let previewSubtitle: String
    let previewIconName: String
    let metadataSummary: String?
    let originalContentTitle: String
    let accessibilityLabel: String
}

extension MemoryArchiveItemKind {
    var archiveDisplayName: String {
        switch self {
        case .photo:
            return "相册"
        case .video:
            return "视频"
        case .audio:
            return "语音"
        case .text:
            return "文字"
        case .timeLetter:
            return "信件"
        }
    }

    var archiveIconName: String {
        switch self {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "waveform"
        case .text:
            return "text.alignleft"
        case .timeLetter:
            return "envelope"
        }
    }
}

extension MemoryArchiveAnalysisStatus {
    var archiveDisplayName: String {
        switch self {
        case .manual:
            return "已归档"
        case .pending:
            return "待分析"
        case .analyzing:
            return "分析中"
        case .analyzed:
            return "已分析"
        case .failed:
            return "分析失败"
        case .retryable:
            return "可重试"
        }
    }
}

extension MemoryArchiveItem {
    var archivePresentation: MemoryArchiveItemPresentation {
        let previewTitle = archiveDetailFeatureTitle
        return MemoryArchiveItemPresentation(
            title: title,
            note: note,
            kindLabel: kind.archiveDisplayName,
            statusLabel: analysisStatus.archiveDisplayName,
            previewTitle: previewTitle,
            previewSubtitle: archiveDetailFeatureSubtitle,
            previewIconName: archiveDetailFeatureIconName,
            metadataSummary: archiveListMetadataSummary,
            originalContentTitle: archiveOriginalContentTitle,
            accessibilityLabel: "\(title)，\(previewTitle)，\(analysisStatus.archiveDisplayName)"
        )
    }

    var archiveDetailFeatureTitle: String {
        switch kind {
        case .photo:
            return "照片影像"
        case .audio:
            return "声音片段"
        case .text:
            return "文字内容"
        case .timeLetter:
            return "写给未来的信"
        case .video:
            return "动态影像"
        }
    }

    var archiveDetailFeatureSubtitle: String {
        switch kind {
        case .photo:
            return archiveListMetadataSummary ?? "封存可回看的影像线索"
        case .audio:
            return archiveListMetadataSummary ?? "记录语气、称呼与情绪线索"
        case .text:
            return archiveListMetadataSummary ?? "手动录入的生活细节"
        case .timeLetter:
            return "已封存，未来回看时作为情感线索"
        case .video:
            return archiveListMetadataSummary ?? "封存动态影像线索"
        }
    }

    var archiveDetailFeatureIconName: String {
        switch kind {
        case .photo:
            return "photo.on.rectangle"
        case .audio:
            return "waveform.circle"
        case .text:
            return "note.text"
        case .timeLetter:
            return "envelope.open"
        case .video:
            return "video"
        }
    }

    var archiveOriginalContentTitle: String {
        switch kind {
        case .photo:
            return "照片说明"
        case .audio:
            return "声音说明"
        case .text:
            return "文字内容"
        case .timeLetter:
            return "信件内容"
        case .video:
            return "原始内容"
        }
    }

    var archiveListMetadataSummary: String? {
        switch kind {
        case .photo:
            return joinedMetadataParts([
                metadataSourceDisplayName,
                metadataFileTypeDisplayName,
                hasResolvedLocalFile ? "本地已保存" : nil,
                archiveBackendSyncDisplayName,
            ])
        case .audio:
            return joinedMetadataParts([
                metadataDurationText,
                metadataSourceDisplayName,
                metadataUploadStatusDisplayName,
                metadataTranscriptionStatusDisplayName,
                hasResolvedLocalFile ? "本地已保存" : nil,
            ])
        case .text:
            return joinedMetadataParts([
                metadataCharacterCountDisplayName,
                metadataSourceDisplayName,
                archiveBackendSyncDisplayName,
            ])
        case .timeLetter:
            return joinedMetadataParts([
                metadataCharacterCountDisplayName,
                metadataSourceDisplayName,
            ])
        case .video:
            return joinedMetadataParts([
                "动态影像",
                metadataSourceDisplayName,
                metadataUploadStatusDisplayName,
                metadataFileSizeDisplayName,
                videoAnalysisStatusDisplayName,
                metadataThumbnailDisplayName,
                metadataFileSizeLimitDisplayName,
            ])
        }
    }

    var archiveDetailMetadataRows: [(title: String, value: String)] {
        var rows: [(String, String)] = [
            ("素材类型", kind.archiveDisplayName),
            ("采集来源", metadataSourceDisplayName ?? "手动录入"),
            ("分析状态", analysisStatus.archiveDisplayName),
        ]
        if let archiveAnalysisAvailabilityDisplayName {
            rows.append(("AI 分析", archiveAnalysisAvailabilityDisplayName))
        }

        switch kind {
        case .photo:
            rows.append(("文件类型", metadataFileTypeDisplayName ?? "图片"))
            rows.append(("文件状态", hasResolvedLocalFile ? "本地已保存" : "未保存本地文件"))
            if let archiveBackendSyncDisplayName {
                rows.append(("云端状态", archiveBackendSyncDisplayName))
            }
        case .audio:
            rows.append(("语音时长", metadataDurationText ?? "已封存"))
            rows.append(("文件类型", metadataFileTypeDisplayName ?? "音频"))
            rows.append(("文件状态", hasResolvedLocalFile ? "本地已保存" : "未保存本地文件"))
            rows.append(("上传状态", metadataUploadStatusDisplayName ?? "本地待上传"))
            if let metadataUploadErrorDisplayName {
                rows.append(("上传错误", metadataUploadErrorDisplayName))
            }
            rows.append(("转写状态", metadataTranscriptionStatusDisplayName ?? "未转写"))
            if let transcriptText = metadataTranscriptText {
                rows.append(("转写结果", transcriptText))
            }
        case .text:
            rows.append(("字数", metadataCharacterCountDisplayName ?? "\(note.count) 字"))
            if let archiveBackendSyncDisplayName {
                rows.append(("云端状态", archiveBackendSyncDisplayName))
            }
        case .timeLetter:
            rows.append(("字数", metadataCharacterCountDisplayName ?? "\(note.count) 字"))
            switch metadata["deliveryState"] {
            case "draft":
                rows.append(("信件状态", "草稿"))
            case "sealed":
                rows.append(("信件状态", "已封存"))
            default:
                rows.append(("信件状态", "已保存"))
            }
            if metadata["deliveryPolicy"] == "pending_product_decision" {
                rows.append(("投递策略", "产品决策后开放"))
            }
            if isTimeLetterDeliveryDisabledUntilProductDecision {
                rows.append(("投递状态", "暂不投递"))
                rows.append(("决策状态", "等待产品决策"))
                rows.append(("通知状态", "未调度通知"))
            }
        case .video:
            rows.append(("文件状态", hasResolvedLocalFile ? "本地已保存" : "未保存本地文件"))
            rows.append(("文件大小", metadataFileSizeDisplayName ?? "未知"))
            rows.append(("上传状态", metadataUploadStatusDisplayName ?? "本地待上传"))
            if let metadataUploadErrorDisplayName {
                rows.append(("上传错误", metadataUploadErrorDisplayName))
            }
            rows.append(("缩略图", metadataThumbnailDisplayName ?? "待生成"))
            rows.append(("视频分析", videoAnalysisStatusDisplayName ?? analysisStatus.archiveDisplayName))
            rows.append(("文件上限", metadataFileSizeLimitDisplayName ?? "\(MemoryArchiveMediaReleaseReadiness.videoFileSizeLimitMB)MB"))
            rows.append(("云端合同", metadata["backendStorageContract"] ?? MemoryArchiveMediaReleaseReadiness.backendMediaStorageContract))
        }

        return rows
    }

    var archiveBackendSyncDisplayName: String? {
        guard isPublicBackendSyncEligible,
              metadata[Self.backendSyncStateMetadataKey] != nil else {
            return nil
        }

        switch backendSyncState {
        case .pending:
            return "待同步云端"
        case .synced:
            return "云端已同步"
        case .failed:
            if analysisStatus.isRetryableFailureLike,
               metadata[Self.backendSyncErrorMetadataKey] == nil {
                return "云端已同步"
            }
            return "同步失败，可稍后重试"
        }
    }

    var archiveAnalysisAvailabilityDisplayName: String? {
        switch analysisStatus {
        case .manual:
            return nil
        case .pending:
            return "AI 分析等待中"
        case .analyzing:
            return "AI 分析中"
        case .analyzed:
            return "AI 分析已生成"
        case .failed:
            return analysisRetryableForBackend ? "AI 分析暂不可用，可稍后重试" : "AI 分析失败"
        case .retryable:
            return "AI 分析暂不可用，可稍后重试"
        }
    }

    private var metadataSourceDisplayName: String? {
        switch metadata["source"] {
        case "manual_text":
            return "手动录入"
        case "photo_library":
            return "相册导入"
        case "sample_photo":
            return "样张封存"
        case "manual_audio":
            return "现场录音"
        case "manual_video":
            return "视频导入"
        case let source? where !source.isEmpty:
            return source
        default:
            return nil
        }
    }

    private var metadataFileTypeDisplayName: String? {
        guard let fileType = metadata["fileType"], !fileType.isEmpty else { return nil }
        return fileType.uppercased()
    }

    private var metadataCharacterCountDisplayName: String? {
        guard let characterCount = metadata["characterCount"], !characterCount.isEmpty else { return nil }
        return "\(characterCount) 字"
    }

    private var metadataDurationText: String? {
        if let durationText = metadata["durationText"], !durationText.isEmpty {
            return durationText
        }

        return tags.first { tag in
            let parts = tag.split(separator: ":")
            guard parts.count == 2,
                  parts.allSatisfy({ $0.count == 2 }) else {
                return false
            }
            return parts.joined().allSatisfy(\.isNumber)
        }
    }

    private var metadataUploadStatusDisplayName: String? {
        switch metadata[MemoryArchiveItem.mediaUploadStatusMetadataKey] {
        case ArchiveMediaUploadStatus.localOnly.rawValue:
            return "本地待上传"
        case ArchiveMediaUploadStatus.pending.rawValue:
            return "上传中"
        case ArchiveMediaUploadStatus.uploaded.rawValue:
            return "已上传"
        case ArchiveMediaUploadStatus.failed.rawValue:
            return "上传失败"
        default:
            return nil
        }
    }

    private var metadataUploadErrorDisplayName: String? {
        guard metadata[MemoryArchiveItem.mediaUploadStatusMetadataKey] == ArchiveMediaUploadStatus.failed.rawValue,
              let error = metadata[MemoryArchiveItem.mediaUploadErrorMetadataKey],
              !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return error
    }

    private var metadataTranscriptionStatusDisplayName: String? {
        switch audioTranscriptionStatusDisplayName {
        case "转写失败，可重试":
            return "转写失败，可重试"
        default:
            return audioTranscriptionStatusDisplayName
        }
    }

    private var metadataTranscriptText: String? {
        metadataTranscriptTextForDisplay
    }

    private var metadataThumbnailDisplayName: String? {
        if metadata["thumbnailObjectKey"]?.isEmpty == false {
            return "云端缩略图已登记"
        }
        if metadata[MemoryArchiveItem.mediaThumbnailPathMetadataKey]?.isEmpty == false {
            return "本地缩略图已生成"
        }
        switch metadata["thumbnailStatus"] {
        case "generated":
            return "缩略图已生成"
        case "pending":
            return "待生成"
        case "failed":
            return "生成失败"
        default:
            return nil
        }
    }

    private var metadataFileSizeLimitDisplayName: String? {
        guard let limit = metadata[MemoryArchiveItem.mediaFileSizeLimitMBMetadataKey],
              !limit.isEmpty else {
            return nil
        }
        return "\(limit)MB"
    }

    private func joinedMetadataParts(_ parts: [String?]) -> String? {
        let displayParts = parts.compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return displayParts.isEmpty ? nil : displayParts.joined(separator: " · ")
    }
}
