import CryptoKit
import Foundation
import KeychainAccess

protocol OwnerTruthMediaUploadSecretStoring: AnyObject {
    func save(
        _ token: OwnerTruthMediaUploadToken,
        scopeDigest: String,
        taskID: UUID
    ) throws

    func load(scopeDigest: String, taskID: UUID) throws -> OwnerTruthMediaUploadToken?

    func remove(scopeDigest: String, taskID: UUID) throws
}

final class OwnerTruthMediaUploadKeychainStore: OwnerTruthMediaUploadSecretStoring {
    static let shared = OwnerTruthMediaUploadKeychainStore()

    private let keychain = Keychain(service: "com.dreamjourney.owner-truth-media-upload")
        .accessibility(.afterFirstUnlockThisDeviceOnly)
        .synchronizable(false)

    func save(
        _ token: OwnerTruthMediaUploadToken,
        scopeDigest: String,
        taskID: UUID
    ) throws {
        try keychain.set(token.rawValue, key: key(scopeDigest: scopeDigest, taskID: taskID))
    }

    func load(scopeDigest: String, taskID: UUID) throws -> OwnerTruthMediaUploadToken? {
        guard let rawValue = try keychain.get(key(scopeDigest: scopeDigest, taskID: taskID)) else {
            return nil
        }
        return OwnerTruthMediaUploadToken(rawValue)
    }

    func remove(scopeDigest: String, taskID: UUID) throws {
        try keychain.remove(key(scopeDigest: scopeDigest, taskID: taskID))
    }

    private func key(scopeDigest: String, taskID: UUID) -> String {
        "\(scopeDigest):\(taskID.uuidString.lowercased())"
    }
}

enum OwnerTruthMediaTaskStoreError: LocalizedError, Equatable {
    case staleAccountLease
    case invalidScope
    case taskNotFound
    case invalidPendingContent
    case invalidReceipt
    case uploadTokenUnavailable
    case storageFailure

    var errorDescription: String? {
        switch self {
        case .staleAccountLease:
            return "账号状态已变化，媒体任务已停止"
        case .invalidScope:
            return "媒体任务账号范围无效"
        case .taskNotFound:
            return "未找到待恢复的媒体任务"
        case .invalidPendingContent:
            return "待上传媒体文件缺失或已损坏"
        case .invalidReceipt:
            return "媒体任务回执无效"
        case .uploadTokenUnavailable:
            return "媒体上传凭据已失效"
        case .storageFailure:
            return "媒体任务本地存储失败"
        }
    }
}

enum OwnerTruthMediaTaskPhase: String, Codable, Equatable, Sendable {
    case prepared
    case uploadReady
    case uploading
    case uploadRetryableFailed
    case uploaded
    case processingQueued
    case processing
    case processed
    case retryableFailed
    case failed
    case quarantined
    case deleted

    fileprivate var needsPendingContent: Bool {
        self == .prepared
            || self == .uploadReady
            || self == .uploading
            || self == .uploadRetryableFailed
    }

    fileprivate var needsStatusRefresh: Bool {
        self == .uploaded || self == .processingQueued || self == .processing
    }
}

struct OwnerTruthMediaTaskReceipt: Codable, Equatable, Sendable {
    static let currentSchemaVersion = "owner-truth-media-task-v1"

    let schemaVersion: String
    let taskID: UUID
    let scopeDigest: String
    var leaseFenceDigest: String
    let commandID: UUID
    let expectedAuthorityEpoch: Int
    let mediaKind: OwnerTruthMediaKind
    let fileName: String
    let contentType: String
    let fileSizeBytes: Int
    let contentSHA256: String
    let purpose: String
    let clientCreatedAt: Date
    let allowExternalProcessing: Bool
    var phase: OwnerTruthMediaTaskPhase
    var uploadIntentID: UUID?
    var uploadIntentExpiresAt: Date?
    var sourceObjectID: UUID?
    var sourceObjectState: OwnerTruthMediaSourceObjectState?
    var processingStatus: OwnerTruthMediaProcessingStatus?
    /// Sanitized server deletion state. It carries no storage or Provider data.
    var mediaAccessState: OwnerTruthMediaAccessState?
    var deletionStatus: OwnerTruthMediaDeletionStatus?
    var deletionRetryable: Bool?
    var deletionFailureCode: String?
    /// The derived private Source is persisted only to continue the in-app
    /// Candidate handoff after a restart. It is never rendered to the user.
    var derivedSourceID: UUID?
    var retryable: Bool
    var failureCode: String?
    let createdAt: Date
    var updatedAt: Date

    fileprivate init(
        taskID: UUID,
        scopeDigest: String,
        leaseFenceDigest: String,
        command: OwnerTruthMediaUploadIntentCommand,
        now: Date
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.taskID = taskID
        self.scopeDigest = scopeDigest
        self.leaseFenceDigest = leaseFenceDigest
        commandID = command.commandID
        expectedAuthorityEpoch = command.expectedAuthorityEpoch
        mediaKind = command.mediaKind
        fileName = command.fileName
        contentType = command.contentType
        fileSizeBytes = command.fileSizeBytes
        contentSHA256 = command.contentSHA256
        purpose = command.purpose
        clientCreatedAt = command.clientCreatedAt
        allowExternalProcessing = command.allowExternalProcessing
        phase = .prepared
        uploadIntentID = nil
        uploadIntentExpiresAt = nil
        sourceObjectID = nil
        sourceObjectState = nil
        processingStatus = nil
        mediaAccessState = nil
        deletionStatus = nil
        deletionRetryable = nil
        deletionFailureCode = nil
        derivedSourceID = nil
        retryable = false
        failureCode = nil
        createdAt = now
        updatedAt = now
    }

    fileprivate func command() throws -> OwnerTruthMediaUploadIntentCommand {
        try OwnerTruthMediaUploadIntentCommand(
            commandID: commandID,
            expectedAuthorityEpoch: expectedAuthorityEpoch,
            mediaKind: mediaKind,
            fileName: fileName,
            contentType: contentType,
            fileSizeBytes: fileSizeBytes,
            contentSHA256: contentSHA256,
            purpose: purpose,
            clientCreatedAt: clientCreatedAt,
            allowExternalProcessing: allowExternalProcessing
        )
    }
}

enum OwnerTruthMediaTaskRetryAction: String, Equatable, Sendable {
    case resumeUpload
    case retryProcessing
    case retryDeletion
}

enum OwnerTruthMediaTaskPresentationTone: String, Equatable, Sendable {
    case neutral
    case progress
    case warning
    case failure
}

/// User-facing projection of the durable Owner Truth media receipt. It never
/// exposes SourceObject IDs, object-store identities or provider error codes.
struct OwnerTruthMediaTaskPresentation: Equatable, Sendable {
    let taskID: UUID
    let mediaKind: OwnerTruthMediaKind
    let fileName: String
    let phase: OwnerTruthMediaTaskPhase
    let stateTitle: String
    let detail: String
    let tone: OwnerTruthMediaTaskPresentationTone
    let retryAction: OwnerTruthMediaTaskRetryAction?
    let retryTitle: String?
    /// A completed processor has persisted a derived Source and can open the
    /// existing Candidate review surface. The Source identifier stays in the
    /// durable receipt and is never exposed by this presentation.
    let candidateHandoffAvailable: Bool
    let candidateHandoffTitle: String?
    let updatedAt: Date

    init(receipt: OwnerTruthMediaTaskReceipt) {
        self.init(
            taskID: receipt.taskID,
            mediaKind: receipt.mediaKind,
            fileName: receipt.fileName,
            phase: receipt.phase,
            allowExternalProcessing: receipt.allowExternalProcessing,
            sourceObjectID: receipt.sourceObjectID,
            deletionStatus: receipt.deletionStatus,
            deletionRetryable: receipt.deletionRetryable,
            hasCandidateHandoffSource: receipt.derivedSourceID != nil,
            updatedAt: receipt.updatedAt
        )
    }

    init(
        taskID: UUID = UUID(),
        mediaKind: OwnerTruthMediaKind,
        fileName: String,
        phase: OwnerTruthMediaTaskPhase,
        allowExternalProcessing: Bool,
        sourceObjectID: UUID? = nil,
        deletionStatus: OwnerTruthMediaDeletionStatus? = nil,
        deletionRetryable: Bool? = nil,
        hasCandidateHandoffSource: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.taskID = taskID
        self.mediaKind = mediaKind
        self.fileName = fileName
        self.phase = phase
        self.updatedAt = updatedAt

        switch phase {
        case .prepared, .uploadReady:
            stateTitle = "待上传"
            detail = "文件已保存在本机，网络恢复后会继续同步。"
            tone = .neutral
            retryAction = .resumeUpload
            retryTitle = "继续上传"
        case .uploading:
            stateTitle = "上传中"
            detail = "正在安全同步文件，请保持当前页面。"
            tone = .progress
            retryAction = nil
            retryTitle = nil
        case .uploadRetryableFailed:
            stateTitle = "云端文件未同步"
            detail = "文件仍保存在本机，可使用原文件重新上传。"
            tone = .failure
            retryAction = .resumeUpload
            retryTitle = "重新上传"
        case .uploaded:
            stateTitle = "文件已验证"
            detail = allowExternalProcessing
                ? "文件已同步，等待处理服务开始整理。"
                : "文件已同步，未请求外部 AI 处理。"
            tone = .neutral
            retryAction = nil
            retryTitle = nil
        case .processingQueued:
            stateTitle = "排队处理中"
            detail = "文件已同步，正在等待处理服务。"
            tone = .progress
            retryAction = nil
            retryTitle = nil
        case .processing:
            stateTitle = "处理中"
            detail = "文件已同步，正在整理内容；结果不会自动进入回响。"
            tone = .progress
            retryAction = nil
            retryTitle = nil
        case .processed:
            stateTitle = "已处理"
            detail = hasCandidateHandoffSource
                ? "素材已整理为待确认记忆；确认后才会进入正式记忆。"
                : "处理结果已就绪，仍需确认后才会进入正式记忆。"
            tone = .neutral
            retryAction = nil
            retryTitle = nil
        case .retryableFailed, .failed:
            stateTitle = "文件已同步，处理暂不可用"
            detail = "原文件已保留，可稍后重新处理，无需重新选择文件。"
            tone = .failure
            retryAction = sourceObjectID == nil ? nil : .retryProcessing
            retryTitle = sourceObjectID == nil ? nil : "重新处理"
        case .quarantined:
            stateTitle = "文件已隔离"
            detail = "文件未通过安全检查，当前不会进入后续处理。"
            tone = .warning
            retryAction = nil
            retryTitle = nil
        case .deleted:
            switch deletionStatus {
            case .pending:
                stateTitle = "访问已撤销"
                detail = deletionRetryable == true
                    ? "该文件已停止读取和处理，删除会由服务端继续完成。"
                    : "该文件已停止读取和处理，正在完成删除。"
                tone = .neutral
                retryAction = nil
                retryTitle = nil
            case .partial:
                stateTitle = "访问已撤销"
                detail = deletionRetryable == true
                    ? "该文件已停止读取和处理，可重新请求完成删除。"
                    : "该文件已停止读取和处理，部分删除步骤将由服务端继续完成。"
                tone = deletionRetryable == true ? .failure : .warning
                retryAction = deletionRetryable == true ? .retryDeletion : nil
                retryTitle = deletionRetryable == true ? "重试删除" : nil
            case .unsupported:
                stateTitle = "访问已撤销"
                detail = deletionRetryable == true
                    ? "该文件已停止读取和处理，存储服务暂不可用，可稍后重试删除。"
                    : "该文件已停止读取和处理，当前存储服务暂不支持完成删除。"
                tone = deletionRetryable == true ? .failure : .warning
                retryAction = deletionRetryable == true ? .retryDeletion : nil
                retryTitle = deletionRetryable == true ? "重试删除" : nil
            case .completed:
                stateTitle = "已删除"
                detail = "该文件已停止读取和处理，删除已完成。"
                tone = .neutral
                retryAction = nil
                retryTitle = nil
            case .notRequested, .none:
                stateTitle = "已删除"
                detail = "该文件已不再提供读取或处理。"
                tone = .neutral
                retryAction = nil
                retryTitle = nil
            }
        }

        candidateHandoffAvailable = phase == .processed && hasCandidateHandoffSource
        candidateHandoffTitle = candidateHandoffAvailable ? "查看待确认记忆" : nil
    }

    var mediaTitle: String {
        switch mediaKind {
        case .image:
            return "图片素材"
        case .audio:
            return "音频素材"
        case .document:
            return "文档素材"
        case .video:
            return "视频素材"
        }
    }
}

final class OwnerTruthMediaTaskStore: @unchecked Sendable {
    static let manifestFileName = "manifest.json"
    static let pendingContentFileName = "payload.bin"
    static let shared = OwnerTruthMediaTaskStore()

    private let rootDirectory: URL
    private let secretStore: OwnerTruthMediaUploadSecretStoring
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let fileManager: FileManager
    private let now: () -> Date
    private let lock = NSRecursiveLock()

    init(
        rootDirectory: URL? = nil,
        secretStore: OwnerTruthMediaUploadSecretStoring = OwnerTruthMediaUploadKeychainStore.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory ?? Self.defaultRootDirectory(fileManager: fileManager)
        self.secretStore = secretStore
        self.accountLeaseRuntime = accountLeaseRuntime
        self.now = now
    }

    func prepare(
        accountLease: AccountLease,
        command: OwnerTruthMediaUploadIntentCommand,
        content: Data
    ) throws -> OwnerTruthMediaTaskReceipt {
        lock.lock()
        defer { lock.unlock() }
        try validateActiveLease(accountLease, at: .request)
        guard !content.isEmpty,
              content.count == command.fileSizeBytes,
              Self.sha256(content) == command.contentSHA256,
              accountLease.vaultId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw OwnerTruthMediaTaskStoreError.invalidPendingContent
        }

        let scopeDigest = try Self.scopeDigest(for: accountLease)
        let taskID = command.commandID
        let taskDirectory = taskDirectoryURL(scopeDigest: scopeDigest, taskID: taskID)
        let manifestURL = taskDirectory.appendingPathComponent(Self.manifestFileName)
        let contentURL = taskDirectory.appendingPathComponent(Self.pendingContentFileName)

        if fileManager.fileExists(atPath: manifestURL.path) {
            var receipt = try loadReceipt(
                taskID: taskID,
                scopeDigest: scopeDigest,
                accountLease: accountLease,
                allowLeaseRebind: true
            )
            guard receipt.commandID == command.commandID,
                  receipt.contentSHA256 == command.contentSHA256,
                  receipt.fileSizeBytes == command.fileSizeBytes else {
                throw OwnerTruthMediaTaskStoreError.invalidReceipt
            }
            if receipt.phase.needsPendingContent {
                let storedContent = try verifiedPendingContent(for: receipt)
                guard storedContent == content else {
                    throw OwnerTruthMediaTaskStoreError.invalidPendingContent
                }
            }
            receipt.updatedAt = now()
            try write(receipt, to: manifestURL)
            try validateActiveLease(accountLease, at: .commit)
            return receipt
        }

        let receipt = OwnerTruthMediaTaskReceipt(
            taskID: taskID,
            scopeDigest: scopeDigest,
            leaseFenceDigest: Self.leaseFenceDigest(for: accountLease),
            command: command,
            now: now()
        )
        do {
            try KnowledgeLocalStoragePolicy.write(content, to: contentURL)
            try write(receipt, to: manifestURL)
            try validateActiveLease(accountLease, at: .commit)
            return receipt
        } catch {
            try? fileManager.removeItem(at: taskDirectory)
            throw normalized(error)
        }
    }

    func apply(
        uploadIntentReceipt intent: OwnerTruthMediaUploadIntentReceipt,
        to taskID: UUID,
        accountLease: AccountLease
    ) throws -> OwnerTruthMediaTaskReceipt {
        lock.lock()
        defer { lock.unlock() }
        try validateActiveLease(accountLease, at: .request)
        let scopeDigest = try Self.scopeDigest(for: accountLease)
        var receipt = try loadReceipt(
            taskID: taskID,
            scopeDigest: scopeDigest,
            accountLease: accountLease,
            allowLeaseRebind: true
        )
        let source = intent.sourceObject
        guard intent.vaultID.rawValue == accountLease.vaultId,
              source.mediaKind == receipt.mediaKind,
              source.contentType == receipt.contentType,
              source.fileName == receipt.fileName,
              source.fileSizeBytes == receipt.fileSizeBytes,
              source.contentSHA256 == receipt.contentSHA256 else {
            throw OwnerTruthMediaTaskStoreError.invalidReceipt
        }

        receipt.uploadIntentID = intent.uploadIntent.uploadIntentID.rawValue
        receipt.uploadIntentExpiresAt = intent.uploadIntent.expiresAt
        receipt.sourceObjectID = source.sourceObjectID.rawValue
        apply(sourceObject: source, to: &receipt)

        if intent.uploadIntent.requiresClientUpload {
            guard let token = intent.uploadIntent.uploadToken else {
                throw OwnerTruthMediaTaskStoreError.uploadTokenUnavailable
            }
            try secretStore.save(token, scopeDigest: scopeDigest, taskID: taskID)
            receipt.phase = .uploadReady
        }
        receipt.updatedAt = now()
        do {
            try write(receipt, to: manifestURL(scopeDigest: scopeDigest, taskID: taskID))
            try validateActiveLease(accountLease, at: .commit)
            if !intent.uploadIntent.requiresClientUpload {
                try clearPendingArtifacts(for: receipt)
            }
            return receipt
        } catch {
            if intent.uploadIntent.requiresClientUpload {
                try? secretStore.remove(scopeDigest: scopeDigest, taskID: taskID)
            }
            throw normalized(error)
        }
    }

    func markUploading(
        taskID: UUID,
        accountLease: AccountLease
    ) throws -> OwnerTruthMediaTaskReceipt {
        try mutate(taskID: taskID, accountLease: accountLease) { receipt in
            guard receipt.phase == .uploadReady || receipt.phase == .uploading else {
                throw OwnerTruthMediaTaskStoreError.invalidReceipt
            }
            receipt.phase = .uploading
        }
    }

    func markUploadRetryableFailure(
        taskID: UUID,
        accountLease: AccountLease
    ) throws -> OwnerTruthMediaTaskReceipt {
        try mutate(taskID: taskID, accountLease: accountLease) { receipt in
            guard receipt.phase.needsPendingContent else {
                throw OwnerTruthMediaTaskStoreError.invalidReceipt
            }
            receipt.phase = .uploadRetryableFailed
            receipt.retryable = true
            receipt.failureCode = "uploadRetryable"
        }
    }

    func apply(
        sourceObjectResponse response: OwnerTruthMediaSourceObjectResponse,
        to taskID: UUID,
        accountLease: AccountLease
    ) throws -> OwnerTruthMediaTaskReceipt {
        lock.lock()
        defer { lock.unlock() }
        try validateActiveLease(accountLease, at: .request)
        let scopeDigest = try Self.scopeDigest(for: accountLease)
        var receipt = try loadReceipt(
            taskID: taskID,
            scopeDigest: scopeDigest,
            accountLease: accountLease,
            allowLeaseRebind: true
        )
        let source = response.sourceObject
        guard response.vaultID.rawValue == accountLease.vaultId,
              receipt.sourceObjectID == nil || receipt.sourceObjectID == source.sourceObjectID.rawValue,
              source.mediaKind == receipt.mediaKind,
              source.contentType == receipt.contentType,
              source.fileName == receipt.fileName,
              source.fileSizeBytes == receipt.fileSizeBytes,
              source.contentSHA256 == receipt.contentSHA256 else {
            throw OwnerTruthMediaTaskStoreError.invalidReceipt
        }
        receipt.sourceObjectID = source.sourceObjectID.rawValue
        apply(sourceObject: source, to: &receipt)
        receipt.updatedAt = now()
        try write(receipt, to: manifestURL(scopeDigest: scopeDigest, taskID: taskID))
        try validateActiveLease(accountLease, at: .commit)

        if source.state != .uploadPending {
            try clearPendingArtifacts(for: receipt)
        }
        return receipt
    }

    func apply(
        deletionReceipt response: OwnerTruthMediaDeletionReceipt,
        to taskID: UUID,
        accountLease: AccountLease
    ) throws -> OwnerTruthMediaTaskReceipt {
        lock.lock()
        defer { lock.unlock() }
        try validateActiveLease(accountLease, at: .request)
        let scopeDigest = try Self.scopeDigest(for: accountLease)
        var receipt = try loadReceipt(
            taskID: taskID,
            scopeDigest: scopeDigest,
            accountLease: accountLease,
            allowLeaseRebind: true
        )
        let source = response.sourceObject
        guard response.vaultID.rawValue == accountLease.vaultId,
              receipt.sourceObjectID == nil || receipt.sourceObjectID == source.sourceObjectID.rawValue,
              source.mediaKind == receipt.mediaKind,
              source.contentType == receipt.contentType,
              source.fileName == receipt.fileName,
              source.fileSizeBytes == receipt.fileSizeBytes,
              source.contentSHA256 == receipt.contentSHA256,
              response.accessState == .accessRevoked else {
            throw OwnerTruthMediaTaskStoreError.invalidReceipt
        }
        receipt.sourceObjectID = source.sourceObjectID.rawValue
        apply(sourceObject: source, to: &receipt)
        receipt.mediaAccessState = response.accessState
        receipt.deletionStatus = response.deletionStatus
        receipt.deletionRetryable = response.retryable
        receipt.deletionFailureCode = response.failureCode
        receipt.retryable = false
        receipt.failureCode = nil
        receipt.phase = .deleted
        receipt.updatedAt = response.updatedAt
        try write(receipt, to: manifestURL(scopeDigest: scopeDigest, taskID: taskID))
        try validateActiveLease(accountLease, at: .commit)
        try clearPendingArtifacts(for: receipt)
        return receipt
    }

    func recoverableTasks(for accountLease: AccountLease) throws -> [OwnerTruthMediaTaskReceipt] {
        lock.lock()
        defer { lock.unlock() }
        try validateActiveLease(accountLease, at: .request)
        let scopeDigest = try Self.scopeDigest(for: accountLease)
        let scopeDirectory = scopeDirectoryURL(scopeDigest: scopeDigest)
        guard fileManager.fileExists(atPath: scopeDirectory.path) else { return [] }
        let taskDirectories = try fileManager.contentsOfDirectory(
            at: scopeDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var receipts: [OwnerTruthMediaTaskReceipt] = []
        for directory in taskDirectories {
            guard let taskID = UUID(uuidString: directory.lastPathComponent) else { continue }
            var receipt = try loadReceipt(
                taskID: taskID,
                scopeDigest: scopeDigest,
                accountLease: accountLease,
                allowLeaseRebind: true
            )
            if receipt.phase.needsPendingContent {
                _ = try verifiedPendingContent(for: receipt)
            } else {
                try clearPendingArtifacts(for: receipt)
            }
            if receipt.leaseFenceDigest != Self.leaseFenceDigest(for: accountLease) {
                receipt.leaseFenceDigest = Self.leaseFenceDigest(for: accountLease)
                receipt.updatedAt = now()
                try write(receipt, to: manifestURL(scopeDigest: scopeDigest, taskID: taskID))
            }
            receipts.append(receipt)
        }
        try validateActiveLease(accountLease, at: .commit)
        return receipts.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.taskID.uuidString < $1.taskID.uuidString
            }
            return $0.createdAt < $1.createdAt
        }
    }

    func loadPendingContent(
        for taskID: UUID,
        accountLease: AccountLease
    ) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        try validateActiveLease(accountLease, at: .request)
        let scopeDigest = try Self.scopeDigest(for: accountLease)
        let receipt = try loadReceipt(
            taskID: taskID,
            scopeDigest: scopeDigest,
            accountLease: accountLease,
            allowLeaseRebind: true
        )
        let content = try verifiedPendingContent(for: receipt)
        try validateActiveLease(accountLease, at: .commit)
        return content
    }

    func uploadToken(
        for taskID: UUID,
        accountLease: AccountLease
    ) throws -> OwnerTruthMediaUploadToken? {
        lock.lock()
        defer { lock.unlock() }
        try validateActiveLease(accountLease, at: .request)
        let scopeDigest = try Self.scopeDigest(for: accountLease)
        _ = try loadReceipt(
            taskID: taskID,
            scopeDigest: scopeDigest,
            accountLease: accountLease,
            allowLeaseRebind: true
        )
        let token = try secretStore.load(scopeDigest: scopeDigest, taskID: taskID)
        try validateActiveLease(accountLease, at: .commit)
        return token
    }

    @discardableResult
    func purgeAccountDataForAccountDeletion(accountLease: AccountLease) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        do {
            let scopeDigest = try Self.scopeDigest(for: accountLease)
            let scopeDirectory = scopeDirectoryURL(scopeDigest: scopeDigest)
            var secretCleanupSucceeded = true
            if fileManager.fileExists(atPath: scopeDirectory.path) {
                let taskDirectories = try fileManager.contentsOfDirectory(
                    at: scopeDirectory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
                for directory in taskDirectories {
                    guard let taskID = UUID(uuidString: directory.lastPathComponent) else { continue }
                    do {
                        try secretStore.remove(scopeDigest: scopeDigest, taskID: taskID)
                    } catch {
                        secretCleanupSucceeded = false
                    }
                }
                try fileManager.removeItem(at: scopeDirectory)
            }
            return secretCleanupSucceeded
        } catch {
            return false
        }
    }

    private func mutate(
        taskID: UUID,
        accountLease: AccountLease,
        mutation: (inout OwnerTruthMediaTaskReceipt) throws -> Void
    ) throws -> OwnerTruthMediaTaskReceipt {
        lock.lock()
        defer { lock.unlock() }
        try validateActiveLease(accountLease, at: .request)
        let scopeDigest = try Self.scopeDigest(for: accountLease)
        var receipt = try loadReceipt(
            taskID: taskID,
            scopeDigest: scopeDigest,
            accountLease: accountLease,
            allowLeaseRebind: true
        )
        try mutation(&receipt)
        receipt.updatedAt = now()
        try write(receipt, to: manifestURL(scopeDigest: scopeDigest, taskID: taskID))
        try validateActiveLease(accountLease, at: .commit)
        return receipt
    }

    private func loadReceipt(
        taskID: UUID,
        scopeDigest: String,
        accountLease: AccountLease,
        allowLeaseRebind: Bool
    ) throws -> OwnerTruthMediaTaskReceipt {
        let url = manifestURL(scopeDigest: scopeDigest, taskID: taskID)
        guard fileManager.fileExists(atPath: url.path) else {
            throw OwnerTruthMediaTaskStoreError.taskNotFound
        }
        let receipt: OwnerTruthMediaTaskReceipt
        do {
            let data = try Data(contentsOf: url)
            receipt = try JSONDecoder().decode(OwnerTruthMediaTaskReceipt.self, from: data)
        } catch {
            throw OwnerTruthMediaTaskStoreError.invalidReceipt
        }
        guard receipt.schemaVersion == OwnerTruthMediaTaskReceipt.currentSchemaVersion,
              receipt.taskID == taskID,
              receipt.commandID == taskID,
              receipt.scopeDigest == scopeDigest,
              receipt.leaseFenceDigest == Self.leaseFenceDigest(for: accountLease)
                || allowLeaseRebind else {
            throw OwnerTruthMediaTaskStoreError.invalidReceipt
        }
        return receipt
    }

    private func verifiedPendingContent(for receipt: OwnerTruthMediaTaskReceipt) throws -> Data {
        let url = pendingContentURL(scopeDigest: receipt.scopeDigest, taskID: receipt.taskID)
        guard let content = try? Data(contentsOf: url),
              content.count == receipt.fileSizeBytes,
              Self.sha256(content) == receipt.contentSHA256 else {
            throw OwnerTruthMediaTaskStoreError.invalidPendingContent
        }
        return content
    }

    private func apply(
        sourceObject: OwnerTruthMediaSourceObjectReceipt,
        to receipt: inout OwnerTruthMediaTaskReceipt
    ) {
        receipt.sourceObjectState = sourceObject.state
        receipt.processingStatus = sourceObject.processingStatus
        receipt.derivedSourceID = sourceObject.derivedSourceID?.rawValue
        receipt.retryable = sourceObject.retryable
        receipt.failureCode = sourceObject.failureCode
        switch sourceObject.state {
        case .uploadPending:
            receipt.phase = .prepared
        case .verified:
            switch sourceObject.processingStatus {
            case .queued:
                receipt.phase = .processingQueued
            case .processing:
                receipt.phase = .processing
            case .succeeded:
                receipt.phase = .processed
            case .retryableFailed:
                receipt.phase = .retryableFailed
            case .failed, .blocked:
                receipt.phase = .failed
            case .notQueued, .notApplicable:
                receipt.phase = .uploaded
            }
        case .processing:
            receipt.phase = .processing
        case .processed:
            receipt.phase = .processed
        case .quarantined:
            receipt.phase = .quarantined
        case .failed:
            receipt.phase = sourceObject.retryable ? .retryableFailed : .failed
        case .deleted:
            receipt.phase = .deleted
        }
    }

    private func clearPendingArtifacts(for receipt: OwnerTruthMediaTaskReceipt) throws {
        let contentURL = pendingContentURL(
            scopeDigest: receipt.scopeDigest,
            taskID: receipt.taskID
        )
        if fileManager.fileExists(atPath: contentURL.path) {
            do {
                try fileManager.removeItem(at: contentURL)
            } catch {
                throw OwnerTruthMediaTaskStoreError.storageFailure
            }
        }
        do {
            try secretStore.remove(scopeDigest: receipt.scopeDigest, taskID: receipt.taskID)
        } catch {
            throw OwnerTruthMediaTaskStoreError.storageFailure
        }
    }

    private func validateActiveLease(
        _ accountLease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) throws {
        guard accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed else {
            throw OwnerTruthMediaTaskStoreError.staleAccountLease
        }
    }

    private func write(_ receipt: OwnerTruthMediaTaskReceipt, to url: URL) throws {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try KnowledgeLocalStoragePolicy.write(try encoder.encode(receipt), to: url)
        } catch let error as OwnerTruthMediaTaskStoreError {
            throw error
        } catch {
            throw OwnerTruthMediaTaskStoreError.storageFailure
        }
    }

    private func normalized(_ error: Error) -> Error {
        if let error = error as? OwnerTruthMediaTaskStoreError { return error }
        return OwnerTruthMediaTaskStoreError.storageFailure
    }

    private func manifestURL(scopeDigest: String, taskID: UUID) -> URL {
        taskDirectoryURL(scopeDigest: scopeDigest, taskID: taskID)
            .appendingPathComponent(Self.manifestFileName)
    }

    private func pendingContentURL(scopeDigest: String, taskID: UUID) -> URL {
        taskDirectoryURL(scopeDigest: scopeDigest, taskID: taskID)
            .appendingPathComponent(Self.pendingContentFileName)
    }

    private func taskDirectoryURL(scopeDigest: String, taskID: UUID) -> URL {
        scopeDirectoryURL(scopeDigest: scopeDigest)
            .appendingPathComponent(taskID.uuidString.lowercased(), isDirectory: true)
    }

    private func scopeDirectoryURL(scopeDigest: String) -> URL {
        rootDirectory.appendingPathComponent(scopeDigest, isDirectory: true)
    }

    private static func defaultRootDirectory(fileManager: FileManager) -> URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return root
            .appendingPathComponent("DreamJourney", isDirectory: true)
            .appendingPathComponent("OwnerTruthMediaTasks", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
    }

    private static func scopeDigest(for accountLease: AccountLease) throws -> String {
        let subject = accountLease.subjectId.trimmingCharacters(in: .whitespacesAndNewlines)
        let vault = accountLease.vaultId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subject.isEmpty, !vault.isEmpty else {
            throw OwnerTruthMediaTaskStoreError.invalidScope
        }
        return sha256(Data("owner-truth-media-scope-v1|\(subject.count):\(subject)|\(vault.count):\(vault)".utf8))
    }

    private static func leaseFenceDigest(for accountLease: AccountLease) -> String {
        let value = "owner-truth-media-lease-v1|\(accountLease.generation)|"
            + "\(accountLease.generationId.uuidString.lowercased())|\(accountLease.authorityEpoch)"
        return sha256(Data(value.utf8))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

}

struct OwnerTruthMediaTaskRecoveryReport: Equatable, Sendable {
    let resumedUploadCount: Int
    let refreshedStatusCount: Int
    let failedTaskCount: Int
}

final class OwnerTruthMediaTaskRecoveryCoordinator: @unchecked Sendable {
    static let shared = OwnerTruthMediaTaskRecoveryCoordinator()

    private let store: OwnerTruthMediaTaskStore
    private let client: OwnerTruthMediaCaptureClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let lock = NSLock()
    private var operationGeneration: UInt64 = 0

    init(
        store: OwnerTruthMediaTaskStore = .shared,
        client: OwnerTruthMediaCaptureClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.store = store
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    /// Invalidates all in-flight callbacks before an account lifecycle transition
    /// unmounts the old owner's durable media task store.
    func cancelForAccountLifecycle() {
        _ = beginOperation()
    }

    func restore(
        accountLease: AccountLease,
        completion: @escaping (OwnerTruthMediaTaskRecoveryReport) -> Void
    ) {
        let generation = beginOperation()
        let tasks: [OwnerTruthMediaTaskReceipt]
        do {
            tasks = try store.recoverableTasks(for: accountLease)
        } catch {
            finish(
                OwnerTruthMediaTaskRecoveryReport(
                    resumedUploadCount: 0,
                    refreshedStatusCount: 0,
                    failedTaskCount: 1
                ),
                generation: generation,
                completion: completion
            )
            return
        }
        process(
            tasks,
            index: 0,
            accountLease: accountLease,
            generation: generation,
            report: OwnerTruthMediaTaskRecoveryReport(
                resumedUploadCount: 0,
                refreshedStatusCount: 0,
                failedTaskCount: 0
            ),
            completion: completion
        )
    }

    /// Requests a new server-side processing generation for an already
    /// uploaded SourceObject. The local file is not picked or uploaded again.
    func retryProcessing(
        taskID: UUID,
        accountLease: AccountLease,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let generation = beginOperation()
        do {
            guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
                  let task = try store.recoverableTasks(for: accountLease)
                    .first(where: { $0.taskID == taskID }),
                  task.phase == .retryableFailed || task.phase == .failed,
                  let vaultID = OwnerTruthVaultID(accountLease.vaultId),
                  let sourceObjectID = task.sourceObjectID.map({ OwnerTruthRecordID(rawValue: $0) }) else {
                throw OwnerTruthMediaTaskStoreError.invalidReceipt
            }

            client.retryOwnerTruthMediaProcessing(
                accountLease: accountLease,
                vaultID: vaultID,
                sourceObjectID: sourceObjectID
            ) { [weak self] result in
                guard let self,
                      self.acceptsCallback(generation, accountLease: accountLease) else { return }
                do {
                    _ = try self.store.apply(
                        sourceObjectResponse: result.get(),
                        to: taskID,
                        accountLease: accountLease
                    )
                    self.finishRetry(.success(()), generation: generation, completion: completion)
                } catch {
                    self.finishRetry(.failure(error), generation: generation, completion: completion)
                }
            }
        } catch {
            finishRetry(.failure(error), generation: generation, completion: completion)
        }
    }

    /// Accepts a revocation-first deletion command. The local task is updated
    /// only from the server's value-minimized receipt, which clears any
    /// pending upload content and prevents restart recovery from resuming it.
    func requestDeletion(
        taskID: UUID,
        accountLease: AccountLease,
        command: OwnerTruthMediaDeletionCommand,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let generation = beginOperation()
        do {
            guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
                  let task = try store.recoverableTasks(for: accountLease)
                    .first(where: { $0.taskID == taskID }),
                  let vaultID = OwnerTruthVaultID(accountLease.vaultId),
                  let sourceObjectID = task.sourceObjectID.map({ OwnerTruthRecordID(rawValue: $0) }) else {
                throw OwnerTruthMediaTaskStoreError.invalidReceipt
            }

            client.requestOwnerTruthMediaDeletion(
                accountLease: accountLease,
                vaultID: vaultID,
                sourceObjectID: sourceObjectID,
                command: command
            ) { [weak self] result in
                guard let self,
                      self.acceptsCallback(generation, accountLease: accountLease) else { return }
                do {
                    _ = try self.store.apply(
                        deletionReceipt: result.get(),
                        to: taskID,
                        accountLease: accountLease
                    )
                    self.finishRetry(.success(()), generation: generation, completion: completion)
                } catch {
                    self.finishRetry(.failure(error), generation: generation, completion: completion)
                }
            }
        } catch {
            finishRetry(.failure(error), generation: generation, completion: completion)
        }
    }

    /// Replays only a provider-side deletion after the object has already
    /// been revoked locally and on the server. It never restores bytes,
    /// upload credentials, processing, or read access.
    func retryDeletion(
        taskID: UUID,
        accountLease: AccountLease,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let generation = beginOperation()
        do {
            guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
                  let task = try store.recoverableTasks(for: accountLease)
                    .first(where: { $0.taskID == taskID }),
                  task.phase == .deleted,
                  task.deletionRetryable == true,
                  task.deletionStatus == .partial || task.deletionStatus == .unsupported,
                  let vaultID = OwnerTruthVaultID(accountLease.vaultId),
                  let sourceObjectID = task.sourceObjectID.map({ OwnerTruthRecordID(rawValue: $0) }) else {
                throw OwnerTruthMediaTaskStoreError.invalidReceipt
            }
            let command = try OwnerTruthMediaDeletionCommand(
                expectedAuthorityEpoch: task.expectedAuthorityEpoch
            )
            client.retryOwnerTruthMediaDeletion(
                accountLease: accountLease,
                vaultID: vaultID,
                sourceObjectID: sourceObjectID,
                command: command
            ) { [weak self] result in
                guard let self,
                      self.acceptsCallback(generation, accountLease: accountLease) else { return }
                do {
                    _ = try self.store.apply(
                        deletionReceipt: result.get(),
                        to: taskID,
                        accountLease: accountLease
                    )
                    self.finishRetry(.success(()), generation: generation, completion: completion)
                } catch {
                    self.finishRetry(.failure(error), generation: generation, completion: completion)
                }
            }
        } catch {
            finishRetry(.failure(error), generation: generation, completion: completion)
        }
    }

    private func process(
        _ tasks: [OwnerTruthMediaTaskReceipt],
        index: Int,
        accountLease: AccountLease,
        generation: UInt64,
        report: OwnerTruthMediaTaskRecoveryReport,
        completion: @escaping (OwnerTruthMediaTaskRecoveryReport) -> Void
    ) {
        guard isCurrent(generation),
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return
        }
        guard index < tasks.count else {
            finish(report, generation: generation, completion: completion)
            return
        }
        let task = tasks[index]
        if task.phase == .prepared || task.phase == .uploadRetryableFailed {
            createIntentAndContinue(
                task,
                tasks: tasks,
                index: index,
                accountLease: accountLease,
                generation: generation,
                report: report,
                completion: completion
            )
        } else if task.phase == .uploadReady || task.phase == .uploading {
            uploadAndContinue(
                task,
                tasks: tasks,
                index: index,
                accountLease: accountLease,
                generation: generation,
                report: report,
                completion: completion
            )
        } else if task.phase.needsStatusRefresh {
            refreshAndContinue(
                task,
                tasks: tasks,
                index: index,
                accountLease: accountLease,
                generation: generation,
                report: report,
                completion: completion
            )
        } else {
            process(
                tasks,
                index: index + 1,
                accountLease: accountLease,
                generation: generation,
                report: report,
                completion: completion
            )
        }
    }

    private func createIntentAndContinue(
        _ task: OwnerTruthMediaTaskReceipt,
        tasks: [OwnerTruthMediaTaskReceipt],
        index: Int,
        accountLease: AccountLease,
        generation: UInt64,
        report: OwnerTruthMediaTaskRecoveryReport,
        completion: @escaping (OwnerTruthMediaTaskRecoveryReport) -> Void
    ) {
        guard let vaultID = OwnerTruthVaultID(accountLease.vaultId),
              let command = try? task.command() else {
            continueAfterFailure(
                tasks, index: index, accountLease: accountLease, generation: generation,
                report: report, completion: completion, uploadTask: task
            )
            return
        }
        client.createOwnerTruthMediaUploadIntent(
            accountLease: accountLease,
            vaultID: vaultID,
            command: command
        ) { [weak self] result in
            guard let self,
                  self.acceptsCallback(generation, accountLease: accountLease) else { return }
            do {
                let receipt = try self.store.apply(
                    uploadIntentReceipt: result.get(),
                    to: task.taskID,
                    accountLease: accountLease
                )
                if receipt.phase == .uploadReady {
                    self.uploadAndContinue(
                        receipt,
                        tasks: tasks,
                        index: index,
                        accountLease: accountLease,
                        generation: generation,
                        report: report,
                        completion: completion
                    )
                } else {
                    self.process(
                        tasks,
                        index: index + 1,
                        accountLease: accountLease,
                        generation: generation,
                        report: report,
                        completion: completion
                    )
                }
            } catch {
                self.continueAfterFailure(
                    tasks, index: index, accountLease: accountLease, generation: generation,
                    report: report, completion: completion, uploadTask: task
                )
            }
        }
    }

    private func uploadAndContinue(
        _ task: OwnerTruthMediaTaskReceipt,
        tasks: [OwnerTruthMediaTaskReceipt],
        index: Int,
        accountLease: AccountLease,
        generation: UInt64,
        report: OwnerTruthMediaTaskRecoveryReport,
        completion: @escaping (OwnerTruthMediaTaskRecoveryReport) -> Void
    ) {
        do {
            guard let vaultID = OwnerTruthVaultID(accountLease.vaultId),
                  let uploadIntentID = task.uploadIntentID.map({ OwnerTruthRecordID(rawValue: $0) }),
                  let token = try store.uploadToken(for: task.taskID, accountLease: accountLease) else {
                throw OwnerTruthMediaTaskStoreError.uploadTokenUnavailable
            }
            let content = try store.loadPendingContent(for: task.taskID, accountLease: accountLease)
            _ = try store.markUploading(taskID: task.taskID, accountLease: accountLease)
            client.uploadOwnerTruthMediaContent(
                accountLease: accountLease,
                vaultID: vaultID,
                uploadIntentID: uploadIntentID,
                uploadToken: token,
                contentType: task.contentType,
                content: content
            ) { [weak self] result in
                guard let self,
                      self.acceptsCallback(generation, accountLease: accountLease) else { return }
                do {
                    _ = try self.store.apply(
                        sourceObjectResponse: result.get(),
                        to: task.taskID,
                        accountLease: accountLease
                    )
                    self.process(
                        tasks,
                        index: index + 1,
                        accountLease: accountLease,
                        generation: generation,
                        report: OwnerTruthMediaTaskRecoveryReport(
                            resumedUploadCount: report.resumedUploadCount + 1,
                            refreshedStatusCount: report.refreshedStatusCount,
                            failedTaskCount: report.failedTaskCount
                        ),
                        completion: completion
                    )
                } catch {
                    self.continueAfterFailure(
                        tasks, index: index, accountLease: accountLease, generation: generation,
                        report: report, completion: completion, uploadTask: task
                    )
                }
            }
        } catch {
            continueAfterFailure(
                tasks, index: index, accountLease: accountLease, generation: generation,
                report: report, completion: completion, uploadTask: task
            )
        }
    }

    private func refreshAndContinue(
        _ task: OwnerTruthMediaTaskReceipt,
        tasks: [OwnerTruthMediaTaskReceipt],
        index: Int,
        accountLease: AccountLease,
        generation: UInt64,
        report: OwnerTruthMediaTaskRecoveryReport,
        completion: @escaping (OwnerTruthMediaTaskRecoveryReport) -> Void
    ) {
        guard let vaultID = OwnerTruthVaultID(accountLease.vaultId),
              let sourceObjectID = task.sourceObjectID.map({ OwnerTruthRecordID(rawValue: $0) }) else {
            continueAfterFailure(
                tasks, index: index, accountLease: accountLease, generation: generation,
                report: report, completion: completion
            )
            return
        }
        client.fetchOwnerTruthMediaSourceObject(
            accountLease: accountLease,
            vaultID: vaultID,
            sourceObjectID: sourceObjectID
        ) { [weak self] result in
            guard let self,
                  self.acceptsCallback(generation, accountLease: accountLease) else { return }
            do {
                _ = try self.store.apply(
                    sourceObjectResponse: result.get(),
                    to: task.taskID,
                    accountLease: accountLease
                )
                self.process(
                    tasks,
                    index: index + 1,
                    accountLease: accountLease,
                    generation: generation,
                    report: OwnerTruthMediaTaskRecoveryReport(
                        resumedUploadCount: report.resumedUploadCount,
                        refreshedStatusCount: report.refreshedStatusCount + 1,
                        failedTaskCount: report.failedTaskCount
                    ),
                    completion: completion
                )
            } catch {
                self.continueAfterFailure(
                    tasks, index: index, accountLease: accountLease, generation: generation,
                    report: report, completion: completion
                )
            }
        }
    }

    private func continueAfterFailure(
        _ tasks: [OwnerTruthMediaTaskReceipt],
        index: Int,
        accountLease: AccountLease,
        generation: UInt64,
        report: OwnerTruthMediaTaskRecoveryReport,
        completion: @escaping (OwnerTruthMediaTaskRecoveryReport) -> Void,
        uploadTask: OwnerTruthMediaTaskReceipt? = nil
    ) {
        if let uploadTask,
           acceptsCallback(generation, accountLease: accountLease) {
            _ = try? store.markUploadRetryableFailure(
                taskID: uploadTask.taskID,
                accountLease: accountLease
            )
        }
        process(
            tasks,
            index: index + 1,
            accountLease: accountLease,
            generation: generation,
            report: OwnerTruthMediaTaskRecoveryReport(
                resumedUploadCount: report.resumedUploadCount,
                refreshedStatusCount: report.refreshedStatusCount,
                failedTaskCount: report.failedTaskCount + 1
            ),
            completion: completion
        )
    }

    private func beginOperation() -> UInt64 {
        lock.lock()
        operationGeneration &+= 1
        let generation = operationGeneration
        lock.unlock()
        return generation
    }

    private func isCurrent(_ generation: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return operationGeneration == generation
    }

    private func acceptsCallback(_ generation: UInt64, accountLease: AccountLease) -> Bool {
        isCurrent(generation)
            && accountLeaseRuntime.validate(accountLease, at: .commit).allowed
    }

    private func finish(
        _ report: OwnerTruthMediaTaskRecoveryReport,
        generation: UInt64,
        completion: @escaping (OwnerTruthMediaTaskRecoveryReport) -> Void
    ) {
        guard isCurrent(generation) else { return }
        if Thread.isMainThread {
            completion(report)
        } else {
            DispatchQueue.main.async { completion(report) }
        }
    }

    private func finishRetry(
        _ result: Result<Void, Error>,
        generation: UInt64,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard isCurrent(generation) else { return }
        if Thread.isMainThread {
            completion(result)
        } else {
            DispatchQueue.main.async { completion(result) }
        }
    }
}
