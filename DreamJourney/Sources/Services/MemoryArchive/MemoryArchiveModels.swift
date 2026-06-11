import Foundation

enum MemoryArchiveItemKind: String, Codable {
    case photo
    case textNote
    case personalityNote
    case catchphrase
}

enum MemoryArchiveAnalysisStatus: String, Codable {
    case manual
    case pending
    case analyzed
    case failed
}

struct MemoryArchiveImageAnalysis: Codable, Equatable {
    let summary: String
    let detectedPeople: [String]
    let scene: String?
    let occasion: String?
    let mood: String?
    let estimatedDecade: Int?
}

struct MemoryArchiveItem: Codable, Identifiable, Equatable {
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
    var scene: String?
    var occasion: String?
    var mood: String?
    var estimatedDecade: Int?
    var tags: [String]
    var isPrivate: Bool
}

struct MemoryArchiveSummary: Equatable {
    let totalCount: Int
    let photoCount: Int
    let textCount: Int
    let analyzedPhotoCount: Int
}
