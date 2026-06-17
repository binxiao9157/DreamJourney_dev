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

    func postArchiveItem(
        _ payload: [String: Any],
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        completion(.success(payload))
    }
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

@main
enum ArchiveContextSnapshotCheck {
    static func main() {
        UserManager.shared.currentUser = TestUser(id: "archive_context_test")
        UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.archive_context_test")
        defer {
            UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.archive_context_test")
        }

        var analyzedText = MemoryArchiveItemFactory.makeTextItem(note: "奶奶在老家的院子里晒太阳")
        analyzedText.applyLocalAnalysisResult(now: Date(timeIntervalSince1970: 1_800_000_000))

        let manualAudio = MemoryArchiveItemFactory.makeAudioItem(
            localPath: "/tmp/archive-audio.m4a",
            duration: 12,
            note: "爸爸讲起小时候听收音机的声音"
        )

        let pendingPhoto = MemoryArchiveItemFactory.makePhotoItem(localPath: "/tmp/pending-photo.jpg")

        MemoryArchiveRepository.shared.add(pendingPhoto)
        MemoryArchiveRepository.shared.add(manualAudio)
        MemoryArchiveRepository.shared.add(analyzedText)

        let snapshot = MemoryArchiveRepository.shared.contextSnapshot(limit: 10)
        assertEqual(snapshot.totalItemCount, 3, "snapshot total count")
        assertEqual(snapshot.availableItemCount, 2, "snapshot available count")
        assertEqual(snapshot.entries.count, 2, "snapshot entry count")
        assertEqual(snapshot.entries.first?.title ?? "", "文字记忆", "snapshot keeps newest available first")
        assertContains(snapshot.entries.first?.people.joined(separator: ",") ?? "", "奶奶", "snapshot carries people hints")
        assertContains(snapshot.entries.first?.tags.joined(separator: ",") ?? "", "文字线索", "snapshot carries tags")

        let prompt = snapshot.promptSection
        assertContains(prompt, "【记忆档案馆素材线索】", "snapshot prompt title")
        assertContains(prompt, "文字记忆", "snapshot prompt text item")
        assertContains(prompt, "语音档案", "snapshot prompt audio item")
        assertContains(prompt, "爸爸", "snapshot prompt relationship hint")
        assertNotContains(prompt, "pending-photo", "snapshot excludes pending photo path")
        assertNotContains(prompt, "/tmp/archive-audio.m4a", "snapshot does not expose local paths")

        let limitedSnapshot = MemoryArchiveRepository.shared.contextSnapshot(limit: 1)
        assertEqual(limitedSnapshot.entries.count, 1, "snapshot respects limit")
    }
}
