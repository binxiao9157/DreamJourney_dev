import Foundation

enum MemoryArchiveItemKind: String, Codable {
    case photo
    case video
    case audio
    case text
    case timeLetter
}

enum MemoryArchiveAnalysisStatus: String, Codable {
    case manual
    case pending
    case analyzed
    case failed
}

struct MemoryArchiveItem: Codable, Identifiable {
    let id: String
    var kind: MemoryArchiveItemKind
    var title: String
    var note: String
    var localPath: String?
    var createdAt: Date
    var updatedAt: Date
    var analysisStatus: MemoryArchiveAnalysisStatus
    var analysisSummary: String?
    var detectedPeople: [String]
    var tags: [String]

    init(
        kind: MemoryArchiveItemKind,
        title: String,
        note: String,
        localPath: String? = nil,
        analysisStatus: MemoryArchiveAnalysisStatus = .pending
    ) {
        self.id = UUID().uuidString
        self.kind = kind
        self.title = title
        self.note = note
        self.localPath = localPath
        self.createdAt = Date()
        self.updatedAt = Date()
        self.analysisStatus = analysisStatus
        self.analysisSummary = nil
        self.detectedPeople = []
        self.tags = []
    }
}
