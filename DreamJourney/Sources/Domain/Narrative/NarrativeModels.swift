import Foundation

let narrativeProjectSchemaVersion = "narrative-project-v1"
let narrativeArtifactSchemaVersion = "narrative-artifact-v1"
let narrativeJobSchemaVersion = "narrative-job-v1"
let narrativeReadinessSchemaVersion = "narrative-readiness-v1"
let narrativeReaderManifestSchemaVersion = "narrative-reader-manifest-v1"
let narrativeReaderChapterSchemaVersion = "narrative-reader-chapter-v1"

enum NarrativeModelError: Error, Equatable {
    case unsupportedSchema(String)
    case invalidIdentifier(String)
    case invalidVersion
    case invalidHash
    case emptyText(String)
}

private protocol NarrativeVersionedContract {
    var schemaVersion: String { get }
    static var supportedSchemaVersion: String { get }
}

private extension NarrativeVersionedContract {
    func validateSchema() throws {
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw NarrativeModelError.unsupportedSchema(schemaVersion)
        }
    }
}

private func validateNarrativeIdentifier(_ value: String, field: String) throws {
    guard UUID(uuidString: value) != nil else {
        throw NarrativeModelError.invalidIdentifier(field)
    }
}

private func validateNarrativeHash(_ value: String) throws {
    guard value.count == 64, value.allSatisfy({ $0.isHexDigit }) else {
        throw NarrativeModelError.invalidHash
    }
}

struct NarrativeProject: Codable, Equatable, Sendable, NarrativeVersionedContract {
    static let supportedSchemaVersion = narrativeProjectSchemaVersion

    let schemaVersion: String
    let projectId: String
    let vaultId: String
    let subjectPersonaId: String
    let projectType: BookProjectType
    let narratorType: NarrativeNarratorType
    let title: String
    let state: BookProjectState
    let projectVersion: Int
    let privacyState: String
    let currentMemorySnapshotId: String?
    let currentGoldenSampleId: String?
    let currentConstitutionId: String?
    let currentOutlineId: String?
    let ignoredMemoryFingerprint: String?
    let writingContext: [String: NarrativeJSONValue]?
    let pausedFromState: BookProjectState?
    let createdAt: String
    let updatedAt: String
    let availableActions: [String]?
    let artifacts: [NarrativeArtifact]?

    func validated() throws -> Self {
        try validateSchema()
        try validateNarrativeIdentifier(projectId, field: "projectId")
        guard projectVersion >= 0 else { throw NarrativeModelError.invalidVersion }
        guard privacyState == "private" else { throw NarrativeModelError.invalidVersion }
        for value in [currentMemorySnapshotId, currentGoldenSampleId, currentConstitutionId, currentOutlineId] {
            if let value { try validateNarrativeIdentifier(value, field: "project reference") }
        }
        if let ignoredMemoryFingerprint { try validateNarrativeHash(ignoredMemoryFingerprint) }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NarrativeModelError.emptyText("title")
        }
        return self
    }
}

struct NarrativeArtifactList: Codable, Equatable, Sendable {
    let schemaVersion: String
    let artifacts: [NarrativeArtifact]

    func validated() throws -> Self {
        guard schemaVersion == "narrative-artifact-list-v1" else {
            throw NarrativeModelError.unsupportedSchema(schemaVersion)
        }
        _ = try artifacts.map { try $0.validated() }
        return self
    }
}

struct NarrativeProjectList: Codable, Equatable, Sendable {
    let schemaVersion: String
    let projects: [NarrativeProject]

    func validated() throws -> Self {
        guard schemaVersion == "narrative-project-list-v1" else {
            throw NarrativeModelError.unsupportedSchema(schemaVersion)
        }
        _ = try projects.map { try $0.validated() }
        return self
    }
}

struct NarrativeDeleteResult: Codable, Equatable, Sendable {
    let schemaVersion: String
    let projectId: String
    let state: BookProjectState
    let formalMemoryDeleted: Bool

    func validated() throws -> Self {
        guard schemaVersion == "narrative-delete-v1" else {
            throw NarrativeModelError.unsupportedSchema(schemaVersion)
        }
        try validateNarrativeIdentifier(projectId, field: "projectId")
        guard state == .deleted, formalMemoryDeleted == false else {
            throw NarrativeModelError.invalidVersion
        }
        return self
    }
}

struct NarrativeStoryCluster: Codable, Equatable, Sendable {
    let clusterKey: String
    let title: String
    let memoryVersionIds: [String]
    let itemCount: Int

    private enum CodingKeys: String, CodingKey {
        case clusterKey
        case title
        case memoryVersionIds
        case itemCount
        case legacyClusterKey = "clusterId"
        case legacyItemCount = "memoryCount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clusterKey = try container.decodeIfPresent(String.self, forKey: .clusterKey)
            ?? container.decode(String.self, forKey: .legacyClusterKey)
        title = try container.decode(String.self, forKey: .title)
        memoryVersionIds = try container.decode([String].self, forKey: .memoryVersionIds)
        itemCount = try container.decodeIfPresent(Int.self, forKey: .itemCount)
            ?? container.decode(Int.self, forKey: .legacyItemCount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clusterKey, forKey: .clusterKey)
        try container.encode(title, forKey: .title)
        try container.encode(memoryVersionIds, forKey: .memoryVersionIds)
        try container.encode(itemCount, forKey: .itemCount)
    }
}

struct NarrativeReadinessGap: Codable, Equatable, Sendable {
    let code: String
    let blocking: Bool
    let echoPrompt: String?
}

struct NarrativeReadiness: Codable, Equatable, Sendable, NarrativeVersionedContract {
    static let supportedSchemaVersion = narrativeReadinessSchemaVersion

    let schemaVersion: String
    let project: NarrativeProject
    let ready: Bool
    let availableMemoryCount: Int
    let storyClusters: [NarrativeStoryCluster]
    let gaps: [NarrativeReadinessGap]
    let generationAvailable: Bool?

    func validated() throws -> Self {
        try validateSchema()
        _ = try project.validated()
        guard availableMemoryCount >= 0 else { throw NarrativeModelError.invalidVersion }
        return self
    }
}

struct NarrativeArtifact: Codable, Equatable, Sendable, NarrativeVersionedContract {
    static let supportedSchemaVersion = narrativeArtifactSchemaVersion

    let schemaVersion: String
    let artifactVersionId: String
    let projectId: String
    let artifactType: NarrativeArtifactType
    let artifactKey: String
    let versionNumber: Int
    let parentVersionId: String?
    let memorySnapshotId: String
    let state: NarrativeArtifactState
    let contentText: String?
    let payload: [String: NarrativeJSONValue]
    let contentHash: String
    let origin: String
    let modelId: String?
    let promptVersion: String?
    let pipelineVersion: String?
    let createdAt: String

    func validated() throws -> Self {
        try validateSchema()
        try validateNarrativeIdentifier(artifactVersionId, field: "artifactVersionId")
        try validateNarrativeIdentifier(projectId, field: "projectId")
        try validateNarrativeIdentifier(memorySnapshotId, field: "memorySnapshotId")
        if let parentVersionId { try validateNarrativeIdentifier(parentVersionId, field: "parentVersionId") }
        try validateNarrativeHash(contentHash)
        guard versionNumber > 0 else { throw NarrativeModelError.invalidVersion }
        return self
    }

    var displayTitle: String {
        if case .string(let title)? = payload["title"], !title.isEmpty { return title }
        switch artifactType {
        case .writingAudition: return "主笔试镜"
        case .goldenSample: return "黄金样章"
        case .narrativeStyleProfile: return "叙事风格"
        case .writingConstitution: return "写作约定"
        case .outline: return "全书大纲"
        case .chapter: return "章节"
        }
    }

    var generationJobId: String? {
        guard case .string(let value)? = payload["generationJobId"],
              UUID(uuidString: value) != nil else {
            return nil
        }
        return value
    }
}

struct NarrativeJob: Codable, Equatable, Sendable, NarrativeVersionedContract {
    static let supportedSchemaVersion = narrativeJobSchemaVersion

    let schemaVersion: String
    let jobId: String
    let projectId: String
    let jobType: String
    let state: NarrativeJobState
    let memorySnapshotId: String
    let progressStage: String
    let attemptCount: Int
    let maxAttempts: Int
    let errorCode: String?
    let retryable: Bool
    let createdAt: String
    let finishedAt: String?

    func validated() throws -> Self {
        try validateSchema()
        try validateNarrativeIdentifier(jobId, field: "jobId")
        try validateNarrativeIdentifier(projectId, field: "projectId")
        try validateNarrativeIdentifier(memorySnapshotId, field: "memorySnapshotId")
        guard attemptCount >= 0, maxAttempts > 0 else { throw NarrativeModelError.invalidVersion }
        return self
    }

    var isTerminal: Bool {
        switch state {
        case .readyForReview, .needsEcho, .failed, .cancelled, .superseded: return true
        default: return false
        }
    }
}

struct NarrativeCommandResult: Codable, Equatable, Sendable {
    let schemaVersion: String
    let accepted: Bool?
    let job: NarrativeJob?
    let project: NarrativeProject?
    let artifact: NarrativeArtifact?
    let artifacts: [NarrativeArtifact]?

    func validated() throws -> Self {
        guard schemaVersion == "narrative-command-result-v1" else {
            throw NarrativeModelError.unsupportedSchema(schemaVersion)
        }
        if let job { _ = try job.validated() }
        if let project { _ = try project.validated() }
        if let artifact { _ = try artifact.validated() }
        _ = try artifacts?.map { try $0.validated() }
        return self
    }
}

struct NarrativeReaderChapterSummary: Codable, Equatable, Sendable {
    let chapterKey: String
    let chapterVersionId: String
    let title: String
    let order: Int
    let contentHash: String
}

struct NarrativeReaderManifest: Codable, Equatable, Sendable, NarrativeVersionedContract {
    static let supportedSchemaVersion = narrativeReaderManifestSchemaVersion

    let schemaVersion: String
    let projectId: String
    let vaultId: String
    let title: String
    let projectType: BookProjectType
    let chapters: [NarrativeReaderChapterSummary]

    func validated() throws -> Self {
        try validateSchema()
        try validateNarrativeIdentifier(projectId, field: "projectId")
        for chapter in chapters {
            try validateNarrativeIdentifier(chapter.chapterVersionId, field: "chapterVersionId")
            try validateNarrativeHash(chapter.contentHash)
        }
        return self
    }
}

struct NarrativeReaderParagraph: Codable, Equatable, Sendable {
    let paragraphId: String
    let text: String
}

struct NarrativeReaderChapter: Codable, Equatable, Sendable, NarrativeVersionedContract {
    static let supportedSchemaVersion = narrativeReaderChapterSchemaVersion

    let schemaVersion: String
    let projectId: String
    let chapterKey: String
    let chapterVersionId: String
    let title: String
    let paragraphs: [NarrativeReaderParagraph]
    let contentHash: String

    func validated() throws -> Self {
        try validateSchema()
        try validateNarrativeIdentifier(projectId, field: "projectId")
        try validateNarrativeIdentifier(chapterVersionId, field: "chapterVersionId")
        try validateNarrativeHash(contentHash)
        guard paragraphs.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw NarrativeModelError.emptyText("paragraph")
        }
        return self
    }
}

struct NarrativeExport: Codable, Equatable, Sendable {
    let schemaVersion: String
    let manifest: NarrativeReaderManifest
    let chapters: [NarrativeReaderChapter]

    func validated() throws -> Self {
        guard schemaVersion == "narrative-export-v1" else {
            throw NarrativeModelError.unsupportedSchema(schemaVersion)
        }
        _ = try manifest.validated()
        _ = try chapters.map { try $0.validated() }
        return self
    }

    var plainText: String {
        ([manifest.title] + chapters.flatMap { chapter in
            [chapter.title, chapter.paragraphs.map(\.text).joined(separator: "\n\n")]
        }).joined(separator: "\n\n")
    }
}
