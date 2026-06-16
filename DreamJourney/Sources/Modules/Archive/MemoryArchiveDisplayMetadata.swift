import Foundation

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
        case .analyzed:
            return "已分析"
        case .failed:
            return "分析失败"
        }
    }
}
