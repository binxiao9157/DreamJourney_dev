import Foundation

struct TestUser {
    let id: String
}

final class UserManager {
    static let shared = UserManager()
    var currentUser: TestUser?
}

final class DreamJourneyBackendClient {
    static let shared = DreamJourneyBackendClient()

    var isArchiveSyncConfigured: Bool {
        false
    }

    var isTimeLetterDispatchConfigured: Bool {
        false
    }

    func postArchiveItem(
        _ payload: [String: Any],
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        completion(.success(payload))
    }

    func listArchiveItems(
        userId: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        completion(.success(["items": []]))
    }

    func dispatchDueTimeLetters(
        limit: Int,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        completion(.success(["status": "dispatched", "limit": limit]))
    }

    func listMailboxLetters(
        userId: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        completion(.success(["userId": userId, "items": []]))
    }

    func markMailboxLetterRead(
        userId: String,
        letterId: String,
        readAtISO: String? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        completion(.success([
            "status": "read",
            "item": [
                "id": letterId,
                "kind": "timeLetterReminder",
                "userId": userId,
                "sourceArchiveItemId": "stub",
                "title": "stub",
                "status": "read",
                "deliveredAt": "",
                "readAt": readAtISO ?? "",
                "recipientRole": "owner",
            ],
        ]))
    }

    func archiveMailboxLetter(
        userId: String,
        letterId: String,
        archivedAtISO: String? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        completion(.success([
            "status": "archived",
            "item": [
                "id": letterId,
                "kind": "timeLetterReminder",
                "userId": userId,
                "sourceArchiveItemId": "stub",
                "title": "stub",
                "status": "archived",
                "deliveredAt": "",
                "archivedAt": archivedAtISO ?? "",
                "recipientRole": "owner",
            ],
        ]))
    }

    func getTimeLetterDetail(
        ownerUserId: String,
        itemId: String,
        viewerUserId: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        completion(.failure(NSError(domain: "ArchiveContextSnapshotCheck", code: 1)))
    }
}

struct ArchiveMediaUploadIntent {
    let uploadIntentId: String
    let objectKey: String
    let storageProvider: String
    let uploadURL: String
}

struct DigitalHumanContext {
    let ownerId: String
    let isSelfAssistant: Bool
}

final class DigitalHumanContextStore {
    static let shared = DigitalHumanContextStore()
    var current = DigitalHumanContext(ownerId: "", isSelfAssistant: true)
}

// The repository's message-center extension only needs the relationship owner
// while this focused model check exercises archive-context behavior. The real
// FamilyMember model is covered by its own module tests; keeping this minimal
// test seam avoids pulling the entire family UI/client dependency graph into a
// standalone Swift executable.
struct FamilyMember {
    let relationshipOwnerUserId: String?
}

func assertEqual(_ lhs: Int, _ rhs: Int, _ message: String) {
    guard lhs == rhs else {
        fatalError("\(message): expected \(rhs), got \(lhs)")
    }
}

func assertEqual(_ lhs: String, _ rhs: String, _ message: String) {
    guard lhs == rhs else {
        fatalError("\(message): expected \(rhs), got \(lhs)")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpectedly found \(needle)")
    }
}

func assertTrue(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

@main
enum ArchiveContextSnapshotCheck {
    static func main() {
        let userId = "archive_context_test_\(UUID().uuidString)"
        let session = AccountSession(
            subjectId: userId,
            vaultId: "archive_context_snapshot_vault",
            sessionId: "archive_context_snapshot_session",
            tokenFamilyId: "archive_context_snapshot_family",
            sessionVersion: 1,
            generation: 1,
            generationId: UUID(),
            state: .active,
            activatedAt: Date()
        )
        UserManager.shared.currentUser = TestUser(id: userId)
        DigitalHumanContextStore.shared.current = DigitalHumanContext(
            ownerId: userId,
            isSelfAssistant: true
        )
        AccountLeaseRuntime.shared.updateAuthorityEpoch("archive-context-snapshot-check")
        AccountLeaseRuntime.shared.publish(session: session)
        guard let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userId) else {
            fatalError("archive context fixture must establish an active account lease")
        }
        defer {
            _ = MemoryArchiveRepository.shared.purgeLocalArchiveDataForAccountDeletion(
                accountLease: accountLease
            )
            AccountLeaseRuntime.shared.publish(session: nil)
            UserManager.shared.currentUser = nil
            DigitalHumanContextStore.shared.current = DigitalHumanContext(
                ownerId: "",
                isSelfAssistant: true
            )
        }

        var analyzedText = MemoryArchiveItemFactory.makeTextItem(note: "奶奶在老家的院子里晒太阳")
        analyzedText.applyLocalAnalysisResult(now: Date(timeIntervalSince1970: 1_800_000_000))

        let manualAudio = MemoryArchiveItemFactory.makeAudioItem(
            localPath: "/tmp/archive-audio.m4a",
            duration: 12,
            note: "爸爸讲起小时候听收音机的声音"
        )

        let pendingPhoto = MemoryArchiveItemFactory.makePhotoItem(localPath: "/tmp/pending-photo.jpg")
        var failedPhoto = MemoryArchiveItemFactory.makePhotoItem(localPath: "/tmp/failed-photo.jpg")
        failedPhoto.note = "爷爷在院子里整理旧相册"
        failedPhoto.detectedPeople = ["不应注入的人物"]
        failedPhoto.tags = ["不应注入的标签"]
        failedPhoto.metadata[MemoryArchiveItem.analysisLocationCluesMetadataKey] = "不应注入的地点"
        failedPhoto.metadata[MemoryArchiveItem.analysisSceneCluesMetadataKey] = "不应注入的场景"
        failedPhoto.markAnalysisFailed(reason: "provider_unavailable")

        assertTrue(
            MemoryArchiveRepository.shared.add(pendingPhoto),
            "pending photo must be accepted under the active owner lease"
        )
        assertTrue(
            MemoryArchiveRepository.shared.add(failedPhoto, syncToBackend: false),
            "failed photo must be accepted under the active owner lease"
        )
        assertTrue(
            MemoryArchiveRepository.shared.add(manualAudio),
            "audio item must be accepted under the active owner lease"
        )
        assertTrue(
            MemoryArchiveRepository.shared.add(analyzedText),
            "text item must be accepted under the active owner lease"
        )

        let snapshot = MemoryArchiveRepository.shared.contextSnapshot(limit: 10)
        assertEqual(snapshot.totalItemCount, 4, "snapshot total count")
        assertEqual(snapshot.availableItemCount, 3, "snapshot available count")
        assertEqual(snapshot.entries.count, 3, "snapshot entry count")
        assertEqual(snapshot.entries.first?.title ?? "", "文字记忆", "snapshot keeps newest available first")
        assertContains(snapshot.entries.first?.people.joined(separator: ",") ?? "", "奶奶", "snapshot carries people hints")
        assertContains(snapshot.entries.first?.tags.joined(separator: ",") ?? "", "文字线索", "snapshot carries tags")
        guard let failedEntry = snapshot.entries.first(where: { $0.title == "相册影像" }) else {
            fatalError("failed analysis item with user note should remain available for archive context")
        }
        assertContains(failedEntry.summary, "爷爷在院子里整理旧相册", "failed analysis context should preserve user note")
        assertEqual(failedEntry.people.count, 0, "failed analysis context should drop people clues")
        assertEqual(failedEntry.locations.count, 0, "failed analysis context should drop location clues")
        assertEqual(failedEntry.scenes.count, 0, "failed analysis context should drop scene clues")
        assertEqual(failedEntry.tags.count, 0, "failed analysis context should drop tags")

        let prompt = snapshot.promptSection
        assertContains(prompt, "【记忆档案馆素材线索】", "snapshot prompt title")
        assertContains(prompt, "文字记忆", "snapshot prompt text item")
        assertContains(prompt, "语音档案", "snapshot prompt audio item")
        assertContains(prompt, "爷爷在院子里整理旧相册", "snapshot prompt keeps failed-item note")
        assertContains(prompt, "爸爸", "snapshot prompt relationship hint")
        assertNotContains(prompt, "不应注入的人物", "snapshot excludes failed people clues")
        assertNotContains(prompt, "不应注入的地点", "snapshot excludes failed location clues")
        assertNotContains(prompt, "不应注入的场景", "snapshot excludes failed scene clues")
        assertNotContains(prompt, "不应注入的标签", "snapshot excludes failed tags")
        assertNotContains(prompt, "pending-photo", "snapshot excludes pending photo path")
        assertNotContains(prompt, "/tmp/archive-audio.m4a", "snapshot does not expose local paths")

        let limitedSnapshot = MemoryArchiveRepository.shared.contextSnapshot(limit: 1)
        assertEqual(limitedSnapshot.entries.count, 1, "snapshot respects limit")
        print("Archive context snapshot checks passed")
    }
}
