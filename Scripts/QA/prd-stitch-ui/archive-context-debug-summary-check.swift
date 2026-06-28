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
enum ArchiveContextDebugSummaryCheck {
    static func main() {
        UserManager.shared.currentUser = TestUser(id: "archive_debug_summary_test")
        UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.archive_debug_summary_test")
        defer {
            UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.archive_debug_summary_test")
        }

        var analyzedText = MemoryArchiveItemFactory.makeTextItem(note: "奶奶在老家院子里晒太阳")
        analyzedText.applyLocalAnalysisResult(now: Date(timeIntervalSince1970: 1_800_000_000))

        let timeLetter = MemoryArchiveItemFactory.makeTimeLetter(note: "写给妈妈的一封信")
        let manualAudio = MemoryArchiveItemFactory.makeAudioItem(
            localPath: "/tmp/archive-audio-secret.m4a",
            duration: 12,
            note: "爸爸讲起小时候听收音机的声音"
        )
        let pendingPhoto = MemoryArchiveItemFactory.makePhotoItem(localPath: "/tmp/pending-photo-secret.jpg")

        MemoryArchiveRepository.shared.add(pendingPhoto, syncToBackend: false)
        MemoryArchiveRepository.shared.add(manualAudio, syncToBackend: false)
        MemoryArchiveRepository.shared.add(timeLetter, syncToBackend: false)
        MemoryArchiveRepository.shared.add(analyzedText, syncToBackend: false)

        let snapshot = MemoryArchiveRepository.shared.contextSnapshot(limit: 10)
        let debugSummary = snapshot.debugSummary(limit: 3)

        assertEqual(debugSummary.split(separator: "，").count, 3, "debug summary respects limit")
        assertContains(debugSummary, "文字记忆（文字）", "debug summary includes text title and kind")
        assertContains(debugSummary, "时间信件（信件）", "debug summary includes time letter title and kind")
        assertContains(debugSummary, "语音档案（语音）", "debug summary includes audio title and kind")
        assertNotContains(debugSummary, "/tmp", "debug summary hides local paths")
        assertNotContains(debugSummary, "pending-photo-secret", "debug summary excludes pending unavailable item")

        let emptySummary = MemoryArchiveContextSnapshot(
            totalItemCount: 0,
            availableItemCount: 0,
            entries: []
        ).debugSummary(limit: 3)
        assertContains(emptySummary, "none", "empty debug summary is explicit")
    }
}
