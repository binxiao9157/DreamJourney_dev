import Foundation

enum MemoryArchiveMediaReleaseReadiness {
    enum Stage: Equatable {
        case publicRelease
        case hiddenReady(feature: DJFeature, qaLaunchArgument: String, reason: String)
        case unavailable(reason: String)
    }

    struct Capability: Equatable {
        let kind: MemoryArchiveItemKind
        let title: String
        let stage: Stage
        let persistence: String
        let requiresMicrophonePermission: Bool
        let releaseCopy: String
    }

    static let hiddenBranchesLaunchArgument = "DJEnableArchiveHiddenBranches"
    static let mediaUploadIntentEndpoint = "/archive/media/upload-intent"
    static let uploadIntentTTLSeconds = 900
    static let audioFileSizeLimitMB = 50
    static let videoFileSizeLimitMB = 200
    static let backendMediaStorageContract = "metadata_only_object_storage"

    private static func stage(for kind: MemoryArchiveItemKind) -> Stage {
        switch kind {
        case .text, .photo:
            return .publicRelease
        case .audio:
            return .hiddenReady(
                feature: .archiveAudioUpload,
                qaLaunchArgument: hiddenBranchesLaunchArgument,
                reason: "等待真机麦克风、权限拒绝恢复和音频播放验收后再公开。"
            )
        case .timeLetter:
            return .publicRelease
        case .video:
            return .hiddenReady(
                feature: .archiveVideoUpload,
                qaLaunchArgument: hiddenBranchesLaunchArgument,
                reason: "等待视频选择、压缩、缩略图、存储和后端媒体策略确认后再公开。"
            )
        }
    }

    static func capability(for kind: MemoryArchiveItemKind) -> Capability {
        switch kind {
        case .text:
            return Capability(
                kind: kind,
                title: "文字记忆",
                stage: stage(for: kind),
                persistence: "local_user_defaults",
                requiresMicrophonePermission: false,
                releaseCopy: "文字录入已作为公开档案入口。"
            )
        case .photo:
            return Capability(
                kind: kind,
                title: "相册影像",
                stage: stage(for: kind),
                persistence: "local_file",
                requiresMicrophonePermission: false,
                releaseCopy: "照片录入已作为公开档案入口。"
            )
        case .audio:
            return Capability(
                kind: kind,
                title: "语音档案",
                stage: stage(for: kind),
                persistence: "local_file",
                requiresMicrophonePermission: true,
                releaseCopy: "语音素材录入将在后续开放"
            )
        case .timeLetter:
            return Capability(
                kind: kind,
                title: "时间信件",
                stage: stage(for: kind),
                persistence: "local_user_defaults",
                requiresMicrophonePermission: false,
                releaseCopy: "时间信件录入已作为公开档案入口。"
            )
        case .video:
            return Capability(
                kind: kind,
                title: "视频片段",
                stage: stage(for: kind),
                persistence: "local_mock_file",
                requiresMicrophonePermission: false,
                releaseCopy: "视频片段暂为隐藏候选入口"
            )
        }
    }

    static func isCreationVisible(
        for kind: MemoryArchiveItemKind,
        isAudioUploadEnabled: Bool,
        isVideoUploadEnabled: Bool,
        isTimeLettersEnabled: Bool,
        isHiddenBranchesEnabled: Bool
    ) -> Bool {
        switch capability(for: kind).stage {
        case .publicRelease:
            return true
        case .hiddenReady(let feature, _, _):
            switch feature {
            case .archiveAudioUpload:
                return isAudioUploadEnabled || isHiddenBranchesEnabled
            case .timeLetters:
                return isTimeLettersEnabled || isHiddenBranchesEnabled
            case .archiveVideoUpload:
                return isVideoUploadEnabled || isHiddenBranchesEnabled
            default:
                return false
            }
        case .unavailable:
            return false
        }
    }

    static func unavailableCopy(for kind: MemoryArchiveItemKind) -> String {
        capability(for: kind).releaseCopy
    }
}
