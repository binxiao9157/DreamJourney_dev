import Foundation

struct MemoryArchiveCreationOption: Equatable {
    let kind: MemoryArchiveItemKind
    let title: String
    let subtitle: String
    let iconName: String
    let isAvailable: Bool
    let submitsOwnerTruthSource: Bool

    var archiveKind: MemoryArchiveItemKind {
        kind
    }

    static func availableOptions(
        isAudioUploadEnabled: Bool,
        isVideoUploadEnabled: Bool,
        isTimeLettersEnabled: Bool,
        isOwnerTruthTextCaptureEnabled: Bool = false
    ) -> [MemoryArchiveCreationOption] {
        var options: [MemoryArchiveCreationOption] = [
            .text,
            .photo,
        ]

        if isOwnerTruthTextCaptureEnabled {
            options.insert(.ownerTruthTextCapture, at: 1)
        }

        if isAudioUploadEnabled {
            options.append(.audio)
        }

        if isVideoUploadEnabled {
            options.append(.video)
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
        submitsOwnerTruthSource: false
    )

    private static let ownerTruthTextCapture = MemoryArchiveCreationOption(
        kind: .text,
        title: "提交待确认记忆",
        subtitle: "先整理为候选记忆，由你确认后才会进入回响。",
        iconName: "checkmark.seal",
        isAvailable: true,
        submitsOwnerTruthSource: true
    )

    private static let photo = MemoryArchiveCreationOption(
        kind: .photo,
        title: "选择照片",
        subtitle: "从相册封存人物、地点和物件线索。",
        iconName: "photo.on.rectangle.angled",
        isAvailable: true,
        submitsOwnerTruthSource: false
    )

    private static let audio = MemoryArchiveCreationOption(
        kind: .audio,
        title: "录入语音",
        subtitle: "补充声音素材，让回响更接近真实语气。",
        iconName: "waveform",
        isAvailable: true,
        submitsOwnerTruthSource: false
    )

    private static let video = MemoryArchiveCreationOption(
        kind: .video,
        title: "录入视频片段",
        subtitle: "预留动态影像素材，等待压缩、缩略图和存储策略确认。",
        iconName: "video",
        isAvailable: true,
        submitsOwnerTruthSource: false
    )

    private static let timeLetter = MemoryArchiveCreationOption(
        kind: .timeLetter,
        title: "录入时间信件",
        subtitle: "写给未来某一天的自己或家人。",
        iconName: "envelope",
        isAvailable: true,
        submitsOwnerTruthSource: false
    )
}
