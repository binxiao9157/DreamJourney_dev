import Foundation

enum MemoryArchiveCreationRoute: Equatable {
    case archive(MemoryArchiveItemKind)
    case ownerTruthTextSource
    case ownerTruthMedia(OwnerTruthMediaKind)
}

struct MemoryArchiveCreationOption: Equatable {
    let kind: MemoryArchiveItemKind
    let title: String
    let subtitle: String
    let iconName: String
    let isAvailable: Bool
    let route: MemoryArchiveCreationRoute

    var archiveKind: MemoryArchiveItemKind {
        kind
    }

    var submitsOwnerTruthSource: Bool {
        route == .ownerTruthTextSource
    }

    var ownerTruthMediaKind: OwnerTruthMediaKind? {
        guard case .ownerTruthMedia(let mediaKind) = route else { return nil }
        return mediaKind
    }

    static func availableOptions(
        isAudioUploadEnabled: Bool,
        isVideoUploadEnabled: Bool,
        isTimeLettersEnabled: Bool,
        isOwnerTruthTextCaptureEnabled: Bool = false,
        isOwnerTruthMediaCaptureEnabled: Bool = false
    ) -> [MemoryArchiveCreationOption] {
        var options: [MemoryArchiveCreationOption] = [
            .text,
            .photo,
        ]

        if isOwnerTruthTextCaptureEnabled {
            options[0] = .ownerTruthTextCapture
        }

        if isOwnerTruthMediaCaptureEnabled {
            options[1] = .ownerTruthPhotoCapture
            options.append(contentsOf: [
                .ownerTruthAudioCapture,
                .ownerTruthDocumentCapture,
                .ownerTruthVideoCapture,
            ])
        } else {
            if isAudioUploadEnabled {
                options.append(.audio)
            }

            if isVideoUploadEnabled {
                options.append(.video)
            }
        }

        if isTimeLettersEnabled {
            options.append(.timeLetter)
        }

        return options
    }

    private static let text = MemoryArchiveCreationOption(
        kind: .text,
        title: "添加文字描述",
        subtitle: "记录一句话、一段场景，或一个重要细节。",
        iconName: "text.alignleft",
        isAvailable: true,
        route: .archive(.text)
    )

    private static let ownerTruthTextCapture = MemoryArchiveCreationOption(
        kind: .text,
        title: "记录文字",
        subtitle: "先整理为候选记忆，由你确认后才会进入回响。",
        iconName: "checkmark.seal",
        isAvailable: true,
        route: .ownerTruthTextSource
    )

    private static let photo = MemoryArchiveCreationOption(
        kind: .photo,
        title: "选择照片",
        subtitle: "从相册封存人物、地点和物件线索。",
        iconName: "photo.on.rectangle.angled",
        isAvailable: true,
        route: .archive(.photo)
    )

    private static let ownerTruthPhotoCapture = MemoryArchiveCreationOption(
        kind: .photo,
        title: "选择图片",
        subtitle: "选择一张图片，并决定是否允许外部服务分析。",
        iconName: "photo.on.rectangle.angled",
        isAvailable: true,
        route: .ownerTruthMedia(.image)
    )

    private static let ownerTruthAudioCapture = MemoryArchiveCreationOption(
        kind: .audio,
        title: "选择音频",
        subtitle: "选择已有录音，并决定是否允许外部服务转写。",
        iconName: "waveform",
        isAvailable: true,
        route: .ownerTruthMedia(.audio)
    )

    private static let ownerTruthDocumentCapture = MemoryArchiveCreationOption(
        kind: .text,
        title: "选择文档",
        subtitle: "支持 TXT、PDF 和 DOCX，当前仅保存原始文件。",
        iconName: "doc.text",
        isAvailable: true,
        route: .ownerTruthMedia(.document)
    )

    private static let ownerTruthVideoCapture = MemoryArchiveCreationOption(
        kind: .video,
        title: "选择视频",
        subtitle: "保存视频素材，当前暂不进行内容分析。",
        iconName: "video",
        isAvailable: true,
        route: .ownerTruthMedia(.video)
    )

    private static let audio = MemoryArchiveCreationOption(
        kind: .audio,
        title: "录入语音",
        subtitle: "补充声音素材，让回响更接近真实语气。",
        iconName: "waveform",
        isAvailable: true,
        route: .archive(.audio)
    )

    private static let video = MemoryArchiveCreationOption(
        kind: .video,
        title: "录入视频片段",
        subtitle: "预留动态影像素材，等待压缩、缩略图和存储策略确认。",
        iconName: "video",
        isAvailable: true,
        route: .archive(.video)
    )

    private static let timeLetter = MemoryArchiveCreationOption(
        kind: .timeLetter,
        title: "录入时间信件",
        subtitle: "写给未来某一天的自己或家人。",
        iconName: "envelope",
        isAvailable: true,
        route: .archive(.timeLetter)
    )
}

enum OwnerTruthMediaCreationPolicyError: LocalizedError, Equatable {
    case externalProcessingChoiceRequired
    case fileTooLarge(maximumMB: Int)

    var errorDescription: String? {
        switch self {
        case .externalProcessingChoiceRequired:
            return "请先选择是否允许外部服务处理该素材"
        case .fileTooLarge(let maximumMB):
            return "文件不能超过 \(maximumMB) MB"
        }
    }
}

enum OwnerTruthMediaCreationPolicy {
    static let initialAuthorityEpoch = 0

    static func requiresExternalProcessingChoice(for mediaKind: OwnerTruthMediaKind) -> Bool {
        mediaKind.allowsExternalProcessing
    }

    static func maximumFileSizeMB(for mediaKind: OwnerTruthMediaKind) -> Int {
        switch mediaKind {
        case .image:
            return 20
        case .audio, .document, .video:
            return 50
        }
    }

    static func successMessage(for mediaKind: OwnerTruthMediaKind) -> String {
        switch mediaKind {
        case .video:
            return "已保存，暂不分析"
        case .image, .audio, .document:
            return "已保存，正在同步"
        }
    }

    static func makeCommand(
        expectedAuthorityEpoch: Int = initialAuthorityEpoch,
        mediaKind: OwnerTruthMediaKind,
        fileName: String,
        contentType: String,
        content: Data,
        allowExternalProcessing: Bool?
    ) throws -> OwnerTruthMediaUploadIntentCommand {
        if requiresExternalProcessingChoice(for: mediaKind), allowExternalProcessing == nil {
            throw OwnerTruthMediaCreationPolicyError.externalProcessingChoiceRequired
        }
        let maximumMB = maximumFileSizeMB(for: mediaKind)
        guard content.count <= maximumMB * 1_024 * 1_024 else {
            throw OwnerTruthMediaCreationPolicyError.fileTooLarge(maximumMB: maximumMB)
        }
        return try OwnerTruthMediaUploadIntentCommand(
            expectedAuthorityEpoch: expectedAuthorityEpoch,
            mediaKind: mediaKind,
            fileName: fileName,
            contentType: contentType,
            content: content,
            allowExternalProcessing: mediaKind.allowsExternalProcessing
                && allowExternalProcessing == true
        )
    }
}
