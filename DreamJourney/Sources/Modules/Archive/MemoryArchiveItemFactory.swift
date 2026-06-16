import Foundation

enum MemoryArchiveItemFactory {
    static func makeTextItem(note: String) -> MemoryArchiveItem {
        MemoryArchiveItem(
            kind: .text,
            title: "文字记忆",
            note: note,
            analysisStatus: .manual,
            analysisSummary: "这是一段手动封存的文字片段，可作为后续回响生成的语义线索。",
            tags: ["文字片段"]
        )
    }

    static func makeTimeLetter(note: String) -> MemoryArchiveItem {
        MemoryArchiveItem(
            kind: .timeLetter,
            title: "时间信件",
            note: note,
            analysisStatus: .manual,
            analysisSummary: "这封信会作为未来回看与生成回响时的情感线索。",
            tags: ["时间信件"]
        )
    }

    static func makePhotoItem(localPath: String) -> MemoryArchiveItem {
        MemoryArchiveItem(
            kind: .photo,
            title: "相册影像",
            note: "从相册封存的一张照片",
            localPath: localPath,
            analysisStatus: .pending,
            analysisSummary: "照片已保存，等待后续图像分析提取人物、地点与场景线索。",
            tags: ["相册影像"]
        )
    }
}
